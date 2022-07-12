######################################

# crosstabulates outcomes and trt group
######################################

# libraries
library(readr)
library(dplyr)
library(fs)

# load data
data_cohort_day5 <- 
  read_rds(here::here("output", "data", "data_processed_day5.rds"))
data_cohort_day0 <-
  read_rds(here::here("output", "data", "data_processed_day0.rds"))

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
              path("output", "data_properties", filename))
}

# print crosstabulation
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
     