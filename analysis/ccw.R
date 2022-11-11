################################################################################
#
# Cox models (propensity score analysis) // BA.1 period
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'adjustment_set' /in {full, agesex, crude} (--> adjustment set used)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(lubridate)
library(survival)
library(survminer)
library(survey)
library(here)
library(readr)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create figures directory
fs::dir_create(here::here("output", "figs"))
# Create tables directory
fs::dir_create(here::here("output", "tables"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
} else if (args[[1]] == "ba1") {
  period = "ba1"
} else if (args[[1]] == "ba2") {
  period = "ba2"
} else {
  # Print error if no argument specified
  stop("No period specified")
}
# Adjustment set
if (length(args) == 0){
  adjustment_set = "full"
} else if (args[[3]] == "full") {
  adjustment_set = "full"
} else if (args[[3]] == "agesex") {
  adjustment_set = "agesex"
} else if (args[[3]] == "crude") {
  adjustment_set = "crude"
} else {
  # Print error if no argument specified
  stop("No adjustment set specified")
}

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed_", "day0", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))

################################################################################
# 0.4 Prepare data
################################################################################
# This step 
# 1. simplifies the variable 'status_primary'
# --> no distinction is made between censored because dereg or because
#     noncovid_death occurred
# --> levels are 0 (no event/censored); 1 (covid hosp/death)
# FIX ME:
# - Should we treat non covid death as a competing risk? (..somehow) 
#   (= informative censoring)
# - Should we censor for non covid hosp? --> currently ignored
# 2. simplifies the variable 'any_treatment_strategy_cat'
# --> this variable is equal to 'Untreated', 'Sotrovimab' or 'Molnupiravir', 
#     depending on whether patients has been treated or not during follow up 
# --> people are sometimes treated after experiencing a primary event
# --> we classify people as untreated if they experience an event and set their
#     tb_postest_treat to NA (= time between treatment and day 0)
data <-
  data %>%
  mutate(
    status_primary_simple = case_when(
      status_primary %in% c("none", "dereg", "noncovid_death") ~ "0",
      status_primary == "covid_hosp_death" ~ "1",
      TRUE ~ status_primary %>% as.character(),
      ) %>% factor(levels = c("0", "1")),
    # in the data, people sometimes go on treatment after experiencing an event
    # (censoring event or outcome event)
    # --> these patient's treatment is set to untreated
    any_treatment_strategy_cat = case_when(
      # if on same day, we assume treatment was before event
      fu_primary < tb_postest_treat ~ "Untreated" %>%
        factor(levels = c("Untreated", "Molnupiravir", "Sotrovimab")),
      TRUE ~ any_treatment_strategy_cat,
    ),
    # if people are untreated following the above defined rule, set 
    # tb_postest_treat (day of fup on wich they've been treated to NA)
    tb_postest_treat = case_when(
      any_treatment_strategy_cat == "Untreated" ~ NA_real_,
      TRUE ~ tb_postest_treat,
    ),
  )

################################################################################
# STEP 1-CLONING: CREATION OF OUTCOME AND FOLLOW-UP TIME IN EACH ARM
################################################################################
# This step adds the following variables in both arms (control + treatment):
# - fup: the follow-up time in the emulated trial (which can be different from 
#       the observed follow-up time)
# - outcome: the outcome in the emulated trial (which can be different from the 
#            observed outcome)
# - fup_uncensored: the follow-up time uncensored in the trial arm (can be 
#                   shorter than the follow-up time in the outcome model)
# - censoring: a binary variable indicating whether the patient was censored in 
#              a given arm (either because they receive surgery in the control 
#              arm or they didn't receive surgery in the surgery arm)
###################################################
# ARM CONTROL: no treatment within 5 days
###################################################
data_control <- 
  data %>%
  mutate(arm = "Control",
         # ADD VARIABLES OUTCOME AND FUP
         outcome = case_when(
           # Case 1: patients receive treatment within 5 days (scenarios A to E)
           # --> they are still alive and followed up until treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ "0" %>% 
             factor(levels = c("0", "1")),
           # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
           # [either no treatment or treatment after five days]
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" |
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ status_primary_simple,
           ),
         fup = case_when(
           # Case 1: patients receive treatment within 5 days (scenarios A to E)
           # --> they are still alive and followed up until treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
           # [either no treatment or treatment after five days]
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" |
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ fu_primary,
           ),
         # ADD VARIABLES CENSORING AND FUP_UNCENSORED
         censoring = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> they are censored in the control group at time of treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ "1" %>% factor(levels = c("0", "1")),
           # Case 2: Patients die or are lost to follow-up within 5 days 
           # addition by LN: and are not treated within 5 days (scenarios K and L)
           # --> we keep their follow-up time but they are uncensored
           (any_treatment_strategy_cat == "Untreated" & 
             tb_postest_treat <= 4 &
              fu_primary <= 4) ~ "0" %>% factor(levels = c("0", "1")),
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered uncensored and their follow-up time is 
           #     5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_primary > 4) |
             (any_treatment_strategy_cat != "Untreated" &
             # NB if people treated > 4 days, fu_primary is > 4 days
             tb_postest_treat > 4) ~ "0" %>% factor(levels = c("0", "1")),
           ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> they are censored in the control group at time of treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days 
           # addition by LN: without being treated (scenarios K and L)
           # --> we keep their follow-up time but they are uncensored
           (any_treatment_strategy_cat == "Untreated" & 
              tb_postest_treat <= 4 &
              fu_primary <= 4) ~ fu_primary,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered uncensored and their follow-up time is 
           #     5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary > 4) |
             (any_treatment_strategy_cat == "Treated" &
                # NB if people treated > 4 days, fu_primary is > 4 days
                tb_postest_treat > 4) ~ 5,
           ),
         )
###################################################
# ARM TREATMENT: treatment within 5 days
###################################################
data_trt <- 
  data %>%
  mutate(arm = "Treatment",
         # ADD VARIABLES OUTCOME AND FUP
         outcome = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ status_primary_simple,
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" &
             fu_primary <= 4 ~ status_primary_simple,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M)
           # --> they don't experience an event and their follow-up time is 5 
           #     days
           (any_treatment_strategy_cat == "Untreated" &
             fu_primary > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ "0" %>% 
             factor(levels = c("0", "1", "2")),
         ),
         fup = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ fu_primary,
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" &
             fu_primary <= 4 ~ fu_primary,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M)
           # --> they don't experience an event and their follow-up time is 5 
           #     days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ 5,
         ),
         # ADD VARIALBES CENSORING AND FUP_UNCENSORED
         censoring = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           #     censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ "0" %>% 
             factor(levels = c("0", "1")),
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_primary <= 4 ~ "0" %>%
             factor(levels = c("0", "1")),
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_primary > 4) | 
             (any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat > 4) ~ "1" %>% 
             factor(levels = c("0", "1")),
         ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           #     censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_primary <= 4 ~ fu_primary,
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary > 4) | 
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ 5,
         ),
  )
###################################################
# CREATION OF THE FINAL DATASET FOR THE ANALYSIS
###################################################
data_cloned <-
  rbind(data_control,
        data_trt)

################################################################################
# STEP 2-SPLITTING THE DATASET AT EACH TIME OF EVENT
################################################################################
# Dataframe 'times' containing the time of events and an ID for the times of 
# events
t_events <- sort(unique(data_cohort$fup))

data_outcome <- 
  data_cloned %>%
  mutate(t_start = 0) %>%
  survSplit(cut = t_events,
            end = "fup",
            start = "t_start",
            event = "outcome") %>%
  mutate(outcome = case_when(
    outcome == "censor" ~ "0",
    TRUE ~ "1",
    ) %>% factor(levels = c("0", "1"))
  )
# LN QU: Don't get why we're using fup and not fup_censoring?????
# fup_censoring is not used in the script...? --> seems odd
data_cnsr <-
  data_cloned %>%
  mutate(t_start = 0) %>%
  survSplit(cut = t_events,
            end = "fup",
            start = "t_start",
            event = "censoring") %>%
  mutate(censoring = case_when(
    censoring == "censor" ~ "0",
    TRUE ~ "1",
  ) %>% factor(levels = c("0", "1"))
  )
  
data_final <-
  data_outcome %>%
  left_join(data_cnsr,
            by = c("arm", "patient_id", "fup", "t_start")) %>%
  select(-c("outcome.y", "censoring.x")) %>%
  rename(outcome = outcome.x,
         censoring = censoring.y,
         t_end = fup)

# TO DO:
# - Model weights for censoring (if needed?)
# - Outcome model
# - Variance estimation (---> bootstrap?)