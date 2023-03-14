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
library(here)
library(optparse)
library(stringr)
source(here::here("lib", "functions", "make_filename.R"))
source(here::here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  contrast <- "all"
  outcome <- "primary"
  model <- "cox"
  subgrp <- "full"
  supp <- "main"
} else {
  
  option_list <- list(
    make_option("--period", type = "character", default = "ba1",
                help = "Period where the analysis is conducted in, options are 'ba1' or 'ba2' [default %default].",
                metavar = "period"),
    make_option("--contrast", type = "character", default = "all",
                help = "Contrast of the analysis, options are 'all' (treated vs untreated), 'molnupiravir' (molnupiravir vs untreated) or 'sotrovimab' (sotrovimab vs untreated) [default %default].",
                metavar = "contrast"),
    make_option("--model", type = "character", default = "cox",
                help = "Model used to estimate probability of remaining uncensored [default %default].",
                metavar = "model"),
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome used in the analysis, options are 'primary' or 'secondary' [default %default].",
                metavar = "outcome"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp"),
    make_option("--supp", type = "character", default = "main",
                help = "Main analysis or supplementary analysis, options are 'main' or 'supp1' [default %default]",
                metavar = "supp")
  )
  
  opt_parser <- OptionParser(usage = "dens_weights:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  contrast <- opt$contrast
  outcome <- opt$outcome
  model <- opt$model
  subgrp <- opt$subgrp
  supp <- opt$supp
}

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
data_properties_long_dir <- 
  concat_dirs(fs::path("data_properties", "data_long"), output_dir, model, subgrp, supp)
# Create directory where output of ccw analysis will be saved
fs::dir_create(data_properties_long_dir)

################################################################################
# 0.3 Import data
################################################################################
data_filename <- make_filename("data_long", period, outcome, contrast, model, subgrp, supp, "feather")
data_dir <- 
  concat_dirs("data", output_dir, model, subgrp, supp)
data_long <- arrow::read_feather(fs::path(data_dir, data_filename))

################################################################################
# 1 Estimate density
################################################################################
calc_dens_of_arm <- function(data, arm_str, time){
  dens <- data %>%
    filter(arm == arm_str & fup == time) %>%
    pull(weight) %>%
    density()
  out <- cbind.data.frame(coord = dens$x, dens = dens$y, arm = arm_str)
}
arms <- c("Control", "Treatment")
dens <- map(.x = arms,
            .f = ~ calc_dens_of_arm(data_long, .x, 4.5)) %>% bind_rows()
q_s <-
  data_long %>%
  group_by(arm, fup) %>%
  summarise(tibble::enframe(quantile(cmlp_uncens, probs = c(0, 0.05, 0.95, 1)), 
                            name = "quantile", "cmlp_uncens"),
            .groups = "keep") %>%
  mutate(quantile = str_remove(quantile, pattern = "%")) %>%
  pivot_wider(values_from = cmlp_uncens,
              names_from = quantile,
              names_prefix = "q_")

################################################################################
# 2 Save table
################################################################################
write_csv(
  dens,
  fs::path(data_properties_long_dir,
           make_filename("dens", period, outcome, contrast, model, subgrp, supp, "csv"))
)
write_csv(
  q_s,
  fs::path(data_properties_long_dir,
           make_filename("q", period, outcome, contrast, model, subgrp, supp, "csv"))
)
