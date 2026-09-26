# Reference: governed work

This reference owns adoption assessment, change records, implementation consultation, destruction,
simplifier cadence, and review waivers. SKILL.md owns change classification and the safety floor.

## Adoption

Assess adoption only when requested. Work read-only, walking the safety floor and each applicable
reference contract. Mark every item compliant, a gap, or not applicable and cite paths, settings,
tests, or missing artifacts as evidence. Use `references/configuration.md` for configuration
migration and `references/prerequisites.md` for legacy integration detection. Prioritize migration
by data safety and provenance, then reproducibility and contracts, then convenience. Apply the
appropriate gate to each accepted migration step; assessment does not authorize migration.

## Context and scope

Read applicable local instructions and the affected project's documentation, configuration, and
nearby tests. Identify the scientific claim, stage, inputs, outputs, and contracts relevant to the
change. Report assumptions that materially affect scientific meaning, interfaces, data safety, or
scope. Do not fix an unrelated defect unless the requested behavior cannot work without it; report
it as follow-up. Size tests to the behavior and repository practice, and keep scratch checks out of
commits.

## Authorization and records

The user's request or a prior approved design can authorize a change. Preserve that authorization
across the task; do not seek a second confirmation for the same action. Authorization does not
expand scope, grant external permissions, or settle a new scientific decision.

For full- and standard-gate changes, append the decision, rationale and evidence, authorization
source, affected work, and any superseded entry to `docs/LAB_NOTEBOOK.md` before presenting results.
Before results affected by a changed analysis decision, amend `docs/ANALYSIS_PLAN.md` as
`references/analysis.md` prescribes and label post hoc status. Results are presented when their
artifacts are committed, pushed, or shared. Records must support resumption from the repository:
exact values, accepted and rejected decisions, and remaining questions. Mechanical prose edits need
no scientific notebook entry.

## Implementation choices

Choose routine implementation details within the approved scientific design and interfaces, such as
equivalent data structures or loop versus comprehension. Investigate failures and fix those caused
by the requested change without a new permission round.

Consult before dependent work when a choice changes scientific meaning, declared contracts, scope,
external commitments, or destructive targets. A missing data-contract column is such a fork;
ordinary implementation freedom is not. Explain the material options and their consequences, ask
only for the decision needed, and continue independent work. Use small scratch experiments when
needed to make options reviewable; keep them outside data and results, and remove them afterward.
Never relax validation to make a failed approach pass. Escalate design-level changes to the full
gate. Record the chosen scientific decision before affected results; a later record cannot supply
missing authorization.

## Destruction

Deletion, dropping columns or rows, overwriting results, rewriting Git history, and force-pushing
require explicit authorization for the narrow targets. Resolve what would be destroyed and whether
it is recoverable before acting. A direct request naming that operation and its exact targets can
supply authorization; ask when the targets or permission are unclear.

Authorized regeneration covers replacement of its declared outputs without another confirmation.
Verify the approved code, configuration, and exact output paths first. This excludes raw inputs,
unrelated files, and broader cleanup. Apply SKILL.md's transactional-output invariant.

## Simplifier review

After code or test changes, obtain one independent `research-code-simplifier` review per coherent
change before delivery. Related plan tasks may share a review; task numbering alone does not set the
cadence. Review earlier when later work depends on a material interface or high-risk change, or when
the approved plan explicitly requires that boundary. A prose-only change needs no simplifier review.

Launch the exact profile through the host using `references/prerequisites.md`. The canonical profile
owns cleanup scope, supported-use boundaries, and verification. Review the resulting diff and rerun
covering checks after its edits. A review with no justified edit succeeds. Do not silently omit the
final required pass because work was batched.

## Review waivers

Only when resolution, invocation, or independent-agent launch fails in this session may the user
explicitly waive or defer a scientific critique or simplifier pass. Otherwise dependent work waits.
Record the failed capability, attempted check, user authorization, and scope in the completion
report. For a scientific-review waiver, also record these in `docs/LAB_NOTEBOOK.md` before affected
results. Continue authorized work within that scope; a waiver does not cover later tasks or other
reviews. A self-pass never substitutes for independent review. Never use a review waiver to bypass
scientific authorization, data safety, or validation, or to claim a review or host smoke test
passed. A capability blocker requires an actual failed attempt, not an assumed limit.
