# Adapter Transaction Completion and Version-Metadata Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the adapters' post-publication rollback race and remove per-file version metadata and drift enforcement from the standard.

**Architecture:** Claude and Codex serialize cooperating installations through one target-local owner-token lock. Each adapter stages outputs on the destination filesystem, records the staged inode before publication, and uses inode identity to roll back only artifacts whose invocation-owned inode is visible when cleanup verifies the destination after ordinary errors or trapped signals. Standard files carry no version field; Git history is the only evolution record and adapters derive only canonical name and description.

**Tech Stack:** Bash compatible with the repository's macOS assumptions, awk, `ls -di`, same-filesystem `mv`, Markdown, Make, Git.

## Global Constraints

- This plan supersedes only the direct-copy/publication details and every version-stamp requirement in `docs/superpowers/plans/2026-08-13-contract-harmonization.md`.
- Preserve all other approved policy, ownership, adapter, reference, and test behavior.
- Rollback may remove a destination only when the invocation-owned inode is visible when cleanup verifies that destination. Do not claim atomic protection from adversarial out-of-band replacement between inode check and unlink.
- Preserve every pre-existing output and every destination whose inode does not match at cleanup verification.
- Both adapters acquire the same exact target-local lock directory with atomic `mkdir` before output-parent creation or staging. A target-local hard-link acquisition guard proves which invocation owns a post-effect/nonzero lock creation; only the guard owner attempts `mkdir`, and only exact recorded guard/claim/directory/owner inode and byte evidence establishes ownership. Protocol adapter identifiers are hardcoded independently of the diagnostic basename. Never reclaim an existing lock automatically. Preserve every live, dead-PID, ambiguous-liveness, malformed, missing, non-directory, or symlink lock for manual intervention; release serialization only after complete finalization and exact identity verification.
- Reject symlinked output parents and generated-profile leaf symlinks; permit only the exact Claude policy alias `CLAUDE.md -> AGENTS.md`.
- Stage each output on its destination filesystem and publish it by same-filesystem atomic rename.
- Arm rollback before the first publish and disarm it only after all declared outputs publish successfully.
- Cover ordinary failures and trapped `HUP`/`INT`/`TERM`; do not claim recovery from untrappable process or machine termination.
- Remove `standard_version` metadata, parsing, propagation, stripping, synchronization, and audits without introducing a replacement version source or persistent drift check.
- Remove obsolete version parsing/output from `vendor.sh`. Preserve vendor safety behavior and the semantics of tests 3–6; strengthen their evidence rather than preserving obsolete bytes.
- Every creation transition, including stage `mktemp` and Claude staged-alias `ln -s`, records exact path/inode evidence before honoring a pending trapped signal, even when the wrapped command returns nonzero. The deferral covers only the filesystem command and immediate bookkeeping.
- Cleanup aggregates destination, stage, staging-directory, parent-directory, owner, lock-directory, claim, and guard failures. Incomplete finalization emits precise diagnostics, exits nonzero without success output, and retains invocation-owned serialization for manual intervention. Preserve an original error or conventional signal status (`HUP=129`, `INT=130`, `TERM=143`); cleanup alone yields status `1`.

---

### Task 1: Remove Per-File Version Metadata

**Files:**
- Modify: `AGENTS.md`
- Modify: `SKILL.md`
- Modify: `README.md`
- Modify: `references/analysis.md`
- Modify: `references/bootstrap.md`
- Modify: `references/configuration.md`
- Modify: `references/data.md`
- Modify: `references/figures.md`
- Modify: `references/prerequisites.md`
- Modify: `agents/code-simplifier.md`
- Modify: `adapters/claude-code.sh`
- Modify: `adapters/codex.sh`
- Modify: `vendor.sh`
- Modify: `tests/vendor_test.sh`

**Interfaces:**
- Consumes: canonical simplifier YAML keys `name` and folded `description`
- Produces: standard documents with no per-file version metadata; adapters whose metadata validation requires only canonical name and description

- [ ] **Step 1: Create the RED state by removing the canonical profile's version key**

Delete this frontmatter entry from `agents/code-simplifier.md`:

```yaml
standard_version: 2026.08.13
```

Run: `bash tests/adapter_test.sh`

Expected: nonzero exit because both adapters report `canonical simplifier metadata is incomplete`.

- [ ] **Step 2: Remove adapter version parsing**

In both adapters, delete `canonical_standard_version` extraction and validate only:

```bash
if [[ -z "$canonical_name" || -z "$canonical_description" ]]; then
  fail "canonical simplifier metadata is incomplete"
fi
```

Do not add an absence assertion or replacement version variable.

- [ ] **Step 3: Remove document metadata and the vendor stamp test**

Delete the opening `<!-- standard_version: 2026.08.13 -->` comment from `AGENTS.md`, `SKILL.md`, `README.md`, and every `references/*.md` file. In `tests/vendor_test.sh`, delete the complete version-stamp test block. Remove `vendor.sh` parsing and use a version-neutral success message. Preserve tests 1–6 semantically and strengthen their command-status, byte-preservation, replacement, and exact fault-call evidence.

- [ ] **Step 4: Audit removal without creating a drift test**

Run:

```bash
if rg -n 'standard_version|standard-version stamp|version stamps present' \
  AGENTS.md SKILL.md README.md references agents adapters tests vendor.sh; then
  exit 1
fi
```

Expected: no matches and exit zero. Historical design and plan artifacts may describe the superseded requirement; do not rewrite them.

- [ ] **Step 5: Verify and commit metadata removal**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh vendor.sh tests/vendor_test.sh
bash tests/vendor_test.sh
bash tests/adapter_test.sh
bash tests/consistency_test.sh
make format
git diff --check
```

Expected: every command exits zero; vendor output still contains only `AGENTS.md`; Claude and Codex metadata still derive from canonical name and description.

Commit:

```bash
git add AGENTS.md SKILL.md README.md references agents/code-simplifier.md \
  adapters/claude-code.sh adapters/codex.sh vendor.sh tests/vendor_test.sh
git commit -m "docs: remove per-file version metadata"
```

### Task 2: Inode-Owned Transactional Publication

**Files:**
- Modify: `adapters/claude-code.sh`
- Modify: `adapters/codex.sh`
- Modify: `tests/adapter_test.sh`

**Interfaces:**
- Consumes: a canonical target, the shared adapter-lock path, and staged artifact/destination paths
- Produces: serialized cooperating adapter runs, `inode_of PATH`, `remove_if_owned DESTINATION EXPECTED_INODE`, pre-publication ownership inode variables, and rollback-safe publication for every new declared output within the narrowed cleanup-verification guarantee

- [ ] **Step 0: Serialize cooperating adapter installations**

Use the same target-local lock path in both adapters and acquire its exact directory with `mkdir` before output-parent creation or staging. First record no-follow absence of a predictable PID-and-nonce-qualified claim path, then atomically create its directory and establish ownership only from that absence-to-exact-directory-inode transition. Write its exact-token regular claim file with shell noclobber semantics and record both inodes. Atomically hard-link the claim to the fixed exact guard path with the POSIX two-path `link SOURCE TARGET` utility; prove guard ownership by exact claim/guard inode and bytes regardless of `link` status. Only that guard owner records no-follow absence of the lock path, attempts the lock `mkdir`, records its observed directory inode regardless of status, and hard-links the claim inode to the exact owner path with `link SOURCE TARGET`. A pre-existing lock branches to read-only inspection and never receives an owner. Set ownership only after exact guard/claim/lock/owner identity and byte verification and after proving that the claim and lock directories each contain only their recorded owner. Track the invocation-created empty directory so owner-link failure permits only inode-checked `rmdir` while it remains empty. Apply the same no-follow absence-to-exact-inode ownership rule to every output-parent `mkdir` while the adapter lock excludes cooperating creators.

Treat exact unique-claim-directory creation, claim-file noclobber creation, each guard/owner link,
stage-file or staging-directory `mktemp`, staged-alias `ln -s`, or directory `mkdir` and only its
immediate status/path/inode bookkeeping as a creation transition.
Claim-file ownership requires a successful shell noclobber redirect as well as exact inode and
byte evidence; preserve an exact-token collision as foreign state.
During that transition, the first trapped signal records its conventional status and returns;
immediately after the command, record exact evidence, leave the transition, and exit through normal
cleanup if a signal is pending. Apply the same helper to every invocation-created output parent.
Outside that narrow transition, preserve immediate signal-to-cleanup behavior.

If `mkdir` fails, inspect without mutation and never create a file inside that path. Report exact valid live owners as contention. Preserve dead-PID or ambiguous liveness, malformed or missing owners, ordinary directories, regular files, and every symlink form for manual intervention. Cleanup on success, ordinary error, or trapped signal acts only when ownership was established, rereads the exact token before removing the owner file, and uses `rmdir` for the lock directory. A missing or changed owner is preserved.

Add focused tests that hold one adapter after acquisition, run the other against the same target, require a contention diagnostic and nonzero status, and prove the contender did not remove the live owner's lock. Cover strict token grammar and nonce uniqueness; dead-PID/nonzero liveness; regular-file, directory, owner-file, and symlink path shapes; same-PID never-owned cleanup; simultaneous stale contenders; and lock release on success, error, and trapped signals. Run the entire fail-safe state matrix against both adapter implementations and assert every adapter-specific output remains absent.

Run a no-follow matrix for claim collisions and fixed-guard regular files, directories, dangling
symlinks, internal-directory symlinks, and external-directory symlinks. Add pre-effect and
effect-then-signal-then-nonzero cases for claim-directory creation, claim-to-guard `link`, and
claim-to-owner `link`, with exact count/path/source/destination/inode/PID markers. Treat lack of
hard-link support as a pre-output failure and prove exact claim cleanup.

Inject a foreign extra child into the claim directory and, independently, the lock directory during
the final acquisition-link transition. For both adapters, require failure before the first output
parent or stage attempt and exact preservation of the changed serialization inventory.

Add effect-then-signal-then-nonzero wrappers for every stage-file/staging-directory `mktemp` and
Claude's staged-alias `ln -s`. Require exact template or source/destination, resulting path, type,
inode, adapter process chain, call count, real-command status, injected status, and complete cleanup.

Use deterministic `mkdir` wrappers that perform the real exact-path creation and record exact count,
path, inode, adapter PID, signal, and return mode. For both adapters, the lock case sends `TERM` and
then returns nonzero; add PID-stable `HUP` and `INT` coverage. Repeat post-effect signal/nonzero coverage for
the first and every nested output parent. Require the effect marker, exact defined signal status,
absence of hangs, outputs, stages, owned lock/guard/claim residue after complete cleanup, and the
lock directory. Record the inode of a pre-existing empty missing-owner lock directory and require
the same empty directory inode after refusal.

- [ ] **Step 1: Add effect-then-fail and trapped-signal tests**

Replace the current second-`mv` mock with a wrapper that proves the real rename happened before returning failure:

```bash
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$MV_COUNT_FILE" ]] || count="$(cat "$MV_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"
"$REAL_MV" "$@"
if [[ "$count" -eq "$FAIL_ON_COUNT" ]]; then
  inode="$(ls -di "$2" | awk '{ print $1 }')"
  printf 'post-effect count=%s inode=%s\n' "$count" "$inode" > "$MV_EFFECT_MARKER"
  exit 1
fi
```

For Codex fail after publish 2; for Claude fail after its final publish. Each assertion must require the exact counter, source, destination, adapter PID, a `post-effect` marker, nonzero adapter status, absence of every newly declared output, absence of `*.stage.*`, and preservation of any pre-existing exact output.

Add wrapper modes that perform the real final rename, write exact post-effect evidence, send `HUP`,
`TERM`, or `INT` to `$PPID`, and exit. Require status `129`, `143`, or `130` respectively and verify complete
rollback for both adapters. Add ordinary-failure and signal modes that atomically replace the
published destination with a different-inode sentinel before cleanup; preserve that sentinel while
rolling back every other invocation-owned output.

- [ ] **Step 2: Run the focused adapter suite and confirm RED**

Run: `bash tests/adapter_test.sh`

Expected: nonzero exit because the current created flags are assigned after publication, leaving post-effect outputs after the injected failure or signal.

- [ ] **Step 3: Add portable inode ownership helpers**

Add to both adapters:

```bash
inode_of() {
  LC_ALL=C ls -di "$1" | awk '{ print $1 }'
}

remove_if_owned() {
  destination=$1
  expected_inode=$2
  if [[ -n "$expected_inode" ]] &&
    { [[ -e "$destination" ]] || [[ -L "$destination" ]]; } &&
    [[ "$(inode_of "$destination")" == "$expected_inode" ]]; then
    rm -f "$destination"
  fi
}
```

Use `ls -di` so symlink identity is the link's inode, not its target's. All stages and destinations are already constrained to the same validated filesystem location.

- [ ] **Step 4: Stage Claude's alias and record ownership before publishing**

Create a target-root staging directory with `mktemp -d`, create `CLAUDE.md -> AGENTS.md` inside it, and retain both the directory and staged alias path for cleanup. Record `alias_inode="$(inode_of "$alias_stage")"` before renaming the staged alias.

For canonical and host profiles in both adapters, set the corresponding ownership inode from the stage immediately before `mv`. Do not clear the stage-path variable or wait until `mv` returns to record ownership.

Publish regular profiles first and Claude's alias last. Existing exact outputs remain unowned: leave their ownership inode empty and remove only their unused stage during cleanup.

- [ ] **Step 5: Replace created-file rollback with inode-owned rollback**

Before publication, arm the existing transaction trap. In cleanup, replace `created_*` file removal with:

```bash
if ((transaction_complete == 0)); then
  remove_if_owned "$host_profile" "$host_inode"
  remove_if_owned "$canonical_destination" "$canonical_inode"
  remove_if_owned "$policy_alias" "$alias_inode"  # Claude only
fi
```

Then remove any remaining stage files/staging directory and inode-owned empty parents. Aggregate
all independent failures and continue independent cleanup. Only when those steps are complete may
the dependent release chain remove the exact owner, verify/remove the exact lock directory,
remove the claim file/directory, and unlink the guard last. Any residual or changed state stops that
dependent chain; a failed lock-directory removal relinks the exact guard inode as owner when the
original directory remains. Otherwise retain serialization. A changed owner is a cleanup failure,
not a silent no-op. Ignore further trapped signals during finite cleanup, preserve the original
status, convert cleanup-only failure to status `1`, and print success only after complete
finalization. Set `transaction_complete=1` only after the final publish succeeds.

Before the first dependent removal, including partial/no-guard cleanup, verify that the exact claim
and lock directories still have their recorded inodes and each contains only its recorded owner.
Prevalidate every recorded guard, claim, lock, and owner component before removing any other
serialization component. Test replacement and extra-child mutations before release, plus
missing/different-inode lock, owner, claim, and guard states during both full and partial release.
Preserve foreign state, emit a precise diagnostic, and retain remaining owned serialization.

The inode comparison and unlink are separate operations. The implementation and report must state that rollback removes only an invocation-owned inode visible at cleanup verification and does not promise atomic safety against an adversarial replacement between those operations. The shared lock eliminates that interleaving only for cooperating adapter invocations.

- [ ] **Step 6: Run focused tests to GREEN**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh tests/adapter_test.sh
bash tests/adapter_test.sh
```

Expected: all adapter tests pass, including shared-lock contention and lifecycle, the duplicated
lock matrix, hardcoded protocol IDs, exact marker/count/source/destination assertions, post-effect
failure rollback, `HUP`/`TERM`/`INT` status and rollback, post-effect/nonzero lock and parent creation,
different-inode sentinel preservation, cleanup-error aggregation and lock retention, changed-owner
failure, pre-effect failure, pre-existing-output inode preservation, parent/leaf symlinks, paths
with spaces, customized preservation, exact reruns, and clean staging/directories.

- [ ] **Step 7: Run full verification and commit**

Run:

```bash
make format
make test
git diff --check
```

Create real temporary Claude and Codex targets, run vendor plus each adapter twice, and inspect canonical byte equality, derived metadata, neutral Codex TOML, exact Claude alias, unchanged rerun checksums, and no stage files. Re-run the effect-then-fail and signal wrappers against fresh temporary targets and confirm no declared output remains.

Commit:

```bash
git add adapters/claude-code.sh adapters/codex.sh tests/adapter_test.sh
git commit -m "fix: make adapter rollback publication-aware"
```

### Task 3: Independent Simplification and Completion Review

**Files:**
- Review: `adapters/claude-code.sh`
- Review: `adapters/codex.sh`
- Review: `tests/adapter_test.sh`
- Review: `tests/vendor_test.sh`
- Review: current standard documents and references for version-field remnants

**Interfaces:**
- Consumes: Tasks 1–2 commits and `agents/code-simplifier.md`
- Produces: behavior-preserving simplifier outcome, complete verification evidence, and a whole-change review verdict

- [ ] **Step 1: Run the required independent simplifier pass**

Delegate this exact scope to an independent agent:

```text
Read and apply agents/code-simplifier.md. Review only adapters/claude-code.sh,
adapters/codex.sh, tests/adapter_test.sh, and tests/vendor_test.sh as changed by this
follow-up. Preserve every transaction, containment, rollback, metadata-removal, and test behavior.
Make only clear behavior-preserving simplifications. Run the covering shell tests after any edit.
```

Inspect any edit and reject changes that weaken inode ownership, marker/count assertions, signal rollback, symlink rejection, or exact-rerun behavior.

- [ ] **Step 2: Re-run all verification on the simplifier-reviewed tree**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh vendor.sh \
  tests/adapter_test.sh tests/vendor_test.sh tests/consistency_test.sh
make format
make test
git diff --check
if rg -n 'standard_version|standard-version stamp|version stamps present' \
  AGENTS.md SKILL.md README.md references agents adapters tests vendor.sh; then
  exit 1
fi
```

Expected: all commands exit zero and the audit prints no version-field matches.

- [ ] **Step 3: Inspect real outputs and fault behavior**

In target directories created by `mktemp -d`, verify both successful adapters twice and both injected post-effect failure/signal paths. Record:

- canonical `cmp` success;
- canonical name/description in Claude and Codex wrappers;
- Claude frontmatter contains exactly name and description;
- Codex TOML contains no model, reasoning, sandbox, MCP, or skill override;
- Claude alias is exactly relative `AGENTS.md`;
- rerun checksums are unchanged;
- fault marker/count proves publication occurred;
- no declared output or stage remains after fault rollback; and
- pre-existing exact outputs retain their checksums.

- [ ] **Step 4: Commit any simplifier edits and verification report changes**

If the independent pass changed executable/test files, commit them after covering tests:

```bash
git add adapters tests
git commit -m "refactor: simplify transactional adapter flow"
```

If it made no edits, record that outcome in the plan ledger/report without creating an empty commit.

- [ ] **Step 5: Request whole-change review**

Give the reviewer the amendment specification, this plan, implementation reports, and the diff from `db88705` through `HEAD`. Require explicit verdicts on post-effect rollback, signal cleanup, inode ownership, pre-existing artifact preservation, version-metadata removal, absence of drift enforcement, shell portability, and test fault-mechanism validity.

Expected: no open Critical or Important finding before branch integration is offered.

---

### Final-review fix wave: complete negative branches and finalization semantics

This section is authoritative where earlier task wording is narrower or contradictory. Implement
the complete finding set in one TDD wave:

**Additional files:**

- Modify: `.superpowers/sdd/2026-08-13-adapter-transaction-version-removal/progress.md`
- Modify: `.superpowers/sdd/2026-08-13-adapter-transaction-version-removal/task-3-report.md`

- remove `vendor.sh` version parsing/output and strengthen vendor tests 1, 2, 4, 5, and 6 with
  explicit status, byte-exact preservation/replacement, and exact fault-call evidence;
- use the exclusive claim directory/file, exact no-follow hard-link guard, pre-lock absence proof,
  and inode bookkeeping described above for post-effect/nonzero claim, guard, owner, lock, and every
  output-parent creation transition;
- aggregate output, stage, staging-directory, parent-directory, owner, lock-directory, claim, and
  guard cleanup errors, preserve original error/signal status, suppress success on incomplete
  finalization, and retain invocation-owned serialization;
- require changed-owner state to fail closed and remain intact;
- cover ordinary-failure and signal cleanup after atomic different-inode destination replacement;
- require every copy, rename, mkdir, cleanup, and vendor fault double to prove exact invocation
  count, source/path, destination where applicable, PID, and external effect marker;
- run the complete fail-safe lock matrix against both Claude and Codex and assert no
  adapter-specific output or outside write;
- hardcode protocol adapter IDs and cover renamed/symlinked invocation;
- cover PID-stable `HUP`, `TERM`, and `INT` with exact `129`, `143`, and `130` status; and
- correct the SDD ledger and Task 3 report claims superseded by this wave.

Required GREEN evidence includes Bash syntax and Apple Bash 3.2, expanded adapter/vendor/consistency
suites, `make format`, `make test`, `git diff --check`, the one-time no-version audit including
`vendor.sh`, real success/rerun artifacts, and focused post-effect failure/signal/nonzero mkdir,
parent mkdir, different-inode, cleanup-retention, lock-matrix, and vendor fault probes. Run the
independent canonical simplifier on every changed shell/test file and rerun covering tests after any
edit.

The corrected ledger/report must supersede the stale review-clean verdict, obsolete signal status,
unchanged-vendor claim, and no-version audit that omitted `vendor.sh`; it records exact RED/GREEN
commands, output counts, commit identifiers, and real artifact/fault evidence from this wave.
