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
data_table <- 
  data %>%
  mutate(N = 1, allpop = "All") %>%
  select(c("N", "allpop", "treatment_strategy_cat_prim", all_of(covars)))
# Generate full and stratified table
pop_levels = c("All", "Molnupiravir", "Sotrovimab", "Untreated")
# Generate table - full and stratified populations
for (pop_level in pop_levels) {
  if (pop_level == "All") { 
    data_summary <- 
      data_table %>% 
      select(-treatment_strategy_cat_prim) %>% 
      tbl_summary(by = allpop,
                  statistic = everything() ~ "{n}")
    data_summary$inputs$data <- NULL
  } else {
    data_summary <- data_table %>% 
      filter(treatment_strategy_cat_prim == pop_level) %>%
      select(-treatment_strategy_cat_prim) %>% 
      tbl_summary(by = allpop,
                  statistic = everything() ~ "{n}")
    data_summary$inputs$data <- NULL
  }
  table1 <- 
    data_summary$table_body %>%
    filter(!is.na(stat_1)) %>%
    mutate(label = if_else(var_type == "dichotomous", "", label)) %>%
    select(group = variable, variable = label, count = stat_1) %>%
    mutate(count = case_when(!is.na(count) ~ as.numeric(gsub(",", "", count)),
                             TRUE ~ NA_real_)) %>%
    mutate(percent = round(count/data_summary$N*100, 1))
  colnames(table1) = c("Group", "Variable", "Count", "Percent")
  # Clean names
  table1_clean = clean_table_names(table1)
  # Calculate rounded total
  rounded_n = plyr::round_any(data_summary$N, rounding_threshold)
  # Round individual values to rounding threshold
  table1_redacted <- table1_clean %>%
    mutate(Count = plyr::round_any(Count, rounding_threshold),
           Percent = round(Count / rounded_n * 100, 1),
           Non_Count = rounded_n - Count)
  # Redact any rows with rounded cell data or non-data <= redaction threshold
  table1_redacted <-
    table1_redacted %>%
    mutate(Summary = paste0(prettyNum(Count, big.mark=","),
                            " (",
                            format(Percent, nsmall = 1), "%)") %>%
                       gsub(" ", "", .,  fixed = TRUE) %>% # Remove spaces generated by decimal formatting
                       gsub("(", " (", ., fixed = TRUE)) %>% # Add first space before (
    mutate(Summary = if_else((Count >= 0 & Count <= redaction_threshold) | 
                               (Non_Count >= 0 & Non_Count <= redaction_threshold),
                             "[Redacted]", 
                             Summary)) %>%
    mutate(Summary = if_else(Group == "N",
                             prettyNum(Count, big.mark = ","),
                             Summary)) %>%
    select(-Non_Count, -Count, -Percent)
  names(table1_redacted)[3] = pop_level
  table1_clean <- table1_clean %>% select(-Percent)
  names(table1_clean)[3] = pop_level
  # collate table
  if (pop_level == "All") { 
    collated_table = table1_redacted 
    collated_table_unred = table1_clean
  } else { 
    collated_table = collated_table %>% 
      left_join(table1_redacted, 
                by = c("Group" = "Group", "Variable" = "Variable"))
    collated_table_unred = collated_table_unred %>% 
      left_join(table1_clean, 
                by = c("Group" = "Group", "Variable" = "Variable"))
  }
}

################################################################################
# 2 Save table
################################################################################
file_name <- make_filename("table1_redacted", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "html")
gtsave(gt(collated_table), 
       filename = fs::path(tables_dir, file_name))
file_name_unred <- make_filename("table1_unredacted", period, outcome = "primary", contrast = "", model = "cox", subgrp = subgrp, supp = "main", type = "html")
gtsave(gt(collated_table_unred), 
       filename = fs::path(tables_dir, file_name_unred))
