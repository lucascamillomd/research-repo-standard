# Contract Harmonization Design

**Date:** 2026-08-13

## Purpose

Apply the accepted runtime, test, domain-reference, bootstrap, and policy-surface review as one
ownership-driven harmonization. The result should preserve the standard's safety floor while making
each layer own one concern:

- `AGENTS.md` owns portable governed policy for generated research repositories.
- `SKILL.md` owns bootstrap and governance-mode routing.
- `references/*.md` own procedures and templates that are intentionally too detailed for policy.
- `adapters/*.sh` install host-specific integration derived from canonical source material.
- `tests/*.sh` assert behavior and semantic contracts without pinning obsolete wording.

This source repository distributes the standard. Its own `AGENTS.md` must identify that role so a
host does not mistake maintenance of the distributor for work inside a generated scientific
repository.

## Policy and ownership

Customize `AGENTS.md`'s `This repository` section to explain the source-repository role and direct a
reader to `README.md` and `make help`. Keep the vendored policy usable by preserving that section as
the target-local splice point.

Align the reference-routing tables in `AGENTS.md` and `SKILL.md`. The figure trigger must include
planning figures, writing plotting code, modifying figure outputs, and QA. Prerequisite guidance is
loaded only when a required host capability is missing or during bootstrap preflight, not for every
governed modification.

Reduce `SKILL.md`'s governed-work prose to routing: apply `AGENTS.md`, load only the relevant
reference, and do not restate policy to the user.

In `AGENTS.md`:

- retain the full/light/no-gate model and safety floor;
- reduce floor item 8 to the invariant that required skills are gates and missing skills block only
  dependent work;
- narrow configuration ownership to stable researcher-editable scientific and operational values,
  allowing implementation constants that are not settings;
- add normalization to the predictive-leakage list;
- distinguish an unavailable critique skill from an unavailable independent agent while allowing
  unrelated work to continue;
- keep the portable requirement to log rather than print, but move concrete libraries, sinks, and
  level conventions to bootstrap procedure;
- remove non-contractual essays about comments and test philosophy;
- add optional `agents/` to the generated layout because supported adapters install the canonical
  simplifier profile there.

## Canonical simplifier and adapters

`agents/code-simplifier.md` remains the canonical, host-neutral profile. Remove language that causes
it to act autonomously or proactively; it runs only when explicitly delegated under the policy's
post-change review step.

Both adapters install an exact copy at `agents/code-simplifier.md`. Claude additionally produces
`.claude/agents/code-simplifier.md` by copying canonical `name` and folded `description` metadata and
the canonical body while omitting `standard_version`. Codex produces
`.codex/agents/code-simplifier.toml` using the same canonical name and description and instructions
that route the worker to `agents/code-simplifier.md`.

Each adapter follows the same conflict rule for generated profiles:

1. Write the expected file when it is missing.
2. Accept an existing byte-identical expected file on rerun.
3. Refuse to replace an existing customized file and leave it untouched.

Claude retains its existing protection for a foreign `CLAUDE.md` file or symlink. Codex continues to
create no `CODEX.md` sidecar.

## Procedural references

References retain unique procedure and replace copied policy with short pointers where context is
helpful.

`references/analysis.md` keeps the analysis-plan field template, reporting procedure beyond policy,
the one-critique-per-batch bootstrap clarification, separate missing-skill/missing-agent behavior,
and the statement that a skill is guidance rather than evidence. It drops the optional skill
catalog, repeated floor rules, repeated critique triggers, and the unsupported claim to own analysis
execution. Center/spread definitions and practical interpretation are recommendations unless
promoted to portable policy.

`references/configuration.md` keeps its four-way ownership decision, qualifying named Python
constants as implementation choices rather than researcher-editable settings. It replaces the
duplicated configuration tree with one sentence, reduces provenance to result-affecting override
recording, and keeps only test requirements not already owned by `AGENTS.md`.

`references/data.md` replaces "expected local location" with registry identity and received-form
description, explicitly keeping internal paths in `paths.py`. It removes repeated missingness and
inclusion-floor prose and the testing-fixtures section while preserving registry fields, validation,
data dictionaries, checksums, and optional per-dataset documentation.

`references/figures.md` assumes the required skill has already been invoked. It collapses repeated
scope policy and retains the pre-plot template, deterministic atomic stems, format directories,
assembly rules, cross-figure encodings, and full QA checklist. Typography requires a consistent
sans-serif rather than prescribing Arial or Helvetica.

## Bootstrap and prerequisites

Bootstrap preflight checks that the three exact required skill names resolve before the interview.
Installation and recovery details remain in `references/prerequisites.md` and are used only when a
capability is missing. Adapter installation and delegated-agent smoke testing occur after a target
repository exists, in the integration steps of `SKILL.md`.

The bootstrap interview explicitly asks for the supported Python minor and selected host adapter.
Examples use `3.XY` and `py3XY` placeholders tied to that answer. The default dev group drops unused
`coverage`. The Makefile skeleton shows the required `help`, `setup`, `test`, and verification
interface and instructs the bootstrapper to add project-specific quality, analysis, figure,
pipeline, and cleanup targets. R containers and `test-r` are created only when the interview says R
is required. The adapter, not bootstrap, installs the simplifier profile. The README checklist drops
the undefined reproducibility classification.

Prerequisites remain host-focused. Consolidate duplicated scientific-skill installation examples
with an `<codex|claude-code>` agent placeholder, explain that Node/`npx` is needed only for those
commands, and remove date-boxed upstream revision pins. Keep the marketplace distinction for
Superpowers, native resolver verification, no silent installation, no `CODEX.md`, the optional
Claude alias, and the distinction between file presence and successful resolution.

## Tests

`tests/vendor_test.sh` asserts that a fresh vendored target contains exactly one top-level entry and
that it is the canonical `AGENTS.md`. Remove obsolete `.bak` and named sidecar absence checks. Keep
the corrupt-source, malformed-target, same-filesystem staging, and failed-replacement tests.

`tests/adapter_test.sh` verifies:

- both adapters require a vendored `AGENTS.md`;
- Claude's policy alias protection remains intact;
- generated Claude metadata and body derive from the canonical profile;
- generated Codex metadata and routing derive from the canonical profile;
- reruns are byte-idempotent; and
- customized canonical or host-specific simplifier files are rejected and preserved.

`tests/consistency_test.sh` removes locks on deleted documentation names and headings. It checks the
four figure-reference triggers semantically instead of pinning a wrapped Markdown table row. It
retains adapter documentation, resolvable blob links, host-neutral portable policy, and sole
ownership of the concrete figure asset grammar.

All touched standard files use the release stamp `2026.08.13`.

## Verification and cleanup

Run `make format` and `make test`, inspect generated adapter fixtures and the final diff, and verify
that no unintended files are present. Because executable shell and tests change, delegate an
independent behavior-preserving review of changed adapter and test files using the canonical
code-simplifier profile. Apply any accepted simplification and rerun covering tests.

The already deleted obsolete design and plan files remain deleted under the user's explicit
worktree-cleanup authorization. This specification and its implementation plan are committed as
separate gate artifacts before implementation begins.
