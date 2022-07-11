######################################

# Treatment distributions
######################################

## Import libraries
library(tidyverse)
library(lubridate)
library(here)

## Create figures directory
fs::dir_create(here::here("output", "figs"))
## Create tables directory
fs::dir_create(here::here("output", "tables"))

## Import command-line arguments
args <- commandArgs(trailingOnly=TRUE)

## Set input and output pathways for matched/unmatched data - default is unmatched
if (length(args) == 0){
  data_label = "day5"
} else if (args[[1]] == "day0") {
  data_label = "day0"
} else if (args[[1]] == "day5") {
  data_label = "day5"
} else {
  # Print error if no argument specified
  stop("No outcome specified")
}

## Import data
if (data_label == "day5") {
  data_cohort <- 
    read_rds(here::here("output", "data", "data_processed_day5.rds"))
} else if (data_label == "day0") {
  data_cohort <-
    read_rds(here::here("output", "data", "data_processed_day0.rds"))
}

## Restrict to patients treated 
d_trt <- data_cohort %>%
  filter(treatment_strategy_cat != "Untreated") %>% 
  select(treatment_strategy_cat, tb_postest_treat) 

## Plot treatment distributions by group
q <- d_trt %>% 
ggplot( 
  aes(x=tb_postest_treat, 
      y=..density.., 
      fill=treatment_strategy_cat)) +
  geom_histogram(color="#e9ecef",
                 alpha=0.8, 
                 position = 'identity', 
                 binwidth = 1) +
  scale_fill_manual(values=c("#E69F00", "#0072B2")) +
  scale_x_continuous(limits = c(0, 4)) + 
  labs(fill="Treatment") +
  xlab("Time-between positive test and treatment (days)") +
  ylab("Density") +
  labs(color='Treatment') +
  theme_bw()

# Save plot
ggsave(q, 
       filename = 
         here("output", "figs", 
              paste0(data_label, "_treatment_pattern.png")),
       width=20, height=14, units="cm")



