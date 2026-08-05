# Configuration Source-of-Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make versioned YAML the explicit source of truth for stable scientific and operational settings while retaining Python for strict loading and derived repository paths.

**Architecture:** Add one detailed configuration reference, route the skill to it, and vendor a concise mandatory ownership contract through `AGENTS.md`. Align bootstrap, analysis, provenance, and testing guidance, then validate the instruction bundle through metadata checks, vendoring, and isolated classification and implementation scenarios.

**Tech Stack:** Markdown Agent Skills, YAML configuration contracts, Bash contract checks, Git, uv, skill-creator validation, isolated agent forward testing

## Global Constraints

- Changed normative files use `standard_version: 2026.08.05`.
- `config/analysis.yaml` owns scientific and result-affecting settings.
- Optional `config/runtime.yaml` owns only stable operational settings demonstrated to be result-equivalent.
- A runtime classification requires a durable rationale in `docs/DECISIONS.md`; otherwise the setting remains scientific.
- `config.py` validates and returns immutable typed configuration without owning project-specific values.
- `paths.py` remains the owner of repository-root discovery, derived internal paths, containment, and environment-provided external roots.
- Secrets, credentials, machine-specific absolute roots, and GPU selection do not live in versioned YAML.
- Do not add a generic `project.yaml` or `settings.yaml`.
- Do not prescribe a schema library or trigger automatic bulk migration of established repositories.
- The approved modification gate already covers this plan; direct and delegated implementation tasks do not restart brainstorming unless scope expands.
- Before every task commit, ask Claude to review that task's diff, assess each suggestion
  against the approved specification, implement only suggestions that improve correctness
  or clarity without expanding scope, and rerun the task checks.

---

## File map

- Create `references/configuration.md`: canonical ownership, loading, path, override, provenance, migration, and testing contract.
- Modify `README.md`: advertise the configuration reference and concise ownership model.
- Modify `SKILL.md`: trigger and route configuration work to the new reference.
- Modify `AGENTS.md`: vendor the self-contained mandatory configuration contract into governed repositories.
- Modify `references/bootstrap.md`: define new-repository YAML scaffolding and loader behavior.
- Modify `references/analysis.md`: bind result-affecting parameters and seed to `config/analysis.yaml`.
- Verify `vendor.sh`: ensure vendored repositories receive the updated contract without losing project identity.

### Task 1: Add the canonical configuration reference

**Files:**
- Create: `references/configuration.md`
- Modify: `README.md:1-79`

**Interfaces:**
- Consumes: approved design at `docs/superpowers/specs/2026-08-05-configuration-source-of-truth-design.md`
- Produces: one canonical detailed reference at `references/configuration.md` for Tasks 2–4

- [ ] **Step 1: Demonstrate the missing reference**

Run:

```bash
test -f references/configuration.md \
  && rg -q 'config/analysis.yaml' references/configuration.md \
  && rg -q 'config/runtime.yaml' references/configuration.md \
  && rg -q 'paths.py' references/configuration.md
```

Expected: exit status `1` because `references/configuration.md` does not exist.

- [ ] **Step 2: Create the canonical reference**

Create `references/configuration.md` with version marker
`<!-- standard_version: 2026.08.05 -->` and these sections in this order:

1. `# Reference: configuration ownership contract`
2. `## Ownership decision`
3. `## Configuration files`
4. `## Loading and overrides`
5. `## Paths and environment`
6. `## Provenance`
7. `## Established repositories`
8. `## Tests`

The ownership section must state this exact decision order:

```markdown
1. If changing a value can alter the dataset, estimate, model, figure, or scientific
   claim, put it in `config/analysis.yaml`.
2. If it is demonstrated to preserve intended results while changing only performance
   or resilience, put it in optional `config/runtime.yaml` and record the equivalence
   rationale in `docs/DECISIONS.md`.
3. If it is secret or machine-specific, supply it through an environment variable.
4. If it is derived from repository structure or another setting, compute it in
   `paths.py` or `config.py`; do not duplicate it in YAML.
5. If changing it inherently changes the implementation, keep it as a named Python
   constant.

When classification is uncertain, treat the value as scientific. Without a durable
equivalence rationale, it does not belong in `runtime.yaml`.
```

The configuration-files section must declare:

```text
config/
├── datasets.yaml              # mandatory provenance and legal-use registry
├── analysis.yaml              # mandatory scientific and result-affecting settings
└── runtime.yaml               # optional proven result-equivalent operational settings
```

It must require `random_seed: 42` in `analysis.yaml` when randomness is used, prohibit
empty `runtime.yaml` scaffolds, and explain that a training batch size remains in
`analysis.yaml` whenever it may affect optimization.

The loading section must require a single load through `config.py`, strict rejection
of unknown and missing fields, immutable typed objects passed into package functions,
and no independent YAML reads or mutable module-level settings. Scientific values
must have no silent Python defaults. Permitted CLI overrides use the same validation
and result-affecting overrides must be recorded.

The paths section must retain `paths.py` for repository-root discovery, canonical
internal paths, containment, and raw-data safety. It must prohibit versioned secrets,
machine-specific absolute roots, and YAML redirection of internal paths. Environment
variables may not override scientific settings.

It must also keep `.python-version`, `pyproject.toml`, and `uv.lock` as the existing
sources of truth for Python, packaging, tools, and locked dependencies rather than
moving those values into analysis or runtime YAML.

The provenance and tests sections must include configuration hashes, validated
effective values, override sources, redacted secret presence, seed and parallelism
boundaries, rejection of hidden result-affecting fallbacks, and failure on unrecorded
result-affecting overrides.

The migration section must trigger when the function or entry point reading a
module-level project setting is edited, require authorization for scientific changes,
preserve behavior with focused tests, and record the migration in
`docs/DECISIONS.md`.

- [ ] **Step 3: Update README navigation and summary**

Change the README version marker to `2026.08.05`. Add this entry after
`prerequisites.md` in the layout block:

```text
  configuration.md     YAML ownership, loading, paths, overrides, provenance
```

Insert this section after `## Hard prerequisites` and before installation guidance:

```markdown
## Configuration source of truth

Stable scientific and result-affecting settings live in `config/analysis.yaml`.
Optional `config/runtime.yaml` contains only operational settings demonstrated to be
result-equivalent. Python validates and consumes configuration; `paths.py` derives
repository paths. See
[`references/configuration.md`](references/configuration.md) for ownership, override,
provenance, and migration rules.
```

- [ ] **Step 4: Verify the canonical contract**

Run:

```bash
git diff --check
rg -n 'analysis.yaml|runtime.yaml|config.py|paths.py|DECISIONS.md' references/configuration.md
rg -n 'Configuration source of truth|references/configuration.md' README.md
rg -n 'standard_version: 2026.08.05' README.md references/configuration.md
```

Expected: all commands exit `0`; ownership, evidence, routing, and version markers are
present.

- [ ] **Step 5: Ask Claude to review the task diff**

Run:

```bash
git add README.md references/configuration.md
git diff --cached -- README.md references/configuration.md | \
  claude -p --model sonnet --effort low \
  --tools "" --disable-slash-commands --no-session-persistence \
  "Review this task diff against the approved configuration source-of-truth design. Identify only concrete correctness, consistency, or documentation defects. Do not propose scope expansion."
```

Assess every suggestion. Apply only useful in-scope changes, document rejected
suggestions in the task notes, rerun Step 4, and stage the final files again.

- [ ] **Step 6: Commit the canonical reference**

```bash
git add README.md references/configuration.md
git commit -m "docs: define configuration ownership contract"
```

### Task 2: Route configuration work through the skill

**Files:**
- Modify: `SKILL.md:1-121`

**Interfaces:**
- Consumes: `references/configuration.md` from Task 1
- Produces: configuration triggers and routing used whenever the skill governs settings, loaders, paths, overrides, or provenance

- [ ] **Step 1: Demonstrate missing skill routing**

Run:

```bash
rg -q 'references/configuration.md' SKILL.md
```

Expected: exit status `1` before the new route is added.

- [ ] **Step 2: Update metadata and version**

Replace the frontmatter description with this single line and change the HTML version
marker to `2026.08.05`:

```yaml
description: The operating standard for reproducible research repositories supporting a scientific analysis, study, or paper. Use whenever setting up such a repository and before any user-requested modification in a governed repository that creates, edits, moves, or deletes files; enforce the required brainstorming, scientific critique, figure, and configuration workflows, and consult the bootstrap, prerequisite, configuration, data, analysis, and figure contracts. Use even when the user does not name the standard, especially for vendoring or re-vendoring it, classifying or moving project settings, editing config/analysis.yaml or config/runtime.yaml, changing config.py or paths.py, registering datasets, writing validation, planning or reporting analyses, checking reproducibility, or producing publication figures and tables.
```

- [ ] **Step 3: Add reference routing and governed-work instruction**

Add this reference-table row after `references/prerequisites.md`:

```markdown
| `references/configuration.md` | classifying settings; changing YAML, loaders, paths, overrides, or configuration provenance |
```

Insert this paragraph after the existing governed scientific/figure routing paragraph:

```markdown
For configuration work, read `references/configuration.md`. Stable scientific and
result-affecting settings belong in `config/analysis.yaml`; only documented
result-equivalent operations belong in optional `config/runtime.yaml`. `config.py`
validates and passes typed values, while `paths.py` derives repository paths.
```

In bootstrap step 7, require both `references/bootstrap.md` and
`references/configuration.md` when creating configuration files and loaders.

- [ ] **Step 4: Validate the updated skill**

Run:

```bash
UV_CACHE_DIR=/private/tmp/research-skill-validator-cache \
  uv run --no-project --with pyyaml python \
  /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
rg -n 'references/configuration.md|config/analysis.yaml|config/runtime.yaml|config.py|paths.py' SKILL.md
git diff --check
```

Expected: validator prints `Skill is valid!`; every route and responsibility appears;
the diff check is silent.

- [ ] **Step 5: Ask Claude to review the task diff**

Run:

```bash
git add SKILL.md
git diff --cached -- SKILL.md | claude -p --model sonnet --effort low \
  --tools "" --disable-slash-commands --no-session-persistence \
  "Review this task diff against the approved configuration source-of-truth design. Identify only concrete correctness, consistency, or skill-routing defects. Do not propose scope expansion."
```

Assess every suggestion. Apply only useful in-scope changes, document rejected
suggestions in the task notes, rerun Step 4, and stage the final file again.

- [ ] **Step 6: Commit the skill routing**

```bash
git add SKILL.md
git commit -m "feat: route research configuration work"
```

### Task 3: Vendor the configuration contract into governed repositories

**Files:**
- Modify: `AGENTS.md:1-395`

**Interfaces:**
- Consumes: canonical detail from `references/configuration.md`
- Produces: self-contained rules that remain active when the skill reference is unavailable

- [ ] **Step 1: Demonstrate missing vendored assertions**

Run:

```bash
rg -q 'Configuration has one owner' AGENTS.md
rg -q 'runtime.yaml.*optional' AGENTS.md
rg -q 'result-affecting override.*provenance' AGENTS.md
rg -q 'Centralize paths in `paths.py`' AGENTS.md
```

Expected: the first three commands exit `1` before implementation; the final command
exits `0` and confirms the unique replacement target exists.

- [ ] **Step 2: Bump version and add reference routing**

Change the first-line marker to `2026.08.05`. Add this row to the `Using this
standard` table after the data-contract row:

```markdown
| the configuration contract | classifying settings; changing YAML, loaders, paths, overrides, or provenance |
```

In the established-repository source-of-truth paragraph, retain
`config/datasets.yaml` for provenance and add existing `config/analysis.yaml` plus
optional `config/runtime.yaml` as the source of truth for project settings.

- [ ] **Step 3: Add a non-negotiable ownership gate**

Append floor item 11:

```markdown
11. **Configuration has one owner.** Stable scientific and operational settings live
    in versioned YAML, never as hidden Python globals or defaults. Derived internal
    paths stay in `paths.py`; secrets and machine-specific roots stay in environment
    variables. Unknown, missing, duplicate, or unrecorded result-affecting values fail
    before computation.
```

- [ ] **Step 4: Update the repository layout**

Add this entry after `config/analysis.yaml`:

```text
│   └── runtime.yaml                  # optional, proven result-equivalent operations
```

Change the preceding connector for `analysis.yaml` from `└──` to `├──`.

- [ ] **Step 5: Replace the concise Code configuration paragraph**

Replace the paragraph beginning `Centralize paths in paths.py` with:

```markdown
Stable researcher-editable values have one versioned YAML owner. Scientific and
result-affecting settings — seed, thresholds, inclusion rules, transformations, model
parameters, and any batch size that may affect optimization — live in
`config/analysis.yaml`. Optional `config/runtime.yaml` contains only stable operational
settings demonstrated to preserve results; record the equivalence rationale in
`docs/DECISIONS.md`. When uncertain, classify the value as scientific.

`config.py` strictly validates YAML, rejects unknown and missing fields, composes only
permitted overrides, and returns immutable typed objects passed explicitly into
package functions. It contains no project-specific scientific or operational values,
and optional schema fields never conceal result-affecting Python defaults. Load once
per stage; package functions do not reread YAML or import mutable settings globals.

`paths.py` discovers the repository root and derives canonical internal paths,
containment, and raw-data protections. Internal layout paths never live in YAML.
Credentials, secrets, machine-specific absolute roots, and GPU selection use
environment variables; environment variables never override scientific settings.
Command-line arguments are only for genuine invocation-time variation and use the
same validation as YAML.

For established repositories, apply this migration when editing the function or entry
point that reads a module-level project setting. Preserve behavior with tests, obtain
authorization before changing scientific meaning, and record the migration in
`docs/DECISIONS.md`.
```

- [ ] **Step 6: Strengthen provenance and testing**

Replace the major-build provenance paragraph with:

```markdown
Each major build writes a deterministic provenance manifest recording: commit
identifier; hashes and validated effective values for every loaded YAML file; every
CLI override and its source; input identifiers and checksums; environment and
container identity without secret values; secret inputs only by variable name and
redacted presence; seed, worker, parallelism, and accelerator boundaries when
relevant; output inventory and checksums; and declared nondeterministic or manual
boundaries. An unrecorded result-affecting override is a provenance failure.
```

Append this paragraph to Testing:

```markdown
Configuration tests reject unknown and missing fields, hidden result-affecting Python
fallbacks, duplicate ownership, invalid cross-field combinations, and unrecorded
result-affecting overrides. Test that stage entry points load once and pass immutable
typed configuration explicitly, and that `paths.py` cannot redirect canonical raw-data
locations outside their contract.
```

- [ ] **Step 7: Verify vendored governance**

Run:

```bash
rg -n 'Configuration has one owner|analysis.yaml|runtime.yaml|immutable typed|Internal layout paths never live in YAML|unrecorded result-affecting override' AGENTS.md
rg -n 'standard_version: 2026.08.05' AGENTS.md
git diff --check
```

Expected: each mandatory layer is found and the diff check is silent.

- [ ] **Step 8: Ask Claude to review the task diff**

Run:

```bash
git add AGENTS.md
git diff --cached -- AGENTS.md | claude -p --model sonnet --effort low \
  --tools "" --disable-slash-commands --no-session-persistence \
  "Review this task diff against the approved configuration source-of-truth design. Identify only concrete correctness, consistency, or vendored-governance defects. Do not propose scope expansion."
```

Assess every suggestion. Apply only useful in-scope changes, document rejected
suggestions in the task notes, rerun Step 7, and stage the final file again.

- [ ] **Step 9: Commit vendored governance**

```bash
git add AGENTS.md
git commit -m "feat: vendor configuration ownership rules"
```

### Task 4: Align bootstrap and analysis references

**Files:**
- Modify: `references/bootstrap.md:1-189`
- Modify: `references/analysis.md:1-103`

**Interfaces:**
- Consumes: `references/configuration.md` ownership and loading rules
- Produces: concrete new-repository scaffolding and analysis-time seed/parameter guidance

- [ ] **Step 1: Demonstrate missing supporting guidance**

Run:

```bash
rg -q 'config/runtime.yaml' references/bootstrap.md
rg -q 'config/analysis.yaml' references/analysis.md
```

Expected: both commands exit `1` before the references are aligned.

- [ ] **Step 2: Add bootstrap configuration guidance**

Change the bootstrap frontmatter version to `2026.08.05`. Replace the two opening
sentences under `## Configuration and secrets` with:

```markdown
Read `references/configuration.md` before creating YAML, `config.py`, `paths.py`, CLI
overrides, or configuration provenance. TOML remains the source of truth for packaging
and tool configuration. Create mandatory `config/datasets.yaml` and
`config/analysis.yaml`; create `config/runtime.yaml` only when stable operational
settings exist and their result-equivalence rationale is recorded.

Put every stable scientific or result-affecting value explicitly in
`config/analysis.yaml`. Put only proven result-equivalent performance and resilience
settings in optional `config/runtime.yaml`. Do not create an empty runtime file.
`config.py` validates strict typed schemas and contains no project values or hidden
result-affecting defaults. `paths.py` derives internal paths and reads permitted
machine-specific roots from environment variables.
```

Keep the existing `.env.example` and container guidance after these paragraphs.

- [ ] **Step 3: Bind analysis settings and seed to YAML**

Change the analysis reference version to `2026.08.05`. After the analysis-plan text
template, add:

```markdown
Every stable value that operationalizes this plan has an explicit field in
`config/analysis.yaml`; prose does not substitute for executable configuration. The
loader rejects missing or unknown scientific fields, and confirmatory runs do not
silently replace them through environment variables or Python defaults.
```

Replace the first Determinism paragraph with:

```markdown
Prefer deterministic algorithms when scientifically equivalent. When randomness is
necessary, declare `random_seed: 42` explicitly in `config/analysis.yaml`, pass it
through the validated typed configuration, and propagate it to every stochastic
component. Do not repeat `42` as a module-level Python setting.
```

- [ ] **Step 4: Verify supporting references**

Run:

```bash
rg -n 'references/configuration.md|config/analysis.yaml|config/runtime.yaml|hidden result-affecting defaults' references/bootstrap.md
rg -n 'config/analysis.yaml|random_seed: 42|module-level Python' references/analysis.md
rg -n 'standard_version: 2026.08.05' references/bootstrap.md references/analysis.md
git diff --check
```

Expected: all ownership and seed rules are present; version markers match; the diff
check is silent.

- [ ] **Step 5: Ask Claude to review the task diff**

Run:

```bash
git add references/bootstrap.md references/analysis.md
git diff --cached -- references/bootstrap.md references/analysis.md | \
  claude -p --model sonnet --effort low \
  --tools "" --disable-slash-commands --no-session-persistence \
  "Review this task diff against the approved configuration source-of-truth design. Identify only concrete correctness, consistency, bootstrap, or analysis-guidance defects. Do not propose scope expansion."
```

Assess every suggestion. Apply only useful in-scope changes, document rejected
suggestions in the task notes, rerun Step 4, and stage the final files again.

- [ ] **Step 6: Commit aligned references**

```bash
git add references/bootstrap.md references/analysis.md
git commit -m "docs: align configuration bootstrap and analysis"
```

### Task 5: Validate vendoring and forward behavior

**Files:**
- Verify: `SKILL.md`
- Verify: `AGENTS.md`
- Verify: `README.md`
- Verify: `references/configuration.md`
- Verify: `references/bootstrap.md`
- Verify: `references/analysis.md`
- Verify: `vendor.sh`

**Interfaces:**
- Consumes: all Task 1–4 contract changes
- Produces: validation evidence and review fixes only; no new contract surface

- [ ] **Step 1: Run metadata and static contract checks**

Run:

```bash
UV_CACHE_DIR=/private/tmp/research-skill-validator-cache \
  uv run --no-project --with pyyaml python \
  /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
bash -n vendor.sh
git diff --check main..HEAD
rg -n 'standard_version: 2026.08.05' SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md references/analysis.md
rg -l 'config/analysis.yaml' SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md references/analysis.md
rg -l 'config/runtime.yaml' SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md
rg -l 'paths.py' SKILL.md AGENTS.md references/configuration.md references/bootstrap.md
```

Expected: the skill validator passes, Bash and diff checks are silent, and every
listed file is returned by its contract search.

- [ ] **Step 2: Run negative contradiction checks**

Run:

```bash
if rg -n 'replace paths.py|internal paths.*runtime.yaml|internal paths.*analysis.yaml' AGENTS.md SKILL.md references; then exit 1; fi
if rg -n 'where permitted:' AGENTS.md references/configuration.md; then exit 1; fi
rg -n 'hidden result-affecting|unrecorded result-affecting' AGENTS.md references/configuration.md references/bootstrap.md
```

Expected: both negated searches produce no output; the required failure rules are
found.

- [ ] **Step 3: Verify vendoring and project identity preservation**

Run:

```bash
validation_repo="$(mktemp -d /private/tmp/research-config-validation.XXXXXX)"
cp AGENTS.md "$validation_repo/AGENTS.md"
perl -0pi -e 's/\*Per-repository section — the only part expected to differ from the source\. Replace it\.\*/Question: Does configuration remain inspectable without reading Python?/' "$validation_repo/AGENTS.md"
./vendor.sh "$validation_repo"
rg -n 'Question: Does configuration remain inspectable without reading Python\?' "$validation_repo/AGENTS.md"
rg -n 'Configuration has one owner|config/analysis.yaml|config/runtime.yaml|paths.py' "$validation_repo/AGENTS.md"
test -L "$validation_repo/CLAUDE.md"
```

Expected: vendoring reports `2026.08.05`; project identity survives; the complete
concise configuration contract is present; `CLAUDE.md` is a symlink. Leave the narrow
temporary fixture for operating-system cleanup.

- [ ] **Step 4: Forward-test classification without leaking the answer**

Dispatch a fresh isolated agent with the completed skill and this read-only user
request:

```text
A governed research repository defines TRAINING_BATCH_SIZE = 64 in a Python module.
The value may affect model optimization, and a teammate wants to make it configurable.
Explain where the value should live, what evidence would permit another location, and
what must be recorded. Do not edit files.
```

Pass only if the response explicitly selects `config/analysis.yaml`, explains that
this fixture is scientific because the prompt says the value may affect optimization,
permits `config/runtime.yaml` only after demonstrated result equivalence recorded in
`docs/DECISIONS.md`, keeps loading in `config.py`, and does not put the value or
repository paths in `paths.py`. Record the response and a pass/fail verdict in the
task notes. This fixture does not imply that every value named “batch size” is
scientific; a demonstrated result-equivalent I/O batch may be runtime configuration.

- [ ] **Step 5: Create the delegated implementation fixture**

Run `mktemp -d /private/tmp/research-config-forward.XXXXXX` and record its returned
absolute path as `config_fixture`. Copy the updated `AGENTS.md` into that directory.
Use `apply_patch` with the resolved absolute path to create these exact files.
The later snippets use the inert token `CONFIG_FIXTURE_ABSOLUTE_PATH`. Before running
each command, replace every occurrence with the literal path returned by `mktemp`;
never run the token literally and do not assume a shell variable survives across
tool calls.

`config/analysis.yaml`:

```yaml
schema_version: 1
model:
  learning_rate: 0.001
```

`config/runtime.yaml`:

```yaml
schema_version: 1
api:
  retry_limit: 3
```

`docs/DECISIONS.md`:

```markdown
# Decisions

## D001: API retry policy is operational

The retry limit changes only repeated delivery attempts for an identical request. A
failed request remains a failed stage and cannot change the accepted payload, so this
setting is result-equivalent runtime configuration.
```

`src/study/__init__.py`: an empty file.

`src/study/config.py`:

```python
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class AnalysisConfig:
    """Validated scientific configuration for the fixture."""

    learning_rate: float


def _read_mapping(path: Path) -> dict[str, Any]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("configuration root must be a mapping")
    return raw


def load_analysis_config(path: Path) -> AnalysisConfig:
    """Load the fixture's strict analysis configuration."""
    raw = _read_mapping(path)
    if set(raw) != {"schema_version", "model"} or raw["schema_version"] != 1:
        raise ValueError("unknown or missing analysis configuration fields")
    model = raw["model"]
    if not isinstance(model, dict) or set(model) != {"learning_rate"}:
        raise ValueError("unknown or missing model fields")
    return AnalysisConfig(learning_rate=float(model["learning_rate"]))
```

`src/study/train.py`:

```python
TRAINING_BATCH_SIZE = 64


def training_batch_size() -> int:
    """Return the batch size used by model optimization."""
    return TRAINING_BATCH_SIZE
```

`tests/test_training_configuration.py`:

```python
from study.train import training_batch_size


def test_training_batch_size_is_64() -> None:
    assert training_batch_size() == 64
```

Initialize the fixture as a Git repository and commit these baseline files so the
forward-test diff is inspectable:

```bash
git -C "CONFIG_FIXTURE_ABSOLUTE_PATH" init -b main
git -C "CONFIG_FIXTURE_ABSOLUTE_PATH" add AGENTS.md config docs src tests
git -C "CONFIG_FIXTURE_ABSOLUTE_PATH" commit -m "test: add configuration forward fixture"
```

- [ ] **Step 6: Run the fixture baseline**

Run:

```bash
UV_CACHE_DIR=/private/tmp/research-config-forward-cache \
  PYTHONPATH="CONFIG_FIXTURE_ABSOLUTE_PATH/src" \
  uv run --no-project --with pyyaml --with pytest \
  pytest "CONFIG_FIXTURE_ABSOLUTE_PATH/tests" -q
```

Expected: one test passes with the original hard-coded value `64`.

- [ ] **Step 7: Dispatch the delegated implementation agent**

Dispatch a second fresh agent with the fixture path, the completed skill path, and
this prompt:

```text
Use the research-repo-standard skill to execute delegated Task 5 of the already
approved configuration-source-of-truth implementation plan in this fixture: make the
training batch size configurable without changing its value. The parent task's
brainstorming, specification, user-review, and planning gates are complete, and this
delegated implementation inherits them. Inspect the fixture and follow its governing
instructions. Report the files changed and the checks run.
```

Do not tell the agent which file should own the value.

- [ ] **Step 8: Inspect the delegated artifacts**

Run:

```bash
git -C "CONFIG_FIXTURE_ABSOLUTE_PATH" diff --check
git -C "CONFIG_FIXTURE_ABSOLUTE_PATH" diff -- config/analysis.yaml config/runtime.yaml src/study/config.py src/study/train.py tests/test_training_configuration.py docs/DECISIONS.md
rg -n 'training_batch_size.*64|training_batch_size: 64' "CONFIG_FIXTURE_ABSOLUTE_PATH/config/analysis.yaml" "CONFIG_FIXTURE_ABSOLUTE_PATH/src/study/config.py"
if rg -n 'TRAINING_BATCH_SIZE|data/raw|results/figures' "CONFIG_FIXTURE_ABSOLUTE_PATH/src/study/train.py" "CONFIG_FIXTURE_ABSOLUTE_PATH/config"; then exit 1; fi
UV_CACHE_DIR=/private/tmp/research-config-forward-cache \
  PYTHONPATH="CONFIG_FIXTURE_ABSOLUTE_PATH/src" \
  uv run --no-project --with pyyaml --with pytest \
  pytest "CONFIG_FIXTURE_ABSOLUTE_PATH/tests" -q
```

Expected: the value moves to `config/analysis.yaml`; `config.py` validates and exposes
it; package logic receives it explicitly; `runtime.yaml` and its rationale remain
unchanged; no module-level batch setting or internal YAML path appears; the focused
tests pass.

- [ ] **Step 9: Inspect final state and commit review fixes if needed**

Run:

```bash
git diff --check main..HEAD
git status --short --branch
git log --oneline main..HEAD
```

If validation or forward testing reveals a contract defect, change only the relevant
contract files and rerun Steps 1–5. Before committing, run:

```bash
git add SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md references/analysis.md
git diff --cached -- SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md references/analysis.md | \
  claude -p --model sonnet --effort low \
  --tools "" --disable-slash-commands --no-session-persistence \
  "Review these validation fixes against the approved configuration source-of-truth design. Identify only concrete correctness or consistency defects. Do not propose scope expansion."
```

Assess every suggestion, apply only useful in-scope changes, rerun Steps 1–5, stage
the final files again, and commit:

```bash
git add SKILL.md AGENTS.md README.md references/configuration.md references/bootstrap.md references/analysis.md
git commit -m "fix: address configuration contract validation"
```

If no files change, do not create an empty commit. Report the validator, vendoring,
classification, and delegated-implementation outcomes in the final handoff.
