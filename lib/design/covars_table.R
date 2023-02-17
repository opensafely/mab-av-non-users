covars <- 
  c("ageband",
    "sex",
    "ethnicity",
    "imdQ5",
    "region_nhs",
    "rural_urban",
    # other comorbidities/clinical characteristics
    "obese",
    "smoking_status",
    "diabetes",
    "chronic_cardiac_disease",
    "copd",
    "dialysis",
    "serious_mental_illness_nhsd",
    "learning_disability_primis",
    "dementia_nhsd",
    "autism_nhsd",
    "care_home_primis",
    "housebound_opensafely",
    # high risk group
    "downs_syndrome_nhsd",
    "cancer_opensafely_snomed_new", # non-overlapping
    "haematological_disease_nhsd",
    "ckd_stage_5_nhsd", 
    "liver_disease_nhsd", 
    "imid_nhsd",
    "immunosupression_nhsd_new", # non-overlapping
    "hiv_aids_nhsd",
    "solid_organ_transplant_nhsd_new", # non-overlapping
    "multiple_sclerosis_nhsd", 
    "motor_neurone_disease_nhsd",
    "myasthenia_gravis_nhsd",
    "huntingtons_disease_nhsd",
    # vax vars
    "vaccination_status",
    "tb_postest_vacc_cat",
    "most_recent_vax_cat")