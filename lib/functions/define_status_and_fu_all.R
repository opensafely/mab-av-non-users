######################################

# This script contains one function used in data_process.R:
# - add_status_and_fu_all: adds colums status_all and fu_all to data
#

# linda.nab@thedatalab.org 20220627
######################################
library("lubridate")
library("tidyverse")

# Function 'add_status_and_fu_all' add columns status_all and fu_all
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# - data.frame with two columns added (status_all and fu_all, see below)
add_status_and_fu_all <- function(data){
  data %>%
  mutate(
      # STATUS 'ALL' ----
      # This status will not be used as an outcome in our study, but added as a
      # descriptive
      # "none": followed for 28 days
      # "dereg": lost to follow up (deregistered)
      # "covid_hosp": covid hospitalisation
      # "noncovid_hosp": non-covid hospitalisation
      # "covid_death": covid death
      # "noncovid_death": non-covid death
      min_date_all = pmin(dereg_date,
                          death_date,
                          allcause_hosp_admission_date,
                          study_window,
                          na.rm = TRUE),
      status_all = case_when(
        # pt should not have both noncovid and covid death, coded here to 
        # circumvent database errors
        min_date_all == covid_death_date ~ "covid_death",
        min_date_all == noncovid_death_date ~ "noncovid_death",
        min_date_all == covid_hosp_admission_date ~ "covid_hosp",
        min_date_all == noncovid_hosp_admission_date ~ "noncovid_hosp",
        min_date_all == dereg_date ~ "dereg",
        TRUE ~ "none"
      ) %>% factor(levels = c("covid_death",
                              "noncovid_death",
                              "covid_hosp",
                              "noncovid_hosp",
                              "dereg",
                              "none")),
      # FOLLOW UP STATUS 'ALL" ----
      fu_all = difftime(min_date_all,
                        covid_test_positive_date,
                        units = "days") %>% as.numeric(),
    )
}
