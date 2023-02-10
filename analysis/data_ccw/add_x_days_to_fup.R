add_x_days_to_fup <- function(data, x){
  data <- 
    data %>%
    mutate(fup = fup + x)
}