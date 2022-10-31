################################################################################
#
# TABLE S2
#
# This script can be run via an action in project.yaml
# It combines various tables to table S2 in the supplements
# saved in:
# ./output/tables_joined/tableS2.csv
################################################################################

################################################################################
# 00. Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)
library(tidyr)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create tables directory
fs::dir_create(here("output", "tables_joined"))

################################################################################
# 0.2 Load data
################################################################################
ba1_flowchart <- read_csv(here::here("output", "tables", "flowchart_redacted.csv"))
ba2_flowchart <- read_csv(here::here("output", "tables", "flowchart_redacted_ba2.csv"))
ba1_day0_4 <- read_csv(here::here("output", "data_properties", "day0_4_all.csv"))
ba2_day0_4 <- read_csv(here::here("output", "data_properties", "ba2_day0_4_all.csv"))

################################################################################
# 0.3 Functions needed for reformatting
################################################################################
reformat_total <- function(flowchart){
  tibble(treatment_strategy_cat = c("Untreated", "Molnupiravir", "Sotrovimab")) %>%
    mutate(total = case_when(treatment_strategy_cat == "Untreated" ~ 
                           flowchart$hosp_death_untreated,
                         treatment_strategy_cat == "Molnupiravir" ~ 
                           flowchart$hosp_death_treated_mol,
                         treatment_strategy_cat == "Sotrovimab" ~ 
                           flowchart$hosp_death_treated_sot))
}
reformat_outcomes <- function(outcomes_day0_4){
  outcomes_day0_4 %>%
    select(status_all, treatment_strategy_cat, n_redacted_rounded) %>%
    pivot_wider(names_from = c(status_all),
                values_from = n_redacted_rounded) %>%
    arrange(match(treatment_strategy_cat, c("Untreated", "Molnupiravir", "Sotrovimab"))) %>%
    select(-none) %>%
    relocate(treatment_strategy_cat,
             covid_hosp,
             covid_death,
             noncovid_hosp,
             noncovid_death,
             dereg)
}

################################################################################
# 1. Create table S2
################################################################################
ba1_flowchart_day5 <- ba1_flowchart %>% filter(treat_window == "day5")
ba2_flowchart_day5 <- ba2_flowchart %>% filter(treat_window == "day5")
ba1_tableS2 <- reformat_total(ba1_flowchart_day5) %>%
  left_join(reformat_outcomes(ba1_day0_4), by = "treatment_strategy_cat")
ba2_tableS2 <- reformat_total(ba2_flowchart_day5) %>%
  left_join(reformat_outcomes(ba2_day0_4), by = "treatment_strategy_cat")
# join 2 together
tableS2 <- 
  ba1_tableS2 %>%
  left_join(ba2_tableS2, 
            by = "treatment_strategy_cat",
            suffix = c(".ba1", ".ba2"))

################################################################################
# 2. Save output
################################################################################
write_csv(tableS2,
          here::here("output", "tables_joined", "tableS2.csv"))
