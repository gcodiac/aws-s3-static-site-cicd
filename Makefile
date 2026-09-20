# Cloud Launchpad — deploy the site straight to S3
#
#   make serve
#   make deploy BUCKET=my-bucket

.PHONY: serve deploy

serve: ## Preview the site on http://localhost:8080
	python3 -m http.server 8080

deploy: ## Sync the site to S3
	aws s3 sync . s3://$(BUCKET) --delete \
		--exclude ".git/*" --exclude ".github/*" --exclude ".gitignore" \
		--exclude "docs/*" --exclude "Makefile" --exclude "README.md" --exclude "LICENSE"
