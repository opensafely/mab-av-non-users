################################################################################
#
# Density of weights
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
library(tidyr)
source(here::here("lib", "functions", "make_filename.R"))

################################################################################
# 0.1 Create directories for output
################################################################################
# Create directory where output of ccw analysis will be saved
output_dir <- here::here("output", "tables", "ccw")
fs::dir_create(output_dir)

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

################################################################################
# 1 Estimate density
################################################################################
calc_dens_of_arm <- function(data, arm, time){
  dens <- data %>%
    filter(fup == time & arm == arm) %>%
    pull(weight) %>%
    density()
  out <- cbind(dens$x, dens$y)
}
arms <- c("Control", "Treatment")
dens <- map(.x = arms,
            .f = ~ calc_dens_of_arm(data_long, .x, 5.5))
names(dens) <- arms

################################################################################
# 2 Save table
################################################################################
iwalk(.x = dens,
      .f = ~ write_csv(
        fs::path(output_dir,
                 make_filename("dens", period, outcome, contrast, "csv"))))
