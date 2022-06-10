######################################

# Processes data from cohort extract
######################################

## Packages
library('tidyverse')
library('lubridate')
library('here')

## Import custom user functions
#source(here::here("analysis", "functions.R"))

## Print session info to metadata log file
sessionInfo()

## Print variable names
read_csv(here::here("output","input.csv"),
         n_max = 0,
         col_types = cols()) %>%
  names() %>%
  print()

## Read in data and set variable types
data_extract <- read_csv(
  here::here("output", "input.csv"),
  
  # TO DO: ADD OTHER COLS!!!!
  col_types = cols_only(
    
    # Identifier
    patient_id = col_integer(),
    
    # Vaccines 
    vaccination_status = col_character(),
    pfizer_most_recent_cov_vac = col_logical() ,                   
    az_most_recent_cov_vac = col_logical() ,                         
    moderna_most_recent_cov_vac = col_logical(), 
    date_most_recent_cov_vac = col_date(format = "%Y-%m-%d"),
    
    # CENSORING ----
    death_date = col_date(format = "%Y-%m-%d"),
    has_died = col_logical(),
    dereg_date = col_date(format = "%Y-%m-%d"),
    registered_eligible = col_logical(),
    registered_treated = col_logical(),
    
    # NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    paxlovid_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    sotrovimab_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    remdesivir_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    molnupiravir_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    casirivimab_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    
    # ELIGIBILITY CRITERIA VARIABLES ----
    covid_test_positive = col_logical(),
    covid_test_positive_date = col_date(format = "%Y-%m-%d"),
    covid_test_positive_date2 = col_date(format = "%Y-%m-%d"),
    #covid_positive_test_type = col_character(),
    covid_positive_prev_90_days = col_logical(),
    any_covid_hosp_prev_90_days = col_logical(),
    symptomatic_covid_test = col_character(),
    covid_symptoms_snomed = col_date(format = "%Y-%m-%d"),
    age = col_integer(),
    pregnancy = col_logical(),
    pregdel = col_logical(),
    preg_36wks_date = col_date(format = "%Y-%m-%d"),
    weight =  col_double(),
    
    # HIGH RISK GROUPS ----
    high_risk_cohort_covid_therapeutics = col_character(),
    downs_syndrome_nhsd = col_date(format = "%Y-%m-%d"),
    cancer_opensafely_snomed = col_date(format = "%Y-%m-%d"),
    haematological_disease_nhsd = col_date(format = "%Y-%m-%d"), 
    ckd_stage_5_nhsd = col_date(format = "%Y-%m-%d"),
    liver_disease_nhsd = col_date(format = "%Y-%m-%d"),
    immunosuppresant_drugs_nhsd = col_date(format = "%Y-%m-%d"),
    oral_steroid_drugs_nhsd = col_date(format = "%Y-%m-%d"),
    oral_steroid_drug_nhsd_3m_count = col_integer(),
    oral_steroid_drug_nhsd_12m_count = col_integer(),
    immunosupression_nhsd = col_date(format = "%Y-%m-%d"),
    hiv_aids_nhsd = col_date(format = "%Y-%m-%d"),
    solid_organ_transplant_nhsd = col_date(format = "%Y-%m-%d"),
    multiple_sclerosis_nhsd = col_date(format = "%Y-%m-%d"),
    motor_neurone_disease_nhsd = col_date(format = "%Y-%m-%d"),
    myasthenia_gravis_nhsd = col_date(format = "%Y-%m-%d"),
    huntingtons_disease_nhsd = col_date(format = "%Y-%m-%d"),
    
    # CLINICAL/DEMOGRAPHIC COVARIATES ----
    sex = col_character(),
    ethnicity_primis = col_character(),
    ethnicity_sus = col_character(),
    imd = col_character(),
    region_nhs = col_character(),
    region_covid_therapeutics = col_character(),
    stp = col_character(),
    rural_urban = col_character(),
    
    
    # CLINICAL GROUPS ----
    autism_nhsd = col_logical(),
    care_home_primis = col_logical(),
    dementia_nhsd = col_logical(),
    housebound_opensafely = col_logical(),
    learning_disability_primis = col_logical(),
    shielded_primis = col_logical(),
    serious_mental_illness_nhsd = col_logical(),
    sickle_cell_disease_nhsd = col_date(format = "%Y-%m-%d"),
   
    
    # COVID VARIENT
    sgtf = col_character(),
    variant = col_character(),
    
    # OUTCOMES ----
    covid_positive_test_30_days_post_elig_or_treat = col_date(format = "%Y-%m-%d"),
    covid_hospitalisation_outcome_date = col_date(format = "%Y-%m-%d"),
    covid_hospitalisation_critical_care = col_integer(),
    death_with_covid_on_the_death_certificate_date = col_date(format = "%Y-%m-%d"),
    death_with_28_days_of_covid_positive_test = col_logical()
  
  ),
  na = character() # more stable to convert to missing later
)

## Parse NAs
data_extract <- data_extract %>%
  mutate(across(
    .cols = where(is.character),
    .fns = ~na_if(.x, "")
  )) %>%
  # Convert numerics and integers but not id variables to NAs if 0
  mutate(across(
    .cols = c(where(is.numeric), -ends_with("_id")), 
    .fns = ~na_if(.x, 0)
  )) %>%
  # Converts TRUE/FALSE to 1/0
  mutate(across(
    where(is.logical),
    ~.x*1L 
  )) %>%
  arrange(patient_id) 

# data cleaning
# apply any other criteria not in the python code
# ADD TO yaml
# save data