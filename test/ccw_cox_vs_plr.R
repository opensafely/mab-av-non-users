################################################################################
# 0.1 Load functions
################################################################################
source(here("analysis", "data_ccw", "simplify_data.R"))
source(here("analysis", "data_ccw", "clone_data.R"))
source(here("analysis", "data_ccw", "add_x_days_to_fup.R"))
source(here("analysis", "models_ccw", "cox_cens.R"))
source(here("analysis", "models_ccw", "plr_cens.R"))
################################################################################
# 0.2 Load data
################################################################################
data_filename <- paste0("data_processed", ".rds")
data <- read_rds(here::here("output", "data", data_filename))
# change data if run using dummy data
if(Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")){
  data <- 
    data %>%
    mutate(study_week = runif(nrow(data), 1, 14) %>% floor())
}
################################################################################
# 0.3 Prepare data and clone data
################################################################################
data <- ccw_simplify_data(data, "primary", "all", "full")
data_cloned <- 
  clone_data(data) %>%
  add_x_days_to_fup(0.5) %>%
  mutate(treatment_ccw_01 = if_else(treatment_ccw == "Treated", 1, 0))
################################################################################
# 0.4 Covars
################################################################################
covars_formula <- "1"

################################################################################
# 1 LOGREG
################################################################################
logreg_trt_formula <- paste0("treatment_ccw_01 ~ ",
                             paste0(covars_formula, collapse = " + "))
# probability to being treated
logreg_trt <- glm(formula = logreg_trt_formula,
                  family = binomial(link = "logit"),
                  data = data_cloned %>% filter(arm == "Treatment"))
data_cloned %>% 
  filter(arm == "Treatment") %>% 
  group_by(treatment_ccw_01) %>%
  tally()
2026 / (2026 + 28215)
1 / (1 + exp(-logreg_trt$coefficients))
# 2026 are treated so remain uncensored, but not all who are untreated remain
# in the at risk set until day 4.5, as some experience outcomes before that, and
# are therefore also uncensored
data_cloned %>% 
  filter(arm == "Treatment" & treatment_ccw_01 == 0 & fu_ccw <= 4.5) %>% 
  nrow()
# 1261 untrt have a follow up shorter or equal to 4.5, meaning that 2026 + 1261 are
# artificially uncensored = 3287 [2026 patients who are treated are not censored]
data_cloned %>%
  filter(arm == "Treatment") %>%
  group_by(censoring) %>%
  tally()
# P(art uncensored) = 3287 / (3287 + 26954)
# probability to remaining uncensored (~ = being treated)
logreg_cens_formula <- paste0("censoring ~ ",
                              paste0(covars_formula, collapse = " + "))
# probability of being censored
logreg_cens <- glm(formula = logreg_cens_formula,
                   family = binomial(link = "logit"),
                   data = data_cloned %>% filter(arm == "Treatment"))
3287 / (3287 + 26954)
# P(art uncensored) = 1 - P(art censored)
1 - (1 / (1 + exp(-logreg_cens$coefficients)))
# In the two probabilities above, the at risk set is the full population.
# However, some people leave the at risk population beause they experience an 
# outcome in the grace period (0-4.5].
km_cens <- survfit(Surv(fup, censoring) ~ 1,
                   data = data_cloned %>% filter(arm == "Treatment"))
broom::tidy(km_cens)
1 - (26954 / 29372)
# The probability of remaining uncensored [S(4.5) = P(T > 4.5)] is 0.0823. Which
# is 1 minus the probability of being censored given that you're still at risk 
# in time interval (3.5-4.5]
data_cloned %>%
  filter(arm == "Treatment" & fup < 4.5) %>% nrow() # 869 lost to fup
29372 + 869 # total pop
# Which is the same as the probability of being treated given that you survive 
# until at least day 4.5 
data_cloned %>%
  filter(arm == "Treatment" & fup >= 4.5) %>%
  group_by(treatment_ccw_01, censoring) %>%
  tally()
# Individuals who are untreated but experience an outcome on day 4.5 are not 
# artificially censored.. They are however not treated.. The probability of 
# being treated given that you survive to at least (3.5-4.5] is therefore not 
# equal to the probability of being censored.
logreg_trt_4 <- glm(formula = logreg_trt_formula,
                    family = binomial(link = "logit"),
                    data = data_cloned %>% filter(arm == "Treatment" & fup >= 4.5))
(1 / (1 + exp(-logreg_trt_4$coefficients)))
data_cloned %>%
  filter(arm == "Treatment" & fup >= 4.5) %>%
  group_by(treatment_ccw_01) %>% tally()
data_cloned %>%
  filter(arm == "Treatment" & fup >= 4.5) %>%
  group_by(censoring) %>% tally()
2418 - 1999 # difference of 419, 419 are untreated but UNcensored because they
# experience an outcome in the last interval (3.5; 4.5].
# if we put censoring = 1 when someone experiences an outcome in interval (3.5-4.5],
# this discrepancy is solved. Not sure if that's needed though...? You don't want to 
# replace these 419 people as they've left the at risk set beyond 4.5
# We could however use the variable censoring in a logreg
logreg_cens <- glm(formula = censoring ~ 1,
                   family = binomial(link = "logit"),
                   data = data_cloned %>% filter(arm == "Treatment" & fup >= 4.5))
1 - (1 / (1 + exp(-logreg_cens$coefficients)))


# POOLED LOGREG
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


km_trt_long <- survfit(Surv(tstart, fup, censoring) ~ 1,
                       data = data_trt_long)
broom::tidy(km_trt_long)
1 - (1 / (1 + exp(-logreg_cens$coefficients)))
cox_trt_long <- coxph(Surv(tstart, fup, censoring) ~ 1,
                      data = data_trt_long)
basehaz_trt_cens <- basehaz(cox_trt_long)
exp(-basehaz_trt_cens$hazard)

data_control_long_4.5 <- data_control_long %>% filter(tstart <= 4.5)
plr_control_long <- glm(censoring ~ ns(fup, 4),
                        family = binomial(link = "logit"), 
                        data = data_control_long_4.5)
data_control_long_4.5 <-
  data_control_long_4.5 %>%
  mutate(p_uncens = 1 - predict(plr_control_long, type = "response")) %>%
  group_by(patient_id) %>%
  mutate(lag_p_uncens = lag(p_uncens, default = 1),
         cmlp_uncens = cumprod(lag_p_uncens)) %>%
  ungroup()

data_control_long_4.5 %>% filter(patient_id == 223254) %>% select(arm, tstart, fup, outcome, censoring, p_uncens, lag_p_uncens, cmlp_uncens)


data_control_long_4.5 %>%
  select(arm, tstart, fup, outcome, censoring, p_uncens, lag_p_uncens, cmlp_uncens) %>%
  View()


cens_control_long <-
  survfit(Surv(tstart, fup, censoring) ~ 1,
          data = data_control_long_4.5)
broom::tidy(cens_control_long)


View(data_long %>% filter(patient_id == 123836) %>% select(arm, tstart, fup, outcome, censoring, cmlp_uncens, cmlp_uncens_plr, weight))
View(data_long %>% filter(patient_id == 124639) %>% select(arm, tstart, fup, outcome, censoring, cmlp_uncens, cmlp_uncens_plr, weight))
View(data_long %>% filter(patient_id == 279020) %>% select(arm, tstart, fup, outcome, censoring, cmlp_uncens, cmlp_uncens_plr, weight))

