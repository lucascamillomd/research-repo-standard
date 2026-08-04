---
name: research-repo-standard
description: The operating standard for reproducible research repositories supporting a scientific analysis, study, or paper. Use whenever setting up such a repository and before any user-requested modification in a governed repository that creates, edits, moves, or deletes files; enforce the required brainstorming, scientific critique, and figure workflows, and consult the bootstrap, data, analysis, figure, and prerequisite contracts. Use even when the user does not name the standard, especially for vendoring or re-vendoring it, registering datasets in config/datasets.yaml, writing validation, planning or reporting analyses in docs/ANALYSIS_PLAN.md, checking reproducibility, and producing publication figures or tables.
---
<!-- standard_version: 2026.08.04 -->

# Research repository standard

Two modes.

**Bootstrapping** — the repository does not exist yet. Follow the sequence below.

**Governance** — the repository exists and vendors `AGENTS.md`, which is already in
context and self-sufficient for the rules. Load a reference here only for detail it
deliberately omits:

| Reference | Read when |
|---|---|
| `references/prerequisites.md` | before bootstrap, before a user-requested governed modification, and when a required skill is missing |
| `references/bootstrap.md` | writing tool config, CI, or a Makefile that does not exist yet |
| `references/data.md` | registering a dataset, defining a schema, writing validation |
| `references/analysis.md` | planning or reporting a confirmatory analysis |
| `references/figures.md` | before writing any plotting code, and again during figure QA |

## Required agent skills

Read `references/prerequisites.md`. Before the bootstrap interview or any
user-requested modification in a governed repository that creates, edits, moves, or
deletes files, use the host-native skill listing or resolver to confirm these exact
names:

- `superpowers:brainstorming`
- `scientific-critical-thinking`
- `nature-figure`

If any is missing, stop at preflight, before the bootstrap interview or repository
mutations, identify it, and give the user the installation and session-reload
instructions from the prerequisite reference. Resume only after the host resolves all
three names. File presence alone is not a pass, and no generic workflow may substitute
for a missing skill.

This is a normative agent gate whose enforcement depends on the host loading and
following the skill instructions; do not describe it as an operating-system control.

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

During governed work, invoke `scientific-critical-thinking` through an independent
critique whenever the task turns on a scientific judgment, under the analysis
contract, and invoke `nature-figure` for every plot under the figure contract.

Do not restate `AGENTS.md` back to the user — they already have it.

## Bootstrapping sequence

1. **Preflight once.** Apply `references/prerequisites.md` and confirm all three exact
   skill names through the host-native resolver. Do not repeat this check before
   scaffolding unless the agent session changes.
2. **Start brainstorming.** Invoke `superpowers:brainstorming`. Explore context, ask
   the interview questions below, and compare design approaches. Do not seek final
   design approval yet.
3. **Critique the science.** Request an independent subagent that applies
   `scientific-critical-thinking` to the proposed question, claim, study design,
   estimand, and major validity risks without implementing. Every material finding
   must be incorporated or explicitly dispositioned in the design. The critique is
   advisory: adopt a recommendation only when it is justified by the evidence and
   task.
4. **Define the figure strategy.** Invoke `nature-figure`. Python is fixed by this
   standard and must not be reopened; if `nature-figure` offers a backend choice, this
   standard controls. Define expected outputs, source data, exports, and QA; when no
   plots are planned, record that explicitly.
5. **Approve and document.** Return to the brainstorming workflow, present the
   integrated design, and obtain approval. If the target repository is not yet
   initialized, initialize only its Git repository and create only the process-artifact
   path needed for the specification. This minimal initialization is part of the
   active gate, not project scaffolding; defer all other scaffold and configuration
   work to step 7. Then write and self-review the specification, commit it, and obtain
   user review.
6. **Plan.** Invoke `superpowers:writing-plans` after the user approves the written
   specification. This companion workflow is delivered by the required Superpowers
   installation; it is not a fourth hard prerequisite.
7. **Scaffold and configure.** Read `AGENTS.md` in this skill, create the approved
   structure, and use `references/bootstrap.md` for tooling. Agent prerequisites
   precede and remain separate from the generated repository's `make setup` target.
8. **Vendor and identify.** Run `./vendor.sh <target-repo>`; it copies `AGENTS.md` and
   symlinks `CLAUDE.md` to it, and nothing else is vendored. Fill in the vendored
   `AGENTS.md` `## This repository` section, then report what was created, assumptions,
   and unresolved boundaries.

## Interview

1. What is the primary research question and intended scientific claim?
2. Should the license be MIT, or should the repository remain unlicensed/proprietary?
3. Which currently supported stable Python minor version?
4. What datasets are expected?
5. Which workflow stages are needed, and which processed-data checkpoint can be shared?
6. Are R or other non-Python tools required, and can they run in a pinned container?
7. What are the expected tables, plots, reports, and publication targets?
8. Which steps cannot be automated because of licensing, compute, or external
   environment constraints?
9. What verification can run in public CI, and what requires external inputs or tools?

**Do not create a `LICENSE` until question 2 is answered.** Do not assume a company or
otherwise private repository should use MIT. If no choice is available, leave the
repository unlicensed and report that as unresolved.

## Drift

A repository vendors `AGENTS.md` at the version stamped in its first line. When this
source changes, vendored copies do not — that is intended, since a project may
legitimately refine the standard for its own science. `make standard-check` in a
governed repository reports the difference; it does not resolve it.
