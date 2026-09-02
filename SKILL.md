---
name: research-repo-standard
description:
  Use when bootstrapping a repository that supports a scientific analysis, study, or paper; when
  adopting this standard in an existing repository or checking whether one complies; or when
  planning, changing, reviewing, or reporting such a repository's scientific data, configuration,
  analysis, figures, code, workflow, or reproducibility work. Not for general-purpose software
  projects or scratch work that will never support a scientific claim.
---

# Research repository standard

## Applicability and precedence

Apply this skill to a repository that is, or will become, the evidence behind a scientific analysis,
study, paper, or claim. Do not apply it to general-purpose software, a teaching repository, or
scratch work that will never support a claim.

Use **bootstrapping mode** to create a research repository. Use **adoption mode** when an existing
repository was not created under this standard or its compliance is unknown. Use **governed-work
mode** for work in a repository that already follows it. In every mode, explicit user instructions
and legal, institutional, journal, and data-use requirements take precedence over this standard.

Local repository instructions may add stricter or project-specific requirements but never silently
weaken this skill's safety floor. When two applicable instructions conflict, report the conflict and
follow the higher-precedence one.

## Required skills and modification gates

Resolve required skills by exact name through the current host's native resolver. A file on disk, or
a prompt or repository that names a skill, is not resolution or invocation evidence. Do not silently
install, imitate, or substitute a required skill. A missing or unverifiable skill blocks only the
work that depends on it.

Classify every requested file modification by what the change means scientifically, not by which
file carries the edit. A configuration value that changes an estimand, an inclusion or exclusion
rule, or a missing-data policy is a design-level change. Ceremony scales with what the change can
break; when uncertain, use the full gate.

- **Full gate.** Design-level changes: estimands, study design, statistical methodology, inclusion
  or exclusion rules, missing-data policy, causal interpretation, data contracts, pipeline
  structure, claim scope, and this standard's rules. Invoke `superpowers:brainstorming`. Write the
  specification, commit it, and obtain approval and user review. Then invoke
  `superpowers:writing-plans` to produce the implementation plan. Do not implement until that plan
  is written. Direct and delegated implementation inherits the completed gate; reopen it at design
  if scope expands.
- **Standard gate.** Result-affecting changes below design level: analysis configuration values,
  figure changes, and feature additions within the approved design. Obtain explicit authorization
  and, before presenting results, append the entry described under Governed work to
  `docs/LAB_NOTEBOOK.md`. Cover the change with tests. No specification or plan artifact is
  required; escalate to the full gate the moment a design-level item is in play.
- **Light path.** Mechanical, non-result-affecting changes: documentation, comments, formatting,
  behavior-preserving renames, tested refactors, and tests that do not change behavior. Deleting,
  disabling, or skip-marking a test, loosening an assertion, or relaxing a schema or validation
  constraint is never light path; classify it by what the check guarded, and a failing check makes
  that classification standard gate or higher. State the intent, the files, and why results cannot
  change; obtain one confirmation, then implement without specification or plan artifacts. Escalate
  to the standard gate if results may change and to the full gate if interfaces or contracts may
  change.
- **No gate.** Read-only explanation, inspection, diagnosis, status reporting, and regeneration of
  declared outputs from an approved workflow whose code and configuration are unchanged since
  approval; verify that before regenerating. A question asks for an answer, not an edit; answer,
  then wait for an explicit change request.

## Reference routing

In every mode, read the table below broadly. Load each reference whose trigger matches the requested
work, read it completely, and apply its contract before dependent decisions or edits. Do not avoid a
contract through narrower task wording. Familiarity with this standard is not a reason to skip a
reference; read it in this session before relying on it.

| Reference                     | Load when                                                                                                                                                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/prerequisites.md` | capability resolution is in scope or a required skill is unresolved, installation or recovery is requested, or host integration must be verified                                                                                            |
| `references/bootstrap.md`     | creating or changing repository structure, tool configuration, dependencies or `uv.lock`, pre-commit, CI, rule logging, the Snakemake workflow and Make interface, external runtimes, or the README and other initial project documentation |
| `references/configuration.md` | classifying, loading, using, changing, or overriding settings, paths, or provenance                                                                                                                                                         |
| `references/data.md`          | acquiring, registering, preprocessing, describing, validating, or contracting data                                                                                                                                                          |
| `references/analysis.md`      | scientific planning, estimands, design, inclusion, missingness, modeling, implementation, interpretation, or reporting                                                                                                                      |
| `references/figures.md`       | planning a figure, writing plotting code, changing figure outputs, or performing QA                                                                                                                                                         |

## Safety floor

These requirements do not bend for convenience, deadlines, or failing checks. Stop and report a
blocker rather than weakening one.

1. **Raw data is immutable.** Nothing under `data/raw/` is ever modified. Corrections,
   harmonization, exclusions, and derived variables create new files under `data/interim/` or
   `data/processed/`. Cleanup paths are narrow, named, guarded, and cannot reach raw data.
2. **Never weaken a gate to make it pass.** Reproducibility, provenance, and validation checks exist
   to fail. A failing check is information, not an obstacle. Removing, disabling, skipping, or
   loosening a check is weakening it, whatever the edit is called, and covering tests are checks.
3. **Estimands, inclusion rules, and data contracts change only with authorization.** Record the
   authorized change before presenting results built on it.
4. **Exploratory never silently becomes confirmatory.** Label analyses. Record post hoc changes and
   their rationale in `docs/LAB_NOTEBOOK.md` before presenting the result as if it were planned.
5. **No silent complete-case filtering.** Report missingness before exclusions or imputation.
   Inclusion and exclusion criteria are code, not prose.
6. **Randomness is declared, never invented.** When randomness is unavoidable, the seed is explicit
   recorded configuration: Seed 42. A deterministic workflow gets no seed. Prefer deterministic
   algorithms when scientifically equivalent, and declare nondeterministic boundaries.
7. **Outputs are written transactionally.** Build a temporary artifact, validate it, and only then
   replace the declared destination. A failed run must not leave output that looks complete.
8. **Configuration has one owner.** Every result-affecting setting has exactly one declared owner.
   Unknown, missing, duplicate-owned, or unrecorded result-affecting values fail before computation
   instead of defaulting silently, and a result-affecting value is never hidden in a code default.

## Bootstrapping sequence

1. **Preflight once.** Before the interview, resolve through the current host, as
   `references/prerequisites.md` prescribes: `research-repo-standard` itself with its source
   provenance, the `superpowers` package as a whole, and the exact names
   `scientific-critical-thinking` and `nature-figure`. Use the same reference for authorized
   recovery. Repeat only if the agent session changes.
2. **Interview one question at a time.** Ask the questions below and pursue conditional follow-ups.
   Never choose anything silently, including a seed, host, license, or scientific default. When the
   user explicitly asks for brevity, the two mechanical topics, host profile and license, may be
   presented together as concrete proposed defaults that still require explicit confirmation.
   Batching is permitted for those two topics only; every other numbered topic below stays one at a
   time.
3. **Design with the full gate.** Invoke `superpowers:brainstorming`, explore alternatives, and keep
   implementation blocked while the design is unsettled.
4. **Critique the science independently.** Launch a separate review agent that applies
   `scientific-critical-thinking` to the question, claim, study design, estimand, and major validity
   risks without implementing. Disposition findings as `references/analysis.md` prescribes.
5. **Define the figure strategy.** Load `references/figures.md` and invoke `nature-figure` before
   planning figures. Define figure data, outputs, exports, and QA. If no figures are planned, record
   an explicit no-figure strategy.
6. **Approve and document.** Present the integrated design for approval. In an empty directory,
   initialize only version control and the gate-artifact path needed to write the specification.
   Write and self-review the specification, commit it, and obtain user review before implementation.
   Do not create target `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or a shared top-level simplifier.
7. **Plan, scaffold, and configure.** Invoke `superpowers:writing-plans`, then load every applicable
   reference, including `references/bootstrap.md`, and create only the approved repository.
8. **Integrate the selected host.** If the user selected Codex or Claude Code, derive that host's
   profile from the canonical `agents/research-code-simplifier.md` in the provenance-verified skill
   source, as `references/prerequisites.md` prescribes, and write only the selected host's profile
   into the target. If none was selected, write no host profile and establish that the host can
   independently resolve the required simplifier; otherwise future code changes are blocked.
9. **Run a real selected-host smoke test.** Run the three-check smoke test
   `references/prerequisites.md` defines through the selected host, including launching the
   delegated reviewer far enough to report its own resolution. Report an unavailable host as that
   reference prescribes.
10. **Inspect and report.** Inspect the generated artifacts, not exit codes, then report every
    remaining assumption and manual or external boundary.

### Interview

Ask these, following the cadence rules in step 2:

1. What is the project identity and purpose?
2. What is the primary research question and intended scientific claim?
3. Is the current status exploratory or confirmatory?
4. Which host profile should be installed: `codex`, `claude-code`, or none?
5. Should the license be MIT, or should the repository stay unlicensed or proprietary?
6. Which datasets and access or data-use constraints are expected?
7. Which workflow stages are needed, which of them require randomness, such as resampling,
   permutation tests, stochastic fitting, or random data splits, and which processed-data checkpoint
   can be shared?
8. Are R or other non-Python tools required, and can they run in a pinned container? If yes, which
   runtime, version, system dependencies, and tests must it support?
9. Which tables, plots, reports, and publication targets are expected?
10. Which steps cannot be automated because of licensing, compute, or external-environment limits?
11. What can public CI verify, and what requires external inputs or tools? What is the smallest
    permitted fixture or checkpoint for each external boundary?
12. Which journal and publication type is the repository expected to support?

### Bootstrap execution record

Maintain these reporting slots throughout bootstrap. When asked to explain or plan a bootstrap
before the answers exist, first reproduce this record with undecided fields marked pending, then ask
exactly one next question. This is a checklist, not a repository file. Saying only that the required
topics will be covered, or listing only the first question, does not satisfy the record:

```text
Preflight: research-repo-standard + superpowers package + two scientific skills resolved
before interview
Reviews: brainstorming outcome; independent scientific critique and dispositions; figure strategy
or explicit no-figure strategy
Gate: integrated design approval; minimal gate-artifact initialization; committed and reviewed
specification; implementation plan ready
Scaffold: uv, Snakemake, and Make core contracts, configuration, data registry and raw-data
safety, analysis, provenance, verification; no unapproved R support
Forbidden artifacts: no target AGENTS.md/CLAUDE.md/CODEX.md, no shared top-level simplifier
Randomness: no seed for a deterministic workflow; otherwise explicit Seed 42
README: expected skill source/provenance, recovery, shortest reproduction path
Host: only the selected host profile, after core scaffold; real smoke test or honest boundary
Boundaries: assumptions and manual or external boundaries reported
Completion: actual generated artifacts inspected before completion is claimed
```

## Adopting an existing repository

Report the governed-work invocation record below first, then walk the standard item by item, the
safety floor first and then each reference's contract in routing-table order. Mark every item
compliant, a gap, or not applicable, and cite the paths, settings, tests, or missing artifacts as
evidence. For configuration items, reuse the established-repository migration in
`references/configuration.md`. For host-integration items, run the legacy-artifact detection in
`references/prerequisites.md` and cite its report.

Then produce a prioritized migration plan: data safety and provenance first, reproducibility and
contracts next, conveniences last. Change nothing while assessing. The review is read-only. Take
each accepted migration step through the gate its own change class requires.

## Governed work

The gates, interview questions, consultation points, capability blockers, and unclear destruction
targets this skill names are the only places to stop for the user. A capability blocker exists only
after the resolution or launch attempt fails in this session; an assumed limit is not a stop.
Between stops, carry out every step you state, whatever the run time or the hour; a stated next step
left undone is unfinished work. When a question arises mid-task, first do everything that does not
depend on the answer, then ask at the consultation point.

### Governed-work invocation record

Before classifying or changing a governed repository, resolve and invoke this skill by exact name
through the host-native resolver. Report, with every slot filled:

```text
Standard skill: research-repo-standard
Host-native resolver: <host and resolver that returned it>
Source provenance: <resolved path or package>
Invoked: yes
```

### Context and scope

Before changing anything, read the local instructions that apply from the repository root down to
the files in scope, plus the README, relevant project documents and configuration, nearby tests, and
`git status`. Identify the scientific claim, pipeline stage, inputs, outputs, and affected
contracts. Preserve unrelated work. Report assumptions that materially affect scientific meaning,
interfaces, data safety, or scope.

### Authorization and records

Obtain authorization before any design-level change listed under the full gate above. Before results
are presented, append the decision, rationale and evidence, authorization source, affected work, and
any superseded entry to `docs/LAB_NOTEBOOK.md`; the standard gate above refers to this entry. Before
presenting results affected by a changed analysis decision, amend `docs/ANALYSIS_PLAN.md` as
`references/analysis.md` prescribes and label its post hoc status. A result is presented once its
artifacts are committed, pushed, or shared in any form, not only when someone is shown a number.
Every obligation keyed to presenting is due before the affected result artifacts are committed;
presentation is never a deadline the agent defers by staying silent about finished results. Write
each record, specification and plan amendment included, so a fresh context can resume from the
repository alone: exact values, decisions taken and rejected, and what remains open.

### Independent critique

Work that depends on a scientific judgment under review waits for an independent critique at every
gate, not only at design level. Standard-gate changes that embody a scientific judgment are
included: covariate sets, thresholds, model settings. A separate review agent must apply
`scientific-critical-thinking` to that judgment and return findings, without implementing them,
before the agent decides or implements the dependent work. `references/analysis.md` owns the
critique procedure, batching, disposition of findings, and capability blockers.

### Change discipline

Keep changes narrow and follow the repository's declared interfaces. Tests and documentation change
with behavior. Validate inputs before expensive computation. If the approved scope expands, return
to the applicable gate. Report a pre-existing bug, performance concern, or behavior the task does
not mention as a follow-up in the completion report; do not fix it in this change unless the
requested behavior cannot work without it. Add tests only where the task or the repository's test
practice calls for them, sized like the neighboring tests, and never commit scratch checks. Edit
files in place; rewrite a whole file only when most of it changes.

### Mid-implementation consultation

When implementation hits a fork the approved plan did not settle, stop and consult the user before
writing dependent code. Forks include a test that cannot pass as designed, a contract that does not
fit, a failed approach, and an unforeseen design choice. Present two to four concrete options with
their consequences and wait for the choice. Ask through the host's question tool when it has one; in
Claude Code that is AskUserQuestion. Otherwise present plain enumerated options. When options differ
in real code, write one small throwaway script per option in a scratch location such as `tmp/`,
never committed and never under the governed `results/` or `data/` trees, so the user reads real
code before choosing. Delete the scripts once the user chooses; they never reach the completion
diff. Silently picking a fallback is a scope expansion, not a fix. An inherited plan approval does
not cover a choice the plan never made, and recording the decision afterward in
`docs/LAB_NOTEBOOK.md` or the completion report does not replace asking first. Later critique and
simplifier passes review a chosen option; they never choose it. The user is the paper's author;
these forks are theirs to decide. Escalate a design-level fork to the full gate.

### Destruction

Destruction is never implied. Deleting files, dropping columns or rows, overwriting existing
results, resetting or rewriting Git history, and force-pushing require explicit authorization. First
resolve the exact narrow targets and state what would be destroyed and whether it is recoverable; if
either is unclear, stop and ask.

### Simplifier review

After changing code or tests, launch an independent review agent through the current host's exact
`research-code-simplifier` profile. When the work executes an implementation plan, run the pass
after each completed plan task and before starting the next; one end-of-plan pass over the combined
diff does not satisfy it. For work outside a plan, run it once per coherent unit of work. Never run
it after every individual edit. It must invoke this skill. The profile governs its scope, method,
and behavior preservation. Re-run covering tests after any simplifier edit. Only when the profile
cannot be resolved or an independent agent cannot be launched may the user explicitly waive or defer
the pass; dependent completion is otherwise blocked, and the waiver and its scope are recorded in
the completion report so it is never silent. This is not a general opt-out, and a self-pass never
substitutes for the independent review.

Before inspecting the delegated diff, the reviewer reports this additional resolution record, with
every slot filled:

```text
Simplifier profile: research-code-simplifier
Host-native resolver: <host and resolver that returned it>
Resolved profile path: <path>
Invoked research-repo-standard from: <source provenance>
```

## Completion

Before declaring completion, run the repository's applicable formatting, lint, type, test, and
verification interfaces. Inspect the generated tables, figures, profiles, and provenance manifests;
exit codes are not evidence. Check `git status` for unintended files and confirm raw inputs and
unrelated work are unchanged.

The completion report states what changed, what was verified and how, what was skipped and why, and
every manual or inaccessible reproducibility boundary. It covers the whole task, not the last step,
and stands on its own for a reader who saw nothing else. Notebook entries, README text, and reports
use literal plain sentences, without metaphor or flourish. Do not claim a selected host integration
is complete without the real resolver smoke test required above. Do not claim the work complete
while a required critique, simplification pass, artifact inspection, or verification gate remains
unresolved without a recorded waiver.
