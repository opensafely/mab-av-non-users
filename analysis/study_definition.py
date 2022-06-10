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
end_date = "2022-02-10"


## Define study population and variables
study = StudyDefinition(
  
  # PRELIMINARIES ----
  
  ## Configure the expectations framework
  default_expectations = {
    "date": {"earliest": "2021-12-16", "latest": end_date},
    "rate": "uniform",
    "incidence": 0.05,
  },
  
  ## Define index date
  studystart_date = campaign_start,
  
  # POPULATION ----
    population = patients.satisfying(
        """
        covid_test_positive AND NOT covid_positive_previous_90_days

        """,
        ),

    # INCLUSION CRITERIA 
    covid_test_positive = patients.with_test_result_in_sgss(
        pathogen = "SARS-CoV-2",
        test_result = "positive",
        returning = "binary_flag",
        on_or_after = "studystart_date",
        find_first_match_in_period = True,
        restrict_to_earliest_specimen_date = False,
        return_expectations = {
        "incidence": 0.8
        },
     ),
    covid_test_positive_date = patients.with_test_result_in_sgss(
        pathogen = "SARS-CoV-2",
        test_result = "positive",
        find_first_match_in_period = True,
        restrict_to_earliest_specimen_date = False,
        returning = "date",
        date_format = "YYYY-MM-DD",
        on_or_after = "studystart_date",
        return_expectations = {
            "date": {"earliest": "studystart_date"},
            "incidence": 0.9
        },
    ),

  ### Positive covid test last 90 days 
    covid_positive_previous_90_days = patients.with_test_result_in_sgss(
        pathogen = "SARS-CoV-2",
        test_result = "positive",
        returning = "binary_flag",
        between = ["covid_test_positive_date - 91 days", "covid_test_positive_date - 1 day"],
        find_last_match_in_period = True,
        restrict_to_earliest_specimen_date = False,
        return_expectations = {
            "incidence": 0.03
        },
    ),
)
  