################################################################################
#
# Cox models (propensity score analysis) // BA.2 period
# SUBGROUP: HAEM DISEASE
#
# This script can be run via an action in project.yaml
# It combines tables to Table 3/ 3 (haem_malig) in the manuscript
# saved in:
# ./output/tables_joined/table3.csv
# ./output/tables_joined/table3_haem.csv
################################################################################

################################################################################
# 00. Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create tables directory
fs::dir_create(here("output", "tables_joined"))

################################################################################
# 0.2 Create string with file names cox models
################################################################################
data_label <- "day5"
# where can input be found?
folder_with_tables <- 
  here("output", "tables")
adjustment_set <- c("crude", "agesex", "full")
cox_prefix <- 
  paste0("cox_models_",
         data_label,
         "_",
         adjustment_set)
# ba.1 / ba.2 all + haem malig
names_cox_ba1 <- 
  paste0(cox_prefix,
         "_new.csv")
names_cox_ba2 <-
  paste0(cox_prefix,
         "_ba2_new.csv")
names_cox_ba1_haem <- 
  paste0(cox_prefix,
         "_haem_malig_new.csv")
names_cox_ba2_haem <-
  paste0(cox_prefix,
         "_ba2_haem_malig_new.csv")

################################################################################
# 0.3 Create string with file names counts
################################################################################
# the crude file will not be released as the numbers of the crude analysis are 
# reported in the agesex/ fully adjusted tables (before restriction)
counts_prefix <-
  paste0("counts_",
         data_label,
         "_",
         adjustment_set[which(adjustment_set != "crude")])
names_counts_ba1 <- paste0("counts_", counts_prefix)

################################################################################
# 1. Define functions
################################################################################
# Adds column adjustment_set and combines HR, LowerCI and UpperCI
prepare_table <- function(.x, .y) {
  .x %>% 
    filter(outcome == "primary") %>%
    add_column(adjustment_set = .y,
               .after = "comparison") %>%
    mutate(HR = round(HR, 2),
           LowerCI = round(LowerCI, 2),
           UpperCI = round(UpperCI, 2),
           HR_CI = paste0(HR, " (", LowerCI, ";", UpperCI, ")")) %>%
    select(-c(outcome, HR, LowerCI, UpperCI))
}
# Combines three tables (three adjustment sets) to one
table_period <- function(folder_with_tables,
                         names){
  tables <- 
    map(.x = fs::path(folder_with_tables, names),
        ~ read_csv(.x))
  names(tables) <- adjustment_set
  
  tables <-
    imap(.x = tables,
         ~ prepare_table(.x, .y))
  
  table <- 
    bind_rows(tables) %>%
    mutate(n_analysis = case_when(adjustment_set == "crude" ~ n,
                                  TRUE ~ n_after_restriction),
           .before = HR_CI) %>%
    select(-c(n, n_after_restriction)) %>%
    arrange(match(comparison, c("All", "Molnupiravir", "Sotrovimab")))
  
  return(table)
}

################################################################################
# 2. BA.1 and BA.2 (no subgroup)
################################################################################
table_ba1 <- table_period(folder_with_tables,
                          names_cox_ba1)
table_ba2 <- table_period(folder_with_tables,
                          names_cox_ba2)
table_joined <-
  table_ba1 %>% left_join(table_ba2,
                          by = c("comparison", "adjustment_set"),
                          suffix = c(".ba1", ".ba2"))


################################################################################
# 2. BA.1 and BA.2 (haem_malig)
################################################################################
table_ba1_haem <- table_period(folder_with_tables,
                               names_cox_ba1_haem)
table_ba2_haem <- table_period(folder_with_tables,
                               names_cox_ba2_haem)
table_joined_haem <-
  table_ba1_haem %>% left_join(table_ba2_haem,
                               by = c("comparison", "adjustment_set"),
                               suffix = c(".ba1", ".ba2"))

################################################################################
# 3. Save output
################################################################################
write_csv(table_joined,
          here("output", "tables_joined", "table3.csv"))
write_csv(table_joined_haem,
          here("output", "tables_joined", "table3_haem.csv"))
