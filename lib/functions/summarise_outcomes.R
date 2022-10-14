# function used to count outcomes
summarise_outcomes <- function(data, 
                               fu, 
                               status,
                               filename){
  fu <- enquo(fu)
  status <- enquo(status)
  data %>%
    select(treatment_strategy_cat, !!fu, !!status) %>%
    group_by(!!status, treatment_strategy_cat, .drop = FALSE) %>%
    summarise(n = n(),
              fu_median = median(!!fu),
              fu_q1 = quantile(!!fu, p = 0.25, na.rm = TRUE),
              fu_q3 = quantile(!!fu, p = 0.75, na.rm = TRUE),
              .groups = "keep") %>%
    mutate(n_redacted_rounded = case_when(n > 0 & n <= 7 ~ "[REDACTED]",
                                          TRUE ~ n %>% plyr::round_any(5) %>% as.character()),
           fu_median_redacted = case_when(n > 0 & n <= 10 ~ "[REDACTED]",
                                          n == 0 ~ NA_character_,
                                          TRUE ~ fu_median %>% as.character()),
           fu_q1_redacted = case_when(n > 0 & n <= 10 ~ "[REDACTED]",
                                      n == 0 ~ NA_character_,
                                      TRUE ~ fu_q1 %>% as.character()),
           fu_q3_redacted = case_when(n > 0 & n <= 10 ~ "[REDACTED]",
                                      n == 0 ~ NA_character_,
                                      TRUE ~ fu_q3 %>% as.character())) %>%
    select(-c(n, fu_median, fu_q1, fu_q3)) %>%
    write_csv(., 
              path(here("output", "data_properties"), filename))
}