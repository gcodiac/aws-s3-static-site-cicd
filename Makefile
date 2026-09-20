# Cloud Launchpad — deploy the site to S3 with Terraform
#
#   make serve
#   make init
#   make deploy BUCKET=my-bucket
#   make destroy BUCKET=my-bucket

.PHONY: serve init deploy destroy

serve: ## Preview the site on http://localhost:8080
	python3 -m http.server 8080

init: ## Download the Terraform providers
	terraform -chdir=infra init

deploy: ## Create the bucket and upload the site
	terraform -chdir=infra apply -var bucket_name=$(BUCKET)

destroy: ## Delete the bucket and everything in it
	terraform -chdir=infra destroy -var bucket_name=$(BUCKET)
