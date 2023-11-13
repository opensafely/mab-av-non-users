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
  n_treated_rem <- 
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
               fu_all == 0)) %>%
    filter(!is.na(remdesivir_covid_therapeutics) & is.na(paxlovid_covid_therapeutics)) %>%
    nrow()
  n_treated_pax <- 
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
             fu_all == 0)) %>%
    filter(!is.na(paxlovid_covid_therapeutics) & is.na(remdesivir_covid_therapeutics)) %>%
    nrow()
  n_treated_rem_and_pax <- 
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
               fu_all == 0)) %>%
    filter(!is.na(paxlovid_covid_therapeutics) & !is.na(remdesivir_covid_therapeutics)) %>%
    nrow()
  n_after_exclusion_processing <- 
    data_processed %>%
    # Exclude patients treated with both sotrovimab and molnupiravir on the
    # same day 
    filter(treated_sot_mol_same_day  == 0) %>%
    # Exclude patients hospitalised on day of positive test
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
               fu_all == 0)) %>%
    # if treated with paxlovid or remidesivir --> exclude
    filter(is.na(paxlovid_covid_therapeutics) &
             is.na(remdesivir_covid_therapeutics)) %>% nrow()
  out <- tibble(n_before_exclusion_processing,
                n_treated_same_day,
                n_hospitalised_pos_test,
                n_treated_rem,
                n_treated_pax,
                n_treated_rem_and_pax,
                n_after_exclusion_processing)
}