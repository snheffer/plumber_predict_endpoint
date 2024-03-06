# Boilerplate Plumber Inference API for R modelling

This plumber package instantiates an API for inference tasks using R machine learning models.

[1. Endpoints](#endpoints)

[2. ML Object Interfaces](#ml-object-interfaces)

[3. Installation](#installation)

[4. Demonstration](#demonstration)

## Endpoints

---

The API's **/{model_id}/predict** endpoint receives POST requests with an arbitrary number of CSV files, containing predictor variables for each respective sensor type involved in the machine learning pipeline: for example, a pipeline using data from two separate multi-spectral imaging (MSI) sensors would take data from two separate files, in the order expected from the pipeline.

The model triggers the pipeline object's **execute()** method, and takes the CSV's text as sequential input. Data that corresponds to the same sample originating from multiple sensor modalities require matching sample names in the corresponding CSV files.


The **model_id** parameter defines the machine learning model to be queried: if the model is stored locally, it will be accessed from the local fileystem and deserialised from an RDS object - if the model is not found locally, the API attempts to locate the model in the associated S3 bucket defined in the environment config. These S3 models are then cached locally for reuse.
**(*Only configured with the self-hosted S3 server solution Minio*)**

---

The **/{model_id}/dimensions** endpoint receives GET requests, and responds with the dimensions of the file(s)/data expected from the machine learning model corresponding to **model_id**. This information is accessed in the web API by calling the pipeline object's **dimensions()** method.

---

The **/{model_id}/columnnames** endpoint receives GET requests, and responds with the column names of the training data or representative file(s) associated with the machine learning pipeline.

---

The **/plumber/healthcheck** GET endpoint returns the status OK-200 if the plumber server is determined to be operating normally.

---

## ML Object Interfaces


The R Script/Pipeline exchange makes use of [R6 Objects](https://r6.r-lib.org/articles/Introduction.html), which are used to encapsulate all of the methods required for inference tasks.

The single required method of the class is **execute(*file_list*)**, where *file_list* represents the list of CSV files uploaded as part of the multipart POST request.
The output for the method is currently arbitrary, and represents the inference outcome from whatever machine learning algorithm is used in the model.

The class itself calls an internally held copy of the machine learning model(s) themselves created during the class build process, and is held in the "***models***" property.

The execute() method calls the internally held model list's ***pre_proc(self$models, file)*** sequentially on the input data, and then the ***main_proc(self$models, transformed_file_list)*** method, which performs the pipeline tasks.
Self is passed to the method to give it a reference to the model list itself, a limitation that may be solved using a different model storage model.

A demonstration of a script that builds a compatible inference object is contained within the *demo_model_configuration* directory.


## Installation

*Requirements:*
- R 4.3.2
- R Packages described in renv.lock file
- make
- S3 implementation (tested only on [Minio](https://min.io/))
- docker (if necessary)

There is a "run_plumber" directive in the associated makefile, assuming that all dependencies are installed.

Dependencies have been managed with [renv](https://cran.r-project.org/web/packages/renv/vignettes/renv.html). This may take some additional configuration.
In order to do so access an R session in the project directory, and run "Renv::restore()" to restore the necessary packages.

There is an associated Docker image, however I have not had time to make this work properly. Feel free to attempt to fix.

## Demonstration

Within the "demo_model_configuration" directory, there is a script named build_demo_model_object.R, which when run using the makefile directive "build_demo_model", will generate an ML object in the "endpoint/demo_models" directory, with an ID corresponding to the current date (YYYYmmdd).

This ID can then be referenced in ML demonstration tasks, and corresponds to the demonstration MSI and FTIR data provided in the demo_model_configuration/demo_sensor_files directory. 