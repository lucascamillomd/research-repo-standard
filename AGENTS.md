<!-- standard_version: 2026.08.10 -->
<!-- Source: https://github.com/lucascamillomd/research-repo-standard -->

# Reproducible Research Repository Standard

Operating standard for repositories that support scientific analyses and papers.
`CLAUDE.md` is a symlink to this file.

## This repository

*Per-repository section — the only part expected to differ from the source. Replace it.*

<!-- What question does this repository answer, and what claim does it support? -->
<!-- Where should a reader start: README, docs/PIPELINE.md, make help. -->

## Using this standard

This file is always in context and is self-sufficient for every rule below. Deeper
reference material is deliberately **not** vendored here — it lives in the
`research-repo-standard` skill. Invoke that skill by name when you need:

| Invoke it for | When |
|---|---|
| bootstrap detail | writing tool config, CI, or a Makefile that does not exist yet |
| the data contract | registering a dataset, defining a schema, writing validation |
| the configuration contract | classifying settings; changing YAML, loaders, paths, overrides, or configuration provenance |
| the analysis contract | planning or reporting a confirmatory analysis |
| the figure contract | the contract template and the full QA checklist |

Do not look for a `references/` directory in this repository; there isn't one. If the
skill is unavailable — another agent, a collaborator's checkout — this file still
governs. Say what you could not consult rather than inventing the detail.

In an established repository the working files are the source of truth:
`pyproject.toml` for lint and type configuration, `make help` for the workflow
interface, `config/datasets.yaml` for provenance, existing `config/analysis.yaml` and
`config/runtime.yaml` (when present) for project settings, and `docs/PIPELINE.md` for
the stage graph. This standard states what must be true; it does not restate their
contents. Where this file and a working file disagree, assume the working file is
current and this file is stale — say so rather than quietly editing either to match.

Placeholders (`<repo-name>`, `<package_name>`, `<dataset_id>`, `<figure_id>`) are for
substitution. Never create a path containing angle brackets.

Explicit user instructions, and legal, institutional, journal, and data-use
requirements, take precedence over everything here. Project-specific scientific
requirements may refine this standard.

## Required agent skills

`superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure` are
all hard prerequisites. Before a user-requested modification that will create, edit,
move, or delete files, use the agent host's native skill listing or resolver to
confirm all three exact names. A directory or `SKILL.md` file alone is not a pass. If
a host has no native listing or resolver, all three skills count as unverifiable and
unavailable. If any name is missing or unverifiable, stop before repository
mutations and consult the canonical prerequisite contract at
<https://github.com/lucascamillomd/research-repo-standard/blob/main/references/prerequisites.md>.
If that reference cannot be reached, report it and remain blocked. Resume only when
the host resolves all three exact canonical names. Do not install skills silently,
modify global agent configuration without the user's authorization, or substitute a
generic workflow for a missing skill.

Each user-requested modification that creates, edits, moves, or deletes files takes
one of two paths. The agent classifies the request; when uncertain, use the full
gate.

**Full gate** — required for any result-affecting or contract-affecting change:
estimands, inclusion or exclusion rules, statistical methods or models,
`config/analysis.yaml`, data contracts and schemas, pipeline structure, publication
figures, new analyses, new features, and changes to this standard's rules. Invoke
`superpowers:brainstorming` and open one active gate. After design approval, the
specification, plan, and approval records may be created under that gate; the
requested implementation files remain blocked until the specification is committed
and reviewed by the user and the implementation plan is ready. All direct or
delegated implementation inherits the completed gate. If the requested scope
expands, reopen that same gate at design before implementing the new scope.

**Light path** — for mechanical, non-result-affecting changes: documentation and
typo fixes, comment edits, lint or formatting fixes, renames with no interface
change, refactors fully covered by existing tests, and added tests that do not
change behavior. State the intent, the files to be touched, and why the change is
non-result-affecting; obtain one user confirmation; implement. No specification or
plan artifacts are created. If the change turns out to affect results, interfaces,
or contracts, stop and reopen as a full gate before continuing.

**No gate** — read-only explanation, inspection, diagnosis, and status reporting
are not modifications. Executing an already approved workflow solely to regenerate
its declared outputs does not open a new gate.

| Request | Path |
|---|---|
| Fix a typo in README | light |
| Rename a stage directory with no interface change | light |
| Add a sensitivity analysis | full |
| Change an inclusion threshold in `config/analysis.yaml` | full |
| Rerun `make figures` unchanged | no gate |
| Explain what a pipeline stage does | no gate |

During repository bootstrap, the `superpowers:brainstorming` invocation for the
repository design is this same full gate, not an additional gate. Before
scaffolding, request an independent `scientific-critical-thinking` critique; it
covers the question, claim, study design, estimand, and major validity risks. Invoke
`nature-figure` for the figure strategy with Python fixed as the plotting language.
If no plots are planned, record that outcome in the approved design. While the gate
is active, only the minimum target-repository initialization needed to store and
commit the process artifacts is allowed; all remaining scaffolding stays blocked
until the gate completes.

`scientific-critical-thinking` and `nature-figure` still apply under their
task-specific Analysis and Figures conditions below.

This is a normative agent instruction, not an operating-system access control. It
depends on the agent host loading and following this file.

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
10. **Required agent workflows are gates.** Availability of
    `superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure`
    is required before file-changing work in a user-requested modification;
    invocation follows the modification-gate, bootstrap, and task-specific conditions
    in this standard. A missing or unverifiable skill stops file-changing work. Do
    not imitate or replace an unavailable skill.
11. **Configuration has one owner.** Stable scientific and operational settings live
    in versioned YAML, never as hidden Python globals or defaults. Derived internal
    paths stay in `paths.py`; secrets and machine-specific roots stay in environment
    variables. Unknown, missing, or duplicate-owned values fail before computation;
    an unrecorded result-affecting override fails provenance verification.

## Core principles

1. Make is the canonical user-facing workflow interface.
2. uv manages all ordinary Python environments, dependencies, builds, and commands.
3. Importable and testable logic lives under `src/<package_name>/`.
4. Numbered stage directories under `scripts/` make execution order visible.
5. Scripts are thin orchestration entry points, not libraries.
6. Inputs, parameters, outputs, assumptions, and manual boundaries are explicit.
7. Tests cover scientific invariants and contracts, not only successful execution.
8. Every plot uses Python; publication figures use the full `nature-figure` workflow.
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
│   ├── analysis.yaml
│   └── runtime.yaml                  # optional, proven result-equivalent operations
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
│   ├── diagnostics/                # working plots (PNG), never publication artifacts
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
If the critique skill or a separate review subagent is unavailable, stop before
making or implementing the scientific judgment and report the blocker.

## Figures

Figures come in two tiers. A **publication figure** — manuscript-bound, or an
analytical figure supporting a claim — uses the `nature-figure` skill, is written in
Python, is implemented as importable functions under `src/<package_name>/figures/`,
has traceable source data, and exports all four formats: editable SVG, editable PDF,
600 dpi TIFF, PNG preview. Each format lives in its own extension-named directory
under `results/figures/<figure_id>/`.

A **working plot** — exploratory or diagnostic — uses Python, obeys the determinism
and seed rules, records which declared dataset or artifact it read, and writes a
single PNG under `results/diagnostics/`. It requires no `nature-figure` invocation,
no `docs/FIGURE_CONTRACT.md` entry, no multi-format export, and no QA checklist. A
working plot never silently becomes a publication figure: promotion goes through the
full publication contract, starting from the pre-plot contract.

For publication figures, record the contract in `docs/FIGURE_CONTRACT.md` **before**
writing plotting code.
Never use R or another language to render a preview, fallback, or substitute plot. If
`nature-figure`, Python, or a required Python dependency is unavailable, stop before
plotting and report the exact blocker rather than rendering something else.

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

Stable researcher-editable values have one versioned YAML owner. Scientific and
result-affecting settings — seed, thresholds, inclusion rules, transformations, model
parameters, and any batch size that may affect optimization — live in
`config/analysis.yaml`. Optional `config/runtime.yaml` contains only stable operational
settings demonstrated to preserve results; record the equivalence rationale in
`docs/DECISIONS.md`. When uncertain, classify the value as scientific.

`config.py` strictly validates YAML, rejects unknown and missing fields, composes only
permitted overrides, and returns immutable typed objects passed explicitly into
package functions. It contains no project-specific scientific or operational values,
and optional schema fields never conceal result-affecting Python defaults. Load once
per stage; package functions do not reread YAML or import mutable settings globals.

`paths.py` discovers the repository root and derives canonical internal paths,
containment, and raw-data protections. Internal layout paths never live in YAML.
Credentials, secrets, machine-specific absolute roots, and GPU selection use
environment variables; environment variables never override scientific settings.
Command-line arguments are only for genuine invocation-time variation and use the
same validation as YAML.

For established repositories, apply this migration when editing the function or entry
point that reads a module-level project setting. Preserve behavior with tests, obtain
authorization before changing scientific meaning, and record the migration in
`docs/DECISIONS.md`.

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

Each major build writes a deterministic provenance manifest recording: commit
identifier; hashes and validated effective values for every loaded YAML file; every
CLI override and its source; input identifiers and checksums; environment and
container identity without secret values; secret inputs only by variable name and
redacted presence; seed, worker, parallelism, and accelerator boundaries when
relevant; output inventory and checksums; and declared nondeterministic or manual
boundaries. An unrecorded result-affecting override is a provenance failure.
When legal or data-use restrictions prohibit recording an input identifier, record a
permitted stable registry alias and the restriction, never the barred value.

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

Configuration tests reject unknown and missing fields, hidden result-affecting Python
fallbacks, duplicate ownership, invalid cross-field combinations, and unrecorded
result-affecting overrides. Test that stage entry points load once and pass immutable
typed configuration explicitly, and that `paths.py` cannot redirect canonical raw-data
locations outside their contract.

## Working procedure

Before the context and status checks below, classify the request under the
modification gates in **Required agent skills** and apply the resulting path. Under
a full gate, requested implementation files remain blocked until the gate
completes; its inheritance, regeneration exemption, and scope-expansion rules
govern the implementation that follows.

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
