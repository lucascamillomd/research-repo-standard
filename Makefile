.DEFAULT_GOAL := help
.PHONY: help test

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

test: ## Run vendor.sh, version-stamp, and doc-consistency tests
	bash tests/vendor_test.sh
	bash tests/consistency_test.sh
