add_x_days_to_day0 <- function(data, x){
  data <- 
    data %>%
    mutate(fup = ifelse(fup==0, fup + x, fup))
}
