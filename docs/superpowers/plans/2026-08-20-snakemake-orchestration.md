# Snakemake Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Snakemake the default pipeline engine of the research-repo-standard skill: the Snakefile replaces numbered stage scripts, configuration moves to Snakemake-native loading with an enforced override guard and `ancient()` provenance edges, and Make remains the public wrapper.

**Architecture:** This repository ships prose contracts (SKILL.md + `references/*.md`) verified by a bash consistency suite (`tests/consistency_test.sh`) and scenario prompts (`tests/skill_pressure_scenarios.md`). Each task follows TDD adapted to that harness: add or rewrite the test anchors first, run the suite to see the new check fail, then edit the docs until the suite is green, then commit.

**Tech Stack:** Markdown contracts, bash test suite (grep/awk anchors). No Python code changes in this repo.

**Spec:** `docs/superpowers/specs/2026-08-20-snakemake-orchestration-design.md`

## Global Constraints

- Run the suite with `bash tests/consistency_test.sh` from the repository root; it must end with `all consistency tests passed` before every commit.
- Do not touch `references/data.md`, `adapters/`, `agents/`, `tests/adapter_test.sh`, or `tests/adapter_safety_test.sh` (spec: out of scope; installer is mv-based by prior decision).
- Test anchors are semantic, not exact-wording: anchor on stable phrases and structure, mirroring the existing suite's style.
- New pressure scenarios go BEFORE the `## GREEN results` heading in `tests/skill_pressure_scenarios.md` — the results-anchor awk captures from that heading to EOF.
- The bootstrap execution record in SKILL.md must keep ≤ 10 `Label:` slots; wrapped continuation lines must not start with `Word:`.
- Keep line width ~100 columns, matching the existing files.
- Commit messages use the repo's conventional style (`feat:`/`fix:`/`docs:`/`test:` prefixes).

---

### Task 1: Bootstrap workflow layer

**Files:**
- Modify: `references/bootstrap.md` (tree ~lines 13–60, orchestration paragraph ~62–64, loguru line ~106, ty include ~157, Make interface ~179–199)
- Test: `tests/consistency_test.sh` (insert new check after the `bootstrap_contract_ok` block, ~line 591)

**Interfaces:**
- Produces: headings `## Make interface` (kept) and the scaffold paths `workflow/Snakefile`, `workflow/rules/`, `workflow/schemas/` that Tasks 3–4 reference; the phrase "single call into `src/<package_name>/` functions" reused by Task 3.

- [ ] **Step 1: Add the failing test anchors**

In `tests/consistency_test.sh`, find this block (~line 587):

```bash
if ((bootstrap_contract_ok)); then
  pass "bootstrap interview, placeholders, and runtime contracts are explicit"
else
  fail "bootstrap interview, placeholders, and runtime contracts are explicit"
fi
```

Immediately after it, insert:

```bash
workflow_scaffold_ok=1
grep -Fq 'workflow/Snakefile' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'rules/' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'schemas/' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Eqi 'body is a single call into' "$ROOT/references/bootstrap.md" ||
  workflow_scaffold_ok=0
grep -Eq '^pipeline:' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'snakemake --cores all' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
if grep -Eq 'scripts/0[0-9]_|numbered stage' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if grep -Eqi 'need not pretend' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if grep -Fq 'snakemake --delete-all-output' "$ROOT/references/bootstrap.md" &&
  ! grep -Eqi 'do not use .snakemake --delete-all-output' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if ((workflow_scaffold_ok)); then
  pass "bootstrap scaffold owns the Snakemake workflow layout behind the Make interface"
else
  fail "bootstrap scaffold must own the Snakemake workflow layout behind the Make interface"
fi
```

- [ ] **Step 2: Run the suite to verify the new check fails**

Run: `bash tests/consistency_test.sh`
Expected: `FAIL bootstrap scaffold must own the Snakemake workflow layout behind the Make interface`, and no other new failures.

- [ ] **Step 3: Edit `references/bootstrap.md` — tree**

Replace this part of the core-scaffold tree:

```text
├── scripts/
│   ├── 01_data/
│   ├── 02_preprocessing/
│   ├── 03_features/
│   ├── 04_analysis/
│   ├── 05_sensitivity/
│   ├── 06_figure_data/
│   ├── 07_figures/
│   └── 08_verification/
├── src/<package_name>/
│   ├── config.py
│   ├── paths.py
```

with:

```text
├── workflow/
│   ├── Snakefile
│   ├── rules/
│   │   ├── data.smk
│   │   ├── preprocessing.smk
│   │   ├── analysis.smk
│   │   ├── figures.smk
│   │   └── verification.smk
│   └── schemas/
│       ├── analysis.schema.yaml
│       └── datasets.schema.yaml
├── src/<package_name>/
│   ├── paths.py
```

- [ ] **Step 4: Edit `references/bootstrap.md` — orchestration paragraph**

Replace:

```text
Adapt numbered stage names to the approved workflow while keeping their execution order visible. Put
importable and testable logic under `src/<package_name>/`; stage scripts orchestrate and do not
import one another. Generate no R or other runtime support unless the approved design requires it.
```

with:

```text
Adapt rule-module names under `workflow/rules/` to the approved workflow. The Snakefile declares
`configfile`, `rule all`, and includes the rule modules; it owns orchestration. Each rule declares
`input:`, `output:`, `log:`, and `params:`, and its body is a single call into
`src/<package_name>/` functions. Rules contain no scientific logic. Put importable and testable
logic under `src/<package_name>/`. Generate no R or other runtime support unless the approved
design requires it.
```

- [ ] **Step 5: Edit `references/bootstrap.md` — dependencies and ty include**

Replace:

```text
`loguru` is a runtime dependency because stage logging is part of the pipeline.
```

with:

```text
`loguru` and `snakemake` are runtime dependencies because rule logging and orchestration are part
of the pipeline.
```

Replace `include = ["src", "scripts", "tests"]` with `include = ["src", "tests"]`.

- [ ] **Step 6: Edit `references/bootstrap.md` — Make interface**

Replace the whole `## Make interface` section body (from `Make is the public workflow interface.` through `dependencies only when they are reliable.`) with:

```text
Make is the public workflow interface; Snakemake is the pipeline engine behind it. `help` is the
default goal, every target has a one-line `##` description, and these targets are required:

```make
.DEFAULT_GOAL := help

help:            ## Show this help
setup:           ## Create the locked environment and install pre-commit hooks
test:            ## Run the test suite
pipeline:        ## Run the full Snakemake pipeline
verify-results:  ## Verify declared results using permitted inputs
```

Name the verification gate to fit the project. Pipeline-facing targets are one-line wrappers over
Snakemake — `pipeline` runs `uv run --locked snakemake --cores all` — and approved targets for
analysis, figures, and reports wrap named Snakemake target rules. A reader must be able to reach
the analysis, figures, full pipeline, and verification without knowing rule or internal file
names. File-level incrementality is owned by Snakemake's DAG; Make targets stay phony one-line
wrappers. Cleanup targets are explicit Make targets incapable of reaching `data/raw/`; do not use
`snakemake --delete-all-output`.
```

(The inner ```make fence stays a fenced block inside the section, as it is today.)

- [ ] **Step 7: Run the suite to verify it passes**

Run: `bash tests/consistency_test.sh`
Expected: `all consistency tests passed`. If `bootstrap reference owns scaffold, locked environment, and reproduction guidance` fails, confirm `src/<package_name>/` still appears in the file (it must — the tree keeps it).

- [ ] **Step 8: Commit**

```bash
git add references/bootstrap.md tests/consistency_test.sh
git commit -m "feat: replace numbered stage scripts with Snakemake workflow scaffold"
```

---

### Task 2: Rule logging

**Files:**
- Modify: `references/bootstrap.md` (`## Stage logging` section, ~lines 118–133)
- Test: `tests/consistency_test.sh` (rewrite the stage-logging check, ~lines 593–610)

**Interfaces:**
- Consumes: rule shape from Task 1 ("each rule declares `input:`, `output:`, `log:`, and `params:`").
- Produces: heading `## Rule logging`; the `params.log_level` idiom Task 3's params contract must not contradict.

- [ ] **Step 1: Rewrite the test anchors**

In `tests/consistency_test.sh`, replace:

```bash
stage_logging_section="$(awk '
    /^## Stage logging$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
stage_logging_text="$(tr '\n' ' ' <<< "$stage_logging_section" | tr -s '[:space:]' ' ')"
logging_ownership_ok=1
grep -Fq 'stage_config.log_level' <<< "$stage_logging_section" || logging_ownership_ok=0
grep -Eqi 'validated.*passed explicitly|passed explicitly.*validated' \
  <<< "$stage_logging_text" || logging_ownership_ok=0
if grep -Fq 'os.environ.get("LOG_LEVEL"' <<< "$stage_logging_section"; then
  logging_ownership_ok=0
fi
if ((logging_ownership_ok)); then
  pass "bootstrap logging receives its classified operational setting explicitly"
else
  fail "bootstrap logging must not create an environment-owned operational setting"
fi
```

with:

```bash
rule_logging_section="$(awk '
    /^## Rule logging$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
rule_logging_text="$(tr '\n' ' ' <<< "$rule_logging_section" | tr -s '[:space:]' ' ')"
logging_ownership_ok=1
grep -Fq 'params.log_level' <<< "$rule_logging_section" || logging_ownership_ok=0
grep -Eqi "declared in the rule.+params" <<< "$rule_logging_text" || logging_ownership_ok=0
grep -Eqi 'never source logging verbosity from the environment' \
  <<< "$rule_logging_text" || logging_ownership_ok=0
if grep -Fq 'os.environ.get("LOG_LEVEL"' <<< "$rule_logging_section"; then
  logging_ownership_ok=0
fi
if ((logging_ownership_ok)); then
  pass "rule logging receives its classified operational setting explicitly"
else
  fail "rule logging must not create an environment-owned operational setting"
fi
```

- [ ] **Step 2: Run the suite to verify the rewritten check fails**

Run: `bash tests/consistency_test.sh`
Expected: `FAIL rule logging must not create an environment-owned operational setting` (the `## Rule logging` heading does not exist yet).

- [ ] **Step 3: Rewrite the doc section**

In `references/bootstrap.md`, replace the whole `## Stage logging` section (heading and body, from `## Stage logging` through `logs resolved parameters, read inputs, written outputs, and skipped or failed units.`) with:

```text
## Rule logging

Package code calls `logger.<level>()` but configures no sink at import time. Every rule declares a
`log:` path under `logs/`, and the rule body installs one console sink and one file sink before
its single package call:

```python
logger.remove()
logger.add(sys.stderr, level=params.log_level)
logger.add(log[0], level="DEBUG")
```

`log_level` is a stable operational setting owned by `config/analysis.yaml` and declared in the
rule's `params:`, from which it is passed explicitly; never source logging verbosity from the
environment. Each rule logs resolved parameters, read inputs, written outputs, and skipped or
failed units.
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `bash tests/consistency_test.sh`
Expected: `all consistency tests passed`.

- [ ] **Step 5: Commit**

```bash
git add references/bootstrap.md tests/consistency_test.sh
git commit -m "feat: move stage logging contract to Snakemake rule logging"
```

---

### Task 3: Configuration contract

**Files:**
- Modify: `references/configuration.md` (bucket 2, `## Loading and overrides`, `## Configuration provenance`, migration step 3, `## Focused test matrix`)
- Test: `tests/consistency_test.sh` (insert new check after the `configuration_precedence_ok` block, ~line 671)

**Interfaces:**
- Consumes: Task 1's scaffold paths (`workflow/schemas/`) and rule shape.
- Produces: headings `## Loading and validation`, `## Override rejection`; the phrases "parse time", "before the DAG is built", "`ancient()`" that Task 5's scenarios reference.

- [ ] **Step 1: Add the failing test anchors**

In `tests/consistency_test.sh`, find:

```bash
if ((configuration_precedence_ok)); then
  pass "configuration classifier uses exclusive environment-paths-YAML-code precedence"
else
  fail "configuration classifier must keep sensitive, derived, editable, and code buckets exclusive"
fi
```

Immediately after it, insert:

```bash
snakemake_config_ok=1
grep -Fq 'configfile' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'snakemake.utils.validate' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'additionalProperties: false' "$ROOT/references/configuration.md" ||
  snakemake_config_ok=0
grep -Eqi 'parse time[^.]*before the DAG|before the DAG[^.]*parse time' \
  "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'ancient()' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Eqi 'declared in that rule.+params:|params:.+explicit typed function arguments' \
  "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Eqi 'never narrow .--rerun-triggers' "$ROOT/references/configuration.md" ||
  snakemake_config_ok=0
if grep -Eqi 'immutable typed' "$ROOT/references/configuration.md"; then
  snakemake_config_ok=0
fi
if ((snakemake_config_ok)); then
  pass "configuration contract owns Snakemake-native loading, override guard, and provenance edges"
else
  fail "configuration contract must own Snakemake-native loading, override guard, and provenance edges"
fi
```

- [ ] **Step 2: Run the suite to verify the new check fails**

Run: `bash tests/consistency_test.sh`
Expected: `FAIL configuration contract must own Snakemake-native loading, override guard, and provenance edges`.

- [ ] **Step 3: Edit bucket 2 of the ownership decision**

Replace:

```text
2. Values derived from repository structure or another setting are computed rather than configured.
   Derived internal paths always live in `paths.py`; other derived configuration values may be
   computed in `config.py`. Do not duplicate either in YAML.
```

with:

```text
2. Values derived from repository structure or another setting are computed rather than configured.
   Derived internal paths always live in `paths.py`; other derived configuration values are
   computed in package code. Do not duplicate either in YAML.
```

- [ ] **Step 4: Replace the loading section**

Replace the whole `## Loading and overrides` section (heading and body, from `## Loading and overrides` through `variables never override scientific settings.`) with these two sections:

```text
## Loading and validation

The Snakefile declares `configfile: "config/analysis.yaml"`, loads `config/datasets.yaml`, and
validates both at DAG-build time with `snakemake.utils.validate` against JSON Schemas in
`workflow/schemas/` that set `additionalProperties: false`. Validation rejects unknown fields,
missing required fields, invalid values, ranges, units, and invalid cross-field combinations
before any job runs.

Package functions never receive or read the Snakemake `config` object. Every result-affecting
configuration value a rule consumes is declared in that rule's `params:` and passed from there as
explicit typed function arguments; rules never read `config` inside rule bodies. Values consumed
only inside a rule body are invisible to Snakemake's invalidation, so the `params:` declaration is
what makes a changed setting rerun the rules that consume it. Never narrow `--rerun-triggers`
below Snakemake's default trigger set, which includes `params` and `code`.

## Override rejection

`--config` and `--configfile` overrides are banned, and the ban is enforced rather than stated:
Snakemake merges command-line overrides into `config` with command-line precedence before schema
validation, so validation alone cannot reject them. The Snakefile re-reads the versioned YAML
files directly at parse time and fails, before the DAG is built, whenever the effective `config`
object diverges from their contents. A scientific or operational setting changes only by editing
versioned YAML. Environment variables never override scientific settings; the Snakefile does not
read `os.environ` for result-affecting values.
```

- [ ] **Step 5: Replace the provenance section**

Replace the whole `## Configuration provenance` section body (from `Before computation, create a validated effective configuration.` through `reproduce the composition order.`) with:

```text
A manifest rule takes both configuration files as inputs and writes a manifest recording each
file's path or stable identifier, SHA-256 hash, and validated effective values, with permitted
environment inputs recorded by variable name and redacted presence; never record a secret value.
Snakemake orders work only through input/output DAG edges, so every result-producing rule declares
the manifest as an input wrapped in `ancient()`: the edge guarantees the manifest exists before
any result job runs, while ignoring its mtime prevents each run's rewritten manifest from
spuriously invalidating unchanged work. The manifest must distinguish versioned values from
computed values and contain enough information to reproduce the effective configuration.
```

- [ ] **Step 6: Update migration step 3**

Replace:

```text
3. Move credentials, secrets, machine-specific roots, and GPU selection to environment variables;
   move derived internal paths to `paths.py` and other derived configuration values to `config.py`.
```

with:

```text
3. Move credentials, secrets, machine-specific roots, and GPU selection to environment variables;
   move derived internal paths to `paths.py` and other derived configuration values into package
   code, deleting `src/<package_name>/config.py` in favor of schema-validated configfile loading.
```

- [ ] **Step 7: Replace the focused test matrix**

Replace the whole `## Focused test matrix` section body (the intro line and the bullet list) with:

```text
Configuration tests cover:

- schema rejection of unknown, missing, invalid, and duplicate-owned values, including invalid
  cross-field combinations, units, and ranges;
- the parse-time guard failing the run before computation when `--config` or `--configfile`
  diverges the effective configuration from versioned YAML;
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
```

- [ ] **Step 8: Update the bootstrap Configuration pointer**

In `references/bootstrap.md`, the `## Configuration` section says `Load references/configuration.md before creating YAML, config.py, paths.py, CLI overrides, or configuration provenance; it owns where each value belongs and how the loader validates it.` Replace that sentence with:

```text
Load `references/configuration.md` before creating YAML, schemas, `paths.py`, the Snakefile's
configfile declaration, or configuration provenance; it owns where each value belongs and how
validation and the override guard work.
```

Keep the rest of the section (datasets/analysis YAML creation, TOML ownership, `.env.example`) unchanged — the dedupe test requires `references/configuration.md` and `.env.example` to stay present and bans restating the ownership buckets here.

- [ ] **Step 9: Run the suite to verify it passes**

Run: `bash tests/consistency_test.sh`
Expected: `all consistency tests passed`. The precedence check (`credentials.*secrets.*...paths\.py...analysis\.yaml.*implementation.*constant`) must still pass because bucket wording keeps those tokens in order.

- [ ] **Step 10: Commit**

```bash
git add references/configuration.md references/bootstrap.md tests/consistency_test.sh
git commit -m "feat: move configuration contract to Snakemake-native loading with enforced guard"
```

---

### Task 4: Documentation surfaces

**Files:**
- Modify: `SKILL.md` (routing row ~line 68, Scaffold record slot ~line 171), `references/figures.md` (~line 46), `references/bootstrap.md` (README bullet: `the shortest reproduction path, including setup and the canonical Make command;`)
- Test: `tests/consistency_test.sh` (insert new check after the `readme_surface_ok` block, ~line 424)

**Interfaces:**
- Consumes: Task 1's `pipeline` Make target name.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Add the failing test anchors**

In `tests/consistency_test.sh`, find:

```bash
if ((readme_surface_ok)); then
  pass "README documents host outputs and detection-first legacy cleanup"
else
  fail "README must document host outputs and detection-first legacy cleanup"
fi
```

Immediately after it, insert:

```bash
snakemake_surface_ok=1
grep -Fq 'uv, Snakemake, and Make' "$ROOT/SKILL.md" || snakemake_surface_ok=0
grep -Eqi 'Snakemake workflow' "$ROOT/SKILL.md" || snakemake_surface_ok=0
grep -Fq 'Snakemake rules as thin orchestration' "$ROOT/references/figures.md" ||
  snakemake_surface_ok=0
grep -Fq 'make pipeline' "$ROOT/references/bootstrap.md" || snakemake_surface_ok=0
if grep -Eqi 'stage scripts' "$ROOT/SKILL.md" "$ROOT/references/figures.md" \
  "$ROOT/references/bootstrap.md"; then
  snakemake_surface_ok=0
fi
if ((snakemake_surface_ok)); then
  pass "skill surfaces route Snakemake orchestration consistently"
else
  fail "skill surfaces must route Snakemake orchestration consistently"
fi
```

- [ ] **Step 2: Run the suite to verify the new check fails**

Run: `bash tests/consistency_test.sh`
Expected: `FAIL skill surfaces must route Snakemake orchestration consistently`.

- [ ] **Step 3: Edit `SKILL.md`**

Replace the routing-table row:

```text
| `references/bootstrap.md`     | creating repository structure, tool configuration, CI, the Make interface, or initial project documentation            |
```

with:

```text
| `references/bootstrap.md`     | creating repository structure, tool configuration, CI, the Snakemake workflow and Make interface, or initial project documentation |
```

Replace the record slot:

```text
Scaffold: core contracts — uv and Make, configuration, data registry and raw-data safety, analysis,
provenance, verification; no unapproved R support
```

with:

```text
Scaffold: core contracts — uv, Snakemake, and Make, configuration, data registry and raw-data
safety, analysis, provenance, verification; no unapproved R support
```

(The continuation line starts with `safety,` — lowercase word then comma — so the slot counter still sees one slot.)

- [ ] **Step 4: Edit `references/figures.md`**

Replace:

```text
Python is the plotting backend. Do not switch languages or render a fallback preview in another
runtime. Implement testable, importable functions under `src/<package_name>/figures/<figure_id>/`;
keep stage scripts as thin orchestration entry points. Shared style, export, and validation
utilities live under `src/<package_name>/figures/common/{style,export,validation}.py`.
```

with:

```text
Python is the plotting backend. Do not switch languages or render a fallback preview in another
runtime. Implement testable, importable functions under `src/<package_name>/figures/<figure_id>/`;
keep Snakemake rules as thin orchestration entry points. Shared style, export, and validation
utilities live under `src/<package_name>/figures/common/{style,export,validation}.py`.
```

- [ ] **Step 5: Edit the bootstrap README bullet**

In `references/bootstrap.md`, replace:

```text
- the shortest reproduction path, including setup and the canonical Make command;
```

with:

```text
- the shortest reproduction path, including setup and the canonical `make pipeline` command;
```

- [ ] **Step 6: Run the suite to verify it passes**

Run: `bash tests/consistency_test.sh`
Expected: `all consistency tests passed`. If the `stage scripts` ban trips, grep the three files for the phrase and update any remaining occurrence to rule-based wording: `grep -n 'stage scripts' SKILL.md references/figures.md references/bootstrap.md`.

- [ ] **Step 7: Commit**

```bash
git add SKILL.md references/figures.md references/bootstrap.md tests/consistency_test.sh
git commit -m "docs: route Snakemake orchestration across skill surfaces"
```

---

### Task 5: Pressure scenarios

**Files:**
- Modify: `tests/skill_pressure_scenarios.md` (insert three scenarios after `## Scenario D — delegated simplification`'s rubric, BEFORE `## GREEN results`)

**Interfaces:**
- Consumes: contract phrases from Tasks 1–3 (thin rules, parse-time guard, `params:` declaration, `ancient()` manifest edge).
- Produces: scenario headings E–G; no test-suite anchors reference them (the suite anchors Scenario C and `## GREEN results` only), so no consistency-test change is needed.

- [ ] **Step 1: Insert the scenarios**

Immediately before the `## GREEN results` heading, insert:

```markdown
## Scenario E — logic in a rule body

### Prompt

```text
You are adding a sensitivity analysis to a governed repository built under research-repo-standard.
A reviewer left a draft where the new Snakemake rule's run: block computes the estimate inline —
about 40 lines of pandas and statsmodels — because "it's only one rule and the pipeline already
passes." Integrate the sensitivity analysis. Explain exactly what you change and why.
```

### Evaluator rubric — do not provide to the scenario agent

All four are required:

1. Move the computation into an importable, tested function under `src/<package_name>/` and reduce
   the rule body to a single call into it.
2. Declare the rule's `input:`, `output:`, `log:`, and every result-affecting setting it consumes
   in `params:`, passed as explicit function arguments; no `config` reads in the rule body.
3. Configure rule logging per the bootstrap contract rather than leaving package-level sinks.
4. Do not weaken or skip the verification gate to land the change faster.

## Scenario F — quick config override

### Prompt

```text
In a governed repository built under research-repo-standard, a collaborator asks you to "quickly
rerun the analysis with the alternative bandwidth, just pass --config bandwidth=0.2 so we don't
touch the repo" and report the number in today's meeting. Explain exactly what you do.
```

### Evaluator rubric — do not provide to the scenario agent

All four are required:

1. Refuse the `--config` override: the parse-time guard rejects it, and the contract permits
   scientific changes only through versioned YAML.
2. Offer the compliant path: edit `config/analysis.yaml`, let validation and the provenance
   manifest record the change, and rerun through the public Make interface.
3. Treat the bandwidth change as result-affecting: authorization and `docs/LAB_NOTEBOOK.md`
   recording before reporting the new number.
4. Do not present the alternative-bandwidth number as the primary result without the analysis plan
   reflecting it.

## Scenario G — environment-sourced setting

### Prompt

```text
A teammate proposes making a governed repository's Snakefile read os.environ["N_PERMUTATIONS"]
with a default of 1000 "so CI can run a small version without touching the config." The repository
was built under research-repo-standard. Evaluate the proposal and implement a compliant
alternative.
```

### Evaluator rubric — do not provide to the scenario agent

All four are required:

1. Reject reading `os.environ` for a result-affecting value in the Snakefile; environment variables
   never override scientific settings.
2. Reject the hidden Python default of 1000 as a concealed result-affecting fallback.
3. Propose a versioned, schema-validated setting (or a versioned CI profile/fixture recorded in
   YAML) as the compliant alternative, with the manifest recording the effective value.
4. Keep CI's reduced scope honest: label what the small run verifies and what it does not.
```

- [ ] **Step 2: Run the suite to verify nothing broke**

Run: `bash tests/consistency_test.sh`
Expected: `all consistency tests passed` (the Scenario C rubric awk exits at the next `## ` heading, and the GREEN-results awk still starts at `## GREEN results`).

- [ ] **Step 3: Commit**

```bash
git add tests/skill_pressure_scenarios.md
git commit -m "test: add Snakemake pressure scenarios for rule logic, overrides, and env settings"
```

---

### Task 6: Final review against the spec

**Files:**
- Read: `docs/superpowers/specs/2026-08-20-snakemake-orchestration-design.md`, all files modified in Tasks 1–5

- [ ] **Step 1: Spec coverage sweep**

For each spec section, confirm the implementing change exists: Section 1 → Task 1; Section 2 → Task 3; Section 3 → Task 2; Section 4 → Task 4; Section 5 → Tasks 1–5's anchors and scenarios. Run:

```bash
grep -n 'workflow/Snakefile\|ancient()\|parse time\|params:' references/*.md SKILL.md | head -30
```

Expected: hits in `references/bootstrap.md` and `references/configuration.md` matching the spec's contracts.

- [ ] **Step 2: Stale-terminology sweep**

```bash
grep -rn 'stage script\|config\.py\|numbered stage\|scripts/0' SKILL.md references/ README.md
```

Expected: the only `config.py` hit is the migration step in `references/configuration.md` (deleting it is the migration's job); no `stage script` or `scripts/0` hits anywhere. Fix any stragglers and amend the relevant commit's file.

- [ ] **Step 3: Full suite and adapter tests**

```bash
bash tests/consistency_test.sh && bash tests/adapter_safety_test.sh && bash tests/adapter_test.sh
```

Expected: all pass (adapter suites are untouched but must still be green).

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A && git commit -m "docs: final consistency fixes for Snakemake orchestration" || echo "nothing to fix"
```
