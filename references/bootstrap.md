<!-- standard_version: 2026.08.13 -->

# Bootstrap: tool configuration

Concrete tool configuration — uv, Ruff, ty, pre-commit, CI guards, Makefile skeleton — to write when
a repository does not yet have it. Everything here describes files that do not exist yet. **Once
written, those files are the source of truth** — read `pyproject.toml`, not this document.

## Agent-host prerequisites

Before the interview, use the host-native resolver to confirm the three exact required skill names.
This preflight is name-resolution only. Use the installation or recovery procedure in
`references/prerequisites.md` only if a name is missing, and never install silently or substitute a
different workflow. Agent-host prerequisites remain separate from the generated repository's
`make setup`.

## Environment

Select a currently supported stable Python minor during the interview. Record it in both
`.python-version` and `project.requires-python`. Do not carry a stale version forward from a
previous project.

uv manages all ordinary Python operations:

```bash
uv init
uv add <package>          uv remove <package>
uv lock                   uv sync --locked
uv run --locked <command> uv build
```

No direct `pip install`, Poetry, Pipenv, or Conda for the primary environment. An incompatible
upstream model or tool may use an explicitly isolated environment only when the limitation and the
exact invocation are documented.

Commit `uv.lock`; never hand-edit it. Declare meaningful compatibility bounds in `pyproject.toml`.
Use exact top-level pins only for demonstrated compatibility, serialization, binary, or model
constraints.

Use Hatchling and the `src/<package_name>` layout unless there is a documented reason for another
PEP 517 backend.

```toml
[dependency-groups]
dev = ["pre-commit", "pytest", "ruff", "ty"]
```

`loguru` is a runtime dependency, not a dev one — stage logging is part of the pipeline. Configure
sinks in the stage script, not in `src/`: library code calls `logger.<level>()` and leaves sink
configuration to the caller, so importing the package never installs a handler. A stage's entry
point removes the default sink and adds its own, one console sink and one file sink under `logs/`:

```python
logger.remove()
logger.add(sys.stderr, level=os.environ.get("LOG_LEVEL", "INFO"))
logger.add(paths.LOGS / "02_fit_{time}.log", level="DEBUG", rotation="20 MB")
```

Verbosity is operational, so an environment variable may set it; nothing else about logging is
configurable and no scientific setting is ever read from `LOG_LEVEL`.

## Ruff

Line length 100. Stable rules only — do not enable all rules indiscriminately, do not enable preview
rules, and avoid rules that conflict with the formatter.

```toml
[tool.ruff]
line-length = 100
target-version = "py3XY"          # match .python-version

[tool.ruff.lint]
# pycodestyle (E, W) + pyflakes (F) + import sorting (I) + pydocstyle (D)
# + modernization (UP) + likely bugs (B) + Ruff correctness (RUF)
select = ["E", "W", "F", "I", "D", "UP", "B", "RUF"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.format]
quote-style = "double"
```

Allow only safe automatic fixes globally. An inline suppression must be narrow and explained when
the reason is not obvious. A repository-wide ignore requires a comment in `pyproject.toml` giving
the reason.

## Type checking

```toml
[tool.ty.environment]
python-version = "3.XY"

[tool.ty.src]
include = ["src", "scripts", "tests"]
```

Apply practical, documented per-file exceptions for scientific dependencies with incomplete type
information rather than disabling type checking globally.

## Pre-commit

```bash
uv run --locked pre-commit install
```

Required hooks: Ruff safe lint fixes, Ruff formatting, trailing-whitespace removal, end-of-file
normalization, YAML and TOML validation, merge-conflict detection, private-key detection, and a
configurable large-file guard.

Use **local** Ruff hooks that call `uv run --locked ruff ...` so there is not a second independently
pinned Ruff version. Generic non-Python hooks may use pinned upstream hook repositories.

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
test:        ## Run the Python test suite
verify-results: ## Verify this project's declared results using permitted inputs
```

Rename the verification gate to fit the project. When relevant, add project-named targets for
quality checks, analysis, figures, the light and full pipelines, reports, and narrowly guarded
cleanup. Never define a cleanup target that can reach `data/raw/`.

Make may use phony high-level targets without pretending to offer file-level incrementality. Add
real file dependencies only when they are reliable.

## Configuration and secrets

Read `references/configuration.md` before creating YAML, `config.py`, `paths.py`, CLI overrides, or
configuration provenance. TOML remains the source of truth for packaging and tool configuration.
Create mandatory `config/datasets.yaml` and `config/analysis.yaml`.

Put every stable scientific or result-affecting value explicitly in `config/analysis.yaml`.
`config.py` validates strict typed schemas and contains no project values or hidden result-affecting
defaults. `paths.py` derives internal paths and reads permitted machine-specific roots from
environment variables.

Create `.env.example` only when the project consumes environment variables. It lists variable names
with safe descriptions or placeholders and never contains real values. The real `.env` is
gitignored.

## Containers when required

Only add an R container and a project `test-r` target when the interview establishes that R is
required. Put language- or purpose-specific containers under `docker/<language-or-tool>/`. For R:
pin the base image by immutable digest when feasible, constrain packages with `renv.lock`, document
CRAN/Bioconductor and system-library limitations, expose build and execution through Make and a
checked-in wrapper, and mount only required directories. Use `testthat` for reusable R logic, run
via `make test-r`. Pin `logger` in `renv.lock` — it is the R counterpart to `loguru`, and R stages
log through it under the same contract:

```r
log_appender(appender_tee(file.path(logs_dir, "03_fit.log")))
log_threshold(INFO)
log_info("fitted {n} models on {nrow(df)} rows", n = length(fits))
```

`appender_tee()` writes to console and file at once, matching the two-sink Python setup. Keep the R
logging surface this small; anything more elaborate belongs in Python.

Do not create a dedicated R package by default. R code stays minimal and may live in its numbered
`scripts/` stage.

## Host adapter integration

Do not copy the canonical simplifier profile during scaffolding. After core vendoring, the selected
host adapter installs that profile and the host's supported independent-agent integration. When no
host adapter was selected, install neither.

## README

Keep it concise: research question and one-paragraph scope, compact repository map, project
prerequisites including the selected Python minor, uv, and Make; the three required agent skills
with a link to the canonical prerequisite contract at
<https://github.com/lucascamillomd/research-repo-standard/blob/main/references/prerequisites.md>;
shortest project setup and reproduction commands, expected results, external data and tool
limitations, and links to `docs/`. Distinguish agent-host prerequisites from project tools and
packages installed by `make setup`.
