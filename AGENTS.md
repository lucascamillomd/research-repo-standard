# research-repo-standard source instructions

This repository maintains the `research-repo-standard` skill and publishes it as a Claude Code and
Codex plugin. `skills/research-repo-standard/SKILL.md` is the maintained product. Its `references/`
own its procedures, `agents/` owns the canonical host-neutral simplifier profile, `.claude-plugin/`
holds the plugin and marketplace manifests that both hosts read, and tests protect those contracts.
Leave `version` out of both manifests so installed copies update on each new commit. Any source
design specs or plans under `docs/superpowers/` are non-normative and never override SKILL.md,
`references/`, or `agents/`. These instructions govern only this source repository and are never
copied to a target.

Use `README.md` for source setup, `SKILL.md` for scope and shared constraints, and the affected
reference or profile for its owned procedure. Read the consistency anchors and pressure scenarios
covering a changed contract; a typo does not require unrelated references. Inspect git status and
preserve unrelated work. Give each requirement one normative owner and keep routing discoverable.
Keep the product concise and host-neutral; `references/prerequisites.md` owns host integration.

Never add a script or instruction that copies this `AGENTS.md`, `README.md`, `SKILL.md`, or
`references/` into a target repository, or that creates or modifies a target's `AGENTS.md`,
`CLAUDE.md`, or `CODEX.md`. The host agent, never a shell script in this repository, derives any
repository host profile from the canonical profile by the "Host profile installation" procedure in
`references/prerequisites.md`.

Work test-first for changed contracts: add meaning and ownership anchors, plus a realistic blind
scenario with a hidden rubric before changing behavior. Record the fresh-agent baseline honestly,
including a passing baseline; never manufacture a failure or sample until one appears. After the
change or relocation, rerun affected scenarios with fresh agents and record scores and evidence
under `## GREEN results` in `tests/skill_pressure_scenarios.md`. Separate policy responses, executed
fixture outcomes, and real host checks. Protect meaningful invariants, not exact sentences or
headings. Test scripts support Apple Bash 3.2. Local tests use disposable fixtures without
production access; run and fix failures caused by the requested change without repeated approval.
For source changes run `make format`, `make test`, and `git diff --check`; `make format-check`
checks formatting without edits. Report unavailable real host-resolver checks as manual boundaries,
never as simulations.
