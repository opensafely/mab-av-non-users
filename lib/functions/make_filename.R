make_filename <- function(object_name, period, outcome, contrast, type){
  paste0(period[period != "ba1"],
         "_"[period != "ba1"],
         object_name,
         "_",
         contrast %>% tolower(),
         "_"[outcome != "primary"],
         outcome[outcome != "primary"],
         ".",
         type)
}