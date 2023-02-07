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

################################################################################
# 2 Process data
################################################################################
# FIX ME: currently slow (but working) due to use of rowwise in combination with
# nth()/first()
data_processed <- process_data(data_extracted)

################################################################################
# 3 Apply additional eligibility and exclusion criteria
################################################################################
# calc n excluded
n_excluded <- calc_n_excluded(data_processed)
data_processed <-
  data_processed %>%
  # Exclude patients treated with both sotrovimab and molnupiravir on the
  # same day 
  filter(treated_sot_mol_same_day  == 0) %>%
  # Exclude patients hospitalised on day of positive test
  filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
           fu_all == 0)) %>%
  # if treated with paxlovid or remidesivir --> exclude
  filter(is.na(paxlovid_covid_therapeutics) &
           is.na(remdesivir_covid_therapeutics))

################################################################################
# 4 Save data
################################################################################
# data_processed are saved
write_rds(data_processed,
          here::here("output", "data", 
                     paste0(
                       period[!period == "ba1"], "_"[!period == "ba1"],
                       "data_processed.rds")))
write_rds(n_excluded,
          here::here("output", "data_properties",
                     paste0(
                       period[!period == "ba1"], "_"[!period == "ba1"],
                       "n_excluded.rds")))
