################################################################################
#
# Write coefficients of weighting models to text file
#
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# It saves the coefficients of the weighting models in a text file
# original models:
# ./output/tables/ccw/['period'_]cox_cens_['arm'_]['contrast'_]['outcome'].rds
# coefficients of each of the models are saved in:
# ./output/models/coefficients/['period'_]cox_cens_['arm'_]['contrast'_]['outcome'].txt
# note if 'period' == ba1, no prefix is used; 
# if 'outcome' == primary, no suffix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)
library(stringr)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create models directory
output_dir <- here("output", "models", "coefficients")
fs::dir_create(output_dir)

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
# 1 Read models
################################################################################
pattern <- if_else(period == "ba1", "^cox_cens", "^ba2_cox_cens")
# directory where models are saved
models_dir <- here("output", "models")
files <- 
  list.files(models_dir,
             pattern = pattern, 
             full.names = FALSE)
# capture names of models
object_names <- str_extract(files, "[^.]+")
models <- 
  map(.x = files,
      .f = ~ readRDS(fs::path(models_dir, .x)))
names(models) <- object_names

################################################################################
# 1 Coef models
################################################################################
coefs <- 
  map(.x = models,
      .f = ~ coefficients(.x))

################################################################################
# 2 Save coefficients to text file
################################################################################
iwalk(
  .x = coefs,
  .f = ~ capture.output(
    .x,
    file = fs::path(output_dir, paste0(.y, ".txt")),
    split = FALSE
  )
)
