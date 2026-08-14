#!/usr/bin/env bash
# Failure-path tests for the host adapters: canonical validation and clean staging.
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
failure_exit_status() {
  failure_count=$1
  ((failure_count > 255)) && failure_count=255
  printf '%s\n' "$failure_count"
}
path_exists() { [[ -e "$1" || -L "$1" ]]; }

test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT

destination_for() {
  case "$1" in
    claude-code) printf '%s/.claude/agents/research-code-simplifier.md\n' "$2" ;;
    codex) printf '%s/.codex/agents/research-code-simplifier.toml\n' "$2" ;;
  esac
}
assert_stage_absent() {
  fixture=$1
  ! find "$fixture" -mindepth 1 -name '.research-code-simplifier.stage.*' \
    -print -quit | grep -q .
}

malformed_canonical_is_rejected() {
  host=$1
  copy_root="$test_root/malformed-source-$host"
  mkdir -p "$copy_root/adapters" "$copy_root/agents" "$copy_root/target"
  cp "$ROOT/adapters/profile-installer.sh" "$ROOT/adapters/$host.sh" "$copy_root/adapters/" \
    2>/dev/null || return 1
  cat > "$copy_root/agents/research-code-simplifier.md" <<'PROFILE'
---
name: wrong-profile-name
description: malformed copied canonical profile
---

Resolve and invoke research-repo-standard.
PROFILE
  set +e
  "$copy_root/adapters/$host.sh" "$copy_root/target" >"$copy_root/output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] &&
    grep -Fq 'canonical profile name is invalid' "$copy_root/output" &&
    ! path_exists "$(destination_for "$host" "$copy_root/target")" &&
    assert_stage_absent "$copy_root/target"
}

for host in claude-code codex; do
  run_case "$host rejects a malformed copied canonical profile" \
    malformed_canonical_is_rejected "$host"
done

run_case 'failure count is used as the suite exit status' \
  test "$(failure_exit_status 7)" -eq 7
run_case 'failure count is capped at the maximum shell exit status' \
  test "$(failure_exit_status 300)" -eq 255

if ((FAILS > 0)); then
  printf '%s test(s) failed\n' "$FAILS"
  exit "$(failure_exit_status "$FAILS")"
fi
printf 'all adapter safety tests passed\n'
