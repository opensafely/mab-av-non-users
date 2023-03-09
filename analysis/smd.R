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
library(tidyr)
library(optparse)
source(here::here("lib", "functions", "std_diff.R"))
source(here::here("lib", "design", "covars_smd.R"))
source(here::here("analysis", "data_ccw", "spread_data.R"))
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
  
  opt_parser <- OptionParser(usage = "smd:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  contrast <- opt$contrast
  outcome <- opt$outcome
  model <- opt$model
  subgrp <- opt$subgrp
  supp <- opt$supp
}

################################################################################
# 0.1 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_ccw_dir <- 
  concat_dirs(fs::path("tables", "ccw"), output_dir, model, subgrp, supp)
# Create directory where output of ccw analysis will be saved
fs::dir_create(tables_ccw_dir)

################################################################################
# 0.3 Import data
################################################################################
data_dir <- concat_dirs("data", output_dir, model, subgrp, supp)
data_filename <- make_filename("data_long", period, outcome, contrast, model, subgrp, supp, "feather")
data_long <- arrow::read_feather(fs::path(data_dir, data_filename))
t_events <- data_long %>% pull(fup) %>% unique()
# spread data:
# - spread factors in dummy columns
data_long_spread <- spread_data(data_long)

################################################################################
# 1 Calculate standardised mean differences
################################################################################
data_long_spread <- data_long_spread %>% mutate(unweight = 1)
calc_smd <- function(time) {
  smd <- 
    bind_rows(covars = covars_smd,
              time = time,
              smd_w = map_dbl(covars_smd,
                             ~ std_diff(data_long_spread,
                                        .x,
                                        "weight",
                                        time)),
              smd_uw = map_dbl(covars_smd,
                               ~ std_diff(data_long_spread,
                                          .x,
                                          "unweight",
                                          time)))
}
smd <- map(
  .x = t_events,
  .f = ~ calc_smd(.x)
) %>% bind_rows()

################################################################################
# 2 Save table
################################################################################
write_csv(smd, 
          fs::path(tables_ccw_dir,
                   make_filename("smd", period, outcome, contrast, model, subgrp, supp, "csv")))
