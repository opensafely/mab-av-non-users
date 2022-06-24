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
source(here::here("lib", "functions", "functions.R"))
source(here::here("lib", "functions", "define_covid_hosp_admissions.R"))
source(here::here("lib", "functions", "define_allcause_hosp_admissions.R"))

## Print session info to metadata log file
sessionInfo()

## Print variable names
cat("#### read in data extract ####\n")
## Read in data and set variable types
data <- read_csv(here::here("output", "input.csv.gz"))

data_extract <- read_csv(
  here::here("output", "input.csv.gz"),
  col_types = cols_only(
   
    # Identifier
    patient_id = col_integer(),
    
    # POPULATION ----
    age = col_integer(),
    sex = col_character(),
    ethnicity = col_character(),
    imdQ5 = col_character(),
    region_nhs = col_character(),
    stp = col_character(),
    rural_urban = col_character(),
    
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
    
    # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
    symptomatic_covid_test = col_character(),
    covid_symptoms_snomed = col_date(format = "%Y-%m-%d"),
    pregnancy = col_logical(),
    
    # CENSORING ----
    death_date = col_date(format = "%Y-%m-%d"),
    dereg_date = col_date(format = "%Y-%m-%d"),
    
    # HIGH RISK GROUPS ----
    high_risk_cohort_covid_therapeutics = col_character(),
    huntingtons_disease_nhsd = col_logical() , 
    myasthenia_gravis_nhsd = col_logical() , 
    motor_neurone_disease_nhsd = col_logical() , 
    multiple_sclerosis_nhsd = col_logical() , 
    solid_organ_transplant_nhsd = col_logical(), 
    hiv_aids_nhsd = col_logical(), 
    immunosupression_nhsd = col_logical(), 
    imid_nhsd = col_logical(), 
    liver_disease_nhsd = col_logical(), 
    ckd_stage_5_nhsd = col_logical(), 
    haematological_disease_nhsd = col_logical(), 
    cancer_opensafely_snomed = col_logical(), 
    downs_syndrome_nhsd  = col_logical(), 

    # CLINICAL/DEMOGRAPHIC COVARIATES ----
    diabetes = col_character(),
    bmi = col_character(),
    smoking_status = col_character(),
    copd = col_logical(),
    dialysis = col_logical(),
    cancer = col_logical(),
    lung_cancer = col_logical(),
    haem_cancer = col_logical(),
    
    # VACCINATION ----
    vaccination_status = col_character(),
    date_most_recent_cov_vac = col_date(format = "%Y-%m-%d"),
    pfizer_most_recent_cov_vac = col_logical(),
    az_most_recent_cov_vac = col_logical(),
    moderna_most_recent_cov_vac = col_logical(),
    
    # VARIANT ----
    sgtf = col_character(),
    variant = col_character(),
    
    # OUTCOMES ----
    # covid specific
    covid_hosp_admission_date0 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date1 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date2 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date3 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date4 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date5 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_date6 = col_date(format = "%Y-%m-%d"),
    covid_hosp_admission_first_date7_27 = col_date(format = "%Y-%m-%d"),
    covid_hosp_discharge_first_date0_7 = col_date(format = "%Y-%m-%d"),
    covid_hosp_date_mabs_procedure = col_date(format = "%Y-%m-%d"),
    # all cause
    allcause_hosp_admission_date0 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date1 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date2 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date3 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date4 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date5 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_date6 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_admission_first_date7_27 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_discharge_first_date0_7 = col_date(format = "%Y-%m-%d"),
    allcause_hosp_date_mabs_procedure = col_date(format = "%Y-%m-%d"),
    # death
    died_ons_covid_any_date = col_date(format = "%Y-%m-%d")
),
  na = character(), # more stable to convert to missing later
)

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
    
    ethnicity = fct_case_when(
      ethnicity == "0" ~ "Unknown",
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
    
    imdQ5 = fct_case_when(
      imdQ5 == "5 (least deprived)" ~ "5 (least deprived)",
      imdQ5 == "4" ~ "4",
      imdQ5 == "3" ~ "3",
      imdQ5 == "2" ~ "2",
      imdQ5 == "1 (most deprived)" ~ "1 (most deprived)",
      TRUE ~ NA_character_
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
    # Treatment assignment window 'treated within 5 days -> <= 4 days'
    treat_window = covid_test_positive_date + days(4),
    
    # Time-between positive test and day of treatment
    tb_postest_treat = ifelse(!is.na(date_treated), difftime(date_treated, covid_test_positive_date), NA),
    
    # Flag records where treatment date falls in treatment assignment window
    treat_check = ifelse(date_treated >= covid_test_positive_date & date_treated <= treat_window, 1, 0),
    
    # Treatment strategy categories
    treatment_strategy_cat = case_when(
      date_treated == sotrovimab_covid_therapeutics & treat_check == 1 ~ "Sotrovimab",
      date_treated == molnupiravir_covid_therapeutics & treat_check == 1 ~ "Molnupiravir",
      TRUE ~ "Untreated",
    ),
    
    # Treatment strategy overall
    treatment = case_when(
      (date_treated == sotrovimab_covid_therapeutics & treat_check == 1) | (date_treated == molnupiravir_covid_therapeutics & treat_check == 1)  ~ "Treated",
      TRUE ~ "Untreated",
    ),
    
    # Treatment date
    treatment_date = ifelse(treatment == "Treated", date_treated, NA
    ),
    
    # Identify patients treated with sot and mol on same day
    treated_sot_mol_same_day = ifelse(sotrovimab_covid_therapeutics==molnupiravir_covid_therapeutics, 1,0
    ),
    
    # Time-between symptom onset and treatment in those treatead
    tb_symponset_treat = as.numeric(pmin(base::as.Date(ifelse(symptomatic_covid_test == "Y", covid_test_positive_date, NA), origin = "1970-01-01"),
                                          covid_symptoms_snomed, na.rm = T) - treatment_date
    ),
    
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
    
  ) %>%
  summarise_covid_admissions() %>%
  summarise_allcause_admissions()

## Apply additional eligibility and exclusion criteria
data_processed_eligible <- data_processed %>%
  filter(
    # Exclude patients treated with both sotrovimab and molnupiravir on the same day 
    treated_sot_mol_same_day  == 0,
  ) 

cat("#### data_processed ####\n")
print(dim(data_processed))

cat("#### data_processed_eligible ####\n")
print(dim(data_processed_eligible))

# save data
fs::dir_create(here::here("output", "data"))
write_rds(data_processed, here::here("output", "data", "data_processed.rds"), compress = "gz")
write_csv(data_processed_eligible, here::here("output", "data", "data_processed.csv"))
