---
name: research-repo-standard
description:
  The operating standard for reproducible research repositories supporting a scientific analysis,
  study, or paper. Use when bootstrapping such a repository, and before any file-changing work in a
  repository that vendors this standard's AGENTS.md — it governs modification gates, configuration
  and data ownership, analysis planning and independent critique, figures, and vendoring. Not for
  general-purpose software projects or scratch analyses that will not support a scientific claim.
---

# Research repository standard

This standard is for repositories whose purpose is to support a scientific claim — an analysis,
study, or paper. It does not govern general-purpose software projects, teaching materials, or
scratch exploration that will never support a claim; apply it when the work is, or is intended to
become, the evidence behind one.

Two modes.

**Bootstrapping** — the repository does not exist yet. Follow the sequence below.

**Governance** — the repository exists and vendors `AGENTS.md`, which is already in context and
self-sufficient for the rules. Load a reference here only for detail it deliberately omits:

| Reference                     | Read when                                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------------------------ |
| `references/prerequisites.md` | bootstrap preflight or recovery from a missing required capability                               |
| `references/configuration.md` | classifying settings, changing YAML, loaders, paths, overrides, or configuration provenance      |
| `references/bootstrap.md`     | writing tool config, CI, or a Makefile that does not exist yet                                   |
| `references/data.md`          | registering a dataset, defining a schema, writing validation                                     |
| `references/analysis.md`      | planning or reporting a confirmatory analysis                                                    |
| `references/figures.md`       | before figure planning, plotting-code work, modifying figure outputs, and again before figure QA |

In governance mode apply AGENTS.md. Load a reference only from the table above. Do not restate
AGENTS.md back to the user.

## Bootstrapping sequence

1. **Preflight once.** Before the interview, use the host-native resolver to confirm the exact names
   `superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure`. This preflight
   is name-resolution only. If a name is missing, pause and use `references/prerequisites.md` for
   authorized installation or recovery; do not silently install or substitute a different workflow.
   Do not repeat the check before scaffolding unless the agent session changes.
2. **Start brainstorming.** Invoke `superpowers:brainstorming`. Explore context, ask the interview
   questions below one at a time, and compare design approaches. Do not seek final design approval
   yet.
3. **Critique the science.** Request an independent review agent that applies
   `scientific-critical-thinking` to the proposed question, claim, study design, estimand, and major
   validity risks without implementing. Every material finding must be incorporated or explicitly
   dispositioned in the design. The critique is advisory: adopt a recommendation only when it is
   justified by the evidence and task.
4. **Define the figure strategy.** Read `references/figures.md`, then invoke `nature-figure` before
   figure planning, plotting-code work, or output modification; consult the reference again before
   performing QA. Python is fixed by this standard and must not be reopened; if `nature-figure`
   offers a backend choice, this standard controls. Define expected outputs, source data, exports,
   and QA; when no plots are planned, record that explicitly.
5. **Approve and document.** Return to the brainstorming workflow, present the integrated design,
   and obtain approval. If the target repository is not yet initialized, initialize only its Git
   repository and create only the process-artifact path needed for the specification. This minimal
   initialization is part of the active gate, not project scaffolding; defer all other scaffold and
   configuration work to step 6. Then write and self-review the specification, commit it, and obtain
   user review.
6. **Plan, then scaffold and configure.** Invoke `superpowers:writing-plans` after the user approves
   the written specification. This companion workflow is delivered by the required Superpowers
   installation; it is not a fourth hard prerequisite. Once the plan is ready, read `AGENTS.md` in
   this skill, create the approved structure, use `references/bootstrap.md` for tooling, and use
   `references/configuration.md` when creating configuration files and loaders. Agent prerequisites
   precede and remain separate from the generated repository's `make setup` target.
7. **Vendor and identify.** Run `./vendor.sh <target-repo>`; portable core vendoring writes only
   `AGENTS.md`. Fill in the vendored `AGENTS.md` `## This repository` section.
8. **Integrate the selected host.** Only when the user selected a host adapter, run its separate
   post-vendor installer: `./adapters/codex.sh <target-repo>` or
   `./adapters/claude-code.sh <target-repo>`. The selected adapter installs the canonical
   code-simplifier profile. Then launch an independent review agent in the target repository and
   require it to name the applicable `AGENTS.md`, resolve or read its assigned profile, and return
   findings without implementation. When no adapter was selected, skip the installer and smoke test.
   Selecting `none` is valid only when the host can independently resolve the canonical simplifier
   profile required for future reviews; otherwise future code changes will block at the independent
   simplification gate. In either case, report what was created, assumptions, and unresolved
   boundaries.

## Interview

Ask these questions one at a time and pursue conditional follow-ups before moving on.

1. What is the primary research question and intended scientific claim?
2. Which currently supported Python minor should the project use?
3. Which host adapter should be installed after vendoring: `codex`, `claude-code`, or none?
4. Should the license be MIT, or should the repository remain unlicensed/proprietary?
5. What datasets are expected?
6. Which workflow stages are needed, and which processed-data checkpoint can be shared?
7. Are R or other non-Python tools required, and can they run in a pinned container? If yes, ask
   which runtime, version, system dependencies, and tests the container must support.
8. What are the expected tables, plots, reports, and publication targets?
9. Which steps cannot be automated because of licensing, compute, or external environment
   constraints?
10. What verification can run in public CI, and what requires external inputs or tools? Follow up on
    the smallest permitted fixture or checkpoint for each external boundary.
11. Which journal and publication type is this repo expected to support?
