################################################################################
#
# Plot density of weights
#
# This script is run locally
# It plots the density of the weights
# original models:
# ./output/data_properties/data_long/['period'_]dens_['contrast']['outcome'].csv:
# note if 'period' == ba1, no prefix is used;
# if 'outcome' == primary, no suffix is used
#
################################################################################

################################################################################
# 0.0 Import libraries + functions
################################################################################
library(here)
library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(ggplot2)

################################################################################
# 0.1 Create directories for output
################################################################################
# Create models directory
output_dir <- here::here("output", "figures", "density")
fs::dir_create(output_dir)

################################################################################
# 0.2 Import command-line arguments
################################################################################
args <- commandArgs(trailingOnly = TRUE)
# Set input data to ba1 or ba2 data, default is ba1
if (length(args) == 0){
  period = "ba1"
} else if (args[[1]] == "ba1") {
  period = "ba1"
} else if (args[[1]] == "ba2") {
  period = "ba2"
} else {
  # Print error if no argument specified
  stop("No period specified")
}

################################################################################
# 1 Read models
################################################################################
pattern <- if_else(period == "ba1", "^dens", "^ba2_dens")
# directory with density files
dens_dir <- here("output", "data_properties", "data_long")
files <- 
  list.files(dens_dir,
             pattern = pattern, 
             full.names = FALSE)
# capture names of models
object_names <- str_extract(files, "[^.]+")
dens <- 
  map(.x = files,
      .f = ~ read_csv(fs::path(dens_dir, .x),
                      col_types = cols_only(arm = col_factor(),
                                            coord = col_double(),
                                            dens = col_double())))
names(dens) <- object_names

################################################################################
# 1 Plot models
################################################################################
plot_dens <- function(dens, dens_contrast){
  contrast <- str_extract(dens_contrast, "[^_]*$")
  title <- 
    paste0(ifelse(contrast == "all", 
                  "Treated vs Untreated",
                  paste0(contrast %>% str_to_title(), " vs Untreated")),
           " [", period %>% toupper(), "]")
  p <- 
    ggplot(data = dens,
           aes(x = coord, y = dens, group = arm)) +
    geom_line(aes(linetype = arm)) + 
    labs(linetype = "Arm") +
    theme_minimal() + 
    theme(legend.background = element_rect()) + 
    scale_x_continuous(name = "Weight") +
    scale_y_continuous(name = "Density", limits = c(0, 25)) +
    ggtitle(title)
}
plots <-
  imap(.x = dens,
       .f = ~ plot_dens(.x, .y))

#p_data %>% ggplot(aes(x = x, y = y)) + geom_col(aes(col = fill)) new histograms

################################################################################
# 2 Save plots
################################################################################
iwalk(.x = plots,
      .f = ~ ggsave(
        fs::path(output_dir, paste0(.y, ".png")),
        device = "png",
        .x
      )
)
