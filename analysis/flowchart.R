################################################################################
#
# Tabularise data needed for flowchart
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# 2 .rds files named:
# -./output/tables/flowchart_redacted_'period'.csv
# -./output/data_properties/'flowchart_'period'.csv
# (if period == ba1, no sufffix is used)
#
# in the _day2-5 files, patients are classified as treated if they are treated
# within 2-5 days, respectively; and excluded if they experience an outcome in
# days 2-5, respectively (outcome = all cause death/ hosp or dereg)
# in the day0 file, patients are classified as treated if they are treated within
# 5 days and never excluded
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(readr)
library(dplyr)
library(fs)
library(here)
library(purrr)

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "data_properties"))
fs::dir_create(here::here("output", "tables"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
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
# 0.1 Import data
################################################################################
# Treatment assignment window 'treated within 5 days -> <= 4 days' etc
treat_windows <- c(1, 2, 3, 4)
data_filename <- paste0(
  period[period != "ba1"], "_"[period != "ba1"],
  "data_processed_day", treat_windows + 1, ".rds")
data_cohort_dayx_list <- 
  map(.x = data_filename,
      .f = ~ read_rds(here("output", "data", .x)))
names(data_cohort_dayx_list) <- paste0("day", treat_windows + 1)
data_cohort_day0 <-
  read_rds(here("output", "data", 
                paste0(period[period != "ba1"], "_"[period != "ba1"],
                       "data_processed_day0.rds")))

################################################################################
# 1. Total
################################################################################
n_total <- data_cohort_day0 %>% nrow()
n_treated <- data_cohort_day0 %>%
  filter(treatment == "Treated") %>%
  nrow()
n_treated_sot <- data_cohort_day0 %>%
  filter(treatment == "Treated" & 
           treatment_strategy_cat == "Sotrovimab") %>%
  nrow()
n_treated_mol <- data_cohort_day0 %>%
  filter(treatment == "Treated" & 
           treatment_strategy_cat == "Molnupiravir") %>%
  nrow()
n_untreated <- data_cohort_day0 %>%
  filter(treatment == "Untreated") %>%
  nrow()

################################################################################
# 2. Excluded
################################################################################
# flowchart
n_excluded_dayx <- function(day){
  data_cohort_day0 %>%
    filter(fu_secondary <= {day - 1}) %>%
    group_by(treatment_strategy_cat, .drop = FALSE) %>%
    summarise(n = n()) %>%
    tidyr::pivot_wider(names_from = treatment_strategy_cat,
                       values_from = n) %>%
    transmute(hosp_death_treated_sot = Sotrovimab,
              hosp_death_treated_mol = Molnupiravir,
              hosp_death_untreated = Untreated) %>%
    mutate(treat_window = paste0("day", day),
           .before = hosp_death_treated_sot) %>%
    mutate(hosp_death_treated = data_cohort_day0 %>%
             filter(treatment == "Treated" & fu_secondary <= {day - 1}) %>%
             nrow(), .after = treat_window)
}
n_excluded <-
  map_dfr(.x = treat_windows + 1,
          .f = ~ n_excluded_dayx(.x))

################################################################################
# 3. Included
################################################################################
n_included_dayx <- function(data_dayx, day){
  n_treated_dayx <- data_dayx %>%
    filter(treatment == "Treated") %>%
    nrow()
  n_treated_dayx_sot <- data_dayx %>%
    filter(treatment == "Treated" & treatment_strategy_cat == "Sotrovimab") %>%
    nrow()
  n_treated_dayx_mol <- data_dayx %>%
    filter(treatment == "Treated" & treatment_strategy_cat == "Molnupiravir") %>%
    nrow()
  n_untreated_dayx <- data_dayx %>%
    filter(treatment == "Untreated") %>%
    nrow()
  n_untreated_treated_after_dayx <- data_dayx %>%
    filter(treat_after_treat_window == 1) %>%
    nrow()
  out <- tibble(
    treat_window = day,
    treated_dayx = n_treated_dayx,
    treated_dayx_sot = n_treated_dayx_sot,
    treated_dayx_mol = n_treated_dayx_mol,
    untreated_dayx = n_untreated_dayx,
    untreated_treated_after_dayx = n_untreated_treated_after_dayx
  )
}
n_included <- 
  imap_dfr(.x = data_cohort_dayx_list,
           .f = ~ n_included_dayx(.x, .y))

flowchart <- 
  cbind(total = n_total, treated = n_treated, 
        treated_sot = n_treated_sot, treated_mol = n_treated_mol,
        untreated = n_untreated,
        n_excluded) %>%
  left_join(n_included,
            by = "treat_window")

################################################################################
# 4. Redact
################################################################################
# redact (simple redaction, round all to nearest 5)
flowchart_redacted <- 
  flowchart %>%
  mutate(across(where(is.integer), ~ plyr::round_any(.x, 5)))

################################################################################
# 5. Save data
################################################################################
# Save flowcharts
write_csv(flowchart, here("output", "data_properties", 
                          paste0("flowchart",
                                 "_"[period != "ba1"],
                                 period[period != "ba1"],
                                 ".csv")))
write_csv(flowchart_redacted, here("output", "tables", 
                                   paste0("flowchart_redacted",
                                          "_"[period != "ba1"],
                                          period[period != "ba1"],
                                          ".csv")))
