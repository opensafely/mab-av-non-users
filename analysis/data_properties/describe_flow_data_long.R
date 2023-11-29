################################################################################
#
# Flowchart NEW
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
# - 'contrast' /in {all, molnupiravir, sotrovimab} (--> mol/sot vs untrt, mol vs untrt, sot vs untrt)
# - 'outcome' /in {primary, secondary} (--> primary or secondary outcome)
# - 'subgrp' /in {full, haem, transplant} (--> full cohort or haematological subgroup)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(lubridate)
library(here)
library(readr)
library(arrow)
library(optparse)
library(fs)
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  contrast <- "all"
  outcome <- "primary"
  model <- "plr"
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
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome used in the analysis, options are 'primary' or 'secondary' [default %default].",
                metavar = "outcome"),
    make_option("--model", type = "character", default = "plr",
                help = "Model used to estimate probability of remaining uncensored [default %default].",
                metavar = "model"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp"),
    make_option("--supp", type = "character", default = "main",
                help = "Main analysis or supplementary analysis, options are 'main' or 'supp1' [default %default]",
                metavar = "supp")
  )
  
  opt_parser <- OptionParser(usage = "describe_flow_data_long", option_list = option_list)
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
fs::dir_create(data_properties_long_dir)

################################################################################
# 1 Import data
################################################################################
data_dir <- concat_dirs("data", output_dir, model, subgrp, supp)
data_filename <- make_filename("data_long", period, outcome, contrast, model, subgrp, supp, "feather")
input_file <- fs::path(data_dir, data_filename)
data_long <- read_feather(input_file)
treatment_window_days <- 4
if (supp %in% c("grace4", "grace3")){
  treatment_window_days <- 
    stringr::str_extract(supp, "[:digit:]") %>% as.numeric() - 1
}
treatment_window_days_05 <- treatment_window_days + 0.5

################################################################################
# 2. Select data needed
################################################################################
data_long <- 
  data_long %>% 
  group_by(arm, patient_id) %>% 
  mutate(max_fup = max(fup)) %>% 
  ungroup()
data_long_control <- 
  data_long %>% filter(arm == "Control" & fup == max_fup)
data_long_treatment <- 
  data_long %>% filter(arm == "Treatment" & fup == max_fup)

################################################################################
# 3. Function
################################################################################
retrieve_n_flowchart <- function(data_long, arm) {
  n_total <- data_long %>% nrow()
  if (arm == "Control"){
    data_cens <- data_long %>% filter(censoring == 0 & max_fup <= treatment_window_days_05)
  } else if (arm == "Treatment"){
    data_cens <- data_long %>% filter(censoring == 0 & max_fup <= treatment_window_days_05 & treatment_ccw == "Untreated")
  }
  n_cens <- data_cens %>% filter(outcome == 0) %>% nrow()
  n_cens_outc <- data_cens %>% filter(outcome == 1) %>% nrow()
  n_art_cens <- data_long %>% filter(censoring == 1 & treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") %>% nrow()
  n_art_cens_pax <- data_long %>% filter(censoring == 1 & treatment_paxlovid_ccw == "Treated") %>% nrow()
  n_art_cens_alt <- data_long %>% filter(censoring == 1 & treatment_alt_ccw == "Treated") %>% nrow()
  if (arm == "Control"){
    data_fup <- data_long %>% filter(censoring == 0 & max_fup > treatment_window_days_05)
  } else if (arm == "Treatment"){
    data_fup <- data_long %>% filter(censoring == 0 & treatment_ccw == "Treated")
  }
  n_fup <- data_fup %>% nrow()
  n_fup_outc <- data_fup %>% filter(outcome == 1) %>% nrow()
  out <- tibble(arm, n_total, n_cens, n_art_cens, n_art_cens_pax, n_art_cens_alt, n_cens_outc, n_fup, n_fup_outc)
}

################################################################################
# 4. Table
################################################################################
n_control <- retrieve_n_flowchart(data_long_control, "Control")
n_treat <- retrieve_n_flowchart(data_long_treatment, "Treatment")
flowchart <- rbind(n_control, n_treat)

################################################################################
# 5. Redact data flow
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
flowchart_red <-
  flowchart %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. > 0 & . <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., rounding_threshold) %>% 
                              as.character())))

################################################################################
# 5. Save output
################################################################################
filename <- 
  make_filename("flow_data", period, outcome, contrast, model, subgrp = "full", supp, type = "csv")
filename_red <- 
  make_filename("flow_data_redacted", period, outcome, contrast, model, subgrp = "full", supp, type = "csv")
write_csv(flowchart,
          fs::path(data_properties_long_dir,
                   filename))
write_csv(flowchart_red,
          fs::path(data_properties_long_dir,
                   filename_red))
