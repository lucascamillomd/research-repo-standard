# Forked third-party skills

Local forks of externally maintained skills. Each fork records its provenance here;
revisions sit on top of a verbatim baseline import, so `git log -- forks/<name>/`
shows exactly what diverged from upstream.

## skill-creator

- **Source:** `~/.claude/plugins/cache/claude-plugins-official/skill-creator/`
  (official Anthropic plugin marketplace; the cache does not label a version — its
  directory is literally named `unknown`).
- **Imported:** 2026-08-10, verbatim except caches and runtime bookkeeping
  (`__pycache__/`, `.remember/`, `.in_use/`).
- **Why forked:** the plugin cache is not a git repository and is overwritten on
  plugin update. This fork carries nine review fixes; see
  `docs/superpowers/specs/2026-08-10-skill-creator-fork-design.md` for findings and
  rationale.
- **Changes on top of baseline** (all in `SKILL.md`): unified `expectations`
  terminology with `references/schemas.md`; viewer PID persisted to a file (shell
  state does not survive between agent commands); packaging made consistently
  conditional on `present_files`; `quick_validate.py` wired in before packaging;
  body trimmed and deduplicated; product-named platform sections replaced by
  capability-keyed adaptations; description guidance bounded against
  workflow-summarizing; timing capture given a fallback; added "when a skill is the
  wrong vehicle" guidance.
