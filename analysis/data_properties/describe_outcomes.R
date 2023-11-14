################################################################################
#
# Describe outcomes
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# -./output/tables/descriptive/'period'_outcomes_'outcome'{_redacted}.csv
# (if period == ba1, no prefix is used; for primary outcome, 'outcomes' is null)
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library('dplyr')
library('lubridate')
library('here')
library('readr')
library('purrr')
library('tidyselect')
library('optparse')

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "tables", "descriptive"))

################################################################################
# 0.2 Import command-line arguments
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
  
  opt_parser <- OptionParser(usage = "ccw:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  period <- opt$period
  subgrp <- opt$subgrp
}

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename)) %>%
  filter(treatment_paxlovid_prim == "Untreated") # paxlovid treated only experience outcomes after 
# treatment by design (_prim treatment cat); paxlovid treated will be censored after pax init,
# so we're not interested in number of outcomes in paxlovid treated group.
# subgroup if subgroup analysis
if (subgrp == "haem"){
  data <-
    data %>% 
    filter(haematological_disease_nhsd == TRUE)
} else if (subgrp == "transplant"){
  data <- 
    data %>%
    filter(solid_organ_transplant_nhsd_new == TRUE)
}

################################################################################
# 1 Add indicator to data
################################################################################
data <-
  data %>%
  mutate(ind_death_equal_after1 = 
           case_when(status_primary == "covid_hosp_death" & 
                      covid_death_date == min_date_primary ~ "equal",
                     status_primary == "covid_hosp_death" &
                       death_date > min_date_primary ~ "after",
                     TRUE ~ NA_character_),
         ind_death_equal_after2 = 
           case_when(status_secondary == "allcause_hosp_death" & 
                       death_date == min_date_secondary ~ "equal",
                     status_secondary == "allcause_hosp_death" &
                       death_date > min_date_secondary ~ "after",
                     TRUE ~ NA_character_),
         all = "All")

################################################################################
# 2 Tabularise outcomes
################################################################################
# function to tabular outcomes
tabularise_outcomes <- function(data, group_var, status_var, indicator){
  table <- 
    data %>%
    group_by({{ group_var }}) %>%
    summarise(
      n = n(), 
      n_covid_hosp_death = 
        sum({{ status_var }} == "covid_hosp_death", na.rm = TRUE),
      n_of_which_covid_death = 
        sum({{ status_var }} == "covid_hosp_death" & {{ indicator }} == "equal", 
            na.rm = TRUE),
      n_death_after_covid_hosp = 
        sum({{ status_var }} == "covid_hosp_death" & {{ indicator }} == "after", 
            na.rm = TRUE),
      noncovid_death = 
        sum({{ status_var }} == "noncovid_death", na.rm = TRUE),
      dereg = sum({{ status_var }} == "dereg", na.rm = TRUE)
    ) %>%
    rename(group = {{ group_var }})
  table
}
table_prim <- 
  tabularise_outcomes(data, 
                      all, 
                      status_primary, 
                      ind_death_equal_after1) %>%
  bind_rows(
    tabularise_outcomes(data, 
                        treatment_strategy_cat_prim, 
                        status_primary, 
                        ind_death_equal_after1))
table_sec <- 
  tabularise_outcomes(data, 
                      all, 
                      status_secondary, 
                      ind_death_equal_after2) %>%
  bind_rows(
    tabularise_outcomes(data,
                        treatment_strategy_cat_sec, 
                        status_secondary, 
                        ind_death_equal_after2))

################################################################################
# 3 Redact tables
################################################################################
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
table_prim_redacted <-
  table_prim %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. >= 0 & . <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., rounding_threshold) %>% 
                              as.character())))
table_sec_redacted <-
  table_sec %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. >= 0 & . <= redaction_threshold ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., rounding_threshold) %>% 
                              as.character())))

################################################################################
# 4 Save output
################################################################################
write_csv(table_prim,
          here::here("output", "tables", "descriptive",
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes",
                            "_"[subgrp != "full"],
                            subgrp[subgrp != "full"],
                            ".csv")))
write_csv(table_prim_redacted,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes",
                            "_"[subgrp != "full"],
                            subgrp[subgrp != "full"],
                            "_redacted.csv")))
write_csv(table_sec,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes_secondary",
                            "_"[subgrp != "full"],
                            subgrp[subgrp != "full"],
                            ".csv")))
write_csv(table_sec_redacted,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes_secondary",
                            "_"[subgrp != "full"],
                            subgrp[subgrp != "full"],
                            "_redacted.csv")))
