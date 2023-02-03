################################################################################
#
# Tabularise outcomes in different data files
# 
# This script can be run via an action in project.yaml using one argument
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# empty file ./output/data_properties/'period'_sense_check.txt
# (if period == ba1, no sufffix is used)
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
fs::dir_create(here("output", "data_properties"))

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
# 0.3 Import data
################################################################################
data <-
  read_rds(here("output", "data", 
                paste0(period[period != "ba1"], "_"[period != "ba1"],
                       "data_processed.rds")))

################################################################################
# Count outcomes
################################################################################
cat("\n************************************\n")
cat("Crude outcomes\n")
data %>%
  summarise(n_death = sum(!is.na(death_date)),
            n_covid_death = sum(!is.na(covid_death_date)),
            n_noncovid_death = sum(!is.na(noncovid_death_date)),
            n_hosp = sum(!is.na(allcause_hosp_admission_date)),
            n_covid_hosp = sum(!is.na(covid_hosp_admission_date)),
            n_noncovid_hosp = sum(!is.na(noncovid_hosp_admission_date))) %>%
  print()
cat("\n All outcomes \n")
data %>%
  group_by(status_all) %>%
  tally() %>%
  print()
cat("\n Primary outcomes \n")
data %>%
  group_by(status_primary) %>%
  tally() %>%
  print()
cat("\n Secondary outcomes \n")
data %>%
  group_by(status_secondary) %>%
  tally() %>%
  print()
cat("\n Non-corresponding outcomes [all and primary] \n")
data %>%
  filter(min_date_all != min_date_primary) %>%
  group_by(status_all, status_primary) %>%
  tally()
cat("\n Non-corresponding outcomes [all and secondary] \n")
data %>%
  filter(min_date_all != min_date_secondary) %>%
  group_by(status_all, status_secondary) %>%
  tally()
cat("\n Non-corresponding outcomes [primary and secondary] \n")
data %>%
  filter(min_date_primary != min_date_secondary) %>%
  group_by(status_primary, status_secondary) %>%
  tally()
cat("\n************************************\n")

cat("\n************************************\n")
cat("\n Treatment categorisation times PRIMARY event\n")
cat("crude\n")
data %>%
  group_by(treatment, status_primary) %>%
  tally() %>% print()
cat("treatment before or on date of event removed\n")
data %>%
  group_by(treatment_prim, status_primary) %>%
  tally() %>% print()
cat("number of treatment before or on date of event\n")
data %>%
  filter(treatment == "Treated" & treatment_prim == "Untreated") %>%
  tally() %>% print()
cat("number of people treated on date of event")
data %>%
  filter(status_primary %in% c("covid_hosp_death", "noncovid_death", "dereg") & 
           treatment_date == min_date_all) %>%
  group_by(treatment, status_primary) %>%
  tally() %>% print()
cat("distribution of tb_postest_treat in treated (treatment_prim)")
data %>%
  filter(treatment_prim == "Treated") %>%
  pull(tb_postest_treat) %>%
  quantile() %>% print()
cat("\n Treatment categorisation times SECONDARY event\n")
cat("crude\n")
data %>%
  group_by(treatment, status_secondary) %>%
  tally() %>% print()
cat("treatment before or on date of event removed\n")
data %>%
  group_by(treatment_sec, status_secondary) %>%
  tally() %>% print()
cat("number of treatment before or on date of event\n")
data %>%
  filter(treatment == "Treated" & treatment_sec == "Untreated") %>%
  tally() %>% print()
cat("number of people treated on date of event")
data %>%
  filter(status_secondary %in% c("allcause_hosp_death", "dereg") & 
           treatment_date == min_date_all) %>%
  group_by(treatment, status_secondary) %>%
  tally() %>% print()
cat("\n************************************\n")

writeLines("see log file", 
           here("output", "data_properties", 
                paste0(period[!period == "ba1"],
                       "_"[!period == "ba1"],
                       "sense_checks.txt")))
