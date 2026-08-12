# Portable Skill Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the research repository standard host-neutral for Codex and Claude Code, remove
source-standard drift checking, consolidate documentation ownership, and add reproducible
repository-wide formatting, linting, and tests.

**Architecture:** `AGENTS.md` is the portable governed-repository contract, `SKILL.md` routes work
to canonical detail in `references/`, and `vendor.sh` handles only portable `AGENTS.md` vendoring.
Host-specific integration is isolated behind documented adapters, while a pinned repository-local
quality toolchain provides separate mutating `format` and non-mutating `check` entry points.

**Tech Stack:** Bash, Make, Markdown, Codex and Claude Code host documentation, mise-managed
command-line tools, npm lockfile for Markdown tooling, ShellCheck, shfmt, Prettier,
markdownlint-cli2, and the existing plain-Bash test suites.

## Global Constraints

- Preserve the pre-existing unstaged changes in `SKILL.md` and `references/bootstrap.md`;
  distinguish cleanup hunks from unrelated Python-version, license, and configuration edits.
- Preserve the existing untracked
  `docs/superpowers/plans/2026-08-12-reduced-documentation-contract.md` unless the user separately
  decides its disposition.
- Keep `## This repository` followed by `## Using this standard` as stable vendoring interfaces.
- Core vendoring installs or updates `AGENTS.md` only.
- Do not create `CODEX.md` or any second textual copy of the portable policy.
- Do not add `make standard-check`, `vendor.sh --check`, or another source-to-target drift
  comparison interface.
- Retain `uv sync --locked` and `uv lock --check`; they are dependency-integrity checks.
- Keep `AGENTS.md` sufficient for routine governed work without the source skill, a network
  connection, or a host-specific profile.
- Put host-specific installation and discovery procedure in `references/prerequisites.md`, not in
  portable policy.
- Put figure-specific identifier, asset, and source-data naming grammar only in
  `references/figures.md`.
- Keep formatter and linter versions committed and reproducible.
- Keep formatting mutating and checking non-mutating.
- Treat `docs/superpowers/specs/` and `docs/superpowers/plans/` as historical, non-normative
  records.
- Use exact-path staging; never stage the whole working tree.
- Every implementation task ends with its focused tests and a focused commit.
- Run every implementation, audit, simplification, and review subagent on `gpt-5.6-sol`; do not
  dispatch Claude-model subagents. Workflow agents must inherit the parent model without a Claude
  model override.

---

## File Structure

### Files to create

- `adapters/claude-code.sh` — optional Claude Code integration for a governed target.
- `adapters/codex.sh` — optional Codex integration only if current official Codex behavior requires
  repository files beyond `AGENTS.md`; otherwise create a no-op validator that explains that the
  portable core is the Codex adapter.
- `tests/adapter_test.sh` — isolated behavioral tests for each host adapter.
- `mise.toml` — pins Node, ShellCheck, and shfmt versions selected from their current official
  releases.
- `package.json` — declares exact Markdown formatter/linter dependencies and quality scripts.
- `package-lock.json` — locks the Markdown tooling dependency graph.
- `.editorconfig` — shared whitespace and newline policy.
- `.prettierrc.json` — Markdown formatting configuration.
- `.prettierignore` — excludes Git internals, worktrees, memory/session artifacts, and generated
  tool directories.
- `.markdownlint-cli2.yaml` — Markdown lint configuration and exclusions.
- `.shellcheckrc` — shell dialect and source-following policy.
- `tools/quality.sh` — single implementation behind `make format`, `make lint`, and `make check`.
- `tests/quality_test.sh` — contract tests for formatting, linting, frontmatter, and non-mutating
  checks.

### Files to modify

- `AGENTS.md` — portable wording, host-neutral delegated-agent requirements, compact canonical
  policy, and figure-reference gate.
- `SKILL.md` — remove drift claims, route to canonical references, and describe portable vendoring
  plus optional adapters.
- `README.md` — describe the portable core, adapters, and actual validation entry points.
- `references/prerequisites.md` — authoritative current Codex and Claude Code setup, discovery,
  delegated-agent, and recovery procedure.
- `references/bootstrap.md` — remove drift documentation and duplicated host/policy procedure;
  scaffold portable profile plus optional adapters.
- `references/configuration.md` — retain only detailed configuration procedure and link to the
  portable policy owner.
- `references/data.md` — retain data mechanics and remove repeated compact policy where `AGENTS.md`
  already owns it.
- `references/analysis.md` — use host-neutral independent-review language and retain detailed
  critique procedure.
- `references/figures.md` — own the figure naming grammar and detailed figure procedure.
- `agents/code-simplifier.md` — remove provider model selection and repeated repository policy.
- `vendor.sh` — remove check mode and Claude-specific side effects; retain safe portable vendoring.
- `tests/vendor_test.sh` — test portable vendoring and deleted behavior.
- `tests/consistency_test.sh` — test canonical ownership and routing instead of check-mode exit
  codes.
- `Makefile` — add format, lint, and aggregate check entry points while retaining test.
- `.gitignore` — ignore only reproducible local tool caches introduced by the selected toolchain.

### Files to format but not semantically rewrite

- `docs/superpowers/specs/2026-08-12-documentation-contract-design.md`
- `docs/superpowers/specs/2026-08-12-portable-skill-cleanup-design.md`
- `docs/superpowers/plans/2026-08-12-reduced-documentation-contract.md`
- `docs/superpowers/plans/2026-08-12-portable-skill-cleanup.md`

---

### Task 1: Freeze the Baseline and Verify Host Contracts

**Files:**

- Modify: `docs/superpowers/plans/2026-08-12-portable-skill-cleanup.md` only if authoritative host
  behavior requires a plan correction
- Reference: `docs/superpowers/specs/2026-08-12-portable-skill-cleanup-design.md`
- Reference: `SKILL.md`
- Reference: `references/prerequisites.md`

**Interfaces:**

- Consumes: the approved portable-core design and current dirty working tree
- Produces: a verified host behavior matrix used by Tasks 2, 4, and 6

- [ ] **Step 1: Capture the exact baseline without modifying files**

Run:

```bash
git status --short --branch
git diff -- SKILL.md references/bootstrap.md
git diff --check
git ls-files -s vendor.sh tests/vendor_test.sh tests/consistency_test.sh
readlink ~/.claude/skills/research-repo-standard || true
```

Expected: `SKILL.md` and `references/bootstrap.md` are modified, the older reduced-documentation
plan remains untracked, and the reported trailing whitespace in `SKILL.md` is visible. Save the
output in the implementation session notes, not in a new repository file.

- [ ] **Step 2: Fan out authoritative host research**

Run one read-only workflow with four independent agents:

1. Codex `AGENTS.md` discovery, precedence, nested scope, skills, and delegated-agent/custom-role
   configuration.
2. Claude Code `CLAUDE.md` symlink behavior, skills, and custom-agent configuration.
3. Official ShellCheck and shfmt installation/versioning mechanisms supported by mise.
4. Official Prettier and markdownlint-cli2 package/version/configuration guidance.

Require every agent to return source URLs, current version identifiers, supported file paths, and
explicit uncertainty. Do not accept blog posts where official documentation or release pages exist.

- [ ] **Step 3: Write the host behavior matrix in the implementation notes**

Record these exact decisions:

```text
Portable policy file: AGENTS.md
Codex policy sidecar: none
Claude Code policy sidecar: optional CLAUDE.md -> AGENTS.md
Canonical simplifier prompt: agents/code-simplifier.md in this standard
Claude Code adapter target path: verified official custom-agent path
Codex adapter target path: verified official role/agent path, or no-op when AGENTS.md plus direct delegated prompting is the supported mechanism
Core vendor command: ./vendor.sh <target-repo>
Claude adapter command: ./adapters/claude-code.sh <target-repo>
Codex adapter command: ./adapters/codex.sh <target-repo>
```

If current official behavior contradicts the approved architecture, stop and ask the user rather
than changing the architecture silently.

- [ ] **Step 4: Verify tool resolution before locking it**

Run:

```bash
mise latest node
mise latest shellcheck
mise latest shfmt
npm view prettier version
npm view markdownlint-cli2 version
```

Expected: each command returns one current stable version. If mise does not officially resolve
ShellCheck or shfmt, use the official release-binary backend supported by mise rather than adding an
unpinned system dependency.

- [ ] **Step 5: Recheck the baseline**

Run:

```bash
git status --short
git diff --check
```

Expected: no files changed during research. Do not commit this task because it is read-only.

---

### Task 2: Add Failing Portable-Vendoring and Adapter Tests

**Files:**

- Modify: `tests/vendor_test.sh:13-111`
- Create: `tests/adapter_test.sh`
- Modify: `tests/consistency_test.sh:32-49`
- Modify: `Makefile:1-9`

**Interfaces:**

- Consumes: verified adapter paths and behavior from Task 1
- Produces: failing executable contracts for `vendor.sh`, `adapters/claude-code.sh`, and
  `adapters/codex.sh`

- [ ] **Step 1: Replace the fresh-vendor assertion with a portable-core assertion**

In `tests/vendor_test.sh`, make the first case assert that `AGENTS.md` matches and no host sidecar
is created:

```bash
# --- 1. fresh vendor copies only portable AGENTS.md ---
t1="$tmp/fresh"
mkdir "$t1"
"$ROOT/vendor.sh" "$t1" >/dev/null
if diff -q "$ROOT/AGENTS.md" "$t1/AGENTS.md" >/dev/null \
    && [[ ! -e "$t1/CLAUDE.md" ]] \
    && [[ ! -e "$t1/CODEX.md" ]]; then
    pass "fresh portable vendor"
else
    fail "fresh portable vendor"
fi
```

Keep the section-preservation, corrupted-source, malformed-target, transactional, and version-stamp
cases.

- [ ] **Step 2: Replace old check-mode tests with a deleted-interface test**

Add this case to `tests/vendor_test.sh`:

```bash
# --- deleted interface: --check is rejected as usage ---
set +e
check_output="$("$ROOT/vendor.sh" --check "$t1" 2>&1)"
check_rc=$?
set -e
if [[ "$check_rc" -eq 2 ]] && grep -q 'usage: vendor.sh <target-repo>' <<<"$check_output"; then
    pass "removed --check interface is rejected"
else
    fail "removed --check interface is rejected"
fi
```

Delete assertions for clean drift state, edited `AGENTS.md`, missing `CLAUDE.md`, and restored
symlink behavior.

- [ ] **Step 3: Create failing Claude adapter tests**

Create `tests/adapter_test.sh` with the existing test harness pattern and these assertions:

```bash
#!/usr/bin/env bash
# Tests for optional host adapters. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

target="$tmp/target"
mkdir "$target"
"$ROOT/vendor.sh" "$target" >/dev/null

"$ROOT/adapters/claude-code.sh" "$target" >/dev/null
if [[ "$(readlink "$target/CLAUDE.md" 2>/dev/null || true)" == "AGENTS.md" ]]; then
    pass "Claude adapter creates relative policy alias"
else
    fail "Claude adapter creates relative policy alias"
fi

if [[ -f "$target/.claude/agents/code-simplifier.md" ]] \
    && ! grep -Eq '^model:' "$target/.claude/agents/code-simplifier.md"; then
    pass "Claude adapter installs provider-neutral simplifier profile"
else
    fail "Claude adapter installs provider-neutral simplifier profile"
fi
```

Append a Codex case matching Task 1's verified mechanism. It must assert that no `CODEX.md` is
created and that any supported Codex role/config references or embeds the canonical simplifier
prompt without adding a provider model.

- [ ] **Step 4: Replace consistency check 3 with adapter/profile routing checks**

Delete the `vendor.sh --check` exit-code block from `tests/consistency_test.sh`. Add assertions
that:

```bash
if grep -qs 'adapters/claude-code\.sh' "$ROOT/references/prerequisites.md" \
    && grep -qs 'adapters/codex\.sh' "$ROOT/references/prerequisites.md"; then
    pass "host adapters are documented by the prerequisite owner"
else
    fail "host adapters are documented by the prerequisite owner"
fi

if grep -qs 'agents/code-simplifier\.md' "$ROOT/AGENTS.md" \
    && [[ -f "$ROOT/agents/code-simplifier.md" ]]; then
    pass "portable simplifier profile is routed from AGENTS.md"
else
    fail "portable simplifier profile is routed from AGENTS.md"
fi
```

- [ ] **Step 5: Wire the adapter suite into Make**

Change `Makefile` temporarily so `test` runs all three suites:

```make
test: ## Run vendoring, adapter, and documentation-contract tests
	bash tests/vendor_test.sh
	bash tests/adapter_test.sh
	bash tests/consistency_test.sh
```

- [ ] **Step 6: Run the focused tests and confirm failure**

Run:

```bash
bash tests/vendor_test.sh
bash tests/adapter_test.sh
bash tests/consistency_test.sh
```

Expected: failures because core vendoring still creates `CLAUDE.md`, `--check` still exists,
adapters do not exist, and documentation does not route to them.

- [ ] **Step 7: Commit only the tests**

```bash
git add tests/vendor_test.sh tests/adapter_test.sh tests/consistency_test.sh Makefile
git commit -m "test: define portable vendoring and adapters"
```

---

### Task 3: Remove Drift Checking and Make Core Vendoring Portable

**Files:**

- Modify: `vendor.sh:1-141`
- Modify: `tests/vendor_test.sh`

**Interfaces:**

- Consumes: `./vendor.sh <target-repo>` failing contracts from Task 2
- Produces: one-argument portable vendoring command that writes only `AGENTS.md`

- [ ] **Step 1: Simplify usage to one portable command**

Replace `usage()` with:

```bash
usage() {
    echo "usage: vendor.sh <target-repo>" >&2
    exit 2
}
```

Delete `CHECK`, the `--check` parser, and all check-specific state.

- [ ] **Step 2: Keep target parsing strict**

Use:

```bash
[[ $# -eq 1 ]] || usage
TARGET="$1"
```

This makes `vendor.sh --check <target>` fail with usage exit 2.

- [ ] **Step 3: Delete drift comparison behavior**

Remove:

- source/target version comparison used only by checking;
- generated-file `diff` and drift verdicts;
- check-specific output strings;
- special missing-`AGENTS.md` exit code; and
- `CLAUDE.md` symlink validation.

Keep `verify_source`, `verify_target`, `build_vendored`, temporary build directory, atomic move,
version output, and section-preservation output.

- [ ] **Step 4: Remove the Claude side effect from core vendoring**

Delete:

```bash
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"
```

Update the file header to:

```bash
# Vendor the portable standard into a target repository.
#
# Copies AGENTS.md only. Detailed references remain in the skill, while optional
# host integration is installed separately through adapters/.
```

- [ ] **Step 5: Run syntax and focused tests**

Run:

```bash
bash -n vendor.sh tests/vendor_test.sh
bash tests/vendor_test.sh
```

Expected: all vendoring tests pass, including rejection of `--check` and absence of host sidecars.

- [ ] **Step 6: Search implementation and tests for the deleted interface**

Run:

```bash
grep -RInE 'standard-check|vendor\.sh --check|--check.*AGENTS|source standard_version|vendored standard_version:.*source' \
    vendor.sh tests || true
```

Expected: no live implementation or test references except a deliberate deleted-interface assertion
in `tests/vendor_test.sh`.

- [ ] **Step 7: Commit portable vendoring**

```bash
git add vendor.sh tests/vendor_test.sh
git commit -m "refactor: make vendoring host neutral"
```

---

### Task 4: Implement Optional Claude Code and Codex Adapters

**Files:**

- Create: `adapters/claude-code.sh`
- Create: `adapters/codex.sh`
- Modify: `tests/adapter_test.sh`
- Modify: `.gitignore`

**Interfaces:**

- Consumes: a target already containing portable `AGENTS.md`, plus Task 1's verified host paths
- Produces: `./adapters/claude-code.sh <target-repo>` and `./adapters/codex.sh <target-repo>`

- [ ] **Step 1: Create a shared adapter validation pattern**

Both scripts begin with:

```bash
#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    echo "usage: $(basename "$0") <target-repo>" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
    echo "$(basename "$0"): not a directory: $TARGET" >&2
    exit 1
fi
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
    echo "$(basename "$0"): vendor AGENTS.md before installing a host adapter" >&2
    exit 1
fi
```

Do not move this into a shared sourced shell library; two small scripts do not justify another
abstraction.

- [ ] **Step 2: Implement the Claude Code adapter**

After validation, `adapters/claude-code.sh` must:

```bash
mkdir -p "$TARGET/.claude/agents"
cp "$SRC/agents/code-simplifier.md" "$TARGET/.claude/agents/code-simplifier.md"
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"
printf 'installed Claude Code adapter -> %s\n' "$TARGET"
```

If Task 1 confirms that Claude Code requires host-only frontmatter absent from the canonical prompt,
have the adapter generate that wrapper while keeping the prompt body sourced from
`agents/code-simplifier.md`. Do not add provider configuration to the canonical file.

- [ ] **Step 3: Implement the Codex adapter from verified official behavior**

The script must always verify `AGENTS.md`, refuse to create `CODEX.md`, and print the installed
mechanism. Choose exactly one implementation based on Task 1:

- If Codex supports a repository-local custom role/agent file, create its official directory,
  install a wrapper that references or embeds `agents/code-simplifier.md`, and leave `AGENTS.md`
  untouched.
- If Codex custom roles are user-global or unavailable, copy the canonical prompt to the documented
  repository location `agents/code-simplifier.md` only when bootstrap has not already seeded it,
  then print that Codex uses `AGENTS.md` natively and the independent delegated agent must load that
  prompt.

The behavioral test must encode the chosen official mechanism so this branch is resolved in code,
not left as prose.

- [ ] **Step 4: Add negative adapter cases**

Extend `tests/adapter_test.sh` to assert for both adapters:

```bash
missing="$tmp/missing"
mkdir "$missing"
if "$ROOT/adapters/claude-code.sh" "$missing" >/dev/null 2>&1; then
    fail "Claude adapter requires vendored AGENTS.md"
else
    pass "Claude adapter requires vendored AGENTS.md"
fi

if "$ROOT/adapters/codex.sh" "$missing" >/dev/null 2>&1; then
    fail "Codex adapter requires vendored AGENTS.md"
else
    pass "Codex adapter requires vendored AGENTS.md"
fi
```

Also assert that rerunning each adapter is idempotent.

- [ ] **Step 5: Run adapter tests**

Run:

```bash
bash -n adapters/claude-code.sh adapters/codex.sh tests/adapter_test.sh
bash tests/adapter_test.sh
```

Expected: all adapter tests pass.

- [ ] **Step 6: Commit adapters**

```bash
git add adapters/claude-code.sh adapters/codex.sh tests/adapter_test.sh .gitignore
git commit -m "feat: add optional host adapters"
```

---

### Task 5: Make the Code-Simplifier Profile Provider-Neutral

**Files:**

- Modify: `agents/code-simplifier.md:1-88`
- Modify: `AGENTS.md:383-415`
- Modify: `tests/consistency_test.sh`
- Test: `tests/adapter_test.sh`

**Interfaces:**

- Consumes: canonical prompt installed by Task 4 adapters
- Produces: provider-neutral simplifier behavior and host-neutral governed policy

- [ ] **Step 1: Add failing provider-neutral profile assertions**

Add to `tests/consistency_test.sh`:

```bash
profile_ok=1
if grep -Eq '^model:' "$ROOT/agents/code-simplifier.md"; then
    fail "canonical simplifier profile must not select a provider model"
    profile_ok=0
fi
if grep -Eq '\.claude/agents|Claude Code|Anthropic|Codex|OpenAI' "$ROOT/agents/code-simplifier.md"; then
    fail "canonical simplifier profile must be host neutral"
    profile_ok=0
fi
((profile_ok)) && pass "canonical simplifier profile is provider neutral"
```

Add a second assertion that `AGENTS.md` requires an independent simplification pass but does not
hardcode `.claude/agents/`.

- [ ] **Step 2: Run the consistency suite and confirm failure**

Run:

```bash
bash tests/consistency_test.sh
```

Expected: failure on `model: opus` and the `.claude/agents/code-simplifier.md` path.

- [ ] **Step 3: Remove provider selection from the canonical profile**

Delete:

```yaml
model: opus
```

Keep `name`, `description`, and `standard_version` frontmatter.

- [ ] **Step 4: Replace repeated repository policy with delegation**

Replace the detailed bullets under **Apply Project Standards** with:

```markdown
2. **Apply Project Standards**: Read and follow the repository's `AGENTS.md`, generated project
   configuration, and tests. Treat those files as authoritative for naming, style, configuration
   ownership, scientific invariants, and validation. Do not copy assumptions from another repository
   or from this profile.
```

Keep behavior preservation, clarity, YAGNI, comment upkeep, scope, process, and test rerun
requirements in the profile.

- [ ] **Step 5: Make the governed working procedure capability-based**

Replace `AGENTS.md`'s hardcoded Claude path with language equivalent to:

```markdown
When a modification changed code under `src/`, `scripts/`, or `tests/`, run an independent
code-simplification pass before declaring completion. The delegated review agent applies the
canonical `agents/code-simplifier.md` profile installed or resolved through the current host
adapter, preserves behavior exactly, and does not implement new requirements. Re-run the covering
tests after any simplifier edit. The simplifier's own edits do not trigger another pass.
Documentation- and configuration-only changes are exempt. If the host cannot launch an independent
review agent or resolve the canonical profile, report the blocker instead of substituting an
unreviewed self-pass.
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
bash tests/consistency_test.sh
bash tests/adapter_test.sh
```

Expected: provider-neutral profile and adapter-copy assertions pass.

- [ ] **Step 7: Commit the neutral profile**

```bash
git add AGENTS.md agents/code-simplifier.md tests/consistency_test.sh tests/adapter_test.sh
git commit -m "docs: make simplifier profile provider neutral"
```

---

### Task 6: Consolidate Portable Policy and Host Prerequisites

**Files:**

- Modify: `AGENTS.md:4-45,94-105,119-140,185-262,293-314,383-415`
- Modify: `SKILL.md:1-115`
- Modify: `references/prerequisites.md:1-107`
- Modify: `references/bootstrap.md:1-30,143-178,220-225`
- Modify: `README.md:1-46`
- Modify: `tests/consistency_test.sh`

**Interfaces:**

- Consumes: portable vendor and adapter commands from Tasks 3-4
- Produces: one host-neutral governance contract plus authoritative host setup procedure

- [ ] **Step 1: Add failing routing and ownership assertions**

Extend `tests/consistency_test.sh` with positive checks for:

```bash
if grep -qs 'references/figures\.md' "$ROOT/SKILL.md" \
    && grep -qs 'before.*plot' "$ROOT/SKILL.md"; then
    pass "SKILL.md routes plotting to the figure reference"
else
    fail "SKILL.md routes plotting to the figure reference"
fi

if grep -qs 'references/prerequisites\.md' "$ROOT/references/bootstrap.md" \
    && ! grep -qs '^## Agent-skill preflight' "$ROOT/references/bootstrap.md"; then
    pass "bootstrap delegates host prerequisites"
else
    fail "bootstrap delegates host prerequisites"
fi

if ! grep -Eq 'CLAUDE\.md.*symlink|\.claude/agents' "$ROOT/AGENTS.md"; then
    pass "AGENTS.md is host neutral"
else
    fail "AGENTS.md is host neutral"
fi
```

Add a live-file scan over `AGENTS.md`, `SKILL.md`, `README.md`, `references/`, `vendor.sh`, and
`tests/` that rejects drift-check interface strings while excluding historical `docs/superpowers/`
records and the deliberate deleted-interface test.

- [ ] **Step 2: Run the suite and confirm failure**

Run:

```bash
bash tests/consistency_test.sh
```

Expected: failures on current Claude-specific wording, duplicated bootstrap preflight, and drift
documentation.

- [ ] **Step 3: Make `AGENTS.md` portable and self-sufficient**

Apply these semantic changes:

- Replace the introduction's `CLAUDE.md` statement with a host-neutral statement that `AGENTS.md` is
  the governed policy.
- Keep the modification gates, safety floor, task triggers, configuration ownership, scientific
  rules, and general naming namespaces.
- Remove host paths and host-specific launcher terminology.
- State that detailed references expand procedure but do not own required safety rules.
- In **Figures**, require consulting the figure reference before plotting and again during QA, while
  leaving detailed figure naming grammar to `references/figures.md`.
- In **Analysis**, say “independent review agent” rather than “subagent” and preserve the
  no-implementation requirement.
- Remove `CLAUDE.md` from the repository-layout comment.

Do not alter the protected vendoring headings or the `## This repository` section boundary.

- [ ] **Step 4: Reduce `SKILL.md` to workflow and routing**

Apply these changes while preserving unrelated user edits already present in the file:

- Remove “and drift checks” from frontmatter.
- Keep applicability and bootstrap/governance mode selection.
- Replace the duplicated prerequisite list and recovery prose with a concise requirement to apply
  `references/prerequisites.md` once.
- Keep task routing to configuration, data, analysis, and figures.
- Make figure routing explicit before planning, plotting, output changes, and QA.
- Change bootstrap review terminology from Claude-specific “subagent” to host-neutral “independent
  review agent.”
- Change vendoring to `./vendor.sh <target>` for portable core, followed only by a user-selected
  optional host adapter.
- Do not silently restore or remove the unrelated Python-version, license, or runtime-configuration
  edits.

- [ ] **Step 5: Make prerequisites the host integration owner**

In `references/prerequisites.md`:

- document how the standard itself is installed/resolved in current Codex and Claude Code;
- retain exact scientific skill names and authoritative upstream sources;
- document `superpowers:writing-plans` resolution at planning time;
- document the verified Codex and Claude adapter commands;
- define delegated-agent skill/profile propagation and its functional smoke check;
- distinguish global host setup from generated project dependencies; and
- keep missing-capability recovery and reload/resume behavior.

Use the official URLs and mechanisms collected in Task 1. Do not claim identical namespace or
propagation behavior where the hosts differ.

- [ ] **Step 6: Remove duplicated host preflight and drift prose from bootstrap**

At the top of `references/bootstrap.md`, replace the full preflight section with:

```markdown
## Agent-host prerequisites

Complete the host-specific discovery, installation, delegated-agent verification, and recovery
procedure in `references/prerequisites.md` before the bootstrap interview. Agent-host prerequisites
remain separate from the generated repository's `make setup`.
```

Delete the `vendor.sh --check` exit-code paragraph. Replace the Claude-only simplifier profile
instruction with portable scaffold plus adapter wording based on Task 1's verified mechanism.

- [ ] **Step 7: Update README as a map**

State:

- `AGENTS.md` is the portable governed policy;
- `vendor.sh` copies only `AGENTS.md`;
- optional adapters install host integration;
- bootstrap may seed the canonical simplifier profile separately from vendoring;
- `tests/vendor_test.sh` covers portable vendoring and safety;
- `tests/adapter_test.sh` covers host integration; and
- `make check` is the aggregate source-repository validation entry point after Task 9.

Do not restate policy or adapter procedures in the README.

- [ ] **Step 8: Run focused tests and residual searches**

Run:

```bash
bash tests/consistency_test.sh
bash tests/vendor_test.sh
bash tests/adapter_test.sh
grep -RInE 'standard-check|vendor\.sh --check|drift checks|\.claude/agents/code-simplifier' \
    AGENTS.md SKILL.md README.md references vendor.sh tests adapters || true
```

Expected: tests pass. Remaining grep matches are limited to the deliberate deleted-interface test or
an adapter-owned path; no live policy claims source drift checking exists.

- [ ] **Step 9: Commit portable policy and prerequisites**

```bash
git add AGENTS.md SKILL.md README.md references/prerequisites.md references/bootstrap.md tests/consistency_test.sh
git commit -m "docs: separate portable policy from host setup"
```

Before committing, inspect `git diff -- SKILL.md references/bootstrap.md` and confirm unrelated
pre-existing hunks remain exactly as intentionally resolved by the user, not accidentally absorbed.

---

### Task 7: Deduplicate Domain References and Centralize Figure Naming

**Files:**

- Modify: `AGENTS.md:185-262,293-314`
- Modify: `references/configuration.md:1-114`
- Modify: `references/data.md:1-79`
- Modify: `references/analysis.md:1-105`
- Modify: `references/figures.md:1-142`
- Modify: `tests/consistency_test.sh`

**Interfaces:**

- Consumes: canonical ownership boundaries established in Task 6
- Produces: compact portable policy plus nonduplicative detailed domain procedures

- [ ] **Step 1: Add canonical-owner tests before editing prose**

Add assertions that:

- `references/figures.md` contains `mf1_{short_descriptive_name}` and the concrete figure asset
  examples.
- `AGENTS.md` contains the general publication identifier examples but does not contain
  `mf1_hazard_ratio_distribution`, `edf1_{short_descriptive_name}`, or the detailed
  extension-directory grammar.
- `references/configuration.md`, `references/data.md`, and `references/analysis.md` each identify
  `AGENTS.md` as the normative policy owner and themselves as procedural expansion.
- `agents/code-simplifier.md` contains no independent test-naming or configuration grammar.

Use exact `grep` checks with clear pass/fail messages.

- [ ] **Step 2: Run the consistency suite and confirm failure**

Run:

```bash
bash tests/consistency_test.sh
```

Expected: figure naming is still duplicated in `AGENTS.md`, and at least one domain reference does
not declare the ownership boundary clearly enough.

- [ ] **Step 3: Keep only general naming namespaces in `AGENTS.md`**

Retain:

```markdown
Publication artifacts use explicit identifiers: `main_figure_1`, `extended_data_figure_2`,
`main_table_1`, `supplementary_table_3`. Detailed atomic figure-asset and source-data naming is
defined by the figure reference and is loaded before figure work.
```

Remove the atomic `mf1_...` grammar and concrete panel-asset rule from `AGENTS.md`; keep the
mandatory figure gate, Python-only invariant, source-data requirement, export categories, and QA
obligation compactly stated.

- [ ] **Step 4: Make `references/figures.md` the sole detailed figure naming owner**

Keep and clarify:

- publication figure IDs versus atomic asset stems;
- `mf1_{short_descriptive_name}` and `edf1_{short_descriptive_name}` grammar;
- no panel letters in atomic files or renders;
- the same stem across SVG, PDF, TIFF, PNG, and source-data files;
- extension-named directories;
- worked path examples; and
- assembly-time panel lettering.

Remove repeated justification already complete in `AGENTS.md`; link back to the governed policy for
mandatory gates.

- [ ] **Step 5: Apply the policy/procedure split to configuration, data, and analysis**

For each reference:

- begin with one sentence that `AGENTS.md` owns the portable invariant;
- keep algorithms, templates, field guidance, migration procedure, validation mechanics, and test
  matrices;
- remove repeated compact floor statements where a link suffices; and
- retain any detail needed to execute the task without reconstructing it from policy.

In `references/analysis.md`, use “independent review agent” consistently and preserve the triggered,
no-implementation critique procedure.

- [ ] **Step 6: Run consistency tests**

Run:

```bash
bash tests/consistency_test.sh
```

Expected: all ownership and routing checks pass.

- [ ] **Step 7: Review duplication mechanically and semantically**

Run:

```bash
grep -RInE 'mf1_|edf1_|\.claude/agents|separate subagent|vendor\.sh --check' \
    AGENTS.md SKILL.md references agents README.md || true
```

Inspect every match. Expected: detailed figure stems occur only in `references/figures.md`;
host-specific paths occur only in prerequisite/adapter procedure; no retired drift interface
remains.

- [ ] **Step 8: Commit domain consolidation**

```bash
git add AGENTS.md references/configuration.md references/data.md references/analysis.md references/figures.md tests/consistency_test.sh
git commit -m "docs: consolidate reference ownership"
```

---

### Task 8: Add the Pinned Formatting and Lint Toolchain

**Files:**

- Create: `mise.toml`
- Create: `package.json`
- Create: `package-lock.json`
- Create: `.editorconfig`
- Create: `.prettierrc.json`
- Create: `.prettierignore`
- Create: `.markdownlint-cli2.yaml`
- Create: `.shellcheckrc`
- Create: `tools/quality.sh`
- Create: `tests/quality_test.sh`
- Modify: `.gitignore`
- Modify: `Makefile`

**Interfaces:**

- Consumes: stable current tool versions discovered in Task 1
- Produces: `make format`, `make lint`, and non-mutating `make check`

- [ ] **Step 1: Pin command-line runtimes with mise**

Run the current-version commands established in Task 1:

```bash
mise use --pin node@latest
mise use --pin shellcheck@latest
mise use --pin shfmt@latest
```

Expected: `mise.toml` contains exact stable versions, not floating `latest` entries. Inspect the
generated file and replace any floating selector with the resolved exact version.

- [ ] **Step 2: Pin Markdown tools with npm**

Create the package manifest and exact lock:

```bash
npm init -y
npm install --save-dev --save-exact prettier@latest markdownlint-cli2@latest
```

Edit `package.json` so it is private and contains:

```json
{
  "name": "research-repo-standard-quality",
  "private": true,
  "scripts": {
    "format:markdown": "prettier --write \"**/*.md\"",
    "check:markdown-format": "prettier --check \"**/*.md\"",
    "lint:markdown": "markdownlint-cli2 \"**/*.md\""
  }
}
```

Keep the exact `devDependencies` written by npm and commit `package-lock.json`.

- [ ] **Step 3: Define repository formatting policy**

Create `.editorconfig`:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{md,sh}]
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab
```

Create `.prettierrc.json`:

```json
{
  "proseWrap": "always",
  "printWidth": 100,
  "tabWidth": 2
}
```

Create `.prettierignore` with:

```text
.git/
.claude/worktrees/
.remember/
.superpowers/
node_modules/
```

Do not exclude `docs/superpowers/`; those historical files are still formatted.

- [ ] **Step 4: Configure Markdown and shell linting**

Create `.markdownlint-cli2.yaml` with explicit rules compatible with Prettier:

```yaml
config:
  default: true
  MD013: false
  MD033: false
globs:
  - "**/*.md"
ignores:
  - ".git/**"
  - ".claude/worktrees/**"
  - ".remember/**"
  - ".superpowers/**"
  - "node_modules/**"
```

Create `.shellcheckrc`:

```text
shell=bash
external-sources=true
```

Use shfmt's two-space Bash style consistently:

```text
shfmt -i 2 -ci -sr
```

- [ ] **Step 5: Create one quality driver**

Create `tools/quality.sh` with commands `format`, `lint`, and `check`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shell_files=(vendor.sh adapters/*.sh tests/*.sh tools/*.sh)

case "${1:-}" in
    format)
        mise exec -- npm ci
        mise exec -- npm run format:markdown
        mise exec -- shfmt -w -i 2 -ci -sr "${shell_files[@]}"
        ;;
    lint)
        mise exec -- npm ci
        mise exec -- npm run check:markdown-format
        mise exec -- npm run lint:markdown
        mise exec -- shellcheck "${shell_files[@]}"
        mise exec -- shfmt -d -i 2 -ci -sr "${shell_files[@]}"
        bash -n "${shell_files[@]}"
        ;;
    check)
        "$0" lint
        make test
        git diff --check
        ;;
    *)
        echo "usage: tools/quality.sh {format|lint|check}" >&2
        exit 2
        ;;
esac
```

If mise's correct execution syntax differs in the verified current release, use that documented
syntax consistently while preserving these three interfaces.

- [ ] **Step 6: Add frontmatter validation to the quality suite**

Extend `tests/quality_test.sh` to parse the opening YAML-like blocks in `SKILL.md` and
`agents/code-simplifier.md` without adding a second YAML tool. Check:

```bash
for file in "$ROOT/SKILL.md" "$ROOT/agents/code-simplifier.md"; do
    first="$(sed -n '1p' "$file")"
    second_delimiter="$(grep -n '^---$' "$file" | sed -n '2p')"
    if [[ "$first" == '---' && -n "$second_delimiter" ]]; then
        pass "frontmatter delimiters present: ${file#"$ROOT/"}"
    else
        fail "frontmatter delimiters present: ${file#"$ROOT/"}"
    fi
done
```

Also assert required keys `name`, `description`, and `standard_version`, reject duplicate keys,
reject tabs and trailing whitespace in tracked text files, and verify one final newline.

- [ ] **Step 7: Add Make entry points**

Use:

```make
.DEFAULT_GOAL := help
.PHONY: help format lint test check

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "%-8s %s\n", $$1, $$2}'

format: ## Format Markdown and shell files
	bash tools/quality.sh format

lint: ## Check Markdown, shell, frontmatter, and whitespace
	bash tools/quality.sh lint
	bash tests/quality_test.sh

test: ## Run vendoring, adapter, and documentation-contract tests
	bash tests/vendor_test.sh
	bash tests/adapter_test.sh
	bash tests/consistency_test.sh
	bash tests/quality_test.sh

check: ## Run every non-mutating repository check
	bash tools/quality.sh check
```

Avoid recursive duplicate execution by having `tools/quality.sh check` call the focused test scripts
directly if `make test` plus the Makefile wiring would rerun quality checks twice.

- [ ] **Step 8: Run focused quality tests before formatting**

Run:

```bash
bash tests/quality_test.sh
make lint
```

Expected: failures on the existing trailing whitespace and formatting differences. Tool installation
must use the committed mise and npm locks.

- [ ] **Step 9: Commit the toolchain and failing contract**

```bash
git add mise.toml package.json package-lock.json .editorconfig .prettierrc.json .prettierignore \
    .markdownlint-cli2.yaml .shellcheckrc tools/quality.sh tests/quality_test.sh Makefile .gitignore
git commit -m "build: add pinned repository quality checks"
```

---

### Task 9: Format and Lint Every Repository Source File

**Files:**

- Modify: all tracked `*.md`
- Modify: `vendor.sh`
- Modify: `adapters/*.sh`
- Modify: `tests/*.sh`
- Modify: `tools/*.sh`
- Modify: `Makefile` only if the configured formatter exposes a real issue
- Modify: the existing untracked historical plan mechanically, without changing its meaning

**Interfaces:**

- Consumes: `make format`, `make lint`, and `make test` from Task 8
- Produces: repository-wide formatting with no lint violations

- [ ] **Step 1: Run the committed formatter over all in-scope files**

Run:

```bash
make format
```

Expected: Prettier formats every Markdown file outside explicit operational exclusions, and shfmt
formats every Bash file.

- [ ] **Step 2: Inspect semantic-sensitive Markdown diffs first**

Run:

```bash
git diff -- AGENTS.md SKILL.md references agents README.md
git diff -- docs/superpowers/specs docs/superpowers/plans
```

Expected: formatting only in historical docs; live policy changes match Tasks 5-7. Reject any
formatter change that alters fenced code meaning, Make recipes, YAML frontmatter values, protected
vendoring headings, or placeholder syntax.

- [ ] **Step 3: Run all non-mutating lint checks**

Run:

```bash
make lint
```

Expected: Prettier check, markdownlint-cli2, ShellCheck, shfmt diff, `bash -n`, frontmatter,
whitespace, and newline checks all pass.

- [ ] **Step 4: Fix lint findings at their source**

For every finding:

- fix prose rather than disabling a rule when the prose is unclear;
- add the narrowest justified lint suppression only when the code is clearer unchanged;
- do not weaken repository-wide rules merely to pass one file; and
- rerun the specific failing command before rerunning `make lint`.

- [ ] **Step 5: Run behavioral tests after formatting**

Run:

```bash
make test
```

Expected: all vendor, adapter, consistency, and quality tests pass.

- [ ] **Step 6: Run diff and residual checks**

Run:

```bash
git diff --check
grep -RInE 'standard-check|vendor\.sh --check|drift checks' \
    AGENTS.md SKILL.md README.md references vendor.sh adapters tests tools || true
git status --short
```

Expected: no whitespace errors; no live retired-interface claim; status contains only intended files
plus the preserved unrelated historical plan state.

- [ ] **Step 7: Commit repository-wide formatting**

Stage explicit paths printed by `git status`; do not use `git add .`:

```bash
git add AGENTS.md SKILL.md README.md references/*.md agents/*.md vendor.sh adapters/*.sh \
    tests/*.sh tools/*.sh Makefile docs/superpowers/specs/*.md \
    docs/superpowers/plans/2026-08-12-portable-skill-cleanup.md

git commit -m "style: format repository sources"
```

Do not stage `docs/superpowers/plans/2026-08-12-reduced-documentation-contract.md` unless the user
separately authorized committing that pre-existing untracked file.

---

### Task 10: Run Cross-Host and End-to-End Verification

**Files:**

- Modify: only files needed to fix a verified defect
- Test: all repository checks and temporary governed-repository smoke cases

**Interfaces:**

- Consumes: completed portable core, adapters, canonical references, and quality toolchain
- Produces: verified release-ready working tree with explicit host limitations reported

- [ ] **Step 1: Run the aggregate repository check**

Run:

```bash
make check
```

Expected: every formatting, lint, shell syntax, frontmatter, behavioral, consistency, and whitespace
check passes.

- [ ] **Step 2: Test portable core in a fresh temporary repository**

Run:

```bash
tmp="$(mktemp -d)"
git -C "$tmp" init -q
./vendor.sh "$tmp"
test -f "$tmp/AGENTS.md"
test ! -e "$tmp/CLAUDE.md"
test ! -e "$tmp/CODEX.md"
grep -q '^## This repository$' "$tmp/AGENTS.md"
```

Expected: only portable `AGENTS.md` integration exists.

- [ ] **Step 3: Test Claude Code adapter behavior**

Run:

```bash
./adapters/claude-code.sh "$tmp"
test "$(readlink "$tmp/CLAUDE.md")" = 'AGENTS.md'
test -f "$tmp/.claude/agents/code-simplifier.md"
```

Then, where Claude Code is available, start a temporary session in the target and verify it can
state:

1. which file owns portable repository policy;
2. where figure naming procedure lives; and
3. which canonical profile an independent simplification pass applies.

It must answer from the alias plus repository files without claiming a drift checker exists.

- [ ] **Step 4: Test Codex adapter behavior**

Create a second fresh target, vendor core, and run:

```bash
codex_tmp="$(mktemp -d)"
git -C "$codex_tmp" init -q
./vendor.sh "$codex_tmp"
./adapters/codex.sh "$codex_tmp"
test -f "$codex_tmp/AGENTS.md"
test ! -e "$codex_tmp/CODEX.md"
```

Where Codex is available, start it in the target and ask the same three policy-routing questions.
Verify it reads `AGENTS.md` at the expected scope and can perform the documented
independent-agent/profile flow. If interactive host execution is unavailable, report it as skipped
and retain the official-documentation plus adapter-test evidence; do not claim a runtime pass.

- [ ] **Step 5: Re-vendor and preserve project identity**

Run:

```bash
python3 - "$tmp/AGENTS.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "## This repository\n",
    "## This repository\n\nCUSTOM-PORTABLE-IDENTITY\n",
    1,
)
path.write_text(text)
PY
./vendor.sh "$tmp"
grep -q 'CUSTOM-PORTABLE-IDENTITY' "$tmp/AGENTS.md"
```

Expected: project identity survives portable re-vendoring and host adapters remain separate.

- [ ] **Step 6: Run an adversarial residual audit workflow**

Fan out read-only agents over:

1. retired drift/check behavior;
2. Claude-only or Codex-only assumptions in portable files;
3. duplicate canonical guidance and figure naming;
4. formatter/linter coverage gaps; and
5. test adequacy and accidental unrelated changes.

Require exact paths and verification. Resolve confirmed findings, rerun focused tests, and repeat
the audit once if any substantive finding was fixed.

- [ ] **Step 7: Run code simplification and review gates**

Because Bash code and tests changed, dispatch an independent code-simplifier agent using the
canonical profile over `vendor.sh`, `adapters/*.sh`, `tests/*.sh`, and `tools/quality.sh`. Accept
only behavior-preserving improvements, then rerun:

```bash
make check
```

Request a separate code review focused on correctness, portability, destructive behavior, and test
gaps. Fix confirmed findings and rerun `make check`.

- [ ] **Step 8: Inspect final repository boundaries**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
git diff --check
git log --oneline -12
```

Also inspect the full cumulative diff from commit `4a08dff`:

```bash
git diff 4a08dff..HEAD -- AGENTS.md SKILL.md README.md references agents vendor.sh adapters tests tools Makefile
```

Confirm:

- protected vendoring headings remain unchanged and ordered;
- no cleanup can reach `data/raw/`;
- no second portable policy copy exists;
- no source drift checker survives;
- figure naming grammar has one detailed owner;
- host-specific paths are confined to adapters and prerequisite procedure;
- every intended file is formatted and linted; and
- unrelated pre-existing changes were not silently decided.

- [ ] **Step 9: Commit any verification fixes**

If verification required changes, stage only those exact files and commit:

```bash
git commit -m "fix: resolve portable cleanup verification findings"
```

If no changes were needed, do not create an empty commit.

- [ ] **Step 10: Report completion faithfully**

Report:

- portable core and adapter behavior;
- drift functionality removed;
- canonical ownership changes;
- formatter/linter versions and commands;
- `make check` result;
- Claude Code and Codex smoke-test results, including skipped runtime checks;
- residual limitations; and
- preserved unrelated working-tree files.
