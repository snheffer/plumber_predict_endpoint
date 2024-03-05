library("dplyr")
drop_NAs_join <- function (read_files, predictor_vector=NULL){
  #Drop rows with NAs from each data table
  cleaned_tables <- lapply(read_files, function(dt) na.omit(dt))
  #Join data tables by sample name
  merged_data <- cleaned_tables %>%
    Reduce(function(x, y) left_join(x,y, colnames(x)[[1]]), .)
  if(!is.null(predictor_vector)){
    merged_data <- left_join(merged_data, predictor_vector, by=colnames(merged_data)[[1]])
  }
  # print(merged_data)
  return(merged_data)
}