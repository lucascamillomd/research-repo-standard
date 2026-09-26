---
name: research-repo-standard
description:
  Bootstrap reproducible research repositories, assess adoption of this standard, and maintain
  scientific and reproducibility contracts in repositories that already follow it.
---

# Research repository standard

## Scope

Use this standard when creating a repository that supports a scientific analysis, study, paper, or
claim; when the user requests adoption or a compliance assessment; or when maintaining a repository
that already follows it. An ordinary task in an ungoverned scientific repository does not initiate
adoption. General-purpose software, teaching repositories, and scratch work that will never support
a claim are outside scope.

Explicit user instructions and legal, institutional, journal, and data-use requirements take
precedence. Report material conflicts and follow the higher-precedence instruction. Project choices
may override the documented seed, Python-version, and plotting-backend defaults; record the choice
in its owning configuration or contract. These conventions are separate from the scientific
invariants below.

Ask questions to understand the task better and catch what you might otherwise assume or overlook.
Ask proactively even if you can proceed without it.

## Change classification

Classify by scientific meaning, not file type. An inclusion rule inside configuration is still a
design decision. Investigate uncertainty before classifying; if scientific impact remains unclear,
use the full gate for dependent work. Existing authorization covers its stated scope: do not ask
again for work the user already authorized.

- **Full gate:** new or changed estimands, study design, statistical methodology, inclusion or
  exclusion rules, missing-data policy, causal interpretation, data contracts, pipeline structure,
  claim scope, or this standard's rules. Resolve and invoke `superpowers:brainstorming`, settle the
  design, write and commit the specification, and obtain user review and approval. Then invoke
  `superpowers:writing-plans` and write the implementation plan before implementing. Reuse completed
  gates for the same scope in direct or delegated work. Scientific judgments also require the
  critique in `references/analysis.md` before dependent decisions or implementation.
- **Standard gate:** result-affecting work within the approved design, including analysis settings,
  figures, and features. The request can supply authorization. Record the change using
  `references/governance.md` before presenting results and add checks appropriate to what can
  change. No separate specification or plan is required. New scientific judgments still require
  critique.
- **Light path:** requested mechanical changes to documentation, comments, formatting, names, or
  tested cleanup within the simplifier profile's supported-use limits. Proceed without another
  confirmation or design artifacts. Escalate if results, public interfaces, or declared contracts
  may change. Removing, disabling, skipping, or loosening a test or validation constraint is never
  light path; classify by what it guards, with a failing check at standard gate or higher.
- **No gate:** read-only explanation, inspection, diagnosis, or status; also regeneration of
  declared outputs when code and configuration are verified unchanged since approval. Apply the
  replacement boundary in `references/governance.md`. An explanation request alone does not
  authorize edits.

## Safety floor

Stop and report a blocker rather than weakening these requirements.

1. **Raw data is immutable.** Nothing under `data/raw/` is ever modified. Corrections,
   harmonization, exclusions, and derived variables create new files under `data/interim/` or
   `data/processed/`. Cleanup paths are narrow, named, guarded, and cannot reach raw data.
2. **Never weaken a gate to make it pass.** Removing, disabling, skipping, or loosening a check
   weakens it. This includes reproducibility, provenance, validation, and covering tests.
3. **Estimands, inclusion rules, and data contracts change only with authorization.** Record the
   authorized change before presenting results built on it.
4. **Exploratory never silently becomes confirmatory.** Label analyses. Record post hoc changes and
   their rationale in `docs/LAB_NOTEBOOK.md` before presenting the result as if it were planned.
5. **No silent complete-case filtering.** Report missingness before exclusions or imputation.
   Inclusion and exclusion criteria are code, not prose.
6. **Randomness is declared, never invented.** When randomness is unavoidable, the seed is explicit
   recorded configuration; `references/configuration.md` owns the seed convention. A deterministic
   workflow gets no seed. Prefer deterministic algorithms when scientifically equivalent, and
   declare nondeterministic boundaries.
7. **Outputs are written transactionally.** Build a temporary artifact, validate it, and only then
   replace the declared destination. A failed run preserves the existing valid output and leaves no
   partial output at the declared destination.
8. **Configuration has one owner.** Every result-affecting setting has exactly one declared owner.
   Unknown, missing, duplicate-owned, or unrecorded result-affecting values fail before computation
   instead of defaulting silently, and a result-affecting value is never hidden in a code default.

## Project history

`docs/LAB_NOTEBOOK.md` is the only file that records project history. Every other file, including
code comments, docstrings, and documentation, describes the repository as it is now. Leave out notes
about earlier versions, replaced methods, removed options, renamed settings, and legacy behavior.
When a change makes text stale, rewrite it to the current state. Record history worth keeping in the
notebook; a change that needs no notebook entry needs no history note, because git keeps the diff.
Exploratory and post hoc labels state the current analysis status and stay. Report stale history in
unrelated files as follow-up.

## Routing

Read the sections relevant to the task and their linked dependencies. Do not load every reference or
repeat unchanged reading solely because a new file is touched. Broaden inspection when a change
crosses a contract boundary. Required capabilities resolve by exact name through the current host;
`references/prerequisites.md` owns resolution evidence, recovery, and host integration.

| Work                                                                                            | Reference and relevant sections                                                                              |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| New repository                                                                                  | [bootstrap](references/bootstrap.md): design and interview, then approved scaffold sections                  |
| Adoption assessment                                                                             | [governance](references/governance.md): adoption; inspect each applicable contract with evidence             |
| Scientific/result-affecting changes, implementation choices, output replacement, code review    | [governance](references/governance.md): records, consultation, destruction, review and waivers as applicable |
| Capability first use, installation, changed provenance, or host integration                     | [prerequisites](references/prerequisites.md)                                                                 |
| Structure, dependencies, lockfile, tool configuration, logging, CI, workflow, external runtimes | [bootstrap](references/bootstrap.md): the affected contract only                                             |
| Initial project documentation or README reproduction instructions                               | [bootstrap](references/bootstrap.md): generated README checklist; a spelling fix needs no scaffold review    |
| Settings, paths, loading, overrides, or provenance                                              | [configuration](references/configuration.md)                                                                 |
| Data acquisition, registration, preprocessing, validation, or schemas                           | [data](references/data.md)                                                                                   |
| Scientific planning, estimands, inclusion, missingness, modeling, interpretation, reporting     | [analysis](references/analysis.md)                                                                           |
| Figures or plotting                                                                             | [figures](references/figures.md): scope and shared data/QA, then the requested delivery mode                 |

## Completion

Complete authorized implementation, required reviews, relevant checks, and artifact inspection
before reporting completion. Continue work independent of a pending question or failed capability. A
long run alone is not a reason to hand back an unfinished authorized task. Resolve routine
implementation choices within the approved design.

Use the repository's applicable formatting, lint, type, test, and verification interfaces. Inspect
generated tables, figures, profiles, and provenance; exit codes alone do not verify artifacts. Check
the diff and git status, preserving raw inputs and unrelated work. Report the whole task: what
changed, what was verified and how, remaining work, and manual or inaccessible boundaries. Never
claim a waived review or unavailable real host check passed.
