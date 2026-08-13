# Adapter Transaction Completion and Version-Metadata Removal Design

**Date:** 2026-08-13

## Purpose

Complete the adapter transaction guarantee after whole-branch review exposed a post-publication
rollback race, and remove per-file `standard_version` metadata and drift checks at the user's
request. This amendment supersedes only the direct-copy/publication details and version-stamp
requirements in the earlier contract-harmonization design and plan. All other approved ownership,
safety, adapter, reference, and test requirements remain in force.

## Transaction model

Both adapters validate the target and structural destinations before transaction mutation, then
validate generated leaves against their completed stages before publication. They
reject symlinked output parents, reject generated-profile leaf symlinks, preserve existing exact
regular files, and refuse to replace customized files. Claude's exact `CLAUDE.md -> AGENTS.md`
policy alias remains the sole permitted generated symlink destination.

Before creating any output parent or staging any artifact, both adapters acquire the same
target-local adapter lock by atomically creating the exact lock directory with `mkdir`. A fixed
target-local acquisition guard serializes only the ambiguous lock-creation transition. Each
invocation first records no-follow absence of a predictable, PID-and-nonce-qualified claim path,
then atomically creates the unique claim directory without following any existing path. Only that
recorded absence-to-exact-directory-inode transition establishes ownership. It writes its strict
PID, hardcoded protocol adapter identifier, and nonce token to a regular claim file with shell
noclobber semantics, and records both inodes. It atomically hard-links that claim to the exact guard
path with the POSIX two-path `link SOURCE TARGET` utility, which never treats an existing target
directory as a destination container. It owns the guard only when the guard has the claim's exact
inode and bytes, regardless of the `link` command status. A collision or any
regular, directory, dangling-symlink, internal-directory-symlink, or external-directory-symlink
claim/guard state fails closed without traversal or replacement. Existing exact guard owners are
inspected without mutation and preserved for manual intervention or reported as live contention
when their exact valid owner is live.

Only the proven guard owner attempts the exact lock-directory `mkdir`. While holding the guard it
first records that the exact lock path is absent by no-follow inspection; a pre-existing path
branches to read-only inspection and never receives an owner. Only an absent-to-exact-directory
transition may establish creation. The invocation records the exact directory path and inode
observed immediately after `mkdir`, regardless of command status. It hard-links the same claim
inode as the exact owner path with `link SOURCE TARGET` and treats the lock as owned only after exact
guard/claim/directory/owner path, inode, and byte verification, with the claim and lock directories
each containing its recorded owner as the sole child. This evidence distinguishes a
post-effect nonzero return from a pre-effect failure without misattributing a competing adapter's
directory. A live owner is reported as contention. Every dead-PID, ambiguous-liveness, malformed,
missing, non-directory, or symlink lock state is preserved and reported for manual intervention;
locks are never automatically reclaimed.

Success, ordinary failure, and trapped signals release serialization only after all other
finalization succeeds and only when the invocation-owned guard, claim, lock directory, and owner
file retain their exact recorded identities. The claim directory must retain its recorded inode
and contain exactly its recorded owner file; a replacement directory or foreign extra child stops
the dependent release chain before the lock is changed, including partial/no-guard cleanup. The
lock directory likewise must retain its recorded inode with the exact owner as its sole child.
Every recorded guard, claim, lock, and owner component is prevalidated before the first dependent
removal in both full and partial ownership states.
Cleanup first aggregates every independent output,
stage, staging-directory, and output-parent result. Only if those are complete does the dependent
release chain remove the owner, verify and remove the lock directory, remove the claim file and
directory, and unlink the guard last. Any residual or changed state stops that dependent chain
while other independent cleanup continues. Because the exact guard remains until the last verified
step, any incomplete release retains serialization; if lock-directory removal fails after owner
removal, cleanup relinks the exact guard inode as owner when the original lock directory remains.
A created but not owned lock directory may be removed only with inode-checked `rmdir` while empty.
If rollback or finalization is incomplete, the invocation retains its owned lock and acquisition
guard for manual intervention. This serializes cooperating Claude and Codex installations without
traversing or deleting pre-existing lock paths.

Each filesystem creation command, including exact unique-claim-directory creation, stage-file and
staging-directory `mktemp`, and Claude's staged-alias `ln -s`, and only its
immediate path/inode bookkeeping forms one creation transition. Claim-file noclobber creation uses
the same deferral until its exact type, inode, and bytes are recorded, but assigns ownership only
when the shell redirect itself succeeded; an exact-token collision remains foreign. A trapped signal arriving in
that transition records the first conventional signal status (`HUP=129`, `INT=130`, `TERM=143`) and
is handled through normal cleanup only after the adapter records the command status and exact
filesystem evidence. This applies to the acquisition guard link, lock directory, owner link, and
every invocation-created output parent. Each parent is recorded no-follow absent immediately before
`mkdir`, and ownership requires that absence-to-exact-directory-inode transition while the adapter
lock excludes cooperating creators. Signal deferral extends no further. A signal status takes
precedence over a simultaneous command failure.

Every new output is staged beside its destination. Before publication, the adapter records the
staged artifact's filesystem inode and arms rollback. It then publishes by same-filesystem atomic
rename. Claude's alias is also built as a target-local staged symlink and published by rename.

Rollback identifies ownership by inode, not by a flag assigned after publication and not by content
alone. On an ordinary error or trapped `HUP`/`INT`/`TERM`, cleanup removes a destination only when its
current inode equals the inode recorded for this invocation's staged artifact. Therefore:

- a rename that takes effect and then reports failure is rolled back;
- a trapped `HUP`, `INT`, or `TERM` delivered after the filesystem effect but before the next shell
  statement is rolled back;
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
success and failure. Cleanup is best-effort across every invocation-owned destination, stage,
staging directory, output parent, owner record, lock directory, claim, and guard: one failure does
not suppress later independent cleanup attempts. Cleanup verifies postconditions, so a removal
that takes effect and then reports nonzero is complete, while a same-inode residual is an error.
Each incomplete item produces a precise diagnostic. The original ordinary-error or signal status
is preserved; cleanup alone changes an otherwise successful status to `1`. Success output is
emitted only after complete finalization. A changed or missing lock owner makes success fail closed
and retains serialization for manual intervention.

The guarantee covers ordinary failures and trapped `HUP`/`INT`/`TERM`; it does not claim recovery
from untrappable process or machine termination.

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
while one is live and that the contender exits nonzero without removing the owner's lock. Run the
complete fail-safe matrix independently against both adapter implementations: regular-file and
ordinary-directory lock paths; missing, malformed, directory, and symlink owner states; valid live
and dead/nonzero-liveness owners; every invalid token grammar; same-PID never-acquired state;
simultaneous stale contenders; and dangling, internal-directory, and external-directory lock
symlinks. Every case preserves exact inode/content/link identity, creates no adapter-specific
output, and writes nothing outside the target.

Run the corresponding no-follow matrix for claim collisions and fixed-guard regular files,
directories, dangling symlinks, internal-directory symlinks, and external-directory symlinks. Add
an exact-token noclobber collision that preserves the foreign owner inode and bytes. Add
pre-effect failure and effect-then-signal-then-nonzero cases for unique claim-directory creation,
claim-to-guard linking, claim-to-owner linking, each stage `mktemp`, and Claude's staged-alias
`ln -s`. Require the exact two-path `link` primitive and exact path/source/destination, inode,
adapter PID, invocation count, effect marker, status, residue, and serialization-retention evidence.
An injected unsupported hard-link operation fails before output-parent mutation and cleans its
exact owned claim when cleanup succeeds.

During the final acquisition-link transition, independently add a foreign extra child to the claim
directory and the lock directory. Both adapters must reject each changed inventory before any
output-parent or stage attempt and preserve the complete serialization evidence for manual
intervention.

Prove unique nonces and release after success, ordinary error, and trapped signals. Invoke each
adapter through renamed and symlinked entry points and require its lock token to retain the
hardcoded protocol identifier (`claude-code.sh` or `codex.sh`) independently of the diagnostic
basename. Pre-existing declared-output rollback tests record inode identity as well as checksums or
symlink targets and verify complete stage and invocation-created-directory cleanup.

Inject `HUP`, `TERM`, and `INT` after a wrapper performs the real lock-directory `mkdir`; the
required TERM case then returns nonzero. Prove both adapters record the exact effect, signal,
status, path, inode, and parent PID, exit with the defined signal status without hanging, and remove the
invocation-created empty lock directory without creating outputs or stages. Repeat the
effect-then-signal-then-nonzero transition for the first output parent and every nested output
parent in both adapters. A missing-owner fixture must retain the exact pre-existing empty directory
inode after refusal.

For each adapter, replace a just-published destination atomically with a different-inode sentinel
before injected ordinary-failure and signal cleanup. The sentinel must survive with exact identity,
while every other visible invocation-owned output rolls back. Cleanup-fault cases cover stages,
owned outputs, output/staging directories, lock owner removal, and lock-directory removal. They
require precise diagnostics, best-effort aggregation, nonzero final status, absence of success
output, and retention of invocation-owned serialization. Changed lock-owner bytes likewise turn an
otherwise successful run into failure and retain the lock. Before dependent release, replacing the
claim or lock directory or adding a foreign child must preserve the exact lock, guard, and remaining claim
state. During full or partial release, a missing or different-inode serialization component is an
incomplete cleanup, preserves foreign state, and retains the remaining owned serialization.

Every partial-copy, pre-effect rename, post-effect rename/signal, directory-creation, cleanup, and
vendor failed-rename double records an external marker containing its exact invocation count,
source or path, destination where applicable, and adapter/vendor PID. A test is invalid unless it
requires that evidence and therefore cannot pass through an earlier abort. Post-effect signal
tests require exact `HUP=129`, `TERM=143`, and `INT=130` statuses; ordinary and cleanup-only
failures require status `1`, and cleanup faults never replace an already nonzero original status.

## Version-metadata removal

Remove `standard_version` metadata from:

- `AGENTS.md`;
- `SKILL.md`;
- `README.md`;
- every `references/*.md` file; and
- `agents/code-simplifier.md`; and
- `vendor.sh` output and parsing.

Remove all code and tests that parse, require, propagate, strip, synchronize, or audit that field.
Claude generation now reads canonical `name` and folded `description`, writes those two frontmatter
keys, and copies the canonical body. Codex generation continues to use canonical name and
description. Missing name or description remains an adapter error.

No repository-level version file replaces the removed metadata. Git history is the sole record of
file evolution, and the suite contains no version-drift check.

The target filesystem must support regular-file hard links for adapter lock ownership. If it does
not, the adapter fails closed before output mutation, reports the exact blocker, and removes only
the exact claim paths whose ownership it proved.

Vendor safety behavior remains governed: fresh vendoring succeeds explicitly; re-vendoring proves
that canonical content is actually replaced while preserving the complete local repository
section; malformed targets are preserved byte-for-byte; same-filesystem staging proves the exact
rename call; and a failed final rename proves its exact call while preserving the previous target
and cleaning staging. Vendor success output is version-neutral.

## Verification

Run shell syntax checks including `vendor.sh`, under the current shell and Apple Bash 3.2; the
focused effect-then-fail, signal, creation-transition, different-inode, cleanup-failure, and lock
matrix cases; all adapter/vendor/consistency tests; formatting; and `git diff --check`. Perform a
one-time no-version audit including `vendor.sh` without adding persistent drift machinery. Inspect
generated Claude and Codex artifacts in real temporary targets, including exact canonical copies,
derived metadata, neutral Codex TOML, alias behavior, rerun checksums, containment, rollback,
serialization retention on incomplete cleanup, and staging cleanup.

Because adapters and shell tests change, an independent agent applies the canonical
`agents/code-simplifier.md` profile to those files after implementation and before completion. A
separate whole-change reviewer checks the amendment, implementation, tests, and verification
evidence before the branch is offered for integration.
