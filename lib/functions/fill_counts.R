source(here::here("lib", "functions", "redact_and_round_subtotals.R"))

fill_counts_n <- function(counts_n, data){
  n <- data %>% nrow()
  n_untreated <- data %>% filter(treatment == "Untreated") %>% nrow()
  n_treated <- data %>% filter(treatment == "Treated") %>% nrow()
  counts_n[, c("n", "n_untreated", "n_treated")] <- 
    redact_and_round_subtotals(n, n_untreated, n_treated)[1:3]
  n_mol <- data %>% filter(treatment_strategy_cat == "Molnupiravir") %>% nrow()
  n_sot <- data %>% filter(treatment_strategy_cat == "Sotrovimab") %>% nrow()
  counts_n[, c("n_mol", "n_sot")] <- 
    redact_and_round_subtotals(counts_n$n_treated, n_mol, n_sot)[2:3]
  counts_n <-
    counts_n %>%
    mutate(across(everything(), ~ as.character(.x)))
  return(counts_n)
}

fill_counts_n_outcome_primary <- function(counts_n_outcome, data){
  n_outcome <- data %>% 
    filter(status_primary == "covid_hosp_death") %>% nrow()
  n_outcome_untreated <- data %>%
    filter(treatment == "Untreated",
           status_primary == "covid_hosp_death") %>% nrow()
  n_outcome_treated <- data %>%
    filter(treatment == "Treated",
           status_primary == "covid_hosp_death") %>% nrow()
  counts_n_outcome[, c("n_outcome", "n_outcome_untreated", "n_outcome_treated")] <-
    redact_and_round_subtotals(n_outcome, n_outcome_untreated, n_outcome_treated)[1:3]
  n_outcome_mol <- data %>%
    filter(treatment_strategy_cat == "Molnupiravir",
           status_primary == "covid_hosp_death") %>% nrow()
  n_outcome_sot <- data %>%
    filter(treatment_strategy_cat == "Sotrovimab",
           status_primary == "covid_hosp_death") %>% nrow()
  counts_n_outcome[, c("n_outcome_mol", "n_outcome_sot")] <- 
    redact_and_round_subtotals(counts_n_outcome$n_outcome_treated, n_outcome_sot,
                               n_outcome_mol)[2:3]
  counts_n_outcome <-
    counts_n_outcome %>%
    mutate(across(everything(), ~ as.character(.x)))
  return(counts_n_outcome)
}
