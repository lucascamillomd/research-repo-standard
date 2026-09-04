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
rule, or a missing-data policy is a design-level change. Choose the gate by scientific impact; when
uncertain, use the full gate.

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
  renames, tested cleanup within the simplifier profile's supported-use limits, and tests that do
  not change behavior. Deleting, disabling, or skip-marking a test, loosening an assertion, or
  relaxing a schema or validation constraint is never light path; classify it by what the check
  guarded, and a failing check makes that classification standard gate or higher. State the intent,
  the files, and why results cannot change; obtain one confirmation, then implement without
  specification or plan artifacts. Escalate to the standard gate if results may change and to the
  full gate if public interfaces or declared contracts may change.
- **No gate.** Read-only explanation, inspection, diagnosis, status reporting, and regeneration of
  declared outputs from an approved workflow whose code and configuration are unchanged since
  approval; verify that before regenerating and apply the replacement rule under Destruction. Answer
  questions without editing unless the user requests a change.

## Reference routing

Load each reference whose trigger matches the work. Read it completely in this session before
applying it. Familiarity never justifies skipping a reference, and narrower task wording does not
remove an applicable contract.

| Reference                     | Load when                                                                                                                                                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/prerequisites.md` | capability resolution is in scope or a required skill is unresolved, installation or recovery is requested, or host integration must be verified                                                                                            |
| `references/bootstrap.md`     | creating or changing repository structure, tool configuration, dependencies or `uv.lock`, pre-commit, CI, rule logging, the Snakemake workflow and Make interface, external runtimes, or the README and other initial project documentation |
| `references/configuration.md` | classifying, loading, using, changing, or overriding settings, paths, or provenance                                                                                                                                                         |
| `references/data.md`          | acquiring, registering, preprocessing, describing, validating, or contracting data                                                                                                                                                          |
| `references/analysis.md`      | scientific planning, estimands, design, inclusion, missingness, modeling, implementation, interpretation, or reporting                                                                                                                      |
| `references/figures.md`       | planning a figure, writing plotting code, changing figure outputs, or performing QA                                                                                                                                                         |

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
   recorded configuration: Seed 42. A deterministic workflow gets no seed. Prefer deterministic
   algorithms when scientifically equivalent, and declare nondeterministic boundaries.
7. **Outputs are written transactionally.** Build a temporary artifact, validate it, and only then
   replace the declared destination. A failed run preserves the existing valid output and leaves no
   partial output at the declared destination.
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
   presented together as concrete proposed defaults that still require explicit confirmation; every
   other numbered topic below stays one at a time.
3. **Design with the full gate.** Invoke `superpowers:brainstorming`, explore alternatives, and keep
   implementation blocked while the design is unsettled.
4. **Critique the science independently.** Follow `references/analysis.md` for the question, claim,
   study design, estimand, and major validity risks.
5. **Define the figure strategy.** Load `references/figures.md` and invoke `nature-figure` before
   planning figures. Define figure data, outputs, exports, and QA. If no figures are planned, record
   an explicit no-figure strategy.
6. **Approve and document.** Present the integrated design for approval. In an empty directory,
   initialize only version control and the gate-artifact path needed to write the specification.
   Write and self-review the specification, commit it, and obtain user review before implementation.
   Do not create target `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or a shared top-level simplifier.
7. **Plan, scaffold, and configure.** Invoke `superpowers:writing-plans`, then load every applicable
   reference, including `references/bootstrap.md`, and create only the approved repository.
8. **Integrate the selected host.** After the core scaffold, follow the profile installation
   procedure in `references/prerequisites.md`. With no host selected, write no profile and verify
   independent simplifier resolution; otherwise future code changes remain blocked subject to Review
   waivers.
9. **Run the selected-host smoke test.** Follow `references/prerequisites.md`, including the
   delegated reviewer's own resolution check. Report unavailable checks as manual boundaries.
10. **Inspect and report.** Inspect generated artifacts and report assumptions and manual or
    external boundaries.

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

Maintain this reporting checklist throughout bootstrap; do not create a repository file for it. When
explaining or planning before answers exist, reproduce the record with undecided fields marked
pending, then ask exactly one next question. A promise to cover the topics does not satisfy the
record:

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

Assess read-only. Prioritize migration by data safety and provenance, then reproducibility and
contracts, then convenience. Apply the appropriate gate to each accepted migration step.

## Governed work

The named gates, interview questions, consultation points, capability blockers, and unclear
destruction targets are the only stops for user input. A capability blocker exists only after a
resolution, invocation, or launch attempt fails in this session. An assumed limit is not a blocker.
Complete every authorized step, including long runs; do not leave a stated next step undone. Before
asking a mid-task question, finish work that does not depend on the answer.

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
`references/analysis.md` prescribes and label its post hoc status. Results are presented when their
artifacts are committed, pushed, or shared. Complete all required records before the first such
action. Records, specifications, and plans must support resumption from the repository alone: exact
values, accepted and rejected decisions, and open questions.

### Independent critique

Obtain critique findings before deciding or implementing work that depends on a scientific judgment.
This applies at every gate, including standard-gate covariate sets, thresholds, and model settings.
`references/analysis.md` owns the procedure, batching, and disposition of findings.

### Change discipline

Keep changes narrow and follow the repository's declared interfaces. Tests and documentation change
with behavior. Validate inputs before expensive computation. If the approved scope expands, return
to the applicable gate. Report a pre-existing bug, performance concern, or behavior the task does
not mention as a follow-up in the completion report; do not fix it in this change unless the
requested behavior cannot work without it. Add tests only where the task or the repository's test
practice calls for them, sized like the neighboring tests, and never commit scratch checks. Edit
files in place; rewrite a whole file only when most of it changes.

### Mid-implementation consultation

When the approved plan leaves an implementation fork unresolved, stop and consult before writing
dependent code. This includes a test that cannot pass as designed, an incompatible contract, a
failed approach, or an unforeseen design choice. Present two to four concrete options with
consequences through the host's question tool, or plain enumerated options, and wait for a choice.
For options that differ in code, write small throwaway scripts under `tmp/`, never committed or
under `results/` or `data/`. Delete the scripts after the choice. Plan approval does not cover a
choice the plan never made. Later records cannot replace approval; critique and simplifier passes
never choose the option. Escalate design-level forks to the full gate.

### Destruction

Destruction is never implied. Deleting files, dropping columns or rows, overwriting existing
results, resetting or rewriting Git history, and force-pushing require explicit authorization. First
resolve the exact narrow targets and state what would be destroyed and whether it is recoverable; if
either is unclear, stop and ask.

Authorized regeneration already covers replacement of its declared outputs without another
confirmation. Verify the approved code, configuration, and exact output paths first. This permission
excludes raw inputs, unrelated files, and broader cleanup. Apply the transactional output rule under
Safety floor.

### Simplifier review

After changing code or tests, launch an independent review agent through the host's exact
`research-code-simplifier` profile. Run it after each completed plan task and before starting the
next; an end-of-plan pass does not satisfy this cadence. Outside a plan, run it once per coherent
unit of work. The profile must invoke this skill and owns cleanup scope, permitted behavior changes,
and verification. Re-run covering tests after its edits. Apply Review waivers if a required
capability fails.

Before inspecting the delegated diff, the reviewer reports this additional resolution record, with
every slot filled:

```text
Simplifier profile: research-code-simplifier
Host-native resolver: <host and resolver that returned it>
Resolved profile path: <path>
Invoked research-repo-standard from: <source provenance>
```

### Review waivers

Only when resolution, invocation, or independent-agent launch fails in this session may the user
explicitly waive or defer a scientific critique or simplifier pass. Otherwise dependent work waits.
Record the failed capability, attempted check, user authorization, and scope in the completion
report. For a scientific-review waiver, also record these in `docs/LAB_NOTEBOOK.md` before affected
results. Continue authorized work within that scope; a waiver does not cover later tasks or other
reviews. A self-pass never substitutes for independent review. Never use a review waiver to bypass
scientific authorization, data safety, or validation, or to claim a review or host smoke test
passed.

## Completion

Run applicable formatting, lint, type, test, and verification interfaces. Inspect generated tables,
figures, profiles, and provenance manifests; passing exit codes alone do not verify artifacts. Check
`git status` and confirm raw inputs and unrelated work are unchanged.

The completion report covers the whole task and stands on its own. State what changed, what was
verified and how, what was skipped and why, and every manual or inaccessible boundary. Use plain,
literal sentences in notebook entries, README text, and reports. Finish reviews, artifact
inspection, and verification before claiming completion, except for recorded review waivers. Host
integration requires the real smoke test in `references/prerequisites.md`; an unavailable check
remains a manual boundary.
