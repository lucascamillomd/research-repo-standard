# research-repo-standard

An operating standard for reproducible repositories that support a scientific analysis, study, or
paper.

## How it works

The standard has two modes:

- **Bootstrapping:** the `research-repo-standard` skill guides the design and creation of a new
  research repository.
- **Governed work:** the skill applies modification gates, safety rules, and focused domain
  references when an agent changes or reviews an existing research repository.

Resolve `research-repo-standard` by exact name through the selected host's native skill listing or
resolver. File presence alone is not resolution. The installation and recovery procedure lives in
`references/prerequisites.md`.

After the approved repository scaffold exists, install only the selected host profile directly from
this source repository:

```bash
./adapters/codex.sh <target-repo>
./adapters/claude-code.sh <target-repo>
```

Run only the command for the selected host. Codex creates
`.codex/agents/research-code-simplifier.toml`; Claude Code creates
`.claude/agents/research-code-simplifier.md`. Then run the host-native smoke test required by
`SKILL.md` to confirm both skill provenance and the `research-code-simplifier` profile.

## Repository structure

```text
AGENTS.md                              source-repository maintenance instructions
Makefile                               source help, format, and test interface
SKILL.md                               normative skill entry point
references/                            focused scientific and repository procedures
agents/research-code-simplifier.md     canonical host-neutral simplifier profile
adapters/                              direct host-profile installers
tests/adapter_test.sh                  normal adapter behavior
tests/adapter_safety_test.sh           adapter fault and cleanup behavior
tests/consistency_test.sh              documentation and ownership contracts
```

This is not the generated research-repository workflow interface.

## Source maintenance

```bash
make help
make format
make test
```

`make test` runs the adapter, adapter-safety, and consistency suites. `make format` formats the
owned Markdown sources.
