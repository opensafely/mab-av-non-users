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
data_processed <-
  read_rds(here::here("output", "data", data_filename))

########################################################################
# STEP 1-CLONING: CREATION OF OUTCOME AND FOLLOW-UP TIME IN EACH ARM
########################################################################
# ARM CONTROL: no treatment within 5 days
data_processed_control <- 
  data_processed %>%
  mutate(arm = "Control",
         # ADD VARIABLES OUTCOME AND FUP
         outcome = case_when(
           # Case 1: patients receive treatment within 5 days (scenarios A to E)
           # --> they are still alive and followed up until treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ "0",
           # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
           # [either no treatment or treatment after five days]
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" |
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ status_all %>% as.character(),
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
                tb_postest_treat > 4) ~ fu_all
           ),
         # ADD VARIALBES CENSORING AND FUP_UNCENSORED
         censoring = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> they are censored in the control group at time of treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ "1",
           # Case 2: Patients die or are lost to follow-up within 5 days 
           # add LN: and are not treated within 5 days (scenarios K and L)
           # --> we keep their follow-up time but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
              fu_all <= 4 ~ "0",
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (patients F-J and M): 
           # --> they are considered uncensored and their follow-up time is 
           #     5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_all > 4) |
             (any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat > 4) ~ "0",
           ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> they are censored in the control group at time of treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days 
           # add LN: and are not treated within 5 days (scenarios K and L)
           # --> we keep their follow-up time but they are uncensored
           fu_all <= 4 ~ fu_all,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (patients F-J and M): 
           # --> they are considered uncensored and their follow-up time is 
           #     5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_all > 4) |
             (any_treatment_strategy_cat == "Treated" &
                tb_postest_treat > 4) ~ 5,
           ),
         )
# ARM TREATMENT: treatment within 5 days
data_processed_treatment <- 
  data_processed %>%
  mutate(arm = "Treatment",
         # ADD VARIABLES OUTCOME AND FUP
         outcome = case_when(
           # Case 1: Patients receive treatment within 5 days 
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ status_all %>% as.character(),
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated 
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" &
             fu_all <= 4 ~ status_all %>% as.character(),
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days  
           # --> they are considered alive and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_all > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ "0"
         ),
         fup = case_when(
           # Case 1: Patients receive treatment within 5 days 
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ fu_all,
           # Case 2: Patients die or are lost to follow-up before 6 months
           # without being treated 
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" &
             fu_all <= 4 ~ fu_all,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still at risk at 5 days  
           # --> they are considered alive and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_all > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ 5
         ),
         # ADD VARIALBES CENSORING AND FUP_UNCENSORED
         censoring = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           # censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ "0",
           # Case 2: Patients die or are lost to follow-up within 5 days (scenarii K and L): 
           # and untreated???? LN
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_all <= 4 ~ "0",
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarii F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           any_treatment_strategy_cat == "Untreated" | 
             (any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat > 4) ~ "1"
         ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           # censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days (scenarii K and L): 
           # and untreated???? LN
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_all <= 4 ~ fu_all,
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarii F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           any_treatment_strategy_cat == "Untreated" | 
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ 5,
         ),
  )

###################################################
# CREATION OF THE FINAL DATASET FOR THE ANALYSIS
###################################################
data_cohort <-
  rbind(data_processed_control,
        data_processed_treatment)

####################################################
# STEP 2-SPLITTING THE DATASET AT EACH TIME OF EVENT
####################################################


#Dataframe containing the time of events and an ID for the times of events
t_events <- sort(unique(data_cohort$fup))
times <- data.frame("t_event" = t_events, "ID_t" = seq(1:length(t_events)))




