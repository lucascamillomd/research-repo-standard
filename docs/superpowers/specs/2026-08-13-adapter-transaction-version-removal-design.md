# Adapter Transaction Completion and Version-Metadata Removal Design

**Date:** 2026-08-13

## Purpose

Complete the adapter transaction guarantee after whole-branch review exposed a post-publication
rollback race, and remove per-file `standard_version` metadata and drift checks at the user's
request. This amendment supersedes only the direct-copy/publication details and version-stamp
requirements in the earlier contract-harmonization design and plan. All other approved ownership,
safety, adapter, reference, and test requirements remain in force.

## Transaction model

Both adapters continue to validate the target and every declared destination before mutation. They
reject symlinked output parents, reject generated-profile leaf symlinks, preserve existing exact
regular files, and refuse to replace customized files. Claude's exact `CLAUDE.md -> AGENTS.md`
policy alias remains the sole permitted generated symlink destination.

Before creating any output parent or staging any artifact, both adapters acquire the same
target-local adapter lock by atomically creating the exact lock directory with `mkdir`. Only the
invocation that successfully creates that directory writes its strict PID, exact adapter name, and
nonce token to the owner file inside. It treats the lock as owned only after an exact reread. A live
owner is reported as contention. Every dead-PID, ambiguous-liveness, malformed, missing, non-directory,
or symlink lock state is preserved and reported for manual intervention; locks are never
automatically reclaimed. Success, ordinary failure, and trapped signals release a lock only when
the invocation marked it owned and its owner file still contains the exact unique token. A created
but not owned lock directory may be removed only with `rmdir` while empty. This serializes
cooperating Claude and Codex installations without traversing or deleting pre-existing lock paths.
The exact `mkdir` and its immediate success bookkeeping form one acquisition transition: a trapped
signal arriving in that transition is recorded and handled through normal cleanup only after the
adapter records whether its own `mkdir` created the directory. Signal deferral extends no further.

Every new output is staged beside its destination. Before publication, the adapter records the
staged artifact's filesystem inode and arms rollback. It then publishes by same-filesystem atomic
rename. Claude's alias is also built as a target-local staged symlink and published by rename.

Rollback identifies ownership by inode, not by a flag assigned after publication and not by content
alone. On an ordinary error or trapped `INT`/`TERM`, cleanup removes a destination only when its
current inode equals the inode recorded for this invocation's staged artifact. Therefore:

- a rename that takes effect and then reports failure is rolled back;
- a signal delivered after the filesystem effect but before the next shell statement is rolled back;
- a rename that fails before taking effect leaves no destination to remove;
- a pre-existing artifact is never marked as invocation-owned;
- a destination whose invocation-owned inode is not visible when cleanup verifies it is preserved;
  and
- rollback never reaches outside the validated target.

The inode check and subsequent unlink are separate filesystem operations. The guarantee is
deliberately limited to the identity visible when cleanup verifies the destination; it does not
claim atomic protection from adversarial out-of-band replacement between that check and unlink. The
target-local lock prevents cooperating adapter installations from creating that interleaving.

Rollback is disarmed only after every declared output is published. Staging paths are removed on
success and failure. The guarantee covers ordinary failures and trapped `INT`/`TERM`; it does not
claim recovery from untrappable process or machine termination.

## Transaction tests

Adapter tests must prove the failure mechanism actually ran. Fault wrappers record invocation count
and an explicit marker or diagnostic. Tests fail if the intended publish operation was not reached.

For each adapter, cover a rename wrapper that performs the real rename and then returns failure.
Assert that the destination briefly received this invocation's inode through the wrapper's marker,
the adapter exits nonzero, all newly created declared outputs are absent afterward, staging is
clean, and pre-existing outputs remain untouched.

Add a focused trapped-signal case in which publication takes effect before the adapter receives
`TERM`. Assert the same rollback and preservation properties. Retain existing pre-effect failure,
parent-symlink, leaf-symlink, paths-with-spaces, customized-file, exact-rerun, and ordinary artifact
coverage.

Add focused serialization cases proving that a Claude and Codex invocation contend on the same lock
while one is live and that the contender exits nonzero without removing the owner's lock. Exercise
regular-file, ordinary-directory, valid-owner, malformed/missing-owner, dangling-symlink,
directory-symlink, and external-directory-symlink lock paths; all must be preserved without output
mutation or writes through existing paths. Reject every non-exact token grammar, and prove nonzero
owner-liveness checks, same-PID never-owned cleanup, and simultaneous stale contenders preserve the
lock for manual intervention. Prove unique nonces and release after success, ordinary error, and
trapped `TERM`. Pre-existing declared-output rollback tests record inode identity as well as
checksums or symlink targets and verify complete stage and invocation-created-directory cleanup.
Inject `TERM` after a wrapper performs the real lock-directory `mkdir` but before that wrapper
returns, and prove both adapters record the effect, exit nonzero without hanging, and remove the
invocation-created empty lock directory without creating outputs or stages. A missing-owner fixture
must retain the exact pre-existing empty directory inode after refusal.

## Version-metadata removal

Remove `standard_version` metadata from:

- `AGENTS.md`;
- `SKILL.md`;
- `README.md`;
- every `references/*.md` file; and
- `agents/code-simplifier.md`.

Remove all code and tests that parse, require, propagate, strip, synchronize, or audit that field.
Claude generation now reads canonical `name` and folded `description`, writes those two frontmatter
keys, and copies the canonical body. Codex generation continues to use canonical name and
description. Missing name or description remains an adapter error.

No repository-level version file replaces the removed metadata. Git history is the sole record of
file evolution, and the suite contains no version-drift check.

## Verification

Run shell syntax checks, the focused effect-then-fail and signal rollback cases, all adapter/vendor/
consistency tests, formatting, and `git diff --check`. Inspect generated Claude and Codex artifacts
in real temporary targets, including exact canonical copies, derived metadata, neutral Codex TOML,
alias behavior, rerun checksums, containment, rollback, and staging cleanup.

Because adapters and shell tests change, an independent agent applies the canonical
`agents/code-simplifier.md` profile to those files after implementation and before completion. A
separate whole-change reviewer checks the amendment, implementation, tests, and verification
evidence before the branch is offered for integration.
