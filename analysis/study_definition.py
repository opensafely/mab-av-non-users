# IMPORT STATEMENTS ----
# Import code building blocks from cohort extractor package
from cohortextractor import (
  StudyDefinition,
  patients,
  filter_codes_by_category,
  combine_codelists,
)
# Import codelists from codelist.py (which pulls them from the codelist
# folder)
from codelists import *
# Define study time variables by importing study-dates
# Import json module
import json
with open('lib/design/study-dates.json', 'r') as f:
    study_dates = json.load(f)
start_date = study_dates["start_date"]
end_date = study_dates["end_date"]


# Function to create variable covid_hosp_admission_date
def make_hosp_admission(day, prefix, diagnoses, primary_diagnoses):
    return{
        f"{prefix}_hosp_admission_date{day}": (
            patients.admitted_to_hospital(
                returning="date_admitted",
                with_these_diagnoses=diagnoses,
                with_these_primary_diagnoses=primary_diagnoses,
                with_patient_classification=["1"],  # ordinary admissions only - exclude day cases and regular attenders
                # see https://docs.opensafely.org/study-def-variables/#sus for more info
                between=[f"covid_test_positive_date + {day} days", f"covid_test_positive_date + {day} days"],
                find_first_match_in_period=True,
                date_format="YYYY-MM-DD",
                return_expectations={
                  "date": {"earliest": "2022-02-16"},
                  "rate": "uniform",
                  "incidence": 0.1},
            )
        )
    }


def hosp_admission_loop_over_days(days, prefix, diagnoses, primary_diagnoses):
    variables = {}
    for day in days:
        variables.update(make_hosp_admission(day=day, prefix=prefix, diagnoses=diagnoses, primary_diagnoses=primary_diagnoses))
    return variables


# DEFINE STUDY POPULATION ----
# Define study population and variables
study = StudyDefinition(

  # PRELIMINARIES ----
  # Configure the expectations framework
  default_expectations={
    "date": {"earliest": "2021-11-01", "latest": "today"},
    "rate": "uniform",
    "incidence": 0.05,
  }, 
  # Define index date
  index_date=start_date,

  # POPULATION ----
  population=patients.satisfying(
    """
    age >= 18 AND age < 110
    AND NOT has_died
    AND (sex = "M" OR sex = "F")
    AND NOT stp = ""
    AND (imd >= 0 AND has_msoa)
    AND (
     registered_eligible
      AND
      (covid_test_positive
      AND NOT covid_positive_prev_90_days
      AND NOT any_covid_hosp_prev_90_days)
    )
    AND NOT prev_treated
    AND high_risk_group
    """,
  ),

  # MAIN ELIGIBILITY - FIRST POSITIVE SARS-CoV-2 TEST IN PERIOD ----
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
  # Date of positive test
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
      "date": {"earliest": "2021-12-16", "latest": "2022-02-01"},
    },
  ),
  # Was patients registered at the time of a positive test?
  registered_eligible=patients.registered_as_of("covid_test_positive_date"),
  # Was patient alive?
  has_died=patients.died_from_any_cause(
    on_or_before="covid_test_positive_date - 1 day",
    returning="binary_flag",
  ),

  # TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
  # Paxlovid
  paxlovid_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics="Paxlovid",
    with_these_indications="non_hospitalised",
    between=["covid_test_positive_date", end_date],
    find_first_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-10"},
      "incidence": 0.05
    },
  ),
  # Sotrovimab
  sotrovimab_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics="Sotrovimab",
    with_these_indications="non_hospitalised",
    between=["covid_test_positive_date", end_date],
    find_first_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.5
    },
  ),
  # Remdesivir
  remdesivir_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics="Remdesivir",
    with_these_indications="non_hospitalised",
    between=["covid_test_positive_date", end_date],
    find_first_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.2
    },
  ),
  # Molnupiravir
  molnupiravir_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics="Molnupiravir",
    with_these_indications="non_hospitalised",
    between=["covid_test_positive_date", end_date],
    find_first_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.5
    },
  ),
  # Casirivimab and imdevimab
  casirivimab_covid_therapeutics=patients.with_covid_therapeutics(
    with_these_therapeutics="Casirivimab and imdevimab",
    with_these_indications="non_hospitalised",
    between=["covid_test_positive_date", end_date],
    find_first_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2021-12-16"},
      "incidence": 0.05
    },
  ),
  # Date treated
  date_treated=patients.minimum_of(
    "paxlovid_covid_therapeutics",
    "sotrovimab_covid_therapeutics",
    "remdesivir_covid_therapeutics",
    "molnupiravir_covid_therapeutics",
    "casirivimab_covid_therapeutics",
  ),

  # PREVIOUS TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
  # Paxlovid
  paxlovid_covid_prev=patients.with_covid_therapeutics(
    with_these_therapeutics="Paxlovid",
    with_these_indications="non_hospitalised",
    on_or_after="covid_test_positive_date - 1 day",
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

  # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
  # Inclusion criteria variables
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
  # Onset of symptoms of COVID-19
  symptomatic_covid_test=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="any",
    returning="symptomatic",
    on_or_after="covid_test_positive_date",
    find_first_match_in_period=True,  # same record as the record used to
    # include patient
    restrict_to_earliest_specimen_date=False,
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
  # Evidence of symptoms of COVID-19
  covid_symptoms_snomed=patients.with_these_clinical_events(
    covid_symptoms_snomed_codes,
    returning="date",
    on_or_after="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    find_first_match_in_period=True,
  ),
  # Pregnancy
  # Sex
  sex=patients.sex(
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {"M": 0.49, "F": 0.51}},
    }
  ),
  # pregnancy record in last 36 weeks
  preg_36wks_date=patients.with_these_clinical_events(
    pregnancy_primis_codes,
    returning="date",
    find_last_match_in_period=True,
    between=["covid_test_positive_date - 252 days", "covid_test_positive_date - 1 day"],
    date_format="YYYY-MM-DD",
  ),
  # pregnancy OR delivery code since latest pregnancy record:
  # if one of these codes occurs later than the latest pregnancy code
  # this indicates pregnancy has ended, if they are same date assume
  # pregnancy has most likely not ended yet
  pregdel=patients.with_these_clinical_events(
    pregdel_primis_codes,
    returning="binary_flag",
    find_last_match_in_period=True,
    between=["preg_36wks_date + 1 day", "covid_test_positive_date - 1 day"],
    date_format="YYYY-MM-DD",
  ),
  pregnancy=patients.satisfying(
    """
    sex = "F" AND preg_age <= 50
    AND (preg_36wks_date AND NOT pregdel)
    """,
    preg_age=patients.age_as_of(
      "preg_36wks_date",
      return_expectations={
        "rate": "universal",
        "int": {"distribution": "population_ages"},
        "incidence": 0.9
      },
    ),
  ),

  # CENSORING ----
  # Death of any cause
  death_date=patients.died_from_any_cause(
    returning="date_of_death",
    date_format="YYYY-MM-DD",
    on_or_after="covid_test_positive_date",
    return_expectations={
      "date": {"earliest": "2021-12-20"},
      "incidence": 0.1
    },
  ),
  # De-registration
  dereg_date=patients.date_deregistered_from_all_supported_practices(
    on_or_after="covid_test_positive_date",
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2021-12-20"},
      "incidence": 0.1
    },
  ),

  # HIGH RISK GROUPS ----
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
  imid_nhsd=patients.satisfying(
    "immunosuppresant_drugs_nhsd OR oral_steroid_drugs_nhsd",
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

  # CLINICAL/DEMOGRAPHIC COVARIATES ----
  # Age
  age=patients.age_as_of(
    "covid_test_positive_date",
    return_expectations={
      "rate": "universal",
      "int": {"distribution": "population_ages"},
      "incidence": 0.9
    },
  ),
  # Sex is defined in pregnancy section above
  # Bmi
  # set maximum to avoid any impossibly extreme values being classified as
  # obese
  bmi_value=patients.most_recent_bmi(
    on_or_after="covid_test_positive_date - 5 years",
    minimum_age_at_measurement=16,
    return_expectations={
      "date": {"latest": "today"},
      "float": {"distribution": "normal", "mean": 25.0, "stddev": 7.5},
      "incidence": 0.8,
    },
  ),
  bmi=patients.categorised_as(
    {
      "Not obese": "DEFAULT",
      "Obese I (30-34.9)": """ bmi_value >= 30 AND bmi_value < 35""",
      "Obese II (35-39.9)": """ bmi_value >= 35 AND bmi_value < 40""",
      "Obese III (40+)": """ bmi_value >= 40 AND bmi_value < 100""",
    },
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "Not obese": 0.7,
          "Obese I (30-34.9)": 0.1,
          "Obese II (35-39.9)": 0.1,
          "Obese III (40+)": 0.1,
        }
      },
      "incidence": 1.0,
    },
  ),
  # Smoking status
  smoking_status=patients.categorised_as(
    {
      "S": "most_recent_smoking_code = 'S'",
      "E": """
        most_recent_smoking_code = 'E' OR (
        most_recent_smoking_code = 'N' AND ever_smoked)
           """,
      "N": "most_recent_smoking_code = 'N' AND NOT ever_smoked",
      "M": "DEFAULT",
    },
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "S": 0.6,
          "E": 0.1,
          "N": 0.2,
          "M": 0.1,
        }
      },
    },
    most_recent_smoking_code=patients.with_these_clinical_events(
      clear_smoking_codes,
      find_last_match_in_period=True,
      on_or_before="covid_test_positive_date",
      returning="category",
    ),
    ever_smoked=patients.with_these_clinical_events(
      filter_codes_by_category(clear_smoking_codes, include=["S", "E"]),
      on_or_before="covid_test_positive_date",
    ),
  ),
  # Ethnicity
  ethnicity_primis=patients.with_these_clinical_events(
    ethnicity_primis_snomed_codes,
    returning="category",
    on_or_before="covid_test_positive_date",
    find_first_match_in_period=True,
    include_date_of_match=False,
    return_expectations={
      "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
      "incidence": 0.75,
    },
  ),
  ethnicity_sus=patients.with_ethnicity_from_sus(
    returning="group_6",  
    use_most_frequent_code=True,
    return_expectations={
      "category": {"ratios": {"1": 0.2, "2": 0.2, "3": 0.2, "4": 0.2, "5": 0.2}},
      "incidence": 0.8,
    },
  ),
  ethnicity=patients.categorised_as(
    {
      "0": "DEFAULT",
      "1": "ethnicity_primis='1' OR (NOT ethnicity_primis AND ethnicity_sus='1')",
      "2": "ethnicity_primis='2' OR (NOT ethnicity_primis AND ethnicity_sus='2')",
      "3": "ethnicity_primis='3' OR (NOT ethnicity_primis AND ethnicity_sus='3')",
      "4": "ethnicity_primis='4' OR (NOT ethnicity_primis AND ethnicity_sus='4')",
      "5": "ethnicity_primis='5' OR (NOT ethnicity_primis AND ethnicity_sus='5')",
    },
    return_expectations={
      "category": {
        "ratios": {
            "0": 0.5,  # missing in 50%
            "1": 0.1,
            "2": 0.1,
            "3": 0.1,
            "4": 0.1,
            "5": 0.1
        }
      },
      "incidence": 1.0,
    },
  ),
  # Index of multiple deprivation
  has_msoa=patients.satisfying(
    "NOT (msoa = '')",
    msoa=patients.address_as_of(
      "index_date",
      returning="msoa",
    ),
    return_expectations={"incidence": 0.2}
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
  imdQ5=patients.categorised_as(
    {
      "0": "DEFAULT",
      "1 (most deprived)": "imd >= 0 AND imd < 32800*1/5",
      "2": "imd >= 32800*1/5 AND imd < 32800*2/5",
      "3": "imd >= 32800*2/5 AND imd < 32800*3/5",
      "4": "imd >= 32800*3/5 AND imd < 32800*4/5",
      "5 (least deprived)": "imd >= 32800*4/5 AND imd <= 32800",
    },
    return_expectations={
      "rate": "universal",
      "category": {
        "ratios": {
          "0": 0,
          "1 (most deprived)": 0.20,
          "2": 0.20,
          "3": 0.20,
          "4": 0.20,
          "5 (least deprived)": 0.20,
        }
      },
    },
  ),
  # Region - NHS England 9 regions
  region_nhs=patients.registered_practice_as_of(
    "covid_test_positive_date",
    returning="nuts1_region_name",
    return_expectations={
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
  # Rurality
  rural_urban=patients.address_as_of(
    "covid_test_positive_date",
    returning="rural_urban_classification",
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {1: 0.125, 2: 0.125, 3: 0.125, 4: 0.125, 5: 0.125, 6: 0.125, 7: 0.125, 8: 0.125}},
      "incidence": 1,
    },
  ),

  # CLINICAL GROUPS ----
  # Autism
  autism_nhsd=patients.with_these_clinical_events(
    autism_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={"incidence": 0.3}
  ),
  # Care home
  care_home_primis=patients.with_these_clinical_events(
    care_home_primis_snomed_codes,
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    return_expectations={"incidence": 0.15,}
  ),
  # Dementia
  dementia_nhsd=patients.satisfying(
    """
    dementia_all
    AND
    age > 39
    """, 
    return_expectations={
      "incidence": 0.01,
    },
    dementia_all=patients.with_these_clinical_events(
      dementia_nhsd_snomed_codes,
      on_or_before="covid_test_positive_date",
      returning="binary_flag",
      return_expectations={"incidence": 0.05}
    ),
  ),
  # Housebound
  housebound_opensafely=patients.satisfying(
    """
    housebound_date
    AND NOT no_longer_housebound
    AND NOT moved_into_care_home
    """,
    return_expectations={
      "incidence": 0.01,
    },
    housebound_date=patients.with_these_clinical_events( 
      housebound_opensafely_snomed_codes, 
      on_or_before="covid_test_positive_date",
      find_last_match_in_period=True,
      returning="date",
      date_format="YYYY-MM-DD",
    ),   
    no_longer_housebound=patients.with_these_clinical_events( 
      no_longer_housebound_opensafely_snomed_codes, 
      on_or_after="housebound_date",
    ),
    moved_into_care_home=patients.with_these_clinical_events(
      care_home_primis_snomed_codes,
      on_or_after="housebound_date",
    ),
  ),
  # Learning disability
  learning_disability_primis=patients.with_these_clinical_events(
    wider_ld_primis_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={"incidence": 0.2}
  ),
  # Shielded
  shielded_primis=patients.satisfying(
    """ 
    severely_clinically_vulnerable
    AND 
    NOT less_vulnerable 
    """, 
    return_expectations={
      "incidence": 0.01,
    },
    # SHIELDED GROUP - first flag all patients with "high risk" codes
    severely_clinically_vulnerable=patients.with_these_clinical_events(
      high_risk_primis_snomed_codes, # note no date limits set
      find_last_match_in_period=True,
      return_expectations={"incidence": 0.02,},
    ),
    # find date at which the high risk code was added
    date_severely_clinically_vulnerable=patients.date_of(
      "severely_clinically_vulnerable", 
      date_format  ="YYYY-MM-DD",   
    ),
    # NOT SHIELDED GROUP (medium and low risk) - only flag if later than 'shielded'
    less_vulnerable=patients.with_these_clinical_events(
      not_high_risk_primis_snomed_codes, 
      on_or_after="date_severely_clinically_vulnerable",
      return_expectations={"incidence": 0.01,},
    ),
  ),  
  # Serious Mental Illness
  serious_mental_illness_nhsd=patients.with_these_clinical_events(
    serious_mental_illness_nhsd_snomed_codes,
    on_or_before="covid_test_positive_date",
    returning="binary_flag",
    return_expectations={"incidence": 0.1}
  ),

  # VACCINATION STATUS ----
  vaccination_status=patients.categorised_as(
    {
      "Un-vaccinated": "DEFAULT",
      "Un-vaccinated (declined)": """ covid_vax_declined AND NOT (covid_vax_1 OR covid_vax_2 OR covid_vax_3)""",
      "One vaccination": """ covid_vax_1 AND NOT covid_vax_2 """,
      "Two vaccinations": """ covid_vax_2 AND NOT covid_vax_3 """,
      "Three or more vaccinations": """ covid_vax_3 """
    },
    # first vaccine from during trials and up to treatment/test date
    covid_vax_1=patients.with_tpp_vaccination_record(
      target_disease_matches="SARS-2 CORONAVIRUS",
      between=["2020-06-08", "covid_test_positive_date"],
      find_first_match_in_period=True,
      returning="date",
      date_format="YYYY-MM-DD"
    ),
    covid_vax_2=patients.with_tpp_vaccination_record(
      target_disease_matches="SARS-2 CORONAVIRUS",
      between=["covid_vax_1 + 19 days", "covid_test_positive_date"],
      find_first_match_in_period=True,
      returning="date",
      date_format="YYYY-MM-DD"
    ),
    covid_vax_3=patients.with_tpp_vaccination_record(
      target_disease_matches="SARS-2 CORONAVIRUS",
      between=["covid_vax_2 + 56 days", "covid_test_positive_date"],
      find_first_match_in_period=True,
      returning="date",
      date_format="YYYY-MM-DD"
    ),
    covid_vax_declined=patients.with_these_clinical_events(
      covid_vaccine_declined_codes,
      returning="binary_flag",
      on_or_before="covid_test_positive_date",
    ),
    return_expectations={
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
  # Date of most recent covid vaccination
  date_most_recent_cov_vac=patients.with_tpp_vaccination_record(
    target_disease_matches="SARS-2 CORONAVIRUS",
    between=["2020-06-08", "covid_test_positive_date"],
    find_last_match_in_period=True,
    returning="date",
    date_format="YYYY-MM-DD"
  ),
  # Most recent covid covid vaccination
  pfizer_most_recent_cov_vac=patients.with_tpp_vaccination_record(
    product_name_matches="COVID-19 mRNA Vaccine Comirnaty 30micrograms/0.3ml dose conc for susp for inj MDV (Pfizer)",
    between=["date_most_recent_cov_vac", "date_most_recent_cov_vac"],
    find_last_match_in_period=True,
    returning="binary_flag",
    return_expectations={
      "incidence": 0.4
    },
  ), 
  az_most_recent_cov_vac=patients.with_tpp_vaccination_record(
    product_name_matches="COVID-19 Vaccine Vaxzevria 0.5ml inj multidose vials (AstraZeneca)",
    between=["date_most_recent_cov_vac", "date_most_recent_cov_vac"],
    find_last_match_in_period=True,
    returning="binary_flag",
    return_expectations={
      "incidence": 0.5
    },
  ),
  moderna_most_recent_cov_vac=patients.with_tpp_vaccination_record(
    product_name_matches="COVID-19 mRNA Vaccine Spikevax (nucleoside modified) 0.1mg/0.5mL dose disp for inj MDV (Moderna)",
    between=["date_most_recent_cov_vac", "date_most_recent_cov_vac"],
    find_last_match_in_period=True,
      returning="binary_flag",
      return_expectations={
        "incidence": 0.5
      },
  ),

  # CLINICAL CO-MORBIDITIES ----
  # Sickle cell disease
  sickle_cell_disease_nhsd=patients.satisfying(
    "sickle_cell_disease_nhsd_snomed OR sickle_cell_disease_nhsd_icd10",
    return_expectations={
      "incidence": 0.01,
    }, 
  ),
  # Diabetes
  diabetes=patients.with_these_clinical_events(
    diabetes_codes,  # imported from codelists.py
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    find_last_match_in_period=True,
  ),
  # Chronic obstructive pulmonary disease
  copd=patients.with_these_clinical_events(
    chronic_respiratory_dis_codes,  # imported from codelists.py
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    find_last_match_in_period=True,
  ),
  # Chronic heart disease
  chronic_cardiac_disease=patients.with_these_clinical_events(
    chronic_cardiac_dis_codes,  # imported from codelists.py
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    find_last_match_in_period=True,
  ),
  # Dialysis
  dialysis=patients.with_these_clinical_events(
    dialysis_codes,  # imported from codelists.py
    returning="binary_flag",
    on_or_before="covid_test_positive_date",
    find_last_match_in_period=True,
    include_date_of_match=True,  # generates dialysis_date
    date_format="YYYY-MM-DD",
  ),
  # Cancer
  cancer=patients.with_these_clinical_events(
    non_haematological_cancer_opensafely_snomed_codes,
    returning="binary_flag",
    between=["covid_test_positive_date - 5 years", "covid_test_positive_date"],
    find_last_match_in_period=True,
    include_date_of_match=True,
    date_format="YYYY-MM-DD",
  ),
  # Lung cancer
  lung_cancer=patients.with_these_clinical_events(
    lung_cancer_opensafely_snomed_codes,
    returning="binary_flag",
    between=["covid_test_positive_date - 5 years", "covid_test_positive_date"],
    find_last_match_in_period=True,
    include_date_of_match=True,
    date_format="YYYY-MM-DD",
  ),
  # Haematological malignancy
  haem_cancer=patients.with_these_clinical_events(
    haem_cancer_codes,  # imported from codelists.py
    returning="binary_flag",
    between=["covid_test_positive_date - 5 years", "covid_test_positive_date"],
    find_last_match_in_period=True,
    include_date_of_match=True,
    date_format="YYYY-MM-DD",
  ),
  
  # COVID VARIANT ----
  # S-Gene Target Failure
  sgtf=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="positive",
    find_first_match_in_period=True,
    between=["covid_test_positive_date", "covid_test_positive_date"],
    returning="s_gene_target_failure",
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {"0": 0.7, "1": 0.1, "9": 0.1, "": 0.1}},
    },
  ), 
  # Variant
  variant=patients.with_test_result_in_sgss(
    pathogen="SARS-CoV-2",
    test_result="positive",
    find_first_match_in_period=True,
    between=["covid_test_positive_date", "covid_test_positive_date"],
    restrict_to_earliest_specimen_date=False,
    returning="variant",
    return_expectations={
      "rate": "universal",
      "category": {"ratios": {"B.1.617.2": 0.7, "B.1.1.7+E484K": 0.1, "No VOC detected": 0.1, "Undetermined": 0.1}},
    },
  ), 

  # OUTCOMES ----  
  # COVID-related hospitalisation on day 0 (+ve test), 1, 2, 3, 4, 5 or 6 
  # These events are extracted seperately in case patient is admitted twice, and first time was for sotrovimab
  # infusion
  # If a patient is admitted and discharged on the same day OR one day apart AND patient 
  # received sotrovimab --> this event should not be counted as an outcome
  # COVID-related hospitalisation is here defined as icd10 code mentioned on the EHR (primary or underlying)
  **hosp_admission_loop_over_days(days={"0", "1", "2", "3", "4", "5", "6"}, prefix="covid", diagnoses=None, primary_diagnoses=covid_icd10_codes),
  # Day 8 - 28ad
  # assuming no day case admission after day 7
  covid_hosp_admission_first_date7_27=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_primary_diagnoses=covid_icd10_codes,
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    between=["covid_test_positive_date + 7 days", "covid_test_positive_date + 27 days"],
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),
  # Discharge
  # return discharge date to (make sure) identify and ignore day cases
  # We only want to know date of first discharge (find_first_match_in_period = TRUE)
  # --> needed to identify day cases for sotrovimab infusions
  # max admission for sotro is day 6 (2 days after day 4), so max discharge is day 7
  covid_hosp_discharge_first_date0_7=patients.admitted_to_hospital(
    returning="date_discharged",
    with_these_primary_diagnoses=covid_icd10_codes,
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    between=["covid_hosp_admission_date0", "covid_hosp_admission_date0 + 7 days"],
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),
  # mention of mabs procedure
  # --> if so, hospital admission should not be counted as outcome
  # (could this occur if patient gets mabs while hospitalised????)
  covid_hosp_date_mabs_procedure=patients.admitted_to_hospital(
    returning="date_admitted",
    with_these_primary_diagnoses=covid_icd10_codes,
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_these_procedures=mabs_procedure_codes,
    on_or_after="covid_test_positive_date",
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),

  # All cause hospitalisation (censoring)
  # Day 1 - day 7 extracted seperately in order to being able to identify day cases (those should not be censored)
  # Day 1
  **hosp_admission_loop_over_days(days={"0", "1", "2", "3", "4", "5", "6"}, prefix="allcause", diagnoses=None, primary_diagnoses=None),
  # Day 8 - 28
  # assuming no day case admission after day 7
  allcause_hosp_admission_first_date7_27=patients.admitted_to_hospital(
    returning="date_admitted",
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    between=["covid_test_positive_date + 7 days", "covid_test_positive_date + 27 days"],
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),
  # Discharge
  # return discharge date to (make sure) identify and ignore day cases
  # We only want to know date of first discharge (find_first_match_in_period = TRUE)
  # --> needed to identify day cases for sotrovimab infusions
  allcause_hosp_discharge_first_date0_7=patients.admitted_to_hospital(
    returning="date_discharged",
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    between=["allcause_hosp_admission_date0", "allcause_hosp_admission_date0 + 7 days"],
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),
  # mention of mabs procedure
  allcause_hosp_date_mabs_procedure=patients.admitted_to_hospital(
    returning="date_admitted",
    with_patient_classification=["1"], # ordinary admissions only - exclude day cases and regular attenders
    # see https://docs.opensafely.org/study-def-variables/#sus for more info
    with_these_procedures=mabs_procedure_codes,
    on_or_after="covid_test_positive_date",
    find_first_match_in_period=True,
    date_format="YYYY-MM-DD",
    return_expectations={
      "date": {"earliest": "2022-02-16"},
      "rate": "uniform",
      "incidence": 0.1
    },
  ),
  # covid related death
  # Patients with ONS-registered death
  died_ons_covid_any_date=patients.with_these_codes_on_death_certificate(
    covid_icd10_codes,  # imported from codelists.py
    returning="date_of_death",
    between=["covid_test_positive_date", "covid_test_positive_date + 27 days"],
    date_format="YYYY-MM-DD",
    match_only_underlying_cause=False,  # boolean for indicating if filters
    # results to only specified cause of death
    return_expectations={
      "rate": "exponential_increase",
      "incidence": 0.05,
    },
  ),
  # cause of death (death_date is extracted above (--> censoring var))
  death_cause=patients.died_from_any_cause(
    returning="underlying_cause_of_death",
    on_or_after="covid_test_positive_date",
    return_expectations={
      "rate": "universal",
      "incidence": 0.05,
      "category": {
        "ratios": {
          "icd1": 0.2,
          "icd2": 0.2,
          "icd3": 0.2,
          "icd4": 0.2,
          "icd5": 0.2,
        }
      },
    },
  ),
)