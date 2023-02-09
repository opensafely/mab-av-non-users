################################################################################
#
# CCW Analysis
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'contrast' /in {all, sotrovimab, molnupiravir} (--> treated vs untreated/ 
#.   sotrovimab vs untreated (excl mol users)/ molnupiravir vs untreated)
# - 'outcome' /in {primary, secondary} (--> primary or secondary outcome)
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
source(here("lib", "design", "covars_formula.R"))
source(here("analysis", "data_ccw", "simplify_data.R"))
source(here("analysis", "data_ccw", "clone_data.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
# Create directory where output of ccw analysis will be saved
fs::dir_create(here::here("output", "tables", "ccw"))
# Create directory for models
fs::dir_create(here::here("output", "models"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
print(args)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
  contrast = "all"
  outcome = "primary"
} else if (length(args) != 3){
  stop("Three arguments are needed")
} else if (length(args) == 3) {
  if (args[[1]] == "ba1") {
    period = "ba1"
  } else if (args[[1]] == "ba2") {
    period = "ba2"
  }
  if (args[[2]] == "all"){
    contrast = "all"
  } else if (args[[2]] == "molnupiravir"){
    contrast = "Molnupiravir"
  } else if (args[[2]] == "sotrovimab"){
    contrast = "Sotrovimab"
  }
  if (args[[3]] == "primary"){
    outcome = "primary"
  } else if (args[[3]] == "secondary"){
    outcome = "secondary"
  }
} else {
  # Print error if no argument specified
  stop("No period and/or contrast and/or outcome specified")
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
# FIX ME:
# - Should we treat non covid death as a competing risk in 'status_primary'?
#   (= informative censoring)
# 2. modifies the variable 'tb_postest_treat' in 'tb_postest_treat_ccw'
# --> we classify people as untreated if they experience an event before or on
#     day of treatment and set their
#     tb_postest_treat to NA (= time between treatment and day 0)
# 3. variable 'treatment_ccw' == 'treatment_prim' OR 'treatment_sec' (depending
#    on value of 'outcome')
# 4. variable 'fu_ccw' == 'fu_primary' OR 'fu_secondary' (depending on value of
#    'outcome')
# 5. if 'contrast' is equal to Molnupiravir, individuals treated with Sot are
#.   removed from the data; if 'contrast' is equal to Sotrovimab,
#.   individuals treated with Mol are removed from the data
data <- ccw_simplify_data(data, outcome, contrast)

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
data_cloned <- clone_data(data)
data_control <- data_cloned %>% filter(arm == "Control")
data_trt <- data_cloned %>% filter(arm == "Treatment")

################################################################################
# Splitting the data set at each time of event
################################################################################
# create vector of unique time points in 'data_cloned'
t_events <- 
  data_cloned %>% pull(fup) %>% unique() %>% sort()
print(t_events)
data_cloned %>%
  filter(fup == 0) %>%
  pull(outcome) %>%
  table() %>% print()
cat("number of 0 fups in control arm\n")
data_control %>%
  filter(fup == 0) %>%
  pull(outcome) %>% table() %>% print()
cat("outcome in people in control arm treated on day 0 (should be 0) \n")
data_cloned %>%
  filter(arm == "Control") %>%
  filter(treatment_ccw == "Treated" & tb_postest_treat_ccw == 0) %>%
  pull(outcome) %>% table() %>% print()
cat("fup in people in control arm treated on day 0 (should be 0) \n")
data_cloned %>%
  filter(arm == "Control") %>%
  filter(treatment_ccw == "Treated" & tb_postest_treat_ccw == 0) %>%
  pull(fup) %>% quantile() %>% print()
cat("number of 0 fups in treatment arm\n")
data_trt %>%
  filter(fup == 0) %>%
  pull(outcome) %>% table() %>% print()
cat("outcome in people with 0 fups in treatment arm\n")
data_cloned %>%
  filter(arm == "Treatment") %>%
  filter(fup == 0) %>%
  pull(status_all) %>%
  table() %>% print()
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
  data_control %>%
  survSplit(cut = t_events,
            end = "fup",
            zero = 0,
            event = "outcome")
# splitting the original data set at each time of event and sorting it
# until censoring happens. This is to have the censoring status at each time of
# event
data_control_long_cens <-
  data_control %>%
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
  data_trt %>%
  survSplit(cut = t_events,
            end = "fup",
            zero = 0,
            event = "outcome")
# splitting the original data set at each time of event and sorting it
# until censoring happens. This is to have the censoring status at each time of
# event
data_trt_long_cens <-
  data_trt %>%
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
# Cox model
# covars_formula in ./lib/design/covars.R
formula_cens <- paste0("Surv(tstart, fup, censoring) ~ ",
                  paste0(covars_formula, collapse = " + ")) %>% as.formula()
################################################################################
# Arm "Control": no treatment within 5 days
################################################################################
# Cox model
cox_control_cens <-
  coxph(formula_cens,
        ties = "efron",
        data = data_control_long)
# calculate baseline hazard (0 for time = 0)
basehazard_control <- 
  basehaz(cox_control_cens, centered = F) %>%
  add_row(hazard = 0, time = 0, .before = 1)
# add linear predictor and calculate probablity of remaining uncensored
data_control_long <-
  data_control_long %>%
  mutate(lin_pred = coxLP(cox_control_cens, data_control_long, center = FALSE)) %>%
  left_join(basehazard_control, by = c("tstart" = "time")) %>%
  mutate(p_uncens = exp(-(hazard)*exp(lin_pred)))
################################################################################
# Arm "Treatment": treatment within 5 days
################################################################################
# Cox model
cox_trt_cens <-
  coxph(formula_cens,
        ties = "efron",
        data = data_trt_long)
# calculate baseline hazard (0 for time = 0)
basehazard_trt <- 
  basehaz(cox_trt_cens, centered = F) %>%
  add_row(hazard = 0, time = 0, .before = 1)
# add linear predictor and calculate probablity of remaining uncensored
data_trt_long <-
  data_trt_long %>%
  mutate(lin_pred = coxLP(cox_trt_cens, data_trt_long, center = FALSE)) %>%
  left_join(basehazard_trt, by = c("tstart" = "time")) %>%
  mutate(p_uncens = exp(-(hazard)*exp(lin_pred)))

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
km_trt <- survfit(Surv(tstart, fup, outcome) ~ 1,
                  data = data_long %>% filter(arm == "Treatment"),
                  weights = weight)
km_control <- survfit(Surv(tstart, fup, outcome) ~ 1,
                      data = data_long %>% filter(arm == "Control"),
                      weights = weight)
# difference in 28 day survival
S28_trt <- km_trt$surv[27] # 28 day survival in treatment group 
S28_control <- km_control$surv[27] # 28 day survival in control group 
diff_surv <- S28_trt - S28_control #Difference in 28 day survival
diff_surv_SE <- sqrt(km_trt$std.err[27] ^ 2 + km_control$std.err[27] ^ 2)
diff_surv_CI <- diff_surv + c(-1, 1) * qnorm(0.975) * diff_surv_SE
# difference in 28-day restricted mean survival
RMST_trt <- summary(km_trt, rmean = 27)$table["rmean"] # Estimated RMST in the trt grp
RMST_control <- summary(km_control, rmean = 27)$table["rmean"] # Estimated RMST in the control grp
diff_RMST <- RMST_trt - RMST_control # Difference in RMST
diff_RMST_SE <- sqrt(summary(km_trt, rmean = 27)$table["se(rmean)"] ^ 2 + 
                       summary(km_control, rmean = 27)$table["se(rmean)"] ^ 2)
diff_RMST_CI <- diff_RMST + c(-1, 1) * qnorm(0.975) * diff_RMST_SE
# Emulated trial with Cox weights (Cox model)
cox_w <- coxph(Surv(tstart, fup, outcome) ~ arm,
               data = data_long, weights = weight)
HR <- cox_w$coefficients %>% exp() #Hazard ratio
HR_CI <- confint(cox_w) %>% exp()
# save all coefficients in tibble
out <-
  tibble(period,
         outcome,
         contrast,
         HR,
         HR_lower = HR_CI[1],
         HR_upper = HR_CI[2],
         diff_surv,
         diff_surv_lower = diff_surv_CI[1],
         diff_surv_upper = diff_surv_CI[2],
         diff_RMST,
         diff_RMST_lower = diff_RMST_CI[1],
         diff_RMST_upper = diff_RMST_CI[2])

################################################################################
# Save output
################################################################################
make_filename <- function(object_name, period, outcome, contrast, type){
  paste0(period[period != "ba1"],
         "_"[period != "ba1"],
         object_name,
         "_",
         contrast %>% tolower(),
         "_"[outcome != "primary"],
         outcome[outcome != "primary"],
         ".",
         type)
}
# save data in long format
write_rds(data_long,
          here::here("output", "data",
          make_filename("data_long", period, outcome, contrast, "rds")))
write_csv(out,
          here::here("output", "tables", "ccw",
          make_filename("ccw", period, outcome, contrast, "csv")))
write_rds(km_trt,
          here::here("output", "models",
          make_filename("km_trt", period, outcome, contrast, "rds")))
write_rds(km_control,
          here::here("output", "models",
          make_filename("km_control", period, outcome, contrast, "rds")))
write_rds(cox_w,
          here::here("output", "models",
          make_filename("cox_w", period, outcome, contrast, "rds")))
