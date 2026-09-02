# Reference: data contract

This contract owns dataset registration, acquisition records, received-form descriptions, schemas,
validation, checksums, and per-dataset documentation.

## Registry

`config/datasets.yaml` is mandatory. Without reading code, a reader must be able to tell what each
dataset is, where it came from, which version was received, what one row represents, and what may
legally be done with it.

Record the fields that answer those questions, normally including:

- a stable machine-readable identifier and human-readable title;
- citation, accession, registry identifier, or stable source URL;
- a received-form description: the file formats, packaging, and structure in which the source
  material arrives;
- acquisition method and the script or documented manual boundary responsible;
- source version, release, retrieval date, or other permitted stable identity;
- expected received files and the row grain of derived datasets;
- optional SHA-256 checksum, recommended only for shared or redistributable fixtures and for
  downloads whose upstream publishes a digest;
- license, consent, contractual, or other data-use restrictions;
- machine-readable data dictionary or schema location; and
- upstream source and downstream pipeline stages.

`paths.py` derives internal locations such as `data/raw/...` under ownership bucket 2 of
`references/configuration.md`. A received-form description never names them. Acquire by script when
licensing and access controls allow. Validate the accession or URL before accepting an acquired
artifact, and check a download against its published digest when the upstream provides one. Local
raw data never needs a checksum.

A per-dataset `README.md` is optional. Add one when a dataset has its own access, provenance,
manual-acquisition, or data-use instructions. It supplements the registry; `config/datasets.yaml`
stays the canonical index.

## Validation

Validate every dataset before analysis. Check, as applicable:

- required and unexpected columns;
- dtypes, category levels, encodings, and units;
- valid ranges and known cross-field constraints;
- declared row grain and identifier uniqueness;
- permitted nullability and sentinel values defined by the schema;
- join cardinality and unmatched-key accounting;
- ordering invariants when order has meaning; and
- expected file inventory, stable identifiers, and checksums the registry records.

Check a checksum only when the registry records one; an absent checksum is not a validation failure.
Fail with the dataset identifier and the violated rule. Validation makes no implicit correction.
Cleaning, harmonization, and derivation belong in declared downstream stages that write new outputs.

## Machine-readable data dictionary

Every analysis-ready dataset has a machine-readable data dictionary or schema linked from its
registry entry. For each field, record name, scientific meaning, type, unit, coding or category
levels, allowed range or values, missing-value representation, provenance, and derivation when
applicable. Also record the row grain, primary or candidate keys, and cross-field constraints.

Terse column names are not documentation. Keep prose explanation near the schema when needed, and
make validation read the same machine-readable definitions that readers inspect.
