# Reference: scientific analysis contract

This contract defines confirmatory analysis planning, statistical reporting, and the independent
scientific critique procedure.

## Analysis-plan template

Before implementing a confirmatory analysis, create or update `docs/ANALYSIS_PLAN.md` with this
complete template:

```text
Research question and hypothesis:
Analysis status (confirmatory or exploratory):
Population and sampling frame:
Exposure, intervention, predictor, or comparison:
Outcome and measurement time:
Estimand and unit:
Inclusion and exclusion criteria:
Covariates and rationale:
Missing-data policy:
Transformations and units:
Primary test or model:
Diagnostics and assumption checks:
Multiplicity strategy or justification for its absence:
Sensitivity and subgroup analyses:
Expected tables and figures:
Decision log entries and authorization:
```

Translate stable researcher-editable analysis decisions into `config/analysis.yaml`; keep the plan
as the scientific explanation and the configuration as the validated executable values. After an
approved post hoc change, update the plan and decision log before presenting the result and label
its status honestly.

## Statistical reporting

For every inferential result, report the effect estimate and unit, uncertainty interval, sample size
and analysis population, exact test or model, assumptions and diagnostics, and multiplicity strategy
or a justification for its absence. A p-value alone is insufficient.

When applicable, also report the definition of center and spread, missingness and attrition through
the analysis population, practical or scientific interpretation, and the distinction between
technical and biological replicates. Tie sensitivity and subgroup results back to their prespecified
role.

For predictive work, verify that preprocessing, normalization, imputation, feature selection, and
tuning saw only the data permitted by the training design. Report the evaluation population,
resampling or split strategy, metrics with uncertainty, and any external-validation boundary.

## Independent critique

Obtain required critique before deciding or implementing work that depends on the scientific
judgment under review. One critique covers one design or coherent batch of decisions. Do not launch
a separate critique for every field in the same design. During bootstrap, the single design-stage
critique covers the proposed question, claim, design, estimand, and major validity risks as one
coherent batch.

An independent agent, separate from the implementing agent, invokes exact
`scientific-critical-thinking`, reads the relevant repository context, and returns findings without
implementing the task. The critique may run beside work that does not depend on the judgment;
dependent decisions wait for its findings. Incorporate material findings into the design or
explicitly disposition them with rationale.

If `scientific-critical-thinking` is missing, cannot be resolved, or cannot be invoked, report the
exact capability blocker and stop only the critique-dependent work. If the skill resolves but the
host cannot provide an independent review agent, report the independent-agent blocker and stop only
the dependent judgment. A self-critique does not replace either missing capability.

A skill is guidance, not evidence. Validate code and results against primary documentation, known
analytical examples, scientific invariants, diagnostics, and the approved study design.
