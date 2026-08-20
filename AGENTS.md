# research-repo-standard source instructions

This repository maintains the `research-repo-standard` skill. SKILL.md is the maintained product;
`references/` owns its focused procedures, `agents/` owns the canonical host-neutral simplifier
profile, and tests protect those contracts. These instructions govern only this source repository
and are never copied to a target.

Before editing, read `README.md`, `SKILL.md`, the affected reference or profile, nearby tests, and
`git status`. Preserve unrelated work. Keep each requirement in one normative owner and keep the
skill concise, direct, host-neutral, and compatible with its documented resolvers.

Never add target-policy vendoring or any instruction that creates or modifies target `AGENTS.md`,
`CLAUDE.md`, or `CODEX.md`. Host profiles are derived from the canonical profile by the host agent
following the documented instructions, never by shell scripts in this repository. Keep test scripts
compatible with Apple Bash 3.2.

Use test-driven changes. Run `make format`, `make test`, and `git diff --check` for affected work.
Report unavailable real host-resolver checks as manual boundaries rather than simulating them.
