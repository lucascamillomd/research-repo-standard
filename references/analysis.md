# Reference: scientific analysis contract

`AGENTS.md` owns the normative portable policy. This reference is its procedural expansion for
planning and reporting confirmatory analyses.

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

Operationalize these fields in `config/analysis.yaml` under the configuration contract.

`AGENTS.md` floor items 4–5 apply.

## Statistical reporting

`AGENTS.md` defines required inferential reporting. Recommended additions, when applicable, are
center and spread definitions and practical or scientific interpretation.

## Independent critique

Where `AGENTS.md` requires an independent critique, obtain it before deciding or implementing work
that depends on the judgment. One critique covers one design or coherent batch of decisions — do not
open a separate critique per individual judgment, and during bootstrap the single design-stage
critique is that batch. The critique may run concurrently with work that does not depend on the
judgment under review; only dependent work waits for its findings.

An independent review agent, separate from the implementing agent, applies
`scientific-critical-thinking` (KDense `k-dense-ai/scientific-agent-skills`) to the proposed
approach and the relevant repository context, and returns findings **without implementing the
task**. A working agent's self-critique is not a substitute.

If `scientific-critical-thinking` is missing, cannot be resolved, or cannot be invoked, stop the
critique-triggering work and report the exact blocker; unrelated work may continue. If the skill
resolves but an independent review agent is unavailable, stop before deciding or implementing the
dependent judgment and report the exact blocker. Only work that depends on that judgment is blocked;
unrelated work may continue.

A skill is guidance, not evidence. Validate code and results against primary documentation, known
examples, scientific invariants, and the study design.
