######################################

# This script contains two functions used in data_process.R:
# - summarise_covid_admissions: combining covid_admissions columns
# - add_hospital_admission_outcome: logic for one new colums:
#   1) covid_hosp_admission
# The logic followed can be found in this Gdoc: 
# https://docs.google.com/document/d/1XmO9He_j-xw8c6a6iLzeCBdDgjmbpkcFIzBLRR8g9NA/edit#

# linda.nab@thedatalab.org 20220624
######################################

library("lubridate")
library("tidyverse")

# Function 'summarise_covid_admissions' summarises covid admissions
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# - data.frame with four columns added (see below)
summarise_covid_admissions <- function(data){
  data <- 
    data %>%
    # add columns 
    # - 'covid_hosp_admission_first':
    #    first hospital admission between date 0 and date 27 (used as the outcome
    #    for all non-sotro treated patients)
    # - 'covid_hosp_admission_first_data0_6':
    #    first admission between date 0 (+ve test) and date 6
    # - 'covid_hosp_admission_2nd_date_0_27':
    #    second admission between date 0 (+ve test) and date 27 (end of study)
    # - 'days_between_treatment_and_first_covid_admission':
    #    number of days between treatment and first covid admission because if 
    #    number of days small, this might be the admission for sotro infusion
    # - 'days_between_first_covid_admission_and_discharge':
    #    number of days between first covid admission and discharge because if 
    #    discharge is quickly after admission, this might be the admission for
    #    sotro infusion
  rowwise() %>%
  mutate(
    covid_hosp_admission_first =
      first(na.omit(c(covid_hosp_admission_date0,
                      covid_hosp_admission_date1,
                      covid_hosp_admission_date2,
                      covid_hosp_admission_date3,
                      covid_hosp_admission_date4,
                      covid_hosp_admission_date5,
                      covid_hosp_admission_date6,
                      covid_hosp_admission_first_date7_27))),
    covid_hosp_admission_first_date0_6 = 
      first(na.omit(c(covid_hosp_admission_date0,
                      covid_hosp_admission_date1,
                      covid_hosp_admission_date2,
                      covid_hosp_admission_date3,
                      covid_hosp_admission_date4,
                      covid_hosp_admission_date5,
                      covid_hosp_admission_date6))),
    covid_hosp_admission_2nd_date0_27 = 
      nth(na.omit(c(covid_hosp_admission_date0,
                    covid_hosp_admission_date1,
                    covid_hosp_admission_date2,
                    covid_hosp_admission_date3,
                    covid_hosp_admission_date4,
                    covid_hosp_admission_date5,
                    covid_hosp_admission_date6,
                    covid_hosp_admission_first_date7_27)), n = 2),
    days_between_treatment_and_first_covid_admission = 
      # NA if one or both NA_Date_
      difftime(covid_hosp_admission_first_date0_6,
               date_treated) %>% as.numeric(), 
    days_between_first_covid_admission_and_discharge = 
      # NA if one or both NA_Date_
      difftime(covid_hosp_discharge_first_date0_7,
               covid_hosp_admission_first_date0_6) %>% as.numeric() 
  ) %>% ungroup()
}

# Function 'add_hosp_admission_outcome' add admissions outcome
# Input:
# - data: data.frame with the data extracted using study_definition.py
# Output:
# data.frame with two colums added: covid_hosp_admission_sotro and 
# covid_hosp_admission and all other covid admission columns deleted
add_covid_hosp_admission_outcome <- function(data){
  data %>%
    mutate(
      # add column 'covid_hosp_admission' that omits hospital admissions
      # that are likely to be an admission for getting an sotro infusion and
      # therefore not counted as an outcome
      covid_hosp_admission_date = case_when(
        # NOT TREATED
        # --> no 'special' rules needed for determining the outcome 
        is.na(date_treated) ~ covid_hosp_admission_first,
        # NOT TREATED WITH SOTRO
        # --> no 'special' rules needed for determining the outcome 
        treatment_strategy_cat != "Sotrovimab" ~ covid_hosp_admission_first,
        # NO HOSPITAL ADMISSION DAYS 0 - 6
        # --> outcome is hospital admission between days 7-27 (NA if there isnt 
        # any)
        is.na(covid_hosp_admission_first_date0_6) ~ 
          covid_hosp_admission_first_date7_27,
        # HOSPITAL ADMISSION DAYS 0 - 6
        # --> in general, this admission is counted as the outcome, except for 
        # two settings:
        # EXCEPTION 1. days between treatment and first hospital admission
        # is 0, 1 or 2 days AND the number of days between that admission and 
        # discharge is 0 or 1 days. 
        # if so --> use second admission as the outcome (NA if there isnt any)
        (!is.na(covid_hosp_admission_first_date0_6) & 
          between(days_between_treatment_and_first_covid_admission, 0, 2) & 
          (!is.na(days_between_first_covid_admission_and_discharge) & 
             between(days_between_first_covid_admission_and_discharge, 0, 1))) ~ 
          covid_hosp_admission_2nd_date0_27,
        # EXCEPTION 2. first admission was associated with a mabs procedure
        # --> use second hospital admission as the outcome (NA if there
        # isnt any)
        (!is.na(covid_hosp_admission_first_date0_6) & 
          covid_hosp_date_mabs_procedure == covid_hosp_admission_first_date0_6) ~ 
          covid_hosp_admission_2nd_date0_27,
        # --> as stated above, if not one of the two exceptions, outcome is the 
        # the first hospital admission
        TRUE ~ covid_hosp_admission_first_date0_6)
      ) %>%
    # deselect all columns not needed
    select(-c(covid_hosp_admission_date0,
              covid_hosp_admission_date1,
              covid_hosp_admission_date2,
              covid_hosp_admission_date3,
              covid_hosp_admission_date4,
              covid_hosp_admission_date5,
              covid_hosp_admission_date6,
              covid_hosp_admission_first_date7_27,
              covid_hosp_admission_first,
              covid_hosp_admission_first_date0_6,
              covid_hosp_admission_2nd_date0_27,
              days_between_treatment_and_first_covid_admission,
              covid_hosp_discharge_first_date0_7,
              days_between_first_covid_admission_and_discharge))
}
