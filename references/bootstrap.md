# Reference: repository bootstrap

Create the scaffold only after the integrated design and specification are approved and the
implementation plan is written. Replace every placeholder with an approved project value; never
create a path containing angle brackets. Once generated, project files such as `pyproject.toml` and
the Makefile are their repository's source of truth.

## Design and interview

Use answers already supplied in the request or repository. Ask only for material missing decisions;
group related questions when that reduces user effort. Do not silently choose a scientific claim,
data-use permission, license, or host integration. The user may authorize proposed mechanical
defaults together; state what was chosen.

Establish the project identity and purpose; research question and intended claim; exploratory or
confirmatory status; datasets and access constraints; workflow stages, randomness, and shareable
processed checkpoint; required external runtimes and whether they can be pinned; tables, figures,
and publication target if any; and compute, licensing, automation, and public-CI boundaries. Confirm
the host profile (`codex`, `claude-code`, or none) and license or unlicensed status when not
supplied. A project without a journal target need not invent one.

Follow SKILL.md's full gate for design. Resolve each capability through
`references/prerequisites.md` when its work becomes necessary. Obtain independent scientific
critique under `references/analysis.md` before dependent judgments. Plan figures under
`references/figures.md` only when figures are in scope; otherwise record the no-figure decision
without loading or resolving the figure skill.

Present the integrated design for approval. In an empty directory initialize only version control
and the path needed for the specification, then write, self-review, commit, and obtain user review
of that specification. Write the implementation plan before scaffolding. Reuse supplied approval for
these exact artifacts; a session change alone does not reopen settled decisions.

Create only the approved scaffold below. Afterward derive only the selected host profile and run the
real selected-host smoke test through `references/prerequisites.md`. With no host selected, write no
profile; resolve a reviewer only when a code-review step requires one. Report missing capabilities
at that step, without claiming future reviews have happened.

Track settled decisions and open questions in the design artifacts. At completion report the
scaffold, configuration/data/provenance checks, scientific critique and figure strategy, selected
host verification or its boundary, and actual inspected outputs. No repeated execution-record
template or separate tracking file is required.

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

Use the latest stable Python minor compatible with required dependencies by default. Preserve an
approved compatibility pin; record its reason. Check current release and dependency support when
choosing a new version, then pin the selected minor consistently in `.python-version`,
`project.requires-python`, and tool configuration. Use Hatchling and the `src/<package_name>/`
layout unless the approved design records another PEP 517 backend.

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
and every tier under `data/`. `tmp/` holds disposable experiments, not analysis outputs. Un-ignore
the fixture or shared processed-data checkpoint approved in the design with an explicit negation
pattern. Register each such file in `config/datasets.yaml` per `references/data.md` and keep it
under the pre-commit large-file guard's limit. Larger data arrives through the registered
acquisition method; use Git LFS or DVC only when the approved design records it. `results/` is not
ignored. `references/governance.md` defines when result records must be complete.

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
approved in the design, run against its permitted fixture or checkpoint. Steps that need external
data, licensed tools, or an unavailable runtime stay out of CI; the README lists them as boundaries.
CI never reads `data/raw/`.

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
plotting follows the approved backend in `references/figures.md`.

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

After the core scaffold, follow `references/prerequisites.md` for the selected
`research-code-simplifier` profile and the host-native smoke test. That reference owns source
verification, profile installation, and unavailable-host reporting.
