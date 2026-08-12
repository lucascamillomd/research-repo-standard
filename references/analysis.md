<!-- standard_version: 2026.08.11 -->

# Reference: scientific analysis contract

Read when planning or reporting a confirmatory analysis. `AGENTS.md` states the rules;
this expands the templates.

## Analysis plan

Before implementing a confirmatory analysis, create or update `docs/ANALYSIS_PLAN.md`:

```text
Research question and hypothesis:
Population and sampling frame:
Exposure, intervention, predictor, or comparison:
Outcome:
Estimand:
Inclusion and exclusion criteria:
Covariates and rationale:
Missing-data policy:
Transformations and units:
Primary model:
Diagnostics and assumption checks:
Multiplicity strategy:
Sensitivity and subgroup analyses:
Expected tables and figures:
```

Every stable value that operationalizes this plan has an explicit field in
`config/analysis.yaml`; prose does not substitute for executable configuration. The
loader rejects missing or unknown scientific fields, and runs do not replace them
through environment variables or Python defaults.

Label every analysis exploratory or confirmatory. An exploratory result must not
silently become confirmatory. Record post hoc changes and their rationale in
`docs/lab_notebook.md` *before* presenting them as part of the final workflow.

## Statistical reporting

Every inferential result reports, as applicable:

- effect estimate and its unit
- uncertainty interval
- sample size and analysis population
- center and spread definitions
- the exact test or model
- model assumptions and diagnostics
- multiple-comparison method, or a justification for its absence
- practical or scientific interpretation

P-values alone are insufficient.

Report missingness before exclusions or imputation. No silent complete-case filtering.
Inclusion and exclusion criteria are testable code, with an attrition table or flow
record when appropriate.

## Predictive analyses

Define train, validation, and test roles explicitly. Test that preprocessing,
normalization, imputation, feature selection, and tuning use only permitted training
data — leakage is a code-level bug with a scientific consequence, so it deserves a
test rather than a comment.

## Determinism

Prefer deterministic algorithms when scientifically equivalent. When randomness is
necessary, declare `random_seed: 42` explicitly in `config/analysis.yaml`, pass it
through the validated typed configuration, and propagate it to every stochastic
component. Do not repeat `42` as a module-level Python setting.

Do not claim complete determinism when GPU kernels, parallel algorithms, external
APIs, or upstream software remain nondeterministic. Name the boundary instead.

## Independent critique

Obtain an independent critique when defining or changing any of: an estimand, a
study design, a statistical method or model choice, inclusion or exclusion rules, a
missing-data policy, a causal interpretation, or the scope of a claim. Obtain it
before deciding or implementing work that depends on the judgment. One critique
covers one design or coherent batch of decisions — do not open a separate critique
per individual judgment, and during bootstrap the single design-stage critique is
that batch. The critique may run concurrently with work that does not depend on the
judgment under review; only dependent work waits for its findings.

A separate review subagent, independent of the implementing agent, applies
`scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) to the proposed approach and the relevant
repository context, and returns findings **without implementing the task**. The
skill's availability and obtaining the independent critique when triggered are
mandatory; the conclusions are advisory. Findings may be rejected based on evidence,
the task scope, or the user's instructions, but the critique may not be skipped. A
working agent's self-critique is not a substitute.

Routine documentation, formatting, plumbing, and faithful implementation work do not
require a critique unless they introduce scientific judgment.
`scientific-critical-thinking` is a hard prerequisite scoped to critique-triggering
work. If the skill is missing, cannot be resolved, or cannot be invoked, stop the
work that meets a critique trigger and report the exact blocker; file-changing work
outside the critique triggers may continue. If the skill resolves but an independent review subagent is unavailable
when scientific judgment is required, stop before deciding or implementing the
dependent judgment and report the exact blocker. Only work that depends on that
judgment is blocked; unrelated work may continue.

A skill is guidance, not evidence. Validate code and results against primary
documentation, known examples, scientific invariants, and the study design.

## Related workflow skills

Use the smallest relevant set, selected from the actual data and method:

- `experimental-design` — study and experiment planning
- `statistical-analysis` — inferential analysis
- `statistical-power` — sample size and power
- `exploratory-data-analysis` — structured data exploration
