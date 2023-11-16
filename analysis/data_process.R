################################################################################
#
# Processing data
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# -./output/data/'period'_data_processed.rds
# - ./output/data_properties/'period'_n_excluded.rds
# (if period == ba1, no prefix is used)
# 
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library('dplyr')
library('lubridate')
library('here')
library('readr')
library('purrr')
## Import custom user functions
source(here::here("analysis", "data_import", "extract_data.R"))
source(here::here("analysis", "data_import", "process_data.R"))
source(here::here("analysis", "data_import", "calc_n_excluded.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "data"))
fs::dir_create(here::here("output", "data_properties"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
  # import globally defined study dates and convert to "Date"
  study_dates <-
    jsonlite::read_json(path = here::here("lib", "design", "study-dates.json")) %>%
    map(as.Date)
} else if (args[[1]] == "ba1") {
  period = "ba1"
  # import globally defined study dates and convert to "Date"
  study_dates <-
    jsonlite::read_json(path = here::here("lib", "design", "study-dates.json")) %>%
    map(as.Date)
} else if (args[[1]] == "ba2") {
  period = "ba2"
  # import globally defined study dates and convert to "Date"
  study_dates <-
    jsonlite::read_json(path = here::here("lib", "design", "study-dates-ba2.json")) %>%
    map(as.Date)
} else {
  # Print error if no argument specified
  stop("No period specified")
}

################################################################################
# 1 Import data
################################################################################
input_filename <- 
  if (period == "ba1"){
    "input.csv.gz"
  } else if (period == "ba2"){
    "input_ba2.csv.gz"
  }
data_extracted <- extract_data(input_filename)
# change data if run using dummy data
if(Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")){
  data_extracted <- 
    data_extracted %>%
    mutate(death_date =
             if_else(!is.na(died_ons_covid_any_date), died_ons_covid_any_date, death_date),
           date_treated = if_else(!is.na(date_treated),
                                  covid_test_positive_date + runif(nrow(data_extracted), 0, 4) %>% round(),
                                  NA_Date_),
           paxlovid_covid_therapeutics = if_else(!is.na(paxlovid_covid_therapeutics),
                                                 date_treated,
                                                 NA_Date_),
           sotrovimab_covid_therapeutics = if_else(!is.na(sotrovimab_covid_therapeutics),
                                                   date_treated,
                                                   NA_Date_),
           molnupiravir_covid_therapeutics = if_else(!is.na(molnupiravir_covid_therapeutics),
                                                     date_treated,
                                                     NA_Date_)) 
}

################################################################################
# 2 Process data
################################################################################
# FIXME: currently slow (but working) due to use of rowwise in combination with
# nth()/first()
data_processed <- 
  map(.x = list(4, 3, 2),
      .f = ~ process_data(data_extracted, treat_window_days = .x))
names(data_processed) <- c("grace5", "grace4", "grace3")
# change data if run using dummy data
if(Sys.getenv("OPENSAFELY_BACKEND") %in% c("", "expectations")){
  data_processed <- 
    map(.x = data_processed,
        .f = ~ .x %>% group_by(patient_id) %>%
          mutate(study_week = runif(1, 0, 12) %>% ceiling(),
                 tb_postest_vacc_cat = sample(c(">= 84 days or unknown", "< 7 days", "7-27 days", "28-83 days"), 1) %>%
                   factor(levels = c(">= 84 days or unknown", "< 7 days", "7-27 days", "28-83 days"))) %>%
          ungroup() %>%
          mutate(ageband = if_else(is.na(ageband), "18-39", ageband %>% as.character()) %>%
                   factor(levels = c("18-39", "40-59", "60-79", "80+"))))
}

################################################################################
# 3 Apply additional eligibility and exclusion criteria
################################################################################
# calc n excluded
n_excluded <- calc_n_excluded(data_processed$grace5)
data_processed <-
  map(.x = data_processed, 
      .f = ~ .x %>%
        # Exclude patients treated with both sotrovimab and molnupiravir on the
        # same day 
        filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
        # Exclude patients hospitalised on day of positive test
        filter(!(status_all %in% c("covid_hosp", "noncovid_hosp", "covid_death", "noncovid_death") &
                   fu_all == 0)) %>%
        # if treated with remidesivir --> exclude
        filter(is.na(remdesivir_covid_therapeutics)))
if (period == "ba1") { # only very few people treated with paxlovid --> exclude
  data_processed <-
    map(.x = data_processed,
        .f = ~ .x %>%
          filter(treatment_paxlovid_prim == "Untreated")
        )
}
cat("Number of people excluded before but included now")
data_processed$grace5 %>%
  filter(!is.na(paxlovid_covid_therapeutics)) %>%
  select(treatment_paxlovid_prim, status_primary) %>%
  table() %>%
  print()

################################################################################
# 4 Save data
################################################################################
# data_processed are saved
iwalk(.x = data_processed,
      .f = ~ write_rds(.x,
                       here::here("output", "data", 
                                  paste0(
                                    period[!period == "ba1"], "_"[!period == "ba1"],
                                    "data_processed",
                                    "_"[!.y == "grace5"],
                                    .y[!.y == "grace5"],
                                    ".rds"))))
write_rds(n_excluded,
          here::here("output", "data_properties",
                     paste0(
                       period[!period == "ba1"], "_"[!period == "ba1"],
                       "n_excluded.rds")))
