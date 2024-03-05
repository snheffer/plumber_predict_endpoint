#!/usr/bin/env Rscript
library(plumber)
library(logger)
library(tictoc)

### Uncomment these for running the script interactively.
# Sys.setenv(
#   MODEL_LOCAL_DIR="./demo_models",
#   MODEL_S3_BUCKET="models-v1",
#   MODEL_S3_ENDPOINT="localhost:8999",
#   S3_ACCESSKEY="minioadmin",
#   S3_SECRETKEY="minioadmin"
# )

# Check if required environment variables are present
required_vars <- c("MODEL_LOCAL_DIR", "MODEL_S3_BUCKET", "MODEL_S3_ENDPOINT", "S3_ACCESSKEY", "S3_SECRETKEY", "PORT")
missing_vars <- setdiff(required_vars, names(Sys.getenv()))

if (length(missing_vars) > 0) {
  warning("Missing required environment variable(s):", paste(missing_vars, collapse = ", "), "\n")
  # cat("Missing required environment variable(s):", paste(missing_vars, collapse = ", "), "\n")
  q(status = 2)
}



env_var <- list()
env_var$model_local_dir <- Sys.getenv()[["MODEL_LOCAL_DIR"]]
env_var$model_s3_bucket <- Sys.getenv()[["MODEL_S3_BUCKET"]]
env_var$model_s3_endpoint <- Sys.getenv()[["MODEL_S3_ENDPOINT"]]
env_var$s3_accesskey <- Sys.getenv()[["S3_ACCESSKEY"]]
env_var$s3_privatekey <- Sys.getenv()[["S3_SECRETKEY"]]
env_var$port <- Sys.getenv()[["PORT"]]

###Set Envs for S3 Compatibility.
Sys.setenv(
  "AWS_ACCESS_KEY_ID" = Sys.getenv()[["S3_ACCESSKEY"]],
  "AWS_SECRET_ACCESS_KEY" = Sys.getenv()[["S3_SECRETKEY"]],
  "AWS_S3_ENDPOINT" = Sys.getenv()[["MODEL_S3_ENDPOINT"]],
  "AWS_DEFAULT_REGION" = ""
)


convert_empty <- function(string) {
  if (string == "") {
    "-"
  } else {
    string
  }
}

# Specify how logs are written 
if("LOG_DIR" %in% names(Sys.getenv())){
  logger::log_appender(logger::appender_tee(tempfile("plumber_", config$log_dir, ".log")))
} else {
  logger::log_appender(logger::appender_stdout)
}
  
#* @response 403 Not Authorized
#* @response 404 Not Found
# Custom Error Handler:
error_handler <- function(req, res, err) {
  if (!inherits(err, "api_error")) {
    traceback(3)  # Use traceback(2) to print the full stack trace
    res$status <- 500
    res$body <- "{\"status\":500,\"message\":\"Internal server error.\"}"
    
    # Print the internal error so we can see it from the server side. A more
    # robust implementation would use proper logging.
    print("INTERNAL ERROR:")
    print(err)
  } else {
    print("CUSTOM ERROR:")
    print(err)
    # We know that the message is intended to be user-facing.
    res$status <- err$status
    res$serializer <- serializer_unboxed_json()
    res$setHeader("Content-Type", "application/json")
    res$body <- sprintf(
      "{\"status\":%d,\"message\":\"%s\"}", err$status, err$message
    )
  }
  res
}

serializer_switch <- function() {
  function(val, req, res, errorHandler) {
    tryCatch({
      format <- attr(val, "serialize_format")
      print("Format:")
      print(format)
      if (is.null(format) || format  == "json" || format == "character") {
        type <- "application/json"
        sfn <- jsonlite::toJSON
      } else if (format == "csv") {
        type <- "text/csv; charset=UTF-8"
        sfn <- readr::format_csv
      } else if (format == "rds") {
        type <- "application/rds"
        sfn <- function(x) base::serialize(x, NULL)
      }
      val <- sfn(val)
      res$setHeader("Content-Type", type)
      res$body <- val
      res$toResponse()
    }, error = function(err) {
      errorHandler(req, res, err)
    })
  }
}

plumber::register_serializer("switch", serializer_switch)

tryCatch(
  #try to do this
  {
    pr <- plumber::plumb("./plumber_endpoint.R")
    pr$setErrorHandler(error_handler)
    pr$registerHooks(
      list(
        preroute = function() {
          # Start timer for log info
          tictoc::tic()
        },
        postroute = function(req, res) {
          end <- tictoc::toc(quiet = TRUE)
          # Log details about the request and the response
          # TODO: Sanitize log details - perhaps in convert_empty
          logger::log_info('{convert_empty(req$REMOTE_ADDR)} "{convert_empty(req$HTTP_USER_AGENT)}" {convert_empty(req$HTTP_HOST)} {convert_empty(req$REQUEST_METHOD)} {convert_empty(req$PATH_INFO)} {convert_empty(res$status)} {round(end$toc - end$tic, digits = getOption("digits", 5))}')
        }
      )
    )
    pr$handle("GET", "/plumber/healthcheck", function(req, res) {
      res$setHeader("Content-Type", "application/json")
      res$status <- 200L
      res$body <- ""
      res
    })
    ###Add specific examples to certain routes:
    # pr$setApiSpec(function(spec) {
    #   spec$paths$`//predict/<file_id>/dimensions`$get$responseBody$content$`application/json`$schema$properties$example <- list(a = 2, b = 3, c = 4)
    #   spec
    # })
    plumber::pr_run(pr, host = "0.0.0.0", port = as.numeric(env_var$port))
  },
  #if an error occurs, log it and quit:
  error=function(e) {
    warning('An Error Occurred in endpoint definition file:')
    print(e)
    q(status=2)
  }
)




