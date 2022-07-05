#######
## Function to clean table names
clean_table_names = function(input_table) {
  # Relabel variables for plotting
  #input_table$Variable[input_table$Variable=="diabetes"] = "Diabetes"
  
  # Relabel groups for plotting
  input_table$Group[input_table$Group=="ageband"] = "Age"
  input_table$Group[input_table$Group=="treatment_strategy_cat"] = "Treatment Group"
  input_table$Group[input_table$Group=="sex"] = "Sex"
  input_table$Group[input_table$Group=="ethnicity"] = "Ethnicity"
  input_table$Group[input_table$Group=="bmi_group"] = "BMI categorised"
  input_table$Group[input_table$Group=="imdQ5"] = "IMD"
  input_table$Group[input_table$Group=="smoking_status"] = "Smoking Status"
  input_table$Group[input_table$Group=="diabetes"] = "Diabetes"
  input_table$Group[input_table$Group=="copd"] = "COPD"
  input_table$Group[input_table$Group=="dialysis"] = "Dialysis"
  input_table$Group[input_table$Group=="cancer"] = "Cancer"
  input_table$Group[input_table$Group=="lung_cancer"] = "Lung Cancer"
  input_table$Group[input_table$Group=="haem_cancer"] = "Haematological Cancer"
  input_table$Group[input_table$Group=="high_risk_cohort_covid_therapeutics"] = "High Risk Groups"
  input_table$Group[input_table$Group=="vaccination_status"] = "Vaccination Status"
  input_table$Group[input_table$Group=="variant"] = "Variant"
  input_table$Group[input_table$Group=="sgtf"] = "SGTF"
  input_table$Group[input_table$Group=="rural_urban"] = "Setting"
  input_table$Group[input_table$Group=="region_nhs"] = "Region"
  
  
  input_table$Group[input_table$Variable=="N"] = "N"
  return(input_table)
}
