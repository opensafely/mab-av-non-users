################################################################################
#
# Numbers for flowchart
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# -./output/data_properties/'period'_flowchart.csv
# (if period == ba1, no prefix is used)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
library(here)
library(readr)
library(dplyr)
library(fs)

################################################################################
# 0.1 Create directories for output
################################################################################
output_dir <- here::here("output", "tables", "flowchart")
fs::dir_create(output_dir)

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
# 1 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_flowchart_processed", ".rds")
n_excluded_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "n_excluded", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))
n_excluded_in_data_processing <-
  read_rds(here::here("output", "data_properties", n_excluded_filename))

################################################################################
# 2 Calc numbers
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
total_n <- nrow(data)
# previously treated
prev_treated <- 
  data %>%
  filter(prev_treated == TRUE) %>% 
  nrow()
# not previously treated but evidence of covid < 90 days
tested_positive <- 
  data %>%
  filter(prev_treated == FALSE) %>%
  filter(covid_positive_prev_90_days == TRUE |
           any_covid_hosp_prev_90_days == TRUE ) %>%
  nrow()
# not previously treated and no evidence of covid < 90 days but in hospital
in_hospital_when_tested <- 
  data %>%
  filter(prev_treated == FALSE) %>%
  filter(covid_positive_prev_90_days == FALSE &
           any_covid_hosp_prev_90_days == FALSE) %>%
  filter(in_hospital_when_tested == TRUE) %>% 
  nrow()
# included
total_n_included <- 
  data %>%
  filter(prev_treated == FALSE) %>%
  filter(covid_positive_prev_90_days == FALSE &
           any_covid_hosp_prev_90_days == FALSE) %>%
  filter(in_hospital_when_tested == FALSE) %>% 
  nrow()
# combine numbers
out <-
  tibble(total_n,
         prev_treated,
         tested_positive,
         in_hospital_when_tested,
         total_n_included)
out <- bind_cols(out, n_excluded_in_data_processing) %>%
  tidyr::pivot_longer(everything())
out_redacted <- 
  out %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(.x > 0 & .x <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ .x %>% 
                              plyr::round_any(rounding_threshold) %>% 
                              as.character())))

################################################################################
# 3 Save output
################################################################################
write_csv(x = out,
          path = path(output_dir, 
                      paste0(
                        period[!period == "ba1"], "_"[!period == "ba1"],
                        "flowchart.csv")))
write_csv(x = out_redacted,
          path = path(output_dir, 
                      paste0(
                        period[!period == "ba1"], "_"[!period == "ba1"],
                        "flowchart_redacted.csv")))
