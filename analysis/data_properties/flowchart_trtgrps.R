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
  
  opt_parser <- OptionParser(usage = "flowchart_trtgrps:[version] [options]", option_list = option_list)
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

################################################################################
# 1 Calc numbers flowchart
################################################################################
n_total <- data %>% nrow()
n_trt_after_postest <- 
  data %>% 
  filter(any_treatment_strategy_cat != "Untreated" &
           tb_postest_treat >= 0) %>% nrow()
n_trt_pax_after_postest <-
  data %>%
  filter(any_treatment_paxlovid != "Untreated" &
           tb_postest_treat >= 0) %>% nrow()
n_untrt_after_postest <- n_total - n_trt_after_postest - n_trt_pax_after_postest
n_trt_after_treat_window <-
  data %>%
  filter(any_treatment_strategy_cat != "Untreated" & treat_after_treat_window == 1) %>% nrow()
n_trt_pax_after_treat_window <-
  data %>%
  filter(any_treatment_paxlovid != "Untreated" & treat_after_treat_window == 1) %>% nrow()
n_trt_treat_window <-
  data %>%
  filter(treatment == "Treated") %>% nrow()
n_trt_pax_treat_window <-
  data %>%
  filter(treatment_paxlovid == "Treated") %>% nrow()
n_untrt_treat_window <- n_total - n_trt_treat_window - n_trt_pax_treat_window
n_trt_on_after_outcome <-
  data %>%
  filter(treatment == "Treated" & treatment_prim == "Untreated") %>%
  nrow()
n_trt_pax_on_after_outcome <-
  data %>%
  filter(treatment_paxlovid == "Treated" & treatment_paxlovid_prim == "Untreated") %>%
  nrow()
n_trt <- 
  data %>%
  filter(treatment_prim == "Treated") %>%
  nrow()
n_trt_pax <-
  data %>%
  filter(treatment_paxlovid_prim == "Treated") %>%
  nrow()
n_untrt <-
  data %>%
  filter(treatment_prim == "Untreated" & treatment_paxlovid_prim == "Untreated") %>%
  nrow()

################################################################################
# 2 Combine in one tibble
################################################################################
flowchart_trtgrps <-
  tibble(n_total,
         n_trt_after_postest,
         n_trt_pax_after_postest,
         n_untrt_after_postest,
         n_trt_after_treat_window,
         n_trt_pax_after_treat_window,
         n_trt_treat_window,
         n_trt_pax_treat_window,
         n_untrt_treat_window,
         n_trt_on_after_outcome,
         n_trt_pax_on_after_outcome,
         n_trt,
         n_trt_pax,
         n_untrt) %>%
  tidyr::pivot_longer(everything())

################################################################################
# 3 Redact flowchart
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
flowchart_trtgrps_red <-
  flowchart_trtgrps %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. > 0 & . <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., rounding_threshold) %>% 
                              as.character())))

################################################################################
# 4 Save output
################################################################################
filename <- 
  make_filename("flowchart_trtgrps", period, outcome, contrast = "", model = "cox", subgrp, supp = "main", type = "csv")
filename_red <- 
  make_filename("flowchart_trtgrps_redacted", period, outcome, contrast = "", model = "cox", subgrp, supp = "main", type = "csv")
write_csv(flowchart_trtgrps,
          fs::path(tables_flowchart_dir,
                   filename))
write_csv(flowchart_trtgrps_red,
          fs::path(tables_flowchart_dir,
                   filename_red))
