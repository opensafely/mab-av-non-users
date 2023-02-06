################################################################################
#
# Processing data flowchart
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# -./output/data/'period'_data_processed.rds
# (if period == ba1, no prefix is used)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(here)
library(readr)
library(dplyr)
library(purrr)
library(fs)

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "data"))

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
input_filename <- 
  if (period == "ba1"){
    "input_flowchart.csv.gz"
  } else if (period == "ba2"){
    "input_flowchart_ba2.csv.gz"
  }
input_file <- here::here("output", input_filename)
data_processed <- 
  read_csv(input_file, 
           col_types = cols_only(
           patient_id = col_integer(),
           prev_treated = col_logical(),
           covid_positive_prev_90_days = col_logical(),
           any_covid_hosp_prev_90_days = col_logical(),
           in_hospital_when_tested = col_logical()))

################################################################################
# 2 Save data
################################################################################
write_rds(data_processed,
          here::here("output", "data", 
                     paste0(
                       period[!period == "ba1"], "_"[!period == "ba1"],
                       "data_flowchart_processed.rds")
          )
)