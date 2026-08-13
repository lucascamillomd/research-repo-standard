#!/usr/bin/env bash

# Focused final-review coverage for adapter acquisition and cleanup transitions.
# This suite intentionally uses only Bash 3.2-era features.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_ADAPTER="$ROOT/adapters/claude-code.sh"
CODEX_ADAPTER="$ROOT/adapters/codex.sh"
SOURCE_AGENTS="$ROOT/AGENTS.md"
SOURCE_PROFILE="$ROOT/agents/code-simplifier.md"

failures=0
test_root="$(mktemp -d "${TMPDIR:-/tmp}/adapter-finalization.XXXXXX")"
if [[ "${KEEP_ADAPTER_FINALIZATION_TMP:-0}" == 1 ]]; then
  trap 'printf "preserved test root: %s\n" "$test_root" >&2' EXIT
else
  trap 'rm -rf "$test_root"' EXIT
fi

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1"
  failures=$((failures + 1))
}

inode_of() {
  ls -di "$1" 2>/dev/null | awk '{ print $1 }'
}

file_checksum() {
  cksum < "$1" | awk '{ print $1 ":" $2 }'
}

prepare_fixture() {
  fixture="$test_root/$1"
  mkdir -p "$fixture"
  fixture="$(cd "$fixture" && pwd -P)"
  cp "$SOURCE_AGENTS" "$fixture/AGENTS.md"
}

set_adapter_metadata() {
  case "$1" in
    claude)
      adapter="$CLAUDE_ADAPTER"
      adapter_id="claude-code.sh"
      host_profile_rel=".claude/agents/code-simplifier.md"
      final_publish_rel="CLAUDE.md"
      publish_count=3
      fresh_rm_total=3
      fresh_rmdir_total=3
      exact_rerun_rm_total=6
      exact_rerun_rmdir_total=3
      output_rollback_rm_total=6
      output_rollback_rmdir_total=6
      lock_directory_fault_count=2
      claim_directory_fault_count=3
      ;;
    codex)
      adapter="$CODEX_ADAPTER"
      adapter_id="codex.sh"
      host_profile_rel=".codex/agents/code-simplifier.toml"
      final_publish_rel=".codex/agents/code-simplifier.toml"
      publish_count=2
      fresh_rm_total=3
      fresh_rmdir_total=2
      exact_rerun_rm_total=5
      exact_rerun_rmdir_total=2
      output_rollback_rm_total=5
      output_rollback_rmdir_total=5
      lock_directory_fault_count=1
      claim_directory_fault_count=2
      ;;
    *)
      printf 'unknown adapter label: %s\n' "$1" >&2
      exit 2
      ;;
  esac
}

assert_no_outputs_or_stages() {
  target="$1"
  ! find "$target" -mindepth 1 \
    ! -path "$target/AGENTS.md" \
    ! -path "$target/.research-repo-standard-adapter.claim.*" \
    ! -path "$target/.research-repo-standard-adapter.claim.*/*" \
    -print -quit | grep -q .
}

assert_only_agents_file() {
  target="$1"
  ! find "$target" -mindepth 1 ! -path "$target/AGENTS.md" -print -quit | grep -q .
}

assert_serialization_absent() {
  target="$1"
  [[ ! -e "$target/.research-repo-standard-adapter.guard" ]] &&
    [[ ! -L "$target/.research-repo-standard-adapter.guard" ]] &&
    [[ ! -e "$target/.research-repo-standard-adapter.lock" ]] &&
    [[ ! -L "$target/.research-repo-standard-adapter.lock" ]] &&
    ! find "$target" -mindepth 1 -maxdepth 1 \
      -name '.research-repo-standard-adapter.claim.*' -print -quit | grep -q .
}

assert_outputs_valid() {
  target="$1"
  host_rel="$2"
  if ! cmp -s "$SOURCE_PROFILE" "$target/agents/code-simplifier.md"; then
    return 1
  fi
  if [[ "$host_rel" == ".claude/agents/code-simplifier.md" ]]; then
    source_body="$(awk 'seen { print } /^---$/ { count += 1; if (count == 2) seen = 1 }' "$SOURCE_PROFILE")"
    host_body="$(awk 'seen { print } /^---$/ { count += 1; if (count == 2) seen = 1 }' "$target/$host_rel")"
    [[ "$source_body" == "$host_body" ]] || return 1
    grep -Fqx 'name: code-simplifier' "$target/$host_rel" || return 1
    grep -Fqx 'description: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.' "$target/$host_rel" || return 1
    [[ -L "$target/CLAUDE.md" ]] || return 1
    [[ "$(readlink "$target/CLAUDE.md")" == "AGENTS.md" ]] || return 1
  else
    grep -Fqx 'name = "code-simplifier"' "$target/$host_rel" || return 1
    grep -Fqx 'description = "Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise."' "$target/$host_rel" || return 1
    grep -Fqx 'developer_instructions = "Read and apply agents/code-simplifier.md before reviewing changed code. Preserve behavior exactly, follow AGENTS.md, edit only within the delegated scope, and rerun covering tests after any edit."' "$target/$host_rel" || return 1
  fi
  return 0
}

recorded_pid() {
  sed -n 's/^pid=//p' "$1"
}

marker_value() {
  key="$1"
  marker="$2"
  sed -n "s/^$key=//p" "$marker" | tail -n 1
}

create_claim_mkdir_wrappers() {
  mkdir -p "$test_root/pre-claim-mkdir-bin" "$test_root/collision-claim-mkdir-bin"

  cat > "$test_root/pre-claim-mkdir-bin/mkdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$MKDIR_COUNT_FILE" ]]; then
  count="$(cat "$MKDIR_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MKDIR_COUNT_FILE"
path="$1"
case "$path" in
  "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*)
    {
      printf '%s\n' 'claim-mkdir-fault'
      printf 'count=%s\n' "$count"
      printf 'path=%s\n' "$path"
      printf 'pid=%s\n' "$PPID"
      printf '%s\n' 'effect=pre'
      printf '%s\n' 'return_status=71'
    } > "$FAULT_MARKER"
    if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 1 ]]; then
      exit 91
    fi
    exit 71
    ;;
esac
exec "$REAL_MKDIR" "$@"
WRAPPER

  cat > "$test_root/collision-claim-mkdir-bin/mkdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$MKDIR_COUNT_FILE" ]]; then
  count="$(cat "$MKDIR_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MKDIR_COUNT_FILE"
path="$1"
case "$path" in
  "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*)
    "$REAL_MKDIR" "$@" || exit $?
    printf '%s\n' 'foreign claim owner' > "$path/owner"
    {
      printf '%s\n' 'claim-file-collision'
      printf 'count=%s\n' "$count"
      printf 'path=%s\n' "$path"
      printf 'owner=%s\n' "$path/owner"
      printf 'owner_inode=%s\n' "$(ls -di "$path/owner" | awk '{ print $1 }')"
      printf 'pid=%s\n' "$PPID"
    } > "$FAULT_MARKER"
    if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 1 ]]; then
      exit 91
    fi
    exit 0
    ;;
esac
exec "$REAL_MKDIR" "$@"
WRAPPER

  chmod +x "$test_root/pre-claim-mkdir-bin/mkdir" \
    "$test_root/collision-claim-mkdir-bin/mkdir"
}

create_claim_wc_wrapper() {
  mkdir -p "$test_root/claim-wc-bin"
  cat > "$test_root/claim-wc-bin/wc" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$WC_COUNT_FILE" ]]; then
  count="$(cat "$WC_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$WC_COUNT_FILE"

"$REAL_WC" "$@"
real_status=$?

claim_owner="$(find "$FAULT_TARGET" -mindepth 2 -maxdepth 2 \
  -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
owner_inode=''
if [[ -n "$claim_owner" ]]; then
  owner_inode="$(ls -di "$claim_owner" | awk '{ print $1 }')"
fi
{
  printf '%s\n' 'claim-file-transition-fault'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$claim_owner"
  printf 'inode=%s\n' "$owner_inode"
  printf 'pid=%s\n' "$EXPECTED_ADAPTER_PID"
  printf 'invoker_pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=post'
  printf '%s\n' 'signal=TERM'
  printf '%s\n' 'return_status=73'
} > "$FAULT_MARKER"

if [[ ! "$EXPECTED_ADAPTER_PID" =~ ^[0-9]+$ || "$count" -ne 1 ||
      "$real_status" -ne 0 || -z "$claim_owner" || -z "$owner_inode" ]]; then
  exit 91
fi

kill -TERM "$EXPECTED_ADAPTER_PID"
exit 73
WRAPPER
  chmod +x "$test_root/claim-wc-bin/wc"
}

create_cleanup_wrappers() {
  mkdir -p "$test_root/cleanup-bin"

  cat > "$test_root/cleanup-bin/rm" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$CLEANUP_RM_COUNT" ]]; then
  count="$(cat "$CLEANUP_RM_COUNT")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$CLEANUP_RM_COUNT"

path=''
for argument in "$@"; do
  path="$argument"
done

matched=0
fault_label="$FAULT_ROLE"
expected_count="$EXPECTED_FAULT_COUNT"
case "$FAULT_ROLE" in
  lock-owner)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.lock/owner" ]] &&
      matched=1
    ;;
  claim-owner)
    case "$path" in
      "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*/owner) matched=1 ;;
    esac
    ;;
  guard)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.guard" ]] &&
      matched=1
    ;;
  canonical-stage)
    case "$path" in
      "$FAULT_TARGET"/agents/.code-simplifier.md.stage.*) matched=1 ;;
    esac
    ;;
  output)
    [[ "$path" == "$FAULT_PATH" ]] && matched=1
    ;;
  multi)
    if [[ "$path" == "$MULTI_OUTPUT_PATH" ]]; then
      matched=1
      fault_label='output'
      expected_count="$MULTI_OUTPUT_COUNT"
    else
      case "$path" in
        "$FAULT_TARGET"/agents/.code-simplifier.md.stage.*)
          matched=1
          fault_label='stage'
          expected_count="$MULTI_STAGE_COUNT"
          ;;
      esac
    fi
    ;;
esac

if [[ "$matched" -eq 0 ]]; then
  exec "$REAL_RM" "$@"
fi

inode_before="$(ls -di "$path" 2>/dev/null | awk '{ print $1 }')"
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne "$expected_count" ||
      -z "$inode_before" ]]; then
  {
    printf '%s\n' 'unexpected-cleanup-fault'
    printf 'role=%s\n' "$fault_label"
    printf 'count=%s\n' "$count"
    printf 'expected_count=%s\n' "$expected_count"
    printf 'path=%s\n' "$path"
    printf 'pid=%s\n' "$PPID"
  } >> "$FAULT_MARKER"
  exit 91
fi

if [[ "$FAULT_EFFECT" == 'post' ]]; then
  "$REAL_RM" "$@"
  real_status=$?
  if [[ "$real_status" -ne 0 || -e "$path" || -L "$path" ]]; then
    exit 92
  fi
  after='absent'
else
  after='present'
fi

{
  printf '%s\n' 'cleanup-fault'
  printf 'role=%s\n' "$fault_label"
  printf 'command=%s\n' 'rm'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$path"
  printf 'inode_before=%s\n' "$inode_before"
  printf 'after=%s\n' "$after"
  printf 'pid=%s\n' "$PPID"
  printf 'effect=%s\n' "$FAULT_EFFECT"
  printf '%s\n' 'return_status=73'
} >> "$FAULT_MARKER"
exit 73
WRAPPER

  cat > "$test_root/cleanup-bin/rmdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$CLEANUP_RMDIR_COUNT" ]]; then
  count="$(cat "$CLEANUP_RMDIR_COUNT")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$CLEANUP_RMDIR_COUNT"

path="$1"
matched=0
case "$FAULT_ROLE" in
  lock-directory)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.lock" ]] &&
      matched=1
    ;;
  claim-directory)
    case "$path" in
      "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*) matched=1 ;;
    esac
    ;;
esac

if [[ "$matched" -eq 0 ]]; then
  exec "$REAL_RMDIR" "$@"
fi

inode_before="$(ls -di "$path" 2>/dev/null | awk '{ print $1 }')"
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$count" -ne "$EXPECTED_FAULT_COUNT" || -z "$inode_before" ]]; then
  {
    printf '%s\n' 'unexpected-cleanup-fault'
    printf 'role=%s\n' "$FAULT_ROLE"
    printf 'count=%s\n' "$count"
    printf 'expected_count=%s\n' "$EXPECTED_FAULT_COUNT"
    printf 'path=%s\n' "$path"
    printf 'pid=%s\n' "$PPID"
  } >> "$FAULT_MARKER"
  exit 91
fi

if [[ "$FAULT_EFFECT" == 'post' ]]; then
  "$REAL_RMDIR" "$@"
  real_status=$?
  if [[ "$real_status" -ne 0 || -e "$path" || -L "$path" ]]; then
    exit 92
  fi
  after='absent'
else
  after='present'
fi

{
  printf '%s\n' 'cleanup-fault'
  printf 'role=%s\n' "$FAULT_ROLE"
  printf 'command=%s\n' 'rmdir'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$path"
  printf 'inode_before=%s\n' "$inode_before"
  printf 'after=%s\n' "$after"
  printf 'pid=%s\n' "$PPID"
  printf 'effect=%s\n' "$FAULT_EFFECT"
  printf '%s\n' 'return_status=73'
} >> "$FAULT_MARKER"
exit 73
WRAPPER

  chmod +x "$test_root/cleanup-bin/rm" "$test_root/cleanup-bin/rmdir"
}

create_mv_wrapper() {
  mkdir -p "$test_root/fault-mv-bin"
  cat > "$test_root/fault-mv-bin/mv" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$MV_COUNT_FILE" ]]; then
  count="$(cat "$MV_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"

source_path="$1"
destination_path="$2"
if [[ "$count" -ne "$FAIL_ON_MV_COUNT" ]]; then
  exec "$REAL_MV" "$@"
fi

source_inode="$(ls -di "$source_path" 2>/dev/null | awk '{ print $1 }')"
"$REAL_MV" "$@"
real_status=$?
destination_inode="$(ls -di "$destination_path" 2>/dev/null | awk '{ print $1 }')"
{
  printf '%s\n' 'publish-transition-fault'
  printf 'count=%s\n' "$count"
  printf 'source=%s\n' "$source_path"
  printf 'destination=%s\n' "$destination_path"
  printf 'source_inode=%s\n' "$source_inode"
  printf 'destination_inode=%s\n' "$destination_inode"
  printf 'pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=post'
  printf '%s\n' 'return_status=1'
} > "$MV_FAULT_MARKER"

if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$destination_path" != "$EXPECTED_MV_DESTINATION" ||
      "$real_status" -ne 0 || -z "$source_inode" ||
      "$source_inode" != "$destination_inode" ]]; then
  exit 91
fi
exit 1
WRAPPER
  chmod +x "$test_root/fault-mv-bin/mv"
}

assert_cleanup_marker() {
  marker="$1"
  role="$2"
  command_name="$3"
  expected_count="$4"
  expected_pid="$5"
  expected_effect="$6"
  expected_path_pattern="$7"

  [[ -f "$marker" ]] || return 1
  [[ "$(grep -c '^cleanup-fault$' "$marker")" -eq 1 ]] || return 1
  [[ "$(marker_value role "$marker")" == "$role" ]] || return 1
  [[ "$(marker_value command "$marker")" == "$command_name" ]] || return 1
  [[ "$(marker_value count "$marker")" == "$expected_count" ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value effect "$marker")" == "$expected_effect" ]] || return 1
  [[ "$(marker_value return_status "$marker")" == 73 ]] || return 1
  marker_path="$(marker_value path "$marker")"
  [[ "$marker_path" == $expected_path_pattern ]] || return 1
  marker_inode="$(marker_value inode_before "$marker")"
  [[ "$marker_inode" =~ ^[0-9]+$ ]] || return 1
  if [[ "$expected_effect" == post ]]; then
    [[ "$(marker_value after "$marker")" == absent ]] || return 1
  else
    [[ "$(marker_value after "$marker")" == present ]] || return 1
  fi
}

run_pre_effect_claim_mkdir_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "pre claim mkdir $label"
  output_file="$test_root/pre-claim-mkdir-$label.out"
  pid_file="$test_root/pre-claim-mkdir-$label.pid"
  marker="$test_root/pre-claim-mkdir-$label.marker"
  count_file="$test_root/pre-claim-mkdir-$label.count"
  status=0

  REAL_MKDIR="$(command -v mkdir)" \
    MKDIR_COUNT_FILE="$count_file" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$marker" \
    PATH="$test_root/pre-claim-mkdir-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_path="$(marker_value path "$marker")"
  if [[ "$status" -eq 1 &&
        "$(cat "$count_file")" -eq 1 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        "$(marker_value effect "$marker")" == pre &&
        "$(marker_value return_status "$marker")" -eq 71 ]] &&
      assert_only_agents_file "$fixture" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label pre-effect claim-directory mkdir failure has exact evidence and no effect"
  else
    fail "$label pre-effect claim-directory mkdir failure has exact evidence and no effect"
  fi
}

run_claim_file_collision_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "claim file collision $label"
  output_file="$test_root/claim-collision-$label.out"
  pid_file="$test_root/claim-collision-$label.pid"
  marker="$test_root/claim-collision-$label.marker"
  count_file="$test_root/claim-collision-$label.count"
  status=0

  REAL_MKDIR="$(command -v mkdir)" \
    MKDIR_COUNT_FILE="$count_file" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$marker" \
    PATH="$test_root/collision-claim-mkdir-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_path="$(marker_value path "$marker")"
  owner_path="$(marker_value owner "$marker")"
  owner_inode="$(marker_value owner_inode "$marker")"
  if [[ "$status" -eq 1 &&
        "$(cat "$count_file")" -eq 1 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        "$owner_path" == "$claim_path/owner" &&
        -f "$owner_path" &&
        ! -L "$owner_path" &&
        "$(inode_of "$owner_path")" == "$owner_inode" &&
        "$(cat "$owner_path")" == 'foreign claim owner' &&
        ! -e "$fixture/.research-repo-standard-adapter.guard" &&
        ! -e "$fixture/.research-repo-standard-adapter.lock" ]] &&
      assert_no_outputs_or_stages "$fixture" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label claim-file noclobber collision preserves the foreign file"
  else
    fail "$label claim-file noclobber collision preserves the foreign file"
  fi
}

run_claim_file_transition_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "claim file transition $label"
  output_file="$test_root/claim-transition-$label.out"
  pid_file="$test_root/claim-transition-$label.pid"
  marker="$test_root/claim-transition-$label.marker"
  count_file="$test_root/claim-transition-$label.count"
  status_file="$test_root/claim-transition-$label.status"

  (
    status=0
    REAL_WC="$(command -v wc)" \
      WC_COUNT_FILE="$count_file" \
      FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
      FAULT_MARKER="$marker" \
      PATH="$test_root/claim-wc-bin:$PATH" \
      bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
        bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?
    printf '%s\n' "$status" > "$status_file"
  ) &
  runner_pid=$!

  ticks=0
  while [[ ! -f "$status_file" && "$ticks" -lt 500 ]]; do
    sleep 0.01
    ticks=$((ticks + 1))
  done
  if [[ ! -f "$status_file" ]]; then
    kill -KILL "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
    fail "$label post-effect claim-file signal transition terminates"
    return
  fi
  wait "$runner_pid" 2>/dev/null || true

  status="$(cat "$status_file")"
  adapter_pid="$(cat "$pid_file")"
  claim_path="$(marker_value path "$marker")"
  marker_inode="$(marker_value inode "$marker")"
  if [[ "$status" -eq 143 &&
        "$(cat "$count_file")" -eq 1 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.*/owner &&
        "$marker_inode" =~ ^[0-9]+$ &&
        "$(marker_value effect "$marker")" == post &&
        "$(marker_value signal "$marker")" == TERM &&
        "$(marker_value return_status "$marker")" -eq 73 ]] &&
      assert_only_agents_file "$fixture" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label post-effect nonzero claim-file transition records ownership before TERM cleanup"
  else
    fail "$label post-effect nonzero claim-file transition records ownership before TERM cleanup"
  fi
}

run_release_cleanup_case() {
  label="$1"
  role="$2"
  effect="$3"
  expected_count="$4"
  expected_rm_total="$5"
  expected_rmdir_total="$6"
  set_adapter_metadata "$label"
  prepare_fixture "release cleanup $label $role $effect"

  output_file="$test_root/release-$label-$role-$effect.out"
  pid_file="$test_root/release-$label-$role-$effect.pid"
  marker="$test_root/release-$label-$role-$effect.marker"
  rm_count="$test_root/release-$label-$role-$effect.rm-count"
  rmdir_count="$test_root/release-$label-$role-$effect.rmdir-count"
  : > "$marker"
  status=0

  case "$role" in
    lock-directory|claim-directory) command_name=rmdir ;;
    *) command_name=rm ;;
  esac

  REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    CLEANUP_RM_COUNT="$rm_count" \
    CLEANUP_RMDIR_COUNT="$rmdir_count" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$marker" \
    FAULT_ROLE="$role" \
    FAULT_EFFECT="$effect" \
    EXPECTED_FAULT_COUNT="$expected_count" \
    FAULT_PATH='' \
    MULTI_OUTPUT_PATH='' \
    MULTI_OUTPUT_COUNT=0 \
    MULTI_STAGE_COUNT=0 \
    PATH="$test_root/cleanup-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  case "$role" in
    lock-owner)
      path_pattern="$fixture/.research-repo-standard-adapter.lock/owner"
      ;;
    lock-directory)
      path_pattern="$fixture/.research-repo-standard-adapter.lock"
      ;;
    claim-owner)
      path_pattern="$fixture/.research-repo-standard-adapter.claim.*/owner"
      ;;
    claim-directory)
      path_pattern="$fixture/.research-repo-standard-adapter.claim.*"
      ;;
    guard)
      path_pattern="$fixture/.research-repo-standard-adapter.guard"
      ;;
  esac

  base_ok=0
  if assert_cleanup_marker "$marker" "$role" "$command_name" \
      "$expected_count" "$adapter_pid" "$effect" "$path_pattern" &&
      [[ "$(cat "$rm_count")" -eq "$expected_rm_total" &&
         "$(cat "$rmdir_count")" -eq "$expected_rmdir_total" ]] &&
      assert_outputs_valid "$fixture" "$host_profile_rel"; then
    base_ok=1
  fi

  if [[ "$effect" == post ]]; then
    if [[ "$base_ok" -eq 1 && "$status" -eq 0 ]] &&
        assert_serialization_absent "$fixture" &&
        grep -q '^installed ' "$output_file" &&
        ! grep -q 'cleanup incomplete' "$output_file"; then
      pass "$label post-effect nonzero cleanup verifies absent $role and continues"
    else
      fail "$label post-effect nonzero cleanup verifies absent $role and continues"
    fi
    return
  fi

  residual_ok=0
  marker_path="$(marker_value path "$marker")"
  marker_inode="$(marker_value inode_before "$marker")"
  case "$role" in
    claim-owner)
      if [[ -f "$marker_path" && ! -L "$marker_path" &&
            "$(inode_of "$marker_path")" == "$marker_inode" &&
            -f "$fixture/.research-repo-standard-adapter.guard" &&
            "$(inode_of "$fixture/.research-repo-standard-adapter.guard")" == "$marker_inode" &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" ]]; then
        residual_ok=1
      fi
      ;;
    claim-directory)
      if [[ -d "$marker_path" && ! -L "$marker_path" &&
            "$(inode_of "$marker_path")" == "$marker_inode" &&
            -f "$fixture/.research-repo-standard-adapter.guard" &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" &&
            ! -e "$marker_path/owner" ]]; then
        residual_ok=1
      fi
      ;;
    guard)
      if [[ -f "$marker_path" && ! -L "$marker_path" &&
            "$(inode_of "$marker_path")" == "$marker_inode" &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" ]] &&
          ! find "$fixture" -mindepth 1 -maxdepth 1 \
            -name '.research-repo-standard-adapter.claim.*' -print -quit | grep -q .; then
        residual_ok=1
      fi
      ;;
  esac

  if [[ "$base_ok" -eq 1 && "$status" -eq 1 && "$residual_ok" -eq 1 ]] &&
      grep -q 'cleanup incomplete' "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label pre-effect $role cleanup failure is surfaced and retains serialization"
  else
    fail "$label pre-effect $role cleanup failure is surfaced and retains serialization"
  fi
}

run_stage_post_effect_cleanup_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "stage post effect cleanup $label"

  first_output="$test_root/stage-post-first-$label.out"
  if ! "$adapter" "$fixture" > "$first_output" 2>&1; then
    fail "$label post-effect stage cleanup setup succeeds"
    return
  fi
  before_checksums="$(
    find "$fixture" -type f -print | sort | while IFS= read -r path; do
      printf '%s %s\n' "$path" "$(file_checksum "$path")"
    done
  )"

  output_file="$test_root/stage-post-$label.out"
  pid_file="$test_root/stage-post-$label.pid"
  marker="$test_root/stage-post-$label.marker"
  rm_count="$test_root/stage-post-$label.rm-count"
  rmdir_count="$test_root/stage-post-$label.rmdir-count"
  : > "$marker"
  status=0

  REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    CLEANUP_RM_COUNT="$rm_count" \
    CLEANUP_RMDIR_COUNT="$rmdir_count" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$marker" \
    FAULT_ROLE=canonical-stage \
    FAULT_EFFECT=post \
    EXPECTED_FAULT_COUNT=1 \
    FAULT_PATH='' \
    MULTI_OUTPUT_PATH='' \
    MULTI_OUTPUT_COUNT=0 \
    MULTI_STAGE_COUNT=0 \
    PATH="$test_root/cleanup-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  after_checksums="$(
    find "$fixture" -type f -print | sort | while IFS= read -r path; do
      printf '%s %s\n' "$path" "$(file_checksum "$path")"
    done
  )"
  if [[ "$status" -eq 0 &&
        "$before_checksums" == "$after_checksums" &&
        "$(cat "$rm_count")" -eq "$exact_rerun_rm_total" &&
        "$(cat "$rmdir_count")" -eq "$exact_rerun_rmdir_total" ]] &&
      assert_cleanup_marker "$marker" canonical-stage rm 1 "$adapter_pid" post \
        "$fixture/agents/.code-simplifier.md.stage.*" &&
      assert_outputs_valid "$fixture" "$host_profile_rel" &&
      assert_serialization_absent "$fixture" &&
      grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass "$label post-effect nonzero stage cleanup verifies absence and preserves exact outputs"
  else
    fail "$label post-effect nonzero stage cleanup verifies absence and preserves exact outputs"
  fi
}

assert_mv_marker() {
  marker="$1"
  expected_count="$2"
  expected_pid="$3"
  expected_destination="$4"
  source_pattern="$5"
  [[ -f "$marker" ]] || return 1
  [[ "$(marker_value count "$marker")" == "$expected_count" ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value destination "$marker")" == "$expected_destination" ]] || return 1
  source_path="$(marker_value source "$marker")"
  [[ "$source_path" == $source_pattern ]] || return 1
  [[ "$(marker_value source_inode "$marker")" =~ ^[0-9]+$ ]] || return 1
  [[ "$(marker_value source_inode "$marker")" == "$(marker_value destination_inode "$marker")" ]] || return 1
  [[ "$(marker_value real_status "$marker")" -eq 0 ]] || return 1
  [[ "$(marker_value effect "$marker")" == post ]] || return 1
  [[ "$(marker_value return_status "$marker")" -eq 1 ]] || return 1
}

run_output_post_effect_cleanup_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "output post effect cleanup $label"

  output_file="$test_root/output-post-$label.out"
  pid_file="$test_root/output-post-$label.pid"
  mv_marker="$test_root/output-post-$label.mv-marker"
  cleanup_marker="$test_root/output-post-$label.cleanup-marker"
  mv_count="$test_root/output-post-$label.mv-count"
  rm_count="$test_root/output-post-$label.rm-count"
  rmdir_count="$test_root/output-post-$label.rmdir-count"
  : > "$cleanup_marker"
  status=0

  final_destination="$fixture/$final_publish_rel"
  cleanup_output="$fixture/$host_profile_rel"
  case "$label" in
    claude) source_pattern="$fixture/.CLAUDE.md.stage.*/CLAUDE.md" ;;
    codex) source_pattern="$fixture/.codex/agents/.code-simplifier.toml.stage.*" ;;
  esac

  REAL_MV="$(command -v mv)" \
    MV_COUNT_FILE="$mv_count" \
    FAIL_ON_MV_COUNT="$publish_count" \
    MV_FAULT_MARKER="$mv_marker" \
    EXPECTED_MV_DESTINATION="$final_destination" \
    REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    CLEANUP_RM_COUNT="$rm_count" \
    CLEANUP_RMDIR_COUNT="$rmdir_count" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$cleanup_marker" \
    FAULT_ROLE=output \
    FAULT_EFFECT=post \
    EXPECTED_FAULT_COUNT=1 \
    FAULT_PATH="$cleanup_output" \
    MULTI_OUTPUT_PATH='' \
    MULTI_OUTPUT_COUNT=0 \
    MULTI_STAGE_COUNT=0 \
    PATH="$test_root/fault-mv-bin:$test_root/cleanup-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  if [[ "$status" -eq 1 &&
        "$(cat "$mv_count")" -eq "$publish_count" &&
        "$(cat "$rm_count")" -eq "$output_rollback_rm_total" &&
        "$(cat "$rmdir_count")" -eq "$output_rollback_rmdir_total" ]] &&
      assert_mv_marker "$mv_marker" "$publish_count" "$adapter_pid" \
        "$final_destination" "$source_pattern" &&
      assert_cleanup_marker "$cleanup_marker" output rm 1 "$adapter_pid" post \
        "$cleanup_output" &&
      assert_only_agents_file "$fixture" &&
      ! grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass "$label post-effect nonzero output cleanup verifies absence and preserves original failure"
  else
    fail "$label post-effect nonzero output cleanup verifies absence and preserves original failure"
  fi
}

run_cross_category_aggregation_case() {
  set_adapter_metadata claude
  prepare_fixture 'cross category aggregation claude'
  mkdir -p "$fixture/agents"
  cp "$SOURCE_PROFILE" "$fixture/agents/code-simplifier.md"
  canonical_inode="$(inode_of "$fixture/agents/code-simplifier.md")"
  canonical_checksum="$(file_checksum "$fixture/agents/code-simplifier.md")"

  output_file="$test_root/cross-category.out"
  pid_file="$test_root/cross-category.pid"
  mv_marker="$test_root/cross-category.mv-marker"
  cleanup_marker="$test_root/cross-category.cleanup-marker"
  mv_count="$test_root/cross-category.mv-count"
  rm_count="$test_root/cross-category.rm-count"
  rmdir_count="$test_root/cross-category.rmdir-count"
  : > "$cleanup_marker"
  status=0

  REAL_MV="$(command -v mv)" \
    MV_COUNT_FILE="$mv_count" \
    FAIL_ON_MV_COUNT=2 \
    MV_FAULT_MARKER="$mv_marker" \
    EXPECTED_MV_DESTINATION="$fixture/CLAUDE.md" \
    REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    CLEANUP_RM_COUNT="$rm_count" \
    CLEANUP_RMDIR_COUNT="$rmdir_count" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$cleanup_marker" \
    FAULT_ROLE=multi \
    FAULT_EFFECT=pre \
    EXPECTED_FAULT_COUNT=0 \
    FAULT_PATH='' \
    MULTI_OUTPUT_PATH="$fixture/.claude/agents/code-simplifier.md" \
    MULTI_OUTPUT_COUNT=1 \
    MULTI_STAGE_COUNT=3 \
    PATH="$test_root/fault-mv-bin:$test_root/cleanup-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  stage_path="$(sed -n '/^role=stage$/{n;n;n;s/^path=//p;}' "$cleanup_marker")"
  output_path="$(sed -n '/^role=output$/{n;n;n;s/^path=//p;}' "$cleanup_marker")"
  claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
    -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
  guard="$fixture/.research-repo-standard-adapter.guard"
  lock_owner="$fixture/.research-repo-standard-adapter.lock/owner"

  markers_ok=0
  if [[ "$(grep -c '^cleanup-fault$' "$cleanup_marker")" -eq 2 &&
        "$(grep -c '^pid='"$adapter_pid"'$' "$cleanup_marker")" -eq 2 &&
        "$(grep -c '^effect=pre$' "$cleanup_marker")" -eq 2 &&
        "$(grep -c '^return_status=73$' "$cleanup_marker")" -eq 2 &&
        "$(grep -c '^count=1$' "$cleanup_marker")" -eq 1 &&
        "$(grep -c '^count=3$' "$cleanup_marker")" -eq 1 &&
        "$output_path" == "$fixture/.claude/agents/code-simplifier.md" &&
        "$stage_path" == "$fixture"/agents/.code-simplifier.md.stage.* ]]; then
    markers_ok=1
  fi

  retained_ok=0
  if [[ -f "$output_path" && -f "$stage_path" &&
        -f "$guard" && ! -L "$guard" &&
        -f "$lock_owner" && ! -L "$lock_owner" &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(inode_of "$guard")" == "$(inode_of "$lock_owner")" &&
        "$(inode_of "$guard")" == "$(inode_of "$claim_owner")" &&
        ! -e "$fixture/CLAUDE.md" &&
        "$(inode_of "$fixture/agents/code-simplifier.md")" == "$canonical_inode" &&
        "$(file_checksum "$fixture/agents/code-simplifier.md")" == "$canonical_checksum" ]]; then
    retained_ok=1
  fi

  if [[ "$status" -eq 1 && "$markers_ok" -eq 1 && "$retained_ok" -eq 1 &&
        "$(cat "$mv_count")" -eq 2 &&
        "$(cat "$rm_count")" -eq 3 &&
        "$(cat "$rmdir_count")" -eq 1 &&
        "$(grep -c 'cleanup incomplete' "$output_file")" -ge 2 ]] &&
      assert_mv_marker "$mv_marker" 2 "$adapter_pid" "$fixture/CLAUDE.md" \
        "$fixture/.CLAUDE.md.stage.*/CLAUDE.md" &&
      ! grep -q '^installed ' "$output_file"; then
    pass 'claude cleanup aggregates output and stage failures before retaining serialization'
  else
    fail 'claude cleanup aggregates output and stage failures before retaining serialization'
  fi
}

create_claim_mkdir_wrappers
create_claim_wc_wrapper
create_cleanup_wrappers
create_mv_wrapper

for adapter_label in claude codex; do
  run_pre_effect_claim_mkdir_case "$adapter_label"
  run_claim_file_collision_case "$adapter_label"
  run_claim_file_transition_case "$adapter_label"
done

for adapter_label in claude codex; do
  set_adapter_metadata "$adapter_label"
  run_release_cleanup_case "$adapter_label" claim-owner pre 2 2 \
    "$lock_directory_fault_count"
  run_release_cleanup_case "$adapter_label" claim-directory pre \
    "$claim_directory_fault_count" 2 "$claim_directory_fault_count"
  run_release_cleanup_case "$adapter_label" guard pre 3 3 \
    "$fresh_rmdir_total"

  run_release_cleanup_case "$adapter_label" lock-owner post 1 \
    "$fresh_rm_total" "$fresh_rmdir_total"
  run_release_cleanup_case "$adapter_label" lock-directory post \
    "$lock_directory_fault_count" "$fresh_rm_total" "$fresh_rmdir_total"
  run_release_cleanup_case "$adapter_label" claim-owner post 2 \
    "$fresh_rm_total" "$fresh_rmdir_total"
  run_release_cleanup_case "$adapter_label" claim-directory post \
    "$claim_directory_fault_count" "$fresh_rm_total" "$fresh_rmdir_total"
  run_release_cleanup_case "$adapter_label" guard post 3 \
    "$fresh_rm_total" "$fresh_rmdir_total"

  run_stage_post_effect_cleanup_case "$adapter_label"
  run_output_post_effect_cleanup_case "$adapter_label"
done

run_cross_category_aggregation_case

if [[ "$failures" -ne 0 ]]; then
  printf '%s adapter finalization test(s) failed\n' "$failures" >&2
  exit 1
fi

printf '%s\n' 'All adapter finalization tests passed'
