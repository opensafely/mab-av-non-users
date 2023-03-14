# PLR model
create_formula_cens_trt_logreg <- function(covars_formula){
  formula_cens <- paste0("censoring ~ ",
                         paste0(covars_formula, collapse = " + ")) %>% 
    as.formula()  
}
create_formula_cens_control_plr <- function(covars_formula){
  formula_cens <- paste0("censoring ~ ",
                         paste0(c("ns(fup, 4)", covars_formula), collapse = " + ")) %>% 
    as.formula()  
}
################################################################################
# Arm "Control": no treatment within 5 days
################################################################################
fit_cens_plr <- function(data_long, formula_cens){
  fit <-
    glm(formula_cens,
        family = binomial(link = "logit"),
        data = data_long)
}
add_p_uncens_plr <- function(data_long, plr_fit){
  # estimate probability of remaining uncensored
  data_long <-
    data_long %>%
    mutate(p_uncens = 1 - predict(plr_fit, type = "response")) %>%
    group_by(patient_id) %>%
    mutate(lag_p_uncens = lag(p_uncens, default = 1),
           cmlp_uncens = cumprod(lag_p_uncens)) %>%
    ungroup()
  data_long
}
