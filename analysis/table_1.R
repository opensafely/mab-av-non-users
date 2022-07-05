######################################

# This script 
# - produces a table summarising selected clinical and demographic characteristics 
# - saves table as html

######################################

## Import libraries
library('tidyverse')
library('here')
library('glue')
library('gt')
library('gtsummary')
library('plyr')
library('reshape2')

## Import command-line arguments
args <- commandArgs(trailingOnly=TRUE)

## Set input and output pathways for matched/unmatched data - default is unmatched
if (args[[1]]=="day0") {
    data_label = "day0"
  } else if (args[[1]]=="day5") {
    data_label = "day5"
  } else {
    # Print error if no argument specified
    stop("No outcome specified")
  }


## Set rounding and redaction thresholds
rounding_threshold = 1
redaction_threshold = 10

data_label = "day0"

## Import data
if (data_label=="day0") {
  data_cohort <- read_rds(here::here("output", "data", "data_processed_day0.rds"))
} else {
  data_cohort <- read_rds(here::here("output", "data", "data_processed_day5.rds"))
}

## Format data
data_cohort <- data_cohort %>%
  mutate(
    N = 1,
    allpop = "All"
  ) 

## Define variables of interest
counts <- data_cohort %>% 
  select(
    N,
    allpop,
    treatment_strategy_cat,
    
    ## Demographics
    ageband,
    sex,
    ethnicity,
    bmi_group,
    imdQ5,
    smoking_status,
  
    ## Clinical
    diabetes,
    copd,
    dialysis,
    cancer,
    lung_cancer,
    haem_cancer,
    
    ## Vaccination
    vaccination_status,
    
    ## Variant
    variant,
    sgtf,
    
    ## High risk groups
    high_risk_cohort_covid_therapeutics,
    
    ## Geography
    region_nhs,
    rural_urban
  ) 

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

## Generate full and stratified table
pop_levels = c("All", "Molnupiravir", "Sotrovimab", "Untreated")

## Generate table - full and stratified populations
for (i in 1:length(pop_levels)) {
  
  if (i == 1) { 
    data_subset = counts
    counts_summary = data_subset %>% 
      select(-treatment_strategy_cat) %>% 
      tbl_summary(by = allpop) 
    counts_summary$inputs$data <- NULL
  } else { 
    data_subset = subset(counts, treatment_strategy_cat==pop_levels[i]) 
    counts_summary = data_subset %>% 
      select(-treatment_strategy_cat) %>% 
      tbl_summary(by = allpop)
    counts_summary$inputs$data <- NULL
  }
  
  table1 <- counts_summary$table_body %>%
    select(group = variable, variable = label, count = stat_1) %>%
    separate(count, c("count","perc"), sep = "([(])") %>%
    mutate(count = gsub(" ", "", count)) %>%
    mutate(count = as.numeric(gsub(",", "", count))) %>%
    filter(!(is.na(count))) %>%
    select(-perc)
  table1$percent = round(table1$count/nrow(data_cohort)*100,1)
  colnames(table1) = c("Group", "Variable", "Count", "Percent")
  
  ## Clean names
  table1_clean = clean_table_names(table1)
  
  ## Calculate rounded total
  rounded_n = plyr::round_any(nrow(data_subset), rounding_threshold)
  
  ## Round individual values to rounding threshold
  table1_redacted <- table1_clean %>%
    mutate(Count = plyr::round_any(Count, rounding_threshold))
  table1_redacted$Percent = round(table1_redacted$Count/rounded_n*100,1)
  table1_redacted$Non_Count = rounded_n - table1_redacted$Count
  
  ## Redact any rows with rounded cell counts or non-counts <= redaction threshold 
  table1_redacted$Summary = paste0(prettyNum(table1_redacted$Count, big.mark=",")," (",format(table1_redacted$Percent,nsmall=1),"%)")
  table1_redacted$Summary = gsub(" ", "", table1_redacted$Summary, fixed = TRUE) # Remove spaces generated by decimal formatting
  table1_redacted$Summary = gsub("(", " (", table1_redacted$Summary, fixed = TRUE) # Add first space before (
  table1_redacted$Summary[(table1_redacted$Count>0 & table1_redacted$Count<=redaction_threshold) | (table1_redacted$Non_Count>0 & table1_redacted$Non_Count<=redaction_threshold)] = "[Redacted]"
  table1_redacted$Summary[table1_redacted$Variable=="N"] = prettyNum(table1_redacted$Count[table1_redacted$Variable=="N"], big.mark=",")
  table1_redacted <- table1_redacted %>% select(-Non_Count, -Count, -Percent)
  names(table1_redacted)[3] = pop_levels[i]
  
  if (i==1) { 
    collated_table = table1_redacted 
  } else { 
    collated_table = collated_table %>% left_join(table1_redacted[,2:3], by ="Variable") 
    collated_table[,i+2][is.na(collated_table[,i+2])] = "--"
  }
}

## Create output directory
fs::dir_create(here::here("output", "tables"))

## Save as html/rds
if (data_label=="day0") {
  gt::gtsave(gt(collated_table), here::here("output","tables", "table1_redacted_day0.html"))
  write_rds(collated_table, here::here("output", "tables", "table1_redacted_day0.rds"), compress = "gz")
} else {
  gt::gtsave(gt(collated_table), here::here("output","tables", "table1_redacted_day5.html"))
  write_rds(collated_table, here::here("output", "tables", "table1_redacted_day5.rds"), compress = "gz")
}