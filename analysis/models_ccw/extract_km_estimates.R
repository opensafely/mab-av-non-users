extract_km_estimates <- function(km_control, km_trt, max_fup){
  # difference in 28 day survival
  S28_trt <- km_trt$surv[which(km_trt$time == max_fup)] # 28 day survival in treatment group
  S28_control <- km_control$surv[which(km_trt$time == max_fup)] # 28 day survival in control group
  diff_surv <- S28_trt - S28_control #Difference in 28 day survival
  diff_surv_SE <- sqrt(km_trt$std.err[which(km_trt$time == max_fup)] ^ 2 +
                         km_control$std.err[which(km_trt$time == max_fup)] ^ 2)
  diff_surv_CI <- diff_surv + c(-1, 1) * qnorm(0.975) * diff_surv_SE
  # difference in 28-day restricted mean survival
  RMST_trt <- summary(km_trt, rmean = max_fup)$table["*rmean"] # Estimated RMST in the trt grp
  RMST_control <- summary(km_control, rmean = max_fup)$table["*rmean"] # Estimated RMST in the control grp
  diff_RMST <- RMST_trt - RMST_control # Difference in RMST
  diff_RMST_SE <- sqrt(summary(km_trt, rmean = max_fup)$table["*se(rmean)"] ^ 2 +
                         summary(km_control, rmean = max_fup)$table["*se(rmean)"] ^ 2)
  diff_RMST_CI <- diff_RMST + c(-1, 1) * qnorm(0.975) * diff_RMST_SE
  out <-
    tibble(
      diff_surv,
      diff_surv_lower = diff_surv_CI[1],
      diff_surv_upper = diff_surv_CI[2],
      diff_surv_SE = diff_surv_SE,
      diff_RMST,
      diff_RMST_lower = diff_RMST_CI[1],
      diff_RMST_upper = diff_RMST_CI[2],
      diff_RMST_SE = diff_RMST_SE
    )
}