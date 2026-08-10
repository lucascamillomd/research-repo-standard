# Simplifier Pass and Figure Revert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revert the two-tier figure contract so every plot uses the full `nature-figure` workflow, and add a mandatory code-simplifier subagent pass (profile shipped with the standard) after code-changing modifications.

**Architecture:** Documentation-first skill repo. One new file (`agents/code-simplifier.md`, the canonical adapted profile), surgical text reverts across AGENTS.md / SKILL.md / references, a new Working-procedure rule, a bootstrap scaffold step, and a one-glob test extension.

**Tech Stack:** markdown, bash (tests/vendor_test.sh), GNU make.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-10-simplifier-and-figure-revert-design.md`. Follow exactly.
- Version stamps on touched files REMAIN `standard_version: 2026.08.10` (no bump — same-day iteration; spec's stamp rationale).
- The tiered modification gate, critique triggers, standard-check, and vendor.sh are NOT touched.
- The floor rules in AGENTS.md are not weakened.
- ~88-column wrapped prose style preserved in every edited file.
- After the figure revert (Tasks 2–3): `grep -rn "working plot\|publication figure\|results/diagnostics" AGENTS.md SKILL.md README.md references/` returns zero.
- Commit after every task with the message given in that task.

---

### Task 1: Canonical code-simplifier profile + stamp-test glob + README layout

**Files:**
- Create: `agents/code-simplifier.md`
- Modify: `tests/vendor_test.sh` (stamp-check glob)
- Modify: `README.md` (layout block)

**Interfaces:**
- Produces: the path `agents/code-simplifier.md` and the governed-repo path `.claude/agents/code-simplifier.md` — Task 4's Working-procedure rule and bootstrap step reference both verbatim.

- [ ] **Step 1: Extend the stamp-check glob (failing test first)**

In `tests/vendor_test.sh`, replace:

```bash
for f in "$ROOT"/AGENTS.md "$ROOT"/SKILL.md "$ROOT"/README.md "$ROOT"/references/*.md; do
```

with:

```bash
for f in "$ROOT"/AGENTS.md "$ROOT"/SKILL.md "$ROOT"/README.md "$ROOT"/references/*.md "$ROOT"/agents/*.md; do
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — `agents/` does not exist, the glob stays literal, `head` errors, and the check reports `missing standard_version stamp: agents/*.md`. Exit 1.

- [ ] **Step 3: Create `agents/code-simplifier.md`**

Exact content (note field order: the stamp must be line 4, inside the test's `head -5` window):

```markdown
---
name: code-simplifier
description: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.
standard_version: 2026.08.10
model: opus
---

You are an expert code simplification specialist focused on enhancing code
clarity, consistency, and maintainability while preserving exact
functionality. Your expertise lies in applying this repository's standard to
simplify and improve code without altering its behavior. You prioritize
readable, explicit code over overly compact solutions. This is a balance you
have mastered over years as an expert software engineer.

You will analyze recently modified code and apply refinements that:

1. **Preserve Functionality**: Never change what the code does — only how it
   does it. All original features, outputs, and behaviors must remain
   intact. Scientific outputs, estimands, seeds, file contracts, and
   provenance are untouchable.

2. **Apply Project Standards**: Follow the repository standard (`AGENTS.md`)
   and its working files:

   - `pyproject.toml` and `.pre-commit-config.yaml` are the style
     authorities: Ruff formatting and lint rules, ty type checking.
   - Public functions and classes in `src/` keep typed interfaces and
     Google-style docstrings covering scientific meaning, units, ranges,
     array shapes, row grain, missing-value behaviour, and failure
     conditions.
   - Scripts orchestrate; logic worth testing lives in `src/` and is
     imported. A stage script never imports another stage script.
   - Configuration ownership is respected: no new module-level settings, no
     hidden result-affecting defaults; values flow through validated typed
     configuration passed explicitly.
   - The floor rules of `AGENTS.md` — raw-data immutability above all — are
     never compromised by a refactor.
   - Test names describe behaviour.

3. **Enhance Clarity**: Simplify code structure by:

   - Reducing unnecessary complexity and nesting
   - Eliminating redundant code and abstractions
   - Improving readability through clear variable and function names
   - Consolidating related logic
   - Removing unnecessary comments that describe obvious code
   - IMPORTANT: Prefer explicit constructs over dense comprehensions,
     chained one-liners, or clever operator tricks — use plain loops and
     if/else chains when they read better
   - Choose clarity over brevity — explicit code is often better than overly
     compact code

4. **Maintain Balance**: Avoid over-simplification that could:

   - Reduce code clarity or maintainability
   - Create overly clever solutions that are hard to understand
   - Combine too many concerns into single functions
   - Remove helpful abstractions that improve code organization
   - Prioritize "fewer lines" over readability (e.g., nested conditional
     expressions, dense one-liners)
   - Make the code harder to debug or extend

5. **Focus Scope**: Only refine code that has been recently modified or
   touched in the current session, unless explicitly instructed to review a
   broader scope.

Your refinement process:

1. Identify the recently modified code sections
2. Analyze for opportunities to improve elegance and consistency
3. Apply the repository standard and its style authorities
4. Ensure all functionality remains unchanged
5. Verify the refined code is simpler and more maintainable
6. Document only significant changes that affect understanding

After refining, re-run the tests covering the amended code; your edits are
not complete until they pass. You operate autonomously and proactively,
refining code immediately after it is written or modified without requiring
explicit requests. Your goal is to ensure all code meets the highest
standards of elegance and maintainability while preserving its complete
functionality.
```

- [ ] **Step 4: Add `agents/` to the README layout block**

In `README.md`, replace:

```
  figures.md           figure contract, exports, QA checklist
vendor.sh              copy AGENTS.md into a target repository
```

with:

```
  figures.md           figure contract, exports, QA checklist
agents/
  code-simplifier.md   post-change simplification subagent profile (canonical copy)
vendor.sh              copy AGENTS.md into a target repository
```

- [ ] **Step 5: Run to verify all pass**

Run: `make test`
Expected: 14 assertions pass (the stamp check covers the new file; assertion count is unchanged because the stamp test is one aggregate assertion). Exit 0.

- [ ] **Step 6: Commit**

```bash
git add agents/code-simplifier.md tests/vendor_test.sh README.md
git commit -m "feat: ship canonical code-simplifier profile"
```

---

### Task 2: Figure revert — AGENTS.md and SKILL.md

**Files:**
- Modify: `AGENTS.md` (principle 8, layout ×2, Figures section, full-gate trigger word)
- Modify: `SKILL.md` (governed-work sentence)

**Interfaces:**
- Produces: the restored universal figure language; Task 3 makes references/ consistent with it.

- [ ] **Step 1: Revert core principle 8**

In `AGENTS.md`, replace:

```
8. Every plot uses Python; publication figures use the full `nature-figure` workflow.
```

with:

```
8. Every plot uses Python and the full `nature-figure` workflow.
```

- [ ] **Step 2: Remove diagnostics from the layout**

Replace:

```
├── results/
│   ├── diagnostics/                # working plots (PNG), never publication artifacts
│   ├── figures/<figure_id>/{svg,pdf,tiff,png}/
```

with:

```
├── results/
│   ├── figures/<figure_id>/{svg,pdf,tiff,png}/
```

- [ ] **Step 3: Revert the FIGURE_CONTRACT layout comment**

Replace:

```
│   ├── FIGURE_CONTRACT.md          # contract and QA record for every publication figure
```

with:

```
│   ├── FIGURE_CONTRACT.md          # contract and QA record for every plot
```

- [ ] **Step 4: Revert the Figures section to the single universal paragraph**

Replace the two paragraphs:

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

with:

```
Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound
— uses the `nature-figure` skill, is written in Python, is implemented as importable
functions under `src/<package_name>/figures/`, has traceable source data, and exports
all four formats: editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each format
lives in its own extension-named directory under `results/figures/<figure_id>/`.
```

Then in the next paragraph, replace:

```
For publication figures, record the contract in `docs/FIGURE_CONTRACT.md` **before**
writing plotting code.
```

with:

```
Record the contract in `docs/FIGURE_CONTRACT.md` **before** writing plotting code.
```

- [ ] **Step 5: Revert the full-gate trigger word**

In the **Full gate** paragraph of the modification-gates section, replace the phrase `pipeline structure, publication figures, new analyses` with `pipeline structure, figures, new analyses` (it occurs exactly once).

- [ ] **Step 6: Revert SKILL.md's governed-work sentence**

In `SKILL.md`, replace:

```
During governed work, obtain the independent `scientific-critical-thinking`
critique when a trigger in the analysis contract applies, and follow the figure
contract's two tiers for plots.
```

with:

```
During governed work, obtain the independent `scientific-critical-thinking`
critique when a trigger in the analysis contract applies, and invoke
`nature-figure` for every plot under the figure contract.
```

- [ ] **Step 7: Verify**

Run: `grep -c 'Every plot — exploratory' AGENTS.md && grep -rn 'working plot\|results/diagnostics' AGENTS.md SKILL.md | wc -l && make test`
Expected: 1, 0, tests pass.

- [ ] **Step 8: Commit**

```bash
git add AGENTS.md SKILL.md
git commit -m "revert: universal nature-figure contract for every plot"
```

---

### Task 3: Figure revert — references/figures.md and references/prerequisites.md

**Files:**
- Modify: `references/figures.md` (Scope section, invocation sentences)
- Modify: `references/prerequisites.md` (nature-figure role cell)

**Interfaces:**
- Consumes: the restored universal language from Task 2; wording must match it.

- [ ] **Step 1: Restore the Scope section**

In `references/figures.md`, replace:

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

with:

```
Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound —
must:

1. use the `nature-figure` skill
2. use Python exclusively for plotting, previewing, exporting, and visual QA
3. define the complete figure contract before plotting
4. be implemented through importable functions under `src/<package_name>/figures/`
5. have traceable source data
6. pass the complete export and QA contract

Exploratory and diagnostic plots are not exempt. Their scientific role may be
"diagnostic" or "exploratory," but they still require the contract, exports, source
data, and QA.
```

- [ ] **Step 2: Restore the task-time invocation sentences (and rewrap)**

Replace:

```
Passing bootstrap discovery does not replace task-time invocation of `nature-figure`
for each publication-figure task. Before writing publication plotting code, that
invocation must succeed. If
```

with:

```
Passing bootstrap discovery does not replace task-time invocation of `nature-figure`
for each plotting task. Before writing plotting code, that invocation must succeed. If
```

- [ ] **Step 3: Restore the prerequisites role cell**

In `references/prerequisites.md`, replace:

```
Figure strategy during bootstrap and the full workflow for every publication figure
```

with:

```
Figure strategy during bootstrap and the full workflow for every plot
```

- [ ] **Step 4: Run the full sweep**

Run: `grep -rn "working plot\|publication figure\|results/diagnostics" AGENTS.md SKILL.md README.md references/ | wc -l && make test`
Expected: 0 and tests pass. (Hits in `docs/superpowers/` and `agents/` are out of sweep scope — the spec scopes the sweep to the contract files listed.)

- [ ] **Step 5: Commit**

```bash
git add references/figures.md references/prerequisites.md
git commit -m "revert: figure references cover every plot again"
```

---

### Task 4: Simplifier workflow rule + bootstrap scaffold step

**Files:**
- Modify: `AGENTS.md` (Working procedure)
- Modify: `references/bootstrap.md` (new section before `## README`)

**Interfaces:**
- Consumes: `agents/code-simplifier.md` and `.claude/agents/code-simplifier.md` paths from Task 1, verbatim.

- [ ] **Step 1: Insert the Working-procedure rule**

In `AGENTS.md`'s Working procedure section, after the paragraph beginning "While implementing:" and before the paragraph beginning "Before declaring completion:", insert this new paragraph:

```
When a modification changed code under `src/`, `scripts/`, or `tests/`, run a
code-simplifier subagent over the changed code before declaring completion. It
applies the profile at `.claude/agents/code-simplifier.md` — canonical copy in the
`research-repo-standard` skill's `agents/` directory, or
<https://github.com/lucascamillomd/research-repo-standard/blob/main/agents/code-simplifier.md>
when the local file is absent — preserves behavior exactly, and its edits are
verified by re-running the covering tests. The simplifier's own edits do not
trigger another pass. Documentation- and configuration-only changes are exempt.
```

- [ ] **Step 2: Add the bootstrap scaffold section**

In `references/bootstrap.md`, insert immediately before the `## README` heading:

```
## Code-simplifier profile

Create `.claude/agents/code-simplifier.md` in the new repository by copying the
canonical profile from the standard's `agents/code-simplifier.md`. The Working
procedure in `AGENTS.md` requires a code-simplifier subagent pass after
code-changing modifications; the copied profile is what that subagent applies.

```

(Keep one blank line between this section's last line and `## README`.)

- [ ] **Step 3: Verify**

Run: `grep -c 'code-simplifier' AGENTS.md references/bootstrap.md && make test`
Expected: at least 2 in AGENTS.md's count line and at least 2 for bootstrap.md; tests pass.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md references/bootstrap.md
git commit -m "feat: mandatory code-simplifier pass after code changes"
```
