######################################

# Cox models (propensity score analysis)
######################################

## Import libraries
library(tidyverse)
library(lubridate)
library(survival)
library(survminer)
library(gridExtra)
library(splines)
library(survey)

## Create figures directory
fs::dir_create(here::here("output", "figs"))

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

## Import data
if (data_label=="day5") {
  data_cohort <- read_rds(here::here("output", "data", "data_processed_day5.rds"))
} else {
  data_cohort <- read_rds(here::here("output", "data", "data_processed_day0.rds"))
}

## Vector of variables for PS model
# Note: age modelled with cubic spline with 3 knots
vars <- c("ns(age, df=4)", "sex", "ethnicity", "imdQ5" , "region_nhs", "rural_urban","huntingtons_disease_nhsd" , 
                "myasthenia_gravis_nhsd" , "motor_neurone_disease_nhsd" , "multiple_sclerosis_nhsd"  , "solid_organ_transplant_nhsd", 
                "hiv_aids_nhsd" , "immunosupression_nhsd" , "imid_nhsd" , "liver_disease_nhsd", "ckd_stage_5_nhsd", "haematological_disease_nhsd" , 
                "cancer_opensafely_snomed" , "downs_syndrome_nhsd", "diabetes", "bmi_group", "smoking_status", "copd", "dialysis", "cancer", 
                "lung_cancer", "haem_cancer", "vaccination_status", "pfizer_most_recent_cov_vac","az_most_recent_cov_vac", "moderna_most_recent_cov_vac"
)

## Fit propensity score model 
# Specify model
outcome <- "treatment"

psModelFunction <- as.formula(
  paste(outcome, 
        paste(vars, collapse = " + "), 
        sep = " ~ "))

# Check your model
print(psModelFunction)

# Fit PS model
psModel <- glm(psModelFunction,
               family  = binomial(link = "logit"),
               data    = data_cohort)

# Append patient-level predicted probability of being assigned to cohort
data_cohort$pscore <- predict(psModel, type = "response")

# Overlap plot 
overlapPlot <- data_cohort %>% 
  mutate(trtlabel = ifelse(treatment == "Treated",
                           yes = 'Treated',
                           no = 'Untreated')) %>%
  ggplot(aes(x = pscore, linetype = trtlabel)) +
  scale_linetype_manual(values=c("solid", "dotted")) +
  geom_density(alpha = 0.5) +
  xlab('Probability of receiving treatment') +
  ylab('Density') +
  scale_fill_discrete('') +
  scale_color_discrete('') +
  scale_x_continuous(breaks=seq(0, 1, 0.1)) +
  theme(strip.text = element_text(colour ='black')) +
  theme_bw() +
  theme(legend.title = element_blank()) +
  theme(legend.position = c(0.82,.8),
        legend.direction = 'vertical', 
        panel.background = element_rect(fill = "white", colour = "white"),
        axis.line = element_line(colour = "black"),
        panel.border = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

ggsave(overlapPlot, 
       filename = here::here("output", "figs", "overlap_plot.png"),
       width=20, height=14, units="cm")

## Dervie inverse probability of treatment weights (IPTW)
data_cohort$weights<-ifelse(data_cohort$treatment=="Treated",1/data_cohort$pscore,1/(1-data_cohort$pscore))


# Check extremes
quantile(data_cohort$weights[data_cohort$treatment=="Treated"],c(0,0.01,0.05,0.95,0.99,1))
quantile(data_cohort$weights[data_cohort$treatment=="Untreated"],c(0,0.01,0.05,0.95,0.99,1))


## Estimate treatment effect
iptw <- svydesign(ids = ~ 1, data = data_cohort, weights = ~ weights)

model_PSw <- svycoxph(Surv(fu_primary,status_primary=="covid_hosp_death")~treatment, design = iptw, data=data_cohort)
summary(model_PSw)
