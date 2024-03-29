################################################################################
#
# Processing data
# 
# This script can be run via an action in project.yaml using one argument:
# - 'period' /in {ba1, ba2} --> period 
#
# Depending on 'period' the output of this script is:
# 5 .rds files named:
# -./output/data/'period'_data_processed_day0.rds
# -./output/data/'period'_data_processed_day2.rds
# -./output/data/'period'_data_processed_day3.rds
# -./output/data/'period'_data_processed_day4.rds
# -./output/data/'period'_data_processed_day5.rds
# (if period == ba1, no prefix is used)
#
# in the _day2-5 files, patients are classified as treated if they are treated
# within 2-5 days, respectively; and excluded if they experience an outcome in
# days 2-5, respectively (outcome = all cause death/ hosp or dereg)
# in the day0 file, patients are classified as treated if they are treated within
# 5 days and never excluded
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library('tidyverse')
library('lubridate')
library('here')
library('gt')
library('gtsummary')
library('arrow')
library('reshape2')
## Import custom user functions
source(here::here("lib", "functions", "fct_case_when.R"))
source(here::here("lib", "functions", "define_covid_hosp_admissions.R"))
source(here::here("lib", "functions", "define_allcause_hosp_admissions.R"))
source(here::here("lib", "functions", "define_allcause_hosp_diagnosis.R"))
source(here::here("lib", "functions", "define_status_and_fu_all.R"))
source(here::here("lib", "functions", "define_status_and_fu_primary.R"))
source(here::here("lib", "functions", "define_status_and_fu_secondary.R"))
# import globally defined study dates and convert to "Date"
study_dates <-
  jsonlite::read_json(path=here("lib", "design", "study-dates.json")) %>%
  map(as.Date)

################################################################################
# 0.1 Create directories for output
################################################################################
fs::dir_create(here::here("output", "data"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
} else if (args[[1]] == "ba1") {
  period = "ba1"
} else if (args[[1]] == "ba2") {
  period = "ba2"
} else {
  # Print error if no argument specified
  stop("No period specified")
}

################################################################################
# 1 Import data
################################################################################
input_filename <- 
  if (period == "ba1"){
    "input.csv.gz"
  } else if (period == "ba2"){
    "input_ba2.csv.gz"
  }
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
    
    # PREVIOUS TREATMENT - NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----
    
    # OVERALL ELIGIBILITY CRITERIA VARIABLES ----
    symptomatic_covid_test = col_character(),
    covid_symptoms_snomed = col_date(format = "%Y-%m-%d"),
    pregnancy = col_logical(),
    
    # CENSORING ----
    death_date = col_date(format = "%Y-%m-%d"),
    dereg_date = col_date(format = "%Y-%m-%d"),
    
    # HIGH RISK GROUPS ----
    high_risk_cohort_covid_therapeutics = col_factor(),
    high_risk_group = col_logical(),
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
    non_haem_cancer_new = col_logical(),
    immunosupression_new = col_logical(),
    solid_organ_transplant_new = col_logical(),
    downs_syndrome_nhsd  = col_logical(), 

    # CLINICAL/DEMOGRAPHIC COVARIATES ----
    diabetes = col_logical(),
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
    # all cause diagnosis of hosp admission
    allcause_hosp_admission_diagnosis0 = col_character(),
    allcause_hosp_admission_diagnosis1 = col_character(),
    allcause_hosp_admission_diagnosis2 = col_character(),
    allcause_hosp_admission_diagnosis4 = col_character(),
    allcause_hosp_admission_diagnosis3 = col_character(),
    allcause_hosp_admission_diagnosis5 = col_character(),
    allcause_hosp_admission_diagnosis6 = col_character(),
    allcause_hosp_admission_first_diagnosis7_27 = col_character(),
    # death
    died_ons_covid_any_date = col_date(format = "%Y-%m-%d"),
    death_cause = col_factor()
  ),
)

################################################################################
# 2 Clean data
################################################################################
## Format columns (i.e, set factor levels)
data_processed <- data_extract %>%
  mutate(
    # Cinic/demo variables -----
    ageband = cut(
      age,
      breaks = c(18, 40, 60, 80, Inf),
      labels = c("18-39", "40-59", "60-79", "80+"),
      right = FALSE
    ),
    
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
    
    bmi_group = fct_case_when(
      bmi == "Not obese" ~ "Not obese",
      bmi == "Obese I (30-34.9)" ~ "Obese I (30-34.9)",
      bmi == "Obese II (35-39.9)" ~ "Obese II (35-39.9)",
      bmi == "Obese III (40+)" ~ "Obese III (40+)",
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
    
    # Rural/urban
    rural_urban = fct_case_when(
      rural_urban %in% c(1:2) ~ "Urban - conurbation",
      rural_urban %in% c(3:4) ~ "Urban - city and town",
      rural_urban %in% c(5:6) ~ "Rural - town and fringe",
      rural_urban %in% c(7:8) ~ "Rural - village and dispersed",
      #TRUE ~ "Unknown",
      TRUE ~ NA_character_
    ),
    
    # Calendar Time
    study_week = difftime(covid_test_positive_date, 
                          study_dates$start_date,units="weeks") %>% 
      as.numeric() %>%
      floor(),
    
    # STP
    stp = as.factor(stp), 
    
    # SGTF
    sgtf = fct_case_when(
     is.na(sgtf) | sgtf == "" ~ "Unknown",
      sgtf == 1  ~ "Isolate with confirmed SGTF",
      sgtf == 0  ~ "S gene detected",
      sgtf == 9 ~ "Cannot be classified",
      #TRUE ~ "Unknown",
      TRUE ~ NA_character_
    ),
  
    # Time-between positive test and last vaccination
    tb_postest_vacc = 
      ifelse(!is.na(date_most_recent_cov_vac),
             difftime(covid_test_positive_date,
                      date_most_recent_cov_vac, units = "days") %>%
               as.numeric(),
             NA_integer_),
    
    tb_postest_vacc_cat = fct_case_when(
      is.na(tb_postest_vacc) ~ "Unknown",
      tb_postest_vacc < 7 ~ "< 7 days",
      tb_postest_vacc >=7 & tb_postest_vacc <28 ~ "7-27 days",
      tb_postest_vacc >= 28 & tb_postest_vacc <84 ~ "28-83 days",
      tb_postest_vacc >= 84 ~ ">= 84 days"
      ),
  )

################################################################################
# 3 Add exposure variables and outcomes
################################################################################
# Make list of 4 different data_processed; depending on when data analysis is
# started
# Treatment assignment window 'treated within 5 days -> <= 4 days' etc
treat_windows <- c(1, 2, 3, 4)
# List of processed data of all days
data_processed_list <- 
  map(.x = treat_windows,
      .f = ~ mutate(data_processed,
                    treat_window = 
                      covid_test_positive_date + days(.x)))
names(data_processed_list) <- paste0("day", treat_windows + 1)

# Add treatment variables and outcomes
data_processed_list <-
  map(data_processed_list,
      .f = ~ mutate(
        .x,
        # NEUTRALISING MONOCLONAL ANTIBODIES OR ANTIVIRALS ----              
        # Time-between positive test and day of treatment
        tb_postest_treat = 
          ifelse(!is.na(date_treated), 
                 difftime(date_treated, 
                          covid_test_positive_date,
                          units = "days") %>% as.numeric(),
                 NA_integer_),
        
        # Treatment strategy categories (regardless of treatment is in treat window)
        any_treatment_strategy_cat = 
          case_when(date_treated == sotrovimab_covid_therapeutics ~ "Sotrovimab",
                    date_treated == molnupiravir_covid_therapeutics ~ "Molnupiravir",
                    TRUE ~ "Untreated") %>% 
          factor(levels = c("Untreated", "Sotrovimab", "Molnupiravir")),
        
        # Flag records where treatment date falls in treatment assignment window
        treat_check = 
          ifelse(date_treated >= covid_test_positive_date & 
                   date_treated <= treat_window,
                 1,
                 0),
        
        # Flag records where treatment date falls after treat_windos
        treat_after_treat_window = 
          ifelse(date_treated >= covid_test_positive_date &
                   date_treated > treat_window,
                 1,
                 0),
        
        # Treatment strategy categories
        treatment_strategy_cat = 
          case_when(date_treated == sotrovimab_covid_therapeutics & 
                      treat_check == 1 ~ "Sotrovimab",
                    date_treated == molnupiravir_covid_therapeutics & 
                      treat_check == 1 ~ "Molnupiravir",
                    TRUE ~ "Untreated") %>% 
          factor(levels = c("Untreated", "Sotrovimab", "Molnupiravir")),
        
        # Treatment strategy overall
        treatment = 
          case_when((date_treated == sotrovimab_covid_therapeutics & 
                       treat_check == 1) |
                      (date_treated == molnupiravir_covid_therapeutics & 
                         treat_check == 1)  ~ "Treated",
                    TRUE ~ "Untreated") %>%
          factor(levels = c("Untreated", "Treated")),
        
        # Treatment date
        treatment_date = 
          ifelse(treatment == "Treated", date_treated, NA_Date_),
        
        # Identify patients treated with sot and mol on same day
        treated_sot_mol_same_day = 
          case_when(is.na(sotrovimab_covid_therapeutics) ~ 0,
                    is.na(molnupiravir_covid_therapeutics) ~ 0,
                    sotrovimab_covid_therapeutics == 
                      molnupiravir_covid_therapeutics ~ 1,
                    TRUE ~ 0),
        
        # Time-between symptom onset and treatment in those treated
        tb_symponset_treat = 
          case_when(is.na(date_treated) ~ NA_real_,
                    symptomatic_covid_test == "Y" ~ 
                      min(covid_test_positive_date,
                      covid_symptoms_snomed) %>%
                      difftime(., date_treated, units = "days") %>%
                      as.numeric()),
        ) %>%
        # because makes logic better readable
        rename(covid_death_date = died_ons_covid_any_date) %>%
        # add columns first admission in day 0-6, second admission etc. to be used
        # to define hospital admissions (hosp admissions for sotro treated are
        # different from the rest as sometimes their admission is just an admission
        # to get the sotro infusion)
        summarise_covid_admissions() %>%
        # adds column covid_hosp_admission_date
        add_covid_hosp_admission_outcome() %>%
        # idem as explained above for all cause hospitalisation
        summarise_allcause_admissions() %>%
        # adds column allcause_hosp_admission_date
        add_allcause_hosp_admission_outcome() %>%
        # add column allcause_hosp_diagnosis
        add_allcause_hosp_diagnosis() %>%
        mutate(
          # Outcome prep --> outcomes are added in add_*_outcome() functions below
          study_window = covid_test_positive_date + days(27),
          # make distinction between noncovid death and covid death, since noncovid
          # death is a censoring event and covid death is an outcome
          noncovid_death_date = 
            case_when(!is.na(death_date) & is.na(covid_death_date) ~ death_date,
                      TRUE ~ NA_Date_
          ),
          # make distinction between noncovid hosp admission and covid hosp
          # admission, non covid hosp admission is not used as a censoring event in
          # our study, but we'd like to report how many pt were admitted to the 
          # hospital for a noncovid-y reason before one of the other events
          noncovid_hosp_admission_date =
            case_when(!is.na(allcause_hosp_admission_date) &
                        is.na(covid_hosp_admission_date) ~
                        allcause_hosp_admission_date,
                      # both dates exist but are not the same
                      (!is.na(allcause_hosp_admission_date) &
                         !is.na(covid_hosp_admission_date)) &
                        allcause_hosp_admission_date < covid_hosp_admission_date ~
                        allcause_hosp_admission_date,
                      TRUE ~ NA_Date_),
        ) %>%
        # adds column status_all and fu_all 
        add_status_and_fu_all() %>%
        # adds column status_primary and fu_primary
        add_status_and_fu_primary() %>%
        # adds column status_secondary and fu_secondary
        add_status_and_fu_secondary() %>%
        # add treatment allocation for day 0 analysis 
        # for more info, see 
        # https://docs.google.com/document/d/1ZPLQ34C0SrXsIrBXy3j9iIlRCfnEEYbEUmgMBx6mv8U/edit#heading=h.sncyl4m0nk5s
        mutate(
          ## PRIMARY ##
          # Treatment strategy categories
          treatment_strategy_cat_day0_prim = case_when(
            covid_hosp_admission_date < date_treated ~ "Untreated",
            TRUE ~ treatment_strategy_cat %>% as.character()) %>% 
            factor(levels = c("Untreated",  "Sotrovimab", "Molnupiravir")),
          # Treatment strategy overall
          treatment_day0_prim = case_when(
            covid_hosp_admission_date < date_treated ~ "Untreated",
            TRUE ~ treatment %>% as.character()) %>% 
            factor(levels = c("Untreated", "Treated")),
          # Treatment date
          treatment_date_day0_prim = 
            ifelse(treatment_day0_prim == "Treated", date_treated, NA_Date_),
          ## SECONDARY ##
          # Treatment strategy categories
          treatment_strategy_cat_day0_sec = case_when(
            allcause_hosp_admission_date < date_treated ~ "Untreated",
            TRUE ~ treatment_strategy_cat %>% as.character()) %>% 
            factor(levels = c("Untreated", "Sotrovimab", "Molnupiravir")),
          # Treatment strategy overall
          treatment_day0_sec = case_when(
            allcause_hosp_admission_date < date_treated ~ "Untreated",
            TRUE ~ treatment %>% as.character()) %>% 
            factor(levels = c("Untreated", "Treated")),
          # Treatment date
          treatment_date_day0_sec = 
            ifelse(treatment_day0_sec == "Treated", date_treated, NA_Date_),
        )
      )
################################################################################
# 4 Apply additional eligibility and exclusion criteria
################################################################################
data_processed_eligible_list <- 
  data_processed_list %>%
  map(.x, 
      .f = ~ filter(
        .x,
        # Exclude patients treated with both sotrovimab and molnupiravir on the
        # same day 
        treated_sot_mol_same_day  == 0,
      )
  )

data_processed_eligible_day0 <- 
  data_processed_eligible_list$day5

# in the initial analysis, all patients with an outcome on day 0, 1, 2, 3, or 4,
# are excluded. 
# [FYI, secondary outcomes are 'dereg', 'allcause_hosp' or'allcause_death']
data_processed_eligible_list <-
  map2(.x = data_processed_eligible_list,
       .y = treat_windows,
       .f = ~ .x %>%
         filter(fu_secondary > .y) %>%
         mutate(fu_primary = fu_primary - {.y + 1},
                fu_secondary = fu_secondary - {.y + 1})) 
               # because starting at day .y + 1 (e.g. 5, 4, 3, 2)

################################################################################
# 5 Save data
################################################################################
# data_processed_eligible_day0 and data_processed_eligible_day2,3,4,5 are saved
write_rds(data_processed_eligible_day0,
          here::here("output", "data", 
                     paste0(
                       period[!period == "ba1"], "_"[!period == "ba1"],
                       "data_processed_day0.rds")
                     )
          )
iwalk(.x = data_processed_eligible_list,
      .f = ~ write_rds(.x,
                       here::here("output", "data",
                                  paste0(
                                    period[!period == "ba1"], "_"[!period == "ba1"],
                                    "data_processed_", .y, ".rds"))
                       )
      )
