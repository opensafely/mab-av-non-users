ccw_simplify_data <- function(data, outcome, contrast, subgrp){
  if (outcome == "primary"){
    data <-
      data %>%
      mutate(
        # simplify primary status
        status_ccw_simple = if_else(
          status_primary %in% c("covid_hosp_death"),
          1,
          0),
        # some people have been treated on or after they experience an event,
        # variable 'treatment_prim' is then 'Untreated' (see process_data.R), if so,
        # set tb_postest_treat_ccw (day of fup on which they've been treated to NA)
        tb_postest_treat_ccw = if_else(
          treatment_prim == "Untreated",
          NA_real_,
          tb_postest_treat),
        treatment_ccw = treatment_prim,
        fu_ccw = fu_primary,
        # some people have been treated on or after they experience an event,
        # variable 'treatment_paxlovid_prim' is then 'Untreated' (see process_data.R), if so,
        # set tb_postest_treat_pax_ccw (day of fup on which they've been treated to NA)
        tb_postest_treat_pax_ccw = if_else(
          treatment_paxlovid_prim == "Untreated",
          NA_real_,
          tb_postest_treat),
        treatment_paxlovid_ccw = treatment_paxlovid_prim,
        treatment_alt_ccw = "Untreated" %>% factor(levels = c("Untreated", "Treated")),
        tb_postest_treat_alt_ccw = NA_real_,
      )
    if (contrast != "all"){
      contrast <- contrast %>% stringr::str_to_title()
      data <- 
        data %>%
        mutate(treatment_ccw = 
                 if_else(
                   treatment_strategy_cat_prim %in% c("Untreated", contrast),
                   treatment_ccw %>% as.character(),
                   "Untreated") %>% factor(levels = c("Untreated", "Treated")),
               treatment_alt_ccw =
                 case_when(
                   treatment_strategy_cat_prim == "Untreated" ~ "Untreated",
                   treatment_strategy_cat_prim == contrast ~ "Untreated",
                   TRUE ~ "Treated") %>% factor(levels = c("Untreated", "Treated")),
               tb_postest_treat_alt_ccw = 
                 if_else(
                   treatment_paxlovid_prim == "Untreated",
                   NA_real_,
                   tb_postest_treat)
               )
    }
  }
  if (subgrp == "haem"){
    data <-
      data %>% 
      filter(haematological_disease_nhsd == TRUE)
  } else if (subgrp == "transplant"){
    data <- 
      data %>%
      filter(solid_organ_transplant_nhsd_new == TRUE)
  }
  data
}
