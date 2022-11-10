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

################################################################################
# 0.4 Prepare data
################################################################################
# This step simplifies the variable 'status_primary_simple'
# --> no distinction is made between censored because dereg or because
#     noncovid_death occurred
# --> levels are 0 (no event/censored); 1 (covid hosp/death) and 2 (censored)
# FIX ME:
# - Should we treat non covid death as a competing risk? (..somehow) 
#   (= informative censoring)
# - Should we censor for non covid hosp? --> currently ignored
data_processed <-
  data_processed %>%
  mutate(
    status_primary_simple = case_when(
      status_primary %in% c("dereg", "noncovid_death") ~ "2",
      status_primary == "covid_hosp_death" ~ "1",
      status_primary == "none" ~ "0",
      TRUE ~ status_primary %>% as.character(),
      ) %>% factor(levels = c("0", "1", "2")),
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
data_processed_control <- 
  data_processed %>%
  mutate(arm = "Control",
         # ADD VARIABLES OUTCOME AND FUP
         outcome = case_when(
           # Case 1: patients receive treatment within 5 days (scenarios A to E)
           # --> they are still alive and followed up until treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ "0" %>% 
             factor(levels = c("0", "1", "2")),
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
             tb_postest_treat > 4 & 
               # FIX ME: could people receive treatment after our outcome/censored?
               fu_primary > 4) ~ "0" %>% factor(levels = c("0", "1")),
           ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> they are censored in the control group at time of treatment
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days 
           # addition by LN: without being treated (scenarios K and L)
           # --> we keep their follow-up time but they are uncensored
           treatment_strategy_cat == "Untreated" &
             fu_primary <= 4 ~ fu_primary,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered uncensored and their follow-up time is 
           #     5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary > 4) |
             (any_treatment_strategy_cat == "Treated" &
                tb_postest_treat > 4 &
                # FIX ME: could people receive treatment after our outcome/censored?
                fu_primary > 4) ~ 5,
           ),
         )
###################################################
# ARM TREATMENT: treatment within 5 days
###################################################
data_processed_treatment <- 
  data_processed %>%
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
             fu_all <= 4 ~ status_primary_simple,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M)
           # --> they are considered alive and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_all > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ "none" %>% 
             factor(levels = c("none", "censored", "covid_hosp_death")),
         ),
         fup = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat <= 4 ~ fu_primary_simple,
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their observed outcomes and follow-up times
           any_treatment_strategy_cat == "Untreated" &
             fu_primary_simple <= 4 ~ fu_primary_simple,
           # Case 3: Patients do not receive treatment within 5 days
           # and are still alive or at risk at 5 days (scenarios F-J and M)
           # --> they are considered alive and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary_simple > 4) |
             (any_treatment_strategy_cat != "Untreated" & 
                tb_postest_treat > 4) ~ 5,
         ),
         # ADD VARIALBES CENSORING AND FUP_UNCENSORED
         censoring = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           # censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ "0",
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_all <= 4 ~ "0",
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
             fu_primary_simple > 4) | 
             (any_treatment_strategy_cat != "Untreated" &
             tb_postest_treat > 4) ~ "1"
         ),
         fup_uncensored = case_when(
           # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
           # --> they are uncensored in the treatment arm and remain at risk of 
           # censoring until time of treatment
           any_treatment_strategy_cat != "Untreated" & 
             tb_postest_treat <= 4 ~ tb_postest_treat,
           # Case 2: Patients die or are lost to follow-up within 5 days
           # without being treated (scenarios K and L)
           # --> we keep their follow-up times but they are uncensored
           any_treatment_strategy_cat == "Untreated" & 
             fu_all <= 4 ~ fu_all,
           # Case 3: Patients do not receive treatment within 5 days and are 
           # still alive or at risk at 5 days (scenarios F-J and M): 
           # --> they are considered censored and their follow-up time is 5 days
           (any_treatment_strategy_cat == "Untreated" &
              fu_primary_simple > 4) | 
             (any_treatment_strategy_cat != "Untreated" &
                tb_postest_treat > 4) ~ 5,
         ),
  )
data_processed_treatment %>% select(outcome) %>% table()
###################################################
# CREATION OF THE FINAL DATASET FOR THE ANALYSIS
###################################################
data_cohort <-
  rbind(data_processed_control,
        data_processed_treatment)

################################################################################
# STEP 2-SPLITTING THE DATASET AT EACH TIME OF EVENT
################################################################################
# Dataframe 'times' containing the time of events and an ID for the times of 
# events
t_events <- sort(unique(data_cohort$fup))
times <- data.frame("t_event" = t_events, "ID_t" = seq(1:length(t_events)))

data_processed_treatment <- 
  data_processed_treatment %>%
  mutate(Tstart = 0)
data_processed_treatment_long <-
  data_processed_treatment %>%
  survSplit(cut = t_events,
            end = "fup",
            start = "Tstart",
            event = "outcome",
            id = patient_id)


tab_s<-tab[tab$arm=="Surgery",]

#Creation of the entry variable (Tstart, 0 for everyone)
tab_s$Tstart<-0

#Splitting the dataset at each time of event until the event happens and sorting it
data.long<-survSplit(tab_s, cut=t_events, end="fup", 
                     start="Tstart", event="outcome",id="ID") 
data.long<-data.long[order(data.long$ID,data.long$fup),] 

#Splitting the original dataset at each time of event and sorting it
#until censoring happens. This is to have the censoring status at each time of event 
data.long.cens<-survSplit(tab_s, cut=t_events, end="fup", 
                          start="Tstart", event="censoring",id="ID") 
data.long.cens<-data.long.cens[order(data.long.cens$ID,data.long.cens$fup),] 

#Replacing the censoring variable in data.long by the censoring variable obtained
# in the second split dataset
data.long$censoring<-data.long.cens$censoring

#Creating Tstop (end of the interval) 
data.long$Tstop<-data.long$fup

#Merge and sort
data.long<-merge(data.long,times,by.x="Tstart",by.y="tevent",all.x=T)
data.long<-data.long[order(data.long$ID,data.long$fup),] 
data.long$ID_t[is.na(data.long$ID_t)]<-0



####################################
# ARM "No Surgery" NOW
###################################
tab_c<-tab[tab$arm=="Control",]

#Creation of the entry variable (Tstart, 0 for everyone)
tab_c$Tstart<-0


#Splitting the dataset first at each time of event
#until the event happens 
data.long2<-survSplit(tab_c, cut=t_events, end="fup", 
                      start="Tstart", event="outcome",id="ID") 
data.long2<-data.long2[order(data.long2$ID,data.long2$fup),] 

#Splitting the original dataset at each time of event
#until censoring happens 
data.long.cens2<-survSplit(tab_c, cut=t_events, end="fup", 
                           start="Tstart", event="censoring",id="ID") 
data.long.cens2<-data.long.cens2[order(data.long.cens2$ID,data.long.cens2$fup),] 


#Replacing the censoring variable in data.long by the censoring variable obtained
# in the second split dataset
data.long2$censoring<-data.long.cens2$censoring

#Creating Tstop (end of the interval)
data.long2$Tstop<-data.long2$fup

#Merge and sort
data.long2<-merge(data.long2,times,by.x="Tstart",by.y="tevent",all.x=T)
data.long2<-data.long2[order(data.long2$ID,data.long2$fup),] 
data.long2$ID_t[is.na(data.long2$ID_t)]<-0

#Final dataset
data<-rbind(data.long,data.long2)
data_final<-merge(data,times,by="ID_t",all.x=T)
data_final<-data_final[order(data_final$ID,data_final$fup),]



