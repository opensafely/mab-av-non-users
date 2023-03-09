# Function to calculate weighted and unweighted standardised differences
library(Hmisc)
std_diff <- function(data, var, wgt, time){
  tab <- 
    data %>%
    filter(fup == time) %>%
    select(arm, .data[[var]], .data[[wgt]]) %>%
    group_by(arm) %>%
    summarise(mu = wtd.mean(.data[[var]], 
                            weights = .data[[wgt]],
                            na.rm = TRUE),
              var = wtd.var(.data[[var]],
                            weights = .data[[wgt]],
                            na.rm = TRUE)) %>%
    mutate(mu = if_else(arm == "Control", - mu, mu))
  sdiff <- (100 * sum(tab$mu, na.rm = TRUE)) / (sqrt(sum(tab$var, na.rm = TRUE) / 2))
  sdiff
}