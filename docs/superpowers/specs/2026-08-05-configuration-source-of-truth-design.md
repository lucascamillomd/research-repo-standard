# Configuration Source-of-Truth Design

**Date:** 2026-08-05

## Context

The standard currently says that scientific decisions and stable parameters belong in
versioned configuration, while `config.py` loads configuration and `paths.py`
centralizes paths. In practice, agents can still hide seeds, thresholds, batch sizes,
worker counts, and similar project settings as module-level Python values. That makes
the effective analysis harder to inspect, review, and reproduce.

The standard needs a sharper ownership contract: stable researcher-editable values
live in YAML, Python validates and consumes them, environment variables supply secrets
and machine-specific values, and derived repository paths remain in `paths.py`.

## Goals

1. Make versioned YAML the source of truth for stable scientific and operational
   settings.
2. Prevent project-specific values from being duplicated or silently defaulted in
   Python.
3. Preserve `paths.py` as the single implementation boundary for derived repository
   paths and containment checks.
4. Make the effective configuration, overrides, and source hashes visible in
   provenance.
5. Give new repositories a clear bootstrap pattern and established repositories a
   narrow migration path.

## Non-goals

- Do not replace `paths.py` with YAML path strings.
- Do not put secrets, credentials, or machine-specific absolute roots in versioned
  YAML.
- Do not require an automatic bulk migration of established repositories.
- Do not prescribe a particular schema library when strict typed validation can be
  implemented equivalently.
- Do not add a generic catch-all `project.yaml` or `settings.yaml`.

## Configuration ownership

Classify each setting in this order:

1. If changing it can alter the dataset, estimate, model, figure, or scientific claim,
   place it in `config/analysis.yaml`.
2. If it should preserve the intended result but alter performance or resilience,
   place it in optional `config/runtime.yaml`.
3. If it is secret or machine-specific, supply it through an environment variable.
4. If it is derived from repository structure or another setting, compute it in
   `paths.py` or `config.py` rather than duplicating it in YAML.
5. If changing it inherently changes the implementation, keep it as a named Python
   constant.

When classification is uncertain, treat the value as scientific until evidence shows
that changing it cannot affect results.

Classifying a setting as result-equivalent runtime configuration requires a durable
one-line rationale in `docs/DECISIONS.md` that identifies the evidence or invariant
supporting equivalence. Without that record, keep the setting in `analysis.yaml`.

Examples:

| Setting | Owner |
|---|---|
| Random seed | `config/analysis.yaml` when randomness is used |
| Inclusion threshold or transformation choice | `config/analysis.yaml` |
| Model hyperparameter | `config/analysis.yaml` |
| Training batch size that can affect optimization | `config/analysis.yaml` |
| Proven result-equivalent batch, chunk, or worker count | `config/runtime.yaml` |
| Retry policy that cannot change included data | `config/runtime.yaml` |
| External data root or GPU selection | Environment variable, with the effective boundary in provenance |
| Credentials | Environment variable only |
| `data/raw/` and `results/figures/` paths | Derived by `paths.py` |
| Schema names and algorithmic invariants | Python |

The selected Python minor, package pins, and tool configuration remain in their
existing sources of truth (`.python-version`, `pyproject.toml`, and `uv.lock`) rather
than moving into analysis or runtime YAML.

## Files and responsibilities

The configuration directory has these roles:

```text
config/
├── datasets.yaml              # mandatory dataset provenance and legal-use registry
├── analysis.yaml              # mandatory scientific and result-affecting settings
└── runtime.yaml               # optional stable performance and resilience settings
```

`config/analysis.yaml` is present in every new repository. A setting is included when
the corresponding behavior exists; for example, `random_seed: 42` is required when a
stage uses randomness and is not invented when the workflow is deterministic.

Create `config/runtime.yaml` only when the project has stable operational settings.
Do not create an empty file merely to satisfy the layout example.

`src/<package_name>/config.py` owns schemas, parsing, type conversion, range and unit
checks, cross-field validation, and composition of permitted overrides. It contains no
project-specific scientific or operational values. Schema-level optionality may
represent a real absent state, but it must not conceal a result-affecting default.

`src/<package_name>/paths.py` remains responsible for repository-root discovery,
canonical internal paths, environment-provided external roots, path containment, and
raw-data safety. Internal layout paths are derived from the repository contract and
must not be repeated in YAML.

## Loading and data flow

Each stage entry point loads configuration once through `config.py`, validates it
before expensive work, and passes immutable typed configuration objects into package
functions. Package functions do not reread YAML independently and do not import
mutable module-level settings.

Command-line arguments remain available only for values that genuinely vary between
invocations. An override must use the same validation as its YAML field. Any override
that can affect outputs must be recorded in provenance; confirmatory analyses also
remain bound by their approved analysis plan and decision log.

Environment variables may override only values classified as secret or
machine-specific. They must not silently override scientific settings.

Reject:

- missing required scientific settings;
- unknown fields;
- invalid types, ranges, units, or cross-field combinations;
- the same setting owned by more than one source;
- result-affecting overrides that cannot be recorded;
- versioned secrets or machine-specific absolute roots; and
- YAML attempts to redirect canonical internal paths or immutable raw-data locations.

## Provenance

Each major build records:

- hashes of every loaded YAML configuration file;
- the validated effective scientific and runtime configuration;
- every CLI override and its source;
- relevant environment-provided machine boundaries without secret values; record
  secret inputs only by variable name and redacted presence, never by value;
- the seed when randomness is used;
- worker, parallelism, or accelerator settings when they can affect determinism; and
- declared nondeterministic boundaries.

A successful run with an unrecorded result-affecting override is a provenance failure.

## Established-repository migration

Do not migrate an established repository wholesale merely because this standard
changes. Apply the migration when the function or entry point that reads a
module-level project setting is edited:

1. Inventory module-level values and classify them with the ownership rules.
2. Obtain authorization before moving or changing a scientific decision, estimand,
   inclusion rule, or data contract.
3. Move stable scientific settings to `analysis.yaml` and stable operational settings
   to `runtime.yaml` when needed.
4. Keep derived paths in `paths.py` and machine-specific values in environment
   variables.
5. Preserve existing behavior with focused tests before changing values.
6. Record the migration and any intentional value change in `docs/DECISIONS.md`.

## Standard and skill changes

Implementation will:

- create `references/configuration.md` as the detailed canonical contract;
- update `SKILL.md` to route configuration work to that reference;
- update `AGENTS.md` with the mandatory concise ownership, loading, provenance, and
  migration rules;
- update the repository layout to show optional `config/runtime.yaml`;
- update `README.md` to advertise the new reference;
- update `references/bootstrap.md` with scaffold and loader guidance; and
- update `references/analysis.md` so result-affecting parameters and seed are explicit
  in `analysis.yaml`.

The changed normative files receive `standard_version: 2026.08.05`. Detailed examples
live in `references/configuration.md` rather than being duplicated across the skill
entry point and vendored standard.

## Validation

Validation will include:

1. The skill-creator metadata validator.
2. Markdown and exact cross-file contract searches.
3. `bash -n vendor.sh` and an isolated vendoring fixture that preserves the target
   repository identity section.
4. Checks that `analysis.yaml`, optional `runtime.yaml`, `config.py`, and `paths.py`
   have one non-contradictory responsibility each.
5. Negative checks against instructions that put stable project settings or canonical
   internal paths in Python or YAML respectively.
6. A loader test in generated repositories showing that an optional schema field with
   a non-null, result-affecting Python fallback is rejected rather than silently used.
7. A provenance verification test showing that a result-affecting CLI override without
   a manifest record fails the verification gate.
8. A fresh-agent forward test asking for a hard-coded batch size that may affect model
   optimization. The agent must classify it as scientific unless equivalence is
   demonstrated and recorded, update the correct YAML contract, and keep derived paths
   out of YAML.

These checks verify instruction behavior and contract consistency. They do not prove
that a future repository's scientific settings are valid.

## Acceptance criteria

- Stable scientific and operational settings have explicit YAML ownership.
- `config.py` validates and passes typed configuration without owning project values.
- `paths.py` remains the only owner of derived repository paths.
- Secrets and machine-specific roots remain outside versioned YAML.
- Effective configuration and result-affecting overrides are recorded in provenance.
- New repositories follow the contract immediately; established repositories migrate
  when the function or entry point reading a module-level project setting is edited,
  with required scientific authorization.
- The skill validates, vendoring preserves the complete concise contract, and the
  forward test routes settings correctly without introducing Python globals.
