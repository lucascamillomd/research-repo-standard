---
name: research-repo-standard
description: The operating standard for reproducible research repositories supporting a scientific analysis, study, or paper. Use when bootstrapping such a repository, and before any file-changing work in a repository that vendors this standard's AGENTS.md — it governs modification gates, configuration and data ownership, analysis planning and independent critique, figures, vendoring, and drift checks. Not for general-purpose software projects or scratch analyses that will not support a scientific claim.
---
<!-- standard_version: 2026.08.12 -->

# Research repository standard

This standard is for repositories whose purpose is to support a scientific claim —
an analysis, study, or paper. It does not govern general-purpose software projects,
teaching materials, or scratch exploration that will never support a claim; apply it
when the work is, or is intended to become, the evidence behind one.

Two modes.

**Bootstrapping** — the repository does not exist yet. Follow the sequence below.

**Governance** — the repository exists and vendors `AGENTS.md`, which is already in
context and self-sufficient for the rules. Load a reference here only for detail it
deliberately omits:

| Reference | Read when |
|---|---|
| `references/prerequisites.md` | before bootstrap, before a user-requested governed modification, and when a required skill is missing |
| `references/configuration.md` | classifying settings, changing YAML, loaders, paths, overrides, or configuration provenance |
| `references/bootstrap.md` | writing tool config, CI, or a Makefile that does not exist yet |
| `references/data.md` | registering a dataset, defining a schema, writing validation |
| `references/analysis.md` | planning or reporting a confirmatory analysis |
| `references/figures.md` | before writing any plotting code, and again during figure QA |

## Required agent skills

Read `references/prerequisites.md`. Before the bootstrap interview, use the
host-native skill listing or resolver to confirm all three exact names — bootstrap
actively uses each of them:

- `superpowers:brainstorming`
- `scientific-critical-thinking`
- `nature-figure`

In a governed repository the requirement is scoped to the work that depends on each
skill; `AGENTS.md` defines that scoping alongside the modification gate it owns.

If a required skill is missing, stop at preflight, before the bootstrap interview or
the dependent repository mutations, identify it, and give the user the installation
and session-reload instructions from the prerequisite reference. Resume only after
the host resolves the required names. File presence alone is not a pass, and no
generic workflow may substitute for a missing skill.

This is a normative agent gate whose enforcement depends on the host loading and
following the skill instructions; do not describe it as an operating-system control.

In governance mode, `AGENTS.md` owns the modification-gate rules — the full gate,
the light path, and the no-gate exemptions. It is already in context in a governed
repository; apply it rather than a restatement.

During governed work, obtain the independent `scientific-critical-thinking`
critique when a trigger in the analysis contract applies, and invoke
`nature-figure` for every plot under the figure contract.

For configuration work, `AGENTS.md` owns the ownership rules; read
`references/configuration.md` for the full contract.

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
   structure, use `references/bootstrap.md` for tooling, and use
   `references/configuration.md` when creating configuration files and loaders. Agent
   prerequisites precede and remain separate from the generated repository's
   `make setup` target.
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
