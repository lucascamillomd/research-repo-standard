# research-repo-standard

A standard for reproducible repositories that support a scientific analysis, study, or paper. This
repository is a plugin marketplace for Claude Code and Codex that publishes one plugin,
`research-repo-standard`.

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

Both hosts list the skill as `research-repo-standard:research-repo-standard`.
`skills/research-repo-standard/references/prerequisites.md` owns provenance, authorized recovery,
host profile installation, and the real host-native smoke test. The skill never creates or modifies
target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md` files. `references/bootstrap.md` in the same
directory owns the target README checklist, including prerequisites, source provenance, recovery,
reproduction commands, outputs, and external boundaries.

Before migration, detect legacy policy, alias, and generic simplifier artifacts using
`references/prerequisites.md`. Leave them unchanged; removal requires explicit authorization.

## Install in Claude Code

1. Add the marketplace and install the plugin. In a Claude Code session, run:

   ```text
   /plugin marketplace add lucascamillomd/research-repo-standard
   /plugin install research-repo-standard@research-repo-standard
   ```

   From a shell, `claude plugin marketplace add lucascamillomd/research-repo-standard` and
   `claude plugin install research-repo-standard@research-repo-standard` do the same.

2. Turn on auto-update. Claude Code leaves it off for this marketplace until you enable it. In a
   session, run `/plugin`, open **Marketplaces**, select `research-repo-standard`, and choose
   **Enable auto-update**. Without the menu, set `"autoUpdate": true` on the
   `research-repo-standard` entry under `extraKnownMarketplaces` in `~/.claude/settings.json`; the
   `marketplace add` command created that entry.

3. Run `/reload-plugins` or start a new session. The skill list shows
   `research-repo-standard:research-repo-standard`, and the agent list shows
   `research-repo-standard:research-code-simplifier`.

The plugin supplies the simplifier profile, so governed repositories need no profile file. With
auto-update on, Claude Code fetches new commits in the background during a session and loads them at
the next launch or `/reload-plugins`. To update by hand, run
`/plugin marketplace update research-repo-standard` in a session or
`claude plugin update research-repo-standard@research-repo-standard` in a shell.

## Install in Codex

1. Add the marketplace and install the plugin from a shell:

   ```bash
   codex plugin marketplace add lucascamillomd/research-repo-standard
   codex plugin add research-repo-standard@research-repo-standard
   ```

   Plugins in the app, or `/plugins` in the CLI, can install it instead.

2. Updates need no setting. Codex refreshes Git marketplaces when it starts and reinstalls the
   plugin when this repository has a new commit. To update immediately, run
   `codex plugin marketplace upgrade research-repo-standard`.

3. Start a new session. The skill list shows `research-repo-standard:research-repo-standard`.

### Codex simplifier profile

Codex plugins cannot supply agents, so each governed repository carries its own profile at
`<target-repo>/.codex/agents/research-code-simplifier.toml`. The agent writes it after the approved
core scaffold exists, by "Host profile installation" in `references/prerequisites.md`; no script
generates it. The steps:

1. Read `agents/research-code-simplifier.md` at the installed plugin root,
   `~/.codex/plugins/cache/research-repo-standard/research-repo-standard/local/`.
2. Write the TOML with three keys: `name` and `description` from the profile's frontmatter, and
   `developer_instructions = '''<body after the frontmatter, unchanged>'''`.
3. Report any existing or legacy simplifier profile and leave it unchanged. Replacing a customized
   profile requires explicit authorization.
4. Start a new Codex session in the repository and run the smoke test in
   `references/prerequisites.md`.

The TOML is a copy, so plugin updates do not change it. When an update changes
`agents/research-code-simplifier.md`, ask the agent to derive the profile again.

## Source repository

```text
.claude-plugin/                        plugin and marketplace manifests both hosts read
skills/research-repo-standard/         SKILL.md entry point and references/ procedures
agents/research-code-simplifier.md     canonical host-neutral simplifier profile
AGENTS.md                              source-repository maintenance instructions
Makefile                               source help, format, and test interface
tests/consistency_test.sh              documentation and ownership contracts
tests/plugin_manifest_test.py          plugin layout and manifest checks
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
dependency into it, and run its Python with
`<resolved-skill-creator>/scripts/quick_validate.py skills/research-repo-standard`.

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
