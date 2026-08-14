# Reference: agent-host prerequisites

This procedure covers host-native skill discovery, authorized installation or recovery, source
provenance, propagation to delegated agents, and the selected-host smoke test. Agent-host
capabilities are separate from packages installed in a research repository.

## Required capabilities

Resolve these three hard-gate capabilities before a bootstrap interview. For governed work, resolve
each capability before the work that depends on it. Resolve the two scientific skills by exact name.
Resolve `superpowers` as a whole package: confirm the host lists its skills — at minimum
`superpowers:brainstorming` and `superpowers:writing-plans`, which the workflow invokes by exact
name.

| Capability                     | Authoritative source                                    |
| ------------------------------ | ------------------------------------------------------- |
| `superpowers` (whole package)  | <https://github.com/obra/superpowers>                   |
| `scientific-critical-thinking` | <https://github.com/k-dense-ai/scientific-agent-skills> |
| `nature-figure`                | <https://github.com/Yuan1z0825/nature-skills>           |

Use the selected host's native skill listing or resolver. The result must contain the exact skill
name and enough source information to verify that it came from the expected package or repository. A
file on disk is not resolved, and a directory named after a skill does not prove that the host can
invoke it. Successful invocation during the required workflow is the functional check.

Resolve `research-repo-standard` itself by exact name through the same host-native mechanism and
verify that its reported source or package provenance is the source approved for the project.

Never silently install a skill or change global agent configuration. When a required name or its
expected provenance cannot be resolved, report the exact name, host, attempted resolver, and result;
obtain authorization before recovery; and do not imitate or substitute another workflow. A missing
capability blocks only the dependent work.

## Authorized installation and recovery

Use the installation mechanism documented by the authoritative source and selected host. Review a
third-party package's source and provenance before installation.

Superpowers uses the host's plugin marketplace rather than the Agent Skills installer:

- In Codex, open **Plugins** in the Codex app or `/plugins` in Codex CLI, find **Superpowers**, and
  install it from the Codex plugin marketplace.
- In Claude Code, install Superpowers from Anthropic's official plugin marketplace with
  `/plugin install superpowers@claude-plugins-official`.

For Agent Skills packages, the documented portable form is:

```text
npx skills add <package> --agent <codex|claude-code>
```

Add `--global`, `--skill <exact-name>`, `--yes`, or `--copy` only when those options match the
approved scope and the selected host. For the two scientific packages, authorized installations may
use:

```bash
npx skills add K-Dense-AI/scientific-agent-skills --global --agent codex --skill scientific-critical-thinking --yes --copy
npx skills add Yuan1z0825/nature-skills --global --agent codex --skill nature-figure --yes --copy
```

Replace `codex` with `claude-code` when that is the selected host. The commands require `npx` only
when this recovery route is chosen; Node.js is not a universal research-repository prerequisite.
Follow other hosts' authoritative installation instructions rather than guessing an equivalent.

## Shared planning companion

`superpowers:writing-plans` is provided by the required Superpowers package and is used after design
approval. At planning time, resolve it by exact name from that same installation before invoking it.

After an authorized installation, restart or reload the agent session when the host requires it,
rerun native discovery, verify the exact name and source provenance, and then resume from the
blocked step. Do not repeat already approved design work solely because the session changed.

## Delegated-agent propagation

Before launching an independent scientific reviewer or simplification reviewer, confirm that the
delegated context can resolve every exact skill and profile assigned to it. Pass the applicable
repository instructions and task scope through the host's supported delegation mechanism. The
delegate must report what it resolved and from which source; the parent must not infer resolution
from its own environment.

If the parent resolves a capability but the delegate cannot, dependent review remains blocked unless
the user explicitly waives or defers it, in which case record the waiver and its scope. Report that
delegated-resolution boundary instead of replacing the independent review with a self-review.

## Selected-host smoke test

After the core scaffold and the one selected host integration are complete, run a real smoke test
through that host. Publishing the delegated profile does not establish any skill's resolution. The
result must:

1. resolve `research-repo-standard` by exact name and report its resolved source or package
   provenance;
2. resolve `research-code-simplifier` through the host and report the expected installed host
   profile path; and
3. launch the profile far enough for the delegated reviewer to report that it resolved and invoked
   `research-repo-standard` from the expected provenance, without requesting an implementation.

An unavailable host or resolver is a manual verification boundary, not a simulated success. Report
the unavailable check and use the authorized recovery procedure before claiming that host
integration is complete.
