<!-- standard_version: 2026.08.13 -->

# Reference: data contract

`AGENTS.md` owns the normative portable policy. This reference is its procedural expansion for
registering datasets, defining schemas, and writing validation.

## Registry

`config/datasets.yaml` is mandatory. A reader must be able to answer, without reading code: what
this data is, where it came from, which version, what one row means, and what may legally be done
with it.

Fields that usually carry that weight:

- stable identifier and human-readable title
- citation or accession
- registry identifier and received-form description; internal `data/raw/...` paths stay in
  `paths.py`
- acquisition method and the script responsible
- source version or retrieval date
- expected files and row grain
- checksum, when appropriate and permitted
- license or data-use restrictions
- variable dictionary location
- upstream and downstream pipeline stages

Record whatever it takes to answer the five questions — not every field for its own sake, and not
fewer than the questions require.

For externally acquired data, provide programmatic acquisition when licensing permits. Use stable
accessions or URLs, and verify SHA-256 checksums for immutable downloads, models, and important
resources.

A dataset-specific `README.md` may live inside its directory when local provenance or access
instructions are unique. The registry remains the canonical index.

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

`AGENTS.md` floor items 4–5 apply to validation and attrition.

## Data dictionary

Record units, semantics, coding, provenance, and missing-value meanings in a machine-readable schema
or dictionary linked from the corresponding `config/datasets.yaml` entry. Terse column names are not
documentation.
