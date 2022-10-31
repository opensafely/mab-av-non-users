################################################################################
#
# TABLE S3 breakdown of primary outcome in patients surviving to at least day 5
# primary outcome is covid hosp or death, this table provides a breakdown in 
# hosp and death
#
# This script can be run via an action in project.yaml using one argument:
# - 'data_label' /in {day0, day2, day4, day4, day5} --> day
#
# This script can be run via an action in project.yaml
# It combines various tables to table S3 in the supplements
# saved in:
# ./output/tables_joined/tableS3_'data_label'.csv
################################################################################

################################################################################
# 00. Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)
library(tidyr)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create tables directory
fs::dir_create(here("output", "tables_joined"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to day5-2 or day0 data, default is day5
if (length(args) == 0){
  data_label = "day5"
} else if (args[[1]] == "day0") {
  data_label = "day0"
} else if (args[[1]] == "day5") {
  data_label = "day5"
} else if (args[[1]] == "day4") {
  data_label = "day4"
} else if (args[[1]] == "day3") {
  data_label = "day3"
} else if (args[[1]] == "day2") {
  data_label = "day2"
} else {
  # Print error if no argument specified
  stop("No day specified")
}

################################################################################
# 0.3 Load data
################################################################################
# where can counts be found?
ba1_n_outcome_dayx <- 
  read_csv(here::here("output", "counts", 
                      paste0("counts_n_outcome_", data_label, "_crude.csv")))
ba2_n_outcome_dayx <- 
  read_csv(here::here("output", "counts",
                      paste0("counts_n_outcome_", data_label, "_crude_ba2.csv")))
ba1_dayx_all <- 
  read_csv(here::here("output", "data_properties",
                      paste0(data_label, "_all.csv")))
ba2_dayx_all <- 
  read_csv(here::here("output", "data_properties",
                      paste0("ba2_", data_label, "_all.csv")))

################################################################################
# 0.3 Functions needed for reformatting
################################################################################
reformat_total <- function(count_n_outcome_crude){
  count_n_outcome_crude <- 
    count_n_outcome_crude %>%
    filter(comparison == "All") %>%
    select(c(n_outcome_untreated, n_outcome_mol, n_outcome_sot)) %>%
    mutate(across(everything(), ~ as.character(.x))) %>%
    rename(Untreated = n_outcome_untreated,
           Molnupiravir = n_outcome_mol,
           Sotrovimab = n_outcome_sot) %>%
    pivot_longer(names_to = "treatment_strategy_cat",
                 values_to = "n_total",
                 cols = c(Untreated, Molnupiravir, Sotrovimab))
}
reformat_subtotals <- function(day5_all){
  day5_all <- 
    day5_all %>%
    filter(status_all %in% c("covid_hosp", "covid_death")) %>%
    select(status_all, treatment_strategy_cat, n_redacted_rounded) %>%
    pivot_wider(names_from = status_all,
                values_from = n_redacted_rounded)
}
outcomes_period <- function(count_n_outcome_crude,
                            day5_all){
  count_n_outcome_crude <- reformat_total(count_n_outcome_crude)
  day5_all <- reformat_subtotals(day5_all)
  S3_period <-
    count_n_outcome_crude %>%
    left_join(day5_all, by = "treatment_strategy_cat")
}

################################################################################
# 1. Create table S3
################################################################################
ba1_tableS3 <- outcomes_period(ba1_n_outcome_dayx,
                               ba1_dayx_all)
ba2_tableS3 <- outcomes_period(ba2_n_outcome_dayx,
                               ba2_dayx_all)
# join 2 together
tableS3 <- 
  ba1_tableS3 %>%
  left_join(ba2_tableS3, 
            by = "treatment_strategy_cat",
            suffix = c(".ba1", ".ba2"))

################################################################################
# 2. Save output
################################################################################
write_csv(tableS3,
          here::here("output", "tables_joined", 
                     paste0("tableS3", 
                            "_"[data_label != "day5"],
                            data_label[data_label != "day5"], ".csv")))
