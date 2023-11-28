# copied from https://github.com/opensafely/kaplan-meier-function
# # # # # # # # # # # # # # # # # # # # #
# Purpose: Get disclosure-safe Kaplan-Meier estimates.
# The function requires an origin date, an event date, and a censoring date, which are converted into a (time , indicator) pair that is passed to `survival::Surv`
# Estimates are stratified by the `exposure` variable, and additionally by any `subgroups`
# Counts are rounded to midpoint values defined by `count_min`.
# # # # # # # # # # # # # # # # # # # # #

# Preliminaries ----

## Import libraries ----

library('here')
library('glue')
library('tidyverse')
library('survival')
library('optparse')
library('rlang')
library('arrow')

## parse command-line arguments ----

args <- commandArgs(trailingOnly=TRUE)

if(length(args)==0){
  # use for interactive testing
  df_input <- "output/plr/data/data_long_all_plr.feather"
  dir_output <- "output/plr/figures/km_estimates/"
  period <- "ba1"
  contrast <- "all"
  outcome <- "primary"
  exposure <- c("arm")
  subgroups <- NULL
  tstart <- "tstart"
  tend <- "fup"
  event_indicator <- "outcome"
  weight <- "weight"
  min_count <- as.integer("6")
  method <- "constant"
  fill_times <- as.logical("FALSE")
  plot <- as.logical("FALSE")
} else {
  
  option_list <- list(
    make_option("--df_input", type = "character", default = "output/data/data_long_all.feather",
                help = "Input dataset .feather filename [default %default]. feather format is enforced to ensure date types are preserved.",
                metavar = "filename.feather"),
    make_option("--dir_output", type = "character", default = "output/figures/km_estimates/",
                help = "Output directory [default %default].",
                metavar = "output"),
    make_option("--period", type = "character", default = "ba1",
                help = "Period of analysis [default %default].",
                metavar = "period"),
    make_option("--contrast", type = "character", default = "all",
                help = "Contrast of analysis [default %default].",
                metavar = "contrast"),
    make_option("--outcome", type = "character", default = "primary",
                help = "Outcome of analysis [default %default].",
                metavar = "outcome"),
    make_option("--exposure", type = "character", default = "arm",
                help = "Exposure variable name in the input dataset [default %default]. All outputs will be stratified by this variable.",
                metavar = "exposure_varname"),
    make_option("--subgroups", type = "character", default = NULL,
                help = "Subgroup variable name or list of variable names [default %default]. If subgroups are used, analyses will be stratified as exposure * ( subgroup1, subgroup2, ...). If NULL, no stratification will occur.",
                metavar = "subgroup_varnames"),
    make_option("--tstart", type = "character", default = "tstart",
                help = "Interval start variable name in the input dataset [default %default]. Should refer to a numeric variable.",
                metavar = "tstart_varname"),
    make_option("--tend", type = "character", default = "fup",
                help = "Interval end variable name in the input dataset [default %default]. Should refer to a numeric variable.",
                metavar = "tend_varname"),
    make_option("--event_indicator", type = "character", default = "outcome",
                help = "Event indicator variable name in the input dataset [default %default].",
                metavar = "event_indicator_varname"),
    make_option("--weight", type = "character", default = "weight",
                help = "Weight variable name in the input dataset [default %default]. Should refer to a numeric variable.",
                metavar = "weight_varname"),
    make_option("--min_count", type = "integer", default = 6,
                help = "The minimum permissable event and censor counts for each 'step' in the KM curve [default %default]. This ensures that at least `min_count` events occur at each event time.",
                metavar = "min_count"),
    make_option("--method", type = "character", default = "constant",
                help = "Interpolation method after rounding [default %default]. The 'constant' method leaves the event times unchanged after rounding, making the KM curve have bigger, fewer steps. The 'linear' method linearly interpolates between rounded events times (then rounds to the nearest day), so that the steps appear more natural.",
                metavar = "method"),
    make_option("--fill_times", type = "logical", default = FALSE,
                help = "Should Kaplan-Meier estimates be provided for all possible event times (TRUE) or just observed event times (FALSE) [default %default]. ",
                metavar = "TRUE/FALSE"),
    make_option("--plot", type = "logical", default = TRUE,
                help = "Should Kaplan-Meier plots be created in the output folder? [default %default]. These are fairly basic plots for sense-checking purposes.",
                metavar = "TRUE/FALSE")
  )
  
  opt_parser <- OptionParser(usage = "km:[version] [options]", option_list = option_list)
  opt <- parse_args(opt_parser)
  
  df_input <- opt$df_input
  dir_output <- opt$dir_output
  period <- opt$period
  outcome <- opt$outcome
  contrast <- opt$contrast
  exposure <- opt$exposure
  subgroups <- opt$subgroups
  tstart <- opt$tstart
  tend <- opt$tend
  event_indicator <- opt$event_indicator
  weight <- opt$weight
  min_count <- opt$min_count
  method <- opt$method
  fill_times <- opt$fill_times
  plot <- opt$plot
}

exposure_sym <- sym(exposure)
subgroup_syms <- syms(subgroups)

# create output directories ----

dir_output <- here::here(dir_output)
fs::dir_create(dir_output)

# survival functions -----

ceiling_any <- function(x, to=1){
  # round to nearest 100 millionth to avoid floating point errors
  #ceiling(plyr::round_any(x/to, 1/100000000))*to
  x - (x-1)%%to + (to-1)
}

floor_any <- function(x, to=1){
  x - x%%to
}

roundmid_any <- function(x, to=1){
  # like ceiling_any, but centers on (integer) midpoint of the rounding points
  ceiling(x/to)*to - (floor(to/2)*(x!=0))
}



round_cmlcount <- function(x, time, min_count, method="linear", integer.times=TRUE) {
  # take a vector of cumulative counts and round them according to...
  stopifnot("x must be non-descreasing" = all(diff(x)>=0))
  stopifnot("x must be integer" = all(x %% 1 ==0))
  
  # round events such that the are no fewer than min_count events per step
  # steps are then shifted by ` - floor(min_count/2)` to remove bias
  if(method=="constant") {
    rounded_counts <- roundmid_any(x, min_count)
  }
  
  # as above, but then linearly-interpolate event times between rounded steps
  # this will also linearly interpolate event if _true_ counts are safe but "steppy" -- can we avoid this by not over-interpolating?
  if(method=="linear") {
    x_ceiling <- ceiling_any(x, min_count)
    x_mid <- roundmid_any(x, min_count)
    #    naturally_steppy <- which((x - x_mid) == 0)
    x_rle <- rle(x_ceiling)
    
    # get index locations of step increases
    steptime <- c(0,time[cumsum(x_rle$lengths)])
    
    # get cumulative count at each step
    stepheight <- c(0,x_rle$values)
    
    rounded_counts <- approx(x=steptime, y=stepheight, xout = time, method=method)$y
    if(integer.times) rounded_counts <- floor(rounded_counts)
  }
  
  return (rounded_counts)
}


# import and process person-level data  ----

## Import ----
data_patients <-
  read_feather(here::here(df_input)) %>%
  transmute(all = TRUE,
            patient_id,
            !!exposure_sym,
            !!!subgroup_syms,
            tstart = .data[[tstart]],
            tend = .data[[tend]],
            event_indicator = .data[[event_indicator]],
            weight = .data[[weight]])
if(is.null(subgroups)) subgroups <- list("all")

# Get KM estimates ------

for (subgroup_i in subgroups) {
  #subgroup_i = "previous_covid_test"
  survival::survfit(survival::Surv(tstart, tend, event_indicator) ~ 1, data = data_patients, id = patient_id, conf.type="log-log", weights = weight) %>% summary()
  
  # for each exposure level and subgroup level, pass data through `survival::Surv` to get KM table
  data_surv <-
    data_patients %>%
    dplyr::mutate(
      .subgroup = .data[[subgroup_i]]
    ) %>%
    dplyr::group_by(.subgroup, !!exposure_sym) %>%
    tidyr::nest() %>%
    dplyr::mutate(
      surv_obj = purrr::map(data, ~ {
        survival::survfit(survival::Surv(tstart, tend, event_indicator) ~ 1, 
                          data = .x, 
                          id = patient_id, 
                          conf.type="log-log", 
                          weights = weight)
      }),
      surv_obj_tidy = purrr::map(surv_obj, ~ {
        tidied <- broom::tidy(.x)
      }),
    ) %>%
    dplyr::select(.subgroup, !!exposure_sym, surv_obj_tidy) %>%
    tidyr::unnest(surv_obj_tidy)
  
  # round event times such that no event time has fewer than `min_count` events
  # recalculate KM estimates based on these rounded event times
  round_km <- function(.data, min_count) {
    .data %>%
      mutate(
        N = max(n.risk, na.rm = TRUE),
        
        # rounded to `min_count - (min_count/2)`
        cml.event = cumsum(n.event),
        cml.censor = cumsum(n.censor),
        cml.event.r = round_cmlcount(round(cml.event), time, min_count, method),
        cml.censor.r = round_cmlcount(round(cml.censor), time, min_count, method),
        cml.eventcensor = cml.event.r + cml.censor.r,
        n.event.r = diff(c(0, cml.event.r)),
        n.censor.r = diff(c(0, cml.censor.r)),
        #n.risk.r = roundmid_any(N, min_count) - lag(cml.eventcensor, 1, 0),
        n.risk.r = roundmid_any(n.risk, min_count),
        
        # KM estimate for event of interest, combining censored and competing events as censored
        #summand = (1 / (n.risk.r - n.event.r)) - (1 / n.risk.r), 
        summand = n.event / ((n.risk - n.event) * n.risk), #but re-written to prevent integer overflow
        surv = cumprod(1 - n.event.r / n.risk.r),
        
        # standard errors on survival scale
        surv.se = surv * sqrt(cumsum(summand)), # greenwood's formula
        # surv.low = surv + qnorm(0.025)*surv.se,
        # surv.high = surv + qnorm(0.975)*surv.se,
        
        
        ## standard errors on log scale
        surv.ln.se = surv.se / surv,
        # surv.low = exp(log(surv) + qnorm(0.025)*surv.ln.se),
        # surv.high = exp(log(surv) + qnorm(0.975)*surv.ln.se),
        
        ## standard errors on complementary log-log scale
        surv.cll = log(-log(surv)),
        surv.cll.se = if_else(surv==1, 0, sqrt((1 / log(surv)^2) * cumsum(summand))), # assume SE is zero until there are events -- makes plotting easier
        surv.low = exp(-exp(surv.cll + qnorm(0.975) * surv.cll.se)),
        surv.high = exp(-exp(surv.cll + qnorm(0.025) * surv.cll.se)),
        surv.se.approx = std.error, # using se that's taking into acount weights
        surv.low.approx = surv + qnorm(0.025) * surv.se.approx,
        surv.high.approx = surv + qnorm(0.975) * surv.se.approx,
        
        #risk (= complement of survival)
        risk = 1 - surv,
        risk.se = surv.se,
        risk.se.approx = surv.se.approx,
        risk.ln.se = surv.ln.se,
        risk.low = 1 - surv.high,
        risk.high = 1 - surv.low,
        risk.low.approx = 1 - surv.high.approx,
        risk.high.approx = 1 - surv.low.approx,
      ) %>%
      filter(
        !(n.event==0 & n.censor==0 & !fill_times) # remove times where there are no events (unless all possible event times are requested with fill_times)
      ) %>%
      mutate(
        lagtime = lag(time, 1, 0), # assumes the time-origin is zero
        interval = time - lagtime,
        conf.high = if_else(estimate == 1, 1, conf.high),
        conf.low = if_else(estimate == 1, 1, conf.low)
      ) %>%
      transmute(
        .subgroup_var = subgroup_i,
        .subgroup,
        !!exposure_sym,
        tstart = lagtime, 
        tend = time,
        interval_length = interval,
        #cml.event, cml.censor,
        N,
        n.risk, n.risk.r,
        n.event, n.event.r, cml.event, cml.event.r,
        n.censor, n.censor.r, cml.censor, cml.censor.r,
        estimate, std.error, conf.high, conf.low,
        surv, surv.se, surv.se.approx, surv.low, surv.high, surv.low.approx, surv.high.approx,
        risk, risk.se, risk.se.approx, risk.low, risk.high, risk.low.approx, risk.high.approx
      )
  }
  
  #data_surv_unrounded <- round_km(data_surv, 1)
  data_surv_rounded <- round_km(data_surv, min_count)
  
  ## write to disk
  file_name <- ifelse(subgroups != "all", glue("km_estimates_{subgroup_i}"), "km_estimates")
  file_name <- paste0(period[period != "ba1"], "_"[period != "ba1"], file_name, "_"[contrast != "all"], contrast[contrast != "all"], "_"[outcome != "primary"], outcome[outcome != "primary"])
  arrow::write_feather(data_surv_rounded, fs::path(dir_output, paste0(file_name, ".feather")))
  write_csv(data_surv_rounded, fs::path(dir_output, paste0(file_name, ".csv")))
  
  data_surv_rounded_red <-
    data_surv_rounded %>%
    select(-c(N, n.risk, n.event, cml.event,
              n.censor, cml.censor, estimate, 
              std.error, conf.high, conf.low,
              surv.se, surv.low, surv.high,
              risk.se, risk.low, risk.high))
  write_csv(data_surv_rounded_red, fs::path(dir_output, paste0(file_name, "_red.csv")))
  data_surv_rounded_red2 <- 
    data_surv_rounded_red %>%
    select(-c(n.censor.r, cml.censor.r, surv, surv.se.approx, surv.low.approx, surv.high.approx, risk.se.approx))
  write_csv(data_surv_rounded_red2, fs::path(dir_output, paste0(file_name, "_red2.csv")))
  
  if(plot){
    
    km_plot <- function(.data) {
      .data %>%
        group_modify(
          ~ add_row(
            .x,
            tstart = 0, # assumes time origin is zero
            tend = 0,
            estimate = 1,
            conf.low = 1,
            conf.high = 1,
            .before = 0
          )
        ) %>%
        ggplot(aes(group = !!exposure_sym, colour = !!exposure_sym, fill = !!exposure_sym)) +
        geom_step(aes(x = tend, y = {1 - estimate}), direction = "hv") +
        geom_rect(aes(xmin = tstart, xmax = tend, ymin = {1 - conf.high}, ymax = {1 - conf.low}), alpha = 0.1, colour = "transparent") +
        facet_grid(rows = vars(.subgroup)) +
        scale_color_brewer(type = "qual", palette = "Set1", na.value = "grey") +
        scale_fill_brewer(type = "qual", palette = "Set1", guide = "none", na.value = "grey") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.01))) +
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
          legend.position = c(.05, .95),
          legend.justification = c(0, 1),
        )
    }
    
    km_plot_rounded <- function(.data) {
      .data %>%
        group_modify(
          ~ add_row(
            .x,
            tstart = 0, # assumes time origin is zero
            tend = 0,
            surv = 1,
            risk = 0,
            risk.low.approx = 0,
            risk.high.approx = 0,
            .before = 0
          )
        ) %>%
        ggplot(aes(group = !!exposure_sym, colour = !!exposure_sym, fill = !!exposure_sym)) +
        geom_step(aes(x = tend, y = risk), direction = "vh") +
        geom_step(aes(x = tend, y = risk), direction = "vh", linetype = "dashed", alpha = 0.5) +
        geom_rect(aes(xmin = tstart, xmax = tend, ymin = risk.low.approx, ymax = risk.high.approx), alpha = 0.1, colour = "transparent") +
        facet_grid(rows = vars(.subgroup)) +
        scale_color_brewer(type = "qual", palette = "Set1", na.value = "grey") +
        scale_fill_brewer(type = "qual", palette = "Set1", guide = "none", na.value = "grey") +
        scale_y_continuous(expand = expansion(mult = c(0, 0.01))) +
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
          legend.position = c(.05, .95),
          legend.justification = c(0, 1),
        )
    }
    
    km_plot <- km_plot(data_surv_rounded)
    km_plot_red <- km_plot_rounded(data_surv_rounded_red)
    ggsave(filename = fs::path(dir_output, paste0(file_name, ".png")), km_plot, width = 20, height = 20, units = "cm")
    ggsave(filename = fs::path(dir_output, paste0(file_name, "_red.png")), km_plot_red, width = 20, height = 20, units = "cm")
  }
}
