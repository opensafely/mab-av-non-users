################################################################################
#
# Table 1
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# -./output/tables/table1.csv
# (if period == ba1, no prefix is used)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library('tidyverse')
library('here')
library('glue')
library('gt')
library('gtsummary')
library('fs')
library('optparse')
# Import custom user functions
source(here::here("lib", "design", "covars_table.R"))
source(here::here("lib", "functions", "clean_table_names.R"))
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))
source(here("lib", "functions", "generate_table1.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  period <- "ba1"
  subgrp <- "full"
} else {
  
  option_list <- list(
    make_option("--period", type = "character", default = "ba1",
                help = "Period where the analysis is conducted in, options are 'ba1' or 'ba2' [default %default].",
                metavar = "period"),
    make_option("--subgrp", type = "character", default = "full",
                help = "Subgroup where the analysis is conducted on, options are 'full' and 'haem' [default %default].",
                metavar = "subgrp")
  )
  
  opt_parser <- OptionParser(usage = "table_1:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  subgrp <- opt$subgrp
}

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_dir <- 
  concat_dirs("tables", output_dir, model = "cox", subgrp, supp = "main")
# model and supp default ones to trick concat_dirs function
fs::dir_create(tables_dir)

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))
data <- 
  data %>%
  mutate(
    treatment_strategy_cat_prim_table = 
      if_else(treatment_paxlovid_prim != "Untreated", "Paxlovid",
              treatment_strategy_cat_prim %>% as.character()) %>%
      factor(levels = c("Sotrovimab", "Molnupiravir", "Paxlovid", "Untreated")))
if (subgrp == "haem"){
  data <-
    data %>% 
    filter(haematological_disease_nhsd == TRUE)
} else if (subgrp == "transplant"){
  data <- 
    data %>%
    filter(solid_organ_transplant_nhsd_new == TRUE)
}
data %>% 
  group_by(treatment_strategy_cat_prim, vaccination_status, moderna_most_recent_cov_vac) %>%
  tally() %>%
  spread(moderna_most_recent_cov_vac, n) %>%
  print()

################################################################################
# 1 Make table 1
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
# Format data
data_table_full <- 
  data %>%
  select(treatment_strategy_cat_prim_table, all_of(covars))
data_table <-
  data_table_full %>%
  filter(treatment_strategy_cat_prim_table %in% c("Sotrovimab", "Molnupiravir", "Untreated"))
# Generate full and stratified table
# exclude pax treated
pop_levels <- c("All", "Sotrovimab", "Molnupiravir", "Untreated")
table1 <- generate_table1(data_table, pop_levels)
# all levels
if (period == "ba2"){
  pop_levels_full <- c("All", "Paxlovid", "Sotrovimab", "Molnupiravir", "Untreated")
  table1_full <- generate_table1(data_table_full, pop_levels_full)
}

################################################################################
# 2 Save table
################################################################################
file_name_red <- make_filename("table1_redacted", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
file_name <- make_filename("table1", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
file_name_red_unf <- make_filename("table1_redacted_unf", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
write_csv(table1$table1,
          fs::path(tables_dir, file_name))
write_csv(table1$table1_red,
          fs::path(tables_dir, file_name_red))
write_csv(table1$table1_red_unf,
          fs::path(tables_dir, file_name_red_unf))
if (period == "ba2"){
  file_name_full_red <- make_filename("table1_full_redacted", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
  file_name_full <- make_filename("table1_full", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
  file_name_full_red_unf <- make_filename("table1_full_redacted_unf", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "csv")
  write_csv(table1_full$table1,
            fs::path(tables_dir, file_name_full))
  write_csv(table1_full$table1_red,
            fs::path(tables_dir, file_name_full_red))
  write_csv(table1_full$table1_red_unf,
            fs::path(tables_dir, file_name_full_red_unf))
}
