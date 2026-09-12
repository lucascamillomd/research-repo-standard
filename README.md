# research-repo-standard

A standard for reproducible repositories that support a scientific analysis, study, or paper.

## Use the standard

The `research-repo-standard` skill has three modes:

- **Bootstrapping.** Guide the approved design and creation of a new research repository.
- **Adoption.** Assess an existing repository against the standard read-only, item by item with
  evidence, then plan gated migration.
- **Governed work.** Maintain scientific and reproducibility contracts within the user's authorized
  scope in a repository that already follows the standard. Routine work in another scientific
  repository does not start adoption.

The entrypoint routes to the relevant reference sections. Bootstrap reuses supplied decisions;
capabilities resolve when needed. Exploratory figures use the requested formats with traceable data
and visual QA; publication delivery adds its contract and editable exports. Scientific safeguards
remain mandatory while approved seed, compatible Python version, and plotting backend choices are
recorded project conventions.

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
make format-check
make test
```

Source checks require Make, Bash 3.2 or newer, and Python 3.9 or newer. `make test` uses Python's
standard library for structural/contract mutation checks and executable simplifier examples. Set
`PYTHON=/path/to/python` if needed. Formatting also requires Node.js and npm; the Makefile pins
Prettier 3.9.6. Its first invocation may download that package. `make format` writes the owned
Markdown sources; `make format-check` checks the same files without changing them.

For skill-creator's optional frontmatter/scaffold validator, use its host-resolved script and a
separate environment with `PyYAML==6.0.2`; this dependency is not needed by `make test`. For
example, create a temporary virtual environment with `python3 -m venv`, install that pinned
dependency into it, and run its Python with `<resolved-skill-creator>/scripts/quick_validate.py .`.

Blind behavioral evaluations are separate from deterministic source checks. Follow
`tests/skill_pressure_scenarios.md`; provide a fresh agent the prompt, skill snapshot, and permitted
fixture only, with the rubric withheld. Policy-response scores do not prove execution or live host
resolution. Preserve the baseline and candidate identifiers and report unavailable checks honestly.

For the execution cases P, Q, S, and V,
`python3 tests/behavioral_fixture.py create CASE /tmp/fixture` creates the raw artifacts and a
sibling evaluator manifest. Give the agent only the fixture and prompt, then run the same command
with `verify`. Verification checks actual edits and protected files; decision scoring and visual
inspection remain separate. Case S's existing plotting workflow additionally uses
`matplotlib==3.10.6` in an isolated evaluation environment. Fixtures are deliberately minimal and do
not certify a full scaffold or a real host integration.
