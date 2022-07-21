######################################

# Cox models (propensity score analysis)
######################################

## Import libraries
library(tidyverse)
library(lubridate)
library(survival)
library(survminer)
library(gridExtra)
library(splines)
library(survey)
library(here)

## Set seed
set.seed(28)

## Load functions
source(here("lib", "functions", "safely_n_quietly.R"))

## Create figures directory
fs::dir_create(here::here("output", "figs"))
## Create tables directory
fs::dir_create(here::here("output", "tables"))
## Create data_models directory (where ps models are saved)
fs::dir_create(here::here("output", "data_models"))

## Import command-line arguments
args <- commandArgs(trailingOnly=TRUE)

## Set input and output pathways for matched/unmatched data - default is unmatched
if (length(args) == 0){
  data_label = "day0"
} else if (args[[1]] == "day0") {
  data_label = "day0"
} else if (args[[1]] == "day5") {
  data_label = "day5"
} else {
  # Print error if no argument specified
  stop("No outcome specified")
}

## Import data
if (data_label == "day5") {
  data_cohort <- 
    read_rds(here::here("output", "data", "data_processed_day5.rds"))
} else if (data_label == "day0") {
  data_cohort <-
    read_rds(here::here("output", "data", "data_processed_day0.rds"))
}


# create data.frame 'estimates' where output is saved 
# 'estimates' has 7 columns with the imputation number and logHR and SE of logHR and 
# n for the number of pt in utilised dataset and how many people assigned 'treated' and how many people assigned 'untreated
# primary outcome x 3 (mol + sot vs none; sot vs none; mol vs none) plus
# secondary outcome x 3 
# iterations x 20
estimates <- matrix(nrow = 180, ncol = 8) %>% as.data.frame()
# give column names
colnames(estimates) <- 
  c("comparison", "outcome", "imputation", "logHR", "Var", "n_after_restriction", "n_assign_trt", "n_assign_untrt")
#c("comparison", "outcome", "HR", "LowerCI", "UpperCI", "n")
# create data.frame 'log' where errors and warnings are saved
# 'log' has 3 columns: comparison, warning and error
# 'log' has 120 rows like 'estimates'
log <- matrix(nrow = 180, ncol = 5) %>% as.data.frame()
# give column names
colnames(log) <- 
  c("comparison", "outcome","imputation", "warning", "error")

# Specify treated group for comparison (Treated vs Untreated)
# used to loop trough different analyses
trt_grp <- c("All", "Sotrovimab", "Molnupiravir")
# Specify outcomes
# uesd to loop through different analyses
outcomes <- c("primary", "secondary")

# Specify number of PS imputations
imputations <- seq(1, 20, by = 1)
imputations_total <- 20

# Keep track of matrix line
mat_line = 0

## Loop over analysis for each treatment comparison 
for(i in seq_along(trt_grp)) {
  if (mat_line > 0) {
    mat_line = mat_line + 1 
  }
  # used later in 'esimates' data.frame to save which analysis is done
  t <- trt_grp[i]
  
  # Select data used analysis ---
  # Subset cohort to those who survive until day 5 to be used for PS estimation
  data_ps <-
    data_cohort %>% 
    filter(fu_secondary > 4)
  
  # (mol/sot are excluded in single comparison analyses)
  if (i == 1) {
    print("All Treated versus Untreated Comparison")
    data_ps_sub <- 
      data_ps 
    
    data_cohort_sub <- data_cohort
   # estimates[c(1, 4), "n"] <- (nrow(data_cohort_sub))
  } else {
    print(paste0(trt_grp[i], " versus Untreated Comparison"))
    # Drop patients treated with molnupiravir or sotrovimab
    data_ps_sub <- 
      data_ps %>% 
      filter(treatment_strategy_cat != trt_grp[i])
    
    data_cohort_sub <- 
      data_cohort %>% 
      filter(treatment_strategy_cat != trt_grp[i])
   
  }

  # Fit Propensity Score Model ---
  # Vector of variables for PS model
  # Note: age modelled with cubic spline with 3 knots
  vars <-
    c(
      "ns(age, df=3)",
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
      "solid_organ_transplant_nhsd",
      "hiv_aids_nhsd" ,
      "immunosupression_nhsd" ,
      "imid_nhsd" ,
      "liver_disease_nhsd",
      "ckd_stage_5_nhsd",
      "haematological_disease_nhsd" ,
      "cancer_opensafely_snomed" ,
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
      "moderna_most_recent_cov_vac"
    )
  # Specify model
  psModelFunction <- as.formula(
    paste("treatment", 
          paste(vars, collapse = " + "), 
          sep = " ~ "))
  # Check your model
  print(psModelFunction)
  # Fit PS model on data_ps_sub
  psModel <- glm(psModelFunction,
                 family = binomial(link = "logit"),
                 data = data_ps_sub)
  
  summary(psModel) %>% coefficients()
  
  # Append patient-level predicted probability of being assigned to cohort
  # Predict PS for members of Day 0 cohort from model fitted to those who survived to Day 5
  data_cohort_sub$pscore <- predict(psModel, type = "response", newdata = data_cohort_sub)
  
  # Loop over imputations
  for(m in seq_along(imputations)) {
  
  mat_line = mat_line + 1 
  m <- imputations[m]
  # Generate random probability from uniform distribution
  data_cohort_sub$rand <- runif(nrow(data_cohort_sub), 0, 1)
  
  # Reassign new data_cohort_sub dataset each loop
  data_cohort_sub2 <- data_cohort_sub
  
  # For 'untreated' patients at time of outcome, assign:
  # 'Treated' if pscore > rand 
  # 'Untreated' if otherwise
  
  # Identify imputed patients
  patients_imputed <- data_cohort_sub2 %>% 
    filter(treatment == "Untreated" & fu_secondary <=4)
  
  cat("#### Patients with imputed treatment ####\n")
  print(dim(patients_imputed))
  
  # Impute "Treated" if pscore > rand
  data_cohort_sub2 <- data_cohort_sub2 %>% 
    mutate(treatment2 = case_when(
      (treatment == "Treated") | 
        (treatment == "Untreated" & fu_secondary <=4 &
           pscore > rand)  ~ "Treated",
      TRUE ~ "Untreated"
    ) %>% factor(levels = c("Untreated", "Treated")))
    
  # Identify how many patients are assigned to each treatment group
   trt_count <- data_cohort_sub2 %>% 
     arrange(treatment) %>% 
     count(treatment, treatment2)
    
   estimates[mat_line, "n_assign_trt"] <- (trt_count[2,3])
   estimates[mat_line, "n_assign_untrt"] <- (nrow(patients_imputed) - trt_count[2,3])
   
   # Derive inverse probability of treatment weights (IPTW)
   data_cohort_sub2$weights <-
     ifelse(data_cohort_sub2$treatment2 == "Treated",
            1 / data_cohort_sub$pscore,
            1 / (1 - data_cohort_sub$pscore))
   
  # Check overlap
  # Identify lowest and highest propensity score in each group
  
  ps_trim <- data_cohort_sub2 %>% 
    select(treatment2, pscore) %>% 
    group_by(treatment2) %>% 
    summarise(min = min(pscore), max= max(pscore)) %>% 
    ungroup() %>% 
    summarise(min = max(min), max = min(max)) # see below for why max of min and min of max is taken
  
  # Restricted to observations within a PS range common to both treated and untreated persons—
  # (i.e. exclude all patients in the nonoverlapping parts of the PS distribution)
  
  #cat("#### Patients before restriction ####\n")
  #print(dim(data_cohort_sub2))  
  
  data_cohort_sub2 <- data_cohort_sub2 %>% 
    filter(pscore >= ps_trim$min[1] & pscore <= ps_trim$max[1])
  
  #cat("#### Patients after restriction ####\n")
  #print(dim(data_cohort_sub2))  
  
  estimates[mat_line, "n_after_restriction"] <- (nrow(data_cohort_sub2))
  
  # Fit outcome model ---
  ## Define svy design for IPTW 
  iptw <- svydesign(ids = ~ 1, data = data_cohort_sub2, weights = ~ weights)
  for (j in seq_along(outcomes)){
    mat_line = mat_line + 1 
    outcome_event <- outcomes[j]
    print(outcome_event)
    # because we need to know where in 'estimates' and 'log' output should be
    # saved
    estimates[mat_line - 1, "comparison"] <- t
    estimates[mat_line - 1, "outcome"] <- outcome_event
    log[mat_line, "comparison"] <- t
    log[mat_line, "outcome"] <- outcome_event
    # create formula for primary and secondary analysis
    if (outcome_event == "primary"){
      formula <- 
        as.formula(
          Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
            treatment2)
    } else if (outcome_event == "secondary"){
      formula <- 
        as.formula(
          Surv(fu_secondary, status_secondary == "allcause_hosp_death") ~ 
            treatment2)
    }
    # Cox regression
    # returns function model_PSw() with components result, output, messages, 
    # warnings and error
    model_PSw <- 
      safely_n_quietly(
        .f = ~ svycoxph(formula, 
                        design = iptw, 
                        data = data_cohort_sub2)
      )
    # save results from model_PSw and save warnings or errors to log file
    if (is.null(model_PSw()$error)){
      # no error
      log[mat_line,"error"] <- NA_character_
      if (length(model_PSw()$warnings) != 0){
        # save warning in log
        log[mat_line, "warning"] <- paste(model_PSw()$warnings, collapse = '; ')
      } else log[mat_line, "warning"] <- NA_character_
      
      # select main effects from 'model_PSw'
      selection <- 
        model_PSw()$result$coefficients %>% names %>% startsWith("treatment2")
      
      # save coefficients of model and CIs in estimates
      estimates[mat_line, "logHR"] <- model_PSw()$result$coefficients[selection] 
      estimates[mat_line, c("Var")] <- 
       model_PSw()$result$var[selection] # Gives the robust variance
      
      
      } else log[mat_line, "error"] <- model_PSw()$messages
   }
  }
}

## Rubin's Rules

# Point estimate mean & within imputation variance
rubins_rules <- estimates %>% 
  group_by(comparison, outcome) %>% 
  summarise(mean = mean(logHR), var_w = mean(Var)) %>% 
  ungroup()

# Between imputation variance 
var_b <- estimates %>% 
  left_join(select(rubins_rules, mean, comparison, outcome)) %>% 
  mutate(diff = (logHR - mean)^2) %>% 
  group_by(comparison, outcome) %>% 
  summarise(sum_diff = sum(diff)) %>% 
  mutate(var_b = sum_diff/(imputations_total-1)) %>% 
  ungroup() %>% 
  select(-c(sum_diff))
  
# Rubins rules + construct CI
rubins_rules <- rubins_rules %>% 
  left_join(var_b) %>% 
  mutate(
    total_var = var_w + var_b + (var_b/imputations_total), 
    se_pooled = sqrt(total_var),
    lci = mean - (1.96*se_pooled) %>% exp(),
    uci = mean + (1.96*se_pooled) %>% exp(),
    hr = exp(mean)
  ) %>% 
  select(comparison, outcome, hr, lci, uci) 


## Save output
write_csv(rubins_rules,
          here("output", 
               "tables", 
               paste0("cox_models_", data_label, ".csv")))

write_rds(rubins_rules, 
          here("output", 
               "tables", 
               paste0("cox_models_", data_label, ".rds")))

write_csv(estimates,
          here("output", 
               "tables", 
               paste0("estimates_", data_label, ".csv")))
write_csv(log,
          here("output", 
               "tables", 
               paste0("log_cox_models_", data_label, ".csv")))

