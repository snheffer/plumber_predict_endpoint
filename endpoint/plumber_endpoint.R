library(plumber)
library(R6)
library(future)
library(dplyr)
library("aws.s3")
# library(caret)
utilities <- new.env()
sys.source("./utilities/utilities_v2.R", envir = utilities, toplevel.env = utilities)

###Print S3 Bucket List
print(aws.s3::bucketlist(use_https=F, url_style="path", region=""))

print(env_var)

api_error <- function(message, status) {
  err <- structure(
    list(message = message, status = status),
    class = c("api_error", "error", "condition")
  )
  signalCondition(err)
}

# Load the serialized model from S3
download_and_load_model <- function(url) {
  temp_file <- tempfile(fileext = ".rds")
  download.file(url, temp_file)
  loaded_model <- readRDS(temp_file)
  return(loaded_model)
}

# Find Model In Local Persistent Volume, Otherwise download from S3. No permission
# needed here, as this is handled by upstream API (sorfml-spring-api).

find_or_download_model <- function(file_id, local_dir, s3_bucket = NULL, s3_endpoint = NULL, s3_access_key, s3_secret_key) {

  
  # Check if the file exists in the local directory
  local_path <- file.path(local_dir, file_id)
  if (file.exists(local_path)) {
    print("Local Path: ")
    print(local_path)
    return(readRDS(file=local_path))
  }
  
  # If S3 bucket and endpoint are provided, attempt to download from S3
  if (!is.null(s3_bucket) && !is.null(s3_endpoint)) {
    tryCatch({
      if(aws.s3::object_exists(file_id, s3_bucket, use_https=F, region="")){
        aws.s3::save_object(object = file_id, bucket = s3_bucket, file = local_path, use_https=F, region="")
        print("Reading from s3...")
        print(local_path)
      }
      return(readRDS(file=local_path))
    }, error = function(e) {
      api_error(message = "File Not Found Locally or on S3", 404)
    })
  }
  
  api_error(message = "RDS file not found in local directory or on S3.", 404)
}

# 
# ##Detach non-core packages:
detachAllPackages <- function() {

  basic.packages <- c("package:stats","package:graphics","package:grDevices","package:utils","package:datasets","package:methods","package:base")

  package.list <- search()[ifelse(unlist(gregexpr("package:",search()))==1,TRUE,FALSE)]

  package.list <- setdiff(package.list,basic.packages)

  if (length(package.list)>0)  for (package in package.list) detach(package, character.only=TRUE)

}
  
# detachAllPackages()


# TODO: Finish definition of this route. Probably not necessary as main use as inference API.
# Define the plumber API
#* @apiTitle BoilerPlate ML Prediction API
#* @apiDescription An API for serving a serialized model
#* @apiParam url The URL of the serialized model

#* @param file_list:[file]
#* @param predictor:name

#* @post /train
function(file_list, predictor=NULL) {
  read_files<- list()
  for (i in 1:length(file_list)){
    read_files[[names(file_list)[i]]]<- read.table(text = file_list[[i]], sep =",", header = TRUE, stringsAsFactors = FALSE)
    if (!is.null(predictor)){
      read_files[[names(file_list)[i]]]<-read_files[[names(file_list)[i]]][,!names(read_files[[names(file_list)[i]]]) %in% 
                                                                             c(predictor)]
    }  
  }
  prediction <- "SamplePredictionResult"
  
  return(list(prediction = prediction, read_files = read_files, body = body))
}

# Define the Plumber API using annotations
#* @post /predict/<file_id>
#* @param file_list:[file]
#* @param file_id:string ID or name of the RDS file
#* @serializer unboxedJSON
#* @response 403 Forbidden
#* @response 404 Not Found
#* @response 400 Bad Request
function(res, req, file_list=NA, file_id) {
  print("file_list digest:")
  print(digest::digest(file_list, algo = "md5"))
  future::future({
    if(identical(file_list, NA)){
      return(api_error(message = "No Files Supplied.", 400))
    }
    loaded_model <- list()
    predictor <- NULL
    loaded_model <- find_or_download_model(file_id, env_var$model_local_dir, env_var$model_s3_bucket, env_var$model_s3_endpoint, env_var$s3_accesskey, env_var$s3_secretkey)
    
    # result <- loaded_model$new()$execute(file_list)
    # print(result)
    # (c(result))
    result <- tryCatch(
      {
        result <- loaded_model$new()$execute(file_list)
      },
      error = function(e) {
        print(e)
        print(traceback(e, 10))
          api_error(message = "An error occurred with your request.", 404)
      }
    )
  })
}

#* @get /predict/<file_id>/dimensions
#* @param file_id:string ID or name of the RDS file
#* @serializer json
#* @response 403 Forbidden
#* @response 404 Not Found
function(req, res, file_id) {
  future::future({
    loaded_model <- list()
    loaded_model <- find_or_download_model(file_id, env_var$model_local_dir, 
                                           env_var$model_s3_bucket, env_var$model_s3_endpoint, 
                                           env_var$s3_accesskey, env_var$s3_secretkey)
    
    dimensions <- loaded_model$new()$data_dimensions
    return((dimensions))
  })
}

#* @get /predict/<file_id>/columnnames
#* @param file_id:string ID or name of the RDS file
#* @serializer json
#* @response 403 Forbidden
#* @response 404 Not Found
function(req, res, file_id) {
  future::future({
    loaded_model <- list()
    loaded_model <- find_or_download_model(file_id, env_var$model_local_dir, 
                                           env_var$model_s3_bucket, env_var$model_s3_endpoint, 
                                           env_var$s3_accesskey, env_var$s3_secretkey)
    
    colnames <- loaded_model$new()$data_colnames
    return((colnames))
  })
}

