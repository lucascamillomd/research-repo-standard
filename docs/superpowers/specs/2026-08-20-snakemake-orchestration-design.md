# Design: Snakemake as the default orchestration engine

Date: 2026-08-20
Status: approved in discussion; pending spec review

## Summary

The research-repo-standard currently uses Make as both the public workflow interface and the
pipeline runner, with numbered stage scripts under `scripts/` and a strict custom configuration
loader in `src/<package_name>/config.py`. This design makes Snakemake the default pipeline engine
for every bootstrapped repository: the Snakefile replaces the numbered stage scripts as the
orchestration layer, configuration moves to Snakemake-native loading with schema validation, and
Make remains the unchanged mandatory public interface wrapping Snakemake invocations.

## Decisions taken

1. **Positioning: default engine.** Every bootstrapped repository gets a Snakemake workflow. Not an
   optional escalation.
2. **Stage layer: Snakefile replaces stage scripts.** `scripts/` and its numbered stages are removed
   from the scaffold. Rules call package functions directly.
3. **Configuration: full Snakemake-native.** `config.py` and its immutable-typed-object loader are
   deleted. Snakemake's `configfile` mechanism plus JSON Schema validation owns loading.

## Section 1 — Workflow layer

- Adopt Snakemake's standardized layout as the default scaffold, always:
  - `workflow/Snakefile` — declares `configfile`, `rule all`, and includes rule modules;
  - `workflow/rules/*.smk` — rule modules, part of the default scaffold from bootstrap, not an
    escape hatch for growth;
  - `workflow/schemas/` — JSON Schemas for configuration validation.
- Rules are thin orchestration. Each rule declares `input:`, `output:`, and `log:`; its body is a
  single call into `src/<package_name>/` functions. The existing contract "stage scripts orchestrate
  and do not contain logic; importable and testable logic lives under `src/`" transfers to rules
  verbatim. No scientific logic in `run:` blocks.
- `rule all` builds the full pipeline. Named pseudo-rules (`analysis`, `figures`) group targets.
- Make remains the mandatory public interface with the same required targets (`help`, `setup`,
  `test`, `verify-results`). Pipeline-facing targets are one-line wrappers, e.g.
  `make pipeline` → `uv run snakemake --cores all`. The reader contract — reach the analysis,
  figures, full pipeline, and verification without knowing internal paths — is unchanged.
- `snakemake` becomes a locked runtime dependency in `pyproject.toml` / `uv.lock`.
- Cleanup remains explicit Make targets incapable of reaching `data/raw/`. Do not rely on
  `snakemake --delete-all-output`.
- The bootstrap caveat "phony high-level targets need not pretend to provide file-level
  incrementality" is deleted. Incrementality is real and Snakemake owns it.

## Section 2 — Configuration contract

- The four ownership buckets and their precedence in `references/configuration.md` survive intact:
  environment for credentials/machine roots/GPU selection; computed values in `paths.py` (and
  derived values in code); researcher-editable scientific and operational settings in
  `config/analysis.yaml`; implementation constants in code. `config/datasets.yaml` keeps the
  dataset registry.
- `src/<package_name>/config.py` is deleted. The Snakefile declares
  `configfile: "config/analysis.yaml"` and reads `config/datasets.yaml`; both are validated at
  DAG-build time with `snakemake.utils.validate` against JSON Schemas in `workflow/schemas/` using
  `additionalProperties: false`, preserving rejection of unknown fields, missing required fields,
  and invalid values.
- Package functions never receive or read the Snakemake `config` object. Rules pass individual
  values as explicit typed function arguments. Explicit propagation and the ban on global mutable
  settings survive at the function boundary.
- `--config` and `--configfile` CLI overrides are banned outright, and the ban is enforced, not
  merely stated: Snakemake merges CLI overrides into `config` with command-line precedence before
  schema validation, so validation alone cannot reject them. The Snakefile therefore re-reads the
  versioned YAML files directly at parse time and fails, before the DAG is built, whenever the
  effective `config` object diverges from their contents. A scientific or operational setting
  changes only by editing versioned YAML. This replaces the previous CLI-override whitelist.
- Environment variables still never override scientific settings; the Snakefile does not read
  `os.environ` for result-affecting values.
- The provenance manifest requirement survives as a manifest rule whose inputs are both config
  files and whose output records each file's path, SHA-256 hash, and validated effective values.
  Snakemake orders work only through input/output DAG edges, so every result-producing rule
  declares the manifest as an input, wrapped in `ancient()`: the dependency edge guarantees the
  manifest exists before any result job runs, while ignoring its mtime prevents each run's
  rewritten manifest from spuriously invalidating the whole pipeline.
- Every result-affecting configuration value a rule consumes is declared in that rule's `params:`
  and passed from there as explicit function arguments; rules never read `config` inside rule
  bodies. Combined with `--rerun-triggers` including `params`, this is what makes a changed
  setting genuinely invalidate downstream outputs — values consumed only inside a rule body are
  invisible to Snakemake's invalidation.
- The seed contract is unchanged: `random_seed: 42` declared and propagated when randomness exists;
  no seed field for a deterministic workflow.
- The six-step migration for established repositories is updated to target the new loading
  mechanism; the ownership classification steps are unchanged.

## Section 3 — Stage logging

- The `## Stage logging` contract moves from script entry points to rules. Each rule declares
  `log:`; the rule body configures the loguru sink to that log file at the `log_level` owned by
  `config/analysis.yaml` before calling package code.
- Package code still calls `logger.<level>()` and configures no sink at import time. Logging
  verbosity is never sourced from the environment.

## Section 4 — Documentation surfaces

- `SKILL.md`: scaffold core-contracts line becomes "uv, Snakemake, and Make"; workflow-stage wording
  updated where it references numbered stages.
- `references/bootstrap.md`: repository tree, stage-naming section, Make-interface section, and
  dependency list rewritten to the workflow layout above.
- README surface: shortest reproduction path includes the canonical `make pipeline`.
- `references/figures.md`: "keep stage scripts as thin orchestration entry points" retargets to
  rules.
- `references/analysis.md`: near-untouched; its `config/analysis.yaml` reference already matches.

## Section 5 — Tests

- `tests/consistency_test.sh`: keep Makefile/README anchors; add anchors for `workflow/Snakefile`,
  `workflow/rules/`, and schema validation; rewrite configuration-precedence and stage-logging
  anchors to the new wording; add anchors for the enforced `--config` guard, the `ancient()`
  manifest edge, the `params:`-declaration rule, and the thin-rule contract. Suite green before
  commit.
- `tests/skill_pressure_scenarios.md`: add three scenarios — scientific logic in a `run:` block,
  using `--config` to "quickly test" a value, and reading `os.environ` inside the Snakefile.
- The focused test matrix in `references/configuration.md` gains entries that bootstrapped
  repositories must implement at runtime: the parse-time guard rejects `--config` and
  `--configfile` before computation; the manifest exists before any result job runs, including
  under parallel scheduling; and a changed result-affecting setting reruns the downstream rules
  that consume it. These are contracts for bootstrapped repositories, not executable tests in this
  skill repository.

## Out of scope

- No changes to the data contract (`references/data.md`), adapters, or installer machinery.
- No bulk migration guidance beyond updating the existing six-step migration section.
- Hydra was evaluated and rejected; it conflicts with the override, provenance, and path-ownership
  contracts.
