# Reference: configuration ownership contract

This contract owns setting classification, schema-validated loading, override rejection, path
ownership, configuration provenance, migration, and the focused configuration tests.

## Ownership decision

Classify each value by the first matching bucket. The buckets are mutually exclusive:

1. Credentials, secrets, machine-specific absolute roots, and GPU selection use environment
   variables, even when a researcher chooses them for a run.
2. Values derived from repository structure or another setting are computed, never configured.
   Derived internal paths live in `paths.py`; other derived values live in package code. Do not
   duplicate either in YAML.
3. Dataset registry entries live in `config/datasets.yaml`; `references/data.md` defines their
   fields.
4. All other researcher-editable scientific or operational settings live in `config/analysis.yaml`.
   This includes every setting that can alter the dataset, estimate, model, figure, or scientific
   claim.
5. An implementation choice that is not a researcher-editable setting remains a named Python
   constant.

## Configuration files

When the workflow uses randomness, declare `random_seed: 42` and propagate it to every stochastic
component. Do not add a seed field to a fully deterministic workflow.

`.python-version`, `pyproject.toml`, and `uv.lock` own the Python version, packaging metadata, tool
configuration, and locked dependencies. Do not duplicate them in analysis YAML, and do not create a
catch-all `project.yaml` or `settings.yaml`.

## Loading and validation

The Snakefile declares `configfile: "config/analysis.yaml"`, loads `config/datasets.yaml`, and
validates both at DAG-build time with `snakemake.utils.validate` against JSON Schemas in
`workflow/schemas/` that set `additionalProperties: false`. Validation rejects unknown fields,
missing required fields, invalid values, ranges, units, and invalid cross-field combinations before
any job runs.

Package functions never receive or read the Snakemake `config` object. Every result-affecting value
a rule consumes is declared in that rule's `params:` and passed on as explicit typed function
arguments; rules never read `config` inside rule bodies. Snakemake's invalidation cannot see values
read only inside a rule body, so the `params:` declaration is what makes a changed setting rerun its
consumers. Never narrow `--rerun-triggers` below Snakemake's default trigger set, which includes
`params` and `code`.

## Override rejection

`--config` and `--configfile` overrides are banned, and the Snakefile enforces the ban. Snakemake
merges command-line overrides over the YAML values before schema validation, so validation alone
cannot reject them. At parse time, before the DAG is built, the Snakefile re-reads the versioned
YAML files and fails whenever the effective `config` object diverges from their contents. A
scientific or operational setting changes only by editing versioned YAML. Environment variables
never override scientific settings; the Snakefile never reads `os.environ` for result-affecting
values.

## Paths and environment

`src/<package_name>/paths.py` owns repository-root discovery, canonical derived internal paths,
containment checks, and raw-data protections. Internal layout paths such as `data/raw/` and
`results/figures/` never live in YAML, and no configuration may redirect a canonical path outside
its repository contract.

For environment-owned values under bucket 1, validate permitted external roots and record the
effective machine boundary without recording secret values. Versioned files hold variable names and
safe placeholders, never credentials.

## Configuration provenance

A manifest rule takes both configuration files as inputs and writes a manifest with each file's path
or stable identifier, SHA-256 hash, and validated effective values. It records permitted environment
inputs by variable name and redacted presence, never by value. Snakemake orders work only through
input/output DAG edges, so every result-producing rule declares the manifest as an `ancient()`
input. The edge guarantees the manifest exists before any result job runs; ignoring its mtime keeps
each run's rewritten manifest from invalidating unchanged work. The manifest must separate versioned
values from computed values and hold enough to reproduce the effective configuration.

## Established repositories

Do not bulk-migrate an established repository only because this contract changed. Migrate when
editing the function or entry point that reads a module-level project setting, or as an accepted
step of an adoption-mode migration plan:

1. Inventory each module-level setting and classify it by the ownership decision above.
2. Pin the current effective values and behavior with focused tests before relocating anything.
3. Relocate each value to the owner its bucket assigns; bucket-5 constants stay in code. Delete the
   module that held them, typically `src/<package_name>/config.py`, in favor of schema-validated
   configfile loading. The relocation must not change any effective value.
4. Take every intentional value change through the gate its change class requires under SKILL.md.
5. Record the migration in `docs/LAB_NOTEBOOK.md`; gated value changes carry their own entries.

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

The guard, manifest-ordering, parallel-scheduling, and rerun entries are integration tests that
execute Snakemake.
