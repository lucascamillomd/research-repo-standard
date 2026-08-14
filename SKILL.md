---
name: research-repo-standard
description:
  The operating standard for repositories that support a scientific analysis, study, or paper. Use
  when bootstrapping such a repository or when planning, changing, reviewing, or reporting its
  scientific data, configuration, analysis, figures, code, workflow, or reproducibility contracts.
  Not for general-purpose software projects or scratch work that will never support a scientific
  claim.
---

# Research repository standard

## Applicability and precedence

Apply this skill to a repository whose purpose is, or is intended to become, the evidence behind a
scientific analysis, study, paper, or claim. Do not apply it to a general-purpose software project,
teaching repository, or scratch exploration that will never support a claim.

Use **bootstrapping mode** when creating a research repository. Use **governed-work mode** for work
in an existing research repository. In both modes, explicit user instructions and legal,
institutional, journal, and data-use requirements take precedence over this standard.

Local repository instructions may add stricter or project-specific requirements. They do not
silently weaken this skill's safety floor. When two applicable instructions conflict, surface the
conflict and follow the higher-precedence requirement.

## Required skills and modification gates

Resolve required skills by exact name through the current host's native resolver; file presence
alone is not resolution. Do not silently install, imitate, or substitute a required skill. A missing
or unverifiable skill blocks only the work that depends on it. Load `references/prerequisites.md`
when resolution, installation, recovery, or host verification is in scope.

Classify every requested file modification into one path. When uncertain, use the full gate.

- **Full gate:** Result-affecting or contract-affecting changes, including scientific decisions,
  analysis configuration, data contracts, pipeline structure, figures, features, and this standard's
  rules. Invoke `superpowers:brainstorming`. Do not implement until the approved specification is
  committed and reviewed and the plan is ready. Direct and delegated implementation inherits the
  completed gate; reopen it at design if scope expands.
- **Light path:** Mechanical, non-result-affecting changes such as documentation, comments,
  formatting, behavior-preserving renames or tested refactors, and tests that do not change
  behavior. State the intent, files, and why the change is non-result-affecting; obtain one
  confirmation, then implement without specification or plan artifacts. Escalate to the full gate if
  results, interfaces, or contracts may change.
- **No gate:** Read-only explanation, inspection, diagnosis, status reporting, and regeneration of
  declared outputs from an already approved workflow. Questions ask for answers, not edits; answer
  first and wait for an explicit change request.

Load every reference whose semantic trigger matches the requested work. Read the selected reference
completely before dependent decisions or edits.

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
   their rationale in `docs/lab_notebook.md` before presenting the result as planned.
5. **No silent complete-case filtering.** Report missingness before exclusions or imputation.
   Inclusion and exclusion criteria are code, not prose.
6. **Use Seed 42 only when randomness is unavoidable.** Propagate it explicitly and record it in
   configuration. Prefer deterministic algorithms when scientifically equivalent, and declare
   nondeterministic boundaries honestly. Do not invent a seed field for a fully deterministic
   workflow.
7. **Outputs are written transactionally.** Build a temporary artifact, validate it, and only then
   replace the declared destination. A failed run must not leave output that looks complete.
8. **Required skills are gates.** A missing skill blocks only its dependent work.
9. **Configuration has one owner.** Stable researcher-editable scientific or result-affecting
   settings live in versioned YAML, never hidden Python globals or defaults. Derived internal paths
   stay in `paths.py`; secrets and machine-specific roots stay in environment variables. Unknown,
   missing, or duplicate-owned values fail before computation, and an unrecorded result-affecting
   override fails provenance verification. Non-setting implementation constants remain in code.

## Bootstrapping sequence

1. **Preflight once.** Before the interview, resolve the exact names `superpowers:brainstorming`,
   `scientific-critical-thinking`, and `nature-figure` through the current host. Use
   `references/prerequisites.md` for authorized recovery. Repeat only if the agent session changes.
2. **Interview one question at a time.** Ask the questions below, pursue conditional follow-ups, and
   do not silently choose a Python version, seed, adapter, license, or scientific default. A request
   to keep the interview short changes the cadence, not the required coverage: never bundle the
   numbered topics or stop after only the answers described as "essential."
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
   reference, including `references/bootstrap.md`, and create only the approved repository. Seed 42
   is configured only when the workflow actually uses randomness.
8. **Integrate the selected host.** If the user selected Codex or Claude Code, run
   `./adapters/codex.sh <target-repo>` or `./adapters/claude-code.sh <target-repo>` respectively. If
   none was selected, install no adapter and first establish that the host can independently resolve
   the required simplifier; otherwise future code changes are blocked.
9. **Run a real selected-host smoke test.** Through the selected host, report the resolved
   provenance of this skill and confirm that `research-code-simplifier` resolves from the expected
   installed profile. Do not simulate an unavailable resolver; report it as a manual boundary and
   follow `references/prerequisites.md` recovery guidance.

### Interview

Ask these one at a time:

1. What is the project identity and purpose, primary research question, intended scientific claim,
   and current exploratory or confirmatory status?
2. Which currently supported Python minor should the project use?
3. Which host adapter should be installed: `codex`, `claude-code`, or none?
4. Should the license be MIT, or should the repository remain unlicensed or proprietary?
5. Which datasets and access or data-use constraints are expected?
6. Which workflow stages are needed, and which processed-data checkpoint can be shared?
7. Are R or other non-Python tools required, and can they run in a pinned container? If yes, which
   runtime, version, system dependencies, and tests must it support?
8. Which tables, plots, reports, and publication targets are expected?
9. Which steps cannot be automated because of licensing, compute, or external-environment limits?
10. What can public CI verify, and what requires external inputs or tools? What is the smallest
    permitted fixture or checkpoint for each external boundary?
11. Which journal and publication type is the repository expected to support?

### Bootstrap execution record

Maintain the following required reporting slots throughout bootstrap. When asked to explain or plan
a bootstrap before the answers exist, the response first reproduces this record with undecided
fields marked pending, then asks exactly one next question. Saying only that the required topics
will be completed, or listing only the first question, does not satisfy the record. This is a
checklist, not a new repository file:

```text
Skill preflight: exact research-repo-standard provenance; exact three hard-gate skills resolved
before interview; authorized recovery or blocker
Interview decisions: identity/purpose/claim/status; data/access; supported Python minor;
R/container need; host adapter; license; outputs; automation, CI, and external boundaries
Design reviews: brainstorming outcome; independent scientific critique and dispositions; figure
strategy or explicit no-figure strategy
Gate state: integrated design approval; minimal gate-artifact initialization; committed and reviewed
specification; implementation plan ready
Core scaffold: uv and Make; configuration; data registry and raw-data safety; analysis; provenance;
verification; no unapproved R support
Forbidden target artifacts: no AGENTS.md, CLAUDE.md, CODEX.md, or shared top-level simplifier
Randomness: deterministic workflow has no seed setting; otherwise explicit Seed 42 and boundaries
README: expected skill source/provenance and recovery; shortest reproduction path
Host integration: only selected adapter, after core scaffold; real profile/provenance smoke test or
honest unavailable-host boundary
Host verification boundary: unavailable host or resolver is reported honestly; success is never
simulated
Completion: actual artifacts inspected
Assumptions and boundaries: every remaining assumption and manual or external boundary reported
```

## Governed work

Before changing anything, discover and read the local instructions that apply from the repository
root through the files in scope. Read the README, relevant project documents and configuration,
nearby tests, and `git status`. Identify the scientific claim, pipeline stage, inputs, outputs, and
affected contracts. Preserve unrelated work and surface assumptions that materially affect
scientific meaning, interfaces, data safety, or scope.

Use the routing table above broadly. Apply every loaded domain contract before dependent decisions.
Do not avoid a contract through narrower task wording.

Obtain authorization before changing an estimand, study design, statistical method or model,
inclusion or exclusion rule, missing-data policy, causal interpretation, data contract, or claim
scope. Before results are presented, append the decision, rationale and evidence, authorization
source, affected work, and any superseded entry to `docs/lab_notebook.md`. A separate review agent
must apply `scientific-critical-thinking` to those scientific judgments and return findings without
implementing them.

Keep changes narrow and follow the repository's declared interfaces. Tests and documentation change
with behavior. Validate inputs before expensive computation, keep raw data immutable, and write
declared outputs transactionally. If the approved scope expands, return to the applicable gate.

Destruction is never implied. Deleting files, dropping columns or rows, overwriting existing
results, resetting or rewriting Git history, and force-pushing require explicit authorization. First
resolve the exact narrow targets and state what would be destroyed and whether it is recoverable; if
either is unclear, stop and ask.

After changing code or tests, launch an independent review agent through the current host's exact
`research-code-simplifier` profile. It must invoke this skill, load the references relevant to the
changed code, preserve behavior, and return or apply only simplifications within the approved scope.
Re-run covering tests after any simplifier edit. If the profile cannot be resolved or an independent
agent cannot be launched, dependent completion is blocked; do not substitute an unreviewed
self-pass.

Before inspecting the delegated diff, the reviewer reports this resolution record:

```text
Standard skill: exact research-repo-standard; host-native resolver; source provenance; invoked
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
simplification pass, artifact inspection, or verification gate remains unresolved.
