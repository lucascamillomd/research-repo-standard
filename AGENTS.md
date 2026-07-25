<!-- standard_version: 2026.07.25 -->
<!-- Source: https://github.com/lucascamillomd/research-repo-standard -->

# Reproducible Research Repository Standard

Operating standard for repositories that support scientific analyses and papers.
`CLAUDE.md` is a symlink to this file.

## This repository

*Per-repository section — the only part expected to differ from the source. Replace it.*

<!-- What question does this repository answer, and what claim does it support? -->
<!-- Where should a reader start: README, docs/PIPELINE.md, make help. -->

## Using this standard

This file is always in context and is self-sufficient for everything below. Deeper
reference material lives in the `research-repo-standard` skill, which is loaded on
demand and is not vendored here:

| Reference | Read when |
|---|---|
| `references/bootstrap.md` | writing tool config, CI, or a Makefile that does not exist yet |
| `references/data.md` | registering a dataset, defining a schema, writing validation |
| `references/analysis.md` | planning or reporting a confirmatory analysis |
| `references/figures.md` | before writing any plotting code, and again during figure QA |

If that skill is unavailable — another agent, a collaborator's checkout — this file
still governs. Say what you could not consult rather than inventing the detail.

In an established repository the working files are the source of truth:
`pyproject.toml` for lint and type configuration, `make help` for the workflow
interface, `config/datasets.yaml` for provenance, `docs/PIPELINE.md` for the stage
graph. This standard states what must be true; it does not restate their contents.
Where this file and a working file disagree, assume the working file is current and
this file is stale — say so rather than quietly editing either to match.

Placeholders (`<repo-name>`, `<package_name>`, `<dataset_id>`, `<figure_id>`) are for
substitution. Never create a path containing angle brackets.

Explicit user instructions, and legal, institutional, journal, and data-use
requirements, take precedence over everything here. Project-specific scientific
requirements may refine this standard.

## The floor

These do not bend for convenience, a deadline, or a failing check. If one of them
blocks you, stop and say so rather than working around it.

1. **Raw data is immutable.** Nothing under `data/raw/` is ever modified. Corrections,
   harmonization, exclusions, and derived variables produce new files under
   `interim/` or `processed/`. No cleanup target may be capable of reaching
   `data/raw/` — cleanup paths are narrow, named, and guarded.
2. **Never weaken a gate to make it pass.** Reproducibility, provenance, and
   validation checks exist to fail. A failing check is information, not an obstacle.
3. **Estimands, inclusion rules, and data contracts change only with authorization**,
   and the change is recorded before results built on it are presented.
4. **Exploratory never silently becomes confirmatory.** Analyses are labelled. Post
   hoc changes and their rationale are recorded in `docs/DECISIONS.md` or the lab
   notebook before the result is presented as planned.
5. **No silent complete-case filtering.** Missingness is reported before exclusions
   or imputation. Inclusion and exclusion criteria are code, not prose.
6. **Seed 42**, propagated explicitly and recorded in configuration, whenever
   randomness is unavoidable. Prefer deterministic algorithms where scientifically
   equivalent. Do not claim full determinism when GPU kernels, parallel algorithms,
   external APIs, or upstream software remain nondeterministic.
7. **Outputs are written transactionally** — build a temporary artifact, validate it,
   then replace the declared destination. A failed run must not leave output that
   looks complete.
8. **Do not overstate what was verified.** Passing tests establish implementation
   behaviour, not scientific truth. Never claim a result is valid because the
   workflow executed, and never claim reproducibility you have not run.
9. **No credentials or secret values** in logs, committed files, or `.env.example`.

## Core principles

1. Make is the canonical user-facing workflow interface.
2. uv manages all ordinary Python environments, dependencies, builds, and commands.
3. Importable and testable logic lives under `src/<package_name>/`.
4. Numbered stage directories under `scripts/` make execution order visible.
5. Scripts are thin orchestration entry points, not libraries.
6. Inputs, parameters, outputs, assumptions, and manual boundaries are explicit.
7. Tests cover scientific invariants and contracts, not only successful execution.
8. Every plot uses Python and the full `nature-figure` workflow.
9. Distinguish computational success from scientific validity.

## Repository layout

```text
<repo-name>/
├── AGENTS.md                       # this standard; CLAUDE.md symlinks here
├── README.md
├── LICENSE                         # only after the user chooses a license
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
│   ├── raw/<dataset_id>/           # immutable source material, as received
│   ├── interim/<dataset_id>/       # intermediate, not yet analysis-ready
│   ├── processed/<dataset_id>/     # validated, defined row grain and schema
│   └── external/<resource_id>/     # reference data, ontologies, model assets
├── docker/
│   ├── README.md
│   └── r/                          # only when R is required
├── docs/
│   ├── ANALYSIS_PLAN.md            # prospective and updated analysis plan
│   ├── DATA.md                     # datasets, variables, units, schemas, access
│   ├── DECISIONS.md                # durable decisions with rationale
│   ├── FIGURE_CONTRACT.md          # contract and QA record for every plot
│   ├── METHODS.md                  # implementation-level scientific methods
│   ├── PIPELINE.md                 # stage graph, I/O, runtimes, manual barriers
│   └── lab_notebook.md             # append-only chronological record
├── logs/                           # gitignored
├── results/
│   ├── figures/<figure_id>/{svg,pdf,tiff,png}/
│   ├── source_data/<figure_id>/
│   ├── tables/
│   └── reports/
├── scripts/
│   ├── 01_data/                    # acquisition, immutable-input registration
│   ├── 02_preprocessing/           # cleaning, harmonization, analysis-ready sets
│   ├── 03_features/                # feature engineering / scoring / modelling
│   ├── 04_analysis/                # primary analyses
│   ├── 05_sensitivity/             # robustness, diagnostics, subgroups
│   ├── 06_figure_data/             # panel-ready and publication source data
│   ├── 07_figures/                 # atomic panel export, then assembly
│   └── 08_verification/            # read-only output and reproducibility checks
├── src/<package_name>/
│   ├── config.py                   # environment and configuration loading
│   ├── paths.py                    # all repository paths
│   └── figures/
│       ├── common/{export,style,validation}.py
│       └── <figure_id>/{data,panels}.py
└── tests/
```

The top-level layout is a contract. Adding a new top-level directory is a structural
decision — say so before doing it.

Stage 03 may be renamed to a concrete name (`03_scoring`, `03_modeling`) when that
describes the project better. Irrelevant stages may be omitted rather than committed
empty, but the remaining numbering and dependencies must stay legible. Later stages
depend only on declared earlier-stage artifacts; the full graph lives in
`docs/PIPELINE.md`.

No `archive/`, `old/`, or `deprecated/` directories. Git history is the record of
superseded work; a dead file left on disk will eventually be imported by someone who
cannot tell it is dead.

No `notebooks/` directory unless the user explicitly revises this standard. Hidden
execution order defeats diffing, testing, and rerunning; analysis logic belongs in
`src/` and `scripts/`.

## Naming

Repository names may use hyphens; package names use lowercase underscores
(`my-paper-project` → `src/my_paper_project/`).

A filename states what the file does, not that it is code. Scripts open with the
action verb that names their stage role: `download_`/`fetch_`, `build_`,
`clean_`/`preprocess_`, `score_`, `fit_`, `calculate_`, `export_`, `assemble_`,
`verify_`. A name that would fit almost any file in the repository is the signal
that something is unnamed. Test names describe behaviour
(`test_standardization_preserves_row_order`).

Number stage directories, not individual scripts. Dataset directories use stable
machine-readable identifiers; human-readable titles and aliases go in
`config/datasets.yaml`.

Publication artifacts use explicit identifiers: `main_figure_1`,
`extended_data_figure_2`, `main_table_1`, `supplementary_table_3`.

## Data

`data/raw/` is source material as received. `interim/` is not yet analysis-ready.
`processed/` is validated with a defined row grain and schema. `external/` is
reference material, not study observations.

Nothing durable is stored as pickle — it cannot be read without the exact
environment that wrote it, and it executes code on load. A durable artifact is
readable by someone who has only the file. Typed intermediates default to Parquet;
publication source data to CSV or TSV, so a reader can open it without a Python
environment.

Every dataset is registered in `config/datasets.yaml`. A reader must be able to
answer, without reading code: what this data is, where it came from, which version,
what one row means, and what may legally be done with it. Record whatever fields
that takes. Validate before analysis, not after.

Git LFS is not the default — it splits the repository across two systems that can
desynchronize. Reach for it only when a bulky artifact genuinely must be versioned,
and record why.

## Analysis

Before implementing a confirmatory analysis, write or update `docs/ANALYSIS_PLAN.md`.
Every inferential result reports the effect estimate and its unit, an uncertainty
interval, the sample size and analysis population, the exact test or model, its
assumptions and diagnostics, and the multiplicity strategy or a justification for its
absence. P-values alone are insufficient. For predictive work, test that
preprocessing, imputation, feature selection, and tuning saw only permitted training
data.

When work turns on a scientific judgment — study design, estimand, statistical
method, alternative explanations, the scope of a claim — request an independent
critique. A separate subagent applies `scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) and returns findings without implementing
anything. The critique is advisory; weigh it against the evidence and the task.
Routine plumbing does not need one. A skill is guidance, not evidence — validate
against primary documentation, known examples, and the study design.

## Figures

Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound
— uses the `nature-figure` skill, is written in Python, is implemented as importable
functions under `src/<package_name>/figures/`, has traceable source data, and exports
all four formats: editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each format
lives in its own extension-named directory under `results/figures/<figure_id>/`.

Record the contract in `docs/FIGURE_CONTRACT.md` **before** writing plotting code.
Never use R or another language to render a preview, fallback, or substitute plot; if
a required Python dependency is missing, stop and report the blocker rather than
rendering something else.

Atomic figure assets carry a semantic name, never a panel letter —
`mf1_hazard_ratio_distribution`, not `mf1a`. Panel letters are layout metadata
applied at assembly and must never rename or alter an underlying asset. Use the same
name stem across every export format and its source-data file.

Open the exported SVG and PDF as part of QA; a successful `savefig` call is not
evidence of a correct export.

## Workflow interface

Make is the public interface; a user should not need to know internal script paths to
reproduce standard results. `help` is the default goal and every target carries a
one-line description. Required: `help`, `setup`, `test`, and a verification gate.
Beyond that a reader must be able to reach quality checks, the analysis, the figures,
the full pipeline, and cleanup — named to fit the project. `make help` is the source
of truth for what exists, not this file.

`make all` is what a stranger runs first. It must not quietly start a large download
or an hours-long job. Anything heavy, metered, or long gets its own target and says
so in `make help`. The cheapest complete path runs from the smallest distributable
processed checkpoint.

The stage graph has one canonical definition. Do not build a competing workflow graph
elsewhere.

## Code

Scripts orchestrate; they do not implement. Anything worth testing lives in `src/`
and is imported. A stage script never imports another stage script — if two stages
need the same logic, it belongs in the package. Scripts within a stage should be
independently runnable when their inputs permit.

Each runtime has one job. Python does the science. Shell wires up environments and
containers and stops there — a transformation written in shell is untested and
unversioned. Containers exist for runtimes uv cannot manage (R, system libraries);
wrapping ordinary Python in Docker adds opacity over an environment that is already
reproducible. R must never generate a plot.

Centralize paths in `paths.py` and configuration loading in `config.py`. Loaders
reject unknown fields and fail clearly on missing required ones. Scientific decisions
and stable parameters live in versioned configuration; credentials and
machine-specific roots live in environment variables. Command-line arguments are for
what genuinely varies between invocations.

Public functions and classes in `src/` have typed interfaces and Google-style
docstrings that explain scientific meaning, units, ranges, array shapes, dataframe row
grain and required columns, missing-value behaviour, side effects, and failure
conditions. Express types in annotations, not prose.

Ruff formats and lints; ty type-checks; pre-commit runs the fast hooks. In an
established repository `pyproject.toml` and `.pre-commit-config.yaml` are the source
of truth for their configuration — read them rather than assuming.

## Results and provenance

Generated artifacts stay under `results/{figures,tables,source_data,reports}/` and
`logs/`. Result filenames and committed manifests carry no timestamps — a rerun must
overwrite its own outputs so they can be byte-compared, and timestamped filenames
quietly turn verification into accumulation. Run-specific timing belongs in `logs/`.

Each major build writes a deterministic provenance manifest recording, where
permitted: commit identifier, configuration hash, input identifiers and checksums,
environment and container identity, seed, output inventory and checksums, and any
declared non-reproducible or manual boundary.

Commit lightweight final tables, source data, editable figures, and deterministic
manifests when licensing permits. Ignore caches, environments, logs, bulky
intermediates, and regenerable binaries.

Every README classifies the project honestly as (1) computationally reproducible with
included or public inputs, (2) reproducible with user-supplied inputs, or (3)
partially reproducible because an upstream resource or environment is unavailable.

## Testing

Organize tests around behaviour, scientific components, and contracts rather than
mirroring source files. Cover transformations and statistics, schemas and data
contracts, pipeline structure and paths, integration on fixtures, figure source-data
and rendering contracts, known analytical examples, scientific invariants and
boundary cases, deterministic or golden-file outputs, and a small end-to-end smoke
test.

Coverage is a smoke detector, not a goal. What must be tested directly, whatever the
percentage says: scientific transformations, estimands, exclusion rules, validation,
and output contracts. A rising coverage number over untested science is a worse state
than a low one.

Use exact comparison for stable tabular and vector output, and explicit justified
tolerances for floating point. CI-runnable verification uses fixtures already in the
repository or generated during the run; anything needing real data belongs in the
full verification path.

## Working procedure

Before changing anything: read this file, the README, the relevant `docs/`, nearby
tests, and `git status`. Identify the scientific claim, the pipeline stage, the inputs
and outputs, and which contracts are affected. Surface assumptions that materially
affect scientific meaning, interfaces, data safety, or scope. Preserve unrelated work.

While implementing: keep the change narrow and reuse what exists. Validate inputs
before expensive computation. Update tests and documentation in the same change.

Before declaring completion: run the checks the change warrants — format, lint,
typecheck, test, and the verification gates — then inspect the actual generated
tables, figures, reports, and manifests rather than trusting exit codes. Check
`git status` for files you did not intend to add. Report what changed, what was
verified, what was skipped and why, and any manual or inaccessible reproducibility
boundary.
