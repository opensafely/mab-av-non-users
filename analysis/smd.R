################################################################################
#
# Standardised mean differences
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'outcome' /in {primary, secondary} (--> primary or secondary outcome)
# - 'contrast' /in {all, sotrovimab, molnupiravir} (--> treated vs untreated/ 
#.   sotrovimab vs untreated (excl mol users)/ molnupiravir vs untreated)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(dplyr)
library(readr)
library(purrr)
source(here::here("lib", "functions", "std_diff.R"))
source(here::here("lib", "design", "covars_smd.R"))
source(here::here("analysis", "data_ccw", "spread_data.R"))
source(here::here("lib", "functions", "make_filename.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
# Create directory where output of ccw analysis will be saved
fs::dir_create(here::here("output", "tables", "ccw"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
  contrast = "all"
  outcome = "primary"
} else if (length(args) != 3){
  stop("Three arguments are needed")
} else if (length(args) == 3) {
  if (args[[1]] == "ba1") {
    period = "ba1"
  } else if (args[[1]] == "ba2") {
    period = "ba2"
  }
  if (args[[2]] == "all"){
    contrast = "all"
  } else if (args[[2]] == "molnupiravir"){
    contrast = "Molnupiravir"
  } else if (args[[2]] == "sotrovimab"){
    contrast = "Sotrovimab"
  }
  if (args[[3]] == "primary"){
    outcome = "primary"
  } else if (args[[3]] == "secondary"){
    outcome = "secondary"
  }
} else {
  # Print error if no argument specified
  stop("No period and/or contrast and/or outcome specified")
}

################################################################################
# 0.3 Import data
################################################################################
data_filename <- make_filename("data_long", period, outcome, contrast, "rds")
data_long <- read_rds(here::here("output", "data", data_filename))
# spread data:
# - spread factors in dummy columns
data_long_spread <- spread_data(data_long)

################################################################################
# 1 Calculate standardised mean differences
################################################################################
data_long_spread <- data_long_spread %>% mutate(unweight = 1)
smd <- 
  bind_rows(covars = covars_smd,
            smd_w = map_dbl(covars_smd,
                           ~ std_diff(data_long_spread,
                                      .x,
                                      "weight",
                                      5)),
            smd_uw = map_dbl(covars_smd,
                             ~ std_diff(data_long_spread,
                                        .x,
                                        "unweight",
                                        5)))

################################################################################
# 2 Save table
################################################################################
write_csv(smd, 
          here::here("output", "tables", "ccw",
                      make_filename("smd", period, outcome, contrast, "csv")))
