######################################

# Processes data from cohort extract
######################################

## Packages
library('tidyverse')
library('lubridate')
library('here')
library('gt')
library('gtsummary')
library('arrow')
library('reshape2')

## Import custom user functions
source(here::here("lib", "functions.R"))

## Print session info to metadata log file
sessionInfo()

## Print variable names
cat("#### read in data extract ####\n")
## Read in data and set variable types
data_extract <- read_csv(
  here::here("output", "input.csv.gz"),
  col_types = cols_only(
   
    # Identifier
    patient_id = col_integer(),
    
    # POPULATION ----
    age = col_integer(),
    has_died = col_logical() , 
    sex = col_character(),
    imd = col_character(),
    stp = col_character(),
    registered_eligible = col_logical(),
    covid_positive_prev_90_days =col_logical(),
    any_covid_hosp_prev_90_days = col_logical(),
    high_risk_group = col_logical(),
    covid_test_positive = col_logical(),
    prev_treated = col_logical(),
    high_risk_group = col_logical(),
    
    # MAIN ELIGIBILITY - FIRST POSITIVE SARS-CoV-2 TEST IN PERIOD ----
    covid_test_positive_date = col_date(format = "%Y-%m-%d"),
    
    # TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    paxlovid_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    sotrovimab_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    remdesivir_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    molnupiravir_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    casirivimab_covid_therapeutics = col_date(format = "%Y-%m-%d"),
    date_treated = col_date(format = "%Y-%m-%d"),
    
    # PREVIOUS TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    date_treated = col_date(format = "%Y-%m-%d"),
    prev_treated = col_logical(),
    
    # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
    covid_test_positive_date2 = col_date(format = "%Y-%m-%d"),
    symptomatic_covid_test = col_character(),
    pregnancy =col_logical() , 
    covid_symptoms_snomed = col_date(format = "%Y-%m-%d"),
    
    # CENSORING ----
    death_date = col_date(format = "%Y-%m-%d"),
    dereg_date = col_date(format = "%Y-%m-%d"),
    
    # HIGH RISK GROUPS ----
    high_risk_cohort_covid_therapeutics = col_character(),

    huntingtons_disease_nhsd =col_logical() , 
    myasthenia_gravis_nhsd =col_logical() , 
    motor_neurone_disease_nhsd =col_logical() , 
    multiple_sclerosis_nhsd =col_logical() , 
    solid_organ_transplant_nhsd =col_logical() , 
    hiv_aids_nhsd =col_logical() , 
    immunosupression_nhsd =col_logical() , 
    imid_nhsd =col_logical() , 
    liver_disease_nhsd =col_logical() , 
    ckd_stage_5_nhsd =col_logical() , 
    haematological_disease_nhsd =col_logical() , 
    cancer_opensafely_snomed =col_logical() , 
    downs_syndrome_nhsd  =col_logical() , 

    # CLINICAL/DEMOGRAPHIC COVARIATES ----
    diabetes = col_logical(),
    bmi = col_character(),
    smoking_status = col_character(),
    sex = col_character(),
    ethnicity_primis = col_double(),
    ethnicity_sus = col_double(),
    imd = col_double(),
    region_nhs = col_character(),
    stp = col_character(),
    rural_urban = col_character(),
    vaccination_status = col_character(),
    date_most_recent_cov_vac = col_date(format = "%Y-%m-%d"),
    pfizer_most_recent_cov_vac = col_logical(),
    az_most_recent_cov_vac = col_logical(),
    moderna_most_recent_cov_vac = col_logical(),
    sgtf = col_character(),
    variant = col_character(),
    
    # OUTCOMES ----
    covid_positive_test_30_days_post_elig_or_treat = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_date0 = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_date1 = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_date0 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_date1 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_day_date0 = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_day_date1 = col_date(format = "%Y-%m-%d"),
    covid_hosp_outcome_day_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_day_date0 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_day_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_emergency0 =col_date(format = "%Y-%m-%d"),
    covid_hosp_date_emergency1 = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_emergency2 = col_date(format = "%Y-%m-%d"),
    covid_emerg_discharge_date0 = col_date(format = "%Y-%m-%d"),
    covid_emerg_discharge_date1 = col_date(format = "%Y-%m-%d"),
    covid_emerg_discharge_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_mabs_procedure = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_mabs_not_pri = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_mabs_day = col_date(format = "%Y-%m-%d"),
    covid_hosp_date0_not_primary = col_date(format = "%Y-%m-%d"),
    covid_hosp_date1_not_primary = col_date(format = "%Y-%m-%d"),
    covid_hosp_date2_not_primary =col_date(format = "%Y-%m-%d"),
    covid_discharge_date0_not_pri = col_date(format = "%Y-%m-%d"),
    covid_discharge_date1_not_pri =col_date(format = "%Y-%m-%d"),
    covid_discharge_date2_not_pri = col_date(format = "%Y-%m-%d"),
    death_with_covid_on_the_death_certificate_date = col_date(format = "%Y-%m-%d"),
    death_with_covid_underlying_date = col_date(format = "%Y-%m-%d"),
    hospitalisation_outcome_date0 = col_date(format = "%Y-%m-%d"),
    hospitalisation_outcome_date1 = col_date(format = "%Y-%m-%d"),
    hospitalisation_outcome_date2 = col_date(format = "%Y-%m-%d"),
    hosp_discharge_date0 = col_date(format = "%Y-%m-%d"),
    hosp_discharge_date1 = col_date(format = "%Y-%m-%d"),
    hosp_discharge_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_mabs_all_cause = col_date(format = "%Y-%m-%d"),
    
),
  na = character(), # more stable to convert to missing later
)

## Parse NAs
data_extract2 <- data_extract %>%
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
cat("#### data cleaning ####\n")

## Format columns (i.e, set factor levels)
data_processed <- data_extract2 %>%
  mutate(
    # Cinic/demo variables -----
    sex = fct_case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    ),
    
    ethnicity = coalesce(ethnicity_primis, ethnicity_sus),
    
    ethnicity = fct_case_when(
      ethnicity == "1" ~ "White",
      ethnicity == "2" ~ "Mixed",
      ethnicity == "3" ~ "Asian or Asian British",
      ethnicity == "4" ~ "Black or Black British",
      ethnicity == "5" ~ "Other ethnic groups",
      #TRUE ~ "Unknown"
      TRUE ~ NA_character_),
    
    smoking_status = fct_case_when(
      smoking_status == "S" ~ "Smoker",
      smoking_status == "E" ~ "Ever",
      smoking_status == "N" ~ "Never",
      smoking_status == "M" ~ "Missing",
      #TRUE ~ "Unknown"
      TRUE ~ NA_character_),
    
    imd = fct_case_when(
      imd == "5" ~ "5 (least deprived)",
      imd == "4" ~ "4",
      imd == "3" ~ "3",
      imd == "2" ~ "2",
      imd == "1" ~ "1 (most deprived)",
      imd == "0" ~ NA_character_
    ),
  
    region_nhs = fct_case_when(
      region_nhs == "London" ~ "London",
      region_nhs == "East" ~ "East of England",
      region_nhs == "East Midlands" ~ "East Midlands",
      region_nhs == "North East" ~ "North East",
      region_nhs == "North West" ~ "North West",
      region_nhs == "South East" ~ "South East",
      region_nhs == "South West" ~ "South West",
      region_nhs == "West Midlands" ~ "West Midlands",
      region_nhs == "Yorkshire and The Humber" ~ "Yorkshire and the Humber",
      #TRUE ~ "Unknown",
      TRUE ~ NA_character_),
    
    # STP
    stp = as.factor(stp),
    
    # Rural/urban
    rural_urban = fct_case_when(
      rural_urban %in% c(1:2) ~ "Urban - conurbation",
      rural_urban %in% c(3:4) ~ "Urban - city and town",
      rural_urban %in% c(5:6) ~ "Rural - town and fringe",
      rural_urban %in% c(7:8) ~ "Rural - village and dispersed",
      #TRUE ~ "Unknown",
      TRUE ~ NA_character_
    ),
    
    # NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    # Treatment assignment window
    treat_window = covid_test_positive_date + days(5),
    
    # Day of treatment
    tb_postest_treat = ifelse(covid_test_positive == 1, as.numeric(date_treated - covid_test_positive_date), NA),
    
    # Flag records where treatment date falls in treatment assignment window
    treat_check = ifelse(date_treated >= covid_test_positive & date_treated <= treat_window, 1, 0),
    
    # Treatment strategy sep
    treatment_strategy_sep = case_when(
      date_treated == sotrovimab_covid_therapeutics & treat_check == 1 ~ "Sotrovimab",
      date_treated == molnupiravir_covid_therapeutics & treat_check == 1 ~ "Molnupiravir",
      TRUE ~ "Untreated",
    ),
    
    # Treatment strategy overall
    treatment_strategy_overall = case_when(
      (date_treated == sotrovimab_covid_therapeutics & treat_check == 1) | (date_treated == molnupiravir_covid_therapeutics & treat_check == 1)  ~ "Sot/Mol",
      TRUE ~ "Untreated",
    ),
    
    # Identify patients treated with sot and mol on same day
    treated_sot_mol = ifelse(sotrovimab_covid_therapeutics==molnupiravir_covid_therapeutics, 1,0
    ),
    
    # TO BE ADDED: Time between symptom onset and treatment
    #tb_symponset_treat = as.numeric(pmin(as.Date(ifelse(covid_test_positive == 1 & symptomatic_covid_test == "Y", covid_test_positive_date, NA), origin = "1970-01-01"),
    #                                       covid_symptoms_snomed, na.rm = T) - date_treated),
    

    # OUTCOMES ----
    #earliest of covid_test_positive + 28days
    #dereg_date
    #death_date
    #hospitalisation 
    #primary -> covid only 
    #secondary -> all-cause
    
    # Ignore day cases and mab procedures in day 0/1
    ## Primary: COVID-19 Hosp + Death (composite)
    # Censor at earliest of 
    
  ) 

## Apply additional eligibility and exclusion criteria
data_processed_eligible <- data_processed %>%
  filter(
    # Patients treated with both sot and mol on the same day 
    treated_sot_mol  == 0,
  ) 

cat("#### data_processed ####\n")
print(dim(data_processed))

cat("#### data_processed_eligible ####\n")
print(dim(data_processed_eligible))

## Clean data
data_processed_clean <- data_processed_eligible %>% 
  select(
    
    # Identifier
    patient_id,
    
    # POPULATION ----
    age, has_died, sex, imd, stp, registered_eligible, covid_positive_prev_90_days,
    any_covid_hosp_prev_90_days, high_risk_group, covid_test_positive, prev_treated, high_risk_group ,
    
    # MAIN ELIGIBILITY - FIRST POSITIVE SARS-CoV-2 TEST IN PERIOD ----
    covid_test_positive_date, 
    
    # TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ---
    treat_window, tb_postest_treat ,treat_check , treatment_strategy_sep, treatment_strategy_overall , date_treated ,
   
    # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
    covid_test_positive_date2, symptomatic_covid_test, pregnancy, covid_symptoms_snomed,
    
    # CENSORING ----
    death_date,dereg_date ,
    
    # HIGH RISK GROUPS ----
    high_risk_cohort_covid_therapeutics ,
    huntingtons_disease_nhsd , 
    myasthenia_gravis_nhsd  , 
    motor_neurone_disease_nhsd,
    multiple_sclerosis_nhsd , 
    solid_organ_transplant_nhsd , 
    hiv_aids_nhsd , 
    immunosupression_nhsd = , 
    imid_nhsd  , 
    liver_disease_nhsd  , 
    ckd_stage_5_nhsd  , 
    haematological_disease_nhsd , 
    cancer_opensafely_snomed  , 
    downs_syndrome_nhsd  , 
    
    # CLINICAL/DEMOGRAPHIC COVARIATES ----
    diabetes  ,
    bmi  ,
    smoking_status ,
    sex ,
    ethnicity  ,
    imd  ,
    region_nhs ,
    stp  ,
    rural_urban  ,
    vaccination_status  ,
    date_most_recent_cov_vac  ,
    pfizer_most_recent_cov_vac,
    az_most_recent_cov_vac ,
    moderna_most_recent_cov_vac ,
    sgtf ,
    variant,
)
# save data
write_rds(data_processed_clean, here::here("output", "data", "data_processed.rds"), compress = "gz")
write_csv(data_processed_clean, here::here("output", "data", "data_processed.csv"))