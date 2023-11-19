################################################################################
#
# Number of people treated and experiencing an outcome on same day
# 
# This script can be run via an action in project.yaml using one argument
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# empty file ./output/data_properties/trt_outcm_same_day.csv
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
output_dir <- here("output", "data_properties")
fs::dir_create(output_dir)

################################################################################
# 0.2 Import command-line arguments
################################################################################

################################################################################
# 0.3 Import data
################################################################################
file_names <- paste0(c("", "ba2_"), "data_processed.rds")
data <-
  map(.x = fs::path(here("output", "data"), file_names),
      .f = ~ read_rds(.x))
names(data) <- c("ba1", "ba2")

################################################################################
# Number of pt treated + outcome on same day
################################################################################
out <- 
  imap(.x = data,
       .f = ~ 
         .x %>%
         filter(status_primary %in% c("covid_hosp_death", "noncovid_death", "dereg") & 
                  treatment_strategy_cat != "Untreated" &
                  treatment_date == min_date_all) %>%
         group_by(status_primary, treatment_strategy_cat, .drop = "FALSE") %>%
         summarise(n = n(), .groups = "keep") %>%
         filter(status_primary != "none") %>%
         mutate(period = .y, .before = status_primary)
  ) %>% bind_rows() %>% filter(treatment_strategy_cat != "Untreated") %>%
  mutate(treatment_strategy_cat = treatment_strategy_cat %>% as.character)
out_pax <- 
  imap(.x = data,
       .f = ~ 
         .x %>%
         filter(status_primary %in% c("covid_hosp_death", "noncovid_death", "dereg") & 
                  treatment_paxlovid == "Treated" &
                  treatment_date_paxlovid == min_date_all) %>%
         group_by(status_primary, .drop = "FALSE") %>%
         summarise(n = n()) %>%
         filter(status_primary != "none") %>%
         mutate(period = .y, treatment_strategy_cat = "Paxlovid", .before = status_primary)
  ) %>% bind_rows()
out <-
  bind_rows(out, out_pax) %>%
  arrange(period, treatment_strategy_cat) %>%
  select(period, treatment_strategy_cat, status_primary, n)
# Set rounding and redaction thresholds
rounding_threshold = 6
redaction_threshold = 8
out_red <-
  out %>%
  mutate(n = if_else(n > 0 & n <= redaction_threshold,
                     "[REDACTED]",
                     plyr::round_any(n, rounding_threshold) %>% as.character()
                     )
         )
################################################################################
#  Save output
################################################################################
write_csv(out,
          path(output_dir, "trt_outcm_same_day.csv"))
write_csv(out_red,
          path(output_dir, "trt_outcm_same_day_red.csv"))
