# Hard skill prerequisites for governed research repositories

**Status:** Approved design
**Date:** 2026-08-04

## Context

The research repository standard currently requires `nature-figure` for plots and
requests `scientific-critical-thinking` for scientific judgments, but repository
bootstrap does not verify either skill. Scientific critique also has a soft fallback
that permits work to continue when the skill is unavailable. The standard does not
currently require `superpowers:brainstorming` before modifying a governed repository.

This creates three failure modes: an agent can begin scaffolding before the repository
design is approved, scientific decisions can bypass the intended independent critique,
and figure work can proceed without the required figure workflow.

## Goals

1. Make `superpowers:brainstorming`, `scientific-critical-thinking`, and
   `nature-figure` hard prerequisites for repository bootstrap.
2. Use all three skills meaningfully during bootstrap before scaffolding begins.
3. Require `superpowers:brainstorming` before every file-changing request in a
   governed research repository.
4. Preserve the task-specific requirements for scientific critique and figure work
   after bootstrap.
5. Give users one authoritative place for installation and verification guidance.
6. Stop safely and clearly when a prerequisite is unavailable.

## Non-goals

- Do not install skills silently or modify global agent configuration automatically.
- Do not treat agent skills as Python project dependencies managed by uv.
- Do not add a filesystem-only checker that assumes one agent host or installation
  layout.
- Do not weaken the existing Python-only plotting requirement.
- Do not change research estimands, data contracts, or scientific methods.

This standard applies to repositories that support a scientific analysis, study, or
paper. A general-purpose utilities or infrastructure repository with no research
question or intended scientific claim is outside its scope. During early bootstrap,
the question or claim may be provisional, but it still supplies meaningful material
for scientific critique.

## Required skills

| Skill | Bootstrap responsibility | Ongoing responsibility |
|---|---|---|
| `superpowers:brainstorming` | Govern repository design, alternatives, approval, specification, and transition to planning | Run before every file-changing request |
| `scientific-critical-thinking` | Independently critique the research question, intended claim, study design, estimand, and major validity risks | Run for scientific judgments through an independent critique |
| `nature-figure` | Define the figure strategy, expected outputs, source-data needs, export contract, and QA requirements | Run for every exploratory, diagnostic, analytical, supplementary, or manuscript plot |

The research repository standard has higher-priority project instructions than the
general figure skill. During bootstrap and later figure work, invoke `nature-figure`
with Python as the already-selected backend. Do not reopen its normal Python/R choice.

## Layered prerequisite contract

### Canonical reference

Add `references/prerequisites.md` as the single detailed source for:

- required skill names and purposes;
- authoritative upstream sources;
- installation routes for supported agent hosts;
- restart or reload requirements;
- availability verification; and
- failure and resumption behavior.

Use these upstream sources:

- Superpowers: <https://github.com/obra/superpowers>
- Scientific Agent Skills: <https://github.com/k-dense-ai/scientific-agent-skills>
- Nature Skills: <https://github.com/Yuan1z0825/nature-skills>

Installation guidance may show host-specific commands. Use the agent host's native
skill listing or resolver as the lightweight discovery check: it must return the exact
required skill name. A directory or `SKILL.md` file alone is insufficient because it
does not prove that the host can resolve the skill. Successful invocation during the
bootstrap or task-specific workflow is the functional verification.

### Skill entry point

Update `SKILL.md` to read the prerequisite reference and enforce the gate before the
bootstrap interview. The skill must stop before any repository mutation if a required
skill cannot be invoked. Its bootstrap sequence must then invoke the three workflows
in the order described below.

### Vendored governance

Update `AGENTS.md` so the requirement remains active inside a governed repository even
when `research-repo-standard` itself is not loaded. Add the hard prerequisite rule to
the non-negotiable floor and add the brainstorming invocation to the working procedure
before the existing context and status checks.

This is a normative agent instruction, not an operating-system access control. Its
enforcement depends on an agent host loading and following `AGENTS.md`; the standard
must state the gate unequivocally without claiming a technical guarantee it cannot
provide.

`AGENTS.md` must distinguish installation from invocation:

- all three skills must be installed and discoverable;
- brainstorming is invoked for every file-changing request;
- scientific critique and figure workflows are invoked when their task-specific
  conditions apply; and
- all three are invoked during bootstrap.

### Supporting references and README

- Update `references/bootstrap.md` so agent-skill preflight precedes Python and tool
  setup, and so generated repository READMEs list the agent prerequisites.
- Update `references/analysis.md` to remove the soft fallback for an unavailable
  critique skill or subagent.
- Update `references/figures.md` to make an unavailable `nature-figure` skill an
  explicit blocker.
- Update `README.md` with a concise hard-prerequisite summary and a link to the
  canonical reference.

## Bootstrap flow

1. **Preflight.** Load `references/prerequisites.md`. Use the host-native skill listing
   or resolver to confirm that all three exact required names are discoverable. If any
   is missing, stop before the interview or file changes and provide the relevant
   installation route. This is the single bootstrap preflight; do not repeat it before
   scaffolding or `make setup` unless the agent session has changed.
2. **Repository design.** Invoke `superpowers:brainstorming`. Complete its context,
   clarification, and alternatives stages, but do not seek final design approval yet.
3. **Scientific critique.** During design, request an independent subagent critique
   using `scientific-critical-thinking`. Give it the proposed research question,
   intended claim, study design, estimand, and relevant constraints. It returns
   findings without implementing. Incorporate or explicitly resolve material findings
   before final design approval.
4. **Figure strategy.** During design, invoke `nature-figure` with Python fixed as the
   backend. Define expected figures, source data, exports, and QA. If the repository
   plans no plots, record that explicitly rather than inventing figure requirements.
5. **Approval and specification.** Present the integrated design for approval, then
   complete the brainstorming specification, self-review, commit, and user-review
   gates.
6. **Plan and scaffold.** Invoke `writing-plans`, then implement the approved bootstrap
   plan. Only now may scaffolding begin.

Agent prerequisites are a gate before the generated repository's `make setup` target.
`make setup` continues to manage the locked project environment and pre-commit hooks;
it does not install or validate global agent skills.

## Ongoing modification flow

For any user request that will create, edit, move, or delete files in a governed
research repository:

1. verify that the three prerequisite skills remain discoverable;
2. invoke `superpowers:brainstorming` before implementation;
3. obtain the required design approval and complete its specification and planning
   gates; and
4. invoke `scientific-critical-thinking` or `nature-figure` when the request also
   meets their task-specific conditions.

Read-only explanation, inspection, diagnosis, and status reporting do not count as
modifications. A later request to implement a diagnosed change does.

## Failure and resumption

When a prerequisite is unavailable:

1. stop before repository mutations;
2. name the missing skill and the failed discovery or invocation;
3. point to its authoritative installation instructions;
4. require the user to install it and restart or reload the agent session as directed
   by the host-specific instructions; and
5. resume only after successful invocation.

Do not substitute generic brainstorming, informal self-critique, a non-skill plotting
workflow, or another model acting without the named skill. Do not claim availability
from a filesystem check alone.

## Versioning

Bump `standard_version` to `2026.08.04` in each changed normative file. The vendored
`AGENTS.md` version remains the project-facing drift identifier.

## Validation

1. Run the skill-creator `quick_validate.py` validator on the skill folder.
2. Search the changed files for contradictory soft-fallback language.
3. Confirm the three exact skill names appear in the prerequisite gate and bootstrap
   flow.
4. Vendor the standard into a temporary repository and inspect the resulting
   `AGENTS.md`, including preservation of an existing `## This repository` section.
5. Run `bash -n vendor.sh`.
6. Review `git diff` and `git status` for unintended changes.
7. Ask Claude through `claude -p` to review the requirements and complete diff. Fix
   valid findings, rerun the relevant checks, and report any rejected feedback with a
   reason.
8. Forward-test an ordinary post-bootstrap file-edit request in a temporary governed
   repository or isolated agent session. Confirm that the agent invokes brainstorming
   and stops for design approval before editing.

These checks verify the skill contract and vendoring behavior. They do not establish
the scientific validity of any future repository or analysis.
