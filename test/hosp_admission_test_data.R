data1 <- 
  tibble(
    treatment_strategy_cat = "Sotrovimab",
    covid_test_positive_date = ymd("20211216"),
    date_treated = ymd("20211220"),
    covid_hosp_admission_date0 = NA_Date_,
    covid_hosp_admission_date1 = NA_Date_,
    covid_hosp_admission_date2 = NA_Date_,
    covid_hosp_admission_date3 = NA_Date_,
    covid_hosp_admission_date4 = ymd("20211220"),
    covid_hosp_admission_date5 = ymd("20211221"), 
    covid_hosp_admission_date6 = NA_Date_,
    covid_hosp_admission_first_date7_27 = ymd("20211225"),
    covid_hosp_discharge_first_date0_7 = NA_Date_,
    covid_hosp_date_mabs_procedure = ymd("20211220")
  )

data2 <- 
  tibble(
    treatment_strategy_cat = "Sotrovimab",
    covid_test_positive_date = ymd("20211218"),
    date_treated = ymd("20211220"),
    covid_hosp_admission_date0 = NA_Date_,
    covid_hosp_admission_date1 = NA_Date_,
    covid_hosp_admission_date2 = NA_Date_,
    covid_hosp_admission_date3 = NA_Date_,
    covid_hosp_admission_date4 = ymd("20211222"),
    covid_hosp_admission_date5 = ymd("20211223"), 
    covid_hosp_admission_date6 = NA_Date_,
    covid_hosp_admission_first_date7_27 = ymd("20211225"),
    covid_hosp_discharge_first_date0_7 = ymd("20211222"),
    covid_hosp_date_mabs_procedure = ymd("20211220")
  )

data <- 
  data1 %>% rbind(data2)

data <- 
  data %>%
  summarise_covid_admissions() %>%
  add_covid_hosp_admission_outcome()

data %>% View()

data %>%
  filter(treatment_strategy_cat == "Sotrovimab" &
           covid_hosp_admission_date == covid_hosp_admission_2nd_date0_27) %>%
  nrow()
