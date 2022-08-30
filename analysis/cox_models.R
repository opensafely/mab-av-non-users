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
  data_label = "day5"
} else if (args[[1]] == "day0") {
  data_label = "day0"
} else if (args[[1]] == "day5") {
  data_label = "day5"
} else {
  # Print error if no argument specified
  stop("No outcome specified")
}

# Adjustment set
if (length(args) == 0){
  adjustment_set = "full"
} else if (args[[2]] == "full") {
  adjustment_set = "full"
} else if (args[[2]] == "agesex") {
  adjustment_set = "agesex"
} else if (args[[2]] == "crude") {
  adjustment_set = "crude"
} else {
  # Print error if no argument specified
  stop("No adjustment set specified")
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
# 'estimates' has 5 columns with the HR and upper and lower limit of CI and 
# n for the number of pt in utilised dataset
# 'estimates' has 6 columns:
# primary outcome x 3 (mol + sot vs none; sot vs none; mol vs none) plus
# secondary outcome x 3 
estimates <- matrix(nrow = 6, ncol = 7) %>% as.data.frame()
# give column names
colnames(estimates) <- 
  c("comparison", "outcome", "HR", "LowerCI", "UpperCI", "n", "n_after_restriction")
# create data.frame 'log' where errors and warnings are saved
# 'log' has 3 columns: comparison, warning and error
# 'log' has 6 rows like 'estimates'
log <- matrix(nrow = 6, ncol = 4) %>% as.data.frame()
# give column names
colnames(log) <- 
  c("comparison", "outcome", "warning", "error")

# Specify treated group for comparison (Treated vs Untreated)
# used to loop trough different analyses
trt_grp <- c("All", "Sotrovimab", "Molnupiravir")
# Specify outcomes
# uesd to loop through different analyses
outcomes <- c("primary", "secondary")

## Loop over analysis for each treatment comparison 
for(i in seq_along(trt_grp)) {
  # used later in 'esimates' data.frame to save which analysis is done
  t <- trt_grp[i]
  
  # Select data used in analysis ---
  # (mol/sot are excluded in single comparison analyses)
  if (i == 1) {
    print("All Treated versus Untreated Comparison")
    data_cohort_sub <- 
      data_cohort 
    estimates[c(1, 4), "n"] <- (nrow(data_cohort_sub))
  } else {
    print(paste0(trt_grp[i], " versus Untreated Comparison"))
    # Drop patients treated with molnupiravir or sotrovimab
    data_cohort_sub <- 
      data_cohort %>% 
      filter(treatment_strategy_cat %in% c("Untreated", trt_grp[i]))
    estimates[c(1 + (i - 1), 4 + (i - 1)), "n"] <- (nrow(data_cohort_sub))
  }

  # Fit Propensity Score Model ---
  # Vector of variables for PS model
  # Note: age modelled with cubic spline with 3 knots
  
  if (adjustment_set != "crude") {
    
    if (adjustment_set == "full"){
  vars <-
    c(
      "ns(age, df=3)",
      "ns(study_week, df=3)",
      "sex",
      "ethnicity",
      "imdQ5",
      "stp",
      "rural_urban",
      "huntingtons_disease_nhsd",
      "myasthenia_gravis_nhsd",
      "motor_neurone_disease_nhsd",
      "multiple_sclerosis_nhsd",
      "solid_organ_transplant_new",
      "hiv_aids_nhsd",
      "immunosuppression_new",
      "imid_nhsd",
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
      "moderna_most_recent_cov_vac"
    )
    } else if (adjustment_set == "agesex") {
      vars <-
        c(
          "ns(age, df=3)",
          "sex"
        )
      
    }
  # Specify model
  psModelFunction <- as.formula(
    paste("treatment", 
          paste(vars, collapse = " + "), 
          sep = " ~ "))

  # Check your model
  print(psModelFunction)
  # Fit PS model
  psModel <- glm(psModelFunction,
                 family = binomial(link = "logit"),
                 data = data_cohort_sub)
  
  summary(psModel) %>% coefficients()
  saveRDS(psModel, here("output", "data_models",
                        paste0(trt_grp[i], "_", adjustment_set, "_psModelFit_new.rds")))
  # Append patient-level predicted probability of being assigned to cohort
  data_cohort_sub$pscore <- predict(psModel, type = "response")
  # Overlap plot 
  overlapPlot <- data_cohort_sub %>% 
    mutate(trtlabel = ifelse(treatment == "Treated",
                             yes = 'Treated',
                             no = 'Untreated')) %>%
    ggplot(aes(x = pscore, linetype = trtlabel)) +
    scale_linetype_manual(values=c("solid", "dotted")) +
    geom_density(alpha = 0.5) +
    xlab('Probability of receiving treatment') +
    ylab('Density') +
    scale_fill_discrete('') +
    scale_color_discrete('') +
    scale_x_continuous(breaks=seq(0, 1, 0.1)) +
    theme(strip.text = element_text(colour ='black')) +
    theme_bw() +
    theme(legend.title = element_blank()) +
    theme(legend.position = c(0.82,.8),
          legend.direction = 'vertical', 
          panel.background = element_rect(fill = "white", colour = "white"),
          axis.line = element_line(colour = "black"),
          panel.border = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())
  # Save plot
  ggsave(overlapPlot, 
         filename = 
           here("output", "figs", 
                paste0(trt_grp[i], "_", adjustment_set, "_overlap_plot_day5_before_restriction_new.png")),
         width=20, height=14, units="cm")
  # Derive inverse probability of treatment weights (IPTW)
  data_cohort_sub$weights <-
    ifelse(data_cohort_sub$treatment == "Treated",
           1 / data_cohort_sub$pscore,
           1 / (1 - data_cohort_sub$pscore))
  # Check overlap
  # Identify lowest and highest propensity score in each group
  
  ps_trim <- data_cohort_sub %>% 
    select(treatment, pscore) %>% 
    group_by(treatment) %>% 
    summarise(min = min(pscore), max= max(pscore)) %>% 
    ungroup() %>% 
    summarise(min = max(min), max = min(max)) # see below for why max of min and min of max is taken
  
  # Restricted to observations within a PS range common to both treated and untreated persons—
  # (i.e. exclude all patients in the nonoverlapping parts of the PS distribution)
  
  cat("#### Patients before restriction ####\n")
  print(dim(data_cohort_sub))  
  
  data_cohort_sub_trimmed <- data_cohort_sub %>% 
    filter(pscore >= ps_trim$min[1] & pscore <= ps_trim$max[1])
  
  cat("#### Patients after restriction ####\n")
  print(dim(data_cohort_sub_trimmed))
  estimates[c(1 + (i - 1), 4 + (i - 1)), "n_after_restriction"] <- nrow(data_cohort_sub_trimmed)
  
  # Overlap plot 
  overlapPlot2 <- data_cohort_sub_trimmed %>% 
    mutate(trtlabel = ifelse(treatment == "Treated",
                             yes = 'Treated',
                             no = 'Untreated')) %>%
    ggplot(aes(x = pscore, linetype = trtlabel)) +
    scale_linetype_manual(values=c("solid", "dotted")) +
    geom_density(alpha = 0.5) +
    xlab('Probability of receiving treatment') +
    ylab('Density') +
    scale_fill_discrete('') +
    scale_color_discrete('') +
    scale_x_continuous(breaks=seq(0, 1, 0.1)) +
    theme(strip.text = element_text(colour ='black')) +
    theme_bw() +
    theme(legend.title = element_blank()) +
    theme(legend.position = c(0.82,.8),
          legend.direction = 'vertical', 
          panel.background = element_rect(fill = "white", colour = "white"),
          axis.line = element_line(colour = "black"),
          panel.border = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())
  # Save plot
  ggsave(overlapPlot2, 
         filename = 
           here("output", "figs", 
                paste0(trt_grp[i], "_", adjustment_set, "_overlap_plot_day5_after_restriction_new.png")),
         width=20, height=14, units="cm")
  
  # Fit outcome model ---
  ## Define svy design for IPTW 
  iptw <- svydesign(ids = ~ 1, data = data_cohort_sub_trimmed, weights = ~ weights)
  for (j in seq_along(outcomes)){
    outcome_event <- outcomes[j]
    print(outcome_event)
    # because we need to know where in 'estimates' and 'log' output should be
    # saved
    k <- i + ((j - 1) * 3)
    estimates[k, "comparison"] <- t
    estimates[k, "outcome"] <- outcome_event
    log[k, "comparison"] <- t
    log[k, "outcome"] <- outcome_event
    # create formula for primary and secondary analysis
    if (outcome_event == "primary"){
      formula <- 
        as.formula(
          Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
            treatment)
    } else if (outcome_event == "secondary"){
      formula <- 
        as.formula(
          Surv(fu_secondary, status_secondary == "allcause_hosp_death") ~ 
            treatment)
    }
    # Cox regression
    # returns function model_PSw() with components result, output, messages, 
    # warnings and error
    model_PSw <- 
      safely_n_quietly(
        .f = ~ svycoxph(formula, 
                        design = iptw, 
                        data = data_cohort_sub_trimmed)
      )
    # save results from model_PSw and save warnings or errors to log file
    if (is.null(model_PSw()$error)){
      # no error
      log[k,"error"] <- NA_character_
      if (length(model_PSw()$warnings) != 0){
        # save warning in log
        log[k, "warning"] <- paste(model_PSw()$warnings, collapse = '; ')
      } else log[k, "warning"] <- NA_character_
      
      # select main effects from 'model_PSw'
      selection <- 
        model_PSw()$result$coefficients %>% names %>% startsWith("treatment")
      
      # save coefficients of model and CIs in estimates
      estimates[k, "HR"] <- model_PSw()$result$coefficients[selection] %>% exp()
      estimates[k, c("LowerCI", "UpperCI")] <- 
        confint(model_PSw()$result)[selection,] %>% exp()
      
      # Survival curves
      # Untreated
      survdata0 <- survfit(model_PSw()$result,
                           newdata=mutate(data_cohort_sub_trimmed, treatment="Untreated"))
    
      estimates0 <- data.frame(time = survdata0$time, 
                               estimate = 1 - rowMeans(survdata0$surv),
                               Treatment = "Untreated")
      
      # Treated
      survdata1 <- survfit(model_PSw()$result, 
                           newdata=mutate(data_cohort_sub_trimmed, treatment="Treated"))
      
      estimates1 <- data.frame(time = survdata1$time, 
                               estimate = 1 - rowMeans(survdata1$surv),
                               Treatment = "Treated")
      
      # Combine estimates in 1 dataframe
      tidy <- data.frame(rbind(estimates0, estimates1)) 
      
      # Plot cumulative incidence percentage
      plot <- ggplot(tidy, aes(x=time, y=100*estimate, fill=Treatment, color=Treatment)) +
        geom_line(size = 1) + 
        xlab("Time (Days)") +
        ylab("Cumulative Incidence (%)") +
        theme_classic() + 
        scale_x_continuous(breaks=c(0, 5, 10, 15, 20), 
                       labels=c("5", "10", "15", "20", "25"))
      
      # Save plot
      ggsave(plot, 
             filename = 
               here("output", "figs", 
                    paste0(trt_grp[i], "_",  outcomes[j], "_", adjustment_set, "_cumInc_day5_new.png")),
             width=20, height=14, units="cm")


    } else log[k, "error"] <- model_PSw()$messages
  }
  }
  if (adjustment_set == "crude") {
    for (j in seq_along(outcomes)){
      outcome_event <- outcomes[j]
      print(outcome_event)
      # because we need to know where in 'estimates' and 'log' output should be
      # saved
      k <- i + ((j - 1) * 3)
      estimates[k, "comparison"] <- t
      estimates[k, "outcome"] <- outcome_event
      log[k, "comparison"] <- t
      log[k, "outcome"] <- outcome_event
      # create formula for primary and secondary analysis
      if (outcome_event == "primary"){
        formula <- 
          as.formula(
            Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
              treatment)
      } else if (outcome_event == "secondary"){
        formula <- 
          as.formula(
            Surv(fu_secondary, status_secondary == "allcause_hosp_death") ~ 
              treatment)
      }
      # Cox regression
      # returns function model with components result, output, messages, 
      # warnings and error
      model <- 
        safely_n_quietly(
          .f = ~ coxph(formula, 
                          data = data_cohort_sub)
        )
      # save results from model_PSw and save warnings or errors to log file
      if (is.null(model()$error)){
        # no error
        log[k,"error"] <- NA_character_
        if (length(model()$warnings) != 0){
          # save warning in log
          log[k, "warning"] <- paste(model()$warnings, collapse = '; ')
        } else log[k, "warning"] <- NA_character_
        
        # select main effects from 'model_PSw'
        selection <- 
          model()$result$coefficients %>% names %>% startsWith("treatment")
        
        # save coefficients of model and CIs in estimates
        estimates[k, "HR"] <- model()$result$coefficients[selection] %>% exp()
        estimates[k, c("LowerCI", "UpperCI")] <- 
          confint(model()$result)[selection,] %>% exp()
      
        } else log[k, "error"] <- model()$messages
    }
  }
}

## Save output
write_csv(estimates,
          here("output", 
               "tables", 
               paste0("cox_models_", data_label, "_", adjustment_set,"_new.csv")))
write_rds(estimates, 
          here("output", 
               "tables", 
               paste0("cox_models_", data_label, "_", adjustment_set, "_new.rds")))
write_csv(log,
          here("output", 
               "tables", 
               paste0("log_cox_models_", data_label, "_", adjustment_set,"_new.csv")))

