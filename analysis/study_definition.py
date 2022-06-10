
# IMPORT STATEMENTS ----

## Import code building blocks from cohort extractor package
from cohortextractor import (
  StudyDefinition,
  patients,
  codelist_from_csv,
  codelist,
  filter_codes_by_category,
  combine_codelists,
  Measure
)

## Import codelists from codelist.py (which pulls them from the codelist folder)
from codelists import *
  
  
# DEFINE STUDY POPULATION ----

## Define study time variables
from datetime import date

campaign_start = "2021-12-16"
end_date = date.today().isoformat()


## Define study population and variables
study = StudyDefinition(
  
  # PRELIMINARIES ----
  
  ## Configure the expectations framework
  default_expectations = {
    "date": {"earliest": "2021-11-01", "latest": "today"},
    "rate": "uniform",
    "incidence": 0.05,
  },
  
  ## Define index date
  index_date = campaign_start,
  
  # POPULATION ----
  population = patients.satisfying(
    """
    age >= 18 AND age < 110
    AND NOT has_died
    AND NOT imd = 0
    AND (
     registered_eligible
      AND
     (covid_test_positive AND NOT covid_positive_prev_90_days AND NOT any_covid_hosp_prev_90_days)
     )
    """,
    
  ),
  
  
  
  # TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
  
  ### Paxlovid
  paxlovid_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = "Paxlovid",
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2022-02-10"},
      "incidence": 0.05
    },
  ), 
  
  ## Sotrovimab
  sotrovimab_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = "Sotrovimab",
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.2
    },
  ),
  
  ## Remdesivir
  remdesivir_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = "Remdesivir",
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.2
    },
  ),
  
  ### Molnupiravir
  molnupiravir_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = "Molnupiravir",
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.2
    },
  ),
  
  ### Casirivimab and imdevimab
  casirivimab_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = "Casirivimab and imdevimab",
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.05
    },
  ), 
  
  
  ## Date treated
  date_treated = patients.minimum_of(
    "paxlovid_covid_therapeutics",
    "sotrovimab_covid_therapeutics",
    "remdesivir_covid_therapeutics",
    "molnupiravir_covid_therapeutics",
    "casirivimab_covid_therapeutics",
    
  ),
  
  
  # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
  
  ## Inclusion criteria variables
  
  ### First positive SARS-CoV-2 test
  # Note patients are eligible for treatment if diagnosed <=5d ago
  # in the latest 5 days there may be patients identified as eligible who have not yet been treated
  covid_test_positive = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    returning = "binary_flag",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    return_expectations = {
      "incidence": 0.2
    },
  ),
  
  covid_test_positive_date = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    find_first_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    returning = "date",
    date_format = "YYYY-MM-DD",
    on_or_after = "index_date",
    return_expectations = {
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.9
    },
  ),
  
  ### Second positive SARS-CoV-2 test
  covid_test_positive_date2 = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    find_first_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    returning = "date",
    date_format = "YYYY-MM-DD",
    on_or_after = "covid_test_positive_date + 30 days",
    return_expectations = {
      "date": {"earliest": "2021-12-20"},
      "incidence": 0.1
    },
  ),
  
  ### Positive covid test last 90 days 
  covid_positive_prev_90_days = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    returning = "binary_flag",
    between = ["covid_test_positive_date - 91 days", "covid_test_positive_date - 1 day"],
    find_last_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    return_expectations = {
      "incidence": 0.05
    },
  ),
  
  ### Onset of symptoms of COVID-19
  symptomatic_covid_test = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "any",
    returning = "symptomatic",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    return_expectations={
      "incidence": 0.1,
      "category": {
        "ratios": {
          "": 0.2,
          "N": 0.2,
          "Y": 0.6,
        }
      },
    },
  ),
  
  covid_symptoms_snomed = patients.with_these_clinical_events(
    covid_symptoms_snomed_codes,
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_first_match_in_period = True,
    on_or_after = "index_date",
  ),
  
  
  ## Study start date for extracting variables
  start_date = covid_test_positive_date
  
  ## Exclusion criteria variables
  
  ### Pattern of clinical presentation indicates that there is recovery rather than risk of deterioration from infection
  #   (not currently possible to define/code)
  
  ### Require hospitalisation for COVID-19
  ## NB this data lags behind the therapeutics/testing data so may be missing
  
  prim_covid_hosp_prev_90_days = patients.admitted_to_hospital(
    with_these_primary_diagnoses = covid_icd10_codes,
    with_patient_classification = ["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"], # emergency admissions only to exclude incidental COVID
    between = ["start_date - 91 days","start_date - 1 day"],
    returning = "binary_flag",
    return_expectations = {
      "incidence": 0.05
    },
  ),
  
  any_covid_hosp_prev_90_days = patients.admitted_to_hospital(
    with_these_diagnoses = covid_icd10_codes,
    with_patient_classification = ["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"], # emergency admissions only to exclude incidental COVID
    between = ["start_date - 91 days","start_date - 1 day"],
    returning = "binary_flag",
    return_expectations = {
      "incidence": 0.05
    },
  ),
  
  ### New supplemental oxygen requirement specifically for the management of COVID-19 symptoms
  #   (not currently possible to define/code)
  
  ### Known hypersensitivity reaction to the active substances or to any of the excipients of treatments
  #   (not currently possible to define/code)
  
  
  
  # TREATMENT SPECIFIC ELIGIBILITY CRITERIA VARIABLES ----
  
  ## Paxlovid - inclusion
  
  ### Clinical judgement deems that an antiviral is the preferred option
  #   (not currently possible to define/code)
  
  ### Treatment is commenced within 5 days of symptom onset
  #   (defined above)
  
  ### The patient does NOT have a history of advanced decompensated liver cirrhosis or stage 3-5 chronic kidney disease
  #   (use renal and liver high rosk cohorts defined below)
  
  ## Paxlovid - exclusion
  
  ### Children aged less than 18 years
  #   (defined below)
  
  ### Pregnancy
  
  # pregnancy record in last 36 weeks
  preg_36wks_date = patients.with_these_clinical_events(
    pregnancy_primis_codes,
    returning = "date",
    find_last_match_in_period = True,
    between = ["start_date - 252 days", "start_date - 1 day"],
    date_format = "YYYY-MM-DD",
  ),
  
  # pregnancy OR delivery code since latest pregnancy record:
  # if one of these codes occurs later than the latest pregnancy code
  #  this indicates pregnancy has ended, if they are same date assume 
  #  pregnancy has most likely not ended yet
  pregdel = patients.with_these_clinical_events(
    pregdel_primis_codes,
    returning = "binary_flag",
    find_last_match_in_period = True,
    between = ["preg_36wks_date + 1 day", "start_date - 1 day"],
    date_format = "YYYY-MM-DD",
  ),
  
  pregnancy = patients.satisfying(
    
    """
    gender = 'F' AND preg_age <= 50
    AND (preg_36wks_date AND NOT pregdel)
    """,
    
    gender = patients.sex(
      return_expectations = {
        "rate": "universal",
        "category": {"ratios": {"M": 0.49, "F": 0.51}},
      }
    ),
    
    preg_age = patients.age_as_of(
      "preg_36wks_date",
      return_expectations = {
        "rate": "universal",
        "int": {"distribution": "population_ages"},
        "incidence" : 0.9
      },
    ),
    
  ),
  
  ### The patient is taking any of the medications listed in Appendix 2
  #   (not currently possible to define/code)
  
  
  ## Sotrovimab - inclusion
  
  ### Clinical judgement deems that an antiviral is the preferred option
  #   (not currently possible to define/code)
  
  ### Treatment is commenced within 5 days of symptom onset
  #   (defined above)
  
  ## Sotrovimab - exclusion
  
  ### Children aged less than 12 years
  #   (defined below)
  
  ### Adolescents (aged 12-17) weighing 40kg and under
  # look in last 6 months only to get a relevant weight value
  weight = patients.with_these_clinical_events(
    weight_opensafely_snomed_codes,
    between = ["start_date - 182 days", "start_date"],
    find_last_match_in_period=True,
    date_format = "YYYY-MM-DD",
    returning = "numeric_value",
    return_expectations = {
      "incidence": 0.8,
      "float": {"distribution": "normal", "mean": 70.0, "stddev": 10.0},
    },
  ),
  
  ## Remdesivir - inclusion
  
  ### Clinical judgement deems that an antiviral is the preferred option
  #   (not currently possible to define/code)
  
  ### Treatment is commenced within 7 days of symptom onset
  #   (defined above)
  
  ## Remdesivir - exclusion
  
  ### Children aged less than 12 years
  #   (defined below)
  
  ### Adolescents (aged 12-17) weighing 40kg and under
  #   (defined above)
  
  
  ## Molnupiravir - inclusion
  
  ### Clinical judgement deems that an antiviral is the preferred option
  #   (not currently possible to define/code)
  
  ### Treatment is commenced within 5 days of symptom onset
  #   (defined above)
  
  ## Molnupiravir - exclusion
  
  ### Children aged less than 18 years
  #   (defined below)
  
  ### Pregnancy
  #   (defined above)
  
  
  
  
  # CENSORING ----
  
  ## Death of any cause
  death_date = patients.died_from_any_cause(
    returning = "date_of_death",
    date_format = "YYYY-MM-DD",
    on_or_after = "start_date",
    return_expectations = {
      "date": {"earliest": "2021-12-20"},
      "incidence": 0.1
    },
  ),
  
  has_died = patients.died_from_any_cause(
    on_or_before = "index_date - 1 day",
    returning = "binary_flag",
  ),
  
  ## De-registration
  dereg_date = patients.date_deregistered_from_all_supported_practices(
    on_or_after = "start_date",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2021-12-20"},
      "incidence": 0.1
    },
  ),
  
  registered_eligible = patients.registered_as_of("covid_test_positive_date"),
  registered_treated = patients.registered_as_of("date_treated"),
  
  
  
  # HIGH RISK GROUPS ----
  
  ## NHSD ‘high risk’ cohort (codelist to be defined if/when data avaliable)
  # high_risk_cohort_nhsd = patients.with_these_clinical_events(
  #   high_risk_cohort_nhsd_codes,
  #   between = [campaign_start, index_date],
  #   returning = "date",
  #   date_format = "YYYY-MM-DD",
  #   find_first_match_in_period = True,
  # ),
  
  ## Blueteq ‘high risk’ cohort
  high_risk_cohort_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    with_these_therapeutics = ["Sotrovimab", "Molnupiravir","Casirivimab and imdevimab", "Paxlovid", "Remdesivir"],
    with_these_indications = "non_hospitalised",
    on_or_after = "index_date",
    find_first_match_in_period = True,
    returning = "risk_group",
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "rate": "universal",
      "incidence": 0.4,
      "category": {
        "ratios": {
          "Downs syndrome": 0.1,
          "sickle cell disease": 0.1,
          "solid cancer": 0.1,
          "haematological diseases,stem cell transplant recipients": 0.1,
          "renal disease,sickle cell disease": 0.1,
          "liver disease": 0.05,
          "IMID": 0.1,
          "IMID,solid cancer": 0.1,
          "haematological malignancies": 0.05,
          "primary immune deficiencies": 0.1,
          "HIV or AIDS": 0.05,
          "NA":0.05,},},
    },
  ),
  
  ## Down's syndrome
  downs_syndrome_nhsd_snomed = patients.with_these_clinical_events(
    downs_syndrome_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  downs_syndrome_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = downs_syndrome_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  downs_syndrome_nhsd = patients.minimum_of("downs_syndrome_nhsd_snomed", "downs_syndrome_nhsd_icd10"), 
  
  ## Solid cancer
  cancer_opensafely_snomed = patients.with_these_clinical_events(
    combine_codelists(
      non_haematological_cancer_opensafely_snomed_codes,
      lung_cancer_opensafely_snomed_codes,
      chemotherapy_radiotherapy_opensafely_snomed_codes
    ),
    between = ["start_date - 6 months", "start_date"],
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  ## Haematological diseases
  haematopoietic_stem_cell_transplant_nhsd_snomed = patients.with_these_clinical_events(
    haematopoietic_stem_cell_transplant_nhsd_snomed_codes,
    between = ["start_date - 12 months", "start_date"],
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  haematopoietic_stem_cell_transplant_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    between = ["start_date - 12 months", "start_date"],
    with_these_diagnoses = haematopoietic_stem_cell_transplant_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  haematopoietic_stem_cell_transplant_nhsd_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    between = ["start_date - 12 months", "start_date"],
    with_these_procedures = haematopoietic_stem_cell_transplant_nhsd_opcs4_codes,
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  haematological_malignancies_nhsd_snomed = patients.with_these_clinical_events(
    haematological_malignancies_nhsd_snomed_codes,
    between = ["start_date - 24 months", "start_date"],
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  haematological_malignancies_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    between = ["start_date - 24 months", "start_date"],
    with_these_diagnoses = haematological_malignancies_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  sickle_cell_disease_nhsd_snomed = patients.with_these_clinical_events(
    sickle_cell_disease_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  sickle_cell_disease_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = sickle_cell_disease_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  haematological_disease_nhsd = patients.minimum_of("haematopoietic_stem_cell_transplant_nhsd_snomed", 
                                                    "haematopoietic_stem_cell_transplant_nhsd_icd10", 
                                                    "haematopoietic_stem_cell_transplant_nhsd_opcs4", 
                                                    "haematological_malignancies_nhsd_snomed", 
                                                    "haematological_malignancies_nhsd_icd10",
                                                    "sickle_cell_disease_nhsd_snomed", 
                                                    "sickle_cell_disease_nhsd_icd10"), 
  
  
  ## Renal disease
  ckd_stage_5_nhsd_snomed = patients.with_these_clinical_events(
    ckd_stage_5_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  ckd_stage_5_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = ckd_stage_5_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  ckd_stage_5_nhsd = patients.minimum_of("ckd_stage_5_nhsd_snomed", "ckd_stage_5_nhsd_icd10"), 
  
  ## Liver disease
  liver_disease_nhsd_snomed = patients.with_these_clinical_events(
    liver_disease_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  liver_disease_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = liver_disease_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  liver_disease_nhsd = patients.minimum_of("liver_disease_nhsd_snomed", "liver_disease_nhsd_icd10"), 
  
  ## Immune-mediated inflammatory disorders (IMID)
  immunosuppresant_drugs_nhsd = patients.with_these_medications(
    codelist = combine_codelists(immunosuppresant_drugs_dmd_codes, immunosuppresant_drugs_snomed_codes),
    returning = "date",
    between = ["start_date - 6 months", "start_date"],
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  oral_steroid_drugs_nhsd = patients.with_these_medications(
    codelist = combine_codelists(oral_steroid_drugs_dmd_codes, oral_steroid_drugs_snomed_codes),
    returning = "date",
    between = ["start_date - 12 months", "start_date"],
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  oral_steroid_drug_nhsd_3m_count = patients.with_these_medications(
    codelist = combine_codelists(oral_steroid_drugs_dmd_codes, oral_steroid_drugs_snomed_codes),
    returning = "number_of_matches_in_period",
    between = ["start_date - 3 months", "start_date"],
    return_expectations = {"incidence": 0.1,
      "int": {"distribution": "normal", "mean": 2, "stddev": 1},
    },
  ),
  
  oral_steroid_drug_nhsd_12m_count = patients.with_these_medications(
    codelist = combine_codelists(oral_steroid_drugs_dmd_codes, oral_steroid_drugs_snomed_codes),
    returning = "number_of_matches_in_period",
    between = ["start_date - 12 months", "start_date"],
    return_expectations = {"incidence": 0.1,
      "int": {"distribution": "normal", "mean": 3, "stddev": 1},
    },
  ),
  
  # imid_nhsd = patients.minimum_of("immunosuppresant_drugs_nhsd", "oral_steroid_drugs_nhsd"), - define in processing script
  
  
  ## Primary immune deficiencies
  immunosupression_nhsd = patients.with_these_clinical_events(
    immunosupression_nhsd_codes,
    on_or_before = "start_date",
    returning = "date",
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  ## HIV/AIDs
  hiv_aids_nhsd_snomed = patients.with_these_clinical_events(
    hiv_aids_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  hiv_aids_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = hiv_aids_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  hiv_aids_nhsd = patients.minimum_of("hiv_aids_nhsd_snomed", "hiv_aids_nhsd_icd10"),
  
  ## Solid organ transplant
  solid_organ_transplant_nhsd_snomed = patients.with_these_clinical_events(
    solid_organ_transplant_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  solid_organ_transplant_nhsd_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_procedures = solid_organ_transplant_nhsd_opcs4_codes,
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_all_y_codes_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = replacement_of_organ_transplant_nhsd_opcs4_codes,
    on_or_before = "start_date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_thymus_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = thymus_gland_transplant_nhsd_opcs4_codes,
    between = ["transplant_all_y_codes_opcs4","transplant_all_y_codes_opcs4"],
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_conjunctiva_y_code_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = conjunctiva_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before = "start_date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_conjunctiva_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = conjunctiva_transplant_nhsd_opcs4_codes,
    between = ["transplant_conjunctiva_y_code_opcs4","transplant_conjunctiva_y_code_opcs4"],
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_stomach_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = stomach_transplant_nhsd_opcs4_codes,
    between = ["transplant_all_y_codes_opcs4","transplant_all_y_codes_opcs4"],
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_ileum_1_Y_codes_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = ileum_1_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before = "start_date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_ileum_2_Y_codes_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = ileum_2_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before = "start_date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_ileum_1_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = ileum_1_transplant_nhsd_opcs4_codes,
    between = ["transplant_ileum_1_Y_codes_opcs4","transplant_ileum_1_Y_codes_opcs4"],
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  transplant_ileum_2_opcs4 = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_procedures = ileum_2_transplant_nhsd_opcs4_codes,
    between = ["transplant_ileum_2_Y_codes_opcs4","transplant_ileum_2_Y_codes_opcs4"],
    date_format = "YYYY-MM-DD",
    find_first_match_in_period = True,
    return_expectations = {
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  
  solid_organ_transplant_nhsd = patients.minimum_of("solid_organ_transplant_nhsd_snomed", "solid_organ_transplant_nhsd_opcs4",
                                                    "transplant_thymus_opcs4", "transplant_conjunctiva_opcs4", "transplant_stomach_opcs4",
                                                    "transplant_ileum_1_opcs4","transplant_ileum_2_opcs4"), 
  
  ## Rare neurological conditions
  
  ### Multiple sclerosis
  multiple_sclerosis_nhsd_snomed = patients.with_these_clinical_events(
    multiple_sclerosis_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  multiple_sclerosis_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = multiple_sclerosis_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  multiple_sclerosis_nhsd = patients.minimum_of("multiple_sclerosis_nhsd_snomed", "multiple_sclerosis_nhsd_icd10"), 
  
  ### Motor neurone disease
  motor_neurone_disease_nhsd_snomed = patients.with_these_clinical_events(
    motor_neurone_disease_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  motor_neurone_disease_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = motor_neurone_disease_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  motor_neurone_disease_nhsd = patients.minimum_of("motor_neurone_disease_nhsd_snomed", "motor_neurone_disease_nhsd_icd10"),
  
  ### Myasthenia gravis
  myasthenia_gravis_nhsd_snomed = patients.with_these_clinical_events(
    myasthenia_gravis_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  myasthenia_gravis_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = myasthenia_gravis_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  myasthenia_gravis_nhsd = patients.minimum_of("myasthenia_gravis_nhsd_snomed", "myasthenia_gravis_nhsd_icd10"),
  
  ### Huntington’s disease
  huntingtons_disease_nhsd_snomed = patients.with_these_clinical_events(
    huntingtons_disease_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "date",
    date_format = "YYYY-MM-DD",
    find_last_match_in_period = True,
  ),
  
  huntingtons_disease_nhsd_icd10 = patients.admitted_to_hospital(
    returning = "date_admitted",
    on_or_before = "start_date",
    with_these_diagnoses = huntingtons_disease_nhsd_icd10_codes,
    find_last_match_in_period = True,
    date_format = "YYYY-MM-DD",
  ),
  
  huntingtons_disease_nhsd = patients.minimum_of("huntingtons_disease_nhsd_snomed", "huntingtons_disease_nhsd_icd10"),
  
  
  
  # CLINICAL/DEMOGRAPHIC COVARIATES ----
  
  ## Age
  age = patients.age_as_of(
    "start_date - 1 days",
    return_expectations = {
      "rate": "universal",
      "int": {"distribution": "population_ages"},
      "incidence" : 0.9
    },
  ),
  
  ## Sex
  sex = patients.sex(
    return_expectations = {
      "rate": "universal",
      "category": {"ratios": {"M": 0.49, "F": 0.51}},
    }
  ),
  
  ## Ethnicity
  ethnicity_primis = patients.with_these_clinical_events(
    ethnicity_primis_snomed_codes,
    returning = "category",
    on_or_before = "start_date",
    find_first_match_in_period = True,
    include_date_of_match = False,
    return_expectations = {
      "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
      "incidence": 0.75,
    },
  ),
  
  ethnicity_sus = patients.with_ethnicity_from_sus(
    returning = "group_6",  
    use_most_frequent_code = True,
    return_expectations = {
      "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
      "incidence": 0.8,
    },
  ),
  
  ## Index of multiple deprivation
  imd = patients.categorised_as(
    {"0": "DEFAULT",
      "1": """index_of_multiple_deprivation >=1 AND index_of_multiple_deprivation < 32844*1/5""",
      "2": """index_of_multiple_deprivation >= 32844*1/5 AND index_of_multiple_deprivation < 32844*2/5""",
      "3": """index_of_multiple_deprivation >= 32844*2/5 AND index_of_multiple_deprivation < 32844*3/5""",
      "4": """index_of_multiple_deprivation >= 32844*3/5 AND index_of_multiple_deprivation < 32844*4/5""",
      "5": """index_of_multiple_deprivation >= 32844*4/5 """,
    },
    index_of_multiple_deprivation = patients.address_as_of(
      "start_date",
      returning = "index_of_multiple_deprivation",
      round_to_nearest = 100,
    ),
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "0": 0.01,
          "1": 0.20,
          "2": 0.20,
          "3": 0.20,
          "4": 0.20,
          "5": 0.19,
        }},
    },
  ),
  
  ## Region - NHS England 9 regions
  region_nhs = patients.registered_practice_as_of(
    "start_date",
    returning = "nuts1_region_name",
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "North East": 0.1,
          "North West": 0.1,
          "Yorkshire and The Humber": 0.1,
          "East Midlands": 0.1,
          "West Midlands": 0.1,
          "East": 0.1,
          "London": 0.2,
          "South West": 0.1,
          "South East": 0.1,},},
    },
  ),
  
  region_covid_therapeutics = patients.with_covid_therapeutics(
    #with_these_statuses = ["Approved", "Treatment Complete"],
    #with_these_therapeutics = ["Sotrovimab", "Molnupiravir", "Casirivimab and imdevimab"],
    with_these_indications = "non_hospitalised",
    on_or_after = "start_date",
    find_first_match_in_period = True,
    returning = "region",
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "North East": 0.1,
          "North West": 0.1,
          "Yorkshire and The Humber": 0.1,
          "East Midlands": 0.1,
          "West Midlands": 0.1,
          "East": 0.1,
          "London": 0.2,
          "South West": 0.1,
          "South East": 0.1,},},
    },
  ),
  
  # STP (NHS administration region based on geography, currenty closest match to CMDU)
  stp = patients.registered_practice_as_of(
    "start_date",
    returning = "stp_code",
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "STP1": 0.1,
          "STP2": 0.1,
          "STP3": 0.1,
          "STP4": 0.1,
          "STP5": 0.1,
          "STP6": 0.1,
          "STP7": 0.1,
          "STP8": 0.1,
          "STP9": 0.1,
          "STP10": 0.1,
        }
      },
    },
  ),
  
  # Rurality
  rural_urban = patients.address_as_of(
    "start_date",
    returning = "rural_urban_classification",
    return_expectations = {
      "rate": "universal",
      "category": {"ratios": {1: 0.125, 2: 0.125, 3: 0.125, 4: 0.125, 5: 0.125, 6: 0.125, 7: 0.125, 8: 0.125}},
      "incidence": 1,
    },
  ),
  
  
  
  # CLINICAL GROUPS ----
  
  ## Autism
  autism_nhsd = patients.with_these_clinical_events(
    autism_nhsd_snomed_codes,
    on_or_before = "start_date",
    returning = "binary_flag",
    return_expectations = {"incidence": 0.3}
  ),
  
  ## Care home 
  care_home_primis = patients.with_these_clinical_events(
    care_home_primis_snomed_codes,
    returning = "binary_flag",
    on_or_before = "start_date",
    return_expectations = {"incidence": 0.15,}
  ),
  
  ## Dementia
  dementia_nhsd = patients.satisfying(
    
    """
    dementia_all
    AND
    age > 39
    """, 
    
    return_expectations = {
      "incidence": 0.01,
    },
    
    dementia_all = patients.with_these_clinical_events(
      dementia_nhsd_snomed_codes,
      on_or_before = "start_date",
      returning = "binary_flag",
      return_expectations = {"incidence": 0.05}
    ),
    
  ),
  
  
  ## Housebound
  housebound_opensafely = patients.satisfying(
    """housebound_date
                AND NOT no_longer_housebound
                AND NOT moved_into_care_home""",
    return_expectations={
      "incidence": 0.01,
    },
    
    housebound_date = patients.with_these_clinical_events( 
      housebound_opensafely_snomed_codes, 
      on_or_before = "start_date",
      find_last_match_in_period = True,
      returning = "date",
      date_format = "YYYY-MM-DD",
    ),   
    
    no_longer_housebound = patients.with_these_clinical_events( 
      no_longer_housebound_opensafely_snomed_codes, 
      on_or_after = "housebound_date",
    ),
    
    moved_into_care_home = patients.with_these_clinical_events(
      care_home_primis_snomed_codes,
      on_or_after = "housebound_date",
    ),
    
  ),
  
  ## Learning disability
  learning_disability_primis = patients.with_these_clinical_events(
    wider_ld_primis_snomed_codes,
    on_or_before = "start_date",
    returning = "binary_flag",
    return_expectations = {"incidence": 0.2}
  ),
  
  ## Shielded
  shielded_primis = patients.satisfying(
    """ 
    severely_clinically_vulnerable
    AND 
    NOT less_vulnerable 
    """, 
    return_expectations = {
      "incidence": 0.01,
    },
    
    ### SHIELDED GROUP - first flag all patients with "high risk" codes
    severely_clinically_vulnerable = patients.with_these_clinical_events(
      high_risk_primis_snomed_codes, # note no date limits set
      find_last_match_in_period = True,
      return_expectations = {"incidence": 0.02,},
    ),
    
    # find date at which the high risk code was added
    date_severely_clinically_vulnerable = patients.date_of(
      "severely_clinically_vulnerable", 
      date_format  ="YYYY-MM-DD",   
    ),
    
    ### NOT SHIELDED GROUP (medium and low risk) - only flag if later than 'shielded'
    less_vulnerable = patients.with_these_clinical_events(
      not_high_risk_primis_snomed_codes, 
      on_or_after = "date_severely_clinically_vulnerable",
      return_expectations = {"incidence": 0.01,},
    ),
  ),
  
  # flag the newly expanded shielding group as of 15 feb (should be a subset of the previous flag)
  shielded_since_feb_15 = patients.satisfying(
    """severely_clinically_vulnerable_since_feb_15
                AND NOT new_shielding_status_reduced
                AND NOT previous_flag
            """,
    return_expectations={
      "incidence": 0.01,
    },
    
    ### SHIELDED GROUP - first flag all patients with "high risk" codes
    severely_clinically_vulnerable_since_feb_15 = patients.with_these_clinical_events(
      high_risk_primis_snomed_codes, 
      on_or_after = "2021-02-15",
      find_last_match_in_period = False,
      return_expectations = {"incidence": 0.02,},
    ),
    
    # find date at which the high risk code was added
    date_vulnerable_since_feb_15 = patients.date_of(
      "severely_clinically_vulnerable_since_feb_15", 
      date_format = "YYYY-MM-DD",   
    ),
    
    ### check that patient's shielding status has not since been reduced to a lower risk level 
    # e.g. due to improved clinical condition of patient
    new_shielding_status_reduced = patients.with_these_clinical_events(
      not_high_risk_primis_snomed_codes,
      on_or_after = "date_vulnerable_since_feb_15",
      return_expectations = {"incidence": 0.01,},
    ),
    
    # anyone with a previous flag of any risk level will not be added to the new shielding group
    previous_flag = patients.with_these_clinical_events(
      combine_codelists(high_risk_primis_snomed_codes, not_high_risk_primis_snomed_codes),
      on_or_before = "2021-02-14",
      return_expectations = {"incidence": 0.01,},
    ),
  ),
  
  ### Serious Mental Illness
  serious_mental_illness_nhsd = patients.with_these_clinical_events(
    serious_mental_illness_nhsd_snomed_codes,
    on_or_before = "index_date",
    returning = "binary_flag",
    return_expectations = {"incidence": 0.1}
  ),
  
  ## Sickle cell disease
  sickle_cell_disease_nhsd = patients.minimum_of("sickle_cell_disease_nhsd_snomed", "sickle_cell_disease_nhsd_icd10"), 
  
  ## Vaccination status
  vaccination_status = patients.categorised_as(
    {
      "Un-vaccinated": "DEFAULT",
      "Un-vaccinated (declined)": """ covid_vax_declined AND NOT (covid_vax_1 OR covid_vax_2 OR covid_vax_3)""",
      "One vaccination": """ covid_vax_1 AND NOT covid_vax_2 """,
      "Two vaccinations": """ covid_vax_2 AND NOT covid_vax_3 """,
      "Three or more vaccinations": """ covid_vax_3 """
    },
    
    # first vaccine from during trials and up to treatment/test date
    covid_vax_1 = patients.with_tpp_vaccination_record(
      target_disease_matches = "SARS-2 CORONAVIRUS",
      between = ["2020-06-08", "start_date"],
      find_first_match_in_period = True,
      returning = "date",
      date_format = "YYYY-MM-DD"
    ),
    
    covid_vax_2 = patients.with_tpp_vaccination_record(
      target_disease_matches = "SARS-2 CORONAVIRUS",
      between = ["covid_vax_1 + 19 days", "start_date"],
      find_first_match_in_period = True,
      returning = "date",
      date_format = "YYYY-MM-DD"
    ),
    
    covid_vax_3 = patients.with_tpp_vaccination_record(
      target_disease_matches = "SARS-2 CORONAVIRUS",
      between = ["covid_vax_2 + 56 days", "start_date"],
      find_first_match_in_period = True,
      returning = "date",
      date_format = "YYYY-MM-DD"
    ),
    
    covid_vax_declined = patients.with_these_clinical_events(
      covid_vaccine_declined_codes,
      returning="binary_flag",
      on_or_before = "start_date",
    ),
    
    return_expectations = {
      "rate": "universal",
      "category": {
        "ratios": {
          "Un-vaccinated": 0.1,
          "Un-vaccinated (declined)": 0.1,
          "One vaccination": 0.1,
          "Two vaccinations": 0.2,
          "Three or more vaccinations": 0.5,
        }
      },
    },
  ),
  
  
  
  # CLINICAL CO-MORBIDITIES TBC ----
  
  # COVID VARIENT
  
  ## S-Gene Target Failure
  sgtf = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    find_first_match_in_period = True,
    between = ["covid_test_positive_date", "covid_test_positive_date"],
    returning = "s_gene_target_failure",
    return_expectations = {
      "rate": "universal",
      "category": {"ratios": {"0": 0.7, "1": 0.1, "9": 0.1, "": 0.1}},
    },
  ), 
  
  ## Variant
  variant = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    find_first_match_in_period = True,
    between = ["covid_test_positive_date", "covid_test_positive_date"],
    restrict_to_earliest_specimen_date = False,
    returning = "variant",
    return_expectations = {
      "rate": "universal",
      "category": {"ratios": {"B.1.617.2": 0.7, "B.1.1.7+E484K": 0.1, "No VOC detected": 0.1, "Undetermined": 0.1}},
    },
  ), 
  
  
  
  # OUTCOMES ----
  
  ## COVID re-infection
  covid_positive_test_30_days_post_elig_or_treat = patients.with_test_result_in_sgss(
    pathogen = "SARS-CoV-2",
    test_result = "positive",
    returning = "date",
    date_format = "YYYY-MM-DD",
    between = ["start_date + 30 days", "start_date + 90 days"],
    find_first_match_in_period = True,
    restrict_to_earliest_specimen_date = False,
    return_expectations = {
      "date": {"earliest": "2021-12-01"},
      "rate": "exponential_increase",
      "incidence": 0.4
    },
  ),
  
  ## COVID-related hospitalisation 
  covid_hospitalisation_outcome_date = patients.admitted_to_hospital(
    returning = "date_admitted",
    with_these_primary_diagnoses = covid_icd10_codes,
    with_patient_classification = ["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"], # emergency admissions only to exclude incidental COVID
    between = ["start_date + 1 day", "start_date + 90 days"],
    find_first_match_in_period = True,
    date_format = "YYYY-MM-DD",
    return_expectations = {
      "date": {"earliest": "2022-02-28"},
      "rate": "uniform",
      "incidence": 0.05
    },
  ),
  
  ## Critical care days for COVID-related hospitalisation 
  covid_hospitalisation_critical_care = patients.admitted_to_hospital(
    returning = "days_in_critical_care",
    with_these_diagnoses = covid_icd10_codes,
    between = ["covid_hospitalisation_outcome_date","covid_hospitalisation_outcome_date + 90 days"],
    find_first_match_in_period = True,
    return_expectations = {
      "category": {"ratios": {"20": 0.5, "40": 0.5}},
      "incidence": 0.2,
    },
  ),
  
  ## COVID related death
  death_with_covid_on_the_death_certificate_date = patients.with_these_codes_on_death_certificate(
    covid_icd10_codes,
    returning = "date_of_death",
    date_format = "YYYY-MM-DD",
    between = ["start_date + 1 day", "start_date + 90 days"], 
    return_expectations = {
      "date": {"earliest": "2021-01-01", "latest" : end_date},
      "rate": "uniform",
      "incidence": 0.3},
  ),
  
  death_with_28_days_of_covid_positive_test = patients.satisfying(
    
    """
    death_date
    AND 
    positive_covid_test_prior_28_days
    """, 
    
    return_expectations = {
      "incidence": 0.2,
    },
    
    positive_covid_test_prior_28_days = patients.with_test_result_in_sgss(
      pathogen = "SARS-CoV-2",
      test_result = "positive",
      returning = "binary_flag",
      date_format = "YYYY-MM-DD",
      between = ["death_date - 28 days", "death_date"],
      find_first_match_in_period = True,
      restrict_to_earliest_specimen_date = False,
      return_expectations = {
        "date": {"earliest": "2020-02-01"},
        "rate": "exponential_increase",
        "incidence": 0.1
      },
    ),
  ),
  
  
)