extract_data <- function(input_filename){
  data_extract <- read_csv(
    here::here("output", input_filename),
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
      
      # SYMPTOMS ----
      symptomatic_covid_test = col_character(),
      covid_symptoms_snomed = col_date(format = "%Y-%m-%d"),
      
      # HIGH RISK GROUPS ----
      high_risk_cohort_covid_therapeutics = col_factor(),
      downs_syndrome_nhsd  = col_logical(),
      cancer_opensafely_snomed = col_logical(), 
      cancer_opensafely_snomed_new = col_logical(), # non-overlapping
      haematological_disease_nhsd = col_logical(),
      ckd_stage_5_nhsd = col_logical(), 
      liver_disease_nhsd = col_logical(), 
      imid_nhsd = col_logical(), 
      immunosupression_nhsd = col_logical(),
      immunosupression_nhsd_new = col_logical(), # non-overlapping
      hiv_aids_nhsd = col_logical(),
      solid_organ_transplant_nhsd = col_logical(), 
      solid_organ_transplant_nhsd_new = col_logical(), # non-overlapping
      multiple_sclerosis_nhsd = col_logical(), 
      motor_neurone_disease_nhsd = col_logical(),
      myasthenia_gravis_nhsd = col_logical(),
      huntingtons_disease_nhsd = col_logical(), 

      # CLINICAL/DEMOGRAPHIC COVARIATES ----
      diabetes = col_logical(),
      chronic_cardiac_disease = col_logical(),
      bmi = col_character(),
      smoking_status = col_character(),
      copd = col_logical(),
      dialysis = col_logical(),
      cancer = col_logical(),
      lung_cancer = col_logical(),
      haem_cancer = col_logical(),
      autism_nhsd = col_logical(),
      care_home_primis = col_logical(),
      dementia_nhsd = col_logical(),
      housebound_opensafely = col_logical(),
      serious_mental_illness_nhsd = col_logical(),
      learning_disability_primis = col_logical(),
      
      # VACCINATION ----
      vaccination_status = col_factor(),
      date_most_recent_cov_vac = col_date(format = "%Y-%m-%d"),
      pfizer_most_recent_cov_vac = col_logical(),
      az_most_recent_cov_vac = col_logical(),
      moderna_most_recent_cov_vac = col_logical(),
      
      # VARIANT ----
      sgtf = col_factor(),
      variant = col_factor(),
      
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
      death_date = col_date(format = "%Y-%m-%d"),
      died_ons_covid_any_date = col_date(format = "%Y-%m-%d"),
      # dereg
      dereg_date = col_date(format = "%Y-%m-%d"),
      
      # DIAGNOSIS ----
      # all cause diagnosis of hosp admission
      allcause_hosp_admission_diagnosis0 = col_character(),
      allcause_hosp_admission_diagnosis1 = col_character(),
      allcause_hosp_admission_diagnosis2 = col_character(),
      allcause_hosp_admission_diagnosis4 = col_character(),
      allcause_hosp_admission_diagnosis3 = col_character(),
      allcause_hosp_admission_diagnosis5 = col_character(),
      allcause_hosp_admission_diagnosis6 = col_character(),
      allcause_hosp_admission_first_diagnosis7_27 = col_character(),
      # death cause
      death_cause = col_factor()
    ),
  )
}
