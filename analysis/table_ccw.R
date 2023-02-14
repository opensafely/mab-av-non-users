################################################################################
#
# CCW RESULTS
#
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# It combines the tables containing the ccw results to one table
# original tables:
# ./output/tables/ccw/['period'_]ccw_['contrast'_]['outcome'].csv
# combined to one table saved as:
# ./output/tables/['period'_]table_ccw.html
# note if 'period' == ba1, no prefix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)
library(gt)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create tables directory
fs::dir_create(here("output", "tables"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly = TRUE)
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
# 0.2 Search files
################################################################################
pattern <- if_else(period == "ba1", "^ccw", "^ba2_ccw")
files <- 
  list.files(here("output", "tables", "ccw"),
             pattern = pattern, 
             full.names = TRUE)

################################################################################
# 0.3 Import output from ccw analysis
################################################################################
output <- 
  map_dfr(.x = files, 
          .f = ~ read_csv(.x, 
                          col_types = 
                            cols_only(period = col_character(),
                                      outcome = col_character(),
                                      contrast = col_character(),
                                      HR = col_double(),
                                      HR_lower = col_double(),
                                      HR_upper = col_double(),
                                      diff_surv = col_double(),
                                      diff_surv_lower = col_double(),
                                      diff_surv_upper = col_double(),
                                      diff_RMST = col_double(),
                                      diff_RMST_lower = col_double(),
                                      diff_RMST_upper = col_double())) %>%
            mutate(across(where(~ is.double(.x)), ~ round(.x, 2)))
  ) # round to second decimal

################################################################################
# 0.4 Function needed to format output
################################################################################
format_output <- function(output, measure){
  measure_lower <- paste0(measure, "_lower")
  measure_upper <- paste0(measure, "_upper")
  output_formatted <- 
    output %>%
    mutate("{measure}" := 
             paste0(.data[[measure]],
                    " (",
                    .data[[measure_lower]],
                    ";",
                    .data[[measure_upper]],
                    ")")) %>%
    select(period, outcome, contrast, measure)
  output_formatted
}

################################################################################
# 1. Format output
################################################################################
output_formatted <-
  map(.x = c("HR", "diff_surv", "diff_RMST"),
      .f = ~ format_output(output, .x))
output_combined <-
  output_formatted %>%
  reduce(full_join, by = c("period", "outcome", "contrast")) %>%
  arrange(period, outcome, contrast)

################################################################################
# 2. Save
################################################################################
file_name <- 
  paste0(period[period != "ba1"], "_"[period != "ba1"], "table_ccw.html")
gtsave(gt(output_combined), 
       filename = here::here("output", "tables", file_name))
