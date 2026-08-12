<!-- standard_version: 2026.08.11 -->

# Reference: required agent skills

Read before bootstrapping a research repository and whenever a governed repository
reports a missing prerequisite. These are agent-environment dependencies, not Python
packages and not project data.

## Hard gate

All three skills must be installed and discoverable before the bootstrap interview —
bootstrap actively uses each one. In an established governed repository the
requirement is scoped to the work that depends on each skill:

| Skill | Authoritative source | Required before |
|---|---|---|
| `superpowers:brainstorming` | <https://github.com/obra/superpowers> | Any user-requested modification that creates, edits, moves, or deletes files |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> | Work meeting an independent-critique trigger in the analysis contract |
| `nature-figure` | <https://github.com/Yuan1z0825/nature-skills> | Work that writes or modifies plotting code or figure outputs |

A missing skill blocks exactly the work that depends on it and nothing else. If a
task's scope expands to meet a trigger it did not start with, stop at that point and
verify the newly required skill before continuing.

This standard was last validated against Superpowers v6.1.1,
`k-dense-ai/scientific-agent-skills` commit `757b63b` (2026-07-24), and
`Yuan1z0825/nature-skills` commit `db69e11` (2026-08-03). Newer upstream releases
are expected to work, but review their changes before relying on behavior that
differs from these versions.

Executing an already approved workflow solely to regenerate declared outputs is not a
new modification. Changes to code, configuration, or contracts are modifications.

Use the agent host's native skill listing or resolver as the lightweight discovery
check. It must return each exact skill name. A directory or `SKILL.md` file alone does
not prove the host can resolve the skill. Successful invocation during the required
workflow is the functional verification.

Do not install these skills silently or modify global agent configuration without the
user's authorization. If a skill is missing, stop before repository mutations.

The Agent Skills commands below require Node.js 18 or later with npm/`npx` available.
This is agent-host tooling and is not installed by project uv or Make.

The examples below resolve current upstream releases. After installation, bootstrap
must record each installed plugin or skill version or source revision, together with
the Agent Skills installer version, in `docs/lab_notebook.md` once the scaffold
exists. Review upgrades before changing that record.

## Codex installation

Install Superpowers from the Codex plugin marketplace: open **Plugins** in the Codex
app, or `/plugins` in Codex CLI, search for **Superpowers**, and install it.

Install the two scientific skills globally with the open Agent Skills installer:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent codex --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent codex --skill nature-figure --yes --copy
```

Verify the two scientific skills with:

```bash
npx skills list --global --agent codex --json
```

Verify Superpowers through the Codex plugin resolver or listing.

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

Verify Superpowers through the Claude Code plugin resolver or listing.

For other agent hosts, follow the installation instructions in each authoritative
source and install only the required skill folders. Review third-party skill contents
and provenance before installation.

## Verify and resume

1. Restart or reload the agent session as directed by the host.
2. Use the host-native skill listing or resolver to confirm all three exact names.
3. Resume bootstrap from its single preflight step. Do not repeat completed design work
   when only the agent session changed.
4. Treat the first required invocation of each skill as functional verification.

If discovery or invocation still fails, report the exact missing name and host, then
stop. Do not substitute generic brainstorming, informal self-critique, or a plotting
workflow that does not use `nature-figure`.
