################################################################################
# Clone data and add vars outcome, fup and censoring
################################################################################
# This step adds the following 4 variables in both arms (control + treatment):
# - arm: "Control" or "Treatment"
# - fup: the follow-up time in the emulated trial (which can be different from 
#       the observed follow-up time)
# - outcome: the outcome in the emulated trial (which can be different from the 
#            observed outcome)
# - censoring: a binary variable indicating whether the patient was censored in 
#              a given arm (either because they receive surgery in the control 
#              arm or they didn't receive surgery in the surgery arm)
################################################################################
clone_data <- function(data, treatment_window_days = 4){
  ################################################################################
  # Arm CONTROL: no treatment within 5 days
  ################################################################################
  data_control <- # We create a copy of the dataset:
    data %>%      # "clones" assigned to the control (no treatment) arm
    mutate(arm = "Control",
           # ADD VARIABLES OUTCOME AND FUP
           outcome = case_when(
             # Case 1: patients receive treatment within 5 days (scenarios A to E)
             # --> they are still alive and followed up until treatment
             treatment_ccw == "Treated" ~ 0,
             # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
             # [either no treatment or treatment after five days]
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Untreated" ~ status_ccw_simple,
             # Case 3: patients receive paxlovid within 5 days
             # --> they are still alive and followed up until treatment
             treatment_paxlovid_ccw == "Treated" ~ 0,
             # Case 4: patients receive alternative treatment within 5 days
             # --> they are still alive and followed up until treatment
             treatment_alt_ccw == "Treated" ~ 0,
           ),
           fup = case_when(
             # Case 1: patients receive treatment within 5 days (scenarios A to E)
             # --> they are still alive and followed up until treatment
             treatment_ccw == "Treated" ~ tb_postest_treat_ccw,
             # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
             # [either no treatment or treatment after five days]
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Untreated" &
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") ~ fu_ccw,
             # Case 3: patients receive paxlovid within 5 days
             # --> they are still alive and followed up until treatment
             treatment_paxlovid_ccw == "Treated" ~ tb_postest_treat_pax_ccw,
             # Case 4: patients receive alternative treatment within 5 days
             # --> they are still alive and followed up until treatment
             treatment_alt_ccw == "Treated" ~ tb_postest_treat_alt_ccw,
           ),
           # ADD VARIABLES CENSORING
           censoring = case_when(
             # Case 1: patients receive treatment within 5 days (scenarios A to E)
             # --> they are censored in the control group at time of treatment (see fup)
             treatment_ccw == "Treated" ~ 1,
             # Case 2: patients do not receive treatment within 5 days (scenarios F to M)
             # [either no treatment or treatment after five days]
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Untreated" &
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") ~ 0,
             # Case 3: patients receive paxlovid within 5 days
             # --> they are censored in the control group at time of treatment (see fup)
             treatment_paxlovid_ccw == "Treated" ~ 1,
             # Case 4: patients receive alternative treatment within 5 days
             # --> they are censored in the control group at time of treatment (see fup)
             treatment_alt_ccw == "Treated" ~ 1,
           ),
    )
  ################################################################################
  # Arm TREATMENT: treatment within 5 days
  ################################################################################
  data_trt <- # We create a copy of the dataset: 
    data %>%  # "clones" assigned to the treatment arm
    mutate(arm = "Treatment",
           # ADD VARIABLES OUTCOME AND FUP
           outcome = case_when(
             # Case 1: Patients receive treatment within 5 days (scenarios A to E)
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Treated" ~ status_ccw_simple,
             # Case 2: Patients die or are lost to follow-up within 5 days
             # without being treated (scenarios K and L)
             # FIXME: check if we need to make sure here that not treated with pax and alt treatment??
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Untreated" & 
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw <= treatment_window_days ~ status_ccw_simple,
             # Case 3: Patients do not receive treatment within 5 days
             # and are still alive or at risk at 5 days (scenarios F-J and M)
             # --> they don't experience an event and their follow-up time is 5 
             #     days
             treatment_ccw == "Untreated" &
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw > treatment_window_days ~ 0,
             # Case 4: Patients receive paxlovid within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_paxlovid_ccw == "Treated" ~ 0,
             # Case 5: Patients receive alternative treatment within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_alt_ccw == "Treated" ~ 0,
           ),
           fup = case_when(
             # Case 1: Patients receive treatment within 5 days (scenarios A to E)
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Treated" ~ fu_ccw,
             # Case 2: Patients die or are lost to follow-up within 5 days
             # without being treated (scenarios K and L)
             # --> we keep their observed outcomes and follow-up times
             treatment_ccw == "Untreated" &
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw <= treatment_window_days ~ fu_ccw,
             # Case 3: Patients do not receive treatment within 5 days
             # and are still alive or at risk at 5 days (scenarios F-J and M)
             # --> they don't experience an event and their follow-up time is 5 
             #     days
             treatment_ccw == "Untreated" & 
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw > treatment_window_days ~ treatment_window_days,
             # Case 4: Patients receive paxlovid within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_paxlovid_ccw == "Treated" ~ tb_postest_treat_pax_ccw,
             # Case 5: Patients receive alternative treatment within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_alt_ccw == "Treated" ~ tb_postest_treat_alt_ccw,
           ),
           # ADD VARIABLE CENSORING
           censoring = case_when(
             # Case 1: Patients receive treatment within 5 days (scenarios A to E): 
             # --> they are uncensored in the treatment arm and remain at risk of 
             #     censoring until time of treatment
             treatment_ccw == "Treated" ~ 0,
             # Case 2: Patients die or are lost to follow-up within 5 days
             # without being treated (scenarios K and L)
             # --> we keep their follow-up times but they are uncensored
             treatment_ccw == "Untreated" &
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw <= treatment_window_days ~ 0,
             # Case 3: Patients do not receive treatment within 5 days and are 
             # still alive or at risk at 5 days (scenarios F-J and M): 
             # --> they are considered censored and their follow-up time is 5 days
             treatment_ccw == "Untreated" & 
               (treatment_paxlovid_ccw == "Untreated" & treatment_alt_ccw == "Untreated") &
               fu_ccw > treatment_window_days ~ 1,
             # Case 4: Patients receive paxlovid within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_paxlovid_ccw == "Treated" ~ 1,
             # Case 5: Patients receive alternative treatment within 5 days
             # --> they are censored in the treatment group at time of treatment (see fup)
             treatment_alt_ccw == "Treated" ~ 1,
           ),
    )
  ################################################################################
  # Combine to one tibble
  ################################################################################
  data_cloned <- bind_rows(data_control, data_trt) 
  data_cloned
}