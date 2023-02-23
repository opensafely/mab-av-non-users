make_filename <- function(object_name, period, outcome, contrast, subgrp, supp, type){
  file_name <- 
    paste0(
      period[period != "ba1"],
      "_"[period != "ba1"],
      object_name,
      "_",
      contrast %>% tolower(),
      "_"[outcome != "primary"],
      outcome[outcome != "primary"],
      "_"[subgrp != "full"],
      subgrp[subgrp != "full"],
      "_"[supp != "main"],
      supp[supp != "main"],
      ".",
      type)
  if (supp != "main"){
    file_name <- 
      fs::path(supp, file_name)
  }
  if(subgrp != "full"){
    file_name <-
      fs::path(subgrp, file_name)
  }
  file_name
}
