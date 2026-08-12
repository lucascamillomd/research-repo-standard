<!-- standard_version: 2026.08.11 -->

# Reference: agent-host prerequisites

This is the authoritative host-integration procedure for installing or resolving the standard, its
required skills, and delegated-agent profiles. Apply it before bootstrap and whenever a governed
repository reports a missing host capability. These are global agent-environment dependencies, not
generated project packages or data.

## Hard gate

All three skills must be installed and discoverable before the bootstrap interview — bootstrap
actively uses each one. In an established governed repository the requirement is scoped to the work
that depends on each skill:

| Skill                          | Authoritative source                                    | Required before                                                              |
| ------------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `superpowers:brainstorming`    | <https://github.com/obra/superpowers>                   | Any user-requested modification that creates, edits, moves, or deletes files |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> | Work meeting an independent-critique trigger in the analysis contract        |
| `nature-figure`                | <https://github.com/Yuan1z0825/nature-skills>           | Work that writes or modifies plotting code or figure outputs                 |

A missing skill blocks exactly the work that depends on it and nothing else. If a task's scope
expands to meet a trigger it did not start with, stop at that point and verify the newly required
skill before continuing.

This standard was last validated against Superpowers v6.1.1, `k-dense-ai/scientific-agent-skills`
commit `757b63b` (2026-07-24), and `Yuan1z0825/nature-skills` commit `db69e11` (2026-08-03). Newer
upstream releases are expected to work, but review their changes before relying on behavior that
differs from these versions.

Executing an already approved workflow solely to regenerate declared outputs is not a new
modification. Changes to code, configuration, or contracts are modifications.

Use the agent host's native skill listing or resolver as the lightweight discovery check. It must
return each exact skill name. A directory or `SKILL.md` file alone does not prove the host can
resolve the skill. Successful invocation during the required workflow is the functional
verification.

Do not install these skills silently or modify global agent configuration without the user's
authorization. If a skill is missing, stop before repository mutations.

The Agent Skills commands below require Node.js 18 or later with npm/`npx` available. This is
agent-host tooling and is not installed by project uv or Make.

The examples below resolve current upstream releases. After installation, bootstrap must record each
installed plugin or skill version or source revision, together with the Agent Skills installer
version, in `docs/lab_notebook.md` once the scaffold exists. Review upgrades before changing that
record.

## Resolve this standard

In Codex, install or expose this repository as the `research-repo-standard` skill under a discovered
`.agents/skills/research-repo-standard/` location, then confirm the exact name appears in the host
skill listing. Codex natively loads governed repository policy from `AGENTS.md`; no `CODEX.md`
sidecar is used. Official discovery documentation: <https://learn.chatgpt.com/docs/build-skills> and
<https://learn.chatgpt.com/docs/agent-configuration/agents-md>.

In Claude Code, install or expose this repository as the `research-repo-standard` skill under a
discovered `.claude/skills/research-repo-standard/` location, then confirm the exact name appears in
the host skill listing. Claude Code can consume governed policy through the optional adapter's
relative `CLAUDE.md -> AGENTS.md` alias; where symlinks are unavailable, use the documented
`CLAUDE.md` file containing `@AGENTS.md` instead. Official discovery documentation:
<https://code.claude.com/docs/en/skills> and <https://code.claude.com/docs/en/memory>.

## Codex installation

Install Superpowers from the Codex plugin marketplace: open **Plugins** in the Codex app, or
`/plugins` in Codex CLI, search for **Superpowers**, and install it.

Install the two scientific skills globally with the open Agent Skills installer:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent codex --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent codex --skill nature-figure --yes --copy
```

Verify the two scientific skills with:

```bash
npx skills list --global --agent codex --json
```

Verify Superpowers through the Codex plugin resolver or listing. At planning time, confirm the
companion `superpowers:writing-plans` skill resolves from that installation; it is used after design
approval rather than treated as a fourth bootstrap hard gate.

## Claude Code installation

Install Superpowers from Anthropic's official plugin marketplace:

```text
/plugin install superpowers@claude-plugins-official
```

Install the two scientific skills globally:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent claude-code --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent claude-code --skill nature-figure --yes --copy
```

Verify the two scientific skills with:

```bash
npx skills list --global --agent claude-code --json
```

Verify Superpowers through the Claude Code plugin resolver or listing. At planning time, confirm the
companion `superpowers:writing-plans` skill resolves from that installation; it is used after design
approval rather than treated as a fourth bootstrap hard gate.

For other agent hosts, follow the installation instructions in each authoritative source and install
only the required skill folders. Review third-party skill contents and provenance before
installation.

## Install the selected project host adapter

Core vendoring is always separate: `./vendor.sh <target-repo>` writes only `AGENTS.md`. After that
command, run only the adapter the user selected:

```bash
./adapters/claude-code.sh <target-repo>
./adapters/codex.sh <target-repo>
```

The Claude Code adapter creates the documented policy alias and installs the simplifier profile at
`.claude/agents/code-simplifier.md`. The Codex adapter installs `.codex/agents/code-simplifier.toml`
plus the canonical `agents/code-simplifier.md`; it creates no `CODEX.md`. Adapter files are
generated project integration, while the skills above are global host setup.

## Delegated-agent verification

A delegated agent does not inherit previously invoked skill content merely because the parent used
it. In Claude Code, preload the needed skill in the custom-agent `skills` field or require the
worker to invoke an available skill explicitly; creating the first `.claude/agents/` or skill
directory during a session may require restart. In Codex, a spawned run rebuilds the effective
`AGENTS.md` chain from its working directory and inherits parent agent configuration unless the
custom TOML overrides it; the installed simplifier wrapper explicitly routes to
`agents/code-simplifier.md`.

Functionally smoke-test delegated propagation by launching an independent review agent in the target
repository and requiring it to name the applicable `AGENTS.md` policy, resolve or read its assigned
skill/profile, and return findings without implementation. A file existing on disk is not enough.

## Verify and resume

1. Restart or reload the agent session as directed by the host.
2. Use the host-native skill listing or resolver to confirm all three exact names.
3. Resume bootstrap from its single preflight step. Do not repeat completed design work when only
   the agent session changed.
4. Treat the first required invocation of each skill as functional verification.

If discovery or invocation still fails, report the exact missing name and host, then stop. Do not
substitute generic brainstorming, informal self-critique, or a plotting workflow that does not use
`nature-figure`.
