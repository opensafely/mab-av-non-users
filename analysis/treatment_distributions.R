######################################

# Treatment distributions
######################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(lubridate)
library(here)

################################################################################
# 0.1 Create directories for output
################################################################################
## Create figures directory
fs::dir_create(here::here("output", "figs"))
## Create tables directory
fs::dir_create(here::here("output", "tables"))
## Create tables directory
fs::dir_create(here::here("output", "data_properties"))

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly=TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
} else if (args[[1]] == "ba1") {
  period = "ba1"
} else if (args[[1]] == "ba2") {
  period = "ba2"
} else {
  # Print error if no argument specified
  stop("No period specified")
}
# Set input data to day5 or day0 data, default is day5
if (length(args) == 0){
  data_label = "day5"
} else if (args[[2]] == "day0") {
  data_label = "day0"
} else if (args[[2]] == "day5") {
  data_label = "day5"
} else {
  # Print error if no argument specified
  stop("No day specified")
}

################################################################################
# 0.3 Import data
################################################################################
data_filename <-
  paste0(period[!period == "ba1"], "_"[!period == "ba1"],
         "data_processed_", data_label, ".rds")
data_cohort <-
  read_rds(here::here("output", "data", data_filename))
#Restrict to patients treated
d_trt <- data_cohort %>%
  filter(treatment_strategy_cat != "Untreated") %>% 
  select(treatment_strategy_cat, tb_postest_treat) 

################################################################################
# 1. Make a table with n treated per day
################################################################################
data_cohort %>%
  filter(any_treatment_strategy_cat != "Untreated" & 
           tb_postest_treat %>% between(0, 6)) %>%
  group_by(tb_postest_treat, any_treatment_strategy_cat) %>%
  summarise(n = n(), .groups = "keep") %>% 
  mutate(n = case_when(n %>% between(1, 7) ~ "[REDACTED]",
                       TRUE ~ n %>% plyr::round_any(5) %>% as.character())) %>%
  write_csv(here::here("output", "data_properties", 
                       paste0(period[!period == "ba1"], "_"[!period == "ba1"],
                              data_label,
                              "_n_treated_day.csv")))
d_trt$treatment_strategy_cat %>% table() %>% print()

################################################################################
# 2. Plot treatment distributions by group
################################################################################
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
  scale_x_continuous(limits = c(-1, 5)) + 
  labs(fill="Treatment") +
  xlab("Time-between positive test and treatment (days)") +
  ylab("Density") +
  labs(color='Treatment') +
  theme_bw()

# Save plot
ggsave(q, 
       filename = 
         here("output", "figs", 
              paste0(period[!period == "ba1"], "_"[!period == "ba1"],
                     data_label, "_treatment_pattern.png")),
       width=20, height=14, units="cm")
