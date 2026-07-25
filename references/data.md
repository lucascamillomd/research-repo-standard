<!-- standard_version: 2026.07.25 -->

# Reference: data contract

Read when registering a dataset, defining a schema, or writing validation.
`AGENTS.md` states the rules; this expands the mechanics.

## Directory semantics

- `data/raw/<dataset_id>/` — immutable source material in its received form
- `data/interim/<dataset_id>/` — incomplete or intermediate transformations not yet
  approved as analysis-ready
- `data/processed/<dataset_id>/` — validated, analysis-ready data with a defined row
  grain and schema
- `data/external/<resource_id>/` — reference databases, ontologies, model assets, or
  other resources that are not study observations

Pipeline code never modifies a file beneath `data/raw/`.

## Registry

`config/datasets.yaml` is mandatory. A reader must be able to answer, without reading
code: what this data is, where it came from, which version, what one row means, and
what may legally be done with it.

Fields that usually carry that weight:

- stable identifier and human-readable title
- citation or accession
- expected local location
- acquisition method and the script responsible
- source version or retrieval date
- expected files and row grain
- checksum, when appropriate and permitted
- license or data-use restrictions
- variable dictionary location
- upstream and downstream pipeline stages

Record whatever it takes to answer the five questions — not every field for its own
sake, and not fewer than the questions require.

For externally acquired data, provide programmatic acquisition when licensing permits.
Use stable accessions or URLs, and verify SHA-256 checksums for immutable downloads,
models, and important resources.

A dataset-specific `README.md` may live inside its directory when local provenance or
access instructions are unique. The registry remains the canonical index.

## Validation

Validate before analysis, not after. Check:

- required and unexpected columns
- dtypes and category levels
- units and valid ranges
- row grain and identifier uniqueness
- missingness assumptions
- join cardinality
- ordering invariants, when order matters
- known cross-field constraints

Turn inclusion and exclusion criteria into testable code, and produce an attrition
table or flow record when appropriate. Report missingness before exclusions or
imputation.

## Data dictionary

Record units, semantics, coding, provenance, and missing-value meanings in
`docs/DATA.md` or a linked machine-readable dictionary. Terse column names are not
documentation.

## Fixtures

Prefer small deterministic fixtures that exercise the behaviour under test. Synthetic
and real-data fixtures are both acceptable; choose whichever gives the clearest,
most representative test without making the repository unnecessarily large.

Tests requiring real data belong in the full verification path, not public CI. CI
fixtures are already in the repository or generated during the run.
