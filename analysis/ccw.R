################################################################################
#
# CCW Analysis
#
# This script can be run via an action in project.yaml using five arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'contrast' /in {all, sotrovimab, molnupiravir} (--> treated vs untreated/ 
#.   sotrovimab vs untreated (excl mol users)/ molnupiravir vs untreated)
# - 'outcome' /in {primary, secondary} (--> primary or secondary outcome)
# - 'model' /in {cox, plr} (--> model used to estimate prob of remaining uncensored)
# - 'subgrp' /in {full, haem, transplant} (--> full cohort or haematological subgroup)
# - 'supp'/in {main, supp1} (--> main analysis or supplemental analysis)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(lubridate)
library(survival)
library(here)
library(readr)
library(riskRegression) #coxLP
library(arrow)
library(optparse)
library(fs)
source(here("analysis", "data_ccw", "simplify_data.R"))
source(here("analysis", "data_ccw", "clone_data.R"))
source(here("analysis", "data_ccw", "add_x_days_to_fup.R"))
source(here("analysis", "data_ccw", "add_x_days_to_day0.R"))
source(here("analysis", "models_ccw", "extract_km_estimates.R"))
source(here("analysis", "models_ccw", "extract_cox_estimates.R"))
source(here("analysis", "models_ccw", "cox_cens.R"))
source(here("analysis", "models_ccw", "plr_cens.R"))
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  contrast <- "all"
  outcome <- "primary"
  model <- "cox"
  subgrp <- "full"
  supp <- "main"
} else {
  
  option_list <- list(
    make_option("--period", type = "character", default = "ba1",
                help = "Period where the analysis is conducted in, options are 'ba1' or 'ba2' [default %default].",
                metavar = "period"),
    make_option("--contrast", type = "character", default = "all",
                help = "Contrast of the analysis, options are 'all' (treated vs untreated), 'molnupiravir' (molnupiravir vs untreated) or 'sotrovimab' (sotrovimab vs untreated) [default %default].",
                metavar = "contrast"),
    make_option("--model", type = "character", default = "cox",
                help = "Model used to estimate probability of remaining uncensored [default %default].",
                metavar = "model"),
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome used in the analysis, options are 'primary' or 'secondary' [default %default].",
                metavar = "outcome"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp"),
    make_option("--supp", type = "character", default = "main",
                help = "Main analysis or supplementary analysis, options are 'main' or 'supp1' [default %default]",
                metavar = "supp")
  )
  
  opt_parser <- OptionParser(usage = "ccw:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  contrast <- opt$contrast
  outcome <- opt$outcome
  model <- opt$model
  subgrp <- opt$subgrp
  supp <- opt$supp
}

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
data_dir <- 
  concat_dirs("data", output_dir, model, subgrp, supp)
tables_ccw_dir <- 
  concat_dirs(path("tables", "ccw"), output_dir, model, subgrp, supp)
models_dir <-
  concat_dirs("models", output_dir, model, subgrp, supp)
models_basehaz_dir <-
  concat_dirs(path("models", "basehaz"), output_dir, model, subgrp, supp)
# Create directory where data in long format will be saved
fs::dir_create(data_dir)
# Create directory where output of ccw analysis will be saved
fs::dir_create(tables_ccw_dir)
# Create directory for models
fs::dir_create(models_dir)
# Create directory for baseline hazards
if (model == "cox"){
  fs::dir_create(models_basehaz_dir)
}

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))
# change data if run using dummy data
if(Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")){
  data <- 
    data %>%
    mutate(study_week = runif(nrow(data), 1, 14) %>% floor())
}

################################################################################
# 0.4 Prepare data
################################################################################
# This step 
# 1. simplifies the variable 'status_primary' OR 'status_secondary' to 
#.   'status_ccw'
# --> levels are 0 (no event/censored); 
#     1 (covid hosp/death; allcause hosp/death)
# --> in 'status_primary', noncovid_hosp is ignored (assuming an event can still 
#.    occur so individual is still at risk for the outcome (covid hosp/death))
# 2. modifies the variable 'tb_postest_treat' in 'tb_postest_treat_ccw'
# --> we classify people as untreated if they experience an event before or on
#     day of treatment and set their
#     tb_postest_treat to NA (= time between treatment and day 0)
# 3. variable 'treatment_ccw' == 'treatment_prim' OR 'treatment_sec' (depending
#    on value of 'outcome')
# 4. variable 'fu_ccw' == 'fu_primary' OR 'fu_secondary' (depending on value of
#    'outcome')
# 5. if 'contrast' is equal to Molnupiravir, individuals treated with Sot are
#    removed from the data; if 'contrast' is equal to Sotrovimab,
#    individuals treated with Mol are removed from the data
# 6. if 'subgrp' is not equal to 'full', the data is subsetted to only include
#    individuals in a particular subgroup (eg haem malignancies)
data <- ccw_simplify_data(data, outcome, contrast, subgrp)
data %>%
  group_by(treatment_ccw) %>%
  tally() %>% print()

################################################################################
# Clone data and add vars outcome, fup and censoring
################################################################################
# This step adds the following 4 variables in both arms (control + treatment):
# - arm: "Control" or "Treatment"
# - fup: the follow-up time in the emulated trial (which can be different from 
#       the observed follow-up time)
# - outcome: the outcome in the emulated trial (which can be different from the 
#            observed outcome)
# - censoring: a binary variable indicating whether the patient was censored in 
#              a given arm (either because they receive surgery in the control 
#              arm or they didn't receive surgery in the surgery arm)
################################################################################
if (supp == "main") {
data_cloned <- 
  clone_data(data) %>%
  add_x_days_to_fup(0.5)
} else if (supp == "supp1") {
  data_cloned <- 
    clone_data(data) %>%
    add_x_days_to_day0(0.5) 
}

################################################################################
# Splitting the data set at each time of event
################################################################################
# create vector of unique time points in 'data_cloned'
t_events <- 
  data_cloned %>% pull(fup) %>% unique() %>% sort()
print(t_events)

################################################################################
# Arm "Control": no treatment within 5 days
################################################################################
# split the data set at each time of an event until the event happens
# the vector 't_events' is used to split the data, for each individual a row
# is added starting at 0 - t_events[1], to t_events[1] - t_events[2] etc. to
# the end of 'fup' (equal or less than max(t_events))
# the start of the interval is saved in column 'tstart', the end of the interval
# is saved in column 'fup', and the indicator of 
# whether or not an event occurred in a time interval is saved in column 
# 'outcome'
data_control_long <- 
  data_cloned %>%
  filter(arm == "Control") %>%
  survSplit(cut = t_events,
            end = "fup",
            zero = 0,
            event = "outcome")
# splitting the original data set at each time of event and sorting it
# until censoring happens. This is to have the censoring status at each time of
# event
data_control_long_cens <-
  data_cloned %>%
  filter(arm == "Control") %>%
  survSplit(cut = t_events,
            end = "fup", 
            zero = 0,
            event = "censoring") %>%
  select(patient_id, tstart, fup, censoring)
data_control_long <-
  data_control_long %>%
  select(-censoring) %>%
  left_join(data_control_long_cens)
################################################################################
# Arm "Treatment": treatment within 5 days
################################################################################
# split the data set at each time of an event until the event happens
# the vector 't_events' is used to split the data, for each individual a row
# is added starting at 0 - t_events[1], to t_events[1] - t_events[2] etc. to
# the end of 'fup' (equal or less than max(t_events))
# the start of the interval is saved in column 'tstart', the end of the interval
# is saved in column 'fup', and the indicator of 
# whether or not an event occurred in a time interval is saved in column 
# 'outcome'
data_trt_long <-
  data_cloned %>%
  filter(arm == "Treatment") %>%
  survSplit(cut = t_events,
            end = "fup",
            zero = 0,
            event = "outcome")
# splitting the original data set at each time of event and sorting it
# until censoring happens. This is to have the censoring status at each time of
# event
data_trt_long_cens <-
  data_cloned %>%
  filter(arm == "Treatment") %>%
  survSplit(cut = t_events,
            end = "fup",
            zero = 0,
            event = "censoring") %>%
  select(patient_id, tstart, fup, censoring)
data_trt_long <-
  data_trt_long %>%
  select(-censoring) %>%
  left_join(data_trt_long_cens) 

################################################################################
# Estimating the censoring weights
################################################################################
# covars_formula in ./lib/design/covars.R
source(here("lib", "design", 
            paste0("covars_formula",
                   "_"[subgrp != "full"], subgrp[subgrp!= "full"],
                   ".R")))
# Cox model (main) or pooled log reg
if (model == "cox"){
  formula_cens <- create_formula_cens_cox(covars_formula)
  ##############################################################################
  # Arm "Control": no treatment within 5 days
  ##############################################################################
  model_cens_control <- fit_cens_cox(data_control_long, formula_cens)
  # set NA coefficients to null
  model_cens_control$coefficients[is.na(model_cens_control$coefficients)] <- 0
  model_cens_control %>% coefficients() %>% print()
  basehaz_control <- basehaz_cens(model_cens_control)
  data_control_long <- 
    data_control_long %>%
    add_p_uncens_cox(model_cens_control, basehaz_control)
  ##############################################################################
  # Arm "Treatment": treatment within 5 days
  ##############################################################################
  model_cens_trt <- fit_cens_cox(data_trt_long, formula_cens)
  # set NA coefficients to null
  model_cens_trt$coefficients[is.na(model_cens_trt$coefficients)] <- 0
  model_cens_trt %>% coefficients() %>% print()
  basehaz_trt <- basehaz_cens(model_cens_trt)
  data_trt_long <- 
    data_trt_long %>%
    add_p_uncens_cox(model_cens_trt, basehaz_trt)
} else if (model == "plr"){
  formula_cens <- create_formula_cens_plr(covars_formula)
  ##############################################################################
  # Arm "Control": no treatment within 5 days
  ##############################################################################
  model_cens_control <- fit_cens_plr(data_control_long, formula_cens)
  model_cens_control %>% coefficients() %>% print()
  data_control_long <- 
    data_control_long %>%
    add_p_uncens_plr(model_cens_control)
  ##############################################################################
  # Arm "Treatment": treatment within 5 days
  ##############################################################################
  model_cens_trt <- fit_cens_plr(data_trt_long, formula_cens)
  model_cens_trt %>% coefficients() %>% print()
  data_trt_long <- 
    data_trt_long %>%
    add_p_uncens_plr(model_cens_trt)
}

################################################################################
# Computing the IPC weights
################################################################################
data_long <- 
  bind_rows(data_control_long, data_trt_long) %>%
  mutate(weight = 1 / p_uncens,
         arm = arm %>% factor(levels = c("Control", "Treatment")))

################################################################################
# Estimating the survivor function
################################################################################
# kaplan meier
km_control <- survfit(Surv(tstart, fup, outcome) ~ 1,
                      data = subset(data_long, arm == "Control"),
                      weights = weight)
km_trt <- survfit(Surv(tstart, fup, outcome) ~ 1,
                  data = subset(data_long, arm == "Treatment"),
                  weights = weight)
max_fup <- max(t_events)
km_est <- extract_km_estimates(km_control, km_trt, max_fup)
# Emulated trial with Cox weights (Cox model)
cox_w <- coxph(Surv(tstart, fup, outcome) ~ arm,
               data = data_long, weights = weight)
cox_w_est <- extract_cox_estimates(cox_w)
# unweighted analysis
cox_uw <- coxph(Surv(tstart, fup, outcome) ~ arm, data = data_long)
cox_uw_est <- extract_cox_estimates(cox_uw)
names(cox_uw_est) <-
  names(cox_uw_est) %>%
  str_replace("HR", "HR_uw")
# save all coefficients in tibble
out <- 
  bind_cols(cox_w_est, cox_uw_est, km_est) %>%
  mutate(period = period,
         outcome = outcome,
         contrast = contrast,
         .before = 1)

################################################################################
# Save output
################################################################################
# save estimates from models
write_csv(
  out,
  fs::path(tables_ccw_dir,
           make_filename("ccw", period, outcome, contrast, model, subgrp, supp, "csv"))
)

################################################################################
# Save residual output
################################################################################
# save data in long format
arrow::write_feather(
  data_long,
  fs::path(data_dir,
           make_filename("data_long", period, outcome, contrast, model, subgrp, supp, "feather")),
  compression = "zstd"
)
# save models
models_list <-
  list(model_cens_control = model_cens_control,
       model_cens_trt = model_cens_control,
       km_control = km_control,
       km_trt = km_trt,
       cox_w = cox_w,
       cox_uw = cox_uw)
names(models_list) <-
  names(models_list) %>%
  str_replace("model", model)
iwalk(.x = models_list,
      .f = ~ 
        write_rds(
          .x,
          fs::path(models_dir,
                   make_filename(
                     .y, period, outcome, contrast, model, subgrp, supp, "rds"
                   )
          )
        )
)
# save baseline hazards
if (model == "cox"){
  basehaz_list <-
    list(basehaz_control = basehaz_control,
         basehaz_trt = basehaz_trt)
  iwalk(.x = basehaz_list,
        .f = ~ 
          write_csv(
            .x,
            fs::path(models_basehaz_dir,
                     make_filename(
                       .y, period, outcome, contrast, model, subgrp, supp, "csv"
                     )
            )
          )
  )
}
