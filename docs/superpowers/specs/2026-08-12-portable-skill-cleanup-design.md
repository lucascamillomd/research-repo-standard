# Portable Skill Cleanup Design

## Goal

Make the research repository standard work as a host-neutral skill contract for both Codex and
Claude Code, remove the retired source-standard drift checker, consolidate repeated guidance under
explicit canonical owners, and establish reproducible formatting, linting, and validation for every
source file in this repository.

The cleanup must preserve existing unrelated working-tree changes and the safety properties of
ordinary vendoring.

## Architecture

### Portable core

`AGENTS.md` is the portable governed-repository contract. It owns the compact rules that must remain
available without a particular host, installed skill, delegated-agent profile, or network
connection:

- modification gates and safety floors;
- scientific, data, configuration, and repository invariants;
- task triggers;
- project-owned documentation and configuration boundaries; and
- general naming namespaces.

Core vendoring installs or updates `AGENTS.md` only. It does not require a Claude-specific sidecar
and does not create a duplicate Codex policy file. Codex consumes `AGENTS.md` directly.

### Host adapters

Host-specific integration is optional and layered on top of the portable core.

A Claude Code adapter may create the relative `CLAUDE.md -> AGENTS.md` alias and install a
Claude-specific delegated-agent configuration. A Codex adapter may install only the configuration
that current Codex supports; it does not create `CODEX.md` or duplicate the portable contract.

Before implementation, verify current Codex and Claude Code integration behavior from authoritative
documentation. Do not invent a Codex configuration path or rely on undocumented skill, symlink,
scope, or delegated-agent behavior.

Portable policy describes required capabilities and outcomes rather than host commands. For example,
it requires an independent review agent and a code-simplification pass that apply the canonical
profile; host adapters decide how to launch those capabilities.

### Skill and reference loading

`SKILL.md` owns applicability, bootstrap-versus-governance mode selection, workflow orchestration,
and progressive-disclosure routing. It is not a second policy owner.

Detailed references are loaded on demand. Static tests may verify that routing instructions exist,
but neither the documentation nor tests may claim they prove an agent actually loaded or followed a
reference at runtime.

## Canonical ownership

### `AGENTS.md`

Owns portable normative governance, including compact modification gates, invariants, task triggers,
configuration ownership classes, repository boundaries, and general naming namespaces.

It remains sufficient for routine governed work when the source skill or detailed references are
unavailable. Detailed procedure may live elsewhere, but a required safety or modification rule may
not exist only in a reference or host adapter.

### `SKILL.md`

Owns the skill entry point, bootstrap flow, governance flow, and task-to-reference routing. It links
to canonical owners rather than restating their detailed contracts.

For figure work, it explicitly requires loading `references/figures.md` before figure planning,
plotting code, figure-output modification, and figure QA.

### `references/prerequisites.md`

Owns exact prerequisite capability names, authoritative sources and validated versions, discovery,
installation, functional verification, delegated-agent propagation, session or reload behavior, and
recovery. Host-specific Claude Code and Codex setup belongs in separate sections here.

### `references/bootstrap.md`

Owns only initial project tooling and scaffold examples for files that do not yet exist. It assumes
prerequisite preflight has completed and links to configuration, figure, and other detailed owners
instead of repeating their policy.

After bootstrap, the generated repository's files own their concrete values and commands.

### Domain references

- `references/configuration.md` owns detailed classification, loading, override, provenance,
  migration, and configuration-test procedure.
- `references/data.md` owns dataset registry mechanics, acquisition, schemas, dictionaries,
  checksums, validation, and fixtures.
- `references/analysis.md` owns analysis planning, reporting mechanics, leakage guidance, and
  independent critique procedure.
- `references/figures.md` owns the figure contract, figure-specific identifier and asset naming
  grammar, layout and rendering mechanics, source-data exports, and QA.

`AGENTS.md` may identify these task categories and mandatory gates, but it does not repeat the
detailed procedure.

### `agents/code-simplifier.md`

Owns the host-neutral simplification mission, process, scope, and behavior-preservation limits. It
does not select an Anthropic or OpenAI model and does not restate repository naming or configuration
policy. Host adapters translate or install the canonical profile using supported host mechanisms.

### Other files

`README.md` remains a short, non-normative human entry point and repository map.
`docs/superpowers/specs/` and `docs/superpowers/plans/` are historical, non-normative process
records. They may receive mechanical formatting and link validation, but they are not rewritten
whenever live policy changes.

## Naming consolidation

`AGENTS.md` briefly defines general namespaces such as repository names, package names, stage
directories, scripts, tests, and dataset identifiers.

Figure publication identifiers, panel assets, source-data files, and their concrete grammar belong
only in `references/figures.md`. Other files route figure work to that owner and may show a linked
example, but do not independently define the grammar.

The same policy-versus-procedure split applies to prerequisites, configuration, data, and analysis
guidance. A repeated passage is removed only after the canonical owner contains the complete rule
and every consumer has a clear route to it.

## Drift-check removal

Retire source-to-governed-repository drift comparison completely. Do not leave an undocumented
low-level checker.

Remove together:

- `standard-check` and drift-check claims in skill, README, and bootstrap text;
- the `vendor.sh --check` option, comparison implementation, check-specific messages, and special
  exit-code contract;
- drift-specific cases in `tests/vendor_test.sh`; and
- the corresponding documentation assertion in `tests/consistency_test.sh`.

Do not add a replacement `standard-check`, drift, or equivalent source-comparison target.

Retain ordinary vendoring safety:

- source and target structural validation;
- preservation of the target-owned `## This repository` section;
- the `## Using this standard` boundary;
- build-before-replace and transactional replacement behavior; and
- version provenance pending any separate decision about stamp semantics.

Dependency integrity commands such as `uv sync --locked` and `uv lock --check` remain. They are
unrelated to source-standard drift checking.

The Claude Code alias moves from core vendoring into the optional Claude adapter. Core vendoring
tests therefore validate portable `AGENTS.md` behavior independently of adapter tests.

## Formatting and validation

Introduce a minimal, pinned repository-local quality toolchain for the source types that exist here.

The toolchain covers:

- Markdown formatting and linting for root Markdown, `references/`, `agents/`, and
  `docs/superpowers/`;
- shell formatting and linting for `vendor.sh` and `tests/*.sh`;
- `bash -n` syntax validation;
- skill and agent-profile frontmatter validation;
- whitespace validation;
- relative-link, reference-routing, and canonical-ownership consistency checks; and
- existing behavioral tests through `make test`.

Provide separate mutating format and non-mutating check commands. A single aggregate non-mutating
Make target may be added, but it must not be named `standard-check`. Formatter and linter versions
and style configuration are committed so results do not depend on globally installed defaults.

The implementation plan will select the smallest practical pinned toolchain after checking what can
cover Markdown, shell, and frontmatter without unnecessary dependencies.

## Tests

Update behavioral tests to cover:

- fresh portable vendoring of `AGENTS.md`;
- preservation of the project-owned section;
- malformed-boundary and transactional-failure behavior;
- removal of the drift-check interface;
- optional host adapters independently from the core;
- host-neutral code-simplifier profile and adapter references;
- task routing from `SKILL.md` to each canonical reference;
- figure routing to `references/figures.md` without duplicating its naming grammar;
- prerequisite delegation from bootstrap to `references/prerequisites.md`;
- frontmatter, links, formatting, lint, shell syntax, and whitespace; and
- the retained reduced-document and lab-notebook contracts.

Use focused positive assertions about canonical owners and routing. Avoid broad negative grep rules
that reject historical or explanatory mentions merely because they name an old concept.

## Verification

Before completion:

1. Record and preserve the pre-existing modifications to `SKILL.md` and `references/bootstrap.md`
   and the untracked plan under `docs/superpowers/plans/`.
2. Verify Codex and Claude Code adapter behavior from current authoritative documentation.
3. Run the pinned formatter over all in-scope files.
4. Run the aggregate non-mutating formatting and lint checks.
5. Run shell syntax checks and `make test`.
6. Search live policy, implementation, and tests for residual `standard-check`, `vendor.sh --check`,
   check-specific exit codes, and stale drift-test claims.
7. Review every remaining use of words such as `drift`, `sync`, and `consistency` by meaning rather
   than deleting them globally.
8. Run `git diff --check` and inspect the complete diff for accidental changes to protected
   vendoring boundaries, data safety, or unrelated working-tree edits.
9. Run equivalent small policy-routing smoke tests in Codex and Claude Code where the available
   harnesses permit it, and report any step that could not be executed.

## Scope boundaries

This cleanup does not silently decide unrelated issues already present in the working tree,
including:

- Python-minor interview placement;
- ownership of stable operational settings;
- license-warning wording;
- version-stamp semantics;
- stronger non-Git vendoring safeguards; or
- disposition of the existing untracked reduced-documentation plan.

If implementation cannot proceed without one of these decisions, stop and ask rather than folding an
assumption into the cleanup.
