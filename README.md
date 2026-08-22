# research-repo-standard

An operating standard for reproducible repositories that support a scientific analysis, study, or
paper.

## Use the standard

The `research-repo-standard` skill has three modes:

- **Bootstrapping:** guide the approved design and creation of a new research repository.
- **Adoption:** assess an existing repository against the standard read-only, item by item with
  evidence, then plan gated migration.
- **Governed work:** apply modification gates, safety rules, and focused domain procedures when an
  agent changes or reviews an existing research repository.

Resolve `research-repo-standard` by exact name through the selected host's native skill listing or
resolver. A file on disk is not proof of resolution. Follow `references/prerequisites.md` for source
provenance, authorized installation or recovery, and host verification.

After the approved core scaffold exists, the agent writes the host profile itself by deriving it
from the canonical `agents/research-code-simplifier.md` in this provenance-verified skill source.
`references/prerequisites.md` owns the exact procedure. A Claude Code host receives the canonical
profile copied verbatim to `<target-repo>/.claude/agents/research-code-simplifier.md`. A Codex host
receives `<target-repo>/.codex/agents/research-code-simplifier.toml` carrying the same name,
description, and body text in the Codex profile format. Write only the selected host's profile, and
write none when no host was selected. This source repository does not create or change target policy
files. Run the real host-native smoke test after installation; `references/prerequisites.md` defines
its three required checks, including launching the delegated reviewer far enough to report that it
resolved `research-repo-standard`. Report an unavailable selected host as a manual boundary.

The generated repository README records the skill prerequisite, expected source provenance and
recovery path, project scope and runtime requirements, shortest Make-based reproduction path,
expected artifacts, and external or manual boundaries. `references/bootstrap.md` owns the complete
checklist.

Migration is detection-first. Detect legacy policy, alias, and generic simplifier artifacts, report
their exact resolved targets and customization status, and leave them unchanged. Removal requires
explicit authorization after that inspection.

## Source repository

```text
AGENTS.md                              source-repository maintenance instructions
Makefile                               source help, format, and test interface
SKILL.md                               normative skill entry point
references/                            focused scientific and repository procedures
agents/research-code-simplifier.md     canonical host-neutral simplifier profile
tests/consistency_test.sh              documentation and ownership contracts
tests/skill_pressure_scenarios.md      blind pressure scenarios and scoring rubrics
```

This source repository maintains the skill. Its commands are not the generated research repository's
workflow interface:

```bash
make help
make format
make test
```

`make test` runs the consistency suite. `make format` formats the owned Markdown sources.
