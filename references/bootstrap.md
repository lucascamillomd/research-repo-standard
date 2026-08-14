# Reference: repository bootstrap

Begin this procedure only after the interview answers, integrated design, written specification, and
implementation plan are approved. Substitute every placeholder with an approved project value; never
create a path containing angle brackets. Once generated, project files such as `pyproject.toml` and
the Makefile become their repository's source of truth.

## Core scaffold

Create only the approved parts of this structure. Repository names may contain hyphens; import
package names use lowercase underscores.

```text
<repo-name>/
├── README.md
├── LICENSE                         # only when the user selected a license
├── Makefile
├── pyproject.toml
├── uv.lock
├── .python-version
├── .gitignore
├── .pre-commit-config.yaml
├── config/
│   ├── datasets.yaml
│   └── analysis.yaml
├── data/
│   ├── raw/<dataset_id>/
│   ├── interim/<dataset_id>/
│   ├── processed/<dataset_id>/
│   └── external/<resource_id>/
├── docker/                         # only when an approved external runtime needs it
├── docs/
│   ├── ANALYSIS_PLAN.md
│   ├── FIGURE_CONTRACT.md
│   └── lab_notebook.md
├── logs/
├── results/
│   ├── figures/
│   ├── source_data/
│   ├── tables/
│   └── reports/
├── scripts/
│   ├── 01_data/
│   ├── 02_preprocessing/
│   ├── 03_features/
│   ├── 04_analysis/
│   ├── 05_sensitivity/
│   ├── 06_figure_data/
│   ├── 07_figures/
│   └── 08_verification/
├── src/<package_name>/
│   ├── config.py
│   ├── paths.py
│   └── figures/
│       └── common/
│           ├── export.py
│           ├── style.py
│           └── validation.py
└── tests/
```

Adapt numbered stage names to the approved workflow while keeping their execution order visible. Put
importable and testable logic under `src/<package_name>/`; stage scripts orchestrate and do not
import one another. Generate no R or other runtime support unless the approved design requires it.

## Python environment and lock

Use the approved currently supported Python minor in both `.python-version` and
`project.requires-python`. Use Hatchling and the `src/<package_name>/` layout unless the approved
design records another PEP 517 backend.

uv manages ordinary Python environments, dependencies, builds, and commands:

```bash
uv init
uv add <package>          uv remove <package>
uv lock                   uv sync --locked
uv run --locked <command> uv build
```

Commit `uv.lock` and never hand-edit it. After project metadata changes, run `uv lock`, then
`uv sync --locked`. CI runs both checks in this order:

```bash
uv lock --check
uv sync --locked
```

`--frozen` alone is insufficient because it skips the metadata-to-lock comparison. Do not use direct
`pip install`, Poetry, Pipenv, or Conda for the primary environment. An incompatible upstream tool
may use an explicitly isolated environment only when the approved design documents the boundary and
exact invocation.

Declare meaningful compatibility bounds. Use exact top-level pins only for demonstrated
compatibility, serialization, binary, or model constraints.

```toml
[dependency-groups]
dev = ["pre-commit", "pytest", "ruff", "ty"]
```

`loguru` is a runtime dependency because stage logging is part of the pipeline.

## Configuration

Load `references/configuration.md` before creating YAML, `config.py`, `paths.py`, CLI overrides, or
configuration provenance. Create `config/datasets.yaml` and `config/analysis.yaml`; TOML remains the
owner of packaging and tool configuration.

All stable researcher-editable scientific or result-affecting settings belong explicitly in
versioned YAML, as do stable researcher-editable operational settings.

Non-setting implementation constants remain in code.

`config.py` uses strict typed schemas and contains no hidden project values or result-affecting
defaults. `paths.py` derives internal paths. Secrets and permitted machine-specific roots use
environment variables.

Create `.env.example` only when the project consumes environment variables. List safe variable names
and placeholders, never values. Ignore the real `.env`.

## Stage logging

Package code calls `logger.<level>()` but configures no sink at import time. Each stage entry point
removes the default sink and installs one console sink and one file sink under `logs/`:

```python
logger.remove()
logger.add(sys.stderr, level=os.environ.get("LOG_LEVEL", "INFO"))
logger.add(paths.LOGS / "02_fit_{time}.log", level="DEBUG", rotation="20 MB")
```

`LOG_LEVEL` is operational and may control verbosity; it never carries a scientific setting. Each
stage logs resolved parameters, read inputs, written outputs, and skipped or failed units.

## Ruff and type checking

Use line length 100 and the selected Python minor in both placeholders:

```toml
[tool.ruff]
line-length = 100
target-version = "py3XY"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "D", "UP", "B", "RUF"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.format]
quote-style = "double"

[tool.ty.environment]
python-version = "3.XY"

[tool.ty.src]
include = ["src", "scripts", "tests"]
```

Enable stable rules only. Do not enable all or preview rules indiscriminately. Permit only safe
automatic fixes globally. Keep inline suppressions narrow and explain non-obvious ones; document
repository-wide ignores beside their configuration. Use focused per-file type exceptions for
scientific libraries with incomplete typing instead of disabling type checking globally.

## Pre-commit

Install hooks with:

```bash
uv run --locked pre-commit install
```

Required hooks cover Ruff safe lint fixes, Ruff formatting, trailing whitespace, final newlines,
YAML and TOML syntax, merge-conflict markers, private keys, and a configurable large-file guard. Use
local Ruff hooks that call `uv run --locked ruff ...` so one locked Ruff version owns linting and
formatting. Generic non-Python hooks may use pinned upstream repositories. Do not put pytest or the
full test suite in pre-commit; Make and CI own tests.

## Make interface

Make is the public workflow interface. `help` is the default goal, every target has a one-line `##`
description, and these targets are required:

```make
.DEFAULT_GOAL := help

help:            ## Show this help
setup:           ## Create the locked environment and install pre-commit hooks
test:            ## Run the test suite
verify-results:  ## Verify declared results using permitted inputs
```

Name the verification gate to fit the project. Add approved targets for quality checks, analysis,
figures, reports, the light and full pipelines, and narrow cleanup. A reader must be able to reach
the analysis, figures, full pipeline, and verification without knowing internal script paths.
Cleanup targets are explicit and incapable of reaching `data/raw/`.

Phony high-level targets need not pretend to provide file-level incrementality. Add file
dependencies only when they are reliable.

## Conditional external runtimes

Create an R container and a `test-r` target only when the approved design requires R. Put it under
`docker/r/`, pin the base image by immutable digest when feasible, lock packages with `renv.lock`,
document CRAN/Bioconductor and system-library limitations, and expose build and execution through
Make and a checked-in wrapper. Mount only required directories and use `testthat` for reusable R
logic.

Pin R `logger` in `renv.lock` and keep the two-sink contract small:

```r
log_appender(appender_tee(file.path(logs_dir, "03_fit.log")))
log_threshold(INFO)
log_info("fitted {n} models on {nrow(df)} rows", n = length(fits))
```

Do not create a dedicated R package by default. Minimal R orchestration may remain in its numbered
stage; scientific plotting remains in Python.

## Generated README checklist

The project README records:

- project identity, research question, analysis status, and one-paragraph scope;
- a compact repository map and links to `docs/`;
- the selected Python minor, uv, Make, and any approved external runtime prerequisites;
- `research-repo-standard` as an exact-name agent prerequisite, its expected source/provenance, and
  recovery instructions when resolution fails, linked to `references/prerequisites.md` from the
  approved standard source;
- required hard-gate skills, clearly separated from packages installed by `make setup`;
- the shortest reproduction path, including setup and the canonical Make command;
- expected tables, figures, reports, and provenance artifacts; and
- external data, licensing, compute, manual, and unavailable-tool boundaries.

## Selected host integration

After the core scaffold is complete, run only the adapter selected in the approved interview:

```bash
./adapters/codex.sh <target-repo>
./adapters/claude-code.sh <target-repo>
```

The commands are alternatives, not a sequence. When no host adapter was selected, run neither. Then
follow `references/prerequisites.md` for the real host-native smoke test of the resolved
`research-repo-standard` provenance and the `research-code-simplifier` host profile. Report an
unavailable selected host as a manual boundary instead of simulating success.
