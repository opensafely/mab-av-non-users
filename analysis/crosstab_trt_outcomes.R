################################################################################
#
# Tabularise outcomes in different data files
# 
# This script can be run via an action in project.yaml using one argument
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# 4 .rds files named:
# -./output/tables/flowchart_redacted_'period'.csv
# -./output/data_properties/'flowchart_'period'.csv
# (if period == ba1, no sufffix is used)
#
# in the _day2-5 files, patients are classified as treated if they are treated
# within 2-5 days, respectively; and excluded if they experience an outcome in
# days 2-5, respectively (outcome = all cause death/ hosp or dereg)
# in the day0 file, patients are classified as treated if they are treated within
# 5 days and never excluded
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(readr)
library(dplyr)
library(fs)
library(here)
library(purrr)
# function used to summarise outcomes
source(here("lib", "functions", "summarise_outcomes.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
dir_create(here("output", "data_properties"))
dir_create(here("output", "tables"))

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

################################################################################
# 0.1 Import data
################################################################################
# Treatment assignment window 'treated within 5 days -> <= 4 days' etc
treat_windows <- c(1, 2, 3, 4)
data_filename <- paste0(
  period[period != "ba1"], "_"[period != "ba1"],
  "data_processed_day", treat_windows + 1, ".rds")
data_cohort_dayx_list <- 
  map(.x = data_filename,
      .f = ~ read_rds(here("output", "data", .x)))
names(data_cohort_dayx_list) <- paste0("day", treat_windows + 1)
data_cohort_day0 <-
  read_rds(here("output", "data", 
                paste0(period[period != "ba1"], "_"[period != "ba1"],
                       "data_processed_day0.rds")))
data_cohort_day0_4 <-
  data_cohort_day0 %>%
  filter(fu_secondary <= 4)

################################################################################
# 1 Crosstabulation trt x outcomes
################################################################################
# cohort dayx-27, primary outcome
imap(.x = data_cohort_dayx_list,
     .f = ~ summarise_outcomes(.x,
                               fu_primary,
                               status_primary,
                               paste0(period[period != "ba1"],
                                      "_"[period != "ba1"],
                                       .y, "_primary.csv")))
# cohort dayx-27, secondary outcome
imap(.x = data_cohort_dayx_list,
     .f = ~ summarise_outcomes(.x,
                               fu_secondary, 
                               status_secondary,
                               paste0(period[period != "ba1"],
                                      "_"[period != "ba1"],
                                      .y, "_secondary.csv")))
# cohort dayx-27, sall outcomes
imap(.x = data_cohort_dayx_list,
     .f = ~ summarise_outcomes(.x,
                               fu_all, 
                               status_all,
                               paste0(period[period != "ba1"],
                                      "_"[period != "ba1"],
                                      .y, "_all.csv")))
# day 0 and day 0-4
summarise_outcomes(data_cohort_day0, 
                   fu_primary, 
                   status_primary,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_primary.csv"))
summarise_outcomes(data_cohort_day0, 
                   fu_secondary, 
                   status_secondary,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_secondary.csv"))
summarise_outcomes(data_cohort_day0, 
                   fu_all, 
                   status_all,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_all.csv"))
summarise_outcomes(data_cohort_day0_4, 
                   fu_primary, 
                   status_primary,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_4_primary.csv"))
summarise_outcomes(data_cohort_day0_4, 
                   fu_secondary, 
                   status_secondary,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_4_secondary.csv"))
summarise_outcomes(data_cohort_day0_4, 
                   fu_all, 
                   status_all,
                   paste0(period[period != "ba1"],
                          "_"[period != "ba1"],
                          "day0_4_all.csv"))

################################################################################
# 4 Checks (printed in log file)
################################################################################
data_cohort_day5 <- data_cohort_dayx_list$day5
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

