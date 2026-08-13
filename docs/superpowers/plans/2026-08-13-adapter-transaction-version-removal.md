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
- Both adapters acquire the same exact target-local lock directory with atomic `mkdir` before output-parent creation or staging. Only the creator writes and verifies the strict PID, exact adapter name, and nonce owner file. Never reclaim an existing lock automatically. Preserve every live, dead-PID, ambiguous-liveness, malformed, missing, non-directory, or symlink lock for manual intervention; release only a lock explicitly owned by this invocation whose exact owner token still matches.
- Reject symlinked output parents and generated-profile leaf symlinks; permit only the exact Claude policy alias `CLAUDE.md -> AGENTS.md`.
- Stage each output on its destination filesystem and publish it by same-filesystem atomic rename.
- Arm rollback before the first publish and disarm it only after all declared outputs publish successfully.
- Cover ordinary failures and trapped `INT`/`TERM`; do not claim recovery from untrappable process or machine termination.
- Remove `standard_version` metadata, parsing, propagation, stripping, synchronization, and audits without introducing a replacement version source or persistent drift check.
- Preserve `vendor.sh` and vendor safety tests 3–6 exactly.

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

Delete the opening `<!-- standard_version: 2026.08.13 -->` comment from `AGENTS.md`, `SKILL.md`, `README.md`, and every `references/*.md` file. In `tests/vendor_test.sh`, delete the complete version-stamp test block while leaving tests 1–6 unchanged.

- [ ] **Step 4: Audit removal without creating a drift test**

Run:

```bash
if rg -n 'standard_version|standard-version stamp|version stamps present' \
  AGENTS.md SKILL.md README.md references agents adapters tests; then
  exit 1
fi
```

Expected: no matches and exit zero. Historical design and plan artifacts may describe the superseded requirement; do not rewrite them.

- [ ] **Step 5: Verify and commit metadata removal**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh tests/vendor_test.sh
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
  adapters/claude-code.sh adapters/codex.sh tests/vendor_test.sh
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

Use the same target-local lock path in both adapters and acquire its exact directory with `mkdir` before output-parent creation or staging. Only after `mkdir` succeeds, write an owner file containing a strict invocation-unique token with PID, exact adapter name, and nonce. Set ownership only after an exact reread. Track the invocation-created empty directory separately so owner-write failure permits only `rmdir` when it remains empty.

If `mkdir` fails, inspect without mutation and never create a file inside that path. Report exact valid live owners as contention. Preserve dead-PID or ambiguous liveness, malformed or missing owners, ordinary directories, regular files, and every symlink form for manual intervention. Cleanup on success, ordinary error, or trapped signal acts only when ownership was established, rereads the exact token before removing the owner file, and uses `rmdir` for the lock directory. A missing or changed owner is preserved.

Add focused tests that hold one adapter after acquisition, run the other against the same target, require a contention diagnostic and nonzero status, and prove the contender did not remove the live owner's lock. Cover strict token grammar and nonce uniqueness; dead-PID/nonzero liveness; regular-file, directory, owner-file, and symlink path shapes; same-PID never-owned cleanup; simultaneous stale contenders; and lock release on success, error, and trapped `TERM`.

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

For Codex fail after publish 2; for Claude fail after its final publish. Each assertion must require the exact counter, a `post-effect` marker, nonzero adapter status, absence of every newly declared output, absence of `*.stage.*`, and preservation of any pre-existing exact output.

Add a second wrapper mode that performs the real final rename, writes `post-effect signal`, sends `TERM` to `$PPID`, and exits. Require the marker and verify complete rollback for both adapters.

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

Then remove any remaining stage files/staging directory, only `rmdir` invocation-created empty parents, and release only this invocation's still-matching lock token. Keep `trap - EXIT HUP INT TERM` and `set +e` at cleanup entry. Set `transaction_complete=1` only after the final publish succeeds.

The inode comparison and unlink are separate operations. The implementation and report must state that rollback removes only an invocation-owned inode visible at cleanup verification and does not promise atomic safety against an adversarial replacement between those operations. The shared lock eliminates that interleaving only for cooperating adapter invocations.

- [ ] **Step 6: Run focused tests to GREEN**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh tests/adapter_test.sh
bash tests/adapter_test.sh
```

Expected: all adapter tests pass, including shared-lock contention and lifecycle, exact marker/count assertions, post-effect failure rollback, trapped-signal rollback, pre-effect failure, pre-existing-output inode preservation, parent/leaf symlinks, paths with spaces, customized preservation, exact reruns, and clean staging/directories.

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
bash -n adapters/claude-code.sh adapters/codex.sh \
  tests/adapter_test.sh tests/vendor_test.sh tests/consistency_test.sh
make format
make test
git diff --check
if rg -n 'standard_version|standard-version stamp|version stamps present' \
  AGENTS.md SKILL.md README.md references agents adapters tests; then
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
