#### Example file showing possible model structure:
##Detach non-core packages:
detachAllPackages <- function() {

  basic.packages <- c("package:stats","package:graphics","package:grDevices","package:utils","package:datasets","package:methods","package:base")

  package.list <- search()[ifelse(unlist(gregexpr("package:",search()))==1,TRUE,FALSE)]

  package.list <- setdiff(package.list,basic.packages)

  if (length(package.list)>0)  for (package in package.list) detach(package, character.only=TRUE)

}
#### INIT
# library(waves)
library(knitr)
library(ggplot2)
library(ggpubr)
library(reshape2)
library(stringr)
library(dplyr)
# library(pls)
# library(caret)
library(splitstackshape)
library(gridExtra)
# library(pls)

get_file_info <- function(file_path) {
  # Read the data from the file
  data <- read.csv(file_path, header = TRUE)  # Assuming CSV format
  
  # Get column names
  column_names <- colnames(data)
  # Get dimensions
  num_rows <- nrow(data)
  num_cols <- ncol(data)
  
  # Return the column names and dimensions
  return(list(column_names = column_names, num_rows = num_rows, num_cols = num_cols))
}

### Variadic arguments refer to representative files referenced by the machine learning pipeline.
r6_wrapper <- function(model_path,...){
  data_dimensions <- list()
  data_colnames <- list()
  variadic_args <- list(...)

  # Loop over the variadic arguments
  for (arg in variadic_args) {
    file_info <- get_file_info(arg)
    file_dim <- c(file_info$num_rows, file_info$num_cols)
    data_dimensions <- c(data_dimensions, list(file_dim))
    data_colnames <- c(data_colnames, list(file_info$column_names))
  }
  # Load the required library in the custom namespace
  model_class <- R6::R6Class(
    "model_class", 
    public = list(
      initialize = function(model_location){
      },
      class_ns = list(predict.mvr=pls:::predict.mvr),
      models = (readRDS(model_path)),
      test_value = "TestValue",
      test = function(){
        cat("THE TEST VALUE IS: ")
        print(self$data_dimensions); cat("\n")
      },

      ### Set Data Dimensions Here:
      data_dimensions = data_dimensions,
      data_colnames = data_colnames,

      execute = function(file_list){
        read_files<- list()
        transformed_files<- list()
        for (i in 1:length(file_list)){
          read_files[[names(file_list)[i]]]<- read.table(text = file_list[[i]], sep =",", header = TRUE, stringsAsFactors = FALSE, row.names = NULL)
          colnames(read_files[[names(file_list)[i]]])
            # colnames(read_files[[names(file_list)[i]]])[1]<-"Sample"
          ###Restrict Data to training colnames:
          read_files[[names(file_list)[i]]] <- read_files[[names(file_list)[i]]][, (colnames(read_files[[names(file_list)[i]]]) %in% data_colnames[[i]]), drop = FALSE]

          ###transform raw files to transformed state.
          cat("Executing File PreProc\n")
          # cat("Model Object:\n")
          # print(self$models)
          transformed_files[[i]]<-self$models$pre_proc[[i]](self$models, read_files[[i]])
        }
        model_metadata<- list()
        model_metadata$xlabels<-list()
        print("\n")
        ### TODO: Passing the reference to self in the main proc method doesnt seem ideal, however,
        ### the wrapped models from the machine learning script are implemented in a list, and have 
        ### no way of accessing "self", i.e. the other members of the list. I could implement the 
        ### "models" member an R6 object, however I have not tried this yet.
        return(as.data.frame(self$models$main_proc(self$models, transformed_files)))
      }
    ),
  )
  return(model_class)
}

#### Save the Demo Model Object RDS.
model_class<-r6_wrapper("PATH_TO_MACHINE_LEARNING_MODELS", "path_to_representative_file_A", "path_to_representative_file_B")
### Test the model.
model_class$new()$test()

saveRDS(model_class, "NAME/OF/SERIALISED/OBJECT/HERE.RDS")

