######################################

# This script contains one function used in data_process.R:
# - add_allcause_hosp_diagnosis: adds colums allcause_hosp_diagnosis
# ** can only be used after adding allcause_hosp_admission_date
#    --> see function ./lib/functions/define_allcause_hosp_admissions.R

# linda.nab@thedatalab.org 20220720
######################################

library("lubridate")
library("tidyverse")

# Function add_allcause_hosp_diagnosis' add columns allcause_hosp_diagnosis
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# - data.frame with one columns added (allcause_hosp_diagnosis, see below)
add_allcause_hosp_diagnosis <- function(data){
  # the first hospital admission can be in the first 6 days (including day 6),
  # if so, outcome for sotrovimab is defined as first hospital admission likely
  # not associated with sotrovimab infusion, leading to an odd way of extracting
  # outcome data. Therefore, we need to find out which hospital admission (if any)
  # was used as the outcome, and if that outcome was used, define 
  # 'allcause_hosp_diagnosis' as the diagnosis associated with the admission on
  # that date
  data %>%
    mutate(allcause_hosp_diagnosis = case_when(
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date0) &
        allcause_hosp_admission_date == allcause_hosp_admission_date0 ~
                                        allcause_hosp_admission_diagnosis0,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date1) &
        allcause_hosp_admission_date == allcause_hosp_admission_date1 ~
        allcause_hosp_admission_diagnosis1,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date2) &
        allcause_hosp_admission_date == allcause_hosp_admission_date2 ~
        allcause_hosp_admission_diagnosis2,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date3) &
        allcause_hosp_admission_date == allcause_hosp_admission_date3 ~
        allcause_hosp_admission_diagnosis3,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date4) &
        allcause_hosp_admission_date == allcause_hosp_admission_date4 ~
        allcause_hosp_admission_diagnosis4,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date5) &
        allcause_hosp_admission_date == allcause_hosp_admission_date5 ~
        allcause_hosp_admission_diagnosis5,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_date6) &
        allcause_hosp_admission_date == allcause_hosp_admission_date0 ~
        allcause_hosp_admission_diagnosis6,
      !is.na(allcause_hosp_admission_date) & !is.na(allcause_hosp_admission_first_date7_27) &
        allcause_hosp_admission_date == allcause_hosp_admission_first_date7_27 ~
        allcause_hosp_admission_first_diagnosis7_27,
      TRUE ~ "not hospitalised") %>% as.factor()
    )
}
