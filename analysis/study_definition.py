######################################

# This script provides the formal specification of the study data that will
# be extracted from the OpenSAFELY database.

######################################

# IMPORT STATEMENTS ----
# Import code building blocks from cohort extractor package

from cohortextractor import (
    StudyDefinition,
    patients,
    filter_codes_by_category,
    combine_codelists,
    codelist_from_csv,
    codelist,
    Measure
)

# Import codelists from codelist.py (which pulls them from the codelist folder)
from codelists import *

# Import config variables (dates, list of demographics and list of
# comorbidities)

# Import json module
import json
with open('lib/design/study-dates.json', 'r') as f:
    study_dates = json.load(f)

start_date = study_dates["start_date"]
end_date = study_dates["end_date"]

# DEFINE STUDY POPULATION ----
# Define study population and variables
study = StudyDefinition(

    # Configure the expectations framework
    default_expectations = {
        "date": {"earliest": "2021-11-01", "latest": "today"},
        "rate": "uniform",
        "incidence": 0.05,
    },
    
    # Set index date to start date
    study_start=start_date,
    study_end=end_date,
    
    # Define the study population
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
        on_or_after = "study_start",
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
        on_or_after = "study_start",
        return_expectations = {
            "date": {"earliest": "study_start"},
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