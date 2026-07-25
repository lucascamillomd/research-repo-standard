<!-- standard_version: 2026.07.25 -->

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

Label every analysis exploratory or confirmatory. An exploratory result must not
silently become confirmatory. Record post hoc changes and their rationale in
`docs/DECISIONS.md` or the lab notebook *before* presenting them as part of the final
workflow.

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
necessary, use seed `42`, propagate it explicitly, and record it in configuration.

Do not claim complete determinism when GPU kernels, parallel algorithms, external
APIs, or upstream software remain nondeterministic. Name the boundary instead.

## Independent critique

When work turns on a scientific judgment — study design, estimand, statistical method,
alternative explanations, the scope of a claim — request an independent critique.

A separate subagent applies `scientific-critical-thinking` (KDense
`k-dense-ai/scientific-agent-skills`) to the proposed approach and the relevant
repository context, and returns findings **without implementing the task**. The
critique is advisory: weigh it against the evidence, the task scope, and the user's
instructions.

Routine documentation, formatting, plumbing, and faithful implementation work do not
need one. If the skill or a review subagent is unavailable, continue and note the
limitation only when it materially affects confidence in the work.

A skill is guidance, not evidence. Validate code and results against primary
documentation, known examples, scientific invariants, and the study design.

## Related workflow skills

Use the smallest relevant set, selected from the actual data and method:

- `experimental-design` — study and experiment planning
- `statistical-analysis` — inferential analysis
- `statistical-power` — sample size and power
- `exploratory-data-analysis` — structured data exploration
