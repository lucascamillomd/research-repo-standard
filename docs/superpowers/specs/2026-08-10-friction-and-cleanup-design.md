# Design: proportionate gates and structural cleanup

Date: 2026-08-10
Status: approved pending user review
Target standard_version for touched files: 2026.08.10

## Motivation

In practice, governed work is too slow. Three rules apply maximum-rigor process
regardless of stakes: every file-changing modification requires the full
brainstorm → spec → review → plan cycle; every plot, including throwaway
diagnostics, pays the full publication-figure contract; and the scientific
critique trigger ("turns on a scientific judgment") is vague enough to fire on
every borderline decision. Separately, the repository violates its own "one
source per rule" principle, promises a `make standard-check` target that is
never defined, and has no verification of its own tooling.

## Goals

1. Make process cost proportionate to scientific risk without weakening the
   floor.
2. Give every governance rule exactly one owning document.
3. Make every promised mechanism actually exist.
4. Verify the standard's own tooling.

## Non-goals (deliberately out of scope)

- Prerequisite skill version pinning or a degraded/offline mode.
- An `examples/` scaffold.
- AGENTS.md context-weight compression beyond what deduplication removes.
- Revisiting seed-42 or the `ty` type-checker choice.

## 1. Tiered modification gate

Owner: `AGENTS.md` (Required agent skills section). `SKILL.md` points to it and
no longer restates it.

Two tiers. The agent classifies; **when uncertain, use the full gate** —
mirroring the existing configuration rule "when uncertain, classify the value
as scientific."

**Full gate** — current behavior (brainstorm → design approval → spec
committed and user-reviewed → implementation plan ready) — applies to any
change that is result-affecting or contract-affecting: estimands, inclusion or
exclusion rules, statistical methods or models, `config/analysis.yaml`, data
contracts and schemas, pipeline structure, publication figures, new analyses,
new features, and changes to this standard's own rules.

**Light path** — applies to mechanical, non-result-affecting changes:
documentation and typo fixes, comment edits, lint or formatting fixes, renames
with no interface change, refactors fully covered by existing tests, and added
tests that do not change behavior. Procedure: state the intent, the files to
be touched, and why the change is non-result-affecting; obtain one user
confirmation; implement. No specification or plan artifacts are created.

**Escalation rule:** if, during a light-path implementation, the change turns
out to affect results, interfaces, or contracts, stop and reopen as a full
gate before continuing.

The existing exemptions are unchanged: read-only work is not a modification;
regenerating declared outputs of an already approved workflow opens no gate.

A short decision table with examples replaces part of the current legalistic
prose:

| Request | Path |
|---|---|
| Fix a typo in README | light |
| Rename `03_features/` to `03_scoring/` (no interface change) | light |
| Add a sensitivity analysis | full |
| Change an inclusion threshold in `config/analysis.yaml` | full |
| Rerun `make figures` unchanged | no gate |
| Explain what a stage does | no gate |

## 2. Two-tier figure contract

Owner: `AGENTS.md` (Figures section) for the rule; `references/figures.md` for
the expanded contract and QA detail.

**Publication figures** — manuscript-bound figures and analytical figures
supporting a claim — keep the entire current contract: `nature-figure`
invocation, pre-plot contract in `docs/FIGURE_CONTRACT.md`, importable
functions under `src/<package_name>/figures/`, four export formats, source
data, full QA checklist.

**Working plots** — exploratory and diagnostic plots — get a lightweight
contract:

- Python only; the R ban is unchanged.
- Determinism and seed rules apply unchanged.
- Inputs must be traceable: the plot's script or function records which
  declared dataset or artifact it read.
- Output is a single PNG under `results/diagnostics/`, organized by context
  as the project sees fit.
- No `nature-figure` invocation, no `FIGURE_CONTRACT.md` entry, no
  multi-format export, no QA checklist.

**Promotion guard** (floor-adjacent, stated with the figure rule): a working
plot never silently becomes a publication figure. Promotion means going
through the full publication contract from the pre-plot contract onward.

`results/diagnostics/` is added to the repository layout in `AGENTS.md`.
`nature-figure` remains a hard repository prerequisite (floor rule 10
unchanged); only its per-task invocation scope narrows to publication figures.
Core principle 8 ("Every plot uses Python and the full `nature-figure`
workflow") is rewritten to match: every plot uses Python; publication figures
use the full `nature-figure` workflow.

## 3. Sharpened critique triggers

Owner: `AGENTS.md` (Analysis section) for the rule; `references/analysis.md`
for the expanded procedure.

Replace "whenever the task turns on a scientific judgment" with an enumerated
trigger list. An independent critique is required when defining or changing:

- an estimand
- study design
- a statistical method or model choice
- inclusion or exclusion rules
- missing-data policy
- a causal interpretation
- the scope of a claim

Batching: one critique covers one design or coherent batch of decisions, not
one critique per individual judgment. Bootstrap keeps its single step-3
critique. The critique subagent may run concurrently with work that does not
depend on the judgment under review; only dependent work blocks. Routine
plumbing remains exempt, as today.

## 4. `standard-check` exists

`vendor.sh --check <target>`:

1. Rebuild in a temp dir exactly what a fresh vendor into `<target>` would
   produce, preserving the target's `## This repository` section.
2. Diff that against the target's actual `AGENTS.md`.
3. Report the drift (or its absence) and both version stamps.
4. Exit 0 when clean, 1 when drifted, 2 on usage error.

`references/bootstrap.md` Makefile skeleton gains:

```make
standard-check: ## Report drift against the research-repo-standard source
```

implemented as a call to `$(STANDARD_SRC)/vendor.sh --check .` with
`STANDARD_SRC ?= ~/.claude/skills/research-repo-standard`, printing a clear
"standard source not found at $(STANDARD_SRC); cannot check" message when the
skill is not installed locally.

`SKILL.md` (Drift) and `README.md` keep their promise of `make standard-check`
unchanged — the mechanism now exists.

## 5. Deduplication — one source per rule

- `AGENTS.md` is the sole owner of gate semantics and of configuration
  ownership rules.
- `SKILL.md` drops its restatements of both, keeping bootstrap-only content
  (sequence, interview, drift note) plus one-line pointers into `AGENTS.md`.
- `README.md` trims restated rules to one-liners linking to the owning file.
- Every touched file gets `standard_version: 2026.08.10`; untouched references
  keep their stamps (per-file stamps are the existing versioning model).

## 6. Skill description rewrite

Replace the ~140-word frontmatter description of `SKILL.md` with roughly:

> Operating standard for reproducible research repositories supporting a
> scientific analysis, study, or paper. Use when bootstrapping such a
> repository, and for any file-changing work in a repository that vendors this
> standard's AGENTS.md — it governs modification gates, configuration and data
> ownership, analysis planning and critique, publication figures, vendoring,
> and drift checks.

Exact wording tuned during implementation; the constraint is: what it governs,
both modes, the vendored-AGENTS.md trigger, and the handful of real trigger
topics — without the filename inventory.

## 7. bootstrap.md frontmatter

Replace the YAML frontmatter block in `references/bootstrap.md` with the same
single HTML `standard_version` comment used by every other reference, moving
its one-line description into the opening prose.

## 8. vendor.sh hardening and tests

Hardening:

- Before splicing, verify the source contains both boundary headings
  (`## This repository`, `## Using this standard`) in that order; abort with a
  clear message otherwise instead of silently producing a corrupted file.
- Stop writing `AGENTS.md.bak` into the target — the target is a git
  repository and git is the backup.

Tests: `tests/vendor_test.sh`, plain bash with temp-dir fixtures, covering:

1. Fresh vendor into an empty repo produces the source file plus symlink.
2. Re-vendor preserves a modified `## This repository` section.
3. A source missing a boundary heading aborts without touching the target.
4. `--check` exits 0 on a clean vendor, 1 after the target's copy is edited.
5. Version-stamp consistency: every file in the skill carries a
   `standard_version` and the set of stamps is reported (the test fails only
   on a missing stamp, not on intentional per-file differences).

A minimal `Makefile` in this repository: `help` (default) and `test` running
the script above.

## Affected files

- `AGENTS.md` — tiered gate + decision table, two-tier figures, critique
  triggers, `results/diagnostics/` in layout.
- `SKILL.md` — description rewrite, dedup to pointers.
- `README.md` — trim restated rules.
- `references/figures.md` — two-tier scope.
- `references/analysis.md` — trigger list, batching, concurrency.
- `references/bootstrap.md` — frontmatter fix, `standard-check` target.
- `vendor.sh` — `--check`, heading verification, no `.bak`.
- `tests/vendor_test.sh`, `Makefile` — new.

## Error handling

- Light-path misclassification: covered by the escalation rule; uncertainty
  defaults to the full gate.
- `standard-check` without a local skill checkout: explicit "cannot check"
  message, non-zero exit.
- vendor.sh structural drift in source headings: hard abort before writing.

## Testing

`make test` in this repository runs the vendor tests. Governed-repository
behavior changes (gates, figures, critique) are prose contracts verified by
review, not executable tests here.
