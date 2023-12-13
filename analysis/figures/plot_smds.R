################################################################################
#
# SMD PLOTS
#
#
# This script plots the SMD estimates
# Input:
# ./output/tables/'period'_]smd_['contrast'_]plr.csv
# Output:
# ./output/plr/figures/smd_plots/['period'_]smd_['contrast'_]plr.png
# note if 'period' == ba1, no prefix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(gridExtra)
library(grid)
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))
source(here("lib", "functions", "clean_smd_names.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
period <- "ba2"
model <- "plr"
outcome <- "primary"
subgrp <- "full"
supp <- "main"

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
smd_dir <-
  concat_dirs(fs::path("tables", "ccw"), output_dir, model, subgrp, supp)
figures_dir <- 
  concat_dirs(fs::path("figures", "smd_plots"), output_dir, model, subgrp, supp)
# Create tables directory
fs::dir_create(figures_dir)

################################################################################
# 0.3 Input
################################################################################
file_names <- 
  list(all = "smd_all_plr.csv",
       molnupiravir = "smd_molnupiravir_plr.csv",
       sotrovimab = "smd_sotrovimab_plr.csv")
if (period == "ba2") {
  file_names <- map(.x = file_names, .f = ~ paste0("ba2_", .x))
}

################################################################################
# 0.4 Import output from ccw analysis
################################################################################
smd <-
  map(.x = file_names,
      .f = ~ read_csv(fs::path(smd_dir, .x)) %>%
                clean_smd_names %>%
                pivot_longer(cols = starts_with("smd"), names_to = "Weighting") %>%
                mutate(Weighting = if_else(Weighting == "smd_w", "Weighted (PLR)", "Unweighted"),
                value = abs(value)) %>%
                rename(Covariates = covars))
 
plots <-
  map(.x = smd,
      .f = ~ .x %>% filter(time == 5.5) %>%
        ggplot(aes(x = Covariates, y = value, color = Weighting)) +
        geom_point() +
        theme_bw() + 
        geom_hline(yintercept = 10, linetype = "dashed", color = "black") +
        coord_flip() +
        theme(axis.text = element_text(size = 10)))

################################################################################
# 2. Save
################################################################################
prefix <- ifelse(period == "ba1", "smd_", "ba2_smd_")
iwalk(.x = plots,
      .f = ~ ggsave(fs::path(figures_dir, paste0(prefix, .y, "_plr.png")),
                    plot = .x,
                    width = 210, height = 297, units = "mm"))
