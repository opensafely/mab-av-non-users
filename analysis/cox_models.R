################################################################################
#
# Cox models (propensity score analysis) // BA.1 period
#
# This script can be run via an action in project.yaml using two arguments:
# - 'day_label' /in {day5, day0} (--> day5 or day0 analysis)
# - 'adjustment_set' /in {full, agesex, crude} (--> adjustment set used)
#
# Depending on 'day_label' and 'adjustment_set' the output of this script is:
# 1. Propensity score plots in ./output/figs:
# - 'trt_grp'_'adjustment_set'_overlap_plot_day5_before_restriction_new.png
# -'trt_grp'_'adjustment_set'_overlap_plot_day5_after_restriction_new.png
# [note, if script is run for day5 and day0, file with ps plots will be 
# overwritten (and named 'day5' in both instances)]
# 2. Survival curves in ./output/figs:
# - 'trt_grp'_'outcomes'_'adjustment_set'_cumInc_day5_new.png
# [note, if script is run for day5 and day0, file with cumInc plots will be 
# overwritten (and named 'day5' in both instances)]
# 3. Tables with effect estimates in ./output/tables:
# - cox_models_'data_label'_'adjustment_set'_new.csv
# 4. Log file with errors and warnings in ./output/tables:
# - log_cox_models_'data_label'_'adjustment_set'_new.csv
# 5. PS models in ./output/data_models:
# - 'trt_grp'_'adjustment_set'_psModelFit_new.rds
# [note, if script is run for day5 and day0, file with ps model will be 
# overwritten]
# 
# where 'trt_grp' /in {All, Sotrovimab, Molnupiravir}, and
#       'outcomes' /in {primary, secondary}
################################################################################

################################################################################
# 00. Import libraries + functions
################################################################################
library(tidyverse)
library(lubridate)
library(survival)
library(survminer)
library(gridExtra)
library(splines)
library(survey)
library(here)
# Load functions (wrapper catching and saving errors/warning messages)
source(here("lib", "functions", "safely_n_quietly.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
# Create figures directory
fs::dir_create(here::here("output", "figs"))
# Create tables directory
fs::dir_create(here::here("output", "tables"))
# Create data_models directory (where ps models are saved)
fs::dir_create(here::here("output", "data_models"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to day5 or day0 data, default is day5
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

################################################################################
# 0.3 Import data
################################################################################
if (data_label == "day5") {
  data_cohort <- 
    read_rds(here::here("output", "data", "data_processed_day5.rds"))
} else if (data_label == "day0") {
  data_cohort <-
    read_rds(here::here("output", "data", "data_processed_day0.rds"))
}

################################################################################
# 0.4 Create data.frame for output (estimates + log file)
################################################################################
# create data.frame 'estimates' where output is saved 
# 'estimates' has 7 columns:
# comparison (all/ mol/ sot); outcome (primary/secondary); HR; LowerCI; UpperCI;
# n (number of pt in utilised dataset);
# n_after_restriction (number of pt after trimming ps).
# 'estimates' has 6 rows:
# primary outcome x 3 (mol + sot vs none; sot vs none; mol vs none) plus
# secondary outcome x 3 (idem)
estimates <- matrix(nrow = 6, ncol = 7) %>% as.data.frame()
# provide column names
colnames(estimates) <- 
  c("comparison", "outcome",
    "HR", "LowerCI", "UpperCI",
    "n", "n_after_restriction")
# create data.frame 'log' where errors and warnings are saved
# 'log' has 3 columns: comparison, warning and error
# 'log' has 6 rows like 'estimates'
log <- matrix(nrow = 6, ncol = 4) %>% as.data.frame()
# provide column names
colnames(log) <- 
  c("comparison", "outcome", "warning", "error")

################################################################################
# 1.0 Create vectors for treatments and outcomes used in analysis
################################################################################
# Specify treated group for comparison (Treated vs Untreated)
# used to loop trough different analyses
trt_grp <- c("All", "Sotrovimab", "Molnupiravir")
# Specify outcomes
# used to loop through different analyses
outcomes <- c("primary", "secondary")

################################################################################
# 2.0 Perform analysis
################################################################################
# data.frame 'estimates' is aiming to look like:
# comparison   outcome   HR LowerCI UpperCI n n_after_comparison
# All          primary   -  -       -       - -
# Sotrovimab   primary   -  -       -       - -
# Molnupiravir primary   -  -       -       - -
# All          secondary -  -       -       - -
# Sotrovimab   secondary -  -       -       - -
# Molnupiravir secondary -  -       -       - -
# Loop over analysis for each treatment comparison 
for(i in seq_along(trt_grp)) {
  ##############################################################################
  # 2.1 Select data
  ##############################################################################
  # used later in 'estimates' data.frame to save which analysis is done
  t <- trt_grp[i]
  # Select data used in analysis
  # (mol/sot are excluded in single comparison analyses)
  if (i == 1) {
    print("All Treated versus Untreated Comparison")
    data_cohort_sub <- 
      data_cohort 
    estimates[c(1, 4), "n"] <- nrow(data_cohort_sub)
  } else {
    print(paste0(trt_grp[i], " versus Untreated Comparison"))
    # Drop patients treated with molnupiravir or sotrovimab
    data_cohort_sub <- 
      data_cohort %>% 
      filter(treatment_strategy_cat %in% c("Untreated", trt_grp[i]))
    estimates[c(1 + (i - 1), 4 + (i - 1)), "n"] <- nrow(data_cohort_sub)
  }
  
  if (adjustment_set != "crude") {
    ############################################################################
    # PART A: Perform analysis with full and agesex adjustment
    ############################################################################
    # Create vector of variables for PS model
    # Note: age modelled with cubic spline with 3 knots
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
    ############################################################################
    # A.2.2 Fit Propensity Score Model
    ############################################################################
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
    # Save fitted model
    saveRDS(psModel,
            here("output", 
                 "data_models",
                 paste0(trt_grp[i],
                        "_",
                        adjustment_set,
                        "_psModelFit_new.rds")
            )
    )
    # Append patient-level predicted probability of being assigned to cohort
    data_cohort_sub$pscore <- predict(psModel, type = "response")
    # Make plot of non-trimmed propensity scores and save
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
                  paste0(trt_grp[i],
                         "_",
                         adjustment_set,
                         "_overlap_plot_day5_before_restriction_new.png")),
           width = 20, height = 14, units = "cm")
    ############################################################################
    # A.2.3 Derive inverse probability of treatment weights (IPTW)
    ############################################################################
    data_cohort_sub$weights <-
      ifelse(data_cohort_sub$treatment == "Treated",
             1 / data_cohort_sub$pscore,
             1 / (1 - data_cohort_sub$pscore))
    ############################################################################
    # A.2.4 Trim propensity scores
    ############################################################################
    # Check overlap
    # Identify lowest and highest propensity score in each group
    ps_trim <- data_cohort_sub %>% 
      select(treatment, pscore) %>% 
      group_by(treatment) %>% 
      summarise(min = min(pscore), max= max(pscore)) %>% 
      ungroup() %>% 
      summarise(min = max(min), max = min(max)) # see below for why max of min 
    # and min of max is taken
    # Restricted to observations within a PS range common to both treated and 
    # untreated persons—
    # (i.e. exclude all patients in the non-overlapping parts of the PS 
    # distribution)
    cat("#### Patients before restriction ####\n")
    print(dim(data_cohort_sub))  
    data_cohort_sub_trimmed <- data_cohort_sub %>% 
      filter(pscore >= ps_trim$min[1] & pscore <= ps_trim$max[1])
    cat("#### Patients after restriction ####\n")
    print(dim(data_cohort_sub_trimmed))
    # Save n in 'estimates' after trimming
    estimates[c(1 + (i - 1), 4 + (i - 1)), "n_after_restriction"] <-
      nrow(data_cohort_sub_trimmed)
    # Make plot of trimmed propensity scores and save
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
                  paste0(trt_grp[i],
                         "_",
                         adjustment_set,
                         "_overlap_plot_day5_after_restriction_new.png")),
           width = 20, height = 14, units = "cm")
    ############################################################################
    # A.2.5 Outcome model
    ############################################################################
    # Define svy design for IPTW 
    iptw <- svydesign(ids = ~ 1,
                      data = data_cohort_sub_trimmed,
                      weights = ~ weights)
    # Loop over outcomes
    for (j in seq_along(outcomes)) {
      ##########################################################################
      # A.2.5.0 Fit outcome model
      ##########################################################################
      outcome_event <- outcomes[j]
      print(outcome_event)
      # because we need to know where in 'estimates' and 'log' output should be
      # saved (depending on i, for first outcome,  k = i [--> 1, 2, 3]; 
      #                        for second outcome, k = i + 3 [--> 4, 5, 6])
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
      ##########################################################################
      # A.2.5.1  Save coefficients
      ##########################################################################
      # save results from model_PSw and save warnings or errors to log file
      if (is.null(model_PSw()$error)){
        # no error
        log[k,"error"] <- NA_character_
        if (length(model_PSw()$warnings) != 0){
          # save warning in log
          log[k, "warning"] <- paste(model_PSw()$warnings, collapse = '; ')
        } else log[k, "warning"] <- NA_character_
        # save coefficients of model and CIs in estimates
        result <- model_PSw()$result
        result_summary <- result %>% summary()
        # estimated treatment effect + robust se
        est <- result_summary$coefficients[, "coef"]
        se_robust <- result_summary$coefficients[, "robust se"]
        # construct robust confidence intervals
        ci <- (est + c(-1, 1) * qnorm(0.975) * se_robust) %>% exp()
        estimates[k, "HR"] <- est %>% exp()
        estimates[k, c("LowerCI", "UpperCI")] <- ci
        ########################################################################
        # A.2.5.2 Survival curves
        ########################################################################
        # Untreated
        survdata0 <- 
          survfit(result,
                  newdata = mutate(data_cohort_sub_trimmed,
                                   treatment = "Untreated"))
        
        estimates0 <- data.frame(time = survdata0$time, 
                                 estimate = 1 - rowMeans(survdata0$surv),
                                 Treatment = "Untreated")
        
        # Treated
        survdata1 <- 
          survfit(result,
                  newdata = mutate(data_cohort_sub_trimmed,
                                   treatment = "Treated"))
        
        estimates1 <- data.frame(time = survdata1$time, 
                                 estimate = 1 - rowMeans(survdata1$surv),
                                 Treatment = "Treated")
        # Combine estimates in 1 data.frame
        tidy <- data.frame(rbind(estimates0, estimates1)) 
        # Plot cumulative incidence percentage
        plot <- ggplot(tidy, 
                       aes(x = time,
                           y = 100*estimate,
                           fill = Treatment,
                           color = Treatment)) +
          geom_line(size = 1) + 
          xlab("Time (Days)") +
          ylab("Cumulative Incidence (%)") +
          theme_classic() + 
          scale_x_continuous(breaks = c(0, 5, 10, 15, 20), 
                             labels = c("5", "10", "15", "20", "25"))
        # Save plot
        ggsave(plot, 
               filename = 
                 here("output", "figs", 
                      paste0(trt_grp[i],
                             "_", 
                             outcomes[j],
                             "_",
                             adjustment_set,
                             "_cumInc_day5_new.png")),
               width = 20, height = 14, units = "cm")
      } else log[k, "error"] <- model_PSw()$messages # end pull from model_Psw
    } # end of loop through outcomes
  } else if (adjustment_set == "crude") { # end PART A, start PART B
    ############################################################################
    # PART B: Perform analysis with NO adjustment
    ############################################################################
    ############################################################################
    # B.2.6 Outcome model (no ps needed)
    ############################################################################
    # Loop over outcomes
    for (j in seq_along(outcomes)) {
      ##########################################################################
      # B.2.6.0 Fit outcome model
      ##########################################################################
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
      ##########################################################################
      # B.2.6.1  Save coefficients
      ##########################################################################
      # save results from model_PSw and save warnings or errors to log file
      if (is.null(model()$error)) {
        # no error
        log[k,"error"] <- NA_character_
        if (length(model()$warnings) != 0){
          # save warning in log
          log[k, "warning"] <- paste(model()$warnings, collapse = '; ')
        } else log[k, "warning"] <- NA_character_
        # save coefficients of model and CIs in estimates
        result <- model()$result
        result_summary <- result %>% summary()
        # estimated treatment effect + robust se
        est <- result_summary$coefficients[, "coef"]
        se <- result_summary$coefficients[, "se(coef)"]
        # construct robust confidence intervals
        ci <- (est + c(-1, 1) * qnorm(0.975) * se) %>% exp()
        estimates[k, "HR"] <- est %>% exp()
        estimates[k, c("LowerCI", "UpperCI")] <- ci
      } else log[k, "error"] <- model()$messages # end pull from model
    } # end loop through outcomes
  } # end PART B
} # end loop through treatments

################################################################################
# 3.0 Save output
################################################################################
write_csv(estimates,
          here("output", 
               "tables", 
               paste0("cox_models_",
                      data_label,
                      "_",
                      adjustment_set,
                      "_new.csv")))
write_csv(log,
          here("output", 
               "tables", 
               paste0("log_cox_models_",
                      data_label,
                      "_",
                      adjustment_set,
                      "_new.csv")))
