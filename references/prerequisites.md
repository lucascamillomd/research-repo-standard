# Reference: agent-host prerequisites

This procedure covers host-native skill discovery, authorized installation or recovery, source
provenance, propagation to delegated agents, and the selected-host smoke test. Agent-host
capabilities are separate from packages installed in a research repository.

## Required capabilities

Resolve these three capabilities before a bootstrap interview. In adoption and governed-work modes,
resolve each before the work that depends on it. Resolve the two scientific skills by exact name and
`superpowers` as a whole package. Confirm the host lists at least `superpowers:brainstorming` and
`superpowers:writing-plans`, which the workflow invokes by exact name.

| Capability                     | Authoritative source                                    |
| ------------------------------ | ------------------------------------------------------- |
| `superpowers` (whole package)  | <https://github.com/obra/superpowers>                   |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> |
| `nature-figure`                | <https://github.com/Yuan1z0825/nature-skills>           |

Use the current host's native skill listing or resolver. The result must show the exact skill name
and enough source information to verify the expected package or repository. Successful invocation
during the workflow is the functional check.

Resolve `research-repo-standard` itself the same way and check that its reported provenance matches
the provenance the project README records under the checklist in `references/bootstrap.md`. When the
README has no entry yet, match the source the user approved.

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

The preflight-resolved `superpowers` package provides `superpowers:writing-plans`. Invoke it after
design approval.

## Delegated-agent propagation

Before launching an independent scientific or simplification reviewer, confirm the delegated context
can resolve every skill and profile assigned to it. Pass the applicable repository instructions and
task scope through the host's delegation mechanism. The delegate reports what it resolved and from
which source. The parent must not infer resolution from its own environment.

If the parent resolves a capability but the delegate cannot, dependent review stays blocked unless
the user explicitly waives or defers it. Record any waiver and its scope. Report the boundary rather
than replacing the independent review with a self-review.

## Host profile installation

After the approved core scaffold exists, the agent writes the simplifier profile into the target
repository itself; there is no installer script. Derive it from the canonical
`agents/research-code-simplifier.md` in the provenance-verified skill source the host-native
resolver reported, never from a path inferred from the current directory.

Before writing the profile, detect artifacts of an earlier integration. Report each one's path, the
path it resolves to, and whether its content was customized, then leave it unchanged. Three kinds
count. A legacy policy is a target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md` that restates this
standard. An alias is a symlink or wrapper file that resolves to a simplifier profile. A generic
simplifier is a simplifier profile outside the selected host's expected path, such as a shared
top-level `agents/` profile or a `code-simplifier` profile. Removing one is destruction under
SKILL.md and follows that report.

- For a Claude Code host, copy the canonical profile verbatim to
  `<target-repo>/.claude/agents/research-code-simplifier.md`.
- For a Codex host, write `<target-repo>/.codex/agents/research-code-simplifier.toml` as a Codex
  custom-agent file with the same name, description, and body text: `name = "<frontmatter name>"`,
  `description = "<frontmatter description>"`, and
  `developer_instructions = '''<body after the frontmatter, unchanged>'''`.

Write only the selected host's profile, and none when no host was selected. The canonical profile
stays host-neutral. Never add host names to it or restate its content in another policy file. Never
create or modify a target `AGENTS.md`, `CLAUDE.md`, or `CODEX.md`. Never overwrite a customized
profile without explicit authorization. Then run the selected-host smoke test below.

## Selected-host smoke test

After the core scaffold and the selected host integration are complete, run a real smoke test
through that host. Writing the profile does not establish any skill's resolution. The result must:

1. resolve `research-repo-standard` by exact name and report its provenance;
2. resolve `research-code-simplifier` through the host and report the installed profile path; and
3. launch the profile far enough that the delegated reviewer reports it resolved and invoked
   `research-repo-standard` from the expected provenance, without requesting an implementation.

An unavailable host or resolver is a manual verification boundary, not a simulated success. Report
the unavailable check and run the authorized recovery procedure before claiming the host integration
is complete.
