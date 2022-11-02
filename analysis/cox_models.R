################################################################################
#
# Cox models (propensity score analysis) // BA.1 period
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'day_label' /in {day5, day0} (--> day5 or day0 analysis)
# - 'adjustment_set' /in {full, agesex, crude} (--> adjustment set used)
#
# Depending on 'day_label' and 'adjustment_set' the output of this script is:
# 1. Propensity score plots in ./output/figs:
# - 'trt_grp'_'adjustment_set'_overlap_plot_'day_label'_before_restriction_'period'_new.png
# - 'trt_grp'_'adjustment_set'_overlap_plot_'day_label'_after_restriction_'period'_new.png
# [note, in previous versions, if script was run for day5 and day0, file with ps plots was 
# overwritten (and named 'day5' in both instances)]
# 2. Survival curves in ./output/figs:
# - 'trt_grp'_'outcomes'_'adjustment_set'_cumInc_'day_label'_'period'_new.png
# [note, in previous versions, if script was run for day5 and day0, file with cumInc plots was 
# overwritten (and named 'day5' in both instances)]
# - 'trt_grp'_'outcomes'_'adjustment_set'_cumInc_'data_label'_'period'_new.csv
# 3. Tables with effect estimates in ./output/tables:
# - cox_models_'data_label'_'adjustment_set'_'period'_new.csv
# 4. Log file with errors and warnings in ./output/tables:
# - log_cox_models_'data_label'_'adjustment_set'_'period'_new.csv
# 5. PS models in ./output/data_models:
# - 'trt_grp'_'adjustment_set'_psModelFit_'data_label'_'period'_new.rds
# [note, if script is run for day5 and day0, file with ps model will be 
# overwritten]
# 6. CSV files with counts (redacted) [currently only deployed for primary outcome]
#    in ./output/counts:
# - counts_n_'data_label'_crude_'period'.csv
# - counts_n_outcome_'data_label'_crude_'period'.csv
# - counts_n_restr_'data_label'_'adjustment_set'_'period'.csv 
# - counts_n_outcome_restr_'data_label'_'adjustment_set'_'period'.csv
# (adjustment_set /in {agesex, full})
#
# where 'trt_grp' /in {All, Sotrovimab, Molnupiravir}, and
#       'outcomes' /in {primary, secondary}
# NOTE: the suffix 'period' is not used if period == 'ba1'.
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
source(here::here("lib", "functions", "safely_n_quietly.R"))
source(here::here("lib", "functions", "fill_counts.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
# Create figures directory
fs::dir_create(here::here("output", "figs"))
# Create tables directory
fs::dir_create(here::here("output", "tables"))
# Create data_models directory (where ps models are saved)
fs::dir_create(here::here("output", "data_models"))
# Folder to save counts
fs::dir_create(here::here("output", "counts"))

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
# Set input data to day5 or day0 data, default is day5
if (length(args) == 0){
  data_label = "day5"
} else if (args[[2]] == "day0") {
  data_label = "day0"
} else if (args[[2]] == "day5") {
  data_label = "day5"
} else if (args[[2]] == "day4") {
  data_label = "day4"
} else if (args[[2]] == "day3") {
  data_label = "day3"
} else if (args[[2]] == "day2") {
  data_label = "day2"
} else {
  # Print error if no argument specified
  stop("No outcome specified")
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
           "data_processed_", data_label, ".rds")
data_cohort <-
  read_rds(here::here("output", "data", data_filename))

################################################################################
# 0.4 Create data.frame for output (estimates + log file + counts)
################################################################################
# create data.frame 'estimates' where output is saved 
# 'estimates' has 8 columns:
# model (iptw / ps_adjusted);
# comparison (all/ mol/ sot); outcome (primary/secondary); HR; LowerCI; UpperCI;
# n (number of pt in utilised dataset);
# n_after_restriction (number of pt after trimming ps).
# 'estimates' has 12 rows:
# model (iptw / ps_adjusted) 2 times
# primary outcome x 3 (mol + sot vs none; sot vs none; mol vs none) plus
# secondary outcome x 3 (idem)
estimates <- matrix(nrow = 12, ncol = 8) %>% as.data.frame()
# provide column names
colnames(estimates) <- 
  c("model", "comparison", "outcome",
    "HR", "LowerCI", "UpperCI",
    "n", "n_after_restriction")
# create data.frame 'log' where errors and warnings are saved
# 'log' has 3 columns: model, comparison, outcome, warning and error
# 'log' has 12 rows like 'estimates'
log <- matrix(nrow = 12, ncol = 5) %>% as.data.frame()
# provide column names
colnames(log) <- 
  c("model", "comparison", "outcome", "warning", "error")
# create data.frame 'counts' used to save number of patients / outcomes before
# ps trimming
# total subtotal1 subtotal2 subtotal21 subtotal22
counts_n <- matrix(nrow = 3, ncol = 6) %>% as.data.frame()
colnames(counts_n) <-
  c("comparison", "n", "n_untreated", "n_treated", "n_mol", "n_sot")
# for the agesex and fully adjusted analyses, some people are excluded from the
# analysis --> we like to know n in restricted analyses
counts_n_restr <- matrix(nrow = 3, ncol = 6) %>% as.data.frame()
colnames(counts_n_restr) <-
  c("comparison", "n", "n_untreated", "n_treated", "n_mol", "n_sot")
# total subtotal1 subtotal2 subtotal21 subtotal22
# outcome: primary/ secondary (primary only used for now)
counts_n_outcome <- matrix(nrow = 3, ncol = 7) %>% as.data.frame()
colnames(counts_n_outcome) <-
  c("comparison", "outcome", "n_outcome", "n_outcome_untreated",
    "n_outcome_treated", "n_outcome_mol", "n_outcome_sot")
# for the agesex and fully adjusted analyses, some people are excluded from the
# analysis --> we like to know number of outcomes in restricted analyses
counts_n_outcome_restr <- matrix(nrow = 3, ncol = 7) %>% as.data.frame()
colnames(counts_n_outcome_restr) <-
  c("comparison", "outcome", "n_outcome", "n_outcome_untreated",
    "n_outcome_treated", "n_outcome_mol", "n_outcome_sot")

################################################################################
# 1.0 Create vectors for treatments and outcomes used in analysis
################################################################################
# Specify models 
models <- c("iptw", "ps_adjusted")
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
  } else {
    print(paste0(trt_grp[i], " versus Untreated Comparison"))
    # Drop patients treated with molnupiravir or sotrovimab
    data_cohort_sub <- 
      data_cohort %>% 
      filter(treatment_strategy_cat %in% c("Untreated", trt_grp[i]))
  }
  # Fill n in estimates
  estimates[c(seq(1, 12, 3) + (i - 1)), "n"] <- 
    nrow(data_cohort_sub) %>% plyr::round_any(5)
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
                        "_psModelFit_",
                        data_label,
                        "_",
                        period[!period == "ba1"], "_"[!period == "ba1"],
                        "new.rds")
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
                         "_overlap_plot_",
                         data_label,
                         "_before_restriction_",
                         period[!period == "ba1"], "_"[!period == "ba1"],
                         "new.png")),
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
    data_cohort_sub_trimmed <- data_cohort_sub %>% 
      filter(pscore >= ps_trim$min[1] & pscore <= ps_trim$max[1])
    # Save n in 'estimates' after trimming
    estimates[c(seq(1, 12, 3) + (i - 1)), "n_after_restriction"] <-
      nrow(data_cohort_sub_trimmed) %>% plyr::round_any(5)
    # Fill counts after trimming
    counts_n_restr[i, "comparison"] <- t
    counts_n_restr[i, ] <- fill_counts_n(counts_n_restr[i, ], data_cohort_sub_trimmed)
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
                         "_overlap_plot_",
                         data_label,
                         "_after_restriction_",
                         period[!period == "ba1"], "_"[!period == "ba1"],
                         "new.png")),
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
      estimates[c(k, k + 6), "comparison"] <- t
      estimates[c(k, k + 6), "outcome"] <- outcome_event
      log[c(k, k + 6), "comparison"] <- t
      log[c(k, k + 6), "outcome"] <- outcome_event
      # create formula for primary and secondary analysis
      if (outcome_event == "primary"){
        # iptw analysis
        formula <- 
          as.formula(
            Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
              treatment)
        # ps adjusted analysis
        formula_ps_adjusted <- 
          as.formula(
            Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
              treatment + ns(pscore, df = 3))
        # Fill counts of outcomes after trimming (only for primary outcome)
        counts_n_outcome_restr[i, "comparison"] <- t
        counts_n_outcome_restr[i, "outcome"] <- "primary"
        counts_n_outcome_restr[i, ] <- 
          fill_counts_n_outcome_primary(counts_n_outcome_restr[i, ], data_cohort_sub_trimmed)
      } else if (outcome_event == "secondary"){
        # iptw analysis
        formula <- 
          as.formula(
            Surv(fu_secondary, status_secondary == "allcause_hosp_death") ~ 
              treatment)
        # ps adjusted analysis
        formula_ps_adjusted <- 
          as.formula(
            Surv(fu_secondary, status_secondary == "allcause_hosp_death") ~ 
              treatment + ns(pscore, df = 3))
      }
      # Cox regression
      # returns function model_PSw() with components result, output, messages, 
      # warnings and error
      # fits both iptw and ps adjusted model, and saves in list, estimates are 
      # then looped through (see beneath)
      model_PSw <- 
        safely_n_quietly(
          .f = ~ svycoxph(formula, 
                          design = iptw, 
                          data = data_cohort_sub_trimmed)
        )
      model_PSadjusted <- 
        safely_n_quietly(
          .f = ~ coxph(formula_ps_adjusted,
                          data = data_cohort_sub_trimmed)
        )
      outcome_models <- list(model_PSw, 
                             model_PSadjusted)
      ##########################################################################
      # A.2.5.1  Save coefficients
      ##########################################################################
      # save results from model_PSw and save warnings or errors to log file
      for (l in seq_along(models)){
        mod <- models[l]
        print(mod)
        estimates[k + 6 * (l - 1), "model"] <- mod
        log[k + 6 * (l - 1), "model"] <- mod
        outcome_model <- outcome_models[[l]]
        if (is.null(outcome_model()$error)){
          # no error
          log[k + 6 * (l - 1),"error"] <- NA_character_
          if (length(outcome_model()$warnings) != 0){
            # save warning in log
            log[k + 6 * (l - 1), "warning"] <- paste(outcome_model()$warnings, collapse = '; ')
          } else log[k + 6 * (l - 1), "warning"] <- NA_character_
          # save coefficients of model and CIs in estimates
          result <- outcome_model()$result
          result_summary <- result %>% summary()
          # estimated treatment effect + robust se
          est <- result_summary$coefficients["treatmentTreated", "coef"]
          se_loc <- ifelse(mod == "iptw", "robust se", "se(coef)")
          se_robust <- result_summary$coefficients["treatmentTreated", se_loc]
          # construct robust confidence intervals
          ci <- (est + c(-1, 1) * qnorm(0.975) * se_robust) %>% exp()
          estimates[k + 6 * (l - 1), "HR"] <- est %>% exp()
          estimates[k + 6 * (l - 1), c("LowerCI", "UpperCI")] <- ci
          ######################################################################
          # A.2.5.2.1 Survival curves (only for iptw analysis)
          ######################################################################
          if (mod == "iptw"){
            # Untreated
            survdata0 <- 
              survfit(result,
                      newdata = mutate(data_cohort_sub_trimmed,
                                       treatment = "Untreated"),
                      conf.type = "plain")
            estimates0 <- data.frame(time = survdata0$time, 
                                     estimate = 1 - rowMeans(survdata0$surv),
                                     lower = 1 - rowMeans(survdata0$upper),
                                     upper = 1 - rowMeans(survdata0$lower),
                                     Treatment = "Untreated")
            # Treated
            survdata1 <- 
              survfit(result,
                      newdata = mutate(data_cohort_sub_trimmed,
                                       treatment = "Treated"),
                      conf.type = "plain")
            estimates1 <- data.frame(time = survdata1$time, 
                                     estimate = 1 - rowMeans(survdata1$surv),
                                     lower = 1 - rowMeans(survdata1$upper),
                                     upper = 1 - rowMeans(survdata1$lower),
                                     Treatment = "Treated")
            # Combine estimates in 1 data.frame
            tidy <- data.frame(rbind(estimates0, estimates1))
            # save estimates and cis if replotting needed outside server
            write_csv(tidy,
                      here("output", 
                           "figs", 
                           paste0(trt_grp[i],
                                  "_",
                                  outcomes[j],
                                  "_",
                                  adjustment_set,
                                  "_cumInc_",
                                  data_label,
                                  "_",
                                  period[!period == "ba1"], "_"[!period == "ba1"],
                                  "new.csv")))
            # Plot cumulative incidence percentage
            plot <- ggplot(tidy, 
                           aes(x = time,
                               y = 100 * estimate,
                               color = Treatment)) +
              geom_line(size = 1) + 
              geom_ribbon(aes(ymin = lower * 100,
                              ymax = upper * 100,
                              fill = Treatment,
                              color = NULL),
                          alpha = .15) +
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
                                 "_cumInc_",
                                 data_label,
                                 "_",
                                 period[!period == "ba1"], "_"[!period == "ba1"],
                                 "new.png")),
                   width = 20, height = 14, units = "cm")
          }
        } else log[k + 6 * (l - 1), "error"] <- outcome_model()$messages # end pull from outcome_model
      }
    } # end of loop through outcomes
  } else if (adjustment_set == "crude") { # end PART A, start PART B
    ############################################################################
    # PART B: Perform analysis with NO adjustment
    ############################################################################
    # Fill counts (n in data)
    counts_n[i, "comparison"] <- t
    counts_n[i, ] <- fill_counts_n(counts_n[i, ], data_cohort_sub)
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
      # because we need to know where in 'estimates', 'log' output
      # should be saved
      k <- i + ((j - 1) * 3)
      estimates[c(k, k + 6), "comparison"] <- t
      estimates[c(k, k + 6), "outcome"] <- outcome_event
      estimates[c(k, k + 6), "model"] <- models
      log[k, "comparison"] <- t
      log[k, "outcome"] <- outcome_event
      # create formula for primary and secondary analysis
      if (outcome_event == "primary"){
        formula <- 
          as.formula(
            Surv(fu_primary, status_primary == "covid_hosp_death") ~ 
              treatment)
        # Fill counts of outcomes before trimming (only for primary outcome)
        counts_n_outcome[i, "comparison"] <- t
        counts_n_outcome[i, "outcome"] <- "primary"
        counts_n_outcome[i, ] <- 
          fill_counts_n_outcome_primary(counts_n_outcome[i, ], data_cohort_sub)
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
        estimates[c(k, k + 6), "HR"] <- est %>% exp()
        estimates[k, c("LowerCI", "UpperCI")] <- ci
        estimates[k + 6, c("LowerCI", "UpperCI")] <- ci
      } else log[k, "error"] <- model()$messages # end pull from model
    } # end loop through outcomes
  } # end PART B
} # end loop through treatments

# Make sure that in the sot vs non and mol vs non analysis, counts (n and 
# number of outcomes) is 0 (it may not be if total is e.g. redacted it'll 
# automatically redact subtotals as well)
if (adjustment_set != "crude"){
  counts_n_restr <- 
    counts_n_restr %>%
    mutate(n_mol = case_when(comparison == "Sotrovimab" ~ "0",
                             TRUE ~ n_mol),
           n_sot = case_when(comparison == "Molnupiravir" ~ "0",
                             TRUE ~ n_sot))
  counts_n_outcome_restr <- 
    counts_n_outcome_restr %>%
    mutate(n_outcome_mol = case_when(comparison == "Sotrovimab" ~ "0",
                                     TRUE ~ n_outcome_mol),
           n_outcome_sot = case_when(comparison == "Molnupiravir" ~ "0",
                                     TRUE ~ n_outcome_sot))
} else {
  log <-
    log[1:6, 2:5]
}

################################################################################
# 4.0 Save output
################################################################################
write_csv(estimates,
          here("output", 
               "tables", 
               paste0("cox_models_",
                      data_label,
                      "_",
                      adjustment_set,
                      "_",
                      period[!period == "ba1"], "_"[!period == "ba1"],
                      "new.csv")))
write_csv(log,
          here("output", 
               "tables", 
               paste0("log_cox_models_",
                      data_label,
                      "_",
                      adjustment_set,
                      "_",
                      period[!period == "ba1"], "_"[!period == "ba1"],
                      "new.csv")))
# restricted counts only of use for fully or agesex adjusted analysis (crude
# analysis is not trimmed)
if (adjustment_set != "crude"){
  write_csv(counts_n_restr,
            here("output",
                 "counts",
                 paste0("counts_n_restr_",
                        data_label,
                        "_",
                        adjustment_set,
                        "_"[!period == "ba1"],
                        period[!period == "ba1"],
                        ".csv")))
  write_csv(counts_n_outcome_restr,
            here("output",
                 "counts",
                 paste0("counts_n_outcome_restr_",
                        data_label,
                        "_",
                        adjustment_set,
                        "_"[!period == "ba1"],
                        period[!period == "ba1"],
                        ".csv")))
} else{
  write_csv(counts_n,
            here("output",
                 "counts",
                 paste0("counts_n_",
                        data_label,
                        "_",
                        adjustment_set,
                        "_"[!period == "ba1"],
                        period[!period == "ba1"],
                        ".csv")))
  write_csv(counts_n_outcome,
            here("output",
                 "counts",
                 paste0("counts_n_outcome_",
                        data_label,
                        "_",
                        adjustment_set,
                        "_"[!period == "ba1"],
                        period[!period == "ba1"],
                        ".csv")))
}
