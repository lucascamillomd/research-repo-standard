# Design: mandatory code-simplifier pass and full figure contract for every plot

Date: 2026-08-10 (second iteration this date; supersedes the figure-tiering
portion of `2026-08-10-friction-and-cleanup-design.md`)
Status: approved pending user review
Version stamps on touched files remain `standard_version: 2026.08.10` — the
scheme is date-based, drift is detected by content comparison, and two bumps
in one day would misrepresent the granularity the scheme offers.

## Motivation

Two user decisions:

1. Every plot — exploratory and diagnostic included — must reflect the
   `nature-figure` workflow and style. The two-tier figure contract
   (publication figures vs working plots) introduced earlier today is
   reverted in full: the friction it saved is not worth style divergence.
2. After code changes, a code-simplifier subagent pass refines the new code
   for clarity and consistency before completion is declared — analogous to
   how the scientific critique gates decisions. The user supplied the agent
   profile; it is adapted to this standard's Python conventions.

## Goals

1. Restore the single, universal figure contract everywhere the two-tier
   split landed, without disturbing the rest of today's cleanup (tiered
   modification gate, critique triggers, standard-check, vendor hardening).
2. Ship the code-simplifier profile with the standard and make the pass a
   mandatory workflow step for code-changing modifications — with no new
   external prerequisite.

## Non-goals

- No change to the tiered modification gate, the critique triggers, the
  standard-check mechanism, or vendor.sh behavior.
- No fourth hard prerequisite: the simplifier profile is carried by the
  standard itself, so the resolver gate does not grow.
- No user-level (`~/.claude/agents/`) installation — the user chose the
  adapted, standard-owned variant only.

## 1. Figure revert

The two-tier language is removed at every site it landed; the restored text
is the pre-branch wording unless noted.

- `AGENTS.md` core principle 8 →
  "Every plot uses Python and the full `nature-figure` workflow."
- `AGENTS.md` repository layout: the
  `│   ├── diagnostics/ …` line is removed from `results/`; the
  FIGURE_CONTRACT.md comment returns to "contract and QA record for every
  plot".
- `AGENTS.md` Figures section: the two paragraphs ("Figures come in two
  tiers…" and "A **working plot** …") are replaced by the original single
  paragraph: "Every plot — exploratory, diagnostic, analytical,
  supplementary, or manuscript-bound — uses the `nature-figure` skill, is
  written in Python, is implemented as importable functions under
  `src/<package_name>/figures/`, has traceable source data, and exports all
  four formats: editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each
  format lives in its own extension-named directory under
  `results/figures/<figure_id>/`." The following paragraph's opening returns
  to "Record the contract in `docs/FIGURE_CONTRACT.md` **before** writing
  plotting code."
- `AGENTS.md` full-gate trigger list: "publication figures" → "figures".
- `references/figures.md` Scope section: restored to the six-requirement
  "Every plot" form including "Exploratory and diagnostic plots are not
  exempt…", and the task-time invocation sentences return to "each plotting
  task" / "Before writing plotting code".
- `references/prerequisites.md` nature-figure role cell →
  "Figure strategy during bootstrap and the full workflow for every plot".
- `SKILL.md` governed-work sentence → "During governed work, obtain the
  independent `scientific-critical-thinking` critique when a trigger in the
  analysis contract applies, and invoke `nature-figure` for every plot under
  the figure contract." (Keeps the enumerated-trigger pointer; only the
  figure clause reverts.)
- Sweep check: `grep -rn "working plot\|publication figure\|results/diagnostics"`
  over AGENTS.md, SKILL.md, README.md, references/ returns zero after the
  revert.

## 2. Code-simplifier pass

### The profile file

New file `agents/code-simplifier.md` in this repository — the canonical
copy. Frontmatter preserved from the user's profile:

```yaml
---
name: code-simplifier
description: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.
model: opus
---
```

Body: the user's text with the JS/React-specific standards bullet replaced
by this standard's conventions. Sections kept in spirit and mostly verbatim:
preserve functionality exactly; apply project standards; enhance clarity;
maintain balance (no over-simplification, no clever one-liners); focus scope
(recently modified code only); the six-step refinement process; autonomous
operation. The "Apply Project Standards" list becomes:

- Follow `pyproject.toml` and `.pre-commit-config.yaml` as the style
  authorities (Ruff formatting and lint rules, ty type checking).
- Public functions in `src/` keep typed interfaces and Google-style
  docstrings covering scientific meaning, units, shapes, and failure modes.
- Scripts orchestrate; logic worth testing lives in `src/` and is imported.
- Configuration ownership is respected: no new module-level settings, no
  hidden defaults; values flow through validated typed configuration.
- Raw-data immutability and the floor rules of AGENTS.md are never
  compromised by a refactor.
- Prefer explicit, readable constructs over dense comprehensions or chained
  one-liners; behavior-describing test names.

The profile ends with the constraint that a simplifier pass must not change
behavior: outputs, estimands, seeds, file contracts, and provenance are
untouchable, and the covering tests are re-run after its edits.

### The workflow rule

`AGENTS.md` Working procedure ("Before declaring completion" paragraph area)
gains:

> When a modification changed code under `src/`, `scripts/`, or `tests/`,
> run a code-simplifier subagent over the changed code before declaring
> completion: it applies the profile at `.claude/agents/code-simplifier.md`
> (canonical copy: the `research-repo-standard` skill's `agents/` directory,
> or
> <https://github.com/lucascamillomd/research-repo-standard/blob/main/agents/code-simplifier.md>
> if the local file is absent), preserves behavior exactly, and its edits are
> verified by re-running the covering tests. The simplifier's own edits do
> not trigger another pass. Documentation- and configuration-only changes
> are exempt.

- `references/bootstrap.md`: the scaffold instructions gain a step — create
  `.claude/agents/code-simplifier.md` in the new repository by copying the
  canonical file from the standard.
- `README.md` Layout block: add `agents/code-simplifier.md` with a one-line
  comment.
- `tests/vendor_test.sh` version-stamp assertion: the glob list gains
  `"$ROOT"/agents/*.md`. The profile carries the stamp as a frontmatter
  field ordered `name`, `description`, `standard_version`, `model`, placing
  `standard_version: 2026.08.10` on line 4 — inside the existing `head -5`
  window, so the check needs no widening.

### What the pass is not

- Not a hard prerequisite: no resolver check, no addition to
  `references/prerequisites.md`'s table or floor rule 10.
- Not vendored: vendor.sh still copies only AGENTS.md. Governed repos get
  the profile at bootstrap; pre-existing governed repos get it when they
  next re-vendor AGENTS.md and follow its pointer to the canonical copy.

## Affected files

- `AGENTS.md` — figure revert (principle 8, layout ×2, Figures section,
  full-gate trigger word), simplifier rule in Working procedure.
- `references/figures.md` — Scope + invocation revert.
- `references/prerequisites.md` — role cell revert.
- `SKILL.md` — governed-work sentence revert (figure clause).
- `references/bootstrap.md` — scaffold step for the agent profile.
- `README.md` — layout block gains `agents/`.
- `agents/code-simplifier.md` — new.
- `tests/vendor_test.sh` — stamp glob extended.

## Error handling

- Simplifier pass with no test coverage over the changed code: the pass
  still runs; the absence of covering tests is reported per floor rule 8
  (do not overstate what was verified) rather than silently accepted.
- Profile file missing in a governed repo: the AGENTS.md pointer names the
  canonical location; the agent copies it in (a file creation that is part
  of the active modification, not a new gate).

## Testing

`make test` (15 assertions after the glob extension) — the stamp check now
covers the new agents/ file. The figure revert is prose verified by the
sweep grep in §1.
