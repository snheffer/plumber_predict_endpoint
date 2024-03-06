build_docker:
	docker build . --tag snheffer/sorfml-plumber-api:$(VER)
incremental_build_docker:
	docker build -t snheffer/sorfml-plumber-api:$(docker images | awk '($1 == "snheffer/sorfml-plumber-api") {print $2 += .01; exit}') .

NAME =date '%Y%m%d'

build_demo_model:
	cd ../demo_model_configuration/ && Rscript build_demo_model_object.R
run_plumber:
	RENV_CONFIG_SANDBOX_ENABLED=FALSE MODEL_LOCAL_DIR=./demo_models MODEL_S3_BUCKET=models-v1 MODEL_S3_ENDPOINT=localhost:8999 S3_ACCESSKEY=minioadmin S3_SECRETKEY=minioadmin PORT=4545 ./entrypoint.R


