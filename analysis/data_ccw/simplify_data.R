ccw_simplify_data <- function(data, outcome, contrast, subgrp){
  contrast <- contrast %>% stringr::str_to_title()
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
        # set tb_postest_treat (day of fup on which they've been treated to NA)
        tb_postest_treat_ccw = if_else(
          treatment_prim == "Untreated",
          NA_real_,
          tb_postest_treat),
        treatment_ccw = treatment_prim,
        fu_ccw = fu_primary,
      )
    if (contrast != "all"){
      data <- 
        data %>%
        filter(treatment_strategy_cat_prim %in% c("Untreated", contrast))
    }
    if (subgrp != "full"){
      data <-
        data %>% 
        filter(haematological_disease_nhsd == 1)
    }
  } else if (outcome == "secondary"){
    data <-
      data %>%
      mutate(
        # simplify primary status
        status_ccw_simple = if_else(
          status_secondary %in% c("allcause_hosp_death"),
          1,
          0),
        # some people have been treated on or after they experience an event,
        # variable 'treatment_prim' is then 'Untreated' (see process_data.R), if so,
        # set tb_postest_treat (day of fup on which they've been treated to NA)
        tb_postest_treat_ccw = if_else(
          treatment_sec == "Untreated",
          NA_real_,
          tb_postest_treat),
        treatment_ccw = treatment_sec,
        fu_ccw = fu_secondary,
      )
    if (contrast != "all"){
      data <- 
        data %>%
        filter(treatment_strategy_cat_sec %in% c("Untreated", contrast))
    }
    if (subgrp == "haem"){
      data <-
        data %>% 
        filter(haematological_disease_nhsd == TRUE)
    } else if (subgrp == "transplant"){
      data <- 
        data %>%
        filter(solid_organ_transplant_nhsd == TRUE)
    }
  }
  data
}
