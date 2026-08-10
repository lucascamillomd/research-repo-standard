# Proportionate Gates and Structural Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the research-repo-standard's process cost proportionate to scientific risk, give every rule one owning document, make `standard-check` real, and test the vendoring tooling.

**Architecture:** The repo is a documentation-first skill: `AGENTS.md` (vendored into projects) owns governance rules, `SKILL.md` is the skill entry point, `references/*.md` hold on-demand detail, `vendor.sh` copies `AGENTS.md` into targets. Tasks 1–3 build the only executable parts (hardened `vendor.sh`, `--check` mode, tests, Makefile). Tasks 4–11 are markdown contract edits verified by grep and review.

**Tech Stack:** bash, awk, GNU make, markdown. No Python involved in this repo itself.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-10-friction-and-cleanup-design.md`. Follow it exactly.
- Every file touched by tasks 4–11 gets its version stamp set to `standard_version: 2026.08.10`. Untouched files keep their stamps.
- The floor rules in `AGENTS.md` (section "The floor") are NOT weakened by any edit. Floor rule 10 stays as written.
- vendor.sh must keep working on macOS's shipped bash 3.2 and BSD awk/sed — no bash 4 features (no associative arrays, no `${var,,}`), no GNU-only flags.
- Markdown style: keep the existing ~88-column wrapping and heading style of each file.
- Uncertainty tie-breakers written into contracts must say: uncertain → full gate / classify as scientific.
- Commit after every task with the message given in that task.

---

### Task 1: Harden vendor.sh and add the test harness

**Files:**
- Modify: `vendor.sh` (full rewrite below)
- Create: `tests/vendor_test.sh`
- Create: `Makefile`

**Interfaces:**
- Produces: `vendor.sh` with internal functions `usage`, `verify_source`, `build_vendored OUT TARGET` (Task 2 adds `--check` on top of these). `tests/vendor_test.sh` with helpers `pass MSG` / `fail MSG` and a `FAILS` counter (Tasks 2–3 append test blocks before the final exit block). `make test` runs the script.

- [ ] **Step 1: Write the test script with tests for hardened behavior**

Create `tests/vendor_test.sh` (mode 755):

```bash
#!/usr/bin/env bash
# Tests for vendor.sh. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- 1. fresh vendor copies AGENTS.md and symlinks CLAUDE.md ---
t1="$tmp/fresh"; mkdir "$t1"
"$ROOT/vendor.sh" "$t1" >/dev/null
if diff -q "$ROOT/AGENTS.md" "$t1/AGENTS.md" >/dev/null \
   && [[ "$(readlink "$t1/CLAUDE.md")" == "AGENTS.md" ]]; then
    pass "fresh vendor"
else
    fail "fresh vendor"
fi

# --- 2. re-vendor preserves a modified '## This repository' section, no .bak ---
awk '/^## This repository$/{print; print ""; print "CUSTOM-MARKER project identity line."; next} {print}' \
    "$t1/AGENTS.md" > "$t1/AGENTS.md.new" && mv "$t1/AGENTS.md.new" "$t1/AGENTS.md"
"$ROOT/vendor.sh" "$t1" >/dev/null
if grep -q 'CUSTOM-MARKER' "$t1/AGENTS.md"; then
    pass "re-vendor preserves the This repository section"
else
    fail "re-vendor preserves the This repository section"
fi
if [[ -e "$t1/AGENTS.md.bak" ]]; then
    fail "re-vendor must not leave AGENTS.md.bak"
else
    pass "no .bak litter"
fi

# --- 3. a source missing a boundary heading aborts, target untouched ---
bad="$tmp/badsrc"; mkdir "$bad"
cp "$ROOT/vendor.sh" "$bad/vendor.sh"
grep -vx '## Using this standard' "$ROOT/AGENTS.md" > "$bad/AGENTS.md"
t3="$tmp/badtarget"; mkdir "$t3"
echo "sentinel" > "$t3/AGENTS.md"
if "$bad/vendor.sh" "$t3" >/dev/null 2>&1; then
    fail "corrupted source must abort"
else
    pass "corrupted source aborts"
fi
if [[ "$(cat "$t3/AGENTS.md")" == "sentinel" ]]; then
    pass "aborted vendor leaves target untouched"
else
    fail "aborted vendor leaves target untouched"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all tests passed"
```

- [ ] **Step 2: Create the Makefile**

```make
.DEFAULT_GOAL := help
.PHONY: help test

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

test: ## Run vendor.sh and version-stamp tests
	bash tests/vendor_test.sh
```

- [ ] **Step 3: Run the tests to verify the new ones fail against current vendor.sh**

Run: `chmod +x tests/vendor_test.sh && make test`
Expected: test 1 and 2 (preserve) pass; "no .bak litter" FAILS (current script writes `.bak`); "corrupted source aborts" FAILS (current script splices silently). Exit 1.

- [ ] **Step 4: Rewrite vendor.sh**

Replace the entire file with:

```bash
#!/usr/bin/env bash
# Vendor the standard into a target repository.
#
# Copies AGENTS.md and points CLAUDE.md at it. Nothing else is vendored --
# references/ stays in the skill and loads on demand.
#
# Re-vendoring preserves the target's "## This repository" section. That
# section is the project's identity and the only part expected to differ from
# this source; wiping it on every update would make the maintenance loop
# (edit here, vendor forward) destructive by default.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "usage: vendor.sh <target-repo>" >&2
    exit 2
}

# The splice below assumes these two headings exist in this order; without the
# check, a renamed heading would silently produce a corrupted vendored file.
verify_source() {
    local this using
    this="$(grep -nx '## This repository' "$SRC/AGENTS.md" | head -1 | cut -d: -f1)"
    using="$(grep -nx '## Using this standard' "$SRC/AGENTS.md" | head -1 | cut -d: -f1)"
    if [[ -z "$this" || -z "$using" ]] || (( this >= using )); then
        echo "vendor.sh: source AGENTS.md must contain '## This repository' followed by '## Using this standard'; aborting" >&2
        exit 1
    fi
}

# Build the vendored AGENTS.md into $1 for target $2, preserving the target's
# "## This repository" section when it has one.
#
# The section body is spliced through files rather than an awk -v variable:
# the awk shipped with macOS rejects newlines in -v values, so a multi-line
# section silently breaks the substitution there.
build_vendored() {
    local out="$1" target="$2" work
    work="$(dirname "$out")"
    if [[ -f "$target/AGENTS.md" ]]; then
        awk '/^## This repository$/{s=1;next} /^## Using this standard$/{s=0} s' \
            "$target/AGENTS.md" > "$work/section"
    else
        : > "$work/section"
    fi
    if [[ -s "$work/section" ]]; then
        awk '{print} /^## This repository$/{exit}'  "$SRC/AGENTS.md" > "$work/head"
        awk '/^## Using this standard$/{f=1} f'     "$SRC/AGENTS.md" > "$work/tail"
        cat "$work/head" "$work/section" "$work/tail" > "$out"
    else
        cp "$SRC/AGENTS.md" "$out"
    fi
}

[[ $# -eq 1 ]] || usage
TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
    echo "vendor.sh: not a directory: $TARGET" >&2
    exit 1
fi

verify_source

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

build_vendored "$work/AGENTS.md" "$TARGET"

# Move into place only after the whole file is built, so a failure partway
# through cannot leave a half-written standard behind. The target is a git
# repository; git is the backup, so no .bak file is written.
had_section=0
[[ -s "$work/section" ]] && had_section=1
mv "$work/AGENTS.md" "$TARGET/AGENTS.md"

# CLAUDE.md is a symlink so there is one file, not two that can disagree.
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"

version="$(sed -n '1s/.*standard_version: \([0-9.]*\).*/\1/p' "$SRC/AGENTS.md")"
echo "vendored standard_version: $version -> $TARGET"

if (( had_section )); then
    echo "preserved the existing '## This repository' section"
else
    echo "next: fill in the '## This repository' section of $TARGET/AGENTS.md"
fi
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `make test`
Expected: all tests pass, exit 0.

- [ ] **Step 6: Commit**

```bash
git add vendor.sh tests/vendor_test.sh Makefile
git commit -m "feat: harden vendor.sh and add vendor tests"
```

---

### Task 2: Add `vendor.sh --check` (standard-check mechanism)

**Files:**
- Modify: `vendor.sh` (from Task 1)
- Modify: `tests/vendor_test.sh` (append test block before the `# --- final ---` block)

**Interfaces:**
- Consumes: `verify_source`, `build_vendored OUT TARGET` from Task 1.
- Produces: `vendor.sh --check <target-repo>` — exit 0 clean, 1 drifted, 2 usage/no-AGENTS.md. Task 9's Makefile skeleton and the existing `make standard-check` promise in SKILL.md/README rely on this exact interface.

- [ ] **Step 1: Append the failing tests**

Insert into `tests/vendor_test.sh` immediately before the `# --- final ---` block:

```bash
# --- 4. --check: clean vendor exits 0, edited target exits 1 ---
if "$ROOT/vendor.sh" --check "$t1" >/dev/null 2>&1; then
    pass "--check clean"
else
    fail "--check clean"
fi
echo "local drift line" >> "$t1/AGENTS.md"
"$ROOT/vendor.sh" --check "$t1" >/dev/null 2>&1
rc=$?
if [[ "$rc" -eq 1 ]]; then
    pass "--check reports drift with exit 1"
else
    fail "--check reports drift with exit 1 (got $rc)"
fi
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `make test`
Expected: the two new `--check` tests fail (current script treats `--check` as a directory name); earlier tests still pass.

- [ ] **Step 3: Implement --check**

In `vendor.sh`, replace the `usage()` body line with:

```bash
    echo "usage: vendor.sh <target-repo> | vendor.sh --check <target-repo>" >&2
```

Replace the argument-parsing block

```bash
[[ $# -eq 1 ]] || usage
TARGET="$1"
```

with:

```bash
CHECK=0
if [[ "${1:-}" == "--check" ]]; then
    CHECK=1
    shift
fi
[[ $# -eq 1 ]] || usage
TARGET="$1"
```

Then insert immediately after the `build_vendored "$work/AGENTS.md" "$TARGET"` line:

```bash
if (( CHECK )); then
    if [[ ! -f "$TARGET/AGENTS.md" ]]; then
        echo "vendor.sh: no AGENTS.md in $TARGET to check" >&2
        exit 2
    fi
    src_version="$(sed -n '1s/.*standard_version: \([0-9.]*\).*/\1/p' "$SRC/AGENTS.md")"
    tgt_version="$(sed -n '1s/.*standard_version: \([0-9.]*\).*/\1/p' "$TARGET/AGENTS.md")"
    echo "source standard_version: ${src_version:-unknown}; vendored standard_version: ${tgt_version:-unknown}"
    if diff -u "$TARGET/AGENTS.md" "$work/AGENTS.md"; then
        echo "standard-check: clean"
        exit 0
    else
        echo "standard-check: drift (diff above: '-' vendored copy, '+' fresh vendor)"
        exit 1
    fi
fi
```

(`diff` exits nonzero on difference; `set -e` does not trigger inside `if` conditions, so this is safe.)

- [ ] **Step 4: Run tests to verify all pass**

Run: `make test`
Expected: all tests pass, exit 0.

- [ ] **Step 5: Commit**

```bash
git add vendor.sh tests/vendor_test.sh
git commit -m "feat: add vendor.sh --check drift mode"
```

---

### Task 3: Version-stamp consistency test

**Files:**
- Modify: `tests/vendor_test.sh` (append before `# --- final ---`)

**Interfaces:**
- Consumes: `pass`/`fail`/`FAILS` helpers from Task 1.
- Produces: a test that fails when any standard file lacks a `standard_version` stamp in its first 5 lines. Tasks 4–11 rely on it to catch stamp regressions.

- [ ] **Step 1: Append the test**

Insert into `tests/vendor_test.sh` immediately before the `# --- final ---` block:

```bash
# --- 5. every standard file carries a version stamp in its first 5 lines ---
stamp_ok=1
for f in "$ROOT"/AGENTS.md "$ROOT"/SKILL.md "$ROOT"/README.md "$ROOT"/references/*.md; do
    if ! head -5 "$f" | grep -q 'standard_version:'; then
        fail "missing standard_version stamp: ${f#"$ROOT"/}"
        stamp_ok=0
    fi
done
if (( stamp_ok )); then
    pass "version stamps present"
fi
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: all pass (every current file, including bootstrap.md's YAML frontmatter, has `standard_version:` within 5 lines). Exit 0.

- [ ] **Step 3: Commit**

```bash
git add tests/vendor_test.sh
git commit -m "test: check version stamps across standard files"
```

---

### Task 4: AGENTS.md — tiered modification gate

**Files:**
- Modify: `AGENTS.md` (lines 1, 64–73, 75–83, and the Working procedure paragraph)

**Interfaces:**
- Produces: the terms **full gate**, **light path**, **no gate** as defined here. Tasks 7, 8, 10, 11 refer to these terms and must not redefine them.

- [ ] **Step 1: Bump the stamp**

Replace line 1:

```
<!-- standard_version: 2026.08.05 -->
```

with:

```
<!-- standard_version: 2026.08.10 -->
```

- [ ] **Step 2: Replace the single-gate paragraph with the tiered rule**

Replace this paragraph (currently AGENTS.md:64–73):

```
Each user-requested modification invokes `superpowers:brainstorming` and opens one
active gate. After design approval, its specification, plan, and approval records may
be created under that gate. The gate completes only when the specification is
committed and reviewed by the user and the implementation plan is ready; requested
implementation files remain blocked until then. All direct or delegated
implementation inherits the completed gate. If the requested scope expands, reopen
that same gate at design before implementing the new scope. Executing an already
approved workflow solely to regenerate its declared outputs does not open a new gate;
changing code, configuration, or contracts does. Read-only explanation, inspection,
diagnosis, and status reporting are not modifications.
```

with:

```
Each user-requested modification that creates, edits, moves, or deletes files takes
one of two paths. The agent classifies the request; when uncertain, use the full
gate.

**Full gate** — required for any result-affecting or contract-affecting change:
estimands, inclusion or exclusion rules, statistical methods or models,
`config/analysis.yaml`, data contracts and schemas, pipeline structure, publication
figures, new analyses, new features, and changes to this standard's rules. Invoke
`superpowers:brainstorming` and open one active gate. After design approval, the
specification, plan, and approval records may be created under that gate; the
requested implementation files remain blocked until the specification is committed
and reviewed by the user and the implementation plan is ready. All direct or
delegated implementation inherits the completed gate. If the requested scope
expands, reopen that same gate at design before implementing the new scope.

**Light path** — for mechanical, non-result-affecting changes: documentation and
typo fixes, comment edits, lint or formatting fixes, renames with no interface
change, refactors fully covered by existing tests, and added tests that do not
change behavior. State the intent, the files to be touched, and why the change is
non-result-affecting; obtain one user confirmation; implement. No specification or
plan artifacts are created. If the change turns out to affect results, interfaces,
or contracts, stop and reopen as a full gate before continuing.

**No gate** — read-only explanation, inspection, diagnosis, and status reporting
are not modifications. Executing an already approved workflow solely to regenerate
its declared outputs does not open a new gate.

| Request | Path |
|---|---|
| Fix a typo in README | light |
| Rename a stage directory with no interface change | light |
| Add a sensitivity analysis | full |
| Change an inclusion threshold in `config/analysis.yaml` | full |
| Rerun `make figures` unchanged | no gate |
| Explain what a pipeline stage does | no gate |
```

- [ ] **Step 3: Align the bootstrap paragraph**

In the next paragraph (begins "During repository bootstrap"), replace:

```
repository design is this same modification gate, not an additional gate.
```

with:

```
repository design is this same full gate, not an additional gate.
```

- [ ] **Step 4: Align the Working procedure reference**

In the Working procedure section, replace:

```
Before the context and status checks below, apply the single normative modification
gate under **Required agent skills**. Requested implementation files remain blocked
until that gate completes; its inheritance, regeneration exemption, and scope-expansion
rules govern the implementation that follows.
```

with:

```
Before the context and status checks below, classify the request under the
modification gates in **Required agent skills** and apply the resulting path. Under
a full gate, requested implementation files remain blocked until the gate
completes; its inheritance, regeneration exemption, and scope-expansion rules
govern the implementation that follows.
```

- [ ] **Step 5: Verify**

Run: `grep -c 'Full gate\|Light path\|No gate' AGENTS.md && make test`
Expected: 3 matches (one each as bold headers); tests pass.

- [ ] **Step 6: Commit**

```bash
git add AGENTS.md
git commit -m "feat: tier the modification gate by scientific risk"
```

---

### Task 5: AGENTS.md — two-tier figure contract

**Files:**
- Modify: `AGENTS.md` (Core principles item 8, repository layout `results/` block, Figures section)

**Interfaces:**
- Consumes: gate terms from Task 4.
- Produces: the terms **publication figure** and **working plot**, and the layout path `results/diagnostics/`. Task 7 (figures.md) uses the same two terms and path.

- [ ] **Step 1: Rewrite core principle 8**

Replace:

```
8. Every plot uses Python and the full `nature-figure` workflow.
```

with:

```
8. Every plot uses Python; publication figures use the full `nature-figure` workflow.
```

- [ ] **Step 2: Add diagnostics to the layout**

In the repository layout block, replace:

```
├── results/
│   ├── figures/<figure_id>/{svg,pdf,tiff,png}/
```

with:

```
├── results/
│   ├── diagnostics/                # working plots (PNG), never publication artifacts
│   ├── figures/<figure_id>/{svg,pdf,tiff,png}/
```

- [ ] **Step 3: Rewrite the Figures section**

Replace the first paragraph of `## Figures`:

```
Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound
— uses the `nature-figure` skill, is written in Python, is implemented as importable
functions under `src/<package_name>/figures/`, has traceable source data, and exports
all four formats: editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each format
lives in its own extension-named directory under `results/figures/<figure_id>/`.
```

with:

```
Figures come in two tiers. A **publication figure** — manuscript-bound, or an
analytical figure supporting a claim — uses the `nature-figure` skill, is written in
Python, is implemented as importable functions under `src/<package_name>/figures/`,
has traceable source data, and exports all four formats: editable SVG, editable PDF,
600 dpi TIFF, PNG preview. Each format lives in its own extension-named directory
under `results/figures/<figure_id>/`.

A **working plot** — exploratory or diagnostic — uses Python, obeys the determinism
and seed rules, records which declared dataset or artifact it read, and writes a
single PNG under `results/diagnostics/`. It requires no `nature-figure` invocation,
no `docs/FIGURE_CONTRACT.md` entry, no multi-format export, and no QA checklist. A
working plot never silently becomes a publication figure: promotion goes through the
full publication contract, starting from the pre-plot contract.
```

Then in the second paragraph of `## Figures`, replace:

```
Record the contract in `docs/FIGURE_CONTRACT.md` **before** writing plotting code.
```

with:

```
For publication figures, record the contract in `docs/FIGURE_CONTRACT.md` **before**
writing plotting code.
```

(The R prohibition and stop-on-blocker sentences in that paragraph stay verbatim — they apply to both tiers.)

- [ ] **Step 4: Verify**

Run: `grep -c 'working plot' AGENTS.md && grep -c 'results/diagnostics/' AGENTS.md && make test`
Expected: at least 2 and at least 2; tests pass.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "feat: two-tier figure contract with working plots"
```

---

### Task 6: AGENTS.md — enumerated critique triggers

**Files:**
- Modify: `AGENTS.md` (Analysis section, second paragraph)

**Interfaces:**
- Produces: the enumerated critique trigger list and batching/concurrency rule. Task 8 (analysis.md) expands but must not contradict it.

- [ ] **Step 1: Replace the critique paragraph**

In `## Analysis`, replace:

```
When work turns on a scientific judgment — study design, estimand, statistical
method, alternative explanations, the scope of a claim — request an independent
critique. A separate subagent applies `scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) and returns findings without implementing
anything. The critique is advisory; weigh it against the evidence and the task.
Routine plumbing does not need one. A skill is guidance, not evidence — validate
against primary documentation, known examples, and the study design.
If the critique skill or a separate review subagent is unavailable, stop before
making or implementing the scientific judgment and report the blocker.
```

with:

```
An independent critique is required when defining or changing: an estimand, a study
design, a statistical method or model choice, inclusion or exclusion rules, a
missing-data policy, a causal interpretation, or the scope of a claim. One critique
covers one design or coherent batch of decisions — not one critique per individual
judgment. A separate subagent applies `scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) and returns findings without implementing
anything. The critique is advisory; weigh it against the evidence and the task. It
may run concurrently with work that does not depend on the judgment under review;
only dependent work waits. Routine plumbing does not need one. A skill is guidance,
not evidence — validate against primary documentation, known examples, and the
study design. If the critique skill or a separate review subagent is unavailable,
stop before making or implementing the scientific judgment and report the blocker.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'coherent batch' AGENTS.md && make test`
Expected: 1; tests pass.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "feat: enumerate and batch critique triggers"
```

---

### Task 7: references/figures.md — two-tier scope

**Files:**
- Modify: `references/figures.md` (stamp, Scope section)

**Interfaces:**
- Consumes: **publication figure** / **working plot** terms and `results/diagnostics/` path from Task 5, verbatim.

- [ ] **Step 1: Bump the stamp**

Replace line 1 `<!-- standard_version: 2026.08.04 -->` with `<!-- standard_version: 2026.08.10 -->`.

- [ ] **Step 2: Rewrite the Scope section**

Replace the entire `## Scope` section body (from "Every plot — exploratory..." through "...still require the contract, exports, source data, and QA.") with:

```
This contract applies in full to **publication figures**: manuscript-bound figures
and analytical figures supporting a claim. Every publication figure must:

1. use the `nature-figure` skill
2. use Python exclusively for plotting, previewing, exporting, and visual QA
3. define the complete figure contract before plotting
4. be implemented through importable functions under `src/<package_name>/figures/`
5. have traceable source data
6. pass the complete export and QA contract

**Working plots** — exploratory and diagnostic — are exempt from this contract.
They use Python, obey the determinism and seed rules, record which declared dataset
or artifact they read, and write a single PNG under `results/diagnostics/`. No
`nature-figure` invocation, no `docs/FIGURE_CONTRACT.md` entry, no multi-format
export, no QA checklist. A working plot never silently becomes a publication
figure: promotion goes through this full contract from the pre-plot contract
onward.
```

Then in the following paragraph, replace:

```
Passing bootstrap discovery does not replace task-time invocation of `nature-figure`
for each plotting task. Before writing plotting code, that invocation must succeed.
```

with:

```
Passing bootstrap discovery does not replace task-time invocation of `nature-figure`
for each publication-figure task. Before writing publication plotting code, that
invocation must succeed.
```

The R-prohibition paragraph stays verbatim; it applies to both tiers.

- [ ] **Step 3: Verify**

Run: `grep -c 'Working plots' references/figures.md && make test`
Expected: 1; tests pass.

- [ ] **Step 4: Commit**

```bash
git add references/figures.md
git commit -m "docs: scope figure contract to publication figures"
```

---

### Task 8: references/analysis.md — critique triggers, batching, concurrency

**Files:**
- Modify: `references/analysis.md` (stamp, Independent critique section)

**Interfaces:**
- Consumes: trigger list and batching rule from Task 6, expanded but not contradicted.

- [ ] **Step 1: Bump the stamp**

Replace line 1 `<!-- standard_version: 2026.08.05 -->` with `<!-- standard_version: 2026.08.10 -->`.

- [ ] **Step 2: Rewrite the trigger paragraph**

In `## Independent critique`, replace:

```
When work turns on a scientific judgment — study design, estimand, statistical method,
alternative explanations, the scope of a claim — obtain an independent critique
before deciding or implementing work that depends on the judgment.
```

with:

```
Obtain an independent critique when defining or changing any of: an estimand, a
study design, a statistical method or model choice, inclusion or exclusion rules, a
missing-data policy, a causal interpretation, or the scope of a claim. Obtain it
before deciding or implementing work that depends on the judgment. One critique
covers one design or coherent batch of decisions — do not open a separate critique
per individual judgment, and during bootstrap the single design-stage critique is
that batch. The critique may run concurrently with work that does not depend on the
judgment under review; only dependent work waits for its findings.
```

The remaining paragraphs of the section (independence, advisory status, blocker handling, exemptions) stay verbatim.

- [ ] **Step 3: Verify**

Run: `grep -c 'coherent batch' references/analysis.md && make test`
Expected: 1; tests pass.

- [ ] **Step 4: Commit**

```bash
git add references/analysis.md
git commit -m "docs: enumerate critique triggers in analysis contract"
```

---

### Task 9: references/bootstrap.md — frontmatter fix and standard-check target

**Files:**
- Modify: `references/bootstrap.md` (frontmatter, Makefile skeleton)

**Interfaces:**
- Consumes: `vendor.sh --check` interface from Task 2 (exit 0/1/2).

- [ ] **Step 1: Replace the YAML frontmatter**

Replace lines 1–5:

```
---
name: standard-bootstrap
description: Concrete tool configuration to write when a repository does not yet have it — uv, Ruff, ty, pre-commit, CI guards, Makefile skeleton. Read when creating these files; once they exist they are the source of truth and this document is history.
standard_version: 2026.08.05
---
```

with:

```
<!-- standard_version: 2026.08.10 -->
```

and replace the opening line under the `# Bootstrap: tool configuration` heading:

```
Everything here describes files that do not exist yet. **Once written, those files are
the source of truth** — read `pyproject.toml`, not this document.
```

with:

```
Concrete tool configuration — uv, Ruff, ty, pre-commit, CI guards, Makefile
skeleton — to write when a repository does not yet have it. Everything here
describes files that do not exist yet. **Once written, those files are the source
of truth** — read `pyproject.toml`, not this document.
```

- [ ] **Step 2: Add standard-check to the Makefile skeleton**

In the `## Makefile skeleton` code block, insert after the `verify-full:` line:

```make
standard-check: ## Report drift against the research-repo-standard source
```

Then append after the code block's closing paragraph ("Make may use phony high-level targets..."):

```
`standard-check` calls the standard's own tooling:

```make
STANDARD_SRC ?= $(HOME)/.claude/skills/research-repo-standard

standard-check: ## Report drift against the research-repo-standard source
	@test -x "$(STANDARD_SRC)/vendor.sh" \
	  || { echo "standard source not found at $(STANDARD_SRC); cannot check"; exit 2; }
	"$(STANDARD_SRC)/vendor.sh" --check .
```

It exits 0 when the vendored `AGENTS.md` matches a fresh vendor (the
`## This repository` section is preserved and never counts as drift), 1 when
drifted, 2 when it cannot check.
```

(Nested make block: use a fenced block with four backticks around the outer fence if needed to keep markdown valid.)

- [ ] **Step 3: Verify**

Run: `head -3 references/bootstrap.md && grep -c 'standard-check' references/bootstrap.md && make test`
Expected: first line is the HTML stamp comment; at least 3 matches; tests pass.

- [ ] **Step 4: Commit**

```bash
git add references/bootstrap.md
git commit -m "docs: define standard-check and fix bootstrap frontmatter"
```

---

### Task 10: SKILL.md — description rewrite and deduplication

**Files:**
- Modify: `SKILL.md` (frontmatter description, stamp, Required agent skills section)

**Interfaces:**
- Consumes: gate terms from Task 4; AGENTS.md is now the sole owner of gate and configuration semantics.

- [ ] **Step 1: Replace the frontmatter description**

Replace the `description:` value in the SKILL.md frontmatter with:

```
description: The operating standard for reproducible research repositories supporting a scientific analysis, study, or paper. Use when bootstrapping such a repository, and before any file-changing work in a repository that vendors this standard's AGENTS.md — it governs modification gates, configuration and data ownership, analysis planning and independent critique, publication figures, vendoring, and drift checks.
```

- [ ] **Step 2: Bump the stamp**

Replace `<!-- standard_version: 2026.08.05 -->` with `<!-- standard_version: 2026.08.10 -->`.

- [ ] **Step 3: Deduplicate the gate and configuration restatements**

In `## Required agent skills`, replace the two paragraphs beginning "In governance mode, each user-requested modification..." (SKILL.md:46–56) and "For configuration work, read `references/configuration.md`..." (SKILL.md:62–66) as follows.

Replace:

```
In governance mode, each user-requested modification that creates, edits, moves, or
deletes files opens one active `superpowers:brainstorming` gate. After design
approval, its specification, plan, and approval-record artifacts may be created under
the active gate, but the requested implementation files remain blocked. The gate
completes only when the specification is committed and user-reviewed and the
implementation plan is ready. Direct or delegated implementation inherits that
completed gate and does not open a nested cycle. If the requested scope expands,
reopen the same gate at design before implementing the new scope. Executing an
already approved workflow solely to regenerate its declared outputs does not open a
new gate; changing code, configuration, or contracts does. Read-only explanation,
inspection, diagnosis, and status reporting are not modifications.
```

with:

```
In governance mode, `AGENTS.md` owns the modification-gate rules — the full gate,
the light path, and the no-gate exemptions. It is already in context in a governed
repository; apply it rather than a restatement.
```

Replace:

```
For configuration work, read `references/configuration.md`. Stable scientific and
result-affecting settings belong in `config/analysis.yaml`; only documented
result-equivalent operations belong in optional `config/runtime.yaml`. `config.py`
validates and passes typed values, while `paths.py` derives repository paths.
```

with:

```
For configuration work, `AGENTS.md` owns the ownership rules; read
`references/configuration.md` for the full contract.
```

- [ ] **Step 4: Verify**

Run: `wc -w SKILL.md && grep -c 'full gate' SKILL.md && make test`
Expected: word count noticeably below the current ~1200; at least 1 pointer mention; tests pass. Confirm no paragraph in SKILL.md still restates gate completion conditions.

- [ ] **Step 5: Commit**

```bash
git add SKILL.md
git commit -m "refactor: dedupe SKILL.md to pointers and tighten description"
```

---

### Task 11: README.md — trim restated rules

**Files:**
- Modify: `README.md` (stamp, Configuration source of truth section, Versioning section)

**Interfaces:**
- Consumes: `standard-check` now real (Task 2/9); AGENTS.md ownership (Task 10).

- [ ] **Step 1: Bump the stamp**

Replace line 1 `<!-- standard_version: 2026.08.05 -->` with `<!-- standard_version: 2026.08.10 -->`.

- [ ] **Step 2: Trim the configuration section**

Replace:

```
Stable scientific and result-affecting settings live in `config/analysis.yaml`.
Optional `config/runtime.yaml` contains only operational settings demonstrated to be
result-equivalent. `config.py` validates and consumes configuration; `paths.py` derives
repository paths. See
[`references/configuration.md`](references/configuration.md) for ownership, override,
provenance, and migration rules.
```

with:

```
`AGENTS.md` owns the configuration ownership rules;
[`references/configuration.md`](references/configuration.md) holds the full
contract — ownership, overrides, provenance, and migration.
```

- [ ] **Step 3: Note the real standard-check in Versioning**

In `## Versioning`, replace:

```
Every file carries `standard_version`. Vendored copies keep the version they were
vendored at; `make standard-check` in a governed repository reports drift against this
source without resolving it — a project may legitimately refine the standard for its
own science.
```

with:

```
Every file carries `standard_version`. Vendored copies keep the version they were
vendored at; `make standard-check` in a governed repository (backed by
`vendor.sh --check`) reports drift against this source without resolving it — a
project may legitimately refine the standard for its own science.
```

- [ ] **Step 4: Full verification pass**

Run: `make test && ./vendor.sh --check . 2>&1 | head -2; git status --short`
Expected: tests pass. (`--check .` against this source repo itself will report clean or exit 2 — either is acceptable; the command is a smoke test that the flag parses.) `git status` shows only intended files.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: trim README restatements and reference real standard-check"
```
