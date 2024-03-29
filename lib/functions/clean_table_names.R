#######
## Function to clean table names
clean_table_names = function(input_table) {
  # Relabel variables for plotting
  #input_table$Variable[input_table$Variable=="diabetes"] = "Diabetes"
  
  # Relabel groups for plotting
  input_table$Group[input_table$Group=="ageband"] = "Age"
  input_table$Group[input_table$Group=="tb_postest_treat"] = "Time-between test and treatment"
  input_table$Group[input_table$Group=="treatment_strategy_cat"] = "Treatment group"
  input_table$Group[input_table$Group=="sex"] = "Sex"
  input_table$Group[input_table$Group=="ethnicity"] = "Ethnicity"
  input_table$Group[input_table$Group=="bmi_group"] = "BMI categorised"
  input_table$Group[input_table$Group=="imdQ5"] = "IMD"
  input_table$Group[input_table$Group=="smoking_status"] = "Smoking status"
  input_table$Group[input_table$Group=="diabetes"] = "Diabetes"
  input_table$Group[input_table$Group=="copd"] = "COPD"
  input_table$Group[input_table$Group=="dialysis"] = "Dialysis"
  input_table$Group[input_table$Group=="cancer"] = "Cancer"
  input_table$Group[input_table$Group=="lung_cancer"] = "Lung cancer"
  input_table$Group[input_table$Group=="haem_cancer"] = "Haematological cancer"
  input_table$Group[input_table$Group=="high_risk_cohort_covid_therapeutics"] = "High risk groups"
  input_table$Group[input_table$Group=="high_risk_group"] = "Member of high risk group"
  input_table$Group[input_table$Group=="vaccination_status"] = "Vaccination status"
  input_table$Group[input_table$Group=="variant"] = "Variant"
  input_table$Group[input_table$Group=="sgtf"] = "SGTF"
  input_table$Group[input_table$Group=="rural_urban"] = "Setting"
  input_table$Group[input_table$Group=="region_nhs"] = "Region"
  input_table$Group[input_table$Group=="tb_postest_vacc_cat"] = "Time-between test since last vaccination"
  input_table$Group[input_table$Group=="huntingtons_disease_nhsd"] = "Huntington’s disease"
  input_table$Group[input_table$Group=="myasthenia_gravis_nhsd"] = "Myasthenia gravis"
  input_table$Group[input_table$Group=="motor_neurone_disease_nhsd"] = "Motor neurone disease"
  input_table$Group[input_table$Group=="multiple_sclerosis_nhsd"] = "Multiple sclerosis"
  input_table$Group[input_table$Group=="solid_organ_transplant_new"] = "Solid organ transplant"
  input_table$Group[input_table$Group=="hiv_aids_nhsd"] = "HIV/AIDs"
  input_table$Group[input_table$Group=="immunosupression_new"] = "Immune deficiencies"
  input_table$Group[input_table$Group=="imid_nhsd"] = "Immune-mediated inflammatory disorders (IMID)"
  input_table$Group[input_table$Group=="liver_disease_nhsd"] = "Liver disease"
  input_table$Group[input_table$Group=="ckd_stage_5_nhsd"] = "Renal disease"
  input_table$Group[input_table$Group=="haematological_disease_nhsd"] = "Haematological diseases"
  input_table$Group[input_table$Group=="non_haem_cancer_new"] = "Solid cancer"
  input_table$Group[input_table$Group=="downs_syndrome_nhsd"] = "Down's syndrome"
  input_table$Group[input_table$Group=="autism_nhsd"] = "Autism"
  input_table$Group[input_table$Group=="care_home_primis"] = "Care home"
  input_table$Group[input_table$Group=="dementia_nhsd"] = "Dementia"
  input_table$Group[input_table$Group=="housebound_opensafely"] = "Housebound"
  input_table$Group[input_table$Group=="serious_mental_illness_nhsd"] = "Severe mental illness"
  input_table$Group[input_table$Variable=="N"] = "N"
  return(input_table)
}
