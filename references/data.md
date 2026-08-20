# Reference: data contract

This contract defines dataset registration, acquisition records, received-form descriptions,
schemas, validation, checksums, and dataset-specific documentation.

## Registry

`config/datasets.yaml` is mandatory. Without reading code, a reader must be able to determine what
each dataset is, where it came from, which version was received, what one row represents, and what
may legally be done with it.

Record the fields needed to answer those questions, normally including:

- a stable machine-readable identifier and human-readable title;
- citation, accession, registry identifier, or stable source URL;
- a received-form description of the source material, without an internal repository path;
- acquisition method and the script or documented manual boundary responsible;
- source version, release, retrieval date, or other permitted stable identity;
- expected received files and the row grain of derived datasets;
- SHA-256 checksum for immutable downloads, models, and important resources when permitted;
- license, consent, contractual, or other data-use restrictions;
- machine-readable data dictionary or schema location; and
- upstream source and downstream pipeline stages.

`paths.py` derives internal locations such as `data/raw/...`; do not encode those paths in a
registry received-form description. Use programmatic acquisition when licensing and access controls
permit it. Validate stable accessions or URLs and the expected SHA-256 digest before accepting an
acquired artifact.

A per-dataset `README.md` is optional when local access, provenance, manual acquisition, or data-use
instructions are unique. It supplements the registry; `config/datasets.yaml` remains the canonical
index.

## Validation

Validate every dataset before analysis. The validation contract checks, as applicable:

- required and unexpected columns;
- dtypes, category levels, encodings, and units;
- valid ranges and known cross-field constraints;
- declared row grain and identifier uniqueness;
- permitted nullability and sentinel values defined by the schema;
- join cardinality and unmatched-key accounting;
- ordering invariants when order has meaning; and
- expected file inventory, stable identifiers, and checksums.

Fail with a precise dataset identifier and violated rule. Validation creates no implicit correction;
cleaning, harmonization, and derivation belong in declared downstream stages with new outputs.

## Machine-readable data dictionary

Every analysis-ready dataset has a machine-readable data dictionary or schema linked from its
registry entry. For each field, record its name, scientific meaning, type, unit, coding or category
levels, allowed range or values, missing-value representation, provenance, and derivation when
applicable. Also record the dataset row grain, primary or candidate keys, and cross-field
constraints.

Terse column names are not documentation. Keep human explanation near the schema when needed, but
make validation consume the same machine-readable definitions that readers inspect.
