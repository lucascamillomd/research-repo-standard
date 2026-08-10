# Skill-Creator Fork and Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the official skill-creator plugin skill into `forks/skill-creator/` verbatim, then apply nine approved review fixes to its `SKILL.md` in four attributable commits.

**Architecture:** Baseline-then-surgical-edits. Commit 1 of this plan imports the skill unchanged so every later diff shows exactly what diverged from upstream. Four edit commits follow, one per finding group from the spec (`docs/superpowers/specs/2026-08-10-skill-creator-fork-design.md`). Only `forks/skill-creator/SKILL.md` is ever edited; all other fork files stay verbatim.

**Tech Stack:** Markdown, bash, git. No Python code is written or modified.

## Global Constraints

- Branch: `skill-creator-fork` (already created; spec already committed).
- Source: `~/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator/`.
- Exclude from import: `__pycache__/`, `.remember/`, `.in_use/`.
- Only `forks/skill-creator/SKILL.md` may differ from upstream after all tasks.
- Line numbers cited below refer to the baseline SKILL.md (486 lines) as imported in Task 1.
- The repo's code-simplifier pass is exempt (documentation-only change, per AGENTS.md).

---

### Task 1: Baseline import

**Files:**
- Create: `forks/README.md`
- Create: `forks/skill-creator/**` (verbatim copy)

**Interfaces:**
- Produces: the baseline `forks/skill-creator/SKILL.md` that Tasks 2–5 edit.

- [ ] **Step 1: Copy the skill**

```bash
cd /Users/lucascamillo/research-repo-standard
mkdir -p forks
rsync -a --exclude='__pycache__' --exclude='.remember' --exclude='.in_use' \
  "$HOME/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator/" \
  forks/skill-creator/
```

- [ ] **Step 2: Verify the copy is complete and clean**

```bash
diff -rq "$HOME/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator/" forks/skill-creator/ | grep -v '__pycache__\|.remember'
find forks/skill-creator -name '__pycache__' -o -name '.remember' -o -name '.in_use'
```

Expected: diff reports only the excluded directories as "Only in" the source; find returns nothing.

- [ ] **Step 3: Write `forks/README.md`**

```markdown
# Forked third-party skills

Local forks of externally maintained skills. Each fork records its provenance here;
revisions sit on top of a verbatim baseline import, so `git log -- forks/<name>/`
shows exactly what diverged from upstream.

## skill-creator

- **Source:** `~/.claude/plugins/cache/claude-plugins-official/skill-creator/`
  (official Anthropic plugin marketplace; the cache does not label a version — its
  directory is literally named `unknown`).
- **Imported:** 2026-08-10, verbatim except caches and runtime bookkeeping
  (`__pycache__/`, `.remember/`, `.in_use/`).
- **Why forked:** the plugin cache is not a git repository and is overwritten on
  plugin update. This fork carries nine review fixes; see
  `docs/superpowers/specs/2026-08-10-skill-creator-fork-design.md` for findings and
  rationale.
- **Changes on top of baseline** (all in `SKILL.md`): unified `expectations`
  terminology with `references/schemas.md`; viewer PID persisted to a file (shell
  state does not survive between agent commands); packaging made consistently
  conditional on `present_files`; `quick_validate.py` wired in before packaging;
  body trimmed and deduplicated; product-named platform sections replaced by
  capability-keyed adaptations; description guidance bounded against
  workflow-summarizing; timing capture given a fallback; added "when a skill is the
  wrong vehicle" guidance.
```

- [ ] **Step 4: Commit**

```bash
git add forks/
git commit -m "feat: import skill-creator baseline into forks/"
```

---

### Task 2: Correctness bugs (spec findings 1–2)

**Files:**
- Modify: `forks/skill-creator/SKILL.md`

**Interfaces:**
- Consumes: baseline SKILL.md from Task 1.

- [ ] **Step 1: Unify `assertions` → `expectations` (finding 1)**

Replace every field-name and prose use of assertion/assertions with
expectation/expectations. Specific occurrences in the baseline:

- L39 (jargon example): `for "JSON" and "assertion" you want to see serious cues` → `for "JSON" and "expectations" you want to see serious cues`
- L145: `Don't write assertions yet — just the prompts. You'll draft assertions in the next step` → `Don't write expectations yet — just the prompts. You'll draft expectations in the next step`
- L161: `(including the `assertions` field, which you'll add later)` → `(including the `expectations` field, which you'll add later)`
- L188: `(assertions can be empty for now)` → `(expectations can be empty for now)`
- L195 (JSON example): `"assertions": []` → `"expectations": []`
- L199 heading: `Step 2: While runs are in progress, draft assertions` → `draft expectations`
- L201: `Draft quantitative assertions for each test case` → `expectations`; `If assertions already exist` → `If expectations already exist`
- L203: `Good assertions are objectively verifiable` → `Good expectations are`; `don't force assertions onto things` → `don't force expectations onto things`
- L205: `Update the ... files ... with the assertions once drafted` → `with the expectations once drafted`
- L225: `evaluates each assertion against the outputs` → `each expectation`; `For assertions that can be checked programmatically` → `For expectations that`
- L234: `assertions that always pass regardless of skill` → `expectations that always pass regardless of skill`
- L259: `collapsed section showing assertion pass/fail` → `showing expectation pass/fail`

- [ ] **Step 2: Verify zero occurrences remain**

```bash
grep -in 'assertion' forks/skill-creator/SKILL.md
```

Expected: no output.

- [ ] **Step 3: Persist the viewer PID to a file (finding 2)**

In the Step-4 viewer launch block (L238–244), replace `VIEWER_PID=$!` with a line
writing the PID to the workspace:

```bash
nohup python <skill-creator-path>/eval-viewer/generate_review.py \
  <workspace>/iteration-N \
  --skill-name "my-skill" \
  --benchmark <workspace>/iteration-N/benchmark.json \
  > /dev/null 2>&1 &
echo $! > <workspace>/viewer.pid
```

In the Step-5 cleanup (L284–288), replace

```bash
kill $VIEWER_PID 2>/dev/null
```

with

```bash
kill "$(cat <workspace>/viewer.pid)" 2>/dev/null
```

and change the preceding sentence to: "Kill the viewer server when you're done with
it — read the PID from the file, since shell variables don't survive between
commands:"

- [ ] **Step 4: Verify no `VIEWER_PID` remains**

```bash
grep -n 'VIEWER_PID' forks/skill-creator/SKILL.md
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add forks/skill-creator/SKILL.md
git commit -m "fix: unify expectations terminology; persist viewer PID to file"
```

---

### Task 3: Consistency fixes (spec findings 3–4)

**Files:**
- Modify: `forks/skill-creator/SKILL.md`

**Interfaces:**
- Consumes: SKILL.md as left by Task 2.
- Produces: a "Validate, Package, and Present" section that Task 4's condensed recap refers to.

- [ ] **Step 1: Wire in quick_validate.py and keep packaging conditional (finding 4)**

Replace the whole "Package and Present (only if `present_files` tool is available)"
section (baseline L408–416) with:

````markdown
### Validate, Package, and Present

Before packaging, validate the skill's structure and frontmatter:

```bash
python <skill-creator-path>/scripts/quick_validate.py <path/to/skill-folder>
```

Fix anything it reports before proceeding.

Then check whether you have access to the `present_files` tool. If you don't, skip
packaging — the skill directory itself is the deliverable. If you do, package the
skill and present the `.skill` file to the user:

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

After packaging, direct the user to the resulting `.skill` file path so they can
install it.
````

- [ ] **Step 2: Fix the contradictory closing recap line (finding 3)**

Baseline L481: `- Package the final skill and return it to the user.` →
`- Validate the skill; if the `present_files` tool is available, package it and return the .skill file.`

(Task 4 later condenses the whole recap; this keeps the intermediate commit
self-consistent.)

- [ ] **Step 3: Verify**

```bash
grep -n 'quick_validate' forks/skill-creator/SKILL.md
grep -n 'Package the final skill and return' forks/skill-creator/SKILL.md
```

Expected: first grep shows the new validation step; second shows nothing.

- [ ] **Step 4: Commit**

```bash
git add forks/skill-creator/SKILL.md
git commit -m "fix: validate before packaging; make recap packaging conditional"
```

---

### Task 4: Structural rewrite (spec findings 5–6)

**Files:**
- Modify: `forks/skill-creator/SKILL.md`

**Interfaces:**
- Consumes: SKILL.md as left by Task 3 (including its "Validate, Package, and Present" section).

- [ ] **Step 1: Record the before size**

```bash
wc -l -w forks/skill-creator/SKILL.md
```

- [ ] **Step 2: Trim filler and tone (finding 5)**

- Delete L30 `Cool? Cool.` (and its blank line).
- Replace the first paragraph of "Communicating with the user" (L34, the
  plumbers/grandparents anecdote) with: "The skill creator is used by people across
  a wide range of technical backgrounds — from experienced developers to people who
  have never opened a terminal. Pay attention to context cues to calibrate your
  language. In the default case, just to give you some idea:" (delete the old L34
  and fold this into L36 so there is one intro sentence, then the existing
  bullets).
- L306: delete the parenthetical `(we are trying to create billions a year in
  economic value here!)` so the sentence reads "This task is pretty important and
  your thinking time is not the blocker; take your time and really mull things
  over."
- Delete the closing `Good luck!` line (L485).

- [ ] **Step 3: Replace the two platform sections with capability-keyed adaptations (finding 6)**

Delete both "Claude.ai-specific instructions" (L420–441) and "Cowork-Specific
Instructions" (L445–456), including their `---` separator, and insert in their
place:

```markdown
## Adapting to your environment

The core loop (draft → test → review → improve → repeat) is the same everywhere.
What changes is which mechanics are available — check capabilities, not product
names:

**No subagents** (e.g., Claude.ai): run each test case yourself, serially — read
the skill's SKILL.md and follow its instructions to complete the test prompt. This
is less rigorous than independent subagents (you wrote the skill and you have full
context), but the human review step compensates. Skip baseline runs, quantitative
benchmarking (baseline comparisons aren't meaningful without independent runs), and
blind comparison. If subagents exist but parallel runs hit timeouts, fall back to
running them in series.

**No display or browser** (e.g., Cowork, remote servers, headless VMs): generate
the viewer with `--static <output_path>` to write a standalone HTML file instead of
starting a server, and give the user a link or path they can open. The "Submit All
Reviews" button then downloads `feedback.json` instead of saving it server-side —
ask the user to put it where you can read it (you may need to request file access),
and copy it into the workspace for the next iteration. If even static HTML can't
reach the user, present each prompt and output directly in conversation and collect
feedback inline.

**No `claude` CLI**: description optimization (`run_loop.py` / `run_eval.py`)
invokes `claude -p` and can't run. Skip it and tell the user why.

**Read-only skill install path** (common when updating an installed skill): copy
the skill to a writable location first, edit the copy, and package from it.
Preserve the original directory name and `name` frontmatter — if the installed
skill is `research-helper`, output `research-helper.skill`, not
`research-helper-v2`.

Packaging (`package_skill.py`) needs only Python and a filesystem — it works in
every environment.

One ordering rule that holds everywhere: after test runs finish, get the results in
front of the user (viewer or inline) *before* judging the outputs and revising the
skill yourself. Your own read of the outputs is not a substitute for theirs.
```

- [ ] **Step 4: Condense the closing recap (finding 5)**

Replace the block from `Repeating one more time the core loop here for emphasis:`
through the todo-list paragraph (baseline L472–483, as modified by Task 3) with:

```markdown
Add the core steps to your todo list so none get skipped: draft or edit the skill,
run test cases (with baselines where available), generate the eval viewer for the
user to review, read their feedback, improve, and repeat until you're both
satisfied. Then validate the skill; if the `present_files` tool is available,
package it and return the `.skill` file.
```

- [ ] **Step 5: Verify size reduction and remaining structure**

```bash
wc -l -w forks/skill-creator/SKILL.md
grep -n '^## ' forks/skill-creator/SKILL.md
grep -in 'cowork\|claude\.ai' forks/skill-creator/SKILL.md
```

Expected: meaningful reduction from Step 1 (spec target: roughly 30–40% fewer body
words; the hard requirement is well under 500 lines). Product names appear only as
parenthetical examples inside "Adapting to your environment", not as section
headings.

- [ ] **Step 6: Commit**

```bash
git add forks/skill-creator/SKILL.md
git commit -m "refactor: trim filler, dedupe core loop, capability-keyed platform guidance"
```

---

### Task 5: Guidance additions (spec findings 7–9)

**Files:**
- Modify: `forks/skill-creator/SKILL.md`

**Interfaces:**
- Consumes: SKILL.md as left by Task 4.

- [ ] **Step 1: Bound the description advice (finding 7)**

In the `**description**` bullet of "Write the SKILL.md" (baseline L67), keep the
existing content and dashboard example, and append:

```markdown
One boundary: never summarize the skill's internal workflow step-by-step in the
description. A description that narrates the process invites the model to follow
the summary instead of reading the skill body — and the body is where the real
instructions live. Be pushy about *when*, not about *how*.
```

- [ ] **Step 2: Add the timing fallback (finding 8)**

At the end of "Step 3: As runs complete, capture timing data" (after baseline
L219), append to the closing paragraph: "If a notification is missed, or the runs
happened inline without notifications, don't stall: write `null` for the missing
fields and move on. Timing data is informative, not gating."

- [ ] **Step 3: Add "When a skill is the wrong vehicle" (finding 9)**

Insert a new subsection immediately before "### Capture Intent" (baseline L47):

```markdown
### When a skill is the wrong vehicle

Not every repeated instruction should become a skill. Steer the user elsewhere
when:

- **It's a one-off task.** Just do the task — a skill pays off through reuse.
- **It's a project-specific convention** (naming rules, review process, directory
  layout): that belongs in the project's CLAUDE.md / AGENTS.md, which is always in
  context without triggering.
- **It's an automated behavior** ("every time I save, run X"): that needs hooks or
  harness settings, which execute deterministically — a skill only advises.

If one of these fits, say so and help with the better mechanism instead.
```

- [ ] **Step 4: Verify**

```bash
grep -n 'wrong vehicle\|informative, not gating\|Be pushy about' forks/skill-creator/SKILL.md
```

Expected: all three additions present.

- [ ] **Step 5: Commit**

```bash
git add forks/skill-creator/SKILL.md
git commit -m "feat: description boundary, timing fallback, wrong-vehicle guidance"
```

---

### Task 6: Verification pass

**Files:**
- None modified (read-only checks).

- [ ] **Step 1: Referenced paths resolve**

Every file path SKILL.md mentions must exist in the fork:

```bash
cd /Users/lucascamillo/research-repo-standard/forks/skill-creator
for p in agents/grader.md agents/comparator.md agents/analyzer.md \
         references/schemas.md assets/eval_review.html \
         eval-viewer/generate_review.py scripts/package_skill.py \
         scripts/quick_validate.py scripts/run_loop.py scripts/run_eval.py \
         scripts/aggregate_benchmark.py; do
  [ -f "$p" ] || echo "MISSING: $p"
done
```

Expected: no output.

- [ ] **Step 2: Terminology and consistency greps**

```bash
grep -in 'assertion\|VIEWER_PID' forks/skill-creator/SKILL.md
grep -c '' forks/skill-creator/SKILL.md
```

Expected: first grep empty; line count well under 500.

- [ ] **Step 3: Repo suite still passes**

```bash
cd /Users/lucascamillo/research-repo-standard && make test
```

Expected: all tests pass, unchanged from main.

- [ ] **Step 4: Clean status and history shape**

```bash
git status --short
git log --oneline main..skill-creator-fork
```

Expected: clean tree; six commits (spec, baseline, and the four edit commits).
