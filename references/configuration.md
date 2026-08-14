# Reference: configuration ownership contract

This contract classifies settings and defines strict configuration loading, path ownership,
overrides, configuration provenance, migration, and focused tests.

## Ownership decision

Classify each value by the first matching bucket below. The buckets are mutually exclusive and their
precedence is normative:

1. Credentials, secrets, machine-specific absolute roots, and GPU selection use environment
   variables, even when a researcher chooses them for a run.
2. Values derived from repository structure or another setting are computed rather than configured.
   Derived internal paths always live in `paths.py`; other derived configuration values may be
   computed in `config.py`. Do not duplicate either in YAML.
3. All remaining stable researcher-editable scientific or operational settings live in
   `config/analysis.yaml`. This includes every setting that can alter the dataset, estimate, model,
   figure, or scientific claim.
4. An implementation choice that is not a researcher-editable setting remains a named Python
   constant.

## Configuration files

After environment-owned and derived values have been classified, `config/analysis.yaml` owns the
remaining stable researcher-editable settings. `config/datasets.yaml` owns the dataset registry
defined by the data contract.

When randomness is used, declare `random_seed: 42` explicitly and propagate it to every stochastic
component. Do not invent a seed field for a fully deterministic workflow.

Python version, packaging metadata, tool configuration, and locked dependencies remain owned by
`.python-version`, `pyproject.toml`, and `uv.lock`. Do not duplicate them in analysis YAML. Do not
create a catch-all `project.yaml` or `settings.yaml`.

## Loading and overrides

Load configuration once per stage through `src/<package_name>/config.py`, before expensive
computation. The loader owns schemas, parsing, type conversion, ranges, units, cross-field
validation, and composition of permitted overrides. Reject unknown fields, missing required fields,
invalid values, and values with more than one owner.

Return immutable typed objects and pass them explicitly from entry points into package functions.
Package functions do not reread YAML or import mutable module-level settings. `config.py` contains
no project-specific scientific or operational values. Optional schema fields may represent a genuine
absent state, but they never conceal a scientific default or result-affecting fallback in Python.

Command-line arguments are reserved for genuine invocation-time variation and use the same
validation as YAML. Define which fields may be overridden and reject all others. Environment
variables never override scientific settings.

## Paths and environment

`src/<package_name>/paths.py` owns repository-root discovery, canonical derived internal paths,
containment checks, and raw-data protections. Internal layout paths such as `data/raw/` and
`results/figures/` never live in YAML, and configuration cannot redirect canonical paths outside
their repository contract.

Credentials, secrets, machine-specific absolute roots, and GPU selection use environment variables.
Validate permitted external roots and record the effective machine boundary without recording secret
values. Versioned files contain variable names and safe placeholders, never credentials.

## Configuration provenance

Before computation, create a validated effective configuration. For every loaded YAML file, record
its path or stable identifier, SHA-256 hash, and validated effective values. Record every CLI
override, its value, its source, and whether it can affect results. Record permitted environment
inputs by variable name and redacted presence; never record a secret value.

Reject an unrecorded result-affecting override. The manifest must distinguish versioned values from
invocation-time values and contain enough information to reproduce the composition order.

## Established repositories

Do not bulk-migrate an established repository solely because this contract changes. Apply this
six-step migration when editing the function or entry point that reads a module-level project
setting:

1. Inventory and classify the values using the ownership decision above.
2. Obtain authorization before changing scientific meaning, an estimand, an inclusion rule, or a
   data contract.
3. Move credentials, secrets, machine-specific roots, and GPU selection to environment variables;
   move derived internal paths to `paths.py` and other derived configuration values to `config.py`.
4. Move the remaining stable researcher-editable scientific or operational settings to
   `analysis.yaml`, and keep non-setting implementation constants in code.
5. Preserve existing behavior with focused tests before intentionally changing values.
6. Record the migration and every authorized value change in `docs/lab_notebook.md`.

## Focused test matrix

Configuration tests cover:

- rejection of unknown, missing, invalid, and duplicate-owned values;
- invalid cross-field combinations, units, ranges, and override composition;
- immutable typed return objects, one load per stage, and explicit parameter propagation;
- absence of hidden result-affecting Python defaults and environment overrides of scientific
  settings;
- precedence collisions, including researcher-selected secrets, machine roots, GPU selection, and
  derived paths that must never fall through to YAML;
- rejection of versioned secrets and YAML redirection of canonical paths;
- repository containment and inability to redirect canonical raw-data locations;
- propagation of `random_seed: 42` to every stochastic component when randomness is used;
- absence of a seed setting in a fully deterministic workflow; and
- provenance failure for every omitted or unrecordable result-affecting override.
