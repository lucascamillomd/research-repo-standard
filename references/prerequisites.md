<!-- standard_version: 2026.08.04 -->

# Reference: required agent skills

Read before bootstrapping a research repository and whenever a governed repository
reports a missing prerequisite. These are agent-environment dependencies, not Python
packages and not project data.

## Hard gate

The following skills must be installed and discoverable before the bootstrap interview
or any user-requested modification that creates, edits, moves, or deletes files in a
governed repository:

| Skill | Authoritative source | Required role |
|---|---|---|
| `superpowers:brainstorming` | <https://github.com/obra/superpowers> | Design and approval before every modification |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> | Independent critique during bootstrap and later scientific judgments |
| `nature-figure` | <https://github.com/Yuan1z0825/nature-skills> | Figure strategy during bootstrap and the full workflow for every plot |

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
the Agent Skills installer version, in durable repository setup provenance. Use
`docs/DECISIONS.md` once the scaffold exists. Review upgrades before changing that
record.

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
