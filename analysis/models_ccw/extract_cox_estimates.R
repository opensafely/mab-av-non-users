extract_cox_estimates <- function(cox){
  HR <- cox$coefficients %>% exp() # Hazard ratio
  HR_SE <- summary(cox)$coefficients[,"se(coef)"]
  HR_CI <- confint(cox) %>% exp()
  out <- 
    tibble(
      HR,
      HR_lower = HR_CI[1],
      HR_upper = HR_CI[2],
      HR_SE = HR_SE
    )
}
