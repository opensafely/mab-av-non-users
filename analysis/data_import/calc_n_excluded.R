calc_n_excluded <- function(data_processed){
  n_before_exclusion_processing <- 
    data_processed %>%
    nrow()
  n_treated_same_day <- 
    data_processed %>%
    filter(treated_sot_mol_same_day != 0) %>%
    nrow()
  n_hospitalised_pos_test <-
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(status_all %in% c("covid_hosp", "noncovid_hosp") &
             fu_all == 0) %>%
    nrow()
  n_treated_pax_rem <- 
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
             fu_all == 0)) %>%
    filter(!is.na(paxlovid_covid_therapeutics) |
             !is.na(remdesivir_covid_therapeutics))
  out <- tibble(n_before_exclusion_processing,
                n_treated_same_day,
                n_hospitalised_pos_test,
                n_treated_pax_rem)
}