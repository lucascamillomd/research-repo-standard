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

Apply this skill to a repository whose purpose is, or is intended to become, the evidence behind a
scientific analysis, study, paper, or claim. Do not apply it to a general-purpose software project,
teaching repository, or scratch exploration that will never support a claim.

Use **bootstrapping mode** when creating a research repository. Use **adoption mode** when an
existing repository was not created under this standard or its compliance is unknown. Use
**governed-work mode** for work in a research repository that already follows it. In every mode,
explicit user instructions and legal, institutional, journal, and data-use requirements take
precedence over this standard.

Local repository instructions may add stricter or project-specific requirements. They do not
silently weaken this skill's safety floor. When two applicable instructions conflict, surface the
conflict and follow the higher-precedence requirement.

## Required skills and modification gates

Resolve required skills by exact name through the current host's native resolver; file presence
alone is not resolution. Do not silently install, imitate, or substitute a required skill. A missing
or unverifiable skill blocks only the work that depends on it. Load `references/prerequisites.md`
when resolution, installation, recovery, or host verification is in scope.

Classify every requested file modification into one path by what the change means scientifically,
not by which file carries the edit: a configuration value that changes an estimand, an inclusion or
exclusion rule, or a missing-data policy is a design-level change. Ceremony scales with what the
change can break, so when uncertain, use the full gate.

- **Full gate:** Design-level changes — estimands, study design, statistical methodology, inclusion
  or exclusion rules, missing-data policy, causal interpretation, data contracts, pipeline
  structure, claim scope, and this standard's rules. Invoke `superpowers:brainstorming`. Do not
  implement until the approved specification is committed and reviewed and the plan is ready. Direct
  and delegated implementation inherits the completed gate; reopen it at design if scope expands.
- **Standard gate:** Result-affecting changes below design level, such as analysis configuration
  values, figure changes, and feature additions within the already approved design. Obtain explicit
  authorization for the change and append to `docs/LAB_NOTEBOOK.md` the entry described under
  Governed work before the results are presented. Cover the change with tests. No specification or
  plan artifact is required; escalate to the full gate the moment a design-level item is in play.
- **Light path:** Mechanical, non-result-affecting changes such as documentation, comments,
  formatting, behavior-preserving renames or tested refactors, and tests that do not change
  behavior. State the intent, files, and why the change is non-result-affecting; obtain one
  confirmation, then implement without specification or plan artifacts. Escalate to the standard
  gate if results may change, and to the full gate if interfaces or contracts may change.
- **No gate:** Read-only explanation, inspection, diagnosis, status reporting, and regeneration of
  declared outputs from an already approved workflow. Questions ask for answers, not edits; answer
  first and wait for an explicit change request.

## Reference routing

In every mode, load each reference whose trigger matches the requested work and read it completely
before dependent decisions or edits.

| Reference                     | Load when                                                                                                              |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `references/prerequisites.md` | a required capability is unresolved, installation or recovery is requested, or host integration must be verified       |
| `references/bootstrap.md`     | creating repository structure, tool configuration, CI, the Make interface, or initial project documentation            |
| `references/configuration.md` | classifying, loading, using, changing, or overriding settings, paths, or provenance                                    |
| `references/data.md`          | acquiring, registering, preprocessing, describing, validating, or contracting data                                     |
| `references/analysis.md`      | scientific planning, estimands, design, inclusion, missingness, modeling, implementation, interpretation, or reporting |
| `references/figures.md`       | planning a figure, writing plotting code, changing figure outputs, or performing QA                                    |

## Safety floor

These requirements do not bend for convenience, deadlines, or failing checks. Stop and report a
blocker rather than weakening one.

1. **Raw data is immutable.** Nothing under `data/raw/` is ever modified. Corrections,
   harmonization, exclusions, and derived variables create new files under `data/interim/` or
   `data/processed/`. Cleanup paths are narrow, named, guarded, and incapable of reaching raw data.
2. **Never weaken a gate to make it pass.** Reproducibility, provenance, and validation checks exist
   to fail. A failing check is information, not an obstacle.
3. **Estimands, inclusion rules, and data contracts change only with authorization.** Record the
   authorized change before presenting results built on it.
4. **Exploratory never silently becomes confirmatory.** Label analyses. Record post hoc changes and
   their rationale in `docs/LAB_NOTEBOOK.md` before presenting the result as planned.
5. **No silent complete-case filtering.** Report missingness before exclusions or imputation.
   Inclusion and exclusion criteria are code, not prose.
6. **Randomness is declared, never invented.** When randomness is unavoidable, the seed is explicit
   recorded configuration — Seed 42. A deterministic workflow gets no seed. Prefer deterministic
   algorithms when scientifically equivalent, and declare nondeterministic boundaries honestly.
7. **Outputs are written transactionally.** Build a temporary artifact, validate it, and only then
   replace the declared destination. A failed run must not leave output that looks complete.
8. **Configuration has one owner.** Every result-affecting setting has exactly one declared owner.
   Unknown, missing, duplicate-owned, or unrecorded result-affecting values fail loudly before
   computation rather than defaulting silently, and a result-affecting value is never hidden in a
   code default.

## Bootstrapping sequence

1. **Preflight once.** Before the interview, resolve the `superpowers` package as a whole — its
   `superpowers:brainstorming` and `superpowers:writing-plans` skills are both used — and the exact
   names `scientific-critical-thinking` and `nature-figure` through the current host. Use
   `references/prerequisites.md` for authorized recovery. Repeat only if the agent session changes.
2. **Interview one question at a time.** Ask the questions below, pursue conditional follow-ups, and
   do not silently choose a seed, adapter, license, or scientific default. When the user explicitly
   asks for brevity, the mechanical topics — host adapter, license — may be presented together as
   concrete proposed defaults that still require explicit confirmation. Batching is permitted for
   those two topics only; every other numbered topic below stays one at a time. Nothing is ever
   chosen silently.
3. **Design with the full gate.** Invoke `superpowers:brainstorming`, explore alternatives, and keep
   implementation blocked while the design is unsettled.
4. **Critique the science independently.** Launch a separate review agent that applies
   `scientific-critical-thinking` to the question, claim, study design, estimand, and major validity
   risks without implementing. Incorporate or explicitly disposition every material finding.
5. **Define the figure strategy.** Load `references/figures.md` and invoke `nature-figure` before
   planning figures. Define source data, outputs, exports, and QA. If no figures are planned, record
   an explicit no-figure strategy.
6. **Approve and document.** Present the integrated design for approval. In an empty directory,
   initialize only version control and the gate-artifact path needed to write the specification.
   Write and self-review the specification, commit it, and obtain user review before implementation.
   Do not create target `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or a shared top-level simplifier.
7. **Plan, scaffold, and configure.** Invoke `superpowers:writing-plans`, then load every applicable
   reference, including `references/bootstrap.md`, and create only the approved repository.
8. **Integrate the selected host.** If the user selected Codex or Claude Code, run
   `./adapters/codex.sh <target-repo>` or `./adapters/claude-code.sh <target-repo>` respectively. If
   none was selected, install no adapter and first establish that the host can independently resolve
   the required simplifier; otherwise future code changes are blocked.
9. **Run a real selected-host smoke test.** Through the selected host, report the resolved
   provenance of this skill and confirm that `research-code-simplifier` resolves from the expected
   installed profile. Do not simulate an unavailable resolver; report it as a manual boundary and
   follow `references/prerequisites.md` recovery guidance.
10. **Inspect and report.** Inspect the actual generated artifacts — not exit codes — then report
    every remaining assumption and manual or external boundary.

### Interview

Ask these, following the cadence rules in step 2:

1. What is the project identity and purpose?
2. What is the primary research question and intended scientific claim?
3. Is the current status exploratory or confirmatory?
4. Which host adapter should be installed: `codex`, `claude-code`, or none?
5. Should the license be MIT, or should the repository remain unlicensed or proprietary?
6. Which datasets and access or data-use constraints are expected?
7. Which workflow stages are needed, and which processed-data checkpoint can be shared?
8. Are R or other non-Python tools required, and can they run in a pinned container? If yes, which
   runtime, version, system dependencies, and tests must it support?
9. Which tables, plots, reports, and publication targets are expected?
10. Which steps cannot be automated because of licensing, compute, or external-environment limits?
11. What can public CI verify, and what requires external inputs or tools? What is the smallest
    permitted fixture or checkpoint for each external boundary?
12. Which journal and publication type is the repository expected to support?

### Bootstrap execution record

Maintain the following required reporting slots throughout bootstrap. When asked to explain or plan
a bootstrap before the answers exist, the response first reproduces this record with undecided
fields marked pending, then asks exactly one next question. This is a checklist, not a new
repository file. Saying only that the required topics will be completed, or listing only the first
question, does not satisfy the record:

```text
Preflight: research-repo-standard + superpowers package + two scientific hard-gate skills resolved
before interview
Reviews: brainstorming outcome; independent scientific critique and dispositions; figure strategy
or explicit no-figure strategy
Gate: integrated design approval; minimal gate-artifact initialization; committed and reviewed
specification; implementation plan ready
Scaffold: core contracts — uv and Make, configuration, data registry and raw-data safety, analysis,
provenance, verification; no unapproved R support
Forbidden artifacts: no target AGENTS.md/CLAUDE.md/CODEX.md, no shared top-level simplifier
Randomness: no seed for a deterministic workflow; otherwise explicit Seed 42
README: expected skill source/provenance, recovery, shortest reproduction path
Host: only the selected adapter, after core scaffold; real smoke test or honest boundary
Boundaries: assumptions and manual or external boundaries reported
Completion: actual generated artifacts inspected before completion is claimed
```

## Adopting an existing repository

Enter adoption mode when the repository already exists and was not created under this standard, or
when its compliance is unknown.

Report the governed-work invocation record below first, then walk the standard item by item: the
safety floor, then each reference's contract in routing-table order. Mark every item compliant, a
gap, or not applicable, and cite file-level evidence — the paths, settings, tests, or missing
artifacts behind the verdict. For configuration items, reuse the established-repository migration in
`references/configuration.md` instead of inventing a second procedure.

Then produce a prioritized migration plan: data safety and provenance first, reproducibility and
contracts next, conveniences last. Change nothing while assessing — the review is read-only — and
take each accepted migration step through the gate its own change class requires.

## Governed work

### Governed-work invocation record

Before classifying or changing a governed repository, resolve and invoke this skill by exact name
through the host-native resolver. A prompt or repository that merely names the skill, and a file on
disk, are not resolution or invocation evidence. Report:

```text
Standard skill: exact research-repo-standard; host-native resolver; source provenance; invoked
```

### Context and scope

Before changing anything, discover and read the local instructions that apply from the repository
root through the files in scope. Read the README, relevant project documents and configuration,
nearby tests, and `git status`. Identify the scientific claim, pipeline stage, inputs, outputs, and
affected contracts. Preserve unrelated work and surface assumptions that materially affect
scientific meaning, interfaces, data safety, or scope.

Use the routing table above broadly. Apply every loaded domain contract before dependent decisions.
Do not avoid a contract through narrower task wording.

### Authorization and records

Obtain authorization before any design-level change listed under the full gate above. Before results
are presented, append the decision, rationale and evidence, authorization source, affected work, and
any superseded entry to `docs/LAB_NOTEBOOK.md`; that entry field set is the one the standard gate
above refers to. Before presenting results affected by a changed analysis decision, amend
`docs/ANALYSIS_PLAN.md` as `references/analysis.md` prescribes and label the change's post hoc
status honestly.

### Independent critique

Work that depends on a scientific judgment under review waits for an independent critique at every
gate, not only at design level: a separate review agent must apply `scientific-critical-thinking` to
that judgment and return findings without implementing them before dependent results are presented.
Standard-gate changes that embody a scientific judgment — covariate sets, thresholds, model settings
— are included. Batching one critique per coherent batch of decisions follows
`references/analysis.md`.

### Change discipline

Keep changes narrow and follow the repository's declared interfaces. Tests and documentation change
with behavior. Validate inputs before expensive computation, keep raw data immutable, and write
declared outputs transactionally. If the approved scope expands, return to the applicable gate.

### Destruction

Destruction is never implied. Deleting files, dropping columns or rows, overwriting existing
results, resetting or rewriting Git history, and force-pushing require explicit authorization. First
resolve the exact narrow targets and state what would be destroyed and whether it is recoverable; if
either is unclear, stop and ask.

### Simplifier review

After changing code or tests, launch an independent review agent through the current host's exact
`research-code-simplifier` profile. Run it once per coherent unit of delegated work, not after
every individual edit. It must
invoke this skill, load the references relevant to the changed code, preserve behavior, and return
or apply only simplifications within the approved scope. Re-run covering tests after any simplifier
edit. Only when the profile cannot be resolved or an independent agent cannot be launched may the
user explicitly waive or defer the pass; dependent completion is otherwise blocked, and the waiver
and its scope are recorded in the completion report so it is never silent. This is not a general
opt-out, and a self-pass never substitutes for the independent review.

Before inspecting the delegated diff, the reviewer reports this additional resolution record:

```text
Simplifier profile: exact research-code-simplifier; host-native resolver; resolved profile path;
invoked
```

## Completion

Before declaring completion, run the repository's applicable formatting, lint, type, test, and
verification interfaces. Inspect actual generated tables, figures, reports, profiles, and provenance
manifests rather than trusting exit codes. Check `git status` for unintended files and confirm raw
inputs and unrelated work are unchanged.

Report what changed, what was verified, what was skipped and why, and every manual or inaccessible
reproducibility boundary. Do not claim a selected host integration is complete without the real
resolver smoke test required above. Do not claim the work complete while a required critique,
simplification pass, artifact inspection, or verification gate remains unresolved and not explicitly
waived and recorded.
