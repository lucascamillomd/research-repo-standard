.DEFAULT_GOAL := help
.PHONY: format help test

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

format: ## Wrap Markdown files
	npx --yes prettier@3.9.6 --write --prose-wrap always --print-width 100 AGENTS.md README.md SKILL.md references/*.md agents/*.md

test: ## Run adapter and documentation-contract tests
	bash tests/adapter_test.sh
	bash tests/adapter_safety_test.sh
	bash tests/consistency_test.sh
