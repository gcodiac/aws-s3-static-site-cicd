# Cloud Launchpad — preview the site locally
#
#   make serve

.PHONY: serve

serve: ## Preview the site on http://localhost:8080
	python3 -m http.server 8080
