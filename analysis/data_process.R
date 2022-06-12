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

## Format columns (i.e, set factor levels)
data_processed <- data_extract %>%
  mutate(
    
    # NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    treatment_date = as.Date(pmin(paxlovid_covid_therapeutics, sotrovimab_covid_therapeutics, 
                                  remdesivir_covid_therapeutics, molnupiravir_covid_therapeutics, 
                                  casirivimab_covid_therapeutics, na.rm = TRUE), origin = "1970-01-01"),
    treatment_type = case_when(
      treatment_date == paxlovid_covid_therapeutics ~ "Paxlovid", 
      treatment_date == sotrovimab_covid_therapeutics ~ "Sotrovimab", 
      treatment_date == remdesivir_covid_therapeutics ~ "Remdesivir", 
      treatment_date == molnupiravir_covid_therapeutics ~ "Molnupiravir", 
      treatment_date == casirivimab_covid_therapeutics ~ "Casirivimab", 
      TRUE ~ NA_character_),
    
    
    # ELIGIBILITY VARIABLES ----
    
    ## Time between positive test and treatment
    tb_postest_treat = ifelse(covid_test_positive == 1, as.numeric(treatment_date - covid_test_positive_date), NA),
    
    ## Time between positive test and symptom onset
    tb_symponset_treat = as.numeric(treatment_date -
                                      pmin(as.Date(ifelse(covid_test_positive == 1 & symptomatic_covid_test == "Y", covid_test_positive_date, NA), origin = "1970-01-01"),
                                           covid_symptoms_snomed, na.rm = T)),
    
    ## IMID - only include patients on corticosteroids (where 2 prescriptions have been issued in 3 month, or 4 prescriptions in 12 months) 
    oral_steroid_drugs_nhsd = as.Date(ifelse(oral_steroid_drug_nhsd_3m_count >= 2 | oral_steroid_drug_nhsd_12m_count >= 4, 
                                             oral_steroid_drugs_nhsd, NA), origin = "1970-01-01"),
    imid_nhsd = pmin(oral_steroid_drugs_nhsd, immunosuppresant_drugs_nhsd, na.rm = T),
    
    ## Convert sickle cell disease from date
    sickle_cell_disease_nhsd = ifelse(!is.na(sickle_cell_disease_nhsd), 1, 0),
    
    # Combine subgoups of rare neurological conditions cohort
    rare_neurological_conditions_nhsd =  pmin(multiple_sclerosis_nhsd, motor_neurone_disease_nhsd, myasthenia_gravis_nhsd,
                                              huntingtons_disease_nhsd, na.rm = T),
    ## Eligibility window
    high_risk_group_nhsd_date = pmin(downs_syndrome_nhsd, cancer_opensafely_snomed,
                                     haematological_disease_nhsd, ckd_stage_5_nhsd, liver_disease_nhsd, imid_nhsd,
                                     immunosupression_nhsd, hiv_aids_nhsd, solid_organ_transplant_nhsd, rare_neurological_conditions_nhsd,
                                     na.rm = TRUE),
    
    elig_start = as.Date(ifelse(covid_test_positive <= Sys.Date() & covid_test_positive == 1 & (covid_test_positive_date >= high_risk_group_nhsd_date), 
                                covid_test_positive_date, NA), origin = "1970-01-01"),
    # HIGH RISK GROUPS ----
    downs_syndrome_nhsd_name = ifelse(!is.na(downs_syndrome_nhsd), "Down's syndrome", NA),
    cancer_opensafely_name = ifelse(!is.na(cancer_opensafely_snomed), "solid cancer", NA),
    haematological_disease_nhsd_name = ifelse(!is.na(haematological_disease_nhsd), "haematological diseases and stem cell transplant recipients", NA),
    ckd_stage_5_nhsd_name = ifelse(!is.na(ckd_stage_5_nhsd), "renal disease", NA),
    liver_disease_nhsd_name = ifelse(!is.na(liver_disease_nhsd), "liver disease", NA),
    imid_nhsd_name = ifelse(!is.na(imid_nhsd), "IMID", NA),
    immunosupression_nhsd_name = ifelse(!is.na(immunosupression_nhsd), "primary immune deficiencies", NA),
    hiv_aids_nhsd_name = ifelse(!is.na(hiv_aids_nhsd), "HIV or AIDS immunosupression", NA),
    solid_organ_transplant_nhsd_name = ifelse(!is.na(solid_organ_transplant_nhsd), "solid organ recipients", NA),
    rare_neurological_conditions_nhsd_name = ifelse(!is.na(rare_neurological_conditions_nhsd), "rare neurological conditions", NA),
    
    downs_syndrome_nhsd = ifelse(!is.na(downs_syndrome_nhsd), 1, NA),
    cancer_opensafely = ifelse(!is.na(cancer_opensafely_snomed), 1, NA),
    haematological_disease_nhsd = ifelse(!is.na(haematological_disease_nhsd), 1, NA),
    ckd_stage_5_nhsd = ifelse(!is.na(ckd_stage_5_nhsd), 1, NA),
    liver_disease_nhsd = ifelse(!is.na(liver_disease_nhsd), 1, NA),
    imid_nhsd = ifelse(!is.na(imid_nhsd), 1, NA),
    immunosupression_nhsd = ifelse(!is.na(immunosupression_nhsd), 1, NA),
    hiv_aids_nhsd = ifelse(!is.na(hiv_aids_nhsd), 1, NA),
    solid_organ_transplant_nhsd = ifelse(!is.na(solid_organ_transplant_nhsd), 1, NA),
    rare_neurological_conditions_nhsd = ifelse(!is.na(rare_neurological_conditions_nhsd), 1, NA),
    
    high_risk_cohort_covid_therapeutics =ifelse(high_risk_cohort_covid_therapeutics == "other", NA, high_risk_cohort_covid_therapeutics),
    downs_syndrome_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "Downs syndrome") == TRUE, 1, NA),
    cancer_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "solid cancer") == TRUE, 1, NA),
    haematological_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "haematological diseases and stem cell transplant recipients") == TRUE, 1, NA),
    haematological_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "haematological diseases") == TRUE, 1, haematological_disease_therapeutics),
    haematological_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "haematologic malignancy") == TRUE, 1, haematological_disease_therapeutics),
    haematological_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "stem cell transplant recipients") == TRUE, 1, haematological_disease_therapeutics),
    haematological_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "sickle cell disease") == TRUE, 1, haematological_disease_therapeutics),
    ckd_stage_5_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "renal disease") == TRUE, 1, NA),
    liver_disease_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "liver disease") == TRUE, 1, NA),
    imid_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "IMID") == TRUE, 1, NA),
    immunosupression_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "primary immune deficiencies") == TRUE, 1, NA),
    hiv_aids_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "HIV or AIDS") == TRUE, 1, NA),
    solid_organ_transplant_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "solid organ recipients") == TRUE, 1, NA),
    solid_organ_transplant_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "solid organ transplant recipients") == TRUE, 1, solid_organ_transplant_therapeutics),
    rare_neurological_conditions_therapeutics = ifelse(str_detect(high_risk_cohort_covid_therapeutics, "rare neurological conditions") == TRUE, 1, NA),   
    
    downs_syndrome = ifelse(downs_syndrome_nhsd == 1 | downs_syndrome_therapeutics == 1, 1, NA),
    solid_cancer = ifelse(cancer_opensafely == 1 | cancer_therapeutics == 1, 1, NA),
    haematological_disease = ifelse(haematological_disease_nhsd == 1 | haematological_disease_therapeutics == 1, 1, NA),
    renal_disease = ifelse(ckd_stage_5_nhsd == 1 | ckd_stage_5_therapeutics == 1, 1, NA),
    liver_disease = ifelse(liver_disease_nhsd == 1 | liver_disease_therapeutics == 1, 1, NA),
    imid = ifelse(imid_nhsd == 1 | imid_therapeutics == 1, 1, NA),
    immunosupression = ifelse(immunosupression_nhsd == 1 | immunosupression_therapeutics == 1, 1, NA),
    hiv_aids = ifelse(hiv_aids_nhsd == 1 | hiv_aids_therapeutics == 1, 1, NA),
    solid_organ_transplant = ifelse(solid_organ_transplant_nhsd == 1 | solid_organ_transplant_therapeutics == 1, 1, NA),
    rare_neurological_conditions = ifelse(rare_neurological_conditions_nhsd == 1 | rare_neurological_conditions_therapeutics == 1, 1, NA)
    
  ) %>%
  unite("high_risk_group_nhsd_combined", downs_syndrome_nhsd_name, cancer_opensafely_name,
        haematological_disease_nhsd_name, ckd_stage_5_nhsd_name, liver_disease_nhsd_name, imid_nhsd_name, immunosupression_nhsd_name, 
        hiv_aids_nhsd_name, solid_organ_transplant_nhsd_name, rare_neurological_conditions_nhsd_name, sep = ",", na.rm = T) %>%
  mutate(
    
    ## Find matches between nhsd high risk cohorts and therapeutics high risk cohorts 
    ind_therapeutic_groups = map_chr(strsplit(high_risk_cohort_covid_therapeutics, ","), paste,collapse="|"),
    #match = str_detect(high_risk_group_nhsd_combined, ind_therapeutic_groups),
    match = ifelse(downs_syndrome_nhsd == 1 & downs_syndrome_therapeutics == 1 |
                     cancer_opensafely == 1 & cancer_therapeutics == 1 |
                     haematological_disease_nhsd == 1 & haematological_disease_therapeutics == 1 |
                     ckd_stage_5_nhsd == 1 & ckd_stage_5_therapeutics == 1 |
                     liver_disease_nhsd == 1 & liver_disease_therapeutics == 1 |
                     imid_nhsd == 1 & imid_therapeutics == 1 |
                     immunosupression_nhsd == 1 & immunosupression_therapeutics == 1 |
                     hiv_aids_nhsd == 1 & hiv_aids_therapeutics == 1 |
                     solid_organ_transplant_nhsd == 1 & solid_organ_transplant_therapeutics == 1 |
                     rare_neurological_conditions_nhsd == 1 & rare_neurological_conditions_therapeutics == 1, 1, NA),
    
    ## Parse NAs
    high_risk_group_nhsd_combined = ifelse(high_risk_group_nhsd_combined == "", NA, high_risk_group_nhsd_combined),
    high_risk_cohort_covid_therapeutics = ifelse(high_risk_cohort_covid_therapeutics == "", NA, high_risk_cohort_covid_therapeutics)
  ) %>%
  ## Combine groups
  unite("high_risk_group_combined", c(high_risk_group_nhsd_combined, high_risk_cohort_covid_therapeutics), sep = ",", 
        na.rm = TRUE, remove = FALSE) %>%
  rowwise() %>%
  mutate(high_risk_group_combined = as.character(paste(unique(unlist(strsplit(high_risk_group_combined, ","))), collapse = ",")),
         high_risk_group_combined = ifelse(high_risk_group_combined == "", NA, high_risk_group_combined),
         high_risk_group_combined_count = ifelse(high_risk_group_combined != "" | high_risk_group_combined != "NA" | !is.na(high_risk_group_combined), 
                                                 str_count(high_risk_group_combined,",") + 1, NA)) %>%
  ungroup() %>%
  mutate(
    
    # Cinic/demo variables
    sex = fct_case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      #sex == "I" ~ "Inter-sex",
      #sex == "U" ~ "Unknown",
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
    
    imd = na_if(imd, "0"),
    imd = fct_case_when(
      imd == 1 ~ "1 most deprived",
      imd == 2 ~ "2",
      imd == 3 ~ "3",
      imd == 4 ~ "4",
      imd == 5 ~ "5 least deprived",
      #TRUE ~ "Unknown",
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
    )
    
    # OUTCOMES ----
    
    
  )

# Save dataset(s) ----
write_rds(data_processed, here::here("output", "data", "data_processed.rds"), compress = "gz")


# Process clean data ----
cat("#### process clean data ####\n")

## Apply eligibility and exclusion criteria
data_processed_eligible <- data_processed %>%
  filter(
    # Alive and registered
    has_died == 0,
    registered_eligible == 1,
    
    # Overall eligibility criteria
    covid_test_positive == 1,
    covid_positive_previous_90_days != 1,
    #symptomatic_covid_test != "N",
    !is.na(high_risk_group_nhsd_combined) | high_risk_group_nhsd_combined != "NA",
    !is.na(elig_start)
    
    # Overall exclusion criteria
    
    # hosp and other stuff to be added
  ) %>%
  mutate(eligibility_status = "Eligible")

cat("#### eligible patients ####\n")
print(dim(data_processed_eligible))
print(table(data_processed_eligible$match))
print(table(data_processed_eligible$symptomatic_covid_test))

## Include registered treated patients not flagged as eligible
data_processed_treated <- data_processed %>%
  filter(
    # Treated but non-eligible patients
    !is.na(treatment_date),
    !(patient_id %in% unique(data_processed_eligible$patient_id))
    
  ) %>%
  mutate(elig_start = coalesce(elig_start, treatment_date),
         eligibility_status = "Treated")

cat("#### treated patients ####\n")
print(dim(data_processed_treated))
print(table(data_processed_treated$match))
print(table(data_processed_treated$symptomatic_covid_test))

## Free up space and combine
rm(data_processed)

data_processed_combined <- rbind(data_processed_eligible, data_processed_treated)

rm(data_processed_eligible)
rm(data_processed_treated)

cat("#### All patients ####\n")
print(dim(data_processed_combined))
print(table(data_processed_combined$eligibility_status))
print(table(data_processed_combined$eligibility_status, data_processed_combined$match))

## Exclude patients issued more than one treatment within two weeks
dup_ids <- data_processed_combined %>%
  select(patient_id, treatment_date, covid_test_positive_date, paxlovid_covid_therapeutics, sotrovimab_covid_therapeutics, remdesivir_covid_therapeutics,
         molnupiravir_covid_therapeutics, casirivimab_covid_therapeutics) %>%
  filter(!is.na(treatment_date)) %>%
  mutate(pax_sot_diff = as.numeric(paxlovid_covid_therapeutics - sotrovimab_covid_therapeutics),
         pax_mol_diff = as.numeric(paxlovid_covid_therapeutics - remdesivir_covid_therapeutics),
         pax_rem_diff = as.numeric(paxlovid_covid_therapeutics - molnupiravir_covid_therapeutics),
         pax_cas_diff = as.numeric(paxlovid_covid_therapeutics - casirivimab_covid_therapeutics),
         sot_rem_diff = as.numeric(sotrovimab_covid_therapeutics - remdesivir_covid_therapeutics),
         sot_mol_diff = as.numeric(sotrovimab_covid_therapeutics - molnupiravir_covid_therapeutics),
         sot_cas_diff = as.numeric(sotrovimab_covid_therapeutics - casirivimab_covid_therapeutics),
         rem_mol_diff = as.numeric(remdesivir_covid_therapeutics - molnupiravir_covid_therapeutics),
         rem_cas_diff = as.numeric(remdesivir_covid_therapeutics - casirivimab_covid_therapeutics),
         mol_cas_diff = as.numeric(molnupiravir_covid_therapeutics - casirivimab_covid_therapeutics)) %>%
  melt(id.var = "patient_id", measure.vars = c("pax_sot_diff", "pax_mol_diff", "pax_rem_diff", "pax_cas_diff",
                                               "sot_rem_diff", "sot_mol_diff", "sot_cas_diff", "rem_mol_diff",
                                               "rem_cas_diff", "mol_cas_diff")) %>%
  filter(!is.na(value),
         value <= 14 | value >= -14) %>%
  group_by(patient_id) %>%
  arrange(patient_id)

cat("#### patients with more than one treatment ####\n")
print(length(unique(dup_ids$patient_id)))

## Exclude patients with implausible treatment date
date_ids <- data_processed_combined %>%
  select(patient_id, treatment_date, covid_test_positive_date) %>%
  filter((treatment_date <= covid_test_positive_date - 21 | treatment_date >= Sys.Date()))

cat("#### patients with implausible treatment date ####\n")
print(length(unique(date_ids$patient_id)))

## Clean data
data_processed_clean <- data_processed_combined %>%
  filter(elig_start <= Sys.Date(),
         !(patient_id %in% unique(dup_ids$patient_id)),
         !(patient_id %in% unique(date_ids$patient_id))) %>%
  select(
    
    # ID
    patient_id, eligibility_status,
    
    # Censoring
    start_date, has_died, death_date, dereg_date, registered_eligible, registered_treated,
    
    # Eligibility
    covid_test_positive, symptomatic_covid_test, covid_test_positive_date, covid_positive_previous_30_days, tb_postest_treat, 
    tb_symponset_treat, elig_start, primary_covid_hospital_discharge_date, any_covid_hospital_discharge_date, pregnancy,
    weight,
    
    # Treatment
    paxlovid_covid_therapeutics, sotrovimab_covid_therapeutics, remdesivir_covid_therapeutics, molnupiravir_covid_therapeutics, 
    casirivimab_covid_therapeutics, treatment_date, treatment_type,
    
    # High risk cohort
    downs_syndrome, solid_cancer, haematological_disease, renal_disease, liver_disease, imid, immunosupression, 
    hiv_aids, solid_organ_transplant, rare_neurological_conditions, high_risk_group_nhsd_combined, high_risk_cohort_covid_therapeutics, 
    match, high_risk_group_combined, high_risk_group_combined_count, 
    
    # Clinical and demographic variables
    age, sex, ethnicity, imd, rural_urban, region_nhs, region_covid_therapeutics, stp,
    
    # Clinical groups
    autism_nhsd, care_home_primis, dementia_nhsd, housebound_opensafely, learning_disability_primis, shielded_primis, 
    serious_mental_illness_nhsd, sickle_cell_disease_nhsd, vaccination_status,
    
    # COVID variant
    sgtf, variant,
    
    # Outcomes
    covid_positive_test_30_days_post_elig_or_treat, covid_positive_test_30_days_post_elig_or_treat_date,
    covid_hospital_admission, covid_hospitalisation_outcome_date,
    covid_hospitalisation_critical_care,
    covid_death, any_death)

cat("#### patients excluded ####\n")
print(dim(data_processed_combined)[1] - dim(data_processed_clean)[1])

rm(data_processed_combined)

# apply any other criteria not in the python code
# ADD TO yaml
# save data