# research-repo-standard source instructions

This repository maintains the `research-repo-standard` skill. SKILL.md is the maintained product.
`references/` owns its procedures, `agents/` owns the canonical host-neutral simplifier profile, and
tests protect those contracts. `docs/superpowers/` holds this repository's own design specs and
plans; they are non-normative and never override SKILL.md, `references/`, or `agents/`. These
instructions govern only this source repository and are never copied to a target.

Before editing a file, read `README.md`, `SKILL.md`, the affected reference or profile, the
`tests/consistency_test.sh` anchors and `tests/skill_pressure_scenarios.md` scenarios that cover it,
and `git status`. Preserve unrelated work. Give each requirement one normative owner. Keep the skill
concise, direct, host-neutral, and compatible with the host-native resolution procedure in
`references/prerequisites.md`.

Never add a script or instruction that copies this `AGENTS.md`, `README.md`, `SKILL.md`, or
`references/` into a target repository, or that creates or modifies a target's `AGENTS.md`,
`CLAUDE.md`, or `CODEX.md`. The host agent, never a shell script in this repository, derives each
host profile from the canonical profile by the "Host profile installation" procedure in
`references/prerequisites.md`.

Work test-first. Pin each contract in `tests/consistency_test.sh` with an anchor on its meaning,
never its exact sentence. Before changing what an agent must do, add a blind scenario with a hidden
rubric to `tests/skill_pressure_scenarios.md`, show a fresh agent fails it against the prior
wording, then make the change and record the fresh-agent GREEN score under `## GREEN results` in
that file. After trimming or consolidating text, re-run the affected scenarios the same way. Keep
test scripts compatible with Apple Bash 3.2. Run `make format`, `make test`, and `git diff --check`
before finishing. Report unavailable real host-resolver checks as manual boundaries, never as
simulations.
