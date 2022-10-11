######################################

# crosstabulates outcomes and trt group
######################################

# libraries
library(readr)
library(dplyr)
library(fs)
library(here)

# load data
data_cohort_day5 <- 
  read_rds(here("output", "data", "data_processed_day5.rds"))
data_cohort_day0 <-
  read_rds(here("output", "data", "data_processed_day0.rds"))
data_cohort_day0_4 <-
  data_cohort_day0 %>%
  filter(fu_secondary <= 4)
# create output folders
dir_create(here("output", "data_properties"))
dir_create(here("output", "tables"))

# function used to summarise outcomes
source(here("lib", "functions", "summarise_outcomes.R"))

# pt treated with sotrovimab whose first outcome is not counted as the outcome
cat("#### Sotrovimab recipients whose first outcome is not counted day 0 ####\n")
data_cohort_day0 %>%
  filter(treatment_strategy_cat == "Sotrovimab" &
           covid_hosp_admission_date == covid_hosp_admission_2nd_date0_27) %>%
  nrow() %>% print()
# pt treated with sotrovimab whose first outcome is not counted as the outcome
cat("\n#### Sotrovimab recipients whose first outcome is not counted ####\n")
data_cohort_day5 %>%
  filter(treatment_strategy_cat == "Sotrovimab" &
           covid_hosp_admission_date == covid_hosp_admission_2nd_date0_27) %>%
  nrow() %>% print()
# pt treated with sotrovimab who has a first outcome but that outcome is not counted
# as an outcome
cat("\n#### Sotrovimab recipients with a first outcome not counted day 0 ####\n")
data_cohort_day0 %>%
  filter(treatment_strategy_cat == "Sotrovimab" &
           is.na(covid_hosp_admission_date) & !is.na(covid_hosp_admission_first_date0_6)) %>%
  nrow() %>% print()
# pt treated with sotrovimab who has a first outcome but that outcome is not counted
# as an outcome
cat("\n#### Sotrovimab recipients with a first outcome not counted day 5 ####\n")
data_cohort_day5 %>%
  filter(treatment_strategy_cat == "Sotrovimab" &
           is.na(covid_hosp_admission_date) & !is.na(covid_hosp_admission_first_date0_6)) %>%
  nrow() %>% print()
# All cause hosp and covid hosp on same date?
cat("\n#### All cause hosp and covid hosp on same date? ####\n")
data_cohort_day5 %>% 
  filter(allcause_hosp_admission_date == covid_hosp_admission_date) %>%
  nrow() %>% print()

# pt hospitalised before treatment
cat("\n#### Treated individuals whose date of treatment is after covid hospital admission ####\n")
data_cohort_day0 %>%
  filter(treatment == "Treated" &
           covid_hosp_admission_date < date_treated) %>%
  group_by(treatment_strategy_cat) %>%
  summarise(n = n()) %>% print()
cat("\n#### Treated individuals whose date of treatment is after all-cause hospital admission ####\n")
data_cohort_day0 %>%
  filter(treatment == "Treated" &
           allcause_hosp_admission_date < date_treated) %>%
  group_by(treatment_strategy_cat) %>%
  summarise(n = n()) %>% print()
cat("\n#### Treated individuals whose date of treatment is after non-covid hospital admission ####\n")
data_cohort_day0 %>%
  filter(treatment == "Treated" &
           noncovid_hosp_admission_date < date_treated) %>%
  group_by(treatment_strategy_cat) %>%
  summarise(n = n()) %>% print()
cat("\n#### Treated individuals with non covid and covid hosp on same day ####\n")
data_cohort_day0 %>%
  filter(treatment == "Treated" &
           noncovid_hosp_admission_date == covid_hosp_admission_date) %>%
  summarise(n = n()) %>% print()


cat("\n#### Overview of treatment groups in day 5 analysis ####\n")
data_cohort_day0 %>%
  group_by(treatment_strategy_cat) %>%
  summarise(n = n()) %>% print()
data_cohort_day0 %>%
  group_by(treatment) %>%
  summarise(n = n()) %>% print()
cat("\n#### Overview of treatment groups in day 0 analysis ####\n")
cat("#### PRIMARY ####")
data_cohort_day0 %>%
  group_by(treatment_strategy_cat_day0_prim) %>%
  summarise(n = n()) %>% print()
data_cohort_day0 %>%
  group_by(treatment_strategy_cat_day0_sec) %>%
  summarise(n = n()) %>% print()
cat("#### SECONDARY ####")
data_cohort_day0 %>%
  group_by(treatment_day0_prim) %>%
  summarise(n = n()) %>% print()
data_cohort_day0 %>%
  group_by(treatment_day0_sec) %>%
  summarise(n = n()) %>% print()

# table of diagnoses of all cause hospitalisation
# data_cohort_day5 %>%
#   filter(!is.na(allcause_hosp_admission_date)) %>%
#   group_by(treatment_strategy_cat, allcause_hosp_diagnosis) %>%
#   summarise(n = n(), .groups = "keep") %>%
#   mutate(n_redacted = case_when(n <= 5 ~ "<=5",
#                                 TRUE ~ n %>% as.character())) %>%
#   select(-n) %>%
#   write_csv(path(here("output", "data_properties"), 
#                  "day5_allcause_hosp_diagnosis.csv"))

# crosstabulation trt x outcomes
cat("#### cohort day 5-27, primary outcome ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_primary, 
                   status_primary,
                   "day5_primary.csv")
cat("\n#### cohort day 5-27, secondary outcome ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_secondary, 
                   status_secondary,
                   "day5_secondary.csv")
cat("\n#### cohort day 5-27, all outcomes ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_all, 
                   status_all,
                   "day5_all.csv")
cat("\n#### cohort day 0-27, primary outcome ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_primary, 
                   status_primary,
                   "day0_primary.csv")
cat("\n#### cohort day 0-27, secondary outcome ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_secondary, 
                   status_secondary,
                   "day0_secondary.csv")
cat("\n#### cohort day 0-27, all outcomes ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_all, 
                   status_all,
                   "day0_all.csv")
cat("\n#### cohort day 0-4, primary outcome ####\n")
summarise_outcomes(data_cohort_day0_4, 
                   fu_primary, 
                   status_primary,
                   "day0_4_primary.csv")
cat("\n#### cohort day 0-4, secondary outcome ####\n")
summarise_outcomes(data_cohort_day0_4, 
                   fu_secondary, 
                   status_secondary,
                   "day0_4_secondary.csv")
cat("\n#### cohort day 0-4, all outcomes ####\n")
summarise_outcomes(data_cohort_day0_4, 
                   fu_all, 
                   status_all,
                   "day0_4_all.csv")


# flowchart
n_total <- data_cohort_day0 %>% nrow()
n_treated <- data_cohort_day0 %>%
  filter(treatment == "Treated") %>%
  nrow()
n_treated_sot <- data_cohort_day0 %>%
  filter(treatment == "Treated" & treatment_strategy_cat == "Sotrovimab") %>%
  nrow()
n_treated_mol <- data_cohort_day0 %>%
  filter(treatment == "Treated" & treatment_strategy_cat == "Molnupiravir") %>%
  nrow()
n_untreated <- data_cohort_day0 %>%
  filter(treatment == "Untreated") %>%
  nrow()
n_hosp_death_treated <- data_cohort_day0 %>%
  filter(treatment == "Treated" & fu_secondary <= 4) %>%
  nrow()
n_hosp_death_treated_sot <- data_cohort_day0 %>%
  filter(treatment == "Treated" & fu_secondary <= 4 & treatment_strategy_cat == "Sotrovimab") %>%
  nrow()
n_hosp_death_treated_mol <- data_cohort_day0 %>%
  filter(treatment == "Treated" & fu_secondary <= 4 & treatment_strategy_cat == "Molnupiravir") %>%
  nrow()
n_hosp_death_untreated <- data_cohort_day0 %>%
  filter(treatment == "Untreated" & fu_secondary <= 4) %>%
  nrow
cat("#####check for any na's in fu_secondary (should be FALSE)#####\n")
print(any(is.na(data_cohort_day0$fu_secondary)))
n_treated_day5 <- data_cohort_day5 %>%
  filter(treatment == "Treated") %>%
  nrow()
n_treated_day5_sot <- data_cohort_day5 %>%
  filter(treatment == "Treated" & treatment_strategy_cat == "Sotrovimab") %>%
  nrow()
n_treated_day5_mol <- data_cohort_day5 %>%
  filter(treatment == "Treated" & treatment_strategy_cat == "Molnupiravir") %>%
  nrow()
n_untreated_day5 <- data_cohort_day5 %>%
  filter(treatment == "Untreated") %>%
  nrow()
# combine in one table
flowchart <-
  tibble(
    total = n_total,
    treated = n_treated,
    treated_sot = n_treated_sot,
    treated_mol = n_treated_mol,
    untreated = n_untreated,
    hosp_death_treated = n_hosp_death_treated,
    hosp_death_treated_sot = n_hosp_death_treated_sot,
    hosp_death_treated_mol = n_hosp_death_treated_mol,
    hosp_death_untreated = n_hosp_death_untreated,
    treated_day5 = n_treated_day5,
    treated_day5_sot = n_treated_day5_sot,
    treated_day5_mol = n_treated_day5_mol,
    untreated_day5 = n_untreated_day5
  )
# redact (simple redaction, round all to nearest 5)
flowchart_redacted <- 
  flowchart %>%
    mutate(across(where(is.integer), ~ plyr::round_any(.x, 5)))
# Save flowcharts
write_csv(flowchart, path(here("output", "data_properties", "flowchart.csv")))
write_csv(flowchart_redacted, path(here("output", "tables", "flowchart_redacted.csv")))
