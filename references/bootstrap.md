---
name: standard-bootstrap
description: Concrete tool configuration to write when a repository does not yet have it — uv, Ruff, ty, pre-commit, CI guards, Makefile skeleton. Read when creating these files; once they exist they are the source of truth and this document is history.
standard_version: 2026.07.25
---

# Bootstrap: tool configuration

Everything here describes files that do not exist yet. **Once written, those files are
the source of truth** — read `pyproject.toml`, not this document.

## Environment

Select a currently supported stable Python minor during the interview. Record it in
both `.python-version` and `project.requires-python`. Do not carry a stale version
forward from a previous project.

uv manages all ordinary Python operations:

```bash
uv init
uv add <package>          uv remove <package>
uv lock                   uv sync --locked
uv run --locked <command> uv build
```

No direct `pip install`, Poetry, Pipenv, or Conda for the primary environment. An
incompatible upstream model or tool may use an explicitly isolated environment only
when the limitation and the exact invocation are documented.

Commit `uv.lock`; never hand-edit it. Declare meaningful compatibility bounds in
`pyproject.toml`. Use exact top-level pins only for demonstrated compatibility,
serialization, binary, or model constraints.

Use Hatchling and the `src/<package_name>` layout unless there is a documented reason
for another PEP 517 backend.

```toml
[dependency-groups]
dev = ["coverage", "pre-commit", "pytest", "ruff", "ty"]
```

## Ruff

Line length 100. Stable rules only — do not enable all rules indiscriminately, do not
enable preview rules, and avoid rules that conflict with the formatter.

```toml
[tool.ruff]
line-length = 100
target-version = "py311"          # match .python-version

[tool.ruff.lint]
# pycodestyle (E, W) + pyflakes (F) + import sorting (I) + pydocstyle (D)
# + modernization (UP) + likely bugs (B) + Ruff correctness (RUF)
select = ["E", "W", "F", "I", "D", "UP", "B", "RUF"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.format]
quote-style = "double"
```

Allow only safe automatic fixes globally. An inline suppression must be narrow and
explained when the reason is not obvious. A repository-wide ignore requires a comment
in `pyproject.toml` giving the reason.

## Type checking

```toml
[tool.ty.environment]
python-version = "3.11"

[tool.ty.src]
include = ["src", "scripts", "tests"]
```

Apply practical, documented per-file exceptions for scientific dependencies with
incomplete type information rather than disabling type checking globally.

## Pre-commit

```bash
uv run --locked pre-commit install
```

Required hooks: Ruff safe lint fixes, Ruff formatting, trailing-whitespace removal,
end-of-file normalization, YAML and TOML validation, merge-conflict detection,
private-key detection, and a configurable large-file guard.

Use **local** Ruff hooks that call `uv run --locked ruff ...` so there is not a second
independently pinned Ruff version. Generic non-Python hooks may use pinned upstream
hook repositories.

Do not run pytest or the full test suite in pre-commit. Tests belong in Make and CI.

## CI lockfile guard

```bash
uv lock --check     # project metadata vs lockfile
uv sync --locked    # lockfile vs environment
```

`--frozen` alone is insufficient: it skips the metadata comparison, so CI passes while
`pyproject.toml` and `uv.lock` disagree.

## Makefile skeleton

`help` is the default goal; every target carries a `##` description.

```make
.DEFAULT_GOAL := help

help:        ## Show this help
setup:       ## Create the locked environment and install pre-commit hooks
format:      ## Format with Ruff
lint:        ## Lint with Ruff
typecheck:   ## Static type-check with ty
test:        ## Run the Python test suite
test-r:      ## R tests in the container (say so here when R is unused)
analysis:    ## Primary, sensitivity, and derived tables from the checkpoint
figures:     ## Figure source data and every declared atomic panel
reports:     ## Machine-generated reports under results/reports/
all:         ## Light path from the smallest distributable checkpoint
full:        ## Longest raw-to-publication path; reports manual boundaries
verify-ci:   ## Data-free, or approved fixtures only
verify-full: ## Complete workflow with real data
clean-*:     ## Remove only the named generated outputs
```

Beyond `help`, `setup`, `test`, and a verification gate, name targets to fit the
project. Never define a cleanup target that can reach `data/raw/`.

Make may use phony high-level targets without pretending to offer file-level
incrementality. Add real file dependencies only when they are reliable.

## Configuration and secrets

TOML for packaging and tool configuration; YAML for dataset and analysis registries.
Configuration loaders reject or explicitly handle unknown fields and fail clearly on
missing required ones.

Create `.env.example` only when the project consumes environment variables. It lists
variable names with safe descriptions or placeholders and never contains real values.
The real `.env` is gitignored.

## Containers

Put language- or purpose-specific containers under `docker/<language-or-tool>/`. For R:
pin the base image by immutable digest when feasible, constrain packages with
`renv.lock`, document CRAN/Bioconductor and system-library limitations, expose build
and execution through Make and a checked-in wrapper, and mount only required
directories. Use `testthat` for reusable R logic, run via `make test-r`.

Do not create a dedicated R package by default. R code stays minimal and may live in
its numbered `scripts/` stage.

## README

Keep it concise: research question and one-paragraph scope, compact repository map,
prerequisites, shortest setup and reproduction commands, expected results, external
data and tool limitations, the reproducibility classification, and links to `docs/`.
