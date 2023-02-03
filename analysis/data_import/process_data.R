# load libraries
source(here::here("lib", "functions", "fct_case_when.R"))
source(here::here("lib", "functions", "define_covid_hosp_admissions.R"))
source(here::here("lib", "functions", "define_allcause_hosp_admissions.R"))
source(here::here("lib", "functions", "define_allcause_hosp_diagnosis.R"))
source(here::here("lib", "functions", "define_status_and_fu_all.R"))
source(here::here("lib", "functions", "define_status_and_fu_primary.R"))
source(here::here("lib", "functions", "define_status_and_fu_secondary.R"))
# function
process_data <- function(data_extracted){
  data_processed <- data_extracted %>%
    mutate(
      # COVARIATES -----
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
        TRUE ~ NA_character_),
      
      bmi_group = fct_case_when(
        bmi == "Not obese" ~ "Not obese",
        bmi %in% c("Obese I (30-34.9)",
                   "Obese II (35-39.9)",
                   "Obese III (40+)") ~ "Obese",
        TRUE ~ NA_character_),
      
      smoking_status = fct_case_when(
        smoking_status == "S" ~ "Smoker",
        smoking_status == "E" ~ "Ever",
        smoking_status == "N" ~ "Never",
        smoking_status == "M" ~ "Unknown"),
      
      smoking_status_comb = fct_case_when(
        smoking_status %in% c("N", "M") ~ "Never and unknown",
        smoking_status == "E" ~ "Former",
        smoking_status == "S" ~ "Current",
        TRUE ~ NA_character_
      ),
      
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
        TRUE ~ "Unknown"),
      
      # Rural/urban
      rural_urban = fct_case_when(
        rural_urban %in% c(1:2) ~ "Urban - conurbation",
        rural_urban %in% c(3:4) ~ "Urban - city and town",
        rural_urban %in% c(5:6) ~ "Rural - town and fringe",
        rural_urban %in% c(7:8) ~ "Rural - village and dispersed"
      ),
      
      # STP
      stp = as.factor(stp), 
      
      # Calendar Time
      study_week = difftime(
        covid_test_positive_date,
        study_dates$start_date,
        units = "weeks") %>% 
        as.numeric() %>%
        floor(),
      
      # SGTF
      sgtf = fct_case_when(
        is.na(sgtf) | sgtf == "" ~ NA_character_,
        sgtf == 1  ~ "Isolate with confirmed SGTF",
        sgtf == 0  ~ "S gene detected",
        sgtf == 9 ~ "Cannot be classified",
        TRUE ~ NA_character_
      ),
      
      # Time-between positive test and last vaccination
      tb_postest_vacc = 
        if_else(!is.na(date_most_recent_cov_vac),
                difftime(covid_test_positive_date,
                         date_most_recent_cov_vac, units = "days") %>%
                  as.numeric(),
                NA_real_),
      
      tb_postest_vacc_cat = fct_case_when(
        is.na(tb_postest_vacc) ~ "Unknown",
        tb_postest_vacc < 7 ~ "< 7 days",
        tb_postest_vacc >=7 & tb_postest_vacc < 28 ~ "7-27 days",
        tb_postest_vacc >= 28 & tb_postest_vacc < 84 ~ "28-83 days",
        tb_postest_vacc >= 84 ~ ">= 84 days"
      ),
      
      # TREATMENT ----              
      # Time-between positive test and day of treatment
      tb_postest_treat = 
        if_else(!is.na(date_treated), 
                difftime(date_treated, 
                         covid_test_positive_date, units = "days") %>%
                  as.numeric(),
               NA_real_),
      
      # treatment window
      treat_window = covid_test_positive_date + days(4),
      
      # Treatment strategy categories
      # (regardless of treatment is in treat window)
      any_treatment_strategy_cat = 
        case_when(date_treated == 
                    sotrovimab_covid_therapeutics ~ "Sotrovimab",
                  date_treated == 
                    molnupiravir_covid_therapeutics ~ "Molnupiravir",
                  TRUE ~ "Untreated") %>% 
        factor(levels = c("Untreated", "Sotrovimab", "Molnupiravir")),
      
      any_treatment_date =
        if_else(any_treatment_strategy_cat != "Untreated",
                date_treated,
                NA_Date_),
      
      # Flag records where treatment date falls in treatment assignment window
      treat_check = 
        if_else(date_treated >= covid_test_positive_date & 
                  date_treated <= treat_window,
                1,
                0),
      
      # Flag records where treatment date falls after treat_windows
      treat_after_treat_window = 
        if_else(date_treated >= covid_test_positive_date &
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
        if_else(treatment == "Treated",
                date_treated,
                NA_Date_),
      
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
      # of note, patients can have allcause hosp before or after covid hosp, 
      # so the number of noncovid_hosp + covid_hosp is not strictly the number
      # of allcause_hosp
      noncovid_hosp_admission_date = 
        if_else(allcause_hosp_admission_date != covid_hosp_admission_date,
                allcause_hosp_admission_date,
                NA_Date_),
    ) %>%
    # adds column status_all and fu_all 
    add_status_and_fu_all() %>%
    # adds column status_primary and fu_primary
    add_status_and_fu_primary() %>%
    # adds column status_secondary and fu_secondary
    add_status_and_fu_secondary() %>%
    # some patients experience one of our outcomes (prim outcome/ sec outcome) 
    # on or before day of treatment --> if so, patients will be categorised as 
    # untreated
    # for more info, see 
    # https://docs.google.com/document/d/1ZPLQ34C0SrXsIrBXy3j9iIlRCfnEEYbEUmgMBx6mv8U/edit#heading=h.sncyl4m0nk5s
    mutate(
      ## PRIMARY ##
      # Treatment strategy categories
      treatment_strategy_cat_prim = 
        if_else(status_primary %in% 
                  c("covid_hosp_death", "noncovid_death", "dereg") &
                  treatment == "Treated" &
                  min_date_primary <= treatment_date,
                "Untreated",
                treatment_strategy_cat %>% as.character()) %>%
        factor(levels = c("Untreated",  "Sotrovimab", "Molnupiravir")),
      # Treatment strategy overall
      treatment_prim =
        if_else(treatment_strategy_cat_prim == "Untreated",
                "Untreated",
                "Treated") %>%
        factor(levels = c("Untreated", "Treated")),
      # Treatment date
      treatment_date_prim = 
        ifelse(treatment_prim == "Treated", treatment_date, NA_Date_),
      ## SECONDARY ##
      # Treatment strategy categories
      treatment_strategy_cat_sec = 
        if_else(status_secondary %in% 
                  c("allcause_hosp_death", "dereg") &
                  treatment == "Treated" &
                  min_date_secondary <= treatment_date,
                "Untreated",
                treatment_strategy_cat %>% as.character()) %>%
        factor(levels = c("Untreated",  "Sotrovimab", "Molnupiravir")),
      # Treatment strategy overall
      treatment_sec =
        if_else(treatment_strategy_cat_sec == "Untreated",
                "Untreated",
                "Treated") %>%
        factor(levels = c("Untreated", "Treated")),
      # Treatment date
      treatment_date_sec = 
        ifelse(treatment_sec == "Treated", date_treated, NA_Date_),
    )
}