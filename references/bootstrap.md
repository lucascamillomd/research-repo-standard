<!-- standard_version: 2026.08.10 -->

# Bootstrap: tool configuration

Concrete tool configuration — uv, Ruff, ty, pre-commit, CI guards, Makefile
skeleton — to write when a repository does not yet have it. Everything here
describes files that do not exist yet. **Once written, those files are the source
of truth** — read `pyproject.toml`, not this document.

## Agent-skill preflight

Before the interview, scaffolding, Python selection, or tool configuration, run the
discovery procedure defined in `references/prerequisites.md` once in the current agent
session. All three exact skill names must resolve. If any name does not resolve, stop
before the interview and report the exact blocker. Do not scaffold, select Python,
write tool configuration, or run `make setup`.

For this preflight, a session is one continuous top-level agent context. An agent-host
restart or reload, or a fresh top-level context, starts a new session and repeats
discovery. Context compaction or an in-plan subagent dispatch does not create a new
session, so do not repeat bootstrap discovery for either. Each subagent must still
resolve and invoke the skill it is assigned to apply.

After preflight, bootstrap invokes all three skills in their declared design stages,
including `scientific-critical-thinking` through an independent-subagent scientific
critique.

Agent skills are not uv dependencies. The generated `make setup` target creates the
locked project environment and installs pre-commit hooks; it does not install or
validate global agent skills.

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
standard-check: ## Report drift against the research-repo-standard source
clean-*:     ## Remove only the named generated outputs
```

Beyond `help`, `setup`, `test`, and a verification gate, name targets to fit the
project. Never define a cleanup target that can reach `data/raw/`.

Make may use phony high-level targets without pretending to offer file-level
incrementality. Add real file dependencies only when they are reliable.

`standard-check` calls the standard's own tooling:

````make
STANDARD_SRC ?= $(HOME)/.claude/skills/research-repo-standard

standard-check: ## Report drift against the research-repo-standard source
	@test -x "$(STANDARD_SRC)/vendor.sh" \
	  || { echo "standard source not found at $(STANDARD_SRC); cannot check"; exit 2; }
	"$(STANDARD_SRC)/vendor.sh" --check .
````

`vendor.sh --check` exits 0 when the vendored `AGENTS.md` matches a fresh
vendor (the `## This repository` section is preserved and never counts as
drift) and `CLAUDE.md` is a symlink to it, 1 when drifted, and 2 when there is
no `AGENTS.md` to check. Note that `make` collapses any failing recipe to its
own exit 2, so branch on `vendor.sh --check` directly when the distinction
matters.

## Configuration and secrets

Read `references/configuration.md` before creating YAML, `config.py`, `paths.py`, CLI
overrides, or configuration provenance. TOML remains the source of truth for packaging
and tool configuration. Create mandatory `config/datasets.yaml` and
`config/analysis.yaml`; create `config/runtime.yaml` only when stable operational
settings exist and their result-equivalence rationale is recorded in
`docs/DECISIONS.md`.

Put every stable scientific or result-affecting value explicitly in
`config/analysis.yaml`. Put only proven result-equivalent performance and resilience
settings in optional `config/runtime.yaml`. Do not create an empty runtime file.
`config.py` validates strict typed schemas and contains no project values or hidden
result-affecting defaults. `paths.py` derives internal paths and reads permitted
machine-specific roots from environment variables.

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

## Code-simplifier profile

Create `.claude/agents/code-simplifier.md` in the new repository by copying the
canonical profile from the standard's `agents/code-simplifier.md`. The Working
procedure in `AGENTS.md` requires a code-simplifier subagent pass after
code-changing modifications; the copied profile is what that subagent applies.

## README

Keep it concise: research question and one-paragraph scope, compact repository map,
project prerequisites including the selected Python minor, uv, and Make; the three
required agent skills with a link to the canonical prerequisite contract at
<https://github.com/lucascamillomd/research-repo-standard/blob/main/references/prerequisites.md>;
shortest project setup and reproduction commands, expected results, external data and
tool limitations, the reproducibility classification, and links to `docs/`. Distinguish
agent-host prerequisites from project tools and packages installed by `make setup`.
