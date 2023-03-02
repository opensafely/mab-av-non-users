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
library(optparse)
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  model <- "cox"
  subgrp <- "full"
  supp <- "main"
} else {
  
  option_list <- list(
    make_option("--period", type = "character", default = "ba1",
                help = "Period where the analysis is conducted in, options are 'ba1' or 'ba2' [default %default].",
                metavar = "period"),
    make_option("--model", type = "character", default = "cox",
                help = "Model used to estimate probability of remaining uncensored [default %default].",
                metavar = "model"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp"),
    make_option("--supp", type = "character", default = "main",
                help = "Main analysis or supplementary analysis, options are 'main' or 'supp1' [default %default]",
                metavar = "supp")
  )
  
  opt_parser <- OptionParser(usage = "ccw_table:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  model <- opt$model
  subgrp <- opt$subgrp
  supp <- opt$supp
}

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_dir <- 
  concat_dirs("tables", output_dir, model, subgrp, supp)
# Create tables directory
fs::dir_create(tables_dir)

################################################################################
# 0.2 Search files
################################################################################
pattern <- if_else(period == "ba1", "^ccw", "^ba2_ccw")
# directory where tables are saved
tables_ccw_dir <- 
  concat_dirs(fs::path("tables", "ccw"), output_dir, model, subgrp, supp)
files <- 
  list.files(tables_ccw_dir,
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
                                      HR_SE = col_double(),
                                      HR_uw = col_double(),
                                      HR_uw_SE = col_double(),
                                      HR_uw_lower = col_double(),
                                      HR_uw_upper = col_double(),
                                      diff_surv = col_double(),
                                      diff_surv_lower = col_double(),
                                      diff_surv_upper = col_double(),
                                      diff_surv_SE = col_double(),
                                      diff_RMST = col_double(),
                                      diff_RMST_lower = col_double(),
                                      diff_RMST_upper = col_double(),
                                      diff_RMST_SE = col_double())) %>%
            mutate(across(where(~ is.double(.x)), ~ round(.x, 3)))
  ) # round to second decimal

################################################################################
# 0.4 Function needed to format output
################################################################################
format_output <- function(output, measure){
  measure_lower <- paste0(measure, "_lower")
  measure_upper <- paste0(measure, "_upper")
  measure_SE <- paste0(measure, "_SE")
  output_formatted <- 
    output %>%
    mutate("{measure}" := 
             paste0(.data[[measure]],
                    " (",
                    .data[[measure_lower]],
                    ";",
                    .data[[measure_upper]],
                    ")")) %>%
    select(period, outcome, contrast, measure, measure_SE)
  output_formatted
}

################################################################################
# 1. Format output
################################################################################
output_formatted <-
  map(.x = c("HR", "HR_uw", "diff_surv", "diff_RMST"),
      .f = ~ format_output(output, all_of(.x)))
output_combined <-
  output_formatted %>%
  reduce(full_join, by = c("period", "outcome", "contrast")) %>%
  arrange(period, outcome, contrast)

################################################################################
# 2. Save
################################################################################
file_name <- 
  make_filename("table_ccw", period, outcome = "primary", contrast = "", model, subgrp, supp, "html")
gtsave(gt(output_combined), 
       fs::path(tables_dir, file_name))
