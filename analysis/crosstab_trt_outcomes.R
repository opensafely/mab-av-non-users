######################################

# crosstabulates outcomes and trt group
######################################

# libraries
library(readr)
library(dplyr)
library(fs)
library(here)

# load data
data_cohort_day5 <- 
  read_rds(here("output", "data", "data_processed_day5.rds"))
data_cohort_day0 <-
  read_rds(here("output", "data", "data_processed_day0.rds"))
# create output folders
dir_create(here("output", "data_properties"))
dir_create(here("output", "tables"))

# function used to summarise outcomes
summarise_outcomes <- function(data, 
                               fu, 
                               status,
                               filename){
  fu <- enquo(fu)
  status <- enquo(status)
  data %>%
    select(treatment_strategy_cat, !!fu, !!status) %>%
    group_by(treatment_strategy_cat, !!status) %>%
    summarise(n = n(),
              fu_median = median(!!fu),
              fu_q1 = quantile(!!fu, p = 0.25, na.rm = TRUE),
              fu_q3 = quantile(!!fu, p = 0.75, na.rm = TRUE),
              .groups = "keep") %>%
    write_csv(., 
              path(here("output", "data_properties"), filename))
}

# crosstabulation trt x outcomes
cat("#### cohort day 5, primary outcome ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_primary, 
                   status_primary,
                   "day5_primary.csv")
cat("\n#### cohort day 5, secondary outcome ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_secondary, 
                   status_secondary,
                   "day5_secondary.csv")
cat("\n#### cohort day 5, all outcomes ####\n")
summarise_outcomes(data_cohort_day5, 
                   fu_all, 
                   status_all,
                   "day5_all.csv")
cat("\n#### cohort day 0, primary outcome ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_primary, 
                   status_primary,
                   "day0_primary.csv")
cat("\n#### cohort day 0, secondary outcome ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_secondary, 
                   status_secondary,
                   "day0_secondary.csv")
cat("\n#### cohort day 0, all outcomes ####\n")
summarise_outcomes(data_cohort_day0, 
                   fu_all, 
                   status_all,
                   "day0_all.csv")

# flowchart
n_total <- data_cohort_day0 %>% nrow()
n_treated <- data_cohort_day0 %>%
  filter(treatment == "Treated") %>%
  nrow()
n_untreated <- data_cohort_day0 %>%
  filter(treatment == "Untreated") %>%
  nrow()
n_hosp_death_treated <- data_cohort_day0 %>%
  filter(treatment == "Treated" & fu_secondary <= 4) %>%
  nrow()
n_hosp_death_untreated <- data_cohort_day0 %>%
  filter(treatment == "Untreated" & fu_secondary <= 4) %>%
  nrow
cat("#####check for any na's in fu_secondary (should be FALSE)#####\n")
print(any(is.na(data_cohort_day0$fu_secondary)))
n_treated_day5 <- data_cohort_day5 %>%
  filter(treatment == "Treated") %>%
  nrow()
n_untreated_day5 <- data_cohort_day5 %>%
  filter(treatment == "Untreated") %>%
  nrow()
# combine in one table
flowchart <-
  tibble(
    total = n_total,
    treated = n_treated,
    untreated = n_untreated,
    hosp_death_treated = n_hosp_death_treated,
    hosp_death_untreated = n_hosp_death_untreated,
    treated_day5 = n_treated_day5,
    untreated_day5 = n_untreated_day5
  )
# redact (simple redaction, round all to nearest 5)
flowchart_redacted <- 
  flowchart %>%
    mutate(across(where(is.integer), ~ plyr::round_any(.x, 5)))
# Save flowcharts
write_csv(flowchart, path(here("output", "data_properties", "flowchart.csv")))
write_csv(flowchart_redacted, path(here("output", "tables", "flowchart_redacted.csv")))
