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
        data_trt) %>% 
  mutate(t_start = 0)

################################################################################
# STEP 2-SPLITTING THE DATASET AT EACH TIME OF EVENT
################################################################################
# Dataframe 'times' containing the time of events and an ID for the times of 
# events
t_events <- sort(unique(data_cloned$fup))

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

#Dataframe containing the time of events and an ID for the times of events
t_events<-sort(unique(tab$fup))
times<-data.frame("tevent"=t_events,"ID_t"=seq(1:length(t_events)))


####################################
# ArRM "Surgery" FIRST
####################################


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


############################################
#STEP 3- ESTIMATING THE CENSORING WEIGHTS
############################################

#######################################################################################################################
# Arm "Surgery" first

data.long<-data_final[data_final$arm=="Surgery",]

###########################
# STEP 1: censoring model
###########################
# Create vector of variables for censoring model
# Note: age and study_week modelled flexibly with cubic spline with 3 knots
if (adjustment_set == "full"){
  vars <-
    c("ns(age, df=3)",
      "ns(study_week, df=3)",
      "sex",
      "ethnicity",
      "imdQ5" ,
      "stp",
      "rural_urban",
      "huntingtons_disease_nhsd" ,
      "myasthenia_gravis_nhsd" ,
      "motor_neurone_disease_nhsd" ,
      "multiple_sclerosis_nhsd"  ,
      "solid_organ_transplant_new",
      "hiv_aids_nhsd" ,
      "immunosupression_new" ,
      "imid_nhsd" ,
      "liver_disease_nhsd",
      "ckd_stage_5_nhsd",
      "haematological_disease_nhsd",
      "non_haem_cancer_new",
      "downs_syndrome_nhsd",
      "diabetes",
      "bmi_group",
      "smoking_status",
      "copd",
      "dialysis",
      "cancer",
      "lung_cancer",
      "haem_cancer",
      "vaccination_status",
      "pfizer_most_recent_cov_vac",
      "az_most_recent_cov_vac",
      "moderna_most_recent_cov_vac")
} else if (adjustment_set == "agesex") {
  vars <-
    c("ns(age, df=3)",
      "sex")
}

# Specify model
censorModelFunction <- as.formula(
  paste("Surv(Tstart, Tstop, censoring)", 
        paste(vars, collapse = " + "), 
        sep = " ~ "))


#Cox model
ms_cens<-coxph(censorModelFunction, 
               ties="efron", 
               data=data.long)


###########################################################
# Estimating the probability of remaining uncensored
###########################################################

#Design matrix
design_mat<-as.matrix(data.long[,c("ns(age, df=3)",
                                   "ns(study_week, df=3)",
                                   "sex",
                                   "ethnicity",
                                   "imdQ5" ,
                                   "stp",
                                   "rural_urban",
                                   "huntingtons_disease_nhsd" ,
                                   "myasthenia_gravis_nhsd" ,
                                   "motor_neurone_disease_nhsd" ,
                                   "multiple_sclerosis_nhsd"  ,
                                   "solid_organ_transplant_new",
                                   "hiv_aids_nhsd" ,
                                   "immunosupression_new" ,
                                   "imid_nhsd" ,
                                   "liver_disease_nhsd",
                                   "ckd_stage_5_nhsd",
                                   "haematological_disease_nhsd",
                                   "non_haem_cancer_new",
                                   "downs_syndrome_nhsd",
                                   "diabetes",
                                   "bmi_group",
                                   "smoking_status",
                                   "copd",
                                   "dialysis",
                                   "cancer",
                                   "lung_cancer",
                                   "haem_cancer",
                                   "vaccination_status",
                                   "pfizer_most_recent_cov_vac",
                                   "az_most_recent_cov_vac",
                                   "moderna_most_recent_cov_vac")])

# Need to check if study_week is defined sensibly and if this should be adjusted for

#Vector of regression coefficients
beta<-coef(ms_cens)

#Calculation of XB (linear combineation of the covariates)
data.long$lin_pred<-design_mat%*%beta

#Estimating the cumulative hazard (when covariates=0)
dat.base<-data.frame(basehaz(ms_cens,centered=F))
names(dat.base)<-c("hazard","t")
dat.base<-unique(merge(dat.base,times,by.x="t",by.y="tevent",all.x=T))


#Merging and reordering the dataset
data.long<-merge(data.long,dat.base,by="ID_t",all.x=T)
data.long<-data.long[order(data.long$id,data.long$fup),]
data.long$hazard<-ifelse(is.na(data.long$hazard),0,data.long$hazard)


#Estimating the probability of remaining uncensored at each time of event
data.long$P_uncens<-exp(-(data.long$hazard)*exp(data.long$lin_pred))  


#############################
# Computing IPC weights
#############################

#Weights are the inverse of the probability of remaining uncensored
data.long$weight_Cox<-1/data.long$P_uncens
####################################################################################################################

####################################
# Arm "No Surgery" now

data.long2<-data_final[data_final$arm=="Control",]

###########################
# STEP 1: censoring model
###########################


#Cox model
ms_cens2<-coxph(censorModelFunction, 
                ties="efron", 
                data=data.long2)

summary(ms_cens2)

###########################################################
# STEP 2: estimate the probability of remaining uncensored
###########################################################

#Design matrix
design_mat2<-as.matrix(data.long2[,c("ns(age, df=3)",
                                     "ns(study_week, df=3)",
                                     "sex",
                                     "ethnicity",
                                     "imdQ5" ,
                                     "stp",
                                     "rural_urban",
                                     "huntingtons_disease_nhsd" ,
                                     "myasthenia_gravis_nhsd" ,
                                     "motor_neurone_disease_nhsd" ,
                                     "multiple_sclerosis_nhsd"  ,
                                     "solid_organ_transplant_new",
                                     "hiv_aids_nhsd" ,
                                     "immunosupression_new" ,
                                     "imid_nhsd" ,
                                     "liver_disease_nhsd",
                                     "ckd_stage_5_nhsd",
                                     "haematological_disease_nhsd",
                                     "non_haem_cancer_new",
                                     "downs_syndrome_nhsd",
                                     "diabetes",
                                     "bmi_group",
                                     "smoking_status",
                                     "copd",
                                     "dialysis",
                                     "cancer",
                                     "lung_cancer",
                                     "haem_cancer",
                                     "vaccination_status",
                                     "pfizer_most_recent_cov_vac",
                                     "az_most_recent_cov_vac",
                                     "moderna_most_recent_cov_vac")])
#Vector of regression coefficients
beta2<-coef(ms_cens2)

#Calculation of XB (linear combineation of the covariates)
data.long2$lin_pred<-design_mat2%*%beta2

#Estimating the cumulative hazard (when covariates=0)
dat.base2<-data.frame(basehaz(ms_cens2,centered=F))
names(dat.base2)<-c("hazard","t")


dat.base2<-unique(merge(dat.base2,times,by.x="t",by.y="tevent",all.x=T))

#Merging and reordering the dataset
data.long2<-merge(data.long2,dat.base2,by="ID_t",all.x=T)
data.long2<-data.long2[order(data.long2$id,data.long2$fup),]
data.long2$hazard<-ifelse(is.na(data.long2$hazard),0,data.long2$hazard)


#Estimating the probability of remaining uncensored at each time of event
data.long2$P_uncens<-exp(-(data.long2$hazard)*exp(data.long2$lin_pred))



#############################
# Computing the IPC weights
#############################

#Weights are the inverse of the probability of remaining uncensored
data.long2$weight_Cox<-1/data.long2$P_uncens
data.long2$weight_Cox[data.long2$ID_t==0]<-1

data.long.Cox<-rbind(data.long,data.long2)


##################################################
# Emulated trial with Cox weights (Cox model)
##################################################

Cox_w <- coxph(Surv(Tstart,Tstop, outcome) ~ arm,
               data=data.long.Cox, weights=weight_Cox) # Since weights are specified robust variance computed

summary(Cox_w)
HR<-exp(Cox_w$coefficients) #Hazard ratio
HR


# To do:
# Check censoring step 
# Check deriviation of datasets for weights calculation
# Update the weights and analysis code upadting variable/dataset names to ours
# Write code for picking up coefficients and writing to file

