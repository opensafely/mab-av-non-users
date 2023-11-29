################################################################################
#
# Write coefficients of weighting models to text file
#
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
# - 'model' /in {cox, plr} (--> model used to estimate prob of remaining uncensored)
# - 'subgrp' /in {full, haem, transplant} (--> full cohort or haematological subgroup)
# - 'supp'/in {main, supp1} (--> main analysis or supplemental analysis)
#
# It saves the coefficients of the weighting models in a text file
# original models:
# ./output/['model']/models/['subgroup']/['supp']/['period'_]cox_cens_['arm'_]['contrast'_]['outcome'_]['model_]['subgroup'][supp'_].rds
# coefficients of each of the models are saved in:
# ./output/['model']/models/['subgroup']/['supp']/coefficients/['period'_]cox_cens_['arm'_]['contrast'_]['outcome'_]['model_]['subgroup'][supp'_].csv
# note if 'period' == ba1, no prefix is used; 
# if 'outcome' == primary, no suffix is used;
# if 'model' == cox no suffix is used;
# if 'subgrp' == full no suffix is used;
# if 'supp' == main no suffix is used
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
library(survival)
library(optparse)
library(broom)
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  model <- "plr"
  outcome <- "primary"
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
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome used in model [default %primary].",
                metavar = "outcome"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp"),
    make_option("--supp", type = "character", default = "main",
                help = "Main analysis or supplementary analysis, options are 'main' or 'supp1' [default %default]",
                metavar = "supp")
  )
  
  opt_parser <- OptionParser(usage = "coef_weight_models:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  model <- opt$model
  outcome <- opt$outcome
  subgrp <- opt$subgrp
  supp <- opt$supp
}

################################################################################
# 0.2 Create directories for output
################################################################################
# Create models directory
output_dir <- here::here("output")
models_coef_dir <-
  concat_dirs(fs::path("models", "coefficients"), output_dir, model, subgrp, supp)
fs::dir_create(models_coef_dir)

################################################################################
# 1 Read models
################################################################################
if (model == "cox"){
  pattern <- if_else(period == "ba1", "^cox_cens", "^ba2_cox_cens")
} else if (model == "plr"){
  pattern <- if_else(period == "ba1", "^plr_cens", "^ba2_plr_cens")
}

# directory where models are saved
models_dir <- 
  concat_dirs("models", output_dir, model, subgrp, supp)
files <- 
  list.files(models_dir,
             pattern = pattern, 
             full.names = FALSE)
files <- files[!stringr::str_detect(files, "plr_cens2_trt_all_*")] # ba1, contrast all --> 
# no alternative censoring (there is a character string saved in the .rds, 
# causing problems when tidy is used in subsequent steps)
if (outcome == "primary"){
  files <- files[!stringr::str_detect(files, "primary_combined")]
} else if (outcome == "primary_combined"){
  files <- files[stringr::str_detect(files, "primary_combined")]
}

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
      .f = ~ tidy(.x))

################################################################################
# 2 Save coefficients to text file
################################################################################
iwalk(
  .x = coefs,
  .f = ~ write_csv(
    .x,
    fs::path(models_coef_dir, paste0(.y, ".csv")),
  )
)
