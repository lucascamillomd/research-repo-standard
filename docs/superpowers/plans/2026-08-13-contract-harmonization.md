# Contract Harmonization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harmonize the portable policy, skill routing, procedural references, host adapters, and tests around one explicit ownership model.

**Architecture:** `AGENTS.md` remains the portable generated-repository policy, `SKILL.md` routes bootstrap and governed work, references own unique procedure, canonical simplifier YAML drives both adapters, and shell tests assert semantic behavior. Changes are grouped so each task ends with a focused test or consistency gate.

**Tech Stack:** Markdown, POSIX-oriented Bash with existing Bash features, awk, Make, Git.

## Global Constraints

- Preserve floor items 1–7 and 9, the full/light/no-gate triad, and all raw-data and destructive-action protections.
- Both adapters install an exact canonical `agents/code-simplifier.md` and refuse to replace customized generated profiles.
- Claude host frontmatter and Codex TOML metadata derive from canonical YAML name and folded description; only `standard_version` is omitted from Claude host frontmatter.
- `vendor.sh` continues to write only `AGENTS.md`; do not alter its heading verification or transactional replacement.
- Keep vendor safety tests 3–6, Claude policy-alias conflict behavior, adapter precondition checks, blob-link checks, host neutrality, and figure asset grammar ownership.
- Use `2026.08.13` as the standard-version stamp in every touched standard file.
- Preserve the user's pre-existing deletions of the three obsolete 2026-08-12 design/plan files.

---

### Task 1: Portable Policy and Source-Repository Identity

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `tests/consistency_test.sh`

**Interfaces:**
- Consumes: the ownership model approved in `docs/superpowers/specs/2026-08-13-contract-harmonization-design.md`
- Produces: portable policy with a source-repository identity, optional canonical `agents/` layout, and semantic consistency assertions used by later tasks

- [ ] **Step 1: Replace obsolete consistency locks with policy-semantic assertions**

In `tests/consistency_test.sh`, delete checks for `docs/{PIPELINE,DATA,DECISIONS,METHODS}.md` and the `## Agent-skill preflight` heading. Add focused assertions that fail against the current policy:

```bash
if grep -q 'This repository distributes the portable standard' "$ROOT/AGENTS.md" &&
  grep -q 'agents/' "$ROOT/AGENTS.md"; then
  pass "source role and canonical agent-profile path are documented"
else
  fail "source role and canonical agent-profile path are documented"
fi

if grep -q 'preprocessing, normalization, imputation, feature selection, and tuning' \
  "$ROOT/AGENTS.md"; then
  pass "predictive leakage policy names normalization"
else
  fail "predictive leakage policy names normalization"
fi

if grep -q 'Required skills are gates\. A missing skill blocks only its dependent work\.' \
  "$ROOT/AGENTS.md"; then
  pass "required-skill floor is concise"
else
  fail "required-skill floor is concise"
fi
```

- [ ] **Step 2: Run the focused consistency test and confirm failure**

Run: `bash tests/consistency_test.sh`

Expected: nonzero exit with the new source-role, normalization, and concise-skill-floor assertions failing.

- [ ] **Step 3: Harmonize `AGENTS.md`**

Make these exact policy changes:

- Set `standard_version` to `2026.08.13`.
- Replace the placeholder `This repository` content with a short statement that this repository distributes the portable standard, that generated-repository rules describe the vendored artifact rather than maintenance of this source, and that readers start at `README.md` or `make help`.
- Add the broader figure-reference trigger to the routing table.
- Reduce floor item 8 to: `Required skills are gates. A missing skill blocks only its dependent work.`
- Change floor item 9 to stable researcher-editable scientific and operational settings.
- Add `agents/code-simplifier.md` as an optional adapter-installed top-level layout entry.
- Add normalization to the predictive leakage list.
- Split critique failure behavior: missing/uninvokable skill blocks critique-triggering work; an unavailable independent agent blocks only the dependent judgment; unrelated work can continue.
- Keep the logger-not-print rule but remove concrete `loguru`, R `logger`, sink, and level prescriptions.
- Remove the comments essay while retaining the typed public-interface and Google-docstring requirement.
- Remove the test-philosophy essay while retaining concrete coverage requirements and comparison rules.

- [ ] **Step 4: Update the source README map**

Set `README.md`'s stamp to `2026.08.13` and add:

```text
├── Makefile                   # source-repo help/test/format wrapper
```

State that it is not the generated-repository workflow interface.

- [ ] **Step 5: Run focused tests and formatting**

Run: `bash tests/consistency_test.sh && make format`

Expected: consistency tests pass and formatting exits zero.

- [ ] **Step 6: Commit the policy surface**

```bash
git add AGENTS.md README.md tests/consistency_test.sh
git commit -m "docs: clarify portable policy ownership"
```

### Task 2: Canonical Simplifier and Protective Host Adapters

**Files:**
- Modify: `agents/code-simplifier.md`
- Modify: `adapters/claude-code.sh`
- Modify: `adapters/codex.sh`
- Modify: `tests/adapter_test.sh`
- Modify: `references/prerequisites.md`

**Interfaces:**
- Consumes: canonical YAML keys `name`, folded `description`, and `standard_version` from `agents/code-simplifier.md`
- Produces: `canonical_name` and `canonical_description` shell values; exact canonical profile copy; generated Claude Markdown and Codex TOML files with refuse-on-conflict behavior

- [ ] **Step 1: Extend adapter tests around canonical derivation and conflict preservation**

Replace the hardcoded Claude-description expectation with YAML-derived expected metadata. Add a test helper in `tests/adapter_test.sh`:

```bash
canonical_name="$(awk '$1 == "name:" { print $2; exit }' "$ROOT/agents/code-simplifier.md")"
canonical_description="$(awk '
    /^description:/ { capture = 1; next }
    capture && /^[[:space:]]+[[:graph:]]/ {
        sub(/^[[:space:]]+/, "")
        text = text (text == "" ? "" : " ") $0
        next
    }
    capture { exit }
    END { print text }
' "$ROOT/agents/code-simplifier.md")"
```

Assert the Claude frontmatter equals `name: $canonical_name` plus `description: $canonical_description`, the Codex TOML contains the same escaped values, and both target canonical profiles equal the source.

Add four conflict cases: customized Claude canonical profile, customized Claude host profile, customized Codex canonical profile, and customized Codex TOML. Each invocation must fail with `refusing to replace customized` and preserve the checksum.

Remove both `CODEX.md` absence assertions.

- [ ] **Step 2: Run adapter tests and confirm failure**

Run: `bash tests/adapter_test.sh`

Expected: nonzero exit because Claude lacks the canonical copy and neither adapter protects customized profiles.

- [ ] **Step 3: Make the canonical profile explicitly delegated**

Set its `standard_version` to `2026.08.13`. Replace the final autonomy sentence with:

```text
Run only when an implementing agent explicitly delegates the repository's required post-change
simplification pass. Do not initiate edits merely because modified code is present.
```

- [ ] **Step 4: Add shared protective-write behavior to both adapters**

In each adapter, use a narrowly scoped helper:

```bash
install_expected_file() {
  source_file=$1
  destination_file=$2
  if [[ -e "$destination_file" ]] && ! cmp -s "$source_file" "$destination_file"; then
    echo "$(basename "$0"): refusing to replace customized ${destination_file#"$TARGET"/}" >&2
    exit 1
  fi
  if [[ ! -e "$destination_file" ]]; then
    cp "$source_file" "$destination_file"
  fi
}
```

Generate host files in a target-local `mktemp` file, compare before replacement, clean temporary files on exit, and move only when the destination is absent. Validate canonical metadata is present before generating either host format.

Claude must create both `$TARGET/agents/code-simplifier.md` and `$TARGET/.claude/agents/code-simplifier.md`. Its generated frontmatter contains only canonical name and one-line folded description, followed by the canonical body.

Codex must create `$TARGET/agents/code-simplifier.md` and generate TOML containing canonical name and description plus the existing provider-neutral developer instruction. Escape backslashes and double quotes before writing TOML.

- [ ] **Step 5: Update host-integration documentation**

In `references/prerequisites.md`, state that both adapters install `agents/code-simplifier.md`, then add their host-specific wrapper. State that customized generated profiles cause refusal rather than overwrite. Set its stamp to `2026.08.13`.

- [ ] **Step 6: Run adapter and vendor tests**

Run: `bash tests/adapter_test.sh && bash tests/vendor_test.sh`

Expected: both suites pass; reruns preserve byte-identical output and every conflict fixture remains unchanged.

- [ ] **Step 7: Commit adapter harmonization**

```bash
git add agents/code-simplifier.md adapters/claude-code.sh adapters/codex.sh \
  tests/adapter_test.sh references/prerequisites.md
git commit -m "fix: derive protected host profiles from canonical source"
```

### Task 3: Domain Reference Deduplication

**Files:**
- Modify: `references/analysis.md`
- Modify: `references/configuration.md`
- Modify: `references/data.md`
- Modify: `references/figures.md`
- Modify: `tests/consistency_test.sh`

**Interfaces:**
- Consumes: normative triggers and floor rules from `AGENTS.md`
- Produces: unique procedural contracts reached through the routing table

- [ ] **Step 1: Replace exact Markdown-row locks with semantic trigger checks**

In `tests/consistency_test.sh`, remove the assertion that pins exact SKILL table punctuation. Add a loop that checks all four figure triggers in both routing and reference surfaces:

```bash
figure_trigger_ok=1
for file in "$ROOT/AGENTS.md" "$ROOT/references/figures.md"; do
  for trigger in 'planning a figure' 'writing plotting code' 'modifying figure outputs' 'performing QA'; do
    if ! grep -Fq "$trigger" "$file"; then
      fail "missing figure trigger in ${file#"$ROOT"/}: $trigger"
      figure_trigger_ok=0
    fi
  done
done
if ((figure_trigger_ok)); then
  pass "figure procedure triggers stay aligned"
fi
```

Retain the existing test that the concrete `mf1_hazard_ratio_distribution` stem occurs only in `references/figures.md`.

- [ ] **Step 2: Run consistency tests and confirm the new wording contract fails**

Run: `bash tests/consistency_test.sh`

Expected: nonzero exit until the routing/reference wording contains all four semantic triggers.

- [ ] **Step 3: Slim the analysis reference**

Set the stamp to `2026.08.13`; change scope from planning/executing/reporting to planning/reporting. Preserve the `ANALYSIS_PLAN.md` field template. Replace copied floor items 4–5 with `AGENTS.md floor items 4–5 apply.` Replace the YAML/loader paragraph with `Operationalize these fields in config/analysis.yaml under the configuration contract.`

Mark center/spread definitions and scientific interpretation as recommended reporting additions. Remove the copied critique trigger list, advisory status, and plumbing exemption; retain one-critique-per-coherent-batch including bootstrap, the split unavailable-skill/unavailable-agent behavior, and “a skill is guidance, not evidence.” Delete `Related workflow skills`.

- [ ] **Step 4: Slim the configuration reference**

Set the stamp to `2026.08.13`. Qualify bucket four as a named Python constant only when the value is an implementation choice and not a researcher-editable scientific or operational setting. Replace the `config/` tree with one sentence saying `analysis.yaml` owns settings and `datasets.yaml` is governed by the data contract.

Replace the duplicated provenance inventory with:

```text
Record every result-affecting override and its source. Reject an override that cannot be recorded.
The complete manifest inventory is defined by AGENTS.md.
```

Reduce configuration tests to extras not already in policy: reject versioned secrets and YAML path redirection; verify seed-42 propagation when stochastic; fail verification when an override is absent from provenance.

- [ ] **Step 5: Slim the data reference**

Set the stamp to `2026.08.13`. Replace `expected local location` with `registry identifier and received-form description; internal data/raw/... paths stay in paths.py`. Replace repeated complete-case/inclusion prose with `AGENTS.md floor items 4–5 apply to validation and attrition.` Delete the fixtures section.

- [ ] **Step 6: Slim the figure reference without weakening its unique contract**

Set the stamp to `2026.08.13`. Collapse `Scope` to a sentence that `AGENTS.md` supplies normative requirements and that this reference must be read before planning a figure, writing plotting code, modifying figure outputs, or performing QA. Remove task-time skill invocation and Python availability restatements.

Keep the pre-plot template including `Backend: Python`, atomic `mf1_`/`edf1_` stems, format directories, assembly-after-atomic rule, panel letters at assembly only, cross-figure encoding consistency, and QA checklist. Change the typography sentence to require a consistent sans-serif with editable SVG/PDF text, without prescribing Arial or Helvetica.

- [ ] **Step 7: Run domain consistency tests**

Run: `bash tests/consistency_test.sh && make format`

Expected: all semantic routing, sole-owner, link, and formatting checks pass.

- [ ] **Step 8: Commit the reference cleanup**

```bash
git add references/analysis.md references/configuration.md references/data.md \
  references/figures.md tests/consistency_test.sh
git commit -m "docs: give domain references unique ownership"
```

### Task 4: Bootstrap and Skill Routing

**Files:**
- Modify: `SKILL.md`
- Modify: `references/bootstrap.md`
- Modify: `references/prerequisites.md`
- Modify: `tests/consistency_test.sh`

**Interfaces:**
- Consumes: exact required skill names and target-repository integration order
- Produces: name-only preflight before interview, explicit Python/host answers, and post-vendor adapter integration

- [ ] **Step 1: Add bootstrap-routing consistency assertions**

Add checks that `SKILL.md` asks for `Python minor` and `host adapter`, that bootstrap examples contain `py3XY` and `3.XY`, that `coverage` and unconditional `test-r:` are absent, and that prerequisites do not own adapter installation headings:

```bash
bootstrap_contract_ok=1
for required in 'Python minor' 'host adapter'; do
  grep -Fq "$required" "$ROOT/SKILL.md" || bootstrap_contract_ok=0
done
grep -Fq 'target-version = "py3XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'python-version = "3.XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'coverage' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
grep -Eq '^test-r:' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
if ((bootstrap_contract_ok)); then
  pass "bootstrap answers and placeholders are explicit"
else
  fail "bootstrap answers and placeholders are explicit"
fi
```

- [ ] **Step 2: Run consistency tests and confirm failure**

Run: `bash tests/consistency_test.sh`

Expected: nonzero exit because Python/host questions and placeholders are missing and coverage/test-r remain.

- [ ] **Step 3: Simplify `SKILL.md` routing and expand the interview**

Set the stamp to `2026.08.13`. Keep the reference table but narrow prerequisites to bootstrap preflight or recovery from a missing required capability. Replace the governed-policy restatement body with:

```text
In governance mode apply AGENTS.md. Load a reference only from the table above.
Do not restate AGENTS.md back to the user.
```

Make preflight name-resolution only before the interview. Add one-at-a-time interview questions for a currently supported Python minor and host adapter (`codex`, `claude-code`, or none). Keep existing project questions, conditional follow-ups, and critique/design gates.

Keep `vendor.sh` as step 7 and adapter installation as step 8. Move delegated smoke testing there, after the target exists, and run it only when a host adapter was selected.

- [ ] **Step 4: Slim bootstrap configuration examples**

Set `references/bootstrap.md` to `2026.08.13`. Change the prerequisite paragraph to exact-name resolution before interview, with installation/recovery only if missing. Use:

```toml
[dependency-groups]
dev = ["pre-commit", "pytest", "ruff", "ty"]

[tool.ruff]
target-version = "py3XY"          # match .python-version

[tool.ty.environment]
python-version = "3.XY"
```

Replace the Makefile target list with required `help`, `setup`, `test`, and one project-named verification gate, followed by prose to add quality, analysis, figures, pipeline, reports, and guarded cleanup targets when relevant. Put R container and `test-r` guidance behind the interview's R requirement.

Remove bootstrap's canonical simplifier-copy step and say the selected adapter installs it. Remove README “reproducibility classification.” Retain uv lock/sync semantics, local Ruff hooks, and tool-config ownership after creation.

- [ ] **Step 5: Keep prerequisites host-only**

In `references/prerequisites.md`, remove upstream revision pins and the adapter-install/delegated-agent sections now owned by `SKILL.md`. Consolidate the scientific-skill examples around an explicitly assigned shell value:

```bash
agent_host=codex  # use claude-code when that is the selected host
npx skills add K-Dense-AI/scientific-agent-skills --global --agent "$agent_host" --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent "$agent_host" --skill nature-figure --yes --copy
npx skills list --global --agent "$agent_host" --json
```

Keep separate Superpowers marketplace instructions for Codex and Claude. State Node 18/`npx` is required only when running those installer commands.

Keep native resolver verification, no silent install, no substitution, Codex `.agents/skills/` with no `CODEX.md`, Claude `.claude/skills/` with optional alias, and writing-plans as a companion rather than a fourth hard gate.

- [ ] **Step 6: Run routing and complete source tests**

Run: `make format && make test`

Expected: all vendor, adapter, and consistency tests pass.

- [ ] **Step 7: Commit bootstrap harmonization**

```bash
git add SKILL.md references/bootstrap.md references/prerequisites.md tests/consistency_test.sh
git commit -m "docs: align bootstrap preflight and integration"
```

### Task 5: Vendor Test Simplification and Release Stamp Audit

**Files:**
- Modify: `tests/vendor_test.sh`
- Modify: any touched standard file whose opening stamp is not `2026.08.13`

**Interfaces:**
- Consumes: unchanged `vendor.sh` single-file output behavior
- Produces: outcome-based fresh-vendor assertion and synchronized release surface

- [ ] **Step 1: Rewrite the fresh-vendor test before changing assertions elsewhere**

Replace named sidecar checks with an exact top-level inventory:

```bash
top_level_count="$(find "$t1" -mindepth 1 -maxdepth 1 | wc -l | tr -d '[:space:]')"
if diff -q "$ROOT/AGENTS.md" "$t1/AGENTS.md" > /dev/null &&
  [[ "$top_level_count" -eq 1 ]]; then
  pass "fresh portable vendor contains only AGENTS.md"
else
  fail "fresh portable vendor contains only AGENTS.md"
fi
```

Delete the `.bak` test block. Do not change `vendor.sh` or tests 3–6.

- [ ] **Step 2: Run vendor tests**

Run: `bash tests/vendor_test.sh`

Expected: all vendor tests pass.

- [ ] **Step 3: Audit standard stamps**

Run:

```bash
for file in AGENTS.md SKILL.md README.md references/*.md agents/*.md; do
  awk 'NR <= 12 && /standard_version: 2026.08.13/ { found=1 } END { exit !found }' "$file" || exit 1
done
```

Expected: exit zero. Update only a touched file that fails; do not change untouched historical artifacts outside the standard-file glob.

- [ ] **Step 4: Commit vendor-test cleanup**

```bash
git add tests/vendor_test.sh AGENTS.md SKILL.md README.md references/*.md agents/*.md
git commit -m "test: simplify portable vendor assertions"
```

### Task 6: Independent Simplification and Final Verification

**Files:**
- Review: `adapters/claude-code.sh`
- Review: `adapters/codex.sh`
- Review: `tests/vendor_test.sh`
- Review: `tests/adapter_test.sh`
- Review: `tests/consistency_test.sh`
- Delete: `docs/superpowers/plans/2026-08-12-portable-skill-cleanup.md`
- Delete: `docs/superpowers/specs/2026-08-12-documentation-contract-design.md`
- Delete: `docs/superpowers/specs/2026-08-12-portable-skill-cleanup-design.md`

**Interfaces:**
- Consumes: completed behavior and canonical `agents/code-simplifier.md` profile
- Produces: independently reviewed shell changes, clean tests, and intentional final worktree inventory

- [ ] **Step 1: Delegate the required simplifier pass**

Launch an independent review agent with this exact scope:

```text
Read and apply agents/code-simplifier.md. Review only adapters/claude-code.sh,
adapters/codex.sh, tests/vendor_test.sh, tests/adapter_test.sh, and
tests/consistency_test.sh as changed in this implementation. Preserve behavior and contract
exactly. Make only clear simplifications, then report edits and tests. Do not introduce new
requirements or edit documentation.
```

Expected: the independent agent returns either no changes or behavior-preserving edits within the five listed files.

- [ ] **Step 2: Inspect and test any simplifier edits**

Run: `git diff -- adapters tests`

Reject any edit that changes conflict behavior, canonical metadata derivation, vendor safety, or semantic contract coverage. If edits remain, run: `bash tests/adapter_test.sh && bash tests/vendor_test.sh && bash tests/consistency_test.sh`.

Expected: all suites pass.

- [ ] **Step 3: Run full verification**

Run:

```bash
make format
make test
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 4: Inspect actual generated adapter artifacts**

Create a temporary target with `mktemp -d`, run `vendor.sh` and each adapter in separate target copies, then inspect:

```text
AGENTS.md
agents/code-simplifier.md
.claude/agents/code-simplifier.md
CLAUDE.md -> AGENTS.md
.codex/agents/code-simplifier.toml
```

Confirm canonical copies are byte-identical, descriptions match canonical YAML, Claude omits `standard_version`, Codex contains no host/model overrides, and reruns do not change checksums. Remove the temporary directory after inspection.

- [ ] **Step 5: Inspect worktree scope and commit completion**

Run: `git status --short && git diff --stat HEAD~5..HEAD`

Confirm only approved source, reference, adapter, test, gate-artifact changes, and the three authorized deletions are present. Commit simplifier edits, deletions, and any final stamp-only corrections:

```bash
git add -A
git commit -m "chore: complete contract harmonization"
```

- [ ] **Step 6: Report completion evidence**

Report changed ownership boundaries, adapter conflict behavior, the independent simplifier outcome, exact verification commands, generated-artifact inspection, authorized deletions, and any skipped boundary. Do not claim completion if any test or inspection is outstanding.
