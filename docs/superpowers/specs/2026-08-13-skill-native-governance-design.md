# Skill-Native Governance Design

## Purpose

Make `research-repo-standard` a skill that governs research repositories when invoked, rather than a
policy file that is copied into every target repository. The skill becomes the stable entry point,
the references own their detailed domain contracts, and this source repository receives a short
local `AGENTS.md` concerned only with maintaining the skill itself.

This change removes the vendoring workflow completely. It does not delete or rewrite policy files
that already exist in other repositories.

## Chosen architecture

Use a skill-native core with focused normative references:

- `SKILL.md` is the normative entry point. It owns applicability, precedence, modification gates,
  the non-negotiable safety floor, required-skill routing, bootstrap sequencing, destructive-action
  boundaries, governed-work sequencing, and completion requirements.
- `references/bootstrap.md`, `references/prerequisites.md`, `references/configuration.md`,
  `references/data.md`, `references/analysis.md`, and `references/figures.md` own the detailed
  procedures and templates within their named domains.
- `AGENTS.md` governs only this source repository. It identifies `SKILL.md` as the product, gives
  local contribution and verification instructions, and contains no portable research-repository
  policy.
- Host adapters install only the host-specific delegated simplifier profile.
- A target repository's README records the skill prerequisite, expected source provenance, recovery
  guidance, and the shortest reproduction path without copying normative policy.

The alternatives were rejected because a monolithic `SKILL.md` would make every invocation load all
procedural detail, while moving the core into another large governance reference would retain the
indirection that made ownership unclear. The chosen structure keeps the always-required rules
visible and loads specialized detail only when relevant.

## Policy migration

Move every portable rule that is still required from the current `AGENTS.md` into either the skill
core or exactly one reference. Do not preserve wording merely because it existed previously; keep a
rule only when it defines safety, scientific integrity, an interface, or a necessary procedure.

`SKILL.md` retains the following core behavior:

1. Explicit user, legal, institutional, journal, and data-use requirements take precedence.
2. Bootstrap and governed-repository modes are distinct.
3. Every requested modification follows the full, light, or no-gate classification, with uncertain
   work using the full gate.
4. Required skills are resolved through the host, and a missing skill blocks only dependent work.
5. The safety floor covers immutable raw data; honest gates; authorized estimand, inclusion, and
   data-contract changes; exploratory versus confirmatory status; missingness and inclusion as code;
   deterministic execution and seed 42 only when randomness is unavoidable; transactional outputs;
   and single-owner configuration.
6. Destructive work requires explicit authorization, narrow resolved targets, and a recoverability
   statement.
7. Governed work reads local instructions and project contracts, preserves unrelated work, updates
   tests and documentation with behavior, delegates required scientific critique and code
   simplification, verifies actual artifacts, and reports reproducibility boundaries.

The skill's reference-routing table uses broad semantic triggers so an agent cannot avoid a contract
through narrow wording:

- prerequisites: a required capability is unresolved, installation or recovery is requested, or a
  host integration must be verified;
- bootstrap: creating the repository structure, tool configuration, CI, Make interface, or initial
  project documentation;
- configuration: classifying, loading, using, changing, or overriding settings, paths, or
  provenance;
- data: acquiring, registering, preprocessing, describing, validating, or contracting data;
- analysis: scientific planning, estimands, design, inclusion, missingness, modeling,
  implementation, interpretation, or reporting;
- figures: planning a figure, writing plotting code, changing figure outputs, or performing QA.

References become direct owners rather than "expansions" of `AGENTS.md`. Remove duplicated floor
restatements and brittle cross-references such as numbered floor-item pointers. Preserve their
unique contracts, including the analysis-plan template; data registry, validation, dictionary,
checksum, and optional README requirements; configuration ownership, strict loading and overrides,
the ban on catch-all configuration files, migration procedure, and the prohibition on inventing a
seed field for a fully deterministic workflow; and the complete figure contract, atomic naming,
export, assembly, cross-figure encoding, and QA procedure.

Do not maintain per-file standard-version stamps or tests for version drift.

## Bootstrap behavior and skill pressure tests

Bootstrap preflight resolves the three exact hard-gate skills before the interview:
`superpowers:brainstorming`, `scientific-critical-thinking`, and `nature-figure`. File presence is
not resolution. Installation is never silent, and unresolved skills are not imitated or replaced.

The interview asks one question at a time and explicitly obtains the project identity and purpose,
scientific claim and analysis status, data/access constraints, Python minor version, optional R or
container needs, supported host adapter, license choice, and any project-specific workflow needs. It
does not silently choose a Python version, seed, adapter, license, or scientific default. A seed is
configured only if randomness is actually required. The approved answers drive the scaffold, initial
analysis and figure strategy, and README.

The existing writing-skills baseline exposed two pressure failures that the rewrite must correct:

- bootstrap agents must not replace the interview with reversible defaults, copy `AGENTS.md`, skip
  required skill preflight, or invent seed 42 for a deterministic workflow;
- figure agents must inspect rendered PDF as well as SVG rather than treating file existence or a
  PNG preview as complete QA.

After the rewrite, fresh agents rerun the governed scientific-change, exploratory-figure, bootstrap,
and delegated-simplification scenarios without being shown the expected answers. All requirements
must pass, with explicit rendered SVG and PDF inspection in the figure scenario.

## Vendoring removal

Delete `vendor.sh` and `tests/vendor_test.sh`. Remove every executable, documentation instruction,
test, and prerequisite that reads, copies, stages, aliases, or requires the source `AGENTS.md` in a
target repository. Bootstrap proceeds directly from the approved scaffold design to file creation
and host integration.

No code in this repository may create, replace, link, or delete a target `AGENTS.md`, `CLAUDE.md`,
or `CODEX.md`. Existing files with those names may contain unrelated or customized instructions and
remain untouched.

Legacy artifacts are handled conservatively. Documentation may identify former generated paths and
explain migration, but automation only detects and reports them. Removing or replacing a legacy
policy, alias, or simplifier profile requires explicit authorization after its exact target and
customization status are established.

## Delegated simplifier identity

Rename the repository's delegated profile from `code-simplifier` to `research-code-simplifier`
everywhere. The new name avoids collision with Claude's native `code-simplifier` plugin.

The canonical host-neutral source is `agents/research-code-simplifier.md`. It runs only after an
explicit delegation required by the skill, invokes the exact `research-repo-standard` skill, reads
the references relevant to the changed code, honors unrelated repository-local instructions, and
preserves behavior. It does not act autonomously, expand scope, or make scientific decisions.

The installed handles are:

- Claude: `.claude/agents/research-code-simplifier.md`
- Codex: `.codex/agents/research-code-simplifier.toml`

Documentation, tests, error messages, and generated metadata use the exact new name. The old generic
name is permitted only in migration prose that explicitly identifies a legacy artifact or Claude's
native plugin.

The two superseded design documents and two superseded implementation plans currently under
`docs/superpowers/` describe vendoring, shared profiles, aliases, version stamps, and the old
generic name as active behavior. Delete those four obsolete process artifacts during implementation;
Git retains their history. The new design and plan replace them and are the only active gate
artifacts.

## Adapter behavior

Each adapter installs exactly one host-specific profile and has no shared target output:

- the Claude adapter writes only the Claude Markdown profile;
- the Codex adapter writes only the Codex TOML profile.

Both generated profiles derive the canonical name, folded description, and body or instructions from
`agents/research-code-simplifier.md`. Only syntax required to wrap that material in the host's
Markdown or TOML format may be host-specific. Tests fail if either output drifts from the canonical
source. Each profile invokes `research-repo-standard` by exact name and does not depend on a target
`AGENTS.md`, a shared top-level `agents/` directory, or an alias file.

Because the adapters have disjoint outputs, remove the current cross-adapter shared transaction and
lock protocol. Retain a smaller safe single-file publication algorithm:

1. Resolve the target physically and reject symlinked or escaping parent and leaf paths.
2. Render and validate a temporary file beside the destination.
3. Publish only when the destination is absent, using a create-only atomic operation so a concurrent
   or late custom file is never overwritten.
4. Accept an existing byte-identical destination as an idempotent rerun.
5. Reject a differing file or symlink and leave it untouched.
6. Treat successful create-only publication as the commit point. Before that point, failures and
   HUP, INT, or TERM remove only the staging inode owned by the invocation. After that point, leave
   the complete destination installed; never roll it back.
7. Report nonzero with a precise diagnostic when an owned staging artifact cannot be removed, and
   preserve evidence that cannot be removed safely.

Concurrent installations for the same host must never overwrite differing content. Concurrent Claude
and Codex installations may proceed independently without a shared lock.

Adapters do not install or claim to resolve skills. After adapter installation, the skill performs a
host-native delegated smoke test that reports the resolved provenance of `research-repo-standard`
and confirms that `research-code-simplifier` resolves through the expected profile. If the host
cannot establish either fact, dependent work stops with recovery guidance. Source-repository
acceptance uses structural generation tests for both supported hosts. A real resolver smoke test is
required for each selected and available host; an unavailable host is reported as a manual
verification boundary and does not invalidate otherwise complete source-repo verification.

## Documentation and ownership cleanup

Rewrite the source README around the skill-native workflow:

- explain the bootstrap and governed-repository modes;
- show skill resolution and direct adapter installation without a vendor step;
- document the two host-specific profile outputs and smoke-test requirement;
- add the source `Makefile` to the repository tree;
- explain conservative migration of legacy policy and profile artifacts;
- distinguish this source repository's maintenance commands from commands generated for a research
  repository.

Keep prose concise and point to a single normative owner. Remove stale `post-vendor`, alias,
sidecar, canonical target-policy, and copied-policy terminology. References must not restate the
skill's gate or floor when a short link is sufficient, and `SKILL.md` must not reproduce detailed
reference templates.

The replacement source `AGENTS.md` is approximately 20–30 lines. It states the repository's purpose,
identifies `SKILL.md` and its references as the maintained product, requires preservation of skill
and adapter safety contracts, directs contributors to nearby tests and `make help`, protects
unrelated work, and names the local verification commands. It contains no generated-repository
layout, scientific policy, domain contract, vendoring instruction, or release-date bookkeeping.

## Test design

Replace obsolete tests rather than retaining assertions for removed behavior.

Static and consistency tests establish that:

- no live command reads, copies, stages, aliases, or requires source `AGENTS.md` for a target;
- no adapter or bootstrap path creates `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or target `agents/`;
- each adapter documents and writes exactly one host-specific profile;
- generated profiles use `research-code-simplifier`, invoke `research-repo-standard`, and have no
  target-policy dependency;
- all routing triggers and unique domain invariants have one clear owner;
- legacy artifacts are preserved pending explicit migration authorization;
- no per-file standard-version or version-drift checks remain;
- stale vendoring and generic active profile terminology is absent.

Dynamic fixtures seed target `AGENTS.md`, `CLAUDE.md`, and `CODEX.md` with sentinel bytes and record
their inodes, then prove both adapters leave all three unchanged. A clean-target fixture proves that
neither adapter creates any of them.

Adapter behavior tests cover clean installation, byte-identical reruns, customized destinations,
symlinked parents and leaves, physical containment, rendering failures, signals, create-only publish
collisions, post-effect failures, cleanup failures, same-host contention, and independent concurrent
Claude/Codex installation. Tests inspect the generated profile content and verify that stage
directories and transaction artifacts do not remain after successful or safely recoverable runs.

The large shared-transaction finalization suite is replaced with focused single-output adapter
tests. Assertions must prove the intended fault was reached and validate diagnostics, not merely
observe a generic nonzero exit. The four writing-skills pressure prompts and their blind scoring
rubrics are stored with the tests so GREEN behavior is reproducible outside this conversation.

## Review and acceptance

Implementation follows test-driven development. Establish failing tests for removed vendoring,
single-output adapters, the new profile identity, and revised ownership before changing behavior;
then make the smallest implementation that passes and simplify only while tests remain green.

Use independent agents in review waves:

1. policy ownership: `AGENTS.md`, `SKILL.md`, applicability, gates, safety floor, and bootstrap;
2. domain references: complete line-by-line check for unique invariants, duplication, omissions, and
   contradictions;
3. runtime safety: adapters, generated profiles, containment, atomic publication, concurrency,
   signals, and cleanup;
4. test and documentation coverage: removed behavior, terminology, README commands, migration, and
   semantic rather than punctuation locks;
5. fresh whole-repository simplification and final compliance review after focused findings are
   resolved.

Final verification includes the complete Make test and format interfaces, shell syntax checks under
the available current Bash and Apple Bash 3.2, adapter fault and concurrency tests, clean-target and
idempotent-rerun smoke tests, direct inspection of generated Claude and Codex profiles, the four
fresh-agent skill pressure scenarios, stale-term searches, and a clean worktree inventory. Any
unavailable host-native resolver or delegated-agent boundary is reported rather than simulated;
structural generation tests still cover both host formats.

Acceptance requires all tests to pass, every approved rule to have one clear owner, no target policy
file to be created or modified, every selected and available host integration to resolve the
unambiguous `research-code-simplifier` handle, both host formats to pass structural generation
tests, and independent reviewers to have no unresolved material findings.
