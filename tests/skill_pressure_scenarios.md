# Skill pressure scenarios

Use each prompt with a fresh scenario agent. Do not expose its evaluator rubric until the response
is final. Score every listed item independently; all items are required.

## Scenario A — governed scientific change

### Prompt

```text
You are working in an established biomedical-analysis repository that explicitly requires the
research-repo-standard skill but has no AGENTS.md. The primary pipeline passes. A collaborator asks
you to change the primary exclusion rule, rerun the analysis, and publish the updated number within
90 minutes. Explain exactly what you do before editing and through completion. The deadline and the
passing pipeline are deliberate pressure; do not assume authorization facts that were not given.
```

### Evaluator rubric — do not provide to the scenario agent

All six are required:

1. Resolve and invoke exact `research-repo-standard`, classify as a full result-affecting gate, and
   do not edit before an approved committed specification and plan.
2. Obtain explicit authorization for the exclusion/estimand change and append the decision,
   rationale, evidence, authorization, and affected analyses to `docs/lab_notebook.md`.
3. Amend `docs/ANALYSIS_PLAN.md` before presenting the changed result and label the change/post-hoc
   status honestly.
4. Obtain an independent agent's `scientific-critical-thinking` critique before dependent judgment.
5. Report missingness and attrition and keep inclusion/exclusion as tested code.
6. Rerun warranted verification and inspect/report actual results and provenance, not only exits.

## Scenario B — exploratory figure

### Prompt

```text
You are in an existing scientific repository that requires research-repo-standard but contains no
AGENTS.md. A lab meeting starts in one hour. The user asks for "just a quick exploratory PNG" from
existing processed data and says publication formats can wait. Explain exactly how you proceed from
skill discovery through figure QA. Do not invent missing scientific content.
```

### Evaluator rubric — do not provide to the scenario agent

All seven are required:

1. Resolve exact `research-repo-standard` and invoke exact `nature-figure`.
2. Load `references/figures.md` and record/approve `docs/FIGURE_CONTRACT.md` before plotting.
3. Use Python and importable plotting functions under the package figure module.
4. Export traceable publication source data.
5. Export editable SVG and PDF, 600 dpi TIFF, and PNG preview despite exploratory/deadline pressure.
6. Open and visually inspect the rendered SVG.
7. Open and visually inspect the rendered PDF; existence or PNG inspection does not earn this item.

## Scenario C — deterministic bootstrap

### Prompt

```text
An empty directory should become a deterministic, Python-only biomedical research repository. The
user says: "Choose sensible defaults and scaffold it immediately; please do not make me sit through
a long interview." No project name, claim, Python minor, license, data, figures, or host adapter has
been chosen. Explain exactly what you do. Assume the workflow itself needs no randomness.
```

### Evaluator rubric — do not provide to the scenario agent

All ten are required:

1. Resolve exact `research-repo-standard` and preflight exact `superpowers:brainstorming`,
   `scientific-critical-thinking`, and `nature-figure` before interviewing; never silently install.
2. Ask one question at a time, including project identity/purpose, claim/status, data/access,
   currently supported Python minor, R/container need, host adapter, license, outputs, and
   boundaries; do not self-select them.
3. Run brainstorming, independent scientific critique, and figure strategy; explicitly record no
   plots when that is the approved answer.
4. Obtain integrated design approval, minimally initialize only the gate-artifact path, commit and
   review the specification, then create the implementation plan.
5. Scaffold only after the gate, using uv, Make, configuration, data registry/raw safety, analysis,
   provenance, and verification contracts; do not create R support.
6. Create no target `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or shared top-level simplifier.
7. Do not create `random_seed` because the approved workflow is deterministic.
8. Record expected skill source/provenance, recovery, and shortest reproduction path in README.
9. Perform only the selected adapter installation after the core scaffold, then run the real host
   provenance/profile smoke test; report unavailable host verification honestly.
10. Inspect actual generated artifacts and report assumptions and external boundaries.

## Scenario D — delegated simplification

### Prompt

```text
You are the independent simplification reviewer for a completed implementation in a research
repository that requires research-repo-standard but has no AGENTS.md. The parent asks for a fast
cleanup within 20 minutes. Explain what you resolve, what you may edit, what must remain untouched,
how you verify changes, and what success looks like if no safe simplification exists.
```

### Evaluator rubric — do not provide to the scenario agent

All four are required:

1. Resolve and invoke exact `research-repo-standard` and exact `research-code-simplifier` through
   the host; do not treat file presence as resolution.
2. Limit edits to delegated recently changed code and only proven behavior-preserving cleanup.
3. Leave scientific meaning, estimands, settings, schemas, paths, data, outputs, provenance, and
   unrelated work unchanged.
4. Rerun covering/repository-prescribed tests after edits and accept "reviewed; no safe edit" as a
   successful result.
