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
# from codelists import *

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
    default_expectations={
        "date": {"earliest": "1900-01-01", "latest": end_date},
        "rate": "uniform",
        "incidence": 0.5,
    },
    
    # Set index date to start date
    study_start=start_date,
    study_end=end_date,
    
    # Define the study population
    population = patients.satisfying(
        """
        covid_test_positive AND
        has_follow_up AND
        NOT died AND
        (age >=18 AND age <= 110) AND
        (sex = "M" OR sex = "F") AND
        NOT stp = "" AND
        imd > 0 

        """,
        ),

    # INCLUSION CRITERIA 
        covid_test_positive = patients.with_test_result_in_sgss(
            pathogen = "SARS-CoV-2",
            test_result = "positive",
            returning = "binary_flag",
            between = ["study_start", "study_end"],
            find_first_match_in_period = True,
            restrict_to_earliest_specimen_date = False,
            return_expectations = {"incidence": 0.9},
        ),
        index_date = patients.with_test_result_in_sgss(
            pathogen = "SARS-CoV-2",
            test_result = "positive",
            find_first_match_in_period = True,
            restrict_to_earliest_specimen_date = False,
            returning = "date",
            date_format = "YYYY-MM-DD",
            return_expectations = {
                "date": {"earliest": "study_start", "latest": "study_end"},
                "incidence": 0.9
            },
        ),
        has_follow_up=patients.registered_with_one_practice_between(
            "index_date - 3 months", "index_date"
        ),
        died=patients.died_from_any_cause(
            on_or_before="index_date",
            returning="binary_flag",
            return_expectations={"incidence": 0.01},
        ),
        # age
        age=patients.age_as_of(
            "index_date",
            return_expectations={
                "rate": "universal",
                "int": {"distribution": "population_ages"},
            },
        ),
        # sex
        sex=patients.sex(
            return_expectations={
                "rate": "universal",
                "category": {"ratios": {"M": 0.49, "F": 0.51}},
            },
        ),
        # stp
        stp=patients.registered_practice_as_of(
            "index_date",
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
        # index of multiple deprivation
        imd=patients.categorised_as(
            {
                "0": "DEFAULT",
                "1": """index_of_multiple_deprivation >=1 AND
                    index_of_multiple_deprivation < 32844*1/5""",
                "2": """index_of_multiple_deprivation >= 32844*1/5 AND
                    index_of_multiple_deprivation < 32844*2/5""",
                "3": """index_of_multiple_deprivation >= 32844*2/5 AND
                    index_of_multiple_deprivation < 32844*3/5""",
                "4": """index_of_multiple_deprivation >= 32844*3/5 AND
                    index_of_multiple_deprivation < 32844*4/5""",
                "5": """index_of_multiple_deprivation >= 32844*4/5 AND
                    index_of_multiple_deprivation < 32844""",
            },
            return_expectations={
                "rate": "universal",
                "category": {
                    "ratios": {
                        "0": 0.05,
                        "1": 0.19,
                        "2": 0.19,
                        "3": 0.19,
                        "4": 0.19,
                        "5": 0.19,
                    }
                },
            },
        
            # imd (index of multiple deprivation) quintile
            index_of_multiple_deprivation=patients.address_as_of(
                date="index_date",
                returning="index_of_multiple_deprivation",
                round_to_nearest=100,
                return_expectations={
                    "rate": "universal",
                    "category": {
                        "ratios": {
                            "0": 0.05,
                            "1": 0.19,
                            "2": 0.19,
                            "3": 0.19,
                            "4": 0.19,
                            "5": 0.19,
                            }
                        },
                    },
            ),
        ),
)