#######
## Function to clean table names
clean_table_names = function(input_table) {
  # Relabel variables for plotting
  #input_table$Variable[input_table$Variable=="diabetes"] = "Diabetes"
  
  # Relabel groups for plotting
  # demographics
  input_table$Group[input_table$Group=="ageband"] = "Age"
  input_table$Group[input_table$Group=="sex"] = "Sex"
  input_table$Group[input_table$Group=="ethnicity"] = "Ethnicity"
  input_table$Group[input_table$Group=="imdQ5"] = "IMD"
  input_table$Group[input_table$Group=="region_nhs"] = "Region"
  input_table$Group[input_table$Group=="rural_urban"] = "Setting"
  # clinical characteristics
  input_table$Group[input_table$Group=="obese"] = "Obesity"
  input_table$Group[input_table$Group=="smoking_status"] = "Smoking status"
  input_table$Group[input_table$Group=="diabetes"] = "Diabetes"
  input_table$Group[input_table$Group=="chronic_cardiac_disease"] = "Chronic Cardiac Disease"
  input_table$Group[input_table$Group=="copd"] = "COPD"
  input_table$Group[input_table$Group=="dialysis"] = "Dialysis"
  input_table$Group[input_table$Group=="serious_mental_illness_nhsd"] = "Severe mental illness"
  input_table$Group[input_table$Group=="learning_disability_primis"] = "Learning disability"
  input_table$Group[input_table$Group=="dementia_nhsd"] = "Dementia"
  input_table$Group[input_table$Group=="autism_nhsd"] = "Autism"
  input_table$Group[input_table$Group=="care_home_primis"] = "Care home"
  input_table$Group[input_table$Group=="housebound_opensafely"] = "Housebound"
  # high risk groups
  input_table$Group[input_table$Group=="downs_syndrome_nhsd"] = "Down's syndrome"
  input_table$Group[input_table$Group=="cancer_opensafely_snomed_new"] = "Solid cancer"
  input_table$Group[input_table$Group=="haematological_disease_nhsd"] = "Haematological diseases"
  input_table$Group[input_table$Group=="ckd_stage_5_nhsd"] = "Renal disease"
  input_table$Group[input_table$Group=="liver_disease_nhsd"] = "Liver disease"
  input_table$Group[input_table$Group=="imid_nhsd"] = "Immune-mediated inflammatory disorders (IMID)"
  input_table$Group[input_table$Group=="immunosupression_nhsd_new"] = "Immune deficiencies"
  input_table$Group[input_table$Group=="hiv_aids_nhsd"] = "HIV/AIDs"
  input_table$Group[input_table$Group=="solid_organ_transplant_nhsd_new"] = "Solid organ transplant"
  input_table$Group[input_table$Group=="multiple_sclerosis_nhsd"] = "Multiple sclerosis"
  input_table$Group[input_table$Group=="motor_neurone_disease_nhsd"] = "Motor neurone disease"
  input_table$Group[input_table$Group=="myasthenia_gravis_nhsd"] = "Myasthenia gravis"
  input_table$Group[input_table$Group=="huntingtons_disease_nhsd"] = "Huntington’s disease"
  # vax vars
  input_table$Group[input_table$Group=="vaccination_status"] = "Vaccination status"
  input_table$Group[input_table$Group=="tb_postest_vacc_cat"] = "Time-between test since last vaccination"
  input_table$Group[input_table$Group=="most_recent_vax_cat"] = "Most recent vaccination"
  input_table$Group[input_table$Group=="pfizer_most_recent_cov_vac"] = "Pfizer"
  input_table$Group[input_table$Group=="az_most_recent_cov_vac"] = "AstraZeneca"
  input_table$Group[input_table$Group=="moderna_most_recent_cov_vac"] = "Moderna"
  #else
  input_table$Group[input_table$Group=="tb_postest_treat"] = "Time-between test and treatment"
  input_table$Group[input_table$Group=="treatment_strategy_cat"] = "Treatment group"
  input_table$Group[input_table$Variable=="N"] = "N"
  return(input_table)
}
