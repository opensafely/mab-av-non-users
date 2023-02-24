determine_output_dir <- function(dir, model){
  if(model != "cox") dir <- fs::path(dir, model)
  dir
}
determine_sub_dir <- function(dir, subgrp, supp){
  if(subgrp != "full") dir <- fs::path(dir, subgrp)
  if (supp != "main") dir <-fs::path(dir, supp)
  dir
}
concat_dirs <- function(dir, output_dir, model, subgrp, supp){
  output_dir <- determine_output_dir(output_dir, model)
  sub_dir <- determine_sub_dir(dir, subgrp, supp)
  fs::path(output_dir, sub_dir)
}