# Import code building blocks from cohort extractor package
from cohortextractor import (
  StudyDefinition,
  patients,
  combine_codelists,
)
# Import codelists from codelist.py (which pulls them from the codelist
# folder)
from codelists import *
# Define study time variables by importing study-dates
# Import json module
import json
with open('lib/design/study-dates-ba2.json', 'r') as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

# Define study population and variables
study = StudyDefinition(
  # Configure the expectations framework
  default_expectations={
    "date": {"earliest": start_date, "latest": end_date},
    "rate": "uniform",
    "incidence": 0.05,
  }, 
  # Define index date
  index_date=start_date,
  # POPULATION ----
  population=patients.satisfying(
    """
    age >= 18 AND age < 110
    AND (NOT has_died)
    AND (sex = "M" OR sex = "F")
    AND (NOT stp = "")
    AND imd != -1
    AND high_risk_group
    AND registered_eligible
    AND covid_test_positive
    """,
  ),
  # Date of positive test (to be used for elig crit)
  covid_test_positive_date=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="positive",
    find_first_match_in_period=True,
    restrict_to_earliest_specimen_date=False,
    returning="date",
    date_format="YYYY-MM-DD",
    between=["index_date", end_date],
    return_expectations={
      "incidence": 1.0,
      "date": {"earliest": "index_date", "latest": "index_date"},
    },
  ),
  # Age
  age=patients.age_as_of(
    "covid_test_positive_date",
    return_expectations={
      "rate": "universal",
      "int": {"distribution": "population_ages"},
      "incidence": 0.9
    },
  ),
  # Was patient alive?
  has_died=patients.died_from_any_cause(
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
  ),
  # Sex
  sex=patients.sex(
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {"M": 0.49, "F": 0.51}},
    }
  ),
  # STP (NHS administration region based on geography, currenty closest match to CMDU)
  stp=patients.registered_practice_as_of(
    "covid_test_positive_date",
    returning="stp_code",
    return_expectations={
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
  # https://docs.opensafely.org/study-def-tricks/#grouping-imd-by-quintile
  imd=patients.address_as_of(
    "covid_test_positive_date",
    returning="index_of_multiple_deprivation",
    round_to_nearest=100,
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "0": 0,
          "1": 0.20,
          "2": 0.20,
          "3": 0.20,
          "4": 0.20,
          "5": 0.20,
        }
      },
    },
  ),
  # Positive test yes/no
  covid_test_positive=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="positive",
    returning="binary_flag",
    between=["index_date", end_date],
    find_first_match_in_period=True,
    restrict_to_earliest_specimen_date=False,
    return_expectations={
      "incidence": 1.0
    },
  ),
  # Was patients registered at the time of a positive test?
  registered_eligible=patients.registered_as_of("covid_test_positive_date"),
  # Previous treatment
  # Paxlovid
  paxlovid_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Paxlovid",
    with_these_indications="non_hospitalised",
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.01
    },
  ),
  # Sotrovimab
  sotrovimab_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Sotrovimab",
    with_these_indications="non_hospitalised",
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.01
    },
  ),
  # Remdesivir
  remdesivir_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Remdesivir",
    with_these_indications="non_hospitalised",
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.01
    },
  ),
  # Molnupiravir
  molnupiravir_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Molnupiravir",
    with_these_indications="non_hospitalised",
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
    date_format="YYYY-MM-DD",
    return_expectations={
      "incidence": 0.01
    },
  ),
  # Casirivimab and imdevimab
  casirivimab_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Casirivimab and imdevimab",
    with_these_indications="non_hospitalised",
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.01
    },
  ),
  # previously treated
  prev_treated=patients.satisfying(
    """
    paxlovid_covid_prev OR
    sotrovimab_covid_prev OR
    remdesivir_covid_prev OR
    molnupiravir_covid_prev OR
    casirivimab_covid_prev
    """,
    return_expectations={
      "incidence": 0.01,
    },
  ),
  # Positive covid test last 90 days
  covid_positive_prev_90_days=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="positive",
    returning="binary_flag",
    between=["covid_test_positive_date - 91 days", "covid_test_positive_date - 1 day"],
    find_last_match_in_period=True,
    restrict_to_earliest_specimen_date=False,
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Prior covid hospitalisation last 90 days
  any_covid_hosp_prev_90_days=patients.admitted_to_hospital(
    with_these_diagnoses=covid_icd10_codes,
    with_patient_classification=["1"],  # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],  # emergency admissions only to exclude incidental COVID
    between=["covid_test_positive_date - 91 days", "covid_test_positive_date - 1 day"],
    returning="binary_flag",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Admitted to hospital when tested positive
  in_hospital_when_tested=patients.satisfying(
   "discharged_date > covid_test_positive_date",
   discharged_date=patients.admitted_to_hospital(
      returning="date_discharged",
      on_or_before="covid_test_positive_date",
      with_patient_classification=["1"],  # ordinary admissions only - exclude day cases and regular attenders
      # see https://github.com/opensafely-core/cohort-extractor/pull/497 for codes
      # see https://docs.opensafely.org/study-def-variables/#sus for more info
      with_admission_method=["21", "22", "23", "24", "25", "2A", "2B", "2C", "2D", "28"],  # emergency admissions only to exclude incidental COVID
      find_last_match_in_period=True,
   ),
   return_expectations={"incidence": 0.05}
  ),
  # High risk groups
  # Blueteq ‘high risk’ cohort
  high_risk_cohort_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics=["Sotrovimab", "Molnupiravir","Casirivimab and imdevimab", "Paxlovid", "Remdesivir"],
    with_these_indications="non_hospitalised",
    on_or_after="covid_test_positive_date",
    find_first_match_in_period=True,
    returning="risk_group",
    date_format="YYYY-MM-DD",
    return_expectations={
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
          "NA": 0.05,
        },
      },
    },
  ),
  # Definition of high risk using regular codelists
  # Down's syndrome
  downs_syndrome_nhsd_snomed=patients.with_these_clinical_events(
    downs_syndrome_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.05
    },
  ),
  downs_syndrome_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=downs_syndrome_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.05
    },
  ),
  downs_syndrome_nhsd=patients.satisfying(
    "downs_syndrome_nhsd_snomed OR downs_syndrome_nhsd_icd10",
    return_expectations={
      "incidence": 0.05,
    },
  ),
  # Solid cancer
  cancer_opensafely_snomed=patients.with_these_clinical_events(
    combine_codelists(
      non_haematological_cancer_opensafely_snomed_codes,
      lung_cancer_opensafely_snomed_codes,
      chemotherapy_radiotherapy_opensafely_snomed_codes
    ),
    between=["covid_test_positive_date - 6 months", "covid_test_positive_date"],
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  cancer_opensafely_snomed_new=patients.with_these_clinical_events(
    combine_codelists(
      non_haem_cancer_new_codes,
      lung_cancer_opensafely_snomed_codes,
      chemotherapy_radiotherapy_opensafely_snomed_codes
    ),
    between=["covid_test_positive_date - 6 months", "covid_test_positive_date"],
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  # Haematological diseases
  haematopoietic_stem_cell_transplant_nhsd_snomed=patients.with_these_clinical_events(
    haematopoietic_stem_cell_transplant_nhsd_snomed_codes,
    between=["covid_test_positive_date - 12 months", "covid_test_positive_date"],
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  haematopoietic_stem_cell_transplant_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    between=["covid_test_positive_date - 12 months", "covid_test_positive_date"],
    with_these_diagnoses=haematopoietic_stem_cell_transplant_nhsd_icd10_codes,
    find_last_match_in_period=True,
    return_expectations={
      "incidence": 0.4
    },
  ),
  haematopoietic_stem_cell_transplant_nhsd_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    between=["covid_test_positive_date - 12 months", "covid_test_positive_date"],
    with_these_procedures=haematopoietic_stem_cell_transplant_nhsd_opcs4_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  haematological_malignancies_nhsd_snomed=patients.with_these_clinical_events(
    haematological_malignancies_nhsd_snomed_codes,
    between=["covid_test_positive_date - 24 months", "covid_test_positive_date"],
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  haematological_malignancies_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    between=["covid_test_positive_date - 24 months", "covid_test_positive_date"],
    with_these_diagnoses=haematological_malignancies_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  sickle_cell_disease_nhsd_snomed=patients.with_these_clinical_events(
    sickle_cell_disease_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  sickle_cell_disease_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=sickle_cell_disease_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  haematological_disease_nhsd=patients.satisfying(
    """
    haematopoietic_stem_cell_transplant_nhsd_snomed OR
    haematopoietic_stem_cell_transplant_nhsd_icd10 OR
    haematopoietic_stem_cell_transplant_nhsd_opcs4 OR
    haematological_malignancies_nhsd_snomed OR
    haematological_malignancies_nhsd_icd10 OR
    sickle_cell_disease_nhsd_snomed OR
    sickle_cell_disease_nhsd_icd10
    """,
    return_expectations={
      "incidence": 0.05,
    },
  ),
  # Renal disease
  ckd_stage_5_nhsd_snomed=patients.with_these_clinical_events(
    ckd_stage_5_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  ckd_stage_5_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=ckd_stage_5_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  ckd_stage_5_nhsd=patients.satisfying(
    "ckd_stage_5_nhsd_snomed OR ckd_stage_5_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Liver disease
  liver_disease_nhsd_snomed=patients.with_these_clinical_events(
    liver_disease_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  liver_disease_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=liver_disease_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  liver_disease_nhsd=patients.satisfying(
    "liver_disease_nhsd_snomed OR liver_disease_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Immune-mediated inflammatory disorders (IMID)
  immunosuppresant_drugs_nhsd=patients.with_these_medications(
    codelist=combine_codelists(
      immunosuppresant_drugs_dmd_codes, 
      immunosuppresant_drugs_snomed_codes),
    returning="binary_flag",
    between=["covid_test_positive_date - 6 months", "covid_test_positive_date"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  oral_steroid_drugs_nhsd=patients.with_these_medications(
    codelist=combine_codelists(
      oral_steroid_drugs_dmd_codes,
      oral_steroid_drugs_snomed_codes),
    returning="binary_flag",
    between=["covid_test_positive_date - 12 months", "covid_test_positive_date"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  oral_steroid_drug_nhsd_3m_count=patients.with_these_medications(
    codelist=combine_codelists(
      oral_steroid_drugs_dmd_codes,
      oral_steroid_drugs_snomed_codes),
    returning="number_of_matches_in_period",
    between=["covid_test_positive_date - 3 months", "covid_test_positive_date"],
    return_expectations={
      "incidence": 0.1,
      "int": {"distribution": "normal", "mean": 2, "stddev": 1},
    },
  ),
  oral_steroid_drug_nhsd_12m_count=patients.with_these_medications(
    codelist=combine_codelists(
      oral_steroid_drugs_dmd_codes,
      oral_steroid_drugs_snomed_codes),
    returning="number_of_matches_in_period",
    between=["covid_test_positive_date - 12 months", "covid_test_positive_date"],
    return_expectations={
      "incidence": 0.1,
      "int": {"distribution": "normal", "mean": 3, "stddev": 1},
    },
  ),
  oral_steroid_drugs_nhsd2=patients.satisfying(
    """
    oral_steroid_drugs_nhsd AND
    (oral_steroid_drug_nhsd_3m_count >=2 AND
    oral_steroid_drug_nhsd_12m_count >=4)
    """,
    return_expectations={
      "incidence": 0.05
    },
  ),
  imid_nhsd=patients.satisfying(
    "immunosuppresant_drugs_nhsd OR oral_steroid_drugs_nhsd2",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Primary immune deficiencies
  immunosupression_nhsd=patients.with_these_clinical_events(
    immunosupression_nhsd_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  immunosupression_nhsd_new=patients.with_these_clinical_events(
    immunosuppression_new_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  # HIV/AIDs
  hiv_aids_nhsd_snomed=patients.with_these_clinical_events(
    hiv_aids_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  hiv_aids_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=hiv_aids_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  hiv_aids_nhsd=patients.satisfying(
    "hiv_aids_nhsd_snomed OR hiv_aids_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Solid organ transplant
  solid_organ_transplant_nhsd_snomed=patients.with_these_clinical_events(
    solid_organ_transplant_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  solid_organ_transplant_nhsd_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_procedures=solid_organ_transplant_nhsd_opcs4_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  transplant_all_y_codes_opcs4=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_procedures=replacement_of_organ_transplant_nhsd_opcs4_codes,
    on_or_before="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    find_last_match_in_period=True,
    return_expectations={
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  transplant_thymus_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    with_these_procedures=thymus_gland_transplant_nhsd_opcs4_codes,
    between=["transplant_all_y_codes_opcs4","transplant_all_y_codes_opcs4"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  transplant_conjunctiva_y_code_opcs4=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_procedures=conjunctiva_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    find_last_match_in_period=True,
    return_expectations={
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  transplant_conjunctiva_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    with_these_procedures=conjunctiva_transplant_nhsd_opcs4_codes,
    between=["transplant_conjunctiva_y_code_opcs4","transplant_conjunctiva_y_code_opcs4"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  transplant_stomach_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    with_these_procedures=stomach_transplant_nhsd_opcs4_codes,
    between=["transplant_all_y_codes_opcs4","transplant_all_y_codes_opcs4"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  transplant_ileum_1_Y_codes_opcs4=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_procedures=ileum_1_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    find_last_match_in_period=True,
    return_expectations={
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  transplant_ileum_2_Y_codes_opcs4=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_procedures=ileum_1_y_codes_transplant_nhsd_opcs4_codes,
    on_or_before="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    find_last_match_in_period=True,
    return_expectations={
      "date": {"earliest": "2020-02-01"},
      "rate": "exponential_increase",
      "incidence": 0.01,
    },
  ),
  transplant_ileum_1_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    with_these_procedures=ileum_1_transplant_nhsd_opcs4_codes,
    between=["transplant_ileum_1_Y_codes_opcs4","transplant_ileum_1_Y_codes_opcs4"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  transplant_ileum_2_opcs4=patients.admitted_to_hospital(
    returning="binary_flag",
    with_these_procedures=ileum_2_transplant_nhsd_opcs4_codes,
    between=["transplant_ileum_2_Y_codes_opcs4","transplant_ileum_2_Y_codes_opcs4"],
    return_expectations={
      "incidence": 0.4
    },
  ),
  solid_organ_transplant_nhsd=patients.satisfying(
    """
    solid_organ_transplant_nhsd_snomed OR
    solid_organ_transplant_nhsd_opcs4 OR
    transplant_thymus_opcs4 OR
    transplant_conjunctiva_opcs4 OR
    transplant_stomach_opcs4 OR
    transplant_ileum_1_opcs4 OR
    transplant_ileum_2_opcs4
    """,
    return_expectations={
      "incidence": 0.05
    },
  ),
  solid_organ_transplant_nhsd_snomed_new=patients.with_these_clinical_events(
    solid_organ_transplant_new_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  solid_organ_transplant_nhsd_new=patients.satisfying(
    """
    solid_organ_transplant_nhsd_snomed_new OR
    solid_organ_transplant_nhsd_opcs4 OR
    transplant_thymus_opcs4 OR
    transplant_conjunctiva_opcs4 OR
    transplant_stomach_opcs4 OR
    transplant_ileum_1_opcs4 OR
    transplant_ileum_2_opcs4
    """,
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Rare neurological conditions
  # Multiple sclerosis
  multiple_sclerosis_nhsd_snomed=patients.with_these_clinical_events(
    multiple_sclerosis_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  multiple_sclerosis_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=multiple_sclerosis_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  multiple_sclerosis_nhsd=patients.satisfying(
    "multiple_sclerosis_nhsd_snomed OR multiple_sclerosis_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Motor neurone disease
  motor_neurone_disease_nhsd_snomed=patients.with_these_clinical_events(
    motor_neurone_disease_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  motor_neurone_disease_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=motor_neurone_disease_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  motor_neurone_disease_nhsd=patients.satisfying(
    "motor_neurone_disease_nhsd_snomed OR motor_neurone_disease_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Myasthenia gravis
  myasthenia_gravis_nhsd_snomed=patients.with_these_clinical_events(
    myasthenia_gravis_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  myasthenia_gravis_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=myasthenia_gravis_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  myasthenia_gravis_nhsd=patients.satisfying(
    "myasthenia_gravis_nhsd_snomed OR myasthenia_gravis_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # Huntington’s disease
  huntingtons_disease_nhsd_snomed=patients.with_these_clinical_events(
    huntingtons_disease_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ),
  huntingtons_disease_nhsd_icd10=patients.admitted_to_hospital(
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    with_these_diagnoses=huntingtons_disease_nhsd_icd10_codes,
    return_expectations={
      "incidence": 0.4
    },
  ),
  huntingtons_disease_nhsd=patients.satisfying(
    "huntingtons_disease_nhsd_snomed OR huntingtons_disease_nhsd_icd10",
    return_expectations={
      "incidence": 0.05
    },
  ),
  # High risk ehr recorded
  high_risk_group=patients.satisfying(
    """
    huntingtons_disease_nhsd OR
    myasthenia_gravis_nhsd OR
    motor_neurone_disease_nhsd OR
    multiple_sclerosis_nhsd OR
    solid_organ_transplant_nhsd OR
    hiv_aids_nhsd OR
    immunosupression_nhsd OR
    imid_nhsd OR
    liver_disease_nhsd OR
    ckd_stage_5_nhsd OR
    haematological_disease_nhsd OR
    cancer_opensafely_snomed OR
    downs_syndrome_nhsd
    """,
    return_expectations={
      "incidence": 1.0
    },
  ),
)
