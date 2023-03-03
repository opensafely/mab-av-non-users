# PLR model
create_formula_cens_plr <- function(covars_formula){
  formula_cens <- paste0("censoring ~ ",
                         paste0(c("poly(tstart, 2)", covars_formula), collapse = " + ")) %>% 
    as.formula()  
}
################################################################################
# Arm "Control": no treatment within 5 days
################################################################################
# Cox model
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
    mutate(p_uncens = predict(plr_fit, type = "response"))
  data_long
}
