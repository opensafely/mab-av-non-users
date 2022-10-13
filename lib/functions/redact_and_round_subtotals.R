################################################################################
# Redaction for subtotals
#
# When redacting <=7 and rounding to nearest 5, if one of subtotals is redacted,
# other subtotal need to be redacted as well if rounded subtotal is equal to 
# rounded grand total. This function sorts that out.
################################################################################
redact_and_round_subtotals <- function(total,
                                       subtotal1,
                                       subtotal2,
                                       redaction_level = 7,
                                       round_to = 5){
  if (total == "[REDACTED]"){
    # if total is redacted, redact subtotals
    # to accommodate use of function twice (if more levels of subtotals are 
    # reported)
    total_rounded <- "[REDACTED]"
    subtotal1_rounded <- "[REDACTED]"
    subtotal2_rounded <- "[REDACTED]"
  } else { # if total is not redacted, check if subtotals need to be redacted
    # prepare rounded counts
    total_rounded <- plyr::round_any(total, round_to)
    subtotal1_rounded <- plyr::round_any(subtotal1, round_to)
    subtotal2_rounded <- plyr::round_any(subtotal2, round_to)
    if (total > 0 & total <= redaction_level) {
      total_rounded <- "[REDACTED]"
      subtotal1_rounded <- "[REDACTED]"
      subtotal2_rounded <- "[REDACTED]"
    } else if (subtotal1 > 0 & subtotal1 <= redaction_level){
      subtotal1_rounded <- "[REDACTED]"
      if (subtotal2 <= redaction_level){
        subtotal2_rounded <- "[REDACTED]"
      } #else if (total_rounded == subtotal2_rounded){
        #subtotal2_rounded <- "[REDACTED]"
      #}
    } else if (subtotal2 > 0 & subtotal2 <= redaction_level){ # subtotal1 not <= redaction_level
      subtotal2_rounded <- "[REDACTED]"
      #if (total_rounded == subtotal1_rounded){
        #subtotal1_rounded <- "[REDACTED]"
      #}
    }
  }
  return(c(total_rounded,
           subtotal1_rounded,
           subtotal2_rounded))
}




