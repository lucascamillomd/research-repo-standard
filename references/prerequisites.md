<!-- standard_version: 2026.08.13 -->

# Reference: agent-host prerequisites

This is the authoritative host procedure for resolving and, when a required capability is missing,
installing this standard and its required skills. Apply it for bootstrap preflight or recovery from
a missing host capability. These are global agent-environment dependencies, not generated project
packages or data.

## Hard gate

All three skills must resolve by exact name before the bootstrap interview because bootstrap uses
each one. In an established governed repository the requirement is scoped to the work that depends
on each skill:

| Skill                          | Authoritative source                                    | Required before                                                              |
| ------------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `superpowers:brainstorming`    | <https://github.com/obra/superpowers>                   | Any user-requested modification that creates, edits, moves, or deletes files |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> | Work meeting an independent-critique trigger in the analysis contract        |
| `nature-figure`                | <https://github.com/Yuan1z0825/nature-skills>           | Work that writes or modifies plotting code or figure outputs                 |

A missing skill blocks exactly the work that depends on it and nothing else. If a task's scope
expands to meet a trigger it did not start with, stop at that point and verify the newly required
skill before continuing.

Executing an already approved workflow solely to regenerate declared outputs is not a new
modification. Changes to code, configuration, or contracts are modifications.

Use the agent host's native skill listing or resolver as the lightweight discovery check. It must
return each exact skill name. A directory or `SKILL.md` file alone does not prove the host can
resolve the skill. Successful invocation during the required workflow is the functional
verification.

Do not install these skills silently or modify global agent configuration without the user's
authorization. If a skill is missing, stop before repository mutations. Do not substitute another
workflow for a missing required skill.

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

## Install Superpowers for Codex

Install Superpowers from the Codex plugin marketplace: open **Plugins** in the Codex app, or
`/plugins` in Codex CLI, search for **Superpowers**, and install it.

## Install Superpowers for Claude Code

Install Superpowers from Anthropic's official plugin marketplace:

```text
/plugin install superpowers@claude-plugins-official
```

At planning time, confirm the companion `superpowers:writing-plans` skill resolves from the selected
Superpowers installation. It is used after design approval and is not a fourth bootstrap hard gate.

## Install the scientific skills

Node.js 18 or later with npm/`npx` is required only when running the Agent Skills installer commands
below. It is agent-host tooling and is not installed by project uv or Make. Set `agent_host` to the
current agent host:

```bash
agent_host=codex  # use claude-code when that is the selected host
npx skills add K-Dense-AI/scientific-agent-skills --global --agent $agent_host --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent $agent_host --skill nature-figure --yes --copy
npx skills list --global --agent $agent_host --json
```

Verify Superpowers through the selected host's plugin resolver or listing. Confirm the two
scientific skill names in the Agent Skills listing and through the host-native resolver. Review
third-party skill contents and provenance before installation.

For other agent hosts, follow the installation instructions in each authoritative source and install
only the required skill folders.

## Verify and resume

1. Restart or reload the agent session as directed by the host.
2. Use the host-native skill listing or resolver to confirm all three exact names.
3. Resume bootstrap from its single preflight step. Do not repeat completed design work when only
   the agent session changed.
4. Treat the first required invocation of each skill as functional verification.

If discovery or invocation still fails, report the exact missing name and host, then stop. Do not
substitute generic brainstorming, informal self-critique, or a plotting workflow that does not use
`nature-figure`.
