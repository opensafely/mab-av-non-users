######################################

# This script contains one function used in data_process.R:
# - add_status_and_fu_secondary: adds colums status_secondary and 
#   fu_secondary to data
#

# linda.nab@thedatalab.org 20220627
######################################

library("lubridate")
library("tidyverse")

# Function 'add_status_and_fu_secondary' add columns status_secondary and 
# fu_secondary
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# - data.frame with two columns added (status_secondary and fu_secondary, 
#   see below)
add_status_and_fu_secondary <- function(data){
  data %>%
    mutate(
      # STATUS 'SECONDARY' ----
      # "none": followed for 28 days
      # "dereg": lost to follow up (deregistered)
      # "allcause_hosp": covid hospitalisation
      # "allcause_death": covid death
      min_date_secondary = pmin(dereg_date,
                                death_date,
                                allcause_hosp_admission_date,
                                study_window,
                                na.rm = TRUE),
      status_secondary = case_when(
        min_date_secondary == death_date ~ "allcause_death",
        min_date_secondary == allcause_hosp_admission_date ~ "allcause_hosp",
        min_date_secondary == dereg_date ~ "dereg",
        TRUE ~ "none"
      ),
      # FOLLOW UP STATUS 'SECONDARY' ----
      # FOLLOW UP STATUS 'ALL" ----
      fu_secondary = difftime(min_date_secondary,
                              covid_test_positive_date,
                              units = "days") %>% as.numeric(),
      # combine covid death and hospitalisation
      status_secondary = if_else(
        status_secondary == "allcause_hosp" | 
          status_secondary == "allcause_death",
        "allcause_hosp_death",
        status_secondary
      ) %>% factor(levels = c("allcause_hosp_death",
                              "dereg",
                              "none"))
    )
}