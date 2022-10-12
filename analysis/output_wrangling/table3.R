################################################################################
#
# TABLE 3
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
names_cox_ba1 <- paste0(cox_prefix, "_new.csv")
names_cox_ba2 <- paste0(cox_prefix, "_ba2_new.csv")
names_cox_ba1_haem <- paste0(cox_prefix, "_haem_malig_new.csv")
names_cox_ba2_haem <- paste0(cox_prefix, "_ba2_haem_malig_new.csv")

################################################################################
# 0.3 Create string with file names counts
################################################################################
# where can counts be found?
folder_with_counts <- here("output", "counts")
counts_n_prefix <-
  paste0("counts_n",
         ifelse(adjustment_set == "crude", "_", "_restr_"),
         data_label,
         "_",
         adjustment_set)
counts_n_outcome_prefix <-
  paste0("counts_n_outcome",
         ifelse(adjustment_set == "crude", "_", "_restr_"),
         data_label,
         "_",
         adjustment_set)


names_counts_n_ba1 <- paste0(counts_n_prefix, ".csv")
names_counts_n_ba2 <- paste0(counts_n_prefix, "_ba2.csv")
names_counts_n_ba1_haem <- paste0(counts_n_prefix, "_haem_malig.csv")
names_counts_n_ba2_haem <- paste0(counts_n_prefix, "_ba2_haem_malig.csv")

names_counts_n_outcome_ba1 <- paste0(counts_n_outcome_prefix, ".csv")
names_counts_n_outcome_ba2 <- paste0(counts_n_outcome_prefix, "_ba2.csv")
names_counts_n_outcome_ba1_haem <- paste0(counts_n_outcome_prefix, "_haem_malig.csv")
names_counts_n_outcome_ba2_haem <- paste0(counts_n_outcome_prefix, "_ba2_haem_malig.csv")

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
    select(-c(outcome, HR, LowerCI, UpperCI, n, n_after_restriction))
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
    arrange(match(comparison, c("All", "Molnupiravir", "Sotrovimab")))
  
  return(table)
}
# prepares counts, adds column 'adjustment_set' and selects n_treated and 
# number of outcomes after ps restriction (for agesex and fully adjusted models)
prepare_counts_n <- function(.x, .y){
  .x %>%
    transmute(adjustment_set = .y,
              comparison,
              n = paste0(n, " (", n_treated, ")"))
}
prepare_counts_n_outcome <- function(.x, .y){
  .x %>%
    transmute(adjustment_set = .y,
              comparison,
              n_outcome = paste0(n_outcome, " (", n_outcome_treated, ")"))
}
# combines crude/agesex and fully adjusted counts to one table
counts_period <- function(folder_with_counts,
                          names_counts_n,
                          names_counts_n_outcome) {
  tables_counts_n <-
    map(.x = fs::path(folder_with_counts, names_counts_n),
        ~ read_csv(.x))
  names(tables_counts_n) <- adjustment_set
  tables_counts_n <-
      imap(.x = tables_counts_n,
           ~ prepare_counts_n(.x, .y))
  
  tables_counts_n_outcome <-
    map(.x = fs::path(folder_with_counts, names_counts_n_outcome),
        ~ read_csv(.x))
  names(tables_counts_n_outcome) <- adjustment_set
  tables_counts_n_outcome <-
    imap(.x = tables_counts_n_outcome,
         ~ prepare_counts_n_outcome(.x, .y))
  
  # combine all tables to one table
  table_counts_n <- 
    bind_rows(tables_counts_n) %>%
    arrange(match(comparison, c("All", "Molnupiravir", "Sotrovimab")))
  
  table_counts_n_outcome <- 
    bind_rows(tables_counts_n_outcome) %>%
    arrange(match(comparison, c("All", "Molnupiravir", "Sotrovimab")))
  
  table <-
    table_counts_n %>%
    left_join(table_counts_n_outcome, by = c("comparison", "adjustment_set"))
  
  return(table)
}

combine_cox_counts <- function(table_cox,
                               table_counts){
  table <- 
    table_counts %>%
    left_join(table_cox, by = c("comparison", "adjustment_set"))
}


################################################################################
# 2. BA.1 and BA.2 (no subgroup)
################################################################################
# ba1
cox_ba1 <- table_period(folder_with_tables,
                        names_cox_ba1)
counts_ba1 <- counts_period(folder_with_counts,
                              names_counts_n_ba1,
                              names_counts_n_outcome_ba1)
table_ba1 <- combine_cox_counts(cox_ba1,
                                counts_ba1)
# ba2
cox_ba2 <- table_period(folder_with_tables,
                        names_cox_ba2)
counts_ba2 <- counts_period(folder_with_counts,
                            names_counts_n_ba2,
                            names_counts_n_outcome_ba2)
table_ba2 <- combine_cox_counts(cox_ba2,
                                counts_ba2)
# table 3
table3 <- 
  table_ba1 %>%
  left_join(table_ba2,
            by = c("comparison", "adjustment_set"),
            suffix = c(".ba1", ".ba2"))

################################################################################
# 2. BA.1 and BA.2 (haem_malig)
################################################################################
# ba1_haem
cox_ba1_haem <- table_period(folder_with_tables,
                             names_cox_ba1_haem)
counts_ba1_haem <- counts_period(folder_with_counts,
                                 names_counts_n_ba1_haem,
                                 names_counts_n_outcome_ba1_haem)
table_ba1_haem <- combine_cox_counts(cox_ba1_haem,
                                     counts_ba1_haem)
# ba2_haem
cox_ba2_haem <- table_period(folder_with_tables,
                        names_cox_ba2_haem)
counts_ba2_haem <- counts_period(folder_with_counts,
                                 names_counts_n_ba2_haem,
                                 names_counts_n_outcome_ba2_haem)
table_ba2_haem <- combine_cox_counts(cox_ba2_haem,
                                     counts_ba2_haem)
# table 3
table3_haem <- 
  table_ba1_haem %>%
  left_join(table_ba2_haem,
            by = c("comparison", "adjustment_set"),
            suffix = c(".ba1", ".ba2"))

################################################################################
# 3. Save output
################################################################################
write_csv(table3,
          here("output", "tables_joined", "table3.csv"))
write_csv(table3_haem,
          here("output", "tables_joined", "table3_haem.csv"))
