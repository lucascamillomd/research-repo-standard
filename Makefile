.DEFAULT_GOAL := help
.PHONY: format format-check help test

PYTHON ?= python3
PRETTIER = npx --yes prettier@3.9.6
MARKDOWN = AGENTS.md README.md SKILL.md references/*.md agents/*.md tests/*.md

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

format: ## Wrap Markdown files
	$(PRETTIER) --write --prose-wrap always --print-width 100 $(MARKDOWN)

format-check: ## Check Markdown formatting without edits
	$(PRETTIER) --check --prose-wrap always --print-width 100 $(MARKDOWN)

test: ## Run documentation-contract tests
	bash tests/consistency_test.sh
	$(PYTHON) tests/consistency_mutations_test.py
	$(PYTHON) tests/simplifier_examples_test.py
	$(PYTHON) -B tests/behavioral_fixture_test.py
