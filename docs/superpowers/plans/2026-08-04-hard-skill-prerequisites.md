# Hard Skill Prerequisites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure` enforceable hard prerequisites during research-repository bootstrap and governed-repository modifications.

**Architecture:** Put detailed installation and verification guidance in one new prerequisite reference, then enforce that contract through the skill entry point and the vendored `AGENTS.md`. Align the bootstrap, analysis, and figure references with the hard-gate semantics, validate the skill metadata and vendoring behavior, and use an isolated agent scenario plus Claude review to check the instruction-level behavior.

**Tech Stack:** Markdown Agent Skills, `AGENTS.md`, Bash vendoring checks, Git, skill-creator validation, Claude Code review

---

## File map

- Create `references/prerequisites.md`: canonical installation, discovery, invocation,
  failure, and resumption contract for the three required skills.
- Modify `README.md`: advertise the hard prerequisites and point to the canonical
  reference without duplicating its full instructions.
- Modify `SKILL.md`: add the preflight and bootstrap workflow, govern all file-changing
  requests, and move `standard_version` out of YAML frontmatter so skill validation
  passes.
- Modify `AGENTS.md`: vendor the hard gate and ongoing brainstorming requirement into
  every governed repository.
- Modify `references/bootstrap.md`: make the single agent-skill preflight precede
  Python/tool setup and require generated READMEs to disclose it.
- Modify `references/analysis.md`: replace the scientific-critique soft fallback with
  a blocker.
- Modify `references/figures.md`: make an unavailable `nature-figure` skill an explicit
  blocker while retaining Python as the only plotting backend.

No executable project code or new test framework is needed. Contract checks use exact
text assertions, the existing skill validator, `vendor.sh`, and isolated agent review.

### Task 1: Add the canonical prerequisite contract

**Files:**
- Create: `references/prerequisites.md`
- Modify: `README.md:1-46`

- [ ] **Step 1: Run the pre-change contract assertion**

Run:

```bash
test -f references/prerequisites.md \
  && rg -q 'superpowers:brainstorming' references/prerequisites.md \
  && rg -q 'scientific-critical-thinking' references/prerequisites.md \
  && rg -q 'nature-figure' references/prerequisites.md
```

Expected: exit status `1` because `references/prerequisites.md` does not exist.

- [ ] **Step 2: Create the canonical reference**

Create `references/prerequisites.md` with this complete content:

````markdown
<!-- standard_version: 2026.08.04 -->

# Reference: required agent skills

Read before bootstrapping a research repository and whenever a governed repository
reports a missing prerequisite. These are agent-environment dependencies, not Python
packages and not project data.

## Hard gate

The following skills must be installed and discoverable before the bootstrap interview
or any file-changing work in a governed repository:

| Skill | Authoritative source | Required role |
|---|---|---|
| `superpowers:brainstorming` | <https://github.com/obra/superpowers> | Design and approval before every modification |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> | Independent critique during bootstrap and later scientific judgments |
| `nature-figure` | <https://github.com/Yuan1z0825/nature-skills> | Figure strategy during bootstrap and the full workflow for every plot |

Use the agent host's native skill listing or resolver as the lightweight discovery
check. It must return each exact skill name. A directory or `SKILL.md` file alone does
not prove the host can resolve the skill. Successful invocation during the required
workflow is the functional verification.

Do not install these skills silently or modify global agent configuration without the
user's authorization. If a skill is missing, stop before repository mutations.

## Codex installation

Install Superpowers from the Codex plugin marketplace: open **Plugins** in the Codex
app, or `/plugins` in Codex CLI, search for **Superpowers**, and install it.

Install the two scientific skills globally with the open Agent Skills installer:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent codex --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent codex --skill nature-figure --yes --copy
```

## Claude Code installation

Install Superpowers from Anthropic's official plugin marketplace:

```text
/plugin install superpowers@claude-plugins-official
```

Install the two scientific skills globally:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent claude-code --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent claude-code --skill nature-figure --yes --copy
```

For other agent hosts, follow the installation instructions in each authoritative
source and install only the required skill folders. Review third-party skill contents
and provenance before installation.

## Verify and resume

1. Restart or reload the agent session as directed by the host.
2. Use the host-native skill listing or resolver to confirm all three exact names.
3. Resume bootstrap from its single preflight step. Do not repeat completed design work
   when only the agent session changed.
4. Treat the first required invocation of each skill as functional verification.

If discovery or invocation still fails, report the exact missing name and host, then
stop. Do not substitute generic brainstorming, informal self-critique, or a plotting
workflow that does not use `nature-figure`.
````

- [ ] **Step 3: Update the README layout and prerequisite summary**

Add this version marker before the README title:

```markdown
<!-- standard_version: 2026.08.04 -->
```

Add this entry inside the existing `references/` layout block after `bootstrap.md`:

```text
  prerequisites.md     required agent skills, installation, verification
```

Insert this section before `## Install as a Claude skill`:

```markdown
## Hard prerequisites

Repository bootstrap and later governed modifications require these discoverable agent
skills:

- `superpowers:brainstorming`
- `scientific-critical-thinking`
- `nature-figure`

Bootstrap actively uses all three. Missing prerequisites stop work before repository
changes; they are not installed by uv or `make setup`. See
[`references/prerequisites.md`](references/prerequisites.md) for authoritative sources,
host-specific installation, verification, and resumption.
```

- [ ] **Step 4: Verify the canonical contract**

Run:

```bash
test -f references/prerequisites.md
rg -n 'superpowers:brainstorming|scientific-critical-thinking|nature-figure' references/prerequisites.md README.md
rg -n 'Do not install these skills silently|stop before repository mutations' references/prerequisites.md
```

Expected: all commands exit `0`; the three names appear in both files and the hard-stop
language appears in the canonical reference.

- [ ] **Step 5: Commit the prerequisite reference**

```bash
git add references/prerequisites.md README.md
git commit -m "docs: define required research agent skills"
```

### Task 2: Enforce prerequisites in the skill entry point

**Files:**
- Modify: `SKILL.md:1-61`

- [ ] **Step 1: Demonstrate the current metadata failure**

Run:

```bash
python /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
```

Expected: FAIL with `Unexpected key(s) in SKILL.md frontmatter: standard_version`.
Do not weaken the validator; correct the skill metadata.

- [ ] **Step 2: Update the frontmatter and version marker**

Replace lines 1-5 with:

```markdown
---
name: research-repo-standard
description: The operating standard for reproducible research repositories supporting a scientific analysis, study, or paper. Use whenever setting up such a repository and before any file-changing request in a governed repository; enforce the required brainstorming, scientific critique, and figure workflows, and consult the bootstrap, data, analysis, figure, and prerequisite contracts. Also use for vendoring or re-vendoring the standard, registering datasets, writing validation, planning or reporting analyses, checking reproducibility, and producing publication figures or tables.
---
<!-- standard_version: 2026.08.04 -->
```

- [ ] **Step 3: Add prerequisite routing and the hard gate**

Add this row first in the reference table:

```markdown
| `references/prerequisites.md` | before bootstrap and when a required skill is missing |
```

Insert this section immediately after the reference table:

```markdown
## Required agent skills

Read `references/prerequisites.md`. Before the bootstrap interview or any
file-changing request in a governed repository, use the host-native skill listing or
resolver to confirm these exact names:

- `superpowers:brainstorming`
- `scientific-critical-thinking`
- `nature-figure`

If any is missing, stop before repository mutations, identify it, and give the user
the installation and session-reload instructions from the prerequisite reference.
Resume only after the host resolves all three names. File presence alone is not a
pass, and no generic workflow may substitute for a missing skill.

This is a normative agent gate whose enforcement depends on the host loading and
following the skill instructions; do not describe it as an operating-system control.

In governance mode, every request that will create, edit, move, or delete files invokes
`superpowers:brainstorming` and completes its approval, specification, and planning
gates before implementation. Read-only explanation, inspection, diagnosis, and status
reporting are not modifications.
```

- [ ] **Step 4: Replace the bootstrap sequence**

Replace the existing seven-step `## Bootstrapping sequence` list with:

```markdown
## Bootstrapping sequence

1. **Preflight once.** Apply `references/prerequisites.md` and confirm all three exact
   skill names through the host-native resolver. Do not repeat this check before
   scaffolding unless the agent session changes.
2. **Start brainstorming.** Invoke `superpowers:brainstorming`. Explore context, ask
   the interview questions below, and compare design approaches. Do not seek final
   design approval yet.
3. **Critique the science.** Request an independent subagent that applies
   `scientific-critical-thinking` to the proposed question, claim, study design,
   estimand, and major validity risks without implementing. Resolve material findings
   in the design.
4. **Define the figure strategy.** Invoke `nature-figure` with Python already selected
   by this standard. Define expected outputs, source data, exports, and QA; when no
   plots are planned, record that explicitly.
5. **Approve and document.** Return to the brainstorming workflow, present the
   integrated design, obtain approval, write and self-review its specification,
   commit it, and obtain user review.
6. **Plan.** Invoke `superpowers:writing-plans` after the user approves the written
   specification.
7. **Scaffold and configure.** Read `AGENTS.md`, create the approved structure, and use
   `references/bootstrap.md` for tooling. Agent prerequisites precede and remain
   separate from the generated repository's `make setup` target.
8. **Vendor and identify.** Run `./vendor.sh <target-repo>`, fill in the vendored
   `AGENTS.md` `## This repository` section, and report assumptions and unresolved
   boundaries.
```

- [ ] **Step 5: Validate the updated skill**

Run:

```bash
python /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
rg -n 'Preflight once|superpowers:brainstorming|scientific-critical-thinking|nature-figure|superpowers:writing-plans' SKILL.md
```

Expected: `Skill is valid!`; every required workflow name appears in the bootstrap
sequence.

- [ ] **Step 6: Commit the skill entry point**

```bash
git add SKILL.md
git commit -m "feat: gate research repository modifications"
```

### Task 3: Vendor the hard gate into governed repositories

**Files:**
- Modify: `AGENTS.md:1-338`

- [ ] **Step 1: Run pre-change governance assertions**

Run:

```bash
rg -q 'Every file-changing request.*superpowers:brainstorming' AGENTS.md
rg -q 'All three skills are hard prerequisites' AGENTS.md
```

Expected: both commands exit `1` because the governed-repository gate is absent.

- [ ] **Step 2: Bump the vendored standard version**

Change the first line to:

```markdown
<!-- standard_version: 2026.08.04 -->
```

- [ ] **Step 3: Add the governed-repository prerequisite section**

Insert this section after the paragraph ending `Project-specific scientific
requirements may refine this standard.`:

```markdown
## Required agent skills

`superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure` are
hard prerequisites. Before file-changing work, use the agent host's native skill
listing or resolver to confirm all three exact names. File presence alone is not
sufficient. If a skill is missing, stop before repository mutations and consult the
canonical prerequisite contract at
<https://github.com/lucascamillomd/research-repo-standard/blob/main/references/prerequisites.md>.
Do not install skills silently or substitute a generic workflow.

Every file-changing request invokes `superpowers:brainstorming` and completes its
design approval, written specification, user review, and planning gates before
implementation. Read-only explanation, inspection, diagnosis, and status reporting do
not count as modifications.

This is a normative agent instruction, not an operating-system access control. It
depends on the agent host loading and following this file.
```

- [ ] **Step 4: Add the prerequisite to the non-negotiable floor**

Append this item after the current item 9:

```markdown
10. **Required agent workflows are gates.** Missing `superpowers:brainstorming`,
    `scientific-critical-thinking`, or `nature-figure` stops file-changing work. Do not
    imitate or replace an unavailable skill.
```

- [ ] **Step 5: Make task-specific missing skills explicit blockers**

Append this sentence to the Analysis paragraph that requires independent critique:

```markdown
If the critique skill or a separate review subagent is unavailable, stop before making
or implementing the scientific judgment and report the blocker.
```

Replace the Figures sentence about missing dependencies with:

```markdown
Never use R or another language to render a preview, fallback, or substitute plot. If
`nature-figure`, Python, or a required Python dependency is unavailable, stop before
plotting and report the exact blocker rather than rendering something else.
```

- [ ] **Step 6: Put brainstorming first in the working procedure**

Insert this paragraph immediately after `## Working procedure`:

```markdown
Before any file-changing request, verify the three required skill names and invoke
`superpowers:brainstorming`. Do not edit until its design is approved, its specification
is committed and reviewed by the user, and its implementation plan is ready.
```

Keep the existing repository-context, implementation, verification, and reporting
paragraphs after this new gate.

- [ ] **Step 7: Verify and commit vendored governance**

Run:

```bash
rg -n 'Required agent skills|Every file-changing request|Required agent workflows are gates|stop before making|nature-figure.*, Python|Before any file-changing request' AGENTS.md
```

Expected: every hard-gate layer is found.

```bash
git add AGENTS.md
git commit -m "feat: vendor required agent workflow gates"
```

### Task 4: Align bootstrap, analysis, and figure references

**Files:**
- Modify: `references/bootstrap.md:1-163`
- Modify: `references/analysis.md:1-93`
- Modify: `references/figures.md:1-135`

- [ ] **Step 1: Run pre-change fallback assertions**

Run:

```bash
rg -n 'If the skill or a review subagent is unavailable, continue' references/analysis.md
rg -n 'If Python or a required plotting dependency is unavailable' references/figures.md
```

Expected: both legacy soft/incomplete fallback statements are found.

- [ ] **Step 2: Add the single bootstrap preflight**

Change `references/bootstrap.md` line 4 to:

```yaml
standard_version: 2026.08.04
```

Insert this section before `## Environment`:

```markdown
## Agent-skill preflight

Before the interview, scaffolding, Python selection, or tool configuration, apply
`references/prerequisites.md` once in the current agent session. All three required
skill names must resolve. Bootstrap then invokes each skill in its declared design
stage. If the session changes, repeat discovery; otherwise do not add a redundant
check before scaffolding or `make setup`.

Agent skills are not uv dependencies. The generated `make setup` target creates the
locked project environment and installs pre-commit hooks; it does not install or
validate global agent skills.
```

Replace the final README guidance with:

```markdown
Keep it concise: research question and one-paragraph scope, compact repository map,
the three required agent skills with a link to the canonical prerequisite contract,
shortest project setup and reproduction commands, expected results, external data and
tool limitations, the reproducibility classification, and links to `docs/`. Distinguish
agent bootstrap prerequisites from packages installed by `make setup`.
```

- [ ] **Step 3: Make scientific critique unavailable a blocker**

Change `references/analysis.md` line 1 to:

```markdown
<!-- standard_version: 2026.08.04 -->
```

Replace the paragraph at lines 79-81 with:

```markdown
Routine documentation, formatting, plumbing, and faithful implementation work do not
invoke a new critique, but `scientific-critical-thinking` and a separate review
subagent must remain available as hard repository prerequisites. If either is
unavailable when scientific judgment is required, stop before deciding or implementing
the judgment and report the exact blocker.
```

- [ ] **Step 4: Make the figure skill unavailable a blocker**

Change `references/figures.md` line 1 to:

```markdown
<!-- standard_version: 2026.08.04 -->
```

Replace lines 24-26 with:

```markdown
Never use R or another language to render a preview, fallback, assembly, or substitute
plot. If `nature-figure`, Python, or a required Python plotting dependency is
unavailable, stop before rendering and report the exact blocker.
```

- [ ] **Step 5: Verify no fallback contradiction remains**

Run:

```bash
! rg -n 'skill or a review subagent is unavailable, continue' AGENTS.md references SKILL.md
rg -n 'stop before deciding or implementing' references/analysis.md
rg -n 'If `nature-figure`, Python' references/figures.md
rg -n 'Agent-skill preflight|does not install or validate global agent skills' references/bootstrap.md
```

Expected: all commands exit `0`; the negated search produces no output.

- [ ] **Step 6: Commit the aligned references**

```bash
git add references/bootstrap.md references/analysis.md references/figures.md
git commit -m "docs: align prerequisite failure behavior"
```

### Task 5: Validate vendoring and behavior, then obtain final review

**Files:**
- Verify: `SKILL.md`
- Verify: `AGENTS.md`
- Verify: `README.md`
- Verify: `references/prerequisites.md`
- Verify: `references/bootstrap.md`
- Verify: `references/analysis.md`
- Verify: `references/figures.md`
- Verify: `vendor.sh`

- [ ] **Step 1: Run metadata and static contract checks**

```bash
python /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
git diff --check caba8e5..HEAD
rg -n 'standard_version: 2026.08.04' SKILL.md AGENTS.md README.md references/prerequisites.md references/bootstrap.md references/analysis.md references/figures.md
rg -l 'superpowers:brainstorming' SKILL.md AGENTS.md README.md references/prerequisites.md
rg -l 'scientific-critical-thinking' SKILL.md AGENTS.md README.md references/prerequisites.md references/analysis.md
rg -l 'nature-figure' SKILL.md AGENTS.md README.md references/prerequisites.md references/figures.md
```

Expected: validator prints `Skill is valid!`; diff check is silent; all listed files
are returned by their searches.

- [ ] **Step 2: Check the vendoring script and project identity preservation**

Run:

```bash
bash -n vendor.sh
validation_repo="$(mktemp -d /private/tmp/research-standard-validation.XXXXXX)"
cp AGENTS.md "$validation_repo/AGENTS.md"
perl -0pi -e 's/\*Per-repository section — the only part expected to differ from the source\. Replace it\.\*/Question: Does the fixture preserve project identity?/' "$validation_repo/AGENTS.md"
./vendor.sh "$validation_repo"
rg -n 'Question: Does the fixture preserve project identity\?' "$validation_repo/AGENTS.md"
rg -n 'superpowers:brainstorming|scientific-critical-thinking|nature-figure' "$validation_repo/AGENTS.md"
test -L "$validation_repo/CLAUDE.md"
```

Expected: `bash -n` is silent; vendoring reports version `2026.08.04`; the identity
line and all three skill names are present; `CLAUDE.md` is a symlink. Leave the narrow
temporary fixture for the operating system to clean up rather than using a broad
destructive command.

- [ ] **Step 3: Forward-test an ordinary governed-repository edit request**

Dispatch a fresh isolated agent with only the vendored fixture's `AGENTS.md` and this
user request:

```text
Change the README heading from "Study" to "Research Study".
```

Expected before any file write: the agent verifies the three required skill names,
invokes `superpowers:brainstorming`, and stops at the design-approval gate. Fail the
test if it edits the README directly or substitutes a generic planning workflow.

- [ ] **Step 4: Ask Claude to review the complete implementation diff**

Run Claude in safe mode so local hooks cannot stall the requested independent review,
and provide the committed implementation diff directly:

```bash
claude -p "You have no tools and must not request tool calls. Review this implementation diff against docs/superpowers/specs/2026-08-04-hard-skill-prerequisites-design.md. Check prerequisite completeness, contradictions, portability, brainstorming sequencing, Python-only figure behavior, validation integrity, and accidental scope. Return prioritized findings and concrete fixes; say explicitly if there are no material issues.\n\n$(git diff caba8e5..HEAD)" --model sonnet --effort low --safe-mode --max-budget-usd 0.50 --tools ""
```

Expected: prioritized findings or an explicit statement that no material issues remain.
Apply only findings consistent with the approved specification.

- [ ] **Step 5: Re-run checks after review fixes**

```bash
python /Users/lucascamillo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
bash -n vendor.sh
git diff --check caba8e5..HEAD
! rg -n 'skill or a review subagent is unavailable, continue' AGENTS.md references SKILL.md
git status --short --branch
```

Expected: validator passes; Bash and diff checks are silent; no soft fallback is found;
status contains only intentional review fixes, or is clean when Claude requested none.

- [ ] **Step 6: Commit review fixes when Claude identifies valid issues**

If review produced file changes, stage only the named contract files and commit:

```bash
git add SKILL.md AGENTS.md README.md references/prerequisites.md references/bootstrap.md references/analysis.md references/figures.md
git commit -m "fix: address prerequisite contract review"
```

If no files changed, do not create an empty commit. Record Claude's result and the
forward-test outcome in the final handoff.
