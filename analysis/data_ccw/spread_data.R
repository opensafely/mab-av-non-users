library(forcats)
recode_fctrs <- function(data){
  data <-
    data %>% 
    mutate(sex_female = 
             if_else(sex == "Female", TRUE, FALSE),
           ethnicity = 
             fct_recode(ethnicity,
                        Asian = "Asian or Asian British",
                        Black = "Black or Black British",
                        Other = "Other ethnic groups"),
           imd = 
             fct_recode(imdQ5,
                        "1" = "1 (most deprived)",
                        "5" = "5 (least deprived)"),
           rural_urban = 
             fct_recode(rural_urban,
                        conurbation = "Urban - conurbation",
                        citytown = "Urban - city and town",
                        townfringe = "Rural - town and fringe",
                        villagedisp = "Rural - village and dispersed"),
           vax_status = 
             fct_recode(vaccination_status,
                        "3" = "Three or more vaccinations",
                        "2" = "Two vaccinations",
                        "1" = "One vaccination",
                        unvax = "Un-vaccinated",
                        declined = "Un-vaccinated (declined)"),
           tb_postest_vax = 
             fct_recode(tb_postest_vacc_cat,
                        "7" = "< 7 days",
                        "7_27" = "7-27 days",
                        "28_83" = "28-83 days",
                        "84" = ">= 84 days"),
           no_most_recent_cov_vac =
             if_else(most_recent_vax_cat == "Un-vaccinated", TRUE, FALSE))
}
make_dummy_var <- function(data, var, names_prefix){
  data <- 
    data %>%
    pivot_wider(names_from = .data[[var]],
                values_from = .data[[var]],
                names_prefix = names_prefix,
                values_fill = 0,
                values_fn = length)
}
spread_data <- function(data){
  data <- 
    data %>%
    recode_fctrs() %>%
    make_dummy_var("ethnicity", "ethnicity_") %>%
    make_dummy_var("imd", "imd_") %>%
    make_dummy_var("rural_urban", "rural_urban_") %>%
    make_dummy_var("smoking_status", "smoking_") %>%
    make_dummy_var("vax_status", "vax_status_") %>%
    make_dummy_var("tb_postest_vax", "tb_postest_vax_")
}
