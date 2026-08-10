# Skill-creator fork and revision — design

**Date:** 2026-08-10
**Branch:** `skill-creator-fork`
**Status:** Approved design, pending spec review

## Purpose

Fork the official `skill-creator` plugin skill into this repository and revise it to
fix nine defects found in review. The installed plugin cache
(`~/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator/`)
is not a git repository and is overwritten on plugin update, so the fork gives the
revision a durable, diffable home. Upstreaming is a possible follow-up, not part of
this work.

## Placement and structure

New top-level directory `forks/`, holding third-party skill forks, starting with:

```text
forks/
├── README.md                 # provenance and change rationale
└── skill-creator/            # complete skill, installable as-is
    ├── SKILL.md              # the only file the revision edits
    ├── LICENSE.txt
    ├── agents/               # grader.md, comparator.md, analyzer.md
    ├── assets/               # eval_review.html
    ├── eval-viewer/          # generate_review.py, viewer.html
    ├── references/           # schemas.md
    └── scripts/              # run_loop.py, package_skill.py, quick_validate.py, …
```

Excluded from the copy: `__pycache__/`, `.remember/`, and the plugin cache's
`.in_use/` bookkeeping. `forks/README.md` records the source path, the fact that the
upstream version is unlabeled (`unknown` in the cache path), the fork date, and a
per-change rationale so a future reader can re-diff against upstream.

Adding `forks/` is a deliberate structural decision: the standard's own top-level
directories (`agents/`, `docs/`, `references/`, `tests/`) all belong to the standard
itself; forked external material needs a clearly separate home.

## Findings to fix (all in `SKILL.md` unless noted)

Correctness bugs:

1. **Terminology: `assertions` vs `expectations`.** SKILL.md instructs writing an
   `assertions` field in `evals.json` and `eval_metadata.json` and claims
   `references/schemas.md` documents it; schemas.md and `grading.json` use
   `expectations` (with exact grading field names `text`/`passed`/`evidence`).
   Fix: use `expectations` everywhere in SKILL.md; schemas.md is already correct.
2. **`kill $VIEWER_PID` cannot work in Claude Code.** Shell state does not persist
   between Bash calls, so a variable captured when launching the viewer is gone at
   cleanup time. Fix: write the PID to `viewer.pid` in the workspace and kill from
   that file.

Consistency fixes:

3. **Packaging contradiction.** The Package step is conditional on the
   `present_files` tool; the closing recap says unconditionally "Package the final
   skill and return it to the user." Fix the recap.
4. **`scripts/quick_validate.py` is never referenced.** Add a validation step
   (before packaging) that runs it; the skill currently has no structural
   validation instruction at all.

Structural rewrite:

5. **Filler, tone, and repetition.** "Cool? Cool.", "billions a year in economic
   value", the plumbers anecdote, an ALL-CAPS aside that itself violates the
   skill's own advice against ALL-CAPS musts, and the core loop stated three times.
   Target roughly 30–40% reduction of body length with no content loss; keep one
   statement of the loop plus a short closing checklist.
6. **Platform sections keyed to product names.** Claude.ai and Cowork sections
   encode environment quirks narratively and will rot. Replace with
   capability-keyed adaptations: no subagents → run serially, skip baselines;
   no display/browser → `--static` viewer output; no `claude` CLI → skip
   description optimization. Product names may appear as examples of each
   condition, not as section owners.

Guidance additions:

7. **Description-writing advice encourages a known failure mode.** The skill tells
   authors to include workflow detail and be "pushy"; observed failure (documented
   in superpowers writing-skills): agents follow a workflow-summarizing description
   instead of reading the skill body. Add a caution: describe what the skill does
   and when to trigger, never summarize its internal process step-by-step.
8. **Timing capture has no fallback.** Step 3 calls the task notification "the only
   opportunity" to capture `total_tokens`/`duration_ms`. Add: if a notification is
   missed or runs happen inline, write nulls and continue; timing is
   nice-to-have, not gating.
9. **No "when NOT to make a skill" guidance.** Add a short section: one-off tasks,
   project-specific conventions (belong in CLAUDE.md/AGENTS.md), and automated
   behaviors (belong in hooks/settings) are not skills; advise the user instead of
   proceeding.

## Revision strategy

Surgical edit series (approved over ground-up rewrite): keep upstream structure and
voice where sound; each edit is attributable to a numbered finding; only the platform
sections and the loop repetition are restructured. This keeps the baseline-to-revision
diff reviewable and future upstream re-syncs mechanical.

## Commit sequence

1. This spec (gate artifact).
2. Baseline import of the skill into `forks/skill-creator/`, verbatim, plus
   `forks/README.md`.
3. Correctness bugs (findings 1–2).
4. Consistency fixes (findings 3–4).
5. Structural rewrite (findings 5–6).
6. Guidance additions (findings 7–9).

## Verification

- `grep` confirms no stray `assertions` field terminology remains in SKILL.md
  (prose uses of the word are fine only where they describe the concept, not the
  field name; prefer `expectations` throughout).
- Every relative path SKILL.md references exists in the fork.
- Word and line counts reported before vs after the rewrite; body stays under the
  skill's own 500-line guideline with clear margin.
- `make test` passes on the branch (the fork must not affect the standard's suite).
- The repository's code-simplifier pass is exempt: the change is
  documentation-only (copied Python scripts are imported verbatim, not modified).
- Optional follow-up, outside this gate: subagent smoke test running the revised
  skill against a toy skill-creation prompt.

## Out of scope

- Modifying the installed plugin cache.
- Any change to the standard's own files beyond creating `forks/`.
- Upstream contribution (possible follow-up).
