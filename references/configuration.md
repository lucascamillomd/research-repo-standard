<!-- standard_version: 2026.08.13 -->

# Reference: configuration ownership contract

`AGENTS.md` owns the normative portable policy. This reference is its procedural expansion for
classifying, loading, migrating, and testing configuration.

## Ownership decision

Classify each stable researcher-editable value in this order:

1. If changing a value can alter the dataset, estimate, model, figure, or scientific claim, put it
   in `config/analysis.yaml`.
2. If it is secret or machine-specific, supply it through an environment variable.
3. If it is derived from repository structure or another setting, compute it in `paths.py` or
   `config.py`; do not duplicate it in YAML.
4. If it is an implementation choice rather than a researcher-editable scientific or operational
   setting, keep it as a named Python constant.

## Configuration files

`analysis.yaml` owns settings and `datasets.yaml` is governed by the data contract.

Python version, packaging metadata, tool configuration, and locked dependencies keep their existing
sources of truth in `.python-version`, `pyproject.toml`, and `uv.lock`. Do not duplicate them in
analysis YAML. Do not create a catch-all `project.yaml` or `settings.yaml`.

## Loading and overrides

Load configuration once per stage through `src/<package_name>/config.py`, before expensive
computation. The loader owns schemas, parsing, type conversion, ranges, units, cross-field
validation, and composition of permitted overrides. It rejects unknown fields, missing required
fields, invalid values, and duplicate ownership.

The loader returns immutable typed objects that entry points pass explicitly into package functions.
Package functions do not reread YAML and do not import mutable module-level settings. `config.py`
contains no project-specific scientific or operational values. Optional schema fields may represent
a genuine absent state, but scientific values have no silent Python defaults or result-affecting
fallbacks.

Command-line arguments are for genuine invocation-time variation. Overrides use the same validation
as YAML. Every result-affecting override and its source is recorded in provenance; reject an
override that cannot be recorded. Confirmatory overrides also remain subject to the approved
analysis plan and decision log.

## Paths and environment

`src/<package_name>/paths.py` owns repository-root discovery, canonical derived internal paths,
containment checks, and raw-data safety. Internal layout paths such as `data/raw/` and
`results/figures/` never live in YAML, and YAML cannot redirect them outside the repository
contract.

Credentials, secrets, machine-specific absolute roots, and GPU selection use environment variables.
Environment variables may not override scientific settings. Validate permitted external roots and
record the effective machine boundary without recording secret values.

## Provenance

Record every result-affecting override and its source. Reject an override that cannot be recorded.
The complete manifest inventory is defined by `AGENTS.md`.

## Established repositories

Do not bulk-migrate an established repository solely because this contract changes. Apply the
migration when editing the function or entry point that reads a module-level project setting:

1. Inventory and classify the values using the ownership decision above.
2. Obtain authorization before changing scientific meaning, an estimand, an inclusion rule, or a
   data contract.
3. Move stable scientific values to `analysis.yaml`.
4. Keep derived paths in `paths.py` and machine-specific values in environment variables.
5. Preserve existing behavior with focused tests before intentionally changing values.
6. Record the migration and any authorized value change in `docs/lab_notebook.md`.

## Tests

Configuration tests reject versioned secrets and YAML redirection of canonical paths. When
stochastic processing is used, they verify propagation of `random_seed: 42` to every stochastic
component. They also fail verification when an override is absent from provenance.
