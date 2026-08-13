#!/usr/bin/env bash
# Normal-behavior tests for the single-output host adapters.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FAILS=0

pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}
run_case() {
  case_name=$1
  shift
  if "$@"; then pass "$case_name"; else fail "$case_name"; fi
}
inode_of() { LC_ALL=C ls -di "$1" | awk '{ print $1 }'; }
checksum_of() { cksum "$1" | awk '{ print $1 ":" $2 }'; }
snapshot_file() {
  snapshot_path=$1
  printf '%s\t%s\t%s\n' "$snapshot_path" "$(inode_of "$snapshot_path")" \
    "$(checksum_of "$snapshot_path")"
}
assert_snapshot_line() {
  snapshot_line=$1
  snapshot_path=${snapshot_line%%$'\t'*}
  snapshot_rest=${snapshot_line#*$'\t'}
  snapshot_inode=${snapshot_rest%%$'\t'*}
  snapshot_checksum=${snapshot_rest#*$'\t'}
  [[ "$(inode_of "$snapshot_path")" == "$snapshot_inode" ]] &&
    [[ "$(checksum_of "$snapshot_path")" == "$snapshot_checksum" ]]
}

test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT

canonical="$ROOT/agents/research-code-simplifier.md"
description='Simplifies recently changed research code for clarity and maintainability while preserving exact behavior and scientific contracts.'

adapter_for() {
  case "$1" in
    claude-code) printf '%s\n' "$ROOT/adapters/claude-code.sh" ;;
    codex) printf '%s\n' "$ROOT/adapters/codex.sh" ;;
  esac
}
destination_for() {
  case "$1" in
    claude-code) printf '%s/.claude/agents/research-code-simplifier.md\n' "$2" ;;
    codex) printf '%s/.codex/agents/research-code-simplifier.toml\n' "$2" ;;
  esac
}
extract_canonical_body() {
  awk 'delimiters < 2 && /^---$/ { delimiters++; next } delimiters >= 2 { print }' "$canonical"
}
extract_claude_body() {
  awk 'delimiters < 2 && /^---$/ { delimiters++; next } delimiters >= 2 { print }' "$1"
}
extract_codex_body() {
  awk -v quote="'''" '
    $0 == "developer_instructions = " quote { capture=1; next }
    capture && $0 == quote { closed=1; next }
    capture && !closed { print }
    END { if (!capture || !closed) exit 1 }
  ' "$1"
}
assert_rendered_profile() {
  rendered_host=$1 rendered_path=$2
  [[ -f "$rendered_path" && ! -L "$rendered_path" ]] || return 1
  case "$rendered_host" in
    claude-code)
      [[ "$(sed -n '1p' "$rendered_path")" == --- ]] &&
        [[ "$(sed -n '2p' "$rendered_path")" == 'name: research-code-simplifier' ]] &&
        [[ "$(sed -n '3p' "$rendered_path")" == "description: $description" ]] &&
        [[ "$(sed -n '4p' "$rendered_path")" == --- ]] &&
        cmp -s <(extract_canonical_body) <(extract_claude_body "$rendered_path")
      ;;
    codex)
      [[ "$(sed -n '1p' "$rendered_path")" == 'name = "research-code-simplifier"' ]] &&
        [[ "$(sed -n '2p' "$rendered_path")" == "description = \"$description\"" ]] &&
        [[ "$(sed -n '3p' "$rendered_path")" == "developer_instructions = '''" ]] &&
        cmp -s <(extract_canonical_body) <(extract_codex_body "$rendered_path")
      ;;
  esac
}
assert_no_transaction_artifacts() {
  artifact_target=$1
  ! find "$artifact_target" -mindepth 1 \
    \( -name '.research-code-simplifier.stage.*' \
      -o -name '.research-repo-standard-adapter.lock' \
      -o -name '.research-repo-standard-adapter.guard' \
      -o -name '.research-repo-standard-adapter.claim.*' \) \
    -print -quit | grep -q .
}

seed_legacy_sentinels() {
  sentinel_root=$1
  mkdir -p "$sentinel_root/agents" "$sentinel_root/.claude/agents" \
    "$sentinel_root/.codex/agents"
  printf 'target agents policy\n' > "$sentinel_root/AGENTS.md"
  printf 'target claude policy\n' > "$sentinel_root/CLAUDE.md"
  printf 'target codex policy\n' > "$sentinel_root/CODEX.md"
  printf 'legacy shared simplifier\n' > "$sentinel_root/agents/code-simplifier.md"
  printf 'legacy claude simplifier\n' > "$sentinel_root/.claude/agents/code-simplifier.md"
  printf 'legacy codex simplifier\n' > "$sentinel_root/.codex/agents/code-simplifier.toml"
}
snapshot_legacy_sentinels() {
  sentinel_root=$1
  for sentinel_path in \
    "$sentinel_root/AGENTS.md" \
    "$sentinel_root/CLAUDE.md" \
    "$sentinel_root/CODEX.md" \
    "$sentinel_root/agents/code-simplifier.md" \
    "$sentinel_root/.claude/agents/code-simplifier.md" \
    "$sentinel_root/.codex/agents/code-simplifier.toml"; do
    snapshot_file "$sentinel_path"
  done
}
legacy_sentinels_are_unchanged() {
  sentinel_snapshot=$1
  while IFS= read -r snapshot_line; do
    assert_snapshot_line "$snapshot_line" || return 1
  done < "$sentinel_snapshot"
}

normal_install_preserves_legacy() {
  fixture="$test_root/normal-install"
  mkdir "$fixture"
  seed_legacy_sentinels "$fixture"
  snapshot_legacy_sentinels "$fixture" > "$fixture.snapshot"
  "$ROOT/adapters/claude-code.sh" "$fixture" >/dev/null 2>&1 || return 1
  "$ROOT/adapters/codex.sh" "$fixture" >/dev/null 2>&1 || return 1
  assert_rendered_profile claude-code "$(destination_for claude-code "$fixture")" || return 1
  assert_rendered_profile codex "$(destination_for codex "$fixture")" || return 1
  legacy_sentinels_are_unchanged "$fixture.snapshot" || return 1
  assert_no_transaction_artifacts "$fixture"
}
run_case 'clean installs derive both host profiles and preserve all six legacy/policy sentinels' \
  normal_install_preserves_legacy

clean_target_creates_only_host_profiles() {
  fixture="$test_root/clean-target"
  mkdir "$fixture"
  "$ROOT/adapters/claude-code.sh" "$fixture" >/dev/null 2>&1 || return 1
  "$ROOT/adapters/codex.sh" "$fixture" >/dev/null 2>&1 || return 1
  assert_rendered_profile claude-code "$(destination_for claude-code "$fixture")" || return 1
  assert_rendered_profile codex "$(destination_for codex "$fixture")" || return 1
  for forbidden in AGENTS.md CLAUDE.md CODEX.md agents/code-simplifier.md \
    .claude/agents/code-simplifier.md .codex/agents/code-simplifier.toml; do
    [[ ! -e "$fixture/$forbidden" && ! -L "$fixture/$forbidden" ]] || return 1
  done
  [[ ! -e "$fixture/agents" && ! -L "$fixture/agents" ]] || return 1
  assert_no_transaction_artifacts "$fixture"
}
run_case 'clean target creates none of the six legacy/policy paths' \
  clean_target_creates_only_host_profiles

idempotent_rerun_preserves_inode_and_bytes() {
  fixture="$test_root/idempotent-$1"
  host=$1
  adapter="$(adapter_for "$host")"
  mkdir "$fixture"
  "$adapter" "$fixture" >/dev/null 2>&1 || return 1
  destination="$(destination_for "$host" "$fixture")"
  before="$(snapshot_file "$destination")"
  "$adapter" "$fixture" >/dev/null 2>&1 || return 1
  assert_snapshot_line "$before" && assert_no_transaction_artifacts "$fixture"
}
for host in claude-code codex; do
  run_case "$host exact rerun preserves destination inode and bytes" \
    idempotent_rerun_preserves_inode_and_bytes "$host"
done

custom_destination_is_refused() {
  host=$1
  fixture="$test_root/custom-$host"
  destination="$(destination_for "$host" "$fixture")"
  mkdir -p "${destination%/*}"
  printf 'custom destination\n' > "$destination"
  before="$(snapshot_file "$destination")"
  set +e
  "$(adapter_for "$host")" "$fixture" >"$fixture.output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] && assert_snapshot_line "$before" &&
    grep -Fq 'refusing customized destination' "$fixture.output" &&
    assert_no_transaction_artifacts "$fixture"
}
for host in claude-code codex; do
  run_case "$host refuses a customized destination without mutation" \
    custom_destination_is_refused "$host"
done

leaf_symlink_is_refused() {
  host=$1
  fixture="$test_root/leaf-link-$host"
  destination="$(destination_for "$host" "$fixture")"
  mkdir -p "${destination%/*}"
  printf 'outside\n' > "$fixture/outside"
  ln -s "$fixture/outside" "$destination"
  before="$(snapshot_file "$fixture/outside")"
  set +e
  "$(adapter_for "$host")" "$fixture" >"$fixture.output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] && [[ -L "$destination" ]] &&
    [[ "$(readlink "$destination")" == "$fixture/outside" ]] &&
    assert_snapshot_line "$before" && grep -Fq 'refusing destination symlink' "$fixture.output"
}
parent_symlink_is_refused() {
  host=$1
  fixture="$test_root/parent-link-$host"
  host_root=.claude
  [[ "$host" == codex ]] && host_root=.codex
  mkdir "$fixture" "$fixture/outside"
  ln -s "$fixture/outside" "$fixture/$host_root"
  set +e
  "$(adapter_for "$host")" "$fixture" >"$fixture.output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] && [[ -L "$fixture/$host_root" ]] &&
    [[ -z "$(find "$fixture/outside" -mindepth 1 -print -quit)" ]] &&
    grep -Fq 'refusing symlinked output parent' "$fixture.output"
}
physical_parent_mismatch_is_refused() {
  host=$1
  fixture="$test_root/physical-$host"
  host_root=.claude
  [[ "$host" == codex ]] && host_root=.codex
  mkdir -p "$fixture/real/$host_root"
  target_path="$fixture/real/../real"
  set +e
  "$(adapter_for "$host")" "$target_path" >"$fixture.output" 2>&1
  status=$?
  set -e
  # The target itself resolves physically; declared output parents must still remain below it.
  [[ "$status" -eq 0 ]] && assert_rendered_profile "$host" \
    "$(destination_for "$host" "$fixture/real")" && assert_no_transaction_artifacts "$fixture/real"
}
non_directory_parent_is_refused() {
  host=$1 component=$2
  fixture="$test_root/non-directory-$host-$component"
  host_root=.claude
  [[ "$host" == codex ]] && host_root=.codex
  mkdir "$fixture"
  if [[ "$component" == leaf-parent ]]; then
    mkdir "$fixture/$host_root"
    printf 'not a directory\n' > "$fixture/$host_root/agents"
  else
    printf 'not a directory\n' > "$fixture/$host_root"
  fi
  set +e
  "$(adapter_for "$host")" "$fixture" >"$fixture.output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] && grep -Fq 'output parent is not a directory' "$fixture.output"
}
for host in claude-code codex; do
  run_case "$host refuses a destination leaf symlink" leaf_symlink_is_refused "$host"
  run_case "$host refuses a symlinked host parent" parent_symlink_is_refused "$host"
  run_case "$host accepts a physically resolved target path without escaping it" \
    physical_parent_mismatch_is_refused "$host"
  run_case "$host refuses a non-directory host parent" \
    non_directory_parent_is_refused "$host" host-root
  run_case "$host refuses a non-directory agents parent" \
    non_directory_parent_is_refused "$host" leaf-parent
done

same_host_concurrency_is_idempotent() {
  host=$1
  fixture="$test_root/concurrent-$host"
  adapter="$(adapter_for "$host")"
  mkdir "$fixture"
  "$adapter" "$fixture" >"$fixture.one" 2>&1 & one=$!
  "$adapter" "$fixture" >"$fixture.two" 2>&1 & two=$!
  wait "$one"; one_status=$?
  wait "$two"; two_status=$?
  [[ "$one_status" -eq 0 && "$two_status" -eq 0 ]] &&
    assert_rendered_profile "$host" "$(destination_for "$host" "$fixture")" &&
    assert_no_transaction_artifacts "$fixture"
}
for host in claude-code codex; do
  run_case "$host same-host concurrent installs converge exactly" \
    same_host_concurrency_is_idempotent "$host"
done

cross_host_concurrency_is_independent() {
  fixture="$test_root/cross-host-concurrent"
  mkdir "$fixture"
  "$ROOT/adapters/claude-code.sh" "$fixture" >"$fixture.claude" 2>&1 & claude_pid=$!
  "$ROOT/adapters/codex.sh" "$fixture" >"$fixture.codex" 2>&1 & codex_pid=$!
  wait "$claude_pid"; claude_status=$?
  wait "$codex_pid"; codex_status=$?
  [[ "$claude_status" -eq 0 && "$codex_status" -eq 0 ]] &&
    assert_rendered_profile claude-code "$(destination_for claude-code "$fixture")" &&
    assert_rendered_profile codex "$(destination_for codex "$fixture")" &&
    assert_no_transaction_artifacts "$fixture"
}
run_case 'cross-host concurrent installs proceed independently' cross_host_concurrency_is_independent

if ((FAILS > 0)); then
  printf '%s test(s) failed\n' "$FAILS"
  exit 1
fi
printf 'all adapter tests passed\n'
