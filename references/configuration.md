# Reference: configuration ownership contract

This contract classifies settings and defines schema-validated loading, override rejection, path
ownership, configuration provenance, migration, and focused tests.

## Ownership decision

Classify each value by the first matching bucket below. The buckets are mutually exclusive and their
precedence is normative:

1. Credentials, secrets, machine-specific absolute roots, and GPU selection use environment
   variables, even when a researcher chooses them for a run.
2. Values derived from repository structure or another setting are computed rather than configured.
   Derived internal paths always live in `paths.py`; other derived configuration values are computed
   in package code. Do not duplicate either in YAML.
3. All remaining stable researcher-editable scientific or operational settings live in
   `config/analysis.yaml`. This includes every setting that can alter the dataset, estimate, model,
   figure, or scientific claim.
4. An implementation choice that is not a researcher-editable setting remains a named Python
   constant.

## Configuration files

`config/datasets.yaml` owns the dataset registry defined by the data contract;
`config/analysis.yaml` owns the stable researcher-editable settings that remain after the
classification above.

When randomness is used, declare `random_seed: 42` explicitly and propagate it to every stochastic
component. Do not invent a seed field for a fully deterministic workflow.

Python version, packaging metadata, tool configuration, and locked dependencies remain owned by
`.python-version`, `pyproject.toml`, and `uv.lock`. Do not duplicate them in analysis YAML. Do not
create a catch-all `project.yaml` or `settings.yaml`.

## Loading and validation

The Snakefile declares `configfile: "config/analysis.yaml"`, loads `config/datasets.yaml`, and
validates both at DAG-build time with `snakemake.utils.validate` against JSON Schemas in
`workflow/schemas/` that set `additionalProperties: false`. Validation rejects unknown fields,
missing required fields, invalid values, ranges, units, and invalid cross-field combinations before
any job runs.

Package functions never receive or read the Snakemake `config` object. Every result-affecting
configuration value a rule consumes is declared in that rule's `params:` and passed from there as
explicit typed function arguments; rules never read `config` inside rule bodies. Values consumed
only inside a rule body are invisible to Snakemake's invalidation, so the `params:` declaration is
what makes a changed setting rerun the rules that consume it. Never narrow `--rerun-triggers` below
Snakemake's default trigger set, which includes `params` and `code`.

## Override rejection

`--config` and `--configfile` overrides are banned, and the ban is enforced rather than stated.
Snakemake merges command-line overrides into `config` with command-line precedence before schema
validation, so validation alone cannot reject them. The Snakefile re-reads the versioned YAML files
directly at parse time and fails, before the DAG is built, whenever the effective `config` object
diverges from their contents. A scientific or operational setting changes only by editing versioned
YAML. Environment variables never override scientific settings; the Snakefile does not read
`os.environ` for result-affecting values.

## Paths and environment

`src/<package_name>/paths.py` owns repository-root discovery, canonical derived internal paths,
containment checks, and raw-data protections. Internal layout paths such as `data/raw/` and
`results/figures/` never live in YAML, and configuration cannot redirect canonical paths outside
their repository contract.

For environment-owned values (ownership bucket 1), validate permitted external roots and record the
effective machine boundary without recording secret values. Versioned files contain variable names
and safe placeholders, never credentials.

## Configuration provenance

A manifest rule takes both configuration files as inputs and writes a manifest recording each file's
path or stable identifier, SHA-256 hash, and validated effective values, with permitted environment
inputs recorded by variable name and redacted presence; never record a secret value. Snakemake
orders work only through input/output DAG edges, so every result-producing rule declares the
manifest as an input wrapped in `ancient()`. The edge guarantees the manifest exists before any
result job runs, while ignoring its mtime prevents each run's rewritten manifest from invalidating
unchanged work. The manifest must distinguish versioned values from computed values and contain
enough information to reproduce the effective configuration.

## Established repositories

Do not bulk-migrate an established repository solely because this contract changes. Apply this
six-step migration when editing the function or entry point that reads a module-level project
setting:

1. Inventory and classify the values using the ownership decision above.
2. Obtain authorization before changing scientific meaning, an estimand, an inclusion rule, or a
   data contract.
3. Move credentials, secrets, machine-specific roots, and GPU selection to environment variables;
   move derived internal paths to `paths.py` and other derived configuration values into package
   code, deleting `src/<package_name>/config.py` in favor of schema-validated configfile loading.
4. Move the remaining stable researcher-editable scientific or operational settings to
   `analysis.yaml`, and keep non-setting implementation constants in code.
5. Preserve existing behavior with focused tests before intentionally changing values.
6. Record the migration and every authorized value change in `docs/LAB_NOTEBOOK.md`.

## Focused test matrix

Configuration tests cover:

- schema rejection of unknown, missing, invalid, and duplicate-owned values, including invalid
  cross-field combinations, units, and ranges;
- the parse-time guard failing the run before computation when `--config` or `--configfile` diverges
  the effective configuration from versioned YAML;
- explicit `params:` declaration and propagation of every result-affecting value a rule consumes,
  with no `config` reads inside rule bodies;
- a changed result-affecting setting rerunning the downstream rules that consume it, and unchanged
  settings not invalidating unrelated work;
- the manifest existing before any result job runs, including under parallel scheduling, and its
  `ancient()` edge not invalidating unchanged work;
- absence of hidden result-affecting Python defaults and environment overrides of scientific
  settings;
- precedence collisions, including researcher-selected secrets, machine roots, GPU selection, and
  derived paths that must never fall through to YAML;
- rejection of versioned secrets and YAML redirection of canonical paths;
- repository containment and inability to redirect canonical raw-data locations;
- propagation of `random_seed: 42` to every stochastic component when randomness is used;
- absence of a seed setting in a fully deterministic workflow; and
- provenance failure when the manifest cannot record a consumed configuration source.

The guard, manifest-ordering, parallel-scheduling, and rerun entries are runtime integration tests
implemented by the bootstrapped repository, not by this skill repository.
