# Reference: agent-host prerequisites

This procedure covers host-native skill discovery, authorized installation or recovery, source
provenance, propagation to delegated agents, and the selected-host smoke test. Agent-host
capabilities are separate from packages installed in a research repository.

## Required capabilities

Resolve a required capability immediately before its dependent work, not as a blanket bootstrap
preflight. A no-figure project does not need `nature-figure`; a mechanical edit does not need
planning or scientific-review skills. Resolve the exact skills used, rather than verifying an entire
package's unrelated capabilities.

| Capability                     | Needed for                                    | Authoritative source                                    |
| ------------------------------ | --------------------------------------------- | ------------------------------------------------------- |
| `superpowers:brainstorming`    | full-gate design                              | <https://github.com/obra/superpowers>                   |
| `superpowers:writing-plans`    | implementation planning after design approval | <https://github.com/obra/superpowers>                   |
| `scientific-critical-thinking` | independent scientific critique               | <https://github.com/k-dense-ai/scientific-agent-skills> |
| `nature-figure`                | publication figure strategy and delivery      | <https://github.com/Yuan1z0825/nature-skills>           |

Use the current host's native skill listing or resolver. The result must show the exact skill name
and enough source information to verify the expected package or repository. Successful invocation
during the workflow is the functional check. A file on disk, or a repository that names a skill, is
not resolution or invocation evidence. Do not silently install, imitate, or substitute a required
skill. A missing capability blocks only work that depends on it.

Resolve this skill the same way. It installs as a plugin from the `research-repo-standard`
marketplace at `github.com/lucascamillomd/research-repo-standard`, so its exact name is
`research-repo-standard:research-repo-standard`. Check that its reported provenance, the marketplace
source and installed commit, matches the provenance the project README records under the checklist
in `references/bootstrap.md`. When the README has no entry yet, match the source the user approved.

Record the host, resolver, resolved source, and invocation evidence at first use. Reuse that record
while the session and provenance are unchanged; report again if resolution fails or the source,
host, or session changes. Do not print a fixed resolver form for every edit. An actual failed
attempt is required before declaring a capability unavailable.

Never change global agent configuration without authorization. When a required name or its
provenance does not resolve, report the exact name, host, resolver tried, and result, then obtain
authorization before installation or recovery.

## Authorized installation and recovery

Install by the mechanism the authoritative source and the current host document. Review a
third-party package's source and provenance first.

Superpowers installs from the host's plugin marketplace, not the Agent Skills installer:

- In Codex, open Plugins in the app or `/plugins` in the CLI and install Superpowers from the
  marketplace.
- In Claude Code, run `/plugin install superpowers@claude-plugins-official`.

This skill installs the same way from its own marketplace. In Claude Code, run
`/plugin marketplace add lucascamillomd/research-repo-standard` and
`/plugin install research-repo-standard@research-repo-standard`. In Codex, run
`codex plugin marketplace add lucascamillomd/research-repo-standard`, then install
`research-repo-standard` from Plugins.

For Agent Skills packages, the documented portable form is:

```text
npx skills add <package> --agent <codex|claude-code>
```

Add `--global`, `--skill <exact-name>`, `--yes`, or `--copy` only when they match the approved scope
and the current host. For the two scientific packages, an authorized installation may use:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent codex --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent codex --skill nature-figure --yes --copy
```

Replace `codex` with `claude-code` on that host. Only this recovery route needs `npx`; Node.js is
not a general research-repository prerequisite. On other hosts, follow their authoritative
installation instructions rather than guessing an equivalent.

After an authorized installation, restart the session if the host requires it, rerun native
discovery, verify the exact name and provenance, and resume from the blocked step. Do not repeat
approved design work because the session changed.

## Shared planning companion

Resolve and invoke `superpowers:writing-plans` after design approval when an implementation plan is
required. Reuse successful resolution from this session when its provenance is unchanged.

## Delegated-agent propagation

Before launching an independent scientific or simplification reviewer, confirm the delegated context
can resolve every skill and profile assigned to it. Pass the applicable repository instructions and
task scope through the host's delegation mechanism. The delegate reports its own skill provenance,
profile path, and invocation evidence. The parent must not infer resolution from its own
environment.

If the delegate cannot resolve or invoke a required capability, report the failure and apply the
Review waivers procedure in `references/governance.md`. Never infer the delegate's capability from
the parent's.

## Host profile installation

After the approved core scaffold exists, complete the selected host's simplifier profile. The
canonical profile is `agents/research-code-simplifier.md` at the root of the provenance-verified
plugin the host-native resolver reported, never a path inferred from the current directory.

Before writing the profile, detect artifacts of an earlier integration. Report each one's path, the
path it resolves to, and whether its content was customized, then leave it unchanged. Three kinds
count. A legacy policy is a target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md` that restates this
standard. An alias is a symlink or wrapper file that resolves to a simplifier profile. A generic
simplifier is a simplifier profile outside the selected host's expected path, such as a shared
top-level `agents/` profile or a `code-simplifier` profile. With a Claude Code host, a repository
copy such as `.claude/agents/research-code-simplifier.md` is a generic simplifier. Removing one
follows the destruction procedure in `references/governance.md` after that report.

- For a Claude Code host, the plugin supplies the profile as
  `research-repo-standard:research-code-simplifier`; write no repository copy.
- For a Codex host, whose plugins cannot supply agents, the agent writes
  `<target-repo>/.codex/agents/research-code-simplifier.toml` itself as a Codex custom-agent file
  with the same name, description, and body text: `name = "<frontmatter name>"`,
  `description = "<frontmatter description>"`, and
  `developer_instructions = '''<body after the frontmatter, unchanged>'''`.

Write only the selected host's profile, and none when no host was selected. The canonical profile
stays host-neutral. Never add host names to it or restate its content in another policy file. Never
create or modify a target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md`. Never overwrite a customized
profile without explicit authorization. Then run the selected-host smoke test below.

## Selected-host smoke test

After the core scaffold and the selected host integration are complete, run a real smoke test
through that host. Writing the profile does not establish any skill's resolution. The result must:

1. resolve the skill by its exact name, `research-repo-standard:research-repo-standard`, and report
   its provenance;
2. resolve the simplifier profile through the host,
   `research-repo-standard:research-code-simplifier` on Claude Code or `research-code-simplifier` on
   Codex, and report the installed profile path; and
3. launch the profile far enough that the delegated reviewer reports it resolved and invoked
   `research-repo-standard` from the expected provenance, without requesting an implementation.

An unavailable host or resolver is a manual verification boundary, not a simulated success. Report
the unavailable check and run the authorized recovery procedure before claiming the host integration
is complete.
