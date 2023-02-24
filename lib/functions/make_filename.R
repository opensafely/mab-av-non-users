make_filename <- function(object_name, period, outcome, contrast, model, subgrp, supp, type){
  file_name <- 
    paste0(
      period[period != "ba1"],
      "_"[period != "ba1"],
      object_name,
      "_",
      contrast %>% tolower(),
      "_"[outcome != "primary"],
      outcome[outcome != "primary"],
      "_"[model != "cox"],
      outcome[model != "cox"],
      "_"[subgrp != "full"],
      subgrp[subgrp != "full"],
      "_"[supp != "main"],
      supp[supp != "main"],
      ".",
      type)
  file_name
}
