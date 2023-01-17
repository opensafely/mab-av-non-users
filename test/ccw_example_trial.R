################################################################################
#
# Synthetic trial 
#
# https://docs.google.com/spreadsheets/d/12WVbVIcLH28XL9JAc6TLRMJ8pcN26eo_2ppYBlZcv48/edit#gid=0
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(survival)
library(lspline)

################################################################################
# 1. Create tibble with trial data
################################################################################
# Trial assignes 36 individuals, 30 to treatment arm and 6 to no treatment arm
# In treatment arm, 6 are treated on day 0, ...., and 6 are treated on day 4
# Treatment has no effect on outcome
# Of each of the 6 individuals assigned to treatment on day 0-4 or no treatment,
# 5 experience an outcome on day 1, 2, 3, 4, or day 22.
data <- 
  tibble(pt_id = 1:36,
         outcome = c(c(1, 1, 1, 1, 1, 0),
                     rep(c(1, 1, 1, 1, 1, 0), 5)),
         fup = c(c(1, 2, 3, 4, 22, 27),
                 rep(c(1, 2, 3, 4, 22, 27), 5)),
         treatment = c(rep(0, 6), rep(1, 30)),
         treatment_t = c(rep(NA_real_, 6),
                         rep(0, 6), 
                         rep(1, 6),
                         rep(2, 6),
                         rep(3, 6),
                         rep(4, 6))
         )
data %>%
  group_by(treatment, outcome) %>%
  tally()
# 5 outcomes in 6 untreated individuals; 25 outcomes in 30 treated individuals
# --> Risk Ratio = 25/30 / 5/6 = 1
# Fit survival model on data
sfit <- survfit(Surv(fup, outcome) ~ treatment,
                data = data)
sfit %>%
  summary()
# Survival probability on day 1 is 5/6; on day 2 is 5/6*4/5; 
# on day 3 is 5/6*4/5*3/4; on day 4 is 5/6*4/5*3/4*2/3
# on day 22 is 5/6*4/5*3/4*2/3*1/2
# equal to 25/30; 25/30*20/25;....; 25/30*20/25*15/20*10/15*5/10
# HR for treatment vs no treatment is 1
coxph(Surv(fup, outcome) ~ treatment,
      data = data)
# logistic regression
# 1 / (1 + exp(-intercept)) = 5/6
# 1 = 5/6 * (1 + exp(-intercept)) =
# 6/5 - 1 = exp(-intercept) =
# intercept = log(6/5 - 1) * -1
glm(outcome ~ treatment,
    family = binomial(link = "logit"), 
    data = data) 
# pooled logistic regression
cuts <- 1:27
data_split <-
  data %>%
  survSplit(cut = cuts, 
            start = "start",
            zero = 0,
            end = "fup",
            event = "outcome")
pooled_logreg_fit <- 
  glm(outcome ~ treatment + lspline(fup, 1),
      family = binomial(link = "logit"),
      data = data_split)
pooled_logreg_fit$coefficients[2] %>% exp() # approx same as HR
################################################################################
# 2. Create tibble with observed data
################################################################################
# Suppose now we don't have columns treatment and treatment_t
# Observed treatment is equal to 1 only if there was no outcome before or on day
# of treatment 
data_obs <- data %>%
  mutate(treatment_obs = case_when(treatment == 1 & fup > treatment_t ~ 1,
                                   TRUE ~ 0),
         treatment_t_obs = case_when(treatment_obs == 1 ~ treatment_t,
                                     TRUE ~ NA_real_)) %>%
  select(-c(treatment, treatment_t))
data_obs %>% 
  group_by(treatment_obs, outcome) %>%
  tally() 
# 15 outcomes in 16 untreated individuals; 15 outcomes in 20 treated individuals
# --> Risk ratio 15/20 / 15/16 < 1 [BIASED]
# Fit survival model on data
sfit_obs <- survfit(Surv(fup, outcome) ~ treatment_obs,
                data = data_obs)
sfit_obs %>%
  summary()
# HR for treatment vs no treatment is < 1
coxph(Surv(fup, outcome) ~ treatment_obs,
      data = data_obs)
# logistic regression
# intercept = log(16/15 - 1) * -1
# slope = log(20/15 - 1) * -1 - log(16/15 - 1) * -1
glm(outcome ~ treatment_obs,
    family = binomial(link = "logit"), 
    data = data_obs) 
# pooled logistic regression
cuts <- 1:27
data_obs_split <-
  data_obs %>%
  survSplit(cut = cuts, 
            start = "start",
            zero = 0,
            end = "fup",
            event = "outcome")
pooled_logreg_fit_obs <- 
  glm(outcome ~ treatment_obs + lspline(fup, 1),
      family = binomial(link = "logit"),
      data = data_obs_split)
pooled_logreg_fit_obs$coefficients[2] %>% exp() # approx same as HR

################################################################################
# 3. CCW
################################################################################
################################################################################
# 3.1 STEP 2: CLONING
################################################################################
# This step adds the following variables:
# - arm: 0 for no treatment and 1 for treatment within 5 days
# - art_censoring: a binary variable indicating whether the patient was censored 
#                  in a given arm (either because they receive treatment in the
#                  control arm or they didn't receive treatment in the treatment
#                  arm)
# - fup_art_uncensored: the follow-up time uncensored in the trial arm (can be 
#                       shorter than the 'fup'). If a patient is art uncensored,
#                       this variable is equal to fup
# - outcome_obs: the outcome in the emulated trial (which can be different from 
#                the observed outcome). If outcome occurs before or on the day a
#                patient is artificially censored, outcome is counted. 
# - fup_obs: the follow up time in the emulated trial (which can be different 
#            from the observed outcome). If outcome occurs before or on the day 
#            the individual is art censored, fup_obs is equal to fup. If outcome 
#            occurs after individual is artificially censored or there is no 
#            outcome, individual is followed until artificially censored
################################################################################
# 3.1A STEP 2: CREATE SYNTHETIC NO TREATMENT ARM
################################################################################
# clone data to synthetic no treatment arm 
data_notrt <- 
  data_obs %>%
  mutate(arm = 0) %>% # no treatment arm
  filter(!(treatment_obs == 1 & treatment_t_obs == 0)) # patients 7-12 are
                                    # excluded bc they were treated on day 0
# prepare data
data_notrt <- 
  data_notrt %>%
  mutate(art_censoring = case_when(treatment_obs == 1 ~ 1,
                                   TRUE ~ 0),
         fup_art_uncensored = case_when(art_censoring == 1 ~ treatment_t_obs,
                                        TRUE ~ fup),
         outcome_obs = case_when(outcome == 1 & fup <= fup_art_uncensored ~ 1,
                                 outcome == 1 & art_censoring == 0 ~ 1,
                                 TRUE ~ 0),
         fup_obs = case_when(outcome_obs == 1 ~ fup,
                             TRUE ~ fup_art_uncensored))
################################################################################
# 3.1B STEP 2: CREATE SYNTHETIC TREATMENT ARM
################################################################################
# clone data to synthetic treatment arm 
data_trt <- 
  data_obs %>%
  mutate(arm = 1) # treatment arm
# prepare data
data_trt <- 
  data_trt %>%
  mutate(art_censoring = case_when(treatment_obs == 0 & fup >= 4 ~ 1,
                                   TRUE ~ 0), # art censored if not treated and
                                              # follow-up longer than 4 days
                                              # if outcome before or on day 4,
                                              # outcome is counted and pt is not
                                              # art censored
         fup_art_uncensored = case_when(art_censoring == 1 ~ 4,
                                        TRUE ~ fup),
         outcome_obs = case_when(outcome == 1 & fup < fup_art_uncensored ~ 1,
                                 outcome == 1 & art_censoring == 0 ~ 1,
                                 TRUE ~ 0),
         fup_obs = case_when(outcome_obs == 1 ~ fup,
                             TRUE ~ fup_art_uncensored))

################################################################################
# 3.2A STEP 3: SPLIT DATASET AT EACH DAY & CALCULAT£ WEIGHTS NO TREATMENT ARM
################################################################################
cuts <- 1:27
# Prepare data for the calculation of weights
# No of people artificially censored per time interval
split_notrt_art_censoring <- 
  data_notrt %>%
    survSplit(data = .,
              cut = cuts, 
              start = "start",
              zero = 0,
              end = "fup_art_uncensored",
              event = "art_censoring") %>%
    group_by(start, fup_art_uncensored) %>%
    summarise(sum_art_censored = sum(art_censoring),
              n = n(),
              .groups = "drop")
split_notrt_art_censoring <- 
  data_notrt %>%
  survSplit(data = .,
            cut = cuts, 
            start = "start",
            zero = 0,
            end = "fup_art_uncensored",
            event = "art_censoring")
fit_artc <-
  glm(art_censoring ~ fup_art_uncensored,
      family = binomial(link = "logit"),
      data = split_notrt_art_censoring)
1 / (1 - predict(fit_artc, type = "response"))
data_notrt_split <-
  data_notrt_split %>%
  mutate(p_c = predict(fit_artc,
                       data = data_notrt_split))
data_notrt_split %>% View()

pooled_logreg_fit_obs_notrt <- 
  glm(censoring ~ lspline(end, 1),
      family = binomial(link = "logit"),
      data = data_notrt_split)

# No of people experiencing an outcome per time interval
split_notrt_outcome <- 
  data_notrt %>%
    survSplit(data = .,
              cut = cuts,
              start = "start",
              zero = 0,
              end = "fup_obs",
              event = "outcome_obs") %>%
    group_by(start, fup_obs) %>%
    summarise(sum_outcome = sum(outcome_obs),
              n = n(),
              .groups = "drop")
# Calculate weights
weights_notrt <-
  split_notrt_art_censoring %>%
  left_join(split_notrt_outcome,
            by = c("start", "fup_art_uncensored" = "fup_obs", "n")) %>%
  mutate(p_uncensored = (n - sum_art_censored) / (n),
         weight = 1 / p_uncensored) %>%
  rename(end = fup_art_uncensored) %>%
  select(start, end, weight) %>%
  mutate(cum_weight = cumprod(weight))
# Split data set and add weights to data
data_notrt_split <- 
  data_notrt %>%
    survSplit(data = .,
              cut = cuts,
              start = "start",
              zero = 0,
              end = "fup_obs",
              event = "outcome_obs") %>%
  full_join(weights_notrt,
            by = c("start" = "start", "fup_obs" = "end"))
################################################################################
# 3.2B STEP 3: SPLIT DATASET AT EACH DAY & CALCULAT£ WEIGHTS TREATMENT ARM
################################################################################
cuts <- 1:27
# Prepare data for the calculation of weights
# No of people artificially censored per time interval
split_trt_art_censoring <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts, 
            start = "start",
            zero = 0,
            end = "fup_art_uncensored",
            event = "art_censoring") %>%
  group_by(start, fup_art_uncensored) %>%
  summarise(sum_art_censored = sum(art_censoring),
            n = n(),
            .groups = "drop")
# No of people experiencing an outcome per time interval
split_trt_outcome <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts,
            start = "start",
            zero = 0,
            end = "fup_obs",
            event = "outcome_obs") %>%
  group_by(start, fup_obs) %>%
  summarise(sum_outcome = sum(outcome_obs),
            n = n(),
            .groups = "drop")
# Calculate weights
weights_trt <-
  split_trt_art_censoring %>%
  left_join(split_trt_outcome,
            by = c("start", "fup_art_uncensored" = "fup_obs", "n")) %>%
  mutate(p_uncensored = (n - sum_art_censored) / (n),
         weight = 1 / p_uncensored) %>%
  rename(end = fup_art_uncensored) %>%
  select(start, end, weight) %>%
  mutate(cum_weight = cumprod(weight))
# Split data set and add weights to data
data_trt_split <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts,
            start = "start",
            zero = 0,
            end = "fup_obs",
            event = "outcome_obs") %>%
  full_join(weights_trt,
            by = c("start" = "start", "fup_obs" = "end"))





survfit(Surv(start, fup_obs, outcome_obs == 1) ~ 1, 
        data_notrt_split, 
        weights = cum_weight) %>% summary()
survfit(Surv(start, fup_obs, outcome_obs == 1) ~ 1, 
        data_notrt_split) %>% summary()

survfit(Surv(start, fup_obs, outcome_obs == 1) ~ 1, 
        data_trt_split, 
        weights = cum_weight) %>% summary()
survfit(Surv(start, fup_obs, outcome_obs == 1) ~ 1, 
        data_trt_split) %>% summary()


data_ccw <-
  rbind(data_notrt_split,
        data_trt_split)
data_ccw %>%
  group_by(arm, outcome_obs) %>%
  tally()

pooled_logreg_fit_ccw <- 
  glm(outcome_obs ~ arm + lspline(fup_obs, 1), 
      family = binomial(link = "logit"),
      weights = cum_weight,
      data = data_ccw)
pooled_logreg_fit_ccw$coefficients[2] %>% exp()

coxph(Surv(start, fup_obs, outcome_obs == 1) ~ arm,
      data = data_ccw,
      weights = cum_weight)



glm(outcome_obs ~ arm,
    family = binomial(link = "logit"),
    data = data_ccw)
library(rms)










# TBC
cuts <- data_trt$fup_obs %>% unique()
split_art_censoring <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts, 
            start = "start",
            zero = 0,
            end = "fup_art_uncensored",
            event = "art_censoring") %>%
  group_by(start, fup_art_uncensored) %>%
  summarise(sum_art_censored = sum(art_censoring),
            n = n(),
            .groups = "drop")
split_outcome <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts,
            start = "start",
            zero = 0,
            end = "fup_obs",
            event = "outcome_obs") %>%
  group_by(start, fup_obs) %>%
  summarise(sum_outcome = sum(outcome_obs),
            n = n(),
            .groups = "drop")
weights <-
  split_art_censoring %>%
  left_join(split_outcome,
            by = c("start", "fup_art_uncensored" = "fup_obs", "n")) %>%
  mutate(p_uncensored = (n - sum_art_censored - sum_outcome) / (n - sum_outcome),
         weight = 1 / p_uncensored)

data_trt_split <- 
  data_trt %>%
  survSplit(data = .,
            cut = cuts,
            start = "start",
            zero = 0,
            end = "fup_obs",
            event = "outcome_obs")

data_trt_split <- 
  data_trt_split %>%
  full_join(weights,
            by = c("start" = "start", "fup_obs" = "fup_art_uncensored"))

data_syn <- 
  rbind(data_notrt_split,
        data_trt_split)

coxph(Surv(start, fup_obs, outcome_obs) ~ treatment_syn,
      data = data_syn)
survfit(Surv(start, fup_obs, outcome_obs) ~ treatment_syn,
        data = data_syn) %>% summary()

coxph(Surv(start, fup_obs, outcome_obs) ~ treatment_syn,
      data = data_syn,
      weights = weight) %>% summary()
survfit(Surv(start, fup_obs, outcome_obs) ~ treatment_syn,
        data = data_syn,
        weights = weight) %>% summary()
survfit(Surv(start, fup, outcome) ~ treatment_syn,
        data = data_syn) %>% summary()

         
