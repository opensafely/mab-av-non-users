library('splines')
covars_formula <-
  c("ns(age, df = 3)",
    "sex",
    "ethnicity",
    "imdQ5",
    "rural_urban",
    "stp",
    # other comorbidities/clinical characteristics
    "smoking_status",
    "chronic_cardiac_disease",
    "copd",
    "obese",
    "dialysis",
    "serious_mental_illness_nhsd",
    "learning_disability_primis",
    "dementia_nhsd",
    "diabetes",
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
    "ns(tb_postest_vacc, df = 3)",
    "pfizer_most_recent_cov_vac",
    "az_most_recent_cov_vac",
    "moderna_most_recent_cov_vac",
    # calendar time
    "ns(study_week, df = 3)")