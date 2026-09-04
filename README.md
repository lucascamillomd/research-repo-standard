# research-repo-standard

A standard for reproducible repositories that support a scientific analysis, study, or paper.

## Use the standard

The `research-repo-standard` skill has three modes:

- **Bootstrapping.** Guide the approved design and creation of a new research repository.
- **Adoption.** Assess an existing repository against the standard read-only, item by item with
  evidence, then plan gated migration.
- **Governed work.** Apply modification gates, safety rules, and focused domain procedures when
  changing or reviewing a repository that already follows the standard.

Resolve `research-repo-standard` by exact name through the host's native resolver.
`references/prerequisites.md` owns provenance, authorized recovery, host profile installation, and
the real host-native smoke test. The selected host receives one simplifier profile:

- Claude Code: `<target-repo>/.claude/agents/research-code-simplifier.md`.
- Codex: `<target-repo>/.codex/agents/research-code-simplifier.toml`.
- No host selected: no profile.

The skill never creates or modifies target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md` files.
`references/bootstrap.md` owns the target README checklist, including prerequisites, source
provenance, recovery, reproduction commands, outputs, and external boundaries.

Before migration, detect legacy policy, alias, and generic simplifier artifacts using
`references/prerequisites.md`. Leave them unchanged; removal requires explicit authorization.

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

These Make targets maintain the skill source. They are not the target repository's workflow
interface:

```bash
make help
make format
make test
```

`make test` runs the consistency suite and executes the simplifier examples using Python 3's
standard library. `make format` formats the owned Markdown sources.
