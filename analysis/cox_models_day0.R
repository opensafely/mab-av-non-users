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

## Load functions
source(here("lib", "functions", "safely_n_quietly.R"))
## Create tables directory
fs::dir_create(here::here("output", "tables"))
## Load data
data_cohort <-
    read_rds(here::here("output", "data", "data_processed_day0.rds"))
## Specify number of PS imputations
imputations_total <- 20
seeds <- runif(imputations_total * 3, min = 0, max = 1e6) %>% floor()

# create data.frame 'estimates' where output is saved 
# 'estimates' has 9 columns with the imputation number and logHR and var of logHR and 
# n for the number of pt in utilised dataset and how many people assigned 'treated' and 
# how many people assigned 'untreated'
# primary outcome x 3 (mol + sot vs none; sot vs none; mol vs none) plus
# secondary outcome x 3 
# --> number of rows is iterations x imputations_total
estimates <- matrix(nrow = 6 * imputations_total, ncol = 9) %>% as.data.frame()
# give column names
colnames(estimates) <- 
  c("comparison", "outcome", "imputation", 
    "logHR", "var", 
    "n_after_restriction", "n_assign_trt", "n_assign_untrt",
    "seed")
# create data.frame 'log' where errors and warnings are saved
# 'log' has 3 columns: comparison, warning and error
# 'log' has number of rows identical to 'estimates'
log <- matrix(nrow = 6 * imputations_total, ncol = 5) %>% as.data.frame()
# give column names
colnames(log) <- 
  c("comparison", "outcome","imputation", "warning", "error")

# Specify treated group for comparison (Treated vs Untreated)
# used to loop trough different analyses
trt_grp <- c("All", "Sotrovimab", "Molnupiravir")
# Specify outcomes
# uesd to loop through different analyses
outcomes <- c("primary", "secondary")
# Specify PS model
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

## Loop over analysis for each treatment comparison 
for(i in seq_along(trt_grp)) {
  # used later in 'estimates' data.frame to save which analysis is done
  t <- trt_grp[i]
  
  # Select data used analysis ---
  # Create data_cohort_sub (data.frame used for the day 0 analysis)
  if (t == "All") {
    cat("\n#### All Treated versus Untreated Comparison ####\n")
    data_cohort_sub <- data_cohort
  } else {  # (mol/sot are excluded in single comparison analyses)
    cat(paste0("\n#### ", t, " versus Untreated Comparison ####\n"))
    # Drop patients treated with molnupiravir or sotrovimab
    data_cohort_sub <- 
      data_cohort %>% 
      filter(treatment_strategy_cat != t)
  }
  # Create data_ps_sub (data.frame used to fit propensity score model on)
  # --> ps model is fitted in day 5 cohort
  # Subset cohort to those who survive until day 5 to be used for PS estimation
  data_ps_sub <-
    data_cohort_sub %>% 
    filter(fu_secondary > 4)

  # Fit Propensity Score Model ---
  # Fit PS model on data_ps_sub
  psModel <- glm(psModelFunction,
                 family = binomial(link = "logit"),
                 data = data_ps_sub)
  summary(psModel) %>% coefficients()
  
  # Add PS to day 0 cohort ---
  # Identify patients for who treatment will be imputed
  # (identical across all data_cohort_sub as number of untreated people is not
  # changing)
  patients_imputed <- 
    data_cohort_sub %>% 
    filter(treatment == "Untreated" & fu_secondary <= 4)
  cat("#### No. of patients for who treatment will be imputed ####\n")
  print(nrow(patients_imputed))
  # Append patient-level predicted probability of being assigned to cohort
  # Predict PS for members of Day 0 cohort from model fitted to those who survived to Day 5
  data_cohort_sub$pscore <- 
    predict(psModel, type = "response", newdata = data_cohort_sub)
  
  # Impute treatment ---
  # For 'untreated' patients at time of outcome, assign:
  # 'Treated' if pscore > rand 
  # 'Untreated' if otherwise
  for(m in 1:imputations_total) {
    cat(paste0("#### Imputation ", m, " ####\n"))
    # Reassign new data_cohort_sub dataset each imputation loop
    data_cohort_sub_imp <- data_cohort_sub
    # identify location in data.frame 'estimates' and 'log' where
    # output is saved
    index <- m + (i - 1) * imputations_total
    # Generate random probability from uniform distribution
    set.seed(seeds[index])
    data_cohort_sub_imp$rand <- runif(nrow(data_cohort_sub), 0, 1)
    estimates[c(index, index + 3 * imputations_total), "seed"] <- seeds[index]
    log[c(index, index + 3 * imputations_total), "seed"] <- seeds[index]
    # Impute "Treated" if pscore > rand
    data_cohort_sub_imp <- 
      data_cohort_sub_imp %>% 
      mutate(treatment2 = case_when(
        (treatment == "Treated") | 
          (treatment == "Untreated" & fu_secondary <= 4 &
             pscore > rand)  ~ "Treated",
        TRUE ~ "Untreated") %>% factor(levels = c("Untreated", "Treated")))
    # Identify how many patients are assigned to each treatment group
    trt_count <- 
      data_cohort_sub_imp %>% 
      arrange(treatment) %>% 
      count(treatment, treatment2)
    # Save count in estimates data.frame
    estimates[c(index, index + 3 * imputations_total), "n_assign_trt"] <- 
      trt_count[2, 3]
    estimates[c(index, index + 3 * imputations_total), "n_assign_untrt"] <- 
      nrow(patients_imputed) - trt_count[2, 3]
    cat("#### No. of patients for who treatment is imputed ####\n")
    print(paste0("Treated: ", trt_count[2, 3],
                 "; Untreated: ", nrow(patients_imputed) - trt_count[2, 3]))
    
    # Derive inverse probability of treatment weights (IPTW) ---
    data_cohort_sub_imp$weights <-
      ifelse(data_cohort_sub_imp$treatment2 == "Treated",
             1 / data_cohort_sub$pscore,
             1 / (1 - data_cohort_sub$pscore))
     
    # Check overlap PS ----
    # Identify lowest and highest propensity score in each group
    ps_trim <- data_cohort_sub_imp %>% 
      select(treatment2, pscore) %>% 
      group_by(treatment2) %>% 
      summarise(min = min(pscore), max= max(pscore)) %>% 
      ungroup() %>% 
      summarise(min = max(min), max = min(max)) # see below for why max of min and min of max is taken
    # Restricted to observations within a PS range common to both treated and untreated persons—
    # (i.e. exclude all patients in the nonoverlapping parts of the PS distribution)
    data_cohort_sub_imp <- 
      data_cohort_sub_imp %>% 
      filter(pscore >= ps_trim$min[1] & pscore <= ps_trim$max[1])
    estimates[c(index, index + 3 * imputations_total), "n_after_restriction"] <- nrow(data_cohort_sub_imp)
    
    # Fit outcome model ---
    ## Define svy design for IPTW 
    iptw <- svydesign(ids = ~ 1, data = data_cohort_sub_imp, weights = ~ weights)
    for (j in seq_along(outcomes)){
      outcome_event <- outcomes[j]
      print(outcome_event)
      # because we need to know where in 'estimates' and 'log' output should be
      # saved
      location <- index + 3 * imputations_total * (j - 1)
      estimates[location, "comparison"] <- t
      estimates[location, "outcome"] <- outcome_event
      estimates[location, "imputation"] <- m
      log[location, "comparison"] <- t
      log[location, "outcome"] <- outcome_event
      log[location, "imputation"] <- m
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
                          data = data_cohort_sub_imp)
        )
      # save results from model_PSw and save warnings or errors to log file
      if (is.null(model_PSw()$error)){
        # no error
        log[location,"error"] <- NA_character_
        if (length(model_PSw()$warnings) != 0){
          # save warning in log
          log[location, "warning"] <- paste(model_PSw()$warnings, collapse = '; ')
        } else log[location, "warning"] <- NA_character_
        
        # select main effects from 'model_PSw'
        selection <- 
          model_PSw()$result$coefficients %>% names %>% startsWith("treatment2")
        
        # save coefficients of model and var in estimates
        estimates[location, "logHR"] <- 
          model_PSw()$result$coefficients[selection] 
        estimates[location, c("var")] <- 
         model_PSw()$result$var[selection] # Gives the robust variance
      # error
      } else log[location, "error"] <- model_PSw()$messages
    }
  }
}

## Rubin's Rules---
# Point estimate mean & within imputation variance
rubins_rules <- 
  estimates %>% 
  group_by(comparison, outcome) %>% 
  summarise(mean = mean(logHR), 
            var_w = mean(var),
            .groups = "keep") 
# Between imputation variance 
var_b <- estimates %>% 
  left_join(select(rubins_rules, mean, comparison, outcome),
            by = c("comparison", "outcome")) %>% 
  mutate(diff = (logHR - mean) ^ 2) %>% 
  group_by(comparison, outcome) %>% 
  summarise(sum_diff = sum(diff),
            .groups = "keep") %>% 
  mutate(var_b = sum_diff / (imputations_total - 1)) %>% 
  select(-c(sum_diff))
# Rubins rules + construct CI
rubins_rules <- 
  rubins_rules %>% 
  left_join(var_b,
            by = c("comparison", "outcome")) %>% 
  mutate(
    total_var = var_w + var_b + (var_b / imputations_total), 
    se_pooled = sqrt(total_var),
    lci = (mean - (1.96 * se_pooled)) %>% exp(),
    uci = (mean + (1.96 * se_pooled)) %>% exp(),
    hr = exp(mean)
  ) %>% 
  select(comparison, outcome, hr, lci, uci) 

## Save output ---
write_csv(rubins_rules,
          here("output", 
               "tables", 
               paste0("cox_models_day0.csv")))
write_rds(rubins_rules, 
          here("output", 
               "tables", 
               paste0("cox_models_day0.rds")))
# save original estimates
write_csv(estimates,
          here("output", 
               "tables", 
               paste0("estimates_day0.csv")))
# save log file
write_csv(log,
          here("output", 
               "tables", 
               paste0("log_cox_models_day0.csv")))

