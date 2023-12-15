################################################################################
#
# META-ANALYSIS
#
#
# This scripts pools the two treatment estimates across the two periods
# Input:
# ./output/tables/'period'_]table_ccw_plr.csv 
# Output:
# ./output/plr/tables/['period'_]table_ccw_plr_meta_analysis.csv
# note if 'period' == ba1, no prefix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library("meta")
library("here")
library("tidyverse")
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
model <- "plr"
outcome <- "primary"
subgrp <- "full"
supp <- "main"

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_dir <- 
  concat_dirs("tables", output_dir, model, subgrp, supp)
# Create tables directory
fs::dir_create(tables_dir)

################################################################################
# 0.3 Input
################################################################################
file_name_ba1 <- "table_ccw_plr.csv"
file_name_ba2 <- "ba2_table_ccw_plr.csv"
table_ccw <- map_dfr(.x = list(file_name_ba1, file_name_ba2),
                     .f = ~ read_csv(fs::path(tables_dir, .x),
                                     col_types = cols_only(
                                       period = col_character(),
                                       contrast = col_character(),
                                       HR = col_character(),
                                       HR_SE = col_double())))

################################################################################
# 1.0 Meta-analysis
################################################################################ 
contrasts <- c("all", "molnupiravir", "sotrovimab")
table_ccw <- 
  table_ccw %>%
  transmute(period = period,
            contrast = contrast,
            HR = stringr::word(HR) %>% as.numeric(),
            HR_SE = HR_SE)
table_ccw_list <- 
  map(.x = contrasts,
      .f = ~ table_ccw %>% filter(contrast == .x))  
names(table_ccw_list) <- contrasts
transform_metagen <- function(results_metagen){
  tibble(HR = results_metagen$TE.common %>% exp(),
         HR_lower = results_metagen$lower.common %>% exp(),
         HR_upper = results_metagen$upper.common %>% exp())
}
results_meta_analysis <-
  imap_dfr(.x = table_ccw_list,
           .f = ~ metagen(TE = .x %>% pull(HR) %>% log(),
                          seTE = .x %>% pull(HR_SE),
                          sm = "HR") %>%
             transform_metagen() %>%
             mutate(contrast = .y))

################################################################################
# 2. Save
################################################################################
file_name_output <- "table_ccw_plr_meta_analysis.csv"
write_csv(results_meta_analysis, 
          fs::path(tables_dir, file_name_output))
