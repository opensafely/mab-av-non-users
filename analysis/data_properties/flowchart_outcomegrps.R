################################################################################
#
# Flowchart treatment groups
#
# This script can be run via an action in project.yaml using three arguments:
# - 'period' /in {ba1, ba2} (--> ba1 or ba2 analysis)
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
source(here("analysis", "data_ccw", "simplify_data.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  outcome <- "primary"
  subgrp <- "full"
} else {
  
  option_list <- list(
    make_option("--period", type = "character", default = "ba1",
                help = "Period where the analysis is conducted in, options are 'ba1' or 'ba2' [default %default].",
                metavar = "period"),
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome used in the analysis, options are 'primary' or 'secondary' [default %default].",
                metavar = "outcome"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp")
  )
  
  opt_parser <- OptionParser(usage = "flowchart_outcomegrps:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  outcome <- opt$outcome
  subgrp <- opt$subgrp
}

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_flowchart_dir <- 
  concat_dirs(path("tables", "flowchart"), output_dir, model = "cox", subgrp, supp = "main")
fs::dir_create(tables_flowchart_dir)

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))
data <- ccw_simplify_data(data, outcome, contrast = "all", subgrp)

################################################################################
# 1 Calc numbers flowchart
################################################################################
n_outcomes <-
  data %>%
  filter(status_ccw_simple == 1) %>%
  nrow()
n_outcomes_non_pax <-
  data %>%
  filter(status_ccw_simple == 1 & treatment_paxlovid_ccw != "Treated") %>%
  nrow()
n_outcomes_trt <- 
  data %>%
  filter(treatment_ccw == "Treated" & status_ccw_simple == 1) %>%
  nrow()
n_outcomes_untrt <- 
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Untreated" &
           status_ccw_simple == 1) %>%
  nrow()
n_outcomes_untrt_pax_trt <-
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Treated" &
           status_ccw_simple == 1) %>%
  nrow()
n_outcomes_untrt_treat_window <-
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Untreated" &
           status_ccw_simple == 1 & fu_ccw <= 4) %>%
  nrow()
n_outcomes_untrt_pax_trt_treat_window <-
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Treated" &
           status_ccw_simple == 1 & fu_ccw <= 4) %>%
  nrow()
n_outcomes_untrt_after_treat_window <-
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Untreated" &
           status_ccw_simple == 1 & fu_ccw > 4) %>%
  nrow()
n_outcomes_untrt_pax_trt_after_treat_window <-
  data %>%
  filter(treatment_ccw == "Untreated" &
           treatment_paxlovid_ccw == "Treated" &
           status_ccw_simple == 1 & fu_ccw > 4) %>%
  nrow()
################################################################################
# 2 Combine in one tibble
################################################################################
flowchart_outcomegrps <-
  tibble(n_outcomes,
         n_outcomes_non_pax,
         n_outcomes_trt,
         n_outcomes_untrt,
         n_outcomes_untrt_pax_trt,
         n_outcomes_untrt_treat_window,
         n_outcomes_untrt_pax_trt_treat_window,
         n_outcomes_untrt_after_treat_window,
         n_outcomes_untrt_pax_trt_after_treat_window) %>%
  tidyr::pivot_longer(everything())
  
################################################################################
# 3 Redact flowchart
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
flowchart_outcomegrps_red <-
  flowchart_outcomegrps %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. > 0 & . <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., rounding_threshold) %>% 
                              as.character())))

################################################################################
# 4 Save output
################################################################################
filename <- 
  make_filename("flowchart_outcomegrps", period, outcome, contrast = "", model = "cox", subgrp, supp = "main", type = "csv")
filename_red <- 
  make_filename("flowchart_outcomegrps_redacted", period, outcome, contrast = "", model = "cox", subgrp, supp = "main", type = "csv")
write_csv(flowchart_outcomegrps,
          fs::path(tables_flowchart_dir,
                   filename))
write_csv(flowchart_outcomegrps_red,
          fs::path(tables_flowchart_dir,
                   filename_red))
