################################################################################
#
# QBA PLOTS
#
#
# This script performs the qba + makes plots
# Input:
# ./output/tables/['period'_]table_ccw_plr.csv 
# Output:
# ./output/plr/tables/qba/scenario*.png
# note if 'period' == ba1, no prefix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(tidyverse)
library(patchwork)
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
model <- "plr"
outcome <- "primary"
subgrp <- "full"
supp <- "main"
periods <- c("ba1", "ba2")

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
tables_dir <- 
  concat_dirs("tables", output_dir, model, subgrp, supp)
tables_qba_dir <- 
  concat_dirs(fs::path("tables", "qba"), output_dir, model, subgrp, supp)
figures_qba_dir <- 
  concat_dirs(fs::path("figures", "qba"), output_dir, model, subgrp, supp)
# Create tables directory
fs::dir_create(tables_dir)
fs::dir_create(figures_qba_dir)

################################################################################
# 0.3 Input
################################################################################
file_name_ba1 <- "table_ccw_plr.csv"
file_name_ba2 <- "ba2_table_ccw_plr.csv"
table_ccw_input <- 
  map_dfr(.x = list(file_name_ba1, file_name_ba2),
          .f = ~ read_csv(fs::path(tables_dir, .x),
                                     col_types = cols_only(
                                       period = col_character(),
                                       contrast = col_character(),
                                       HR = col_character(),
                                       HR_SE = col_double())))

################################################################################
# 1.0 QBA SCENARIO 1
################################################################################ 
qba_scen1 <-
  table_ccw_input %>%
  transmute(period = period,
            contrast = contrast,
            HR_lower = str_extract(HR, "(?<=[:blank:]).*;") %>% str_sub(start = 2L, end = 6L) %>% as.numeric(),
            HR_upper = str_extract(HR, ";.*") %>% str_sub(start = 2L, end = 6L) %>% as.numeric(),
            HR = word(HR) %>% as.numeric(),
            HR_SE = HR_SE,
            prev_trt1 = 0.70,
            prev_trt2 = 0.85,
            prev_trt3 = 0.90,
            prev_untrt = 0.65,
            gamma1 = 1.20,
            gamma2 = 1.50,
            gamma3 = 2.50) %>%
  pivot_longer(cols = starts_with("prev_trt"),
               values_to = "prev_trt",
               names_to = "scenario_prev_trt") %>%
  pivot_longer(cols = starts_with("gamma"),
               values_to = "gamma",
               names_to = "scenario_gamma") %>%
  group_by(period, contrast, HR, HR_SE, HR_lower, HR_upper) %>%
  group_modify(.f = ~ .x %>%
                 add_row(
                   prev_untrt = 0,
                   scenario_prev_trt = "base",
                   prev_trt = 0,
                   gamma = 0,
                   scenario_gamma = "base")) %>%
  mutate(bias_term = (1 + prev_trt * (gamma - 1))/(1 + prev_untrt * (gamma - 1)),
         HR_cor = HR / bias_term,
         HR_lower_cor = HR_lower / bias_term,
         HR_upper_cor = HR_upper / bias_term,
         scenario_prev_trt_descr = 
           if_else(scenario_prev_trt == "base", "None", paste0("Pr: ", prev_trt)),
         scenario_gamma_descr = 
           if_else(scenario_gamma == "base", "Observed Effect", paste0("HR: ", gamma)) %>%
           factor(levels = c("Observed Effect", "HR: 1.2", "HR: 1.5", "HR: 2.5")),
         contrast_descr = if_else(contrast == "all", "Overall", contrast %>% str_to_title()) %>%
           factor(levels = c("Overall", "Molnupiravir", "Sotrovimab")))
plots_qba_scen1 <- 
  map(
    .x = periods,
    .f = ~ 
      qba_scen1 %>%
      filter(period == .x) %>%
      ggplot(aes(x = scenario_prev_trt_descr, y = HR_cor, ymin = HR_lower_cor, ymax = HR_upper_cor)) +
      geom_pointrange(position = position_dodge(width = 0.75), 
                      aes(col = scenario_gamma_descr)) +
      geom_hline(yintercept = 1, linetype = 2) +
      ylab("Hazard Ratio (95% CI)") +
      xlab("") +
      geom_errorbar(position = position_dodge(width=0.75), 
                    aes(ymin = HR_lower_cor, ymax = HR_upper_cor, col = scenario_gamma_descr), 
                    width = 0, 
                    cex = 1) + 
      facet_wrap(~contrast_descr, 
                 strip.position="top",
                 nrow = 1, 
                 scales = "free_x") +
      theme(plot.title = element_text(size = 16),
            axis.text.x = element_text(angle = 90),
            axis.title = element_text(size=12)) +
      scale_y_log10(breaks = c(0.55, 0.75, 1, 1.25, 1.5),
                    limits = c(0.55, 1.5)) +
      theme_bw() + 
      theme(legend.position = "bottom",
            strip.background = element_blank(),
            axis.text.x = element_text(angle = 45, vjust = 0.5)) +
      labs(color = "Confounder Strength")
  )
names(plots_qba_scen1) <- periods
# combine
plot_qba_scen1 <- 
  plots_qba_scen1$ba1 + ggtitle("A) BA.1 (scenario 1)") +
  plots_qba_scen1$ba2 + ggtitle("B) BA.2 (scenario 1)") +
  plot_layout(ncol = 2, nrow = 1, guides = "collect") & 
  theme(legend.position = "bottom", legend.box.spacing = unit(0, "pt"))

################################################################################
# 1.0 QBA SCENARIO 2
################################################################################ 
qba_scen2 <-
  table_ccw_input %>%
  transmute(period = period,
            contrast = contrast,
            HR_lower = str_extract(HR, "(?<=[:blank:]).*;") %>% str_sub(start = 2L, end = 6L) %>% as.numeric(),
            HR_upper = str_extract(HR, ";.*") %>% str_sub(start = 2L, end = 6L) %>% as.numeric(),
            HR = word(HR) %>% as.numeric(),
            HR_SE = HR_SE,
            prev_trt = 0.1,
            prev_untrt1 = 0.15,
            prev_untrt2 = 0.30,
            prev_untrt3 = 0.50,
            gamma1 = 0.7,
            gamma2 = 0.5,
            gamma3 = 0.2) %>%
  pivot_longer(cols = starts_with("prev_untrt"),
               values_to = "prev_untrt",
               names_to = "scenario_prev_untrt") %>%
  pivot_longer(cols = starts_with("gamma"),
               values_to = "gamma",
               names_to = "scenario_gamma") %>%
  group_by(period, contrast, HR, HR_SE, HR_lower, HR_upper) %>%
  group_modify(.f = ~ .x %>%
                 add_row(
                   prev_untrt = 0,
                   scenario_prev_untrt = "base",
                   prev_trt = 0,
                   gamma = 0,
                   scenario_gamma = "base")) %>%
  mutate(bias_term = (1 + prev_trt * (gamma - 1))/(1 + prev_untrt * (gamma - 1)),
         HR_cor = HR / bias_term,
         HR_lower_cor = HR_lower / bias_term,
         HR_upper_cor = HR_upper / bias_term,
         scenario_prev_trt_descr = 
           if_else(scenario_prev_untrt == "base", "None", paste0("Pr: ", prev_untrt)),
         scenario_gamma_descr = 
           if_else(scenario_gamma == "base", "Observed Effect", paste0("HR: ", gamma)) %>%
           factor(levels = c("Observed Effect", "HR: 0.7", "HR: 0.5", "HR: 0.2")),
         contrast_descr = if_else(contrast == "all", "Overall", contrast %>% str_to_title()) %>%
           factor(levels = c("Overall", "Molnupiravir", "Sotrovimab")))
plots_qba_scen2 <- 
  map(
    .x = periods,
    .f = ~ 
      qba_scen2 %>%
      filter(period == .x) %>%
      ggplot(aes(x = scenario_prev_trt_descr, y = HR_cor, ymin = HR_lower_cor, ymax = HR_upper_cor)) +
      geom_pointrange(position = position_dodge(width = 0.75), 
                      aes(col = scenario_gamma_descr)) +
      geom_hline(yintercept = 1, linetype = 2) +
      ylab("Hazard Ratio (95% CI)") +
      xlab("") +
      geom_errorbar(position = position_dodge(width=0.75), 
                    aes(ymin = HR_lower_cor, ymax = HR_upper_cor, col = scenario_gamma_descr), 
                    width = 0, 
                    cex = 1) + 
      facet_wrap(~contrast_descr, 
                 strip.position="top",
                 nrow = 1, 
                 scales = "free_x") +
      theme(plot.title = element_text(size = 16),
            axis.text.x = element_text(angle = 90),
            axis.title = element_text(size=12)) +
      scale_y_log10(breaks = c(0.45, 0.75, 1, 1.25, 1.5),
                    limits = c(0.42, 1.5)) +
      theme_bw() +
      theme(legend.position = "bottom",
            strip.background = element_blank(),
            axis.text.x=element_text(angle = 45, vjust = 0.5)) +
      labs(color = "Confounder Strength")
    )
names(plots_qba_scen2) <- periods
# combine
plot_qba_scen2 <- 
  plots_qba_scen2$ba1 + ggtitle("C) BA.1 (scenario 2)") +
  plots_qba_scen2$ba2 + ggtitle("D) BA.2 (scenario 2)") +
  plot_layout(ncol = 2, nrow = 1, guides = "collect") & 
  theme(legend.position = "bottom", legend.box.spacing = unit(0, "pt"))

################################################################################
# 2. Save
################################################################################
ggsave(plot_qba_scen1, 
       filename = fs::path(figures_qba_dir, "scenario1.png"),
       width = 30, height = 9, units = "cm")
ggsave(plot_qba_scen2, 
       filename = fs::path(figures_qba_dir, "scenario2.png"),
       width = 30, height = 9, units = "cm")
