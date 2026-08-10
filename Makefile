.DEFAULT_GOAL := help
.PHONY: help test

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

test: ## Run vendor.sh and version-stamp tests
	bash tests/vendor_test.sh
