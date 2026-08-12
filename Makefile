.DEFAULT_GOAL := help
.PHONY: help format lint test check

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

format: ## Format Markdown and shell files
	bash tools/quality.sh format

lint: ## Check Markdown, shell, frontmatter, and whitespace
	bash tools/quality.sh lint
	bash tests/quality_test.sh

test: ## Run vendoring, adapter, documentation-contract, and quality tests
	bash tests/vendor_test.sh
	bash tests/adapter_test.sh
	bash tests/consistency_test.sh
	bash tests/quality_test.sh

check: ## Run every non-mutating repository check
	bash tools/quality.sh check
