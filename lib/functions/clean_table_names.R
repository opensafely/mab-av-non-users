#######
## Function to clean table names
clean_table_names = function(input_table) {
  input_table %>%
    mutate(
      group = case_when(group == "ageband" ~ "Age",
                        group == "sex" ~ "Sex",
                        group == "ethnicity" ~ "Ethnicity",
                        group == "imdQ5" ~ "IMD",
                        group == "region_nhs" ~ "Region",
                        group == "rural_urban" ~ "Setting",
                        # clinical vars
                        group == "obese" ~ "Obesity",
                        group == "smoking_status" ~ "Smoking status",
                        group == "diabetes" ~ "Diabetes",
                        group == "hypertension" ~ "Hypertension",
                        group == "chronic_cardiac_disease" ~ "Chronic Cardiac Disease",
                        group == "copd" ~ "COPD",
                        group == "dialysis" ~ "Dialysis",
                        group == "serious_mental_illness_nhsd" ~ "Severe mental illness",
                        group == "learning_disability_primis" ~ "Learning disability",
                        group == "dementia_nhsd" ~ "Dementia",
                        group == "autism_nhsd" ~ "Autism",
                        group == "care_home_primis" ~ "Care home",
                        group == "housebound_opensafely" ~ "Housebound",
                        # high risk group
                        group == "downs_syndrome_nhsd" ~ "Down's syndrome",
                        group == "cancer_opensafely_snomed_new" ~ "Solid cancer",
                        group == "haematological_disease_nhsd" ~ "Haematological diseases",
                        group == "ckd_stage_5_nhsd" ~ "CKD stage 5",
                        group == "liver_disease_nhsd" ~ "Liver disease",
                        group == "imid_nhsd" ~ "Immune-mediated inflammatory disorders (IMID)",
                        group == "immunosupression_nhsd_new" ~ "Immune deficiencies",
                        group == "hiv_aids_nhsd" ~ "HIV/AIDs",
                        group == "solid_organ_transplant_nhsd_new" ~ "Solid organ transplant",
                        group == "multiple_sclerosis_nhsd" ~ "Multiple sclerosis",
                        group == "motor_neurone_disease_nhsd" ~ "Motor neurone disease",
                        group == "myasthenia_gravis_nhsd" ~ "Myasthenia gravis",
                        group == "huntingtons_disease_nhsd" ~ "Huntington's disease",
                        # vax vars
                        group == "vaccination_status" ~ "Vaccination status",
                        group == "tb_postest_vacc_cat" ~ "Time-between test since last vaccination",
                        group == "most_recent_vax_cat" ~ "Most recent vaccination",
                        group == "pfizer_most_recent_cov_vac" ~ "Pfizer",
                        group == "az_most_recent_cov_vac" ~ "AstraZeneca",
                        group == "moderna_most_recent_cov_vac" ~ "Moderna",
                        TRUE ~ group))
}