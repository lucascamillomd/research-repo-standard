# research-repo-standard

A standard for reproducible repositories that support a scientific analysis, study, or paper.

## Use the standard

The `research-repo-standard` skill has three modes:

- **Bootstrapping.** Guide the approved design and creation of a new research repository.
- **Adoption.** Assess an existing repository against the standard read-only, item by item with
  evidence, then plan gated migration.
- **Governed work.** Apply modification gates, safety rules, and focused domain procedures when
  changing or reviewing a repository that already follows the standard.

Resolve `research-repo-standard` by exact name through the current host's native skill listing or
resolver, under the resolution rule SKILL.md states. `references/prerequisites.md` owns source
provenance, authorized installation or recovery, host verification, host profile installation, and
the smoke test. Once the approved core scaffold exists, the agent derives only the selected host's
profile from the canonical `agents/research-code-simplifier.md` in the provenance-verified skill
source the host-native resolver reports. Claude Code gets a verbatim copy at
`<target-repo>/.claude/agents/research-code-simplifier.md`. Codex gets
`<target-repo>/.codex/agents/research-code-simplifier.toml` with the same name, description, and
body text in the Codex profile format. With no host selected, write none. The skill never creates or
modifies a target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md`. Then run the real host-native smoke test
whose three checks `references/prerequisites.md` defines and report an unavailable host as it
prescribes.

The target repository's README records the skill prerequisite, expected source provenance and
recovery path, project scope and runtime requirements, the shortest Make-based reproduction path,
expected artifacts, and external or manual boundaries. `references/bootstrap.md` owns the full
checklist.

Migration is detection-first. `references/prerequisites.md` has the agent detect legacy policy,
alias, and generic simplifier artifacts, report their resolved targets and customization status, and
leave them unchanged. Removal requires explicit authorization under SKILL.md's destruction rules.

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

`make test` runs the consistency suite. `make format` formats the owned Markdown sources.
