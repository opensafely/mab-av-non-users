# Cox PH model
create_formula_cens_cox <- function(covars_formula){
  formula_cens <- paste0("Surv(tstart, fup, censoring) ~ ",
                         paste0(covars_formula, collapse = " + ")) %>% 
    as.formula()  
}
################################################################################
# Arm "Control": no treatment within 5 days
################################################################################
# Cox model
fit_cens_cox <- function(data_long, formula_cens){
  fit <-
    coxph(formula_cens,
          ties = "efron",
          data = data_long,
          model = TRUE)
}
basehaz_cens <- function(data_long, cox_fit){
  # calculate baseline hazard (0 for time = 0)
  basehazard <- 
    basehaz(cox_fit, centered = FALSE) %>%
    add_row(hazard = 0, time = 0, .before = 1)
}
add_p_uncens_cox <- function(data_long, cox_fit, basehazard){
  # add linear predictor and calculate probability of remaining uncensored
  data_long <-
    data_long %>%
    mutate(lin_pred = coxLP(cox_fit, data_long, center = FALSE)) %>%
    left_join(basehazard, by = c("tstart" = "time")) %>%
    mutate(p_uncens = exp(-(hazard)*exp(lin_pred)))
  data_long
}
