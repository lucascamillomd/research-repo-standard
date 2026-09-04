# Reference: scientific analysis contract

This contract owns confirmatory analysis planning, statistical reporting, and the independent
critique procedure.

## Analysis-plan template

Before implementing a confirmatory analysis, create or update `docs/ANALYSIS_PLAN.md` with every
field of this template:

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
docs/LAB_NOTEBOOK.md entries and authorization:
```

Record researcher-editable analysis decisions in `config/analysis.yaml`. The plan explains the
science; the configuration holds the validated executable values. After an approved post hoc change,
update the plan and append the `docs/LAB_NOTEBOOK.md` entry before presenting the result, and label
its post hoc status.

## Statistical reporting

For every inferential result, report the effect estimate and unit, uncertainty interval, sample size
and analysis population, exact test or model, assumptions and diagnostics, and multiplicity strategy
or a justification for its absence. A p-value alone is insufficient.

Where they apply, also report the definition of center and spread, missingness and attrition through
the analysis population, the practical or scientific interpretation, and whether replicates are
technical or biological. Tie sensitivity and subgroup results to their prespecified role.

For predictive work, verify that preprocessing, normalization, imputation, feature selection, and
tuning saw only the data permitted by the training design. Report the evaluation population,
resampling or split strategy, metrics with uncertainty, and any external-validation boundary.

## Independent critique

Obtain the required critique before deciding or implementing work that depends on the scientific
judgment under review. One critique covers one design or coherent batch of decisions, not one
critique per field of the same design. During bootstrap, the design-stage critique is one such
batch.

An independent agent, separate from the implementing agent, invokes exact
`scientific-critical-thinking`, reads the relevant repository context, and returns findings without
implementing the task. Work that does not depend on the judgment may proceed beside the critique;
dependent decisions wait for its findings. Incorporate each material finding into the design or
disposition it with a recorded rationale.

If the skill cannot resolve or invoke, or an independent agent cannot launch, report the attempted
check and stop dependent work. Apply SKILL.md's Review waivers procedure if the user authorizes an
exception. Independent work may continue.

A skill is guidance, not evidence. Validate code and results against primary documentation, known
analytical examples, scientific invariants, diagnostics, and the approved study design.
