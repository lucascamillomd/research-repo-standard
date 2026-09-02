# Reference: repository bootstrap

Begin only after the interview answers, integrated design, specification, and implementation plan
are approved. Replace every placeholder with an approved project value; never create a path
containing angle brackets. Once generated, project files such as `pyproject.toml` and the Makefile
are their repository's source of truth.

## Core scaffold

Create only the approved parts of this structure. Repository names may contain hyphens;
import-package names use lowercase underscores.

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
├── .github/workflows/ci.yml        # or the forge's equivalent CI configuration
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
│   └── LAB_NOTEBOOK.md
├── logs/
├── results/
│   ├── figures/
│   ├── figure_data/
│   └── tables/
├── workflow/
│   ├── Snakefile
│   ├── rules/
│   │   ├── data.smk
│   │   ├── preprocessing.smk
│   │   ├── analysis.smk
│   │   ├── figures.smk
│   │   └── verification.smk
│   └── schemas/
│       ├── analysis.schema.yaml
│       └── datasets.schema.yaml
├── src/<package_name>/
│   ├── paths.py
│   └── figures/
│       └── common/
│           ├── export.py
│           ├── style.py
│           └── validation.py
└── tests/
```

Name rule modules under `workflow/rules/` after the approved workflow. `workflow/Snakefile` declares
`configfile` and `rule all`, includes the rule modules, and owns orchestration. Each rule declares
`input:`, `output:`, `log:`, and `params:`; its body is a single call into `src/<package_name>/`.
Rules hold no scientific logic. Importable, testable logic lives under `src/<package_name>/`.
Generate no R or other runtime support unless the approved design requires it.

## Python environment and lock

Pin the latest stable Python minor in both `.python-version` and `project.requires-python`. The
Python version is not an interview decision; check the current release rather than recalling one
from memory. Use Hatchling and the `src/<package_name>/` layout unless the approved design records
another PEP 517 backend.

uv manages environments, dependencies, builds, and commands:

```bash
uv init --package --build-backend hatch --vcs none --python 3.XY --name <repo-name> <target-repo>
uv add <package>          uv remove <package>
uv lock                   uv sync --locked
uv run --locked <command> uv build
```

uv normalizes the hyphenated repository name to the import-package name. Run `uv init` against the
approved target path; do not rely on the current directory or uv's application defaults.

Commit `uv.lock` and never hand-edit it. After metadata changes, run `uv lock`, then
`uv sync --locked`. Do not use `pip install`, Poetry, Pipenv, or Conda for the primary environment.
An incompatible upstream tool may get an isolated environment only when the approved design
documents the boundary and exact invocation.

Declare compatibility bounds. Pin an exact top-level version only for a demonstrated compatibility,
serialization, binary, or model constraint.

```toml
[dependency-groups]
dev = ["pre-commit", "pytest", "ruff", "ty"]
```

`loguru` and `snakemake` are runtime dependencies because rule logging and orchestration are part of
the pipeline.

## Configuration

Load `references/configuration.md` before creating YAML, schemas, `paths.py`, the Snakefile's
`configfile` declaration, or configuration provenance. It owns where each value belongs and how
validation and the override guard work. Create `config/datasets.yaml` and `config/analysis.yaml`;
TOML owns packaging and tool configuration.

Create `.env.example` only when the project consumes environment variables. List safe variable names
and placeholders, never values.

## Ignore policy

The generated `.gitignore` ignores `.env`, `tmp/`, `logs/`, `.venv/`, `__pycache__/`, `.snakemake/`,
and every tier under `data/`. `tmp/` holds the mid-implementation consultation's throwaway option
scripts, so they never reach the completion `git status` check. Un-ignore the fixture or shared
processed-data checkpoint approved in interview questions 7 and 11 with an explicit negation
pattern. Register each such file in `config/datasets.yaml` per `references/data.md` and keep it
under the pre-commit large-file guard's limit. Larger data arrives through the registered
acquisition method; use Git LFS or DVC only when the approved design records it. `results/` is not
ignored. SKILL.md treats a commit under it as presenting a result.

## Rule logging

Package code calls `logger.<level>()` but configures no sink at import time. Every rule declares a
`log:` path under `logs/`, and the rule body installs one console sink and one file sink before its
single package call:

```python
logger.remove()
logger.add(sys.stderr, level=params.log_level)
logger.add(log[0], level="DEBUG")
```

`log_level` is an operational setting owned by `config/analysis.yaml` and declared in the rule's
`params:`; the rule passes it explicitly. Never source logging verbosity from the environment. Each
rule logs resolved parameters, read inputs, written outputs, and skipped or failed units.

## Ruff and type checking

Use line length 100 and the latest stable Python minor in both placeholders:

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
include = ["src", "tests"]
```

Enable stable rules only, never all or preview rules. Permit only safe automatic fixes. Keep inline
suppressions narrow and explain the non-obvious ones; document repository-wide ignores beside their
configuration. Give scientific libraries with incomplete typing per-file type exceptions instead of
disabling type checking globally.

## Pre-commit

Install hooks with:

```bash
uv run --locked pre-commit install
```

Required hooks: Ruff safe lint fixes, Ruff formatting, trailing whitespace, final newlines, YAML and
TOML syntax, merge-conflict markers, private keys, and a configurable large-file guard. Ruff hooks
are local hooks that call `uv run --locked ruff ...`, so one locked Ruff version owns linting and
formatting. Generic non-Python hooks may use pinned upstream repositories. Do not run pytest in
pre-commit; Make and CI own tests.

## Continuous integration

Create the forge's CI configuration as part of the core scaffold. It runs on every push and pull
request, in this order:

```bash
uv lock --check
uv sync --locked
uv run --locked pre-commit run --all-files
uv run --locked ty check
make test
```

`--frozen` alone is not enough. It skips the metadata-to-lock comparison. Add the verification scope
approved in interview question 11, run against its permitted fixture or checkpoint. Steps that need
external data, licensed tools, or an unavailable runtime stay out of CI; the README lists them as
boundaries. CI never reads `data/raw/`.

## Make interface

Make is the public workflow interface; Snakemake is the pipeline engine behind it. `help` is the
default goal, every target has a one-line `##` description, and these targets are required:

```make
.DEFAULT_GOAL := help

help:            ## Show this help
setup:           ## Create the locked environment and install pre-commit hooks
test:            ## Run the test suite
pipeline:        ## Run the full Snakemake pipeline
verify-results:  ## Verify declared results using permitted inputs
```

`verify-results` is a placeholder. Name the verification gate to fit the project. Pipeline-facing
targets are phony one-line wrappers over Snakemake, so Snakemake's DAG owns file-level
incrementality. `pipeline` runs `uv run --locked snakemake --cores all`; approved analysis and
figure targets wrap named Snakemake rules. A reader reaches the analysis, figures, full pipeline,
and verification without knowing rule or internal file names.

Do not use `snakemake --delete-all-output`; cleanup targets are explicit Make targets that cannot
reach `data/raw/`.

## Conditional external runtimes

Create an R container and a `test-r` target only when the approved design requires R. Put the
container under `docker/r/`, pin the base image by digest when feasible, lock packages with
`renv.lock`, document CRAN, Bioconductor, and system-library limits, and expose build and execution
through Make and a checked-in wrapper. Mount only required directories. Test reusable R logic with
`testthat`.

Pin R `logger` in `renv.lock`. The R entry point takes the log path from the rule's `log:` and
`log_level` from its `params:`, as Python rules do, through the wrapper's arguments or through
`snakemake@log` and `snakemake@params` when the rule uses `script:`. Keep the two-sink contract
small:

```r
log_appender(appender_tee(log_path))
log_threshold(log_level)
log_info("fitted {n} models on {nrow(df)} rows", n = length(fits))
```

Do not create an R package by default. Minimal R orchestration may sit behind its Snakemake rule;
scientific plotting stays in Python.

## Generated README checklist

The project README records:

- project identity, research question, analysis status, and one-paragraph scope;
- a compact repository map and links to `docs/`;
- prerequisites: the pinned Python minor, uv, Make, and any approved external runtime;
- `research-repo-standard` as an exact-name agent prerequisite, its expected source and provenance,
  and recovery steps when resolution fails, linked to `references/prerequisites.md` in the approved
  standard source;
- required skills, separated from the packages `make setup` installs;
- the shortest reproduction path, including setup and the canonical `make pipeline` command;
- expected tables, figures, and provenance artifacts; and
- external data, licensing, compute, manual, and unavailable-tool boundaries.

## Selected host integration

After the core scaffold, write only the selected host's simplifier profile, and none when no host
was selected. Derive it from the canonical `agents/research-code-simplifier.md` in the
provenance-verified skill source reported by the host-native resolver, then run the host-native
smoke test. Both follow `references/prerequisites.md` exactly.
