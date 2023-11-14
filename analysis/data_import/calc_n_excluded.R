calc_n_excluded <- function(data_processed){
  n_before_exclusion_processing <- 
    data_processed %>%
    nrow()
  n_treated_same_day <- 
    data_processed %>%
    filter(treated_sot_mol_same_day != 0) %>%
    nrow()
  n_pax_same_day_as_sot_mol <-
    data_processed %>%
    filter(treated_sot_mol_same_day == 0) %>%
    filter(treated_pax_on_same_day_as_sot_mol != 0) %>%
    nrow()
  n_hospitalised_pos_test <-
    data_processed %>%
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    filter(status_all %in% c("covid_hosp", "noncovid_hosp") &
             fu_all == 0) %>%
    nrow()
  n_died_pos_test <-
    data_processed %>%
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp") &
               fu_all == 0)) %>%
    filter(status_all %in% c("covid_death", "noncovid_death") &
             fu_all == 0) %>%
    nrow()
  n_treated_rem <-
    data_processed %>%
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp", "covid_death", "noncovid_death") &
               fu_all == 0)) %>%
    filter(!is.na(remdesivir_covid_therapeutics)) %>%
    nrow()
  n_after_exclusion_processing_pax_included <- 
    data_processed %>%
    # Exclude patients treated with both sotrovimab and molnupiravir on the
    # same day 
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    # Exclude patients hospitalised on day of positive test
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp", "covid_death", "noncovid_death") &
               fu_all == 0)) %>%
    # if treated with remidesivir --> exclude
    filter(is.na(remdesivir_covid_therapeutics)) %>% nrow()
  n_treated_pax <-
    data_processed %>%
    # Exclude patients treated with both sotrovimab and molnupiravir on the
    # same day 
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    # Exclude patients hospitalised on day of positive test
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp", "covid_death", "noncovid_death") &
               fu_all == 0)) %>%
    # if treated with remidesivir --> exclude
    filter(is.na(remdesivir_covid_therapeutics)) %>%
    filter(treatment_paxlovid_prim == "Treated") %>% nrow()
  n_after_exclusion_processing_pax_excluded <-
    data_processed %>%
    # Exclude patients treated with both sotrovimab and molnupiravir on the
    # same day 
    filter(treated_sot_mol_same_day == 0 & treated_pax_on_same_day_as_sot_mol == 0) %>%
    # Exclude patients hospitalised on day of positive test
    filter(!(status_all %in% c("covid_hosp", "noncovid_hosp", "covid_death", "noncovid_death") &
               fu_all == 0)) %>%
    # if treated with remidesivir --> exclude
    filter(is.na(remdesivir_covid_therapeutics)) %>%
    filter(treatment_paxlovid_prim == "Untreated") %>% nrow()
  out <- tibble(n_before_exclusion_processing,
                n_treated_same_day,
                n_pax_same_day_as_sot_mol,
                n_hospitalised_pos_test,
                n_died_pos_test,
                n_treated_rem,
                n_after_exclusion_processing_pax_included,
                n_treated_pax,
                n_after_exclusion_processing_pax_excluded)
}