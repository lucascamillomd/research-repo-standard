<!-- standard_version: 2026.08.12 -->
<!-- Source: https://github.com/lucascamillomd/research-repo-standard -->

# Reproducible Research Repository Standard

Portable governed policy for repositories that support scientific analyses and papers. `AGENTS.md`
is the normative policy regardless of which supported agent host applies it.

## This repository

_Per-repository section — the only part expected to differ from the source. Replace it._

<!-- What question does this repository answer, and what claim does it support? -->
<!-- Where should a reader start: README or make help. -->

## Using this standard

Detailed references are deliberately **not** vendored here — they remain in the
`research-repo-standard` skill and expand procedure without owning or weakening any required safety
rule in this policy. Invoke that skill by name when you need:

| Invoke it for              | When                                                                                        |
| -------------------------- | ------------------------------------------------------------------------------------------- |
| bootstrap detail           | writing tool config, CI, or a Makefile that does not exist yet                              |
| the data contract          | registering a dataset, defining a schema, writing validation                                |
| the configuration contract | classifying settings; changing YAML, loaders, paths, overrides, or configuration provenance |
| the analysis contract      | planning or reporting a confirmatory analysis                                               |
| the figure contract        | the contract template and the full QA checklist                                             |

Placeholders (`<repo-name>`, `<package_name>`, `<dataset_id>`, `<figure_id>`) are for substitution.
Never create a path containing angle brackets.

Explicit user instructions, and legal, institutional, journal, and data-use requirements, take
precedence over everything here.

## Required agent skills

Invoke the skills required by the modification gate and the task-specific **Analysis** and
**Figures** sections. Verify exact names with the host's native resolver as described in the
canonical
[prerequisite contract](https://github.com/lucascamillomd/research-repo-standard/blob/main/references/prerequisites.md);
file presence alone is insufficient. A missing or unverifiable skill blocks only its dependent work.
Do not silently install skills, change global agent configuration, or substitute another workflow.
If scope expands, verify any newly required skill before continuing.

Classify every requested file modification into one path; when uncertain, use the full gate:

- **Full gate:** result-affecting or contract-affecting changes, including scientific decisions,
  analysis configuration, data contracts, pipeline structure, figures, features, and this standard's
  rules. Invoke `superpowers:brainstorming`. Do not implement until the approved specification is
  committed and reviewed and the plan is ready. Direct and delegated implementation inherits the
  completed gate; reopen it at design if scope expands.
- **Light path:** mechanical, non-result-affecting changes such as documentation, comments,
  formatting, behavior-preserving renames or tested refactors, and tests that do not change
  behavior. State the intent, files, and why the change is non-result-affecting; obtain one
  confirmation, then implement without specification or plan artifacts. Escalate to the full gate if
  results, interfaces, or contracts may change.
- **No gate:** read-only explanation, inspection, diagnosis, status reporting, and regeneration of
  declared outputs from an already approved workflow. Questions ask for answers, not edits; answer
  first and wait for an explicit change request.

These are normative agent instructions enforced by the host, not operating-system access controls.

## The floor

These do not bend for convenience, a deadline, or a failing check. If one of them blocks you, stop
and say so rather than working around it.

1. **Raw data is immutable.** Nothing under `data/raw/` is ever modified. Corrections,
   harmonization, exclusions, and derived variables produce new files under `interim/` or
   `processed/`. No cleanup target may be capable of reaching `data/raw/` — cleanup paths are
   narrow, named, and guarded.
2. **Never weaken a gate to make it pass.** Reproducibility, provenance, and validation checks exist
   to fail. A failing check is information, not an obstacle.
3. **Estimands, inclusion rules, and data contracts change only with authorization**, and the change
   is recorded before results built on it are presented.
4. **Exploratory never silently becomes confirmatory.** Analyses are labelled. Post hoc changes and
   their rationale are recorded in `docs/lab_notebook.md` before the result is presented as planned.
5. **No silent complete-case filtering.** Missingness is reported before exclusions or imputation.
   Inclusion and exclusion criteria are code, not prose.
6. **Seed 42**, propagated explicitly and recorded in configuration, whenever randomness is
   unavoidable. Prefer deterministic algorithms where scientifically equivalent. Do not claim full
   determinism when GPU kernels, parallel algorithms, external APIs, or upstream software remain
   nondeterministic.
7. **Outputs are written transactionally** — build a temporary artifact, validate it, then replace
   the declared destination. A failed run must not leave output that looks complete.
8. **Required agent workflows are gates.** `superpowers:brainstorming` must be available before any
   file-changing user-requested modification; `scientific-critical-thinking` and `nature-figure`
   must be available for the work scoped to them in **Required agent skills**. Invocation follows
   the modification-gate, bootstrap, and task-specific conditions in this standard. A missing or
   unverifiable required skill stops the work that depends on it. Do not imitate or replace an
   unavailable skill.
9. **Configuration has one owner.** Stable scientific and operational settings live in versioned
   YAML, never as hidden Python globals or defaults. Derived internal paths stay in `paths.py`;
   secrets and machine-specific roots stay in environment variables. Unknown, missing, or
   duplicate-owned values fail before computation; an unrecorded result-affecting override fails
   provenance verification.

## Core principles

1. Make is the canonical user-facing workflow interface.
2. uv manages all ordinary Python environments, dependencies, builds, and commands.
3. Importable and testable logic lives under `src/<package_name>/`.
4. Numbered stage directories under `scripts/` make execution order visible.
5. Scripts are thin orchestration entry points, not libraries.
6. Inputs, parameters, outputs, assumptions, and manual boundaries are explicit.
7. Every plot uses Python and the full `nature-figure` workflow.
8. The science is complex; the repository should not add to it. Finding the simplest honest way to
   solve a problem is part of solving it, not a finishing touch.

## Repository layout

```text
<repo-name>/
├── AGENTS.md                       # portable governed policy
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
│   ├── FIGURE_CONTRACT.md          # contract and QA record for every plot
│   └── lab_notebook.md             # append-only chronology and decision record
├── logs/                           # gitignored
├── results/
│   ├── figures/<figure_id>/             # editable and preview exports
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

The top-level layout is a contract. Adding a new top-level directory is a structural decision — say
so before doing it.

`docs/lab_notebook.md` is append-only. Each consequential decision records its date, the decision,
rationale and evidence, authorization source, and affected analyses, configuration, data contracts,
figures, or outputs. A correction or reversal appends a new entry naming what it supersedes; routine
run detail belongs in logs and provenance manifests.

The stage names and numbers inside `scripts/` are suggestions that can be adapted for the project.
The Makefile dependency graph is canonical; `make help` exposes the workflow, numbered stages show
normal order, and the README records the shortest reproduction path plus manual or external
boundaries.

## Naming

Repository names may use hyphens; package names use lowercase underscores (`my-paper-project` →
`src/my_paper_project/`).

A filename states what the file does, not that it is code. Scripts open with the action verb that
names their stage role: `download_`/`fetch_`, `build_`, `clean_`/`preprocess_`, `score_`, `fit_`,
`calculate_`, `export_`, `assemble_`, `verify_`. A name that would fit almost any file in the
repository is the signal that something is unnamed. Test names describe behaviour
(`test_standardization_preserves_row_order`).

Number stage directories, not individual scripts. Dataset directories use stable machine-readable
identifiers; human-readable titles and aliases go in `config/datasets.yaml`.

Publication artifacts use explicit identifiers: `main_figure_1`, `extended_data_figure_2`,
`main_table_1`, `supplementary_table_3`. Detailed atomic figure-asset and source-data naming is
defined by the figure reference and is loaded before figure work.

## Data

`data/raw/` is source material as received. `interim/` is not yet analysis-ready. `processed/` is
validated with a defined row grain and schema. `external/` is reference material, not study
observations.

Typed intermediates default to Parquet; publication source data to CSV or TSV, so a reader can open
it without a Python environment. Don't use pickle.

Every dataset is registered in `config/datasets.yaml`. A reader must be able to answer, without
reading code: what this data is, where it came from, which version, what one row means, and what may
legally be done with it. Record whatever fields that takes. Validate before analysis, not after.

Git LFS is not the default — it splits the repository across two systems that can desynchronize.
Reach for it only when a bulky artifact genuinely must be versioned, and record why.

## Analysis

Before implementing a confirmatory analysis, write or update `docs/ANALYSIS_PLAN.md`. Every
inferential result reports the effect estimate and its unit, an uncertainty interval, the sample
size and analysis population, the exact test or model, its assumptions and diagnostics, and the
multiplicity strategy or a justification for its absence. P-values alone are insufficient. For
predictive work, test that preprocessing, imputation, feature selection, and tuning saw only
permitted training data.

An independent critique is required when defining or changing: an estimand, a study design, a
statistical method or model choice, inclusion or exclusion rules, a missing-data policy, a causal
interpretation, or the scope of a claim. One critique covers one design or coherent batch of
decisions. A separate independent review agent applies `scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) and returns findings without implementing anything. The
critique is advisory; weigh it against the evidence and the task. It may run concurrently with work
that does not depend on the judgment under review; only dependent work waits. Routine plumbing does
not need one. If the critique skill or an independent review agent is unavailable, stop before
making or implementing the scientific judgment and report the blocker.

## Figures

Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound — uses the
`nature-figure` skill, is written in Python, is implemented as importable functions under
`src/<package_name>/figures/`, has traceable source data, and exports editable SVG and PDF, 600 dpi
TIFF, and a PNG preview.

Consult the canonical `references/figures.md` procedure before planning a figure, writing plotting
code, modifying figure outputs, or performing QA, and record the contract in
`docs/FIGURE_CONTRACT.md` first. That procedure owns atomic asset naming, export paths, and assembly
conventions. Never use R or another language to render a preview, fallback, or substitute plot. If
`nature-figure`, Python, or a required Python dependency is unavailable, stop before plotting and
report the exact blocker rather than rendering something else. Open the exported SVG during QA; a
successful `savefig` call is not evidence of a correct export.

## Workflow interface

Make is the public interface; a user should not need to know internal script paths to reproduce
standard results. `help` is the default goal and every target carries a one-line description.
Required: `help`, `setup`, `test`, and a verification gate. Beyond that a reader must be able to
reach quality checks, the analysis, the figures, the full pipeline, and cleanup — named to fit the
project. `make help` is the source of truth for what exists, not this file.

## Code

Scripts orchestrate; they do not implement. Anything worth testing lives in `src/` and is imported.
A stage script never imports another stage script — if two stages need the same logic, it belongs in
the package. Scripts within a stage should be independently runnable when their inputs permit.

Each runtime has one job. Python does the science. Shell wires up environments and containers and
stops there — a transformation written in shell is untested and unversioned. Containers exist for
runtimes uv cannot manage (R, system libraries).

Stages report progress through a logger, never `print()` or `cat()`: `loguru` in Python, the
`logger` package in R. Each stage configures a console sink and a file sink under `logs/` at entry,
logs the parameters it resolved, the inputs it read, the outputs it wrote, and every skipped or
failed unit — enough to tell a long-running stage apart from a hung one, and to reconstruct
afterwards where a run diverged. Log levels carry meaning: `DEBUG` for developer detail, `INFO` for
stage progress, `WARNING` for a recoverable deviation a reader must know about, `ERROR` for a unit
that failed.

Stable researcher-editable values have one versioned YAML owner. Scientific and result-affecting
settings — seed, thresholds, inclusion rules, transformations, model parameters, and any batch size
that may affect optimization — live in `config/analysis.yaml`.

`config.py` strictly validates YAML, rejects unknown and missing fields, composes only permitted
overrides, and returns immutable typed objects passed explicitly into package functions. It contains
no project-specific scientific or operational values, and optional schema fields never conceal
result-affecting Python defaults. Load once per stage; package functions do not reread YAML or
import mutable settings globals.

`paths.py` discovers the repository root and derives canonical internal paths, containment, and
raw-data protections. Internal layout paths never live in YAML. Credentials, secrets,
machine-specific absolute roots, and GPU selection use environment variables; environment variables
never override scientific settings. Command-line arguments are only for genuine invocation-time
variation and use the same validation as YAML.

For established repositories, apply this migration when editing the function or entry point that
reads a module-level project setting. Preserve behavior with tests, obtain authorization before
changing scientific meaning, and record the migration in `docs/lab_notebook.md`.

Public functions and classes in `src/` have typed interfaces and Google-style docstrings that
explain scientific meaning, units, ranges, array shapes, dataframe row grain and required columns,
missing-value behaviour, side effects, and failure conditions. Express types in annotations, not
prose.

Comments carry what the code cannot: why this approach over the obvious one, which paper or protocol
a constant comes from, what a caller must know before reaching for a function. They are not a
line-by-line narration of syntax. A comment that no longer matches the code beneath it is a defect,
and in scientific code it is the kind that survives review — a reader trusts a stated unit, cohort,
or assumption over the arithmetic. Update comments and docstrings in the same change as the code
they describe, or delete them.

Ruff formats and lints; ty type-checks; pre-commit runs the fast hooks. In an established repository
`pyproject.toml` and `.pre-commit-config.yaml` are the source of truth for their configuration —
read them rather than assuming.

## Results and provenance

Generated artifacts stay under `results/{figures,tables,source_data,reports}/` and `logs/`. Result
filenames and committed manifests carry no timestamps — a rerun must overwrite its own outputs so
they can be byte-compared, and timestamped filenames quietly turn verification into accumulation.
Run-specific timing belongs in `logs/`.

Each major build writes a deterministic provenance manifest recording: commit identifier; hashes and
validated effective values for every loaded YAML file; every CLI override and its source; input
identifiers and checksums; environment and container identity without secret values; secret inputs
only by variable name and redacted presence; seed, worker, parallelism, and accelerator boundaries
when relevant; output inventory and checksums; and declared nondeterministic or manual boundaries.
An unrecorded result-affecting override is a provenance failure. When legal or data-use restrictions
prohibit recording an input identifier, record a permitted stable registry alias and the
restriction, never the barred value.

Commit lightweight final tables, source data, editable figures, and deterministic manifests when
licensing permits. Ignore caches, environments, logs, bulky intermediates, and regenerable binaries.

## Testing

Organize tests around behaviour, scientific components, and contracts rather than mirroring source
files. Cover transformations and statistics, schemas and data contracts, pipeline structure and
paths, integration on fixtures, figure source-data and rendering contracts, known analytical
examples, scientific invariants and boundary cases, deterministic or golden-file outputs, and a
small end-to-end smoke test.

A test earns its place by naming one behaviour it would catch breaking. Prefer few sharp tests over
many shallow ones: one end-to-end smoke test tells you the wiring holds and a second one tells you
nothing, and a suite padded with tests that only assert code ran hides the handful that assert
science. When behaviour is deleted, delete its tests with it — a test kept to guard a removed
feature pins an absence in place and misleads the next reader about what the pipeline does. A test
that reproduces a real defect is always worth writing; a test written to raise a number is not.

Use exact comparison for stable tabular and vector output, and explicit justified tolerances for
floating point. CI-runnable verification uses fixtures already in the repository or generated during
the run; anything needing real data belongs in the full verification path.

Configuration tests reject unknown and missing fields, hidden result-affecting Python fallbacks,
duplicate ownership, invalid cross-field combinations, and unrecorded result-affecting overrides.
Test that stage entry points load once and pass immutable typed configuration explicitly, and that
`paths.py` cannot redirect canonical raw-data locations outside their contract.

## Working procedure

Before the context and status checks below, classify the request under the modification gates in
**Required agent skills** and apply the resulting path. Under a full gate, requested implementation
files remain blocked until the gate completes; its inheritance, regeneration exemption, and
scope-expansion rules govern the implementation that follows.

Before changing anything: read this file, the README, the relevant `docs/`, nearby tests, and
`git status`. Identify the scientific claim, the pipeline stage, the inputs and outputs, and which
contracts are affected. Surface assumptions that materially affect scientific meaning, interfaces,
data safety, or scope. Preserve unrelated work.

Destruction is never implied. Deleting files, dropping columns or rows, overwriting existing
results, resetting or rewriting Git history, and force-pushing are things the user asks for
explicitly; a request to change something is not a request to remove what was there. When a task
appears to need one, say what would be destroyed and whether it is recoverable, then wait.

While implementing: keep the change narrow and reuse what exists. If a materially better approach
exists — a simpler design, a sounder estimand, a cheaper pipeline — propose it at the gate rather
than building it unasked; the bold idea is welcome, the silent substitution is a scope change.
Validate inputs before expensive computation. Update tests and documentation in the same change.

When a modification changed code under `src/`, `scripts/`, or `tests/`, run an independent
code-simplification pass before declaring completion. The delegated review agent applies the
canonical `agents/code-simplifier.md` profile installed or resolved through the current host
adapter, preserves behavior exactly, and does not implement new requirements. Re-run the covering
tests after any simplifier edit. The simplifier's own edits do not trigger another pass.
Documentation- and configuration-only changes are exempt. If the host cannot launch an independent
review agent or resolve the canonical profile, report the blocker instead of substituting an
unreviewed self-pass.

Before declaring completion: run the checks the change warrants — format, lint, typecheck, test, and
the verification gates — then inspect the actual generated tables, figures, reports, and manifests
rather than trusting exit codes. Check `git status` for files you did not intend to add. Report what
changed, what was verified, what was skipped and why, and any manual or inaccessible reproducibility
boundary.
