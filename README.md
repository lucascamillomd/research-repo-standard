# research-repo-standard

An operating standard for reproducible repositories that support a scientific analysis, study, or
paper.

## Use the standard

The `research-repo-standard` skill has two modes:

- **Bootstrapping:** guide the approved design and creation of a new research repository.
- **Governed work:** apply modification gates, safety rules, and focused domain procedures when an
  agent changes or reviews an existing research repository.

Resolve `research-repo-standard` by exact name through the selected host's native skill listing or
resolver. A file on disk is not proof of resolution. Follow `references/prerequisites.md` for source
provenance, authorized installation or recovery, and host verification.

After the approved core scaffold exists, enter this provenance-verified source directory and run
only the adapter for the selected host:

```bash
./adapters/codex.sh <target-repo>
./adapters/claude-code.sh <target-repo>
```

Each command has one output. Codex creates `.codex/agents/research-code-simplifier.toml`; Claude
Code creates `.claude/agents/research-code-simplifier.md`. This source repository does not create or
change target policy files. Run the real host-native smoke test required by `SKILL.md` after
installation: it must report the resolved provenance of `research-repo-standard` and confirm the
expected `research-code-simplifier` host profile. Report an unavailable selected host as a manual
boundary.

The generated repository README records the skill prerequisite, expected source provenance and
recovery path, project scope and runtime requirements, shortest Make-based reproduction path,
expected artifacts, and external or manual boundaries. The complete checklist is owned by
`references/bootstrap.md`.

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
adapters/profile-installer.sh          common safe profile installer
adapters/{codex,claude-code}.sh        direct selected-host adapters
tests/adapter_test.sh                  normal adapter and concurrency behavior
tests/adapter_safety_test.sh           focused fault and cleanup behavior
tests/consistency_test.sh              documentation and ownership contracts
tests/skill_pressure_scenarios.md      blind pressure scenarios and scoring rubrics
```

This source repository maintains the skill and adapters. Its commands are not the generated research
repository's workflow interface:

```bash
make help
make format
make test
```

`make test` runs the focused adapter, adapter-safety, and consistency suites. `make format` formats
the owned Markdown sources.
