######################################

# This script contains one function used in data_process.R:
# - add_status_and_fu_primary: adds colums status_primary and fu_primary to data
#

# linda.nab@thedatalab.org 20220627
######################################

library("lubridate")
library("tidyverse")

# Function 'add_status_and_fu_primary' add columns status_primary and fu_primary
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# - data.frame with two columns added (status_primary and fu_primary, see below)
add_status_and_fu_primary <- function(data){
  data %>%
    mutate(
      # STATUS 'PRIMARY' ----
      # "none": followed for 28 days
      # "dereg": lost to follow up (deregistered)
      # "covid_hosp": covid hospitalisation
      # "covid_death": covid death
      # "noncovid_death": non-covid death
      min_date_primary = pmin(dereg_date,
                              death_date,
                              covid_hosp_admission_date,
                              study_window,
                              na.rm = TRUE),
      status_primary = case_when(
        min_date_primary == dereg_date ~ "dereg",
        min_date_primary == covid_hosp_admission_date ~ "covid_hosp",
        # pt should not have both noncovid and covid death, coded here to 
        # circumvent mistakes if database errors exist
        min_date_primary == covid_death_date ~ "covid_death",
        min_date_primary == noncovid_death_date ~ "noncovid_death",
        TRUE ~ "none"
      ),
      # FOLLOW UP STATUS 'PRIMARY' ----
      fu_primary = case_when(
        status_primary == "none" ~ as.difftime(27, units = "days"),
        status_primary == "dereg" ~ difftime(dereg_date, 
                                             covid_test_positive_date,
                                             units = "days"),
        status_primary == "covid_hosp" ~ difftime(covid_hosp_admission_date,
                                                  covid_test_positive_date,
                                                  units = "days"),
        status_primary == "covid_death" ~ difftime(covid_death_date, 
                                                   covid_test_positive_date,
                                                   units = "days"),
        status_primary == "noncovid_death" ~ difftime(noncovid_death_date, 
                                                      covid_test_positive_date,
                                                      units = "days"),
      ) %>% as.numeric(),
      # combine covid death and hospitalisation
      status_primary = case_when(
        status_primary == "covid_hosp" | 
          status_primary == "covid_death" ~ "covid_hosp_death",
        TRUE ~ status_primary
      ) %>% factor(levels = 
                     c("covid_hosp_death", 
                       "dereg",
                       "none"))
    )
}