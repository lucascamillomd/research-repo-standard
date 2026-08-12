# Reduced Documentation Contract Design

## Goal

Reduce generated research-repository documentation to files with distinct, durable
responsibilities. Remove prose files that duplicate executable workflow definitions,
versioned configuration, code, or one another.

## Documentation ownership

### Workflow

Do not create `docs/PIPELINE.md`.

The Makefile dependency graph is the canonical workflow definition. `make help`
exposes user-facing entry points, numbered directories under `scripts/` make normal
execution order visible, and the README states the shortest reproduction path and any
manual, external, expensive, or inaccessible boundaries.

### Data

Do not create `docs/DATA.md`.

`config/datasets.yaml` is the canonical dataset registry. It records enough information
to identify and obtain each dataset, establish its version and row grain, understand
its permitted use, and locate its schema or variable dictionary. Large schemas and
dictionaries remain machine-readable files linked from the registry rather than prose
duplicated in a second document.

The skill's `references/data.md` remains. It owns directory semantics, validation
expectations, data-registry guidance, and fixture rules that do not belong in a project
registry entry.

### Decisions and chronology

Do not create `docs/DECISIONS.md`. Create `docs/lab_notebook.md` as the single
append-only chronological record.

Every consequential decision entry records:

- date;
- decision;
- rationale and evidence;
- who authorized it or the approval source; and
- affected analyses, configuration, data contracts, figures, or outputs.

Corrections and reversals append a new entry that names the superseded decision. They
do not rewrite historical entries. Routine run detail remains in logs and provenance
manifests rather than the lab notebook.

### Methods

Do not create or prescribe `docs/METHODS.md`.

During repository work, the implemented scientific method is represented by the
approved analysis plan, validated configuration, code, tests, and provenance. A
manuscript or formal report owns its publication-specific methods narrative rather
than maintaining a parallel repository document that can drift.

## Standard changes

Update all normative references so:

- workflow guidance points to Make, `make help`, numbered scripts, and the README;
- project data documentation points to `config/datasets.yaml` and linked
  machine-readable schemas or dictionaries;
- decision and setup-provenance recording points exclusively to
  `docs/lab_notebook.md`;
- the repository layout omits `PIPELINE.md`, `DATA.md`, `DECISIONS.md`, and
  `METHODS.md`;
- no guidance presents those four files as optional fallback owners.

Relevant files are `AGENTS.md`, `references/analysis.md`,
`references/configuration.md`, `references/data.md`, `references/prerequisites.md`,
and the consistency tests. Existing unrelated working-tree changes must be preserved.

## Verification

Extend the consistency tests to fail if the standard or its references prescribe any
of the four removed generated documents. Verify that consequential decision guidance
points to `docs/lab_notebook.md` and that the existing vendoring tests continue to
pass.
