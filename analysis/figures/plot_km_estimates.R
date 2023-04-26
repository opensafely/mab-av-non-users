################################################################################
#
# KAPLAN MEIER CURVES
#
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(ggplot2)
source(here("lib", "functions", "make_filename.R"))
source(here("lib", "functions", "dir_structure.R"))

################################################################################
# 0.1 Import command-line arguments
################################################################################
model <- "plr"
subgrp <- "full"
supp <- "main"
periods <- c("ba1", "ba2")

################################################################################
# 0.2 Create directories for output
################################################################################
output_dir <- here::here("output")
figures_km_dir <- 
  concat_dirs(fs::path("figures", "km_estimates"), output_dir, model, subgrp, supp)
# Create tables directory
fs::dir_create(figures_km_dir)

################################################################################
# 0.3 Search files + read
################################################################################
files <- 
    list.files(figures_km_dir,
               pattern = "_red.csv$", 
               full.names = FALSE)
period_contrast <- 
  str_remove(files, "_red.csv") %>% 
  str_remove("km_estimates") %>%
  str_replace("__", "_") %>%
  str_remove("^_|_$")
period_contrast <- case_when(
  period_contrast == "" ~ "BA.1 Treated vs Untreated",
  period_contrast == "sotrovimab" ~ "BA.1 Sotrovimab vs Untreated",
  period_contrast == "molnupiravir" ~ "BA.1 Molnupiravir vs Untreated",
  period_contrast == "ba2" ~ "BA.2 Treated vs Untreated",
  period_contrast == "ba2_sotrovimab" ~ "BA.2 Sotrovimab vs Untreated",
  period_contrast == "ba2_molnupiravir" ~ "BA.2 Molnupiravir vs Untreated")
output <- 
  map2(.x = fs::path(figures_km_dir, files),
       .y = period_contrast,
       .f = ~ read_csv(.x, 
                       col_types = cols_only(arm = col_character(),
                                             time = col_double(),
                                             lagtime = col_double(),
                                             risk = col_double(),
                                             risk.low.approx = col_double(),
                                             risk.high.approx = col_double())) %>%
         mutate(contrast = .y))
names(output) <- str_remove(files, ".csv")
################################################################################
# 0.4 Function plotting KMs
################################################################################
km_plot_rounded <- function(.data) {
  .data %>%
    group_by(arm, contrast) %>%
    group_modify(
      ~ add_row(
        .x,
        time = 0, # assumes time origin is zero
        lagtime = 0,
        risk = 0,
        risk.low.approx = 0,
        risk.high.approx = 0,
        .before = 0
      ),
    ) %>%
    mutate(time = if_else(time == 27.5, 28, time)) %>%
    ggplot(aes(group = arm, colour = arm, fill = arm)) +
    geom_step(aes(x = time, y = risk), direction = "vh") +
    geom_step(aes(x = time, y = risk), direction = "vh", linetype = "dashed", alpha = 0.5) +
    geom_rect(aes(xmin = lagtime, xmax = time, ymin = risk.low.approx, ymax = risk.high.approx), alpha = 0.1, colour = "transparent") +
    facet_grid(rows = vars(contrast)) +
    scale_color_brewer(type = "qual", palette = "Set1", na.value = "grey") +
    scale_fill_brewer(type = "qual", palette = "Set1", guide = "none", na.value = "grey") +
    scale_y_continuous(limits = limits_y, breaks = breaks_y, expand = expansion(mult = c(0, 0.01))) +
    scale_x_continuous(limits = c(0, 28), breaks = c(0, 7, 14, 21, 28)) +
    coord_cartesian(xlim = c(0, NA)) +
    labs(
      x = "Days since origin",
      y = "Kaplan-Meier estimate",
      colour = NULL,
      title = NULL
    ) +
    theme_minimal() +
    theme(
      axis.line.x = element_line(colour = "black"),
      panel.grid.minor.x = element_blank(),
      legend.position = c(0.27, 0.95),
      legend.text = element_text(size = 7),
      axis.title = element_text(size = 9),
      strip.text.x = element_text(size = 30),
      strip.background =element_rect(fill="grey")
    )
}
limits_y <- c(0, 0.05)
breaks_y <- seq(0, 0.05, 0.01)
plots <- 
  map(.x = output,
      .f = ~ km_plot_rounded(.x))

library(patchwork)
p <- 
  (plots$km_estimates_red | plots$km_estimates_molnupiravir_red | plots$km_estimates_sotrovimab_red) /
  (plots$ba2_km_estimates_red | plots$ba2_km_estimates_molnupiravir_red | plots$ba2_km_estimates_sotrovimab_red) + 
  plot_annotation(tag_levels = "A",
                  tag_suffix = ")") & 
  theme(plot.tag = element_text(size = 9))

ggsave(p, 
       filename = fs::path(figures_km_dir, "plr_kms.png"),
       width = 22,
       height = 12.5,
       units = "cm",
       bg = "white")

