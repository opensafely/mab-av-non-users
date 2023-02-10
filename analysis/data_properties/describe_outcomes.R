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

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "tables", "descriptive"))

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
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed", ".rds")
data <-
  read_rds(here::here("output", "data", data_filename))

################################################################################
# 1 Describe primary outcomes
################################################################################
data <-
  data %>%
  mutate(ind_death_equal_after1 = 
           case_when(status_primary == "covid_hosp_death" & 
                      covid_death_date == min_date_primary ~ "equal",
                     status_primary == "covid_hosp_death" &
                       death_date > min_date_primary ~ "after",
                     TRUE ~ NA_character_))
table_prim <- 
  data %>%
  summarise(
    n_covid_hosp_death = sum(status_primary == "covid_hosp_death", 
                             na.rm = TRUE),
    n_of_which_covid_death = sum(status_primary == "covid_hosp_death" & 
                                   ind_death_equal_after1 == "equal", 
                                 na.rm = TRUE),
    n_death_after_covid_hosp = sum(status_primary == "covid_hosp_death" & 
                                     ind_death_equal_after1 == "after", 
                                   na.rm = TRUE),
    noncovid_death = sum(status_primary == "noncovid_death", 
                         na.rm = TRUE),
    dereg = sum(status_primary == "dereg", 
                na.rm = TRUE)
    )
table_prim_redacted <-
  table_prim %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. <= 7 ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., 5) %>% as.character())))
write_csv(table_prim,
          here::here("output", "tables", "descriptive",
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes.csv")))
write_csv(table_prim_redacted,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes_redacted.csv")))

################################################################################
# 2 Describe secondary outcomes
################################################################################
data <-
  data %>%
  mutate(ind_death_equal_after2 = 
           case_when(status_secondary == "allcause_hosp_death" & 
                       death_date == min_date_secondary ~ "equal",
                     status_secondary == "allcause_hosp_death" &
                       death_date > min_date_secondary ~ "after",
                     TRUE ~ NA_character_))
table_sec <- 
  data %>%
  summarise(
    n_allcause_hosp_death = sum(status_secondary == "allcause_hosp_death",
                                na.rm = TRUE),
    n_of_which_death = sum(status_secondary == "allcause_hosp_death" & 
                             ind_death_equal_after2 == "equal",
                           na.rm = TRUE),
    n_death_after_allcause_hosp = sum(status_secondary == "allcause_hosp_death" & 
                                        ind_death_equal_after2 == "after",
                                      na.rm = TRUE),
    dereg = sum(status_secondary == "dereg",
                na.rm = TRUE)
    )
table_sec_redacted <-
  table_sec %>%
  mutate(across(where(~ is.integer(.x)), 
                ~ case_when(. <= 7 ~ "[REDACTED]",
                            TRUE ~ plyr::round_any(., 5) %>% as.character())))
write_csv(table_sec,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes_secondary.csv")))
write_csv(table_sec_redacted,
          here::here("output", "tables", "descriptive", 
                     paste0(period[period != "ba1"],
                            "_"[period != "ba1"],
                            "outcomes_secondary_redacted.csv")))
