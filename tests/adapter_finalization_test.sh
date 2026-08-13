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
      pre_lock_owner_rmdir_total=1
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
      pre_lock_owner_rmdir_total=0
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
  mkdir -p "$test_root/pre-claim-mkdir-bin" "$test_root/collision-claim-mkdir-bin" \
    "$test_root/exact-token-collision-claim-mkdir-bin"

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
      printf 'invoker_pid=%s\n' "$PPID"
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

  cat > "$test_root/exact-token-collision-claim-mkdir-bin/mkdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$MKDIR_COUNT_FILE" ]]; then
  count="$(cat "$MKDIR_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MKDIR_COUNT_FILE"

argument_count=$#
path="${1:-}"
case "$path" in
  "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*)
    "$REAL_MKDIR" "$@"
    real_status=$?
    claim_prefix="$FAULT_TARGET/.research-repo-standard-adapter.claim.$EXPECTED_ADAPTER_PID-"
    nonce=${path#"$claim_prefix"}
    expected_token="$EXPECTED_ADAPTER_PID:$EXPECTED_ADAPTER_ID:$nonce"
    owner_path="$path/owner"
    printf '%s\n' "$expected_token" > "$owner_path"
    directory_inode="$(ls -di "$path" 2> /dev/null | awk '{ print $1 }')"
    owner_inode="$(ls -di "$owner_path" 2> /dev/null | awk '{ print $1 }')"
    owner_byte_count="$(LC_ALL=C wc -c < "$owner_path" | tr -d '[:space:]')"
    owner_checksum="$(LC_ALL=C cksum < "$owner_path" | awk '{ print $1 ":" $2 }')"
    {
      printf '%s\n' 'exact-token-claim-file-collision'
      printf 'count=%s\n' "$count"
      printf 'argument_count=%s\n' "$argument_count"
      printf 'path=%s\n' "$path"
      printf 'directory_inode=%s\n' "$directory_inode"
      printf 'owner=%s\n' "$owner_path"
      printf 'owner_inode=%s\n' "$owner_inode"
      printf 'adapter_id=%s\n' "$EXPECTED_ADAPTER_ID"
      printf 'expected_token=%s\n' "$expected_token"
      printf 'owner_byte_count=%s\n' "$owner_byte_count"
      printf 'owner_checksum=%s\n' "$owner_checksum"
      printf 'pid=%s\n' "$EXPECTED_ADAPTER_PID"
      printf 'invoker_pid=%s\n' "$PPID"
      printf 'real_status=%s\n' "$real_status"
      printf '%s\n' 'effect=post-mkdir-pre-claim-file'
      printf '%s\n' 'return_status=0'
    } > "$FAULT_MARKER"

    expected_byte_count=$((${#expected_token} + 1))
    claim_child="$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2> /dev/null)"
    case "$EXPECTED_ADAPTER_ID" in
      claude-code.sh|codex.sh) adapter_id_ok=1 ;;
      *) adapter_id_ok=0 ;;
    esac
    if [[ ! "$EXPECTED_ADAPTER_PID" =~ ^[1-9][0-9]*$ ||
          "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 1 ||
          "$argument_count" -ne 1 || "$real_status" -ne 0 ||
          "$path" != "$claim_prefix"* ||
          ! "$nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ || "$adapter_id_ok" -ne 1 ||
          ! "$directory_inode" =~ ^[0-9]+$ || ! "$owner_inode" =~ ^[0-9]+$ ||
          "$owner_byte_count" -ne "$expected_byte_count" ||
          "$claim_child" != "$owner_path" ]]; then
      exit 91
    fi
    exit 0
    ;;
esac
exec "$REAL_MKDIR" "$@"
WRAPPER

  chmod +x "$test_root/pre-claim-mkdir-bin/mkdir" \
    "$test_root/collision-claim-mkdir-bin/mkdir" \
    "$test_root/exact-token-collision-claim-mkdir-bin/mkdir"
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
if [[ "$count" -ne 1 ]]; then
  exec "$REAL_WC" "$@"
fi

"$REAL_WC" "$@"
real_status=$?
argument_count=$#
argument_one=${1:-}

claim_owner="$(find "$FAULT_TARGET" -mindepth 2 -maxdepth 2 \
  -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
owner_inode=''
stdin_inode=''
if [[ -n "$claim_owner" ]]; then
  owner_inode="$(ls -di "$claim_owner" | awk '{ print $1 }')"
  stdin_inode="$(ls -diL /dev/stdin 2> /dev/null | awk '{ print $1 }')"
fi
wrapper_status=73
wrapper_pid=$$
invoker_parent_pid="$(ps -o ppid= -p "$PPID" 2> /dev/null | tr -d '[:space:]')"
if [[ ! "$EXPECTED_ADAPTER_PID" =~ ^[0-9]+$ ||
      ! "$wrapper_pid" =~ ^[0-9]+$ || ! "$PPID" =~ ^[0-9]+$ ||
      ! "$invoker_parent_pid" =~ ^[0-9]+$ ||
      "$invoker_parent_pid" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 1 ||
      "$argument_count" -ne 1 || "$argument_one" != -c ||
      "$real_status" -ne 0 || -z "$claim_owner" || -z "$owner_inode" ||
      ! "$stdin_inode" =~ ^[0-9]+$ || "$stdin_inode" != "$owner_inode" ]]; then
  wrapper_status=91
fi
{
  printf '%s\n' 'claim-file-transition-fault'
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'argument_one=%s\n' "$argument_one"
  printf 'path=%s\n' "$claim_owner"
  printf 'inode=%s\n' "$owner_inode"
  printf 'stdin_inode=%s\n' "$stdin_inode"
  printf 'pid=%s\n' "$EXPECTED_ADAPTER_PID"
  printf 'wrapper_pid=%s\n' "$wrapper_pid"
  printf 'invoker_pid=%s\n' "$PPID"
  printf 'invoker_parent_pid=%s\n' "$invoker_parent_pid"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=post'
  printf '%s\n' 'signal=TERM'
  printf 'return_status=%s\n' "$wrapper_status"
} > "$FAULT_MARKER"

if [[ "$wrapper_status" -eq 73 ]]; then
  kill -TERM "$EXPECTED_ADAPTER_PID"
fi
exit "$wrapper_status"
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
argument_count=$#
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
if [[ "${REPLACE_CLAIM_DIRECTORY_BEFORE_RELEASE:-0}" == 1 ]]; then
  claim_directory="$(find "$FAULT_TARGET" -mindepth 1 -maxdepth 1 \
    -type d -name '.research-repo-standard-adapter.claim.*' -print -quit)"
  claim_owner="$claim_directory/owner"
  claim_directory_inode="$(ls -di "$claim_directory" | awk '{ print $1 }')"
  claim_owner_inode="$(ls -di "$claim_owner" | awk '{ print $1 }')"
  guard_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.guard" | awk '{ print $1 }')"
  lock_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.lock" | awk '{ print $1 }')"
  lock_owner_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.lock/owner" | awk '{ print $1 }')"
  "$REAL_RM" "$claim_owner"
  owner_rm_status=$?
  "$REAL_RMDIR" "$claim_directory"
  directory_rmdir_status=$?
  directory_after_rmdir=present
  if [[ ! -e "$claim_directory" && ! -L "$claim_directory" ]]; then
    directory_after_rmdir=absent
  fi
  "$REAL_MKDIR" "$claim_directory"
  directory_mkdir_status=$?
  sentinel_path="$claim_directory/foreign-sentinel"
  printf '%s\n' 'foreign pre-release claim directory' > "$sentinel_path"
  replacement_inode="$(ls -di "$claim_directory" | awk '{ print $1 }')"
  {
    printf '%s\n' 'pre-release-claim-directory-replacement'
    printf 'count=%s\n' "$count"
    printf 'path=%s\n' "$claim_directory"
    printf 'original_inode=%s\n' "$claim_directory_inode"
    printf 'replacement_inode=%s\n' "$replacement_inode"
    printf 'claim_owner_inode=%s\n' "$claim_owner_inode"
    printf 'guard_inode=%s\n' "$guard_inode"
    printf 'lock_inode=%s\n' "$lock_inode"
    printf 'lock_owner_inode=%s\n' "$lock_owner_inode"
    printf 'owner_rm_status=%s\n' "$owner_rm_status"
    printf 'directory_rmdir_status=%s\n' "$directory_rmdir_status"
    printf 'directory_after_rmdir=%s\n' "$directory_after_rmdir"
    printf 'directory_mkdir_status=%s\n' "$directory_mkdir_status"
    printf 'sentinel_path=%s\n' "$sentinel_path"
    printf 'pid=%s\n' "$PPID"
    printf '%s\n' 'effect=different-inode-replacement-before-release'
  } > "$PRE_RELEASE_MARKER"
  if [[ "$owner_rm_status" -ne 0 || "$directory_rmdir_status" -ne 0 ||
        "$directory_after_rmdir" != absent || "$directory_mkdir_status" -ne 0 ||
        "$claim_directory_inode" == "$replacement_inode" ]]; then
    exit 91
  fi
fi
if [[ "${ADD_CLAIM_CHILD_BEFORE_RELEASE:-0}" == 1 ]]; then
  claim_directory="$(find "$FAULT_TARGET" -mindepth 1 -maxdepth 1 \
    -type d -name '.research-repo-standard-adapter.claim.*' -print -quit)"
  claim_owner="$claim_directory/owner"
  extra_path="$claim_directory/foreign-extra"
  claim_directory_inode="$(ls -di "$claim_directory" | awk '{ print $1 }')"
  claim_owner_inode="$(ls -di "$claim_owner" | awk '{ print $1 }')"
  guard_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.guard" | awk '{ print $1 }')"
  lock_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.lock" | awk '{ print $1 }')"
  lock_owner_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.lock/owner" | awk '{ print $1 }')"
  printf '%s\n' 'foreign pre-release claim child' > "$extra_path"
  extra_status=$?
  extra_inode="$(ls -di "$extra_path" 2> /dev/null | awk '{ print $1 }')"
  directory_inode_after="$(ls -di "$claim_directory" 2> /dev/null | awk '{ print $1 }')"
  {
    printf '%s\n' 'pre-release-claim-extra-child'
    printf 'count=%s\n' "$count"
    printf 'path=%s\n' "$claim_directory"
    printf 'claim_directory_inode=%s\n' "$claim_directory_inode"
    printf 'directory_inode_after=%s\n' "$directory_inode_after"
    printf 'claim_owner_inode=%s\n' "$claim_owner_inode"
    printf 'guard_inode=%s\n' "$guard_inode"
    printf 'lock_inode=%s\n' "$lock_inode"
    printf 'lock_owner_inode=%s\n' "$lock_owner_inode"
    printf 'extra_path=%s\n' "$extra_path"
    printf 'extra_inode=%s\n' "$extra_inode"
    printf 'extra_status=%s\n' "$extra_status"
    printf 'pid=%s\n' "$PPID"
    printf '%s\n' 'effect=foreign-extra-child-before-release'
  } > "$PRE_RELEASE_MARKER"
  if [[ "$extra_status" -ne 0 || ! "$extra_inode" =~ ^[0-9]+$ ||
        "$directory_inode_after" != "$claim_directory_inode" ]]; then
    exit 91
  fi
fi
if [[ "${ADD_LOCK_CHILD_BEFORE_RELEASE:-0}" == 1 ]]; then
  lock_directory="$FAULT_TARGET/.research-repo-standard-adapter.lock"
  lock_owner="$lock_directory/owner"
  claim_directory="$(find "$FAULT_TARGET" -mindepth 1 -maxdepth 1 \
    -type d -name '.research-repo-standard-adapter.claim.*' -print -quit)"
  claim_directory_count="$(find "$FAULT_TARGET" -mindepth 1 -maxdepth 1 \
    -type d -name '.research-repo-standard-adapter.claim.*' -print | \
    wc -l | tr -d '[:space:]')"
  claim_owner="$claim_directory/owner"
  guard_path="$FAULT_TARGET/.research-repo-standard-adapter.guard"
  extra_path="$lock_directory/foreign-extra"

  lock_inode_before="$(ls -di "$lock_directory" 2> /dev/null | awk '{ print $1 }')"
  lock_owner_inode_before="$(ls -di "$lock_owner" 2> /dev/null | awk '{ print $1 }')"
  claim_directory_inode="$(ls -di "$claim_directory" 2> /dev/null | awk '{ print $1 }')"
  claim_owner_inode="$(ls -di "$claim_owner" 2> /dev/null | awk '{ print $1 }')"
  guard_inode="$(ls -di "$guard_path" 2> /dev/null | awk '{ print $1 }')"
  owner_value="$(cat "$lock_owner" 2> /dev/null)"
  owner_byte_count_before="$(LC_ALL=C wc -c < "$lock_owner" | tr -d '[:space:]')"
  owner_checksum_before="$(LC_ALL=C cksum < "$lock_owner" | awk '{ print $1 ":" $2 }')"
  claim_owner_checksum_before="$(LC_ALL=C cksum < "$claim_owner" | awk '{ print $1 ":" $2 }')"
  guard_checksum_before="$(LC_ALL=C cksum < "$guard_path" | awk '{ print $1 ":" $2 }')"
  children_before="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
    LC_ALL=C sort | paste -sd, -)"

  printf '%s\n' 'foreign pre-release lock child' > "$extra_path"
  extra_status=$?
  extra_inode="$(ls -di "$extra_path" 2> /dev/null | awk '{ print $1 }')"
  extra_checksum="$(LC_ALL=C cksum < "$extra_path" | awk '{ print $1 ":" $2 }')"
  lock_inode_after="$(ls -di "$lock_directory" 2> /dev/null | awk '{ print $1 }')"
  lock_owner_inode_after="$(ls -di "$lock_owner" 2> /dev/null | awk '{ print $1 }')"
  owner_byte_count_after="$(LC_ALL=C wc -c < "$lock_owner" | tr -d '[:space:]')"
  owner_checksum_after="$(LC_ALL=C cksum < "$lock_owner" | awk '{ print $1 ":" $2 }')"
  children_after="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
    LC_ALL=C sort | paste -sd, -)"

  {
    printf '%s\n' 'pre-release-lock-extra-child'
    printf 'count=%s\n' "$count"
    printf 'argument_count=%s\n' "$argument_count"
    printf 'source=%s\n' "$source_path"
    printf 'destination=%s\n' "$destination_path"
    printf 'source_inode=%s\n' "$source_inode"
    printf 'destination_inode=%s\n' "$destination_inode"
    printf 'path=%s\n' "$lock_directory"
    printf 'lock_inode_before=%s\n' "$lock_inode_before"
    printf 'lock_inode_after=%s\n' "$lock_inode_after"
    printf 'lock_owner=%s\n' "$lock_owner"
    printf 'lock_owner_inode_before=%s\n' "$lock_owner_inode_before"
    printf 'lock_owner_inode_after=%s\n' "$lock_owner_inode_after"
    printf 'owner_value=%s\n' "$owner_value"
    printf 'owner_byte_count_before=%s\n' "$owner_byte_count_before"
    printf 'owner_byte_count_after=%s\n' "$owner_byte_count_after"
    printf 'owner_checksum_before=%s\n' "$owner_checksum_before"
    printf 'owner_checksum_after=%s\n' "$owner_checksum_after"
    printf 'adapter_id=%s\n' "$EXPECTED_ADAPTER_ID"
    printf 'claim_directory=%s\n' "$claim_directory"
    printf 'claim_directory_count=%s\n' "$claim_directory_count"
    printf 'claim_directory_inode=%s\n' "$claim_directory_inode"
    printf 'claim_owner=%s\n' "$claim_owner"
    printf 'claim_owner_inode=%s\n' "$claim_owner_inode"
    printf 'claim_owner_checksum_before=%s\n' "$claim_owner_checksum_before"
    printf 'guard=%s\n' "$guard_path"
    printf 'guard_inode=%s\n' "$guard_inode"
    printf 'guard_checksum_before=%s\n' "$guard_checksum_before"
    printf 'children_before=%s\n' "$children_before"
    printf 'children_after=%s\n' "$children_after"
    printf 'extra_path=%s\n' "$extra_path"
    printf 'extra_inode=%s\n' "$extra_inode"
    printf 'extra_checksum=%s\n' "$extra_checksum"
    printf 'extra_status=%s\n' "$extra_status"
    printf 'pid=%s\n' "$PPID"
    printf 'real_status=%s\n' "$real_status"
    printf '%s\n' 'effect=foreign-extra-child-in-exact-lock-after-final-publication'
    printf '%s\n' 'return_status=1'
  } > "$PRE_RELEASE_MARKER"

  expected_owner_byte_count=$((${#owner_value} + 1))
  expected_owner_prefix="$EXPECTED_ADAPTER_PID:$EXPECTED_ADAPTER_ID:"
  owner_nonce=${owner_value#"$expected_owner_prefix"}
  if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ||
        "$count" -ne "$EXPECTED_FINAL_PUBLISH_COUNT" || "$argument_count" -ne 2 ||
        "$source_path" != $EXPECTED_FINAL_MV_SOURCE_PATTERN ||
        "$destination_path" != "$EXPECTED_MV_DESTINATION" ||
        "$real_status" -ne 0 || "$source_inode" != "$destination_inode" ||
        "$lock_directory" != "$FAULT_TARGET/.research-repo-standard-adapter.lock" ||
        ! "$lock_inode_before" =~ ^[0-9]+$ ||
        "$lock_inode_after" != "$lock_inode_before" ||
        "$claim_directory_count" -ne 1 || ! "$claim_directory_inode" =~ ^[0-9]+$ ||
        ! "$lock_owner_inode_before" =~ ^[0-9]+$ ||
        "$lock_owner_inode_after" != "$lock_owner_inode_before" ||
        "$claim_owner_inode" != "$lock_owner_inode_before" ||
        "$guard_inode" != "$lock_owner_inode_before" ||
        "$owner_value" != "$expected_owner_prefix$owner_nonce" ||
        ! "$owner_nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ ||
        "$owner_byte_count_before" -ne "$expected_owner_byte_count" ||
        "$owner_byte_count_after" -ne "$expected_owner_byte_count" ||
        "$owner_checksum_after" != "$owner_checksum_before" ||
        "$claim_owner_checksum_before" != "$owner_checksum_before" ||
        "$guard_checksum_before" != "$owner_checksum_before" ||
        "$children_before" != owner || "$children_after" != foreign-extra,owner ||
        "$extra_path" != "$lock_directory/foreign-extra" || "$extra_status" -ne 0 ||
        ! "$extra_inode" =~ ^[0-9]+$ ]]; then
    exit 91
  fi
fi
exit 1
WRAPPER
  chmod +x "$test_root/fault-mv-bin/mv"
}

create_stage_creation_wrappers() {
  mkdir -p "$test_root/stage-mktemp-bin" "$test_root/stage-ln-bin"

  cat > "$test_root/stage-mktemp-bin/mktemp" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$STAGE_CREATE_COUNT_FILE" ]]; then
  count="$(cat "$STAGE_CREATE_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$STAGE_CREATE_COUNT_FILE"

if [[ "$count" -ne "$FAIL_ON_STAGE_CREATE_COUNT" ]]; then
  exec "$REAL_MKTEMP" "$@"
fi

argument_count=$#
argument_one="${1:-}"
argument_two="${2:-}"
template="$argument_one"
if [[ "$argument_one" == -d ]]; then
  template="$argument_two"
fi

created_path=''
created_type=''
created_inode=''
real_status='not-run'
signal_name='none'
return_status=73
effect="${STAGE_CREATE_EFFECT:-post}"
if [[ "$effect" == post ]]; then
  created_path="$("$REAL_MKTEMP" "$@")"
  real_status=$?
  printf '%s\n' "$created_path"
  if [[ -f "$created_path" && ! -L "$created_path" ]]; then
    created_type='regular-file'
  elif [[ -d "$created_path" && ! -L "$created_path" ]]; then
    created_type='directory'
  fi
  created_inode="$(ls -di "$created_path" 2>/dev/null | awk '{ print $1 }')"
  signal_name=TERM
fi

{
  printf '%s\n' 'stage-creation-transition-fault'
  printf '%s\n' 'command=mktemp'
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'argument_one=%s\n' "$argument_one"
  printf 'argument_two=%s\n' "$argument_two"
  printf 'template=%s\n' "$template"
  printf 'path=%s\n' "$created_path"
  printf 'inode=%s\n' "$created_inode"
  printf 'type=%s\n' "$created_type"
  printf 'pid=%s\n' "$EXPECTED_ADAPTER_PID"
  printf 'invoker_pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf 'effect=%s\n' "$effect"
  printf 'signal=%s\n' "$signal_name"
  printf 'return_status=%s\n' "$return_status"
} > "$STAGE_CREATE_MARKER"

expected_prefix=${EXPECTED_STAGE_TEMPLATE%XXXXXX}
if [[ ! "$EXPECTED_ADAPTER_PID" =~ ^[0-9]+$ ||
      "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$count" -ne "$EXPECTED_STAGE_CREATE_COUNT" ||
      "$argument_count" -ne "$EXPECTED_ARGUMENT_COUNT" ||
      "$argument_one" != "$EXPECTED_ARGUMENT_ONE" ||
      "$argument_two" != "$EXPECTED_ARGUMENT_TWO" ||
      "$template" != "$EXPECTED_STAGE_TEMPLATE" ]]; then
  exit 91
fi
if [[ "$effect" == post ]]; then
  if [[ "$created_path" != "$expected_prefix"?????? ||
        "$real_status" -ne 0 || -z "$created_inode" ||
        "$created_type" != "$EXPECTED_CREATED_TYPE" ]]; then
    exit 91
  fi
  kill -TERM "$EXPECTED_ADAPTER_PID"
elif [[ "$effect" != pre || -n "$created_path" || -n "$created_inode" ||
        -n "$created_type" || "$real_status" != not-run ]]; then
  exit 91
fi
exit 73
WRAPPER

  cat > "$test_root/stage-ln-bin/ln" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$STAGE_CREATE_COUNT_FILE" ]]; then
  count="$(cat "$STAGE_CREATE_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$STAGE_CREATE_COUNT_FILE"

argument_count=$#
argument_one="${1:-}"
source_path="${2:-}"
destination_path="${3:-}"
created_type=''
created_inode=''
created_target=''
real_status='not-run'
signal_name='none'
effect="${STAGE_CREATE_EFFECT:-post}"
if [[ "$effect" == post ]]; then
  "$REAL_LN" "$@"
  real_status=$?
  if [[ -L "$destination_path" ]]; then
    created_type='symbolic-link'
  fi
  created_inode="$(ls -di "$destination_path" 2>/dev/null | awk '{ print $1 }')"
  created_target="$(readlink "$destination_path" 2>/dev/null)"
  signal_name=TERM
fi

{
  printf '%s\n' 'stage-creation-transition-fault'
  printf '%s\n' 'command=ln'
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'argument_one=%s\n' "$argument_one"
  printf 'source=%s\n' "$source_path"
  printf 'destination=%s\n' "$destination_path"
  printf 'path=%s\n' "$destination_path"
  printf 'inode=%s\n' "$created_inode"
  printf 'type=%s\n' "$created_type"
  printf 'target=%s\n' "$created_target"
  printf 'pid=%s\n' "$EXPECTED_ADAPTER_PID"
  printf 'invoker_pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf 'effect=%s\n' "$effect"
  printf 'signal=%s\n' "$signal_name"
  printf '%s\n' 'return_status=73'
} > "$STAGE_CREATE_MARKER"

case "$destination_path" in
  "$EXPECTED_DESTINATION_PREFIX"??????/CLAUDE.md) destination_matches=1 ;;
  *) destination_matches=0 ;;
esac
if [[ ! "$EXPECTED_ADAPTER_PID" =~ ^[0-9]+$ ||
      "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$count" -ne 1 || "$argument_count" -ne 3 ||
      "$argument_one" != -s || "$source_path" != AGENTS.md ||
      "$destination_matches" -ne 1 ]]; then
  exit 91
fi
if [[ "$effect" == post ]]; then
  if [[ "$real_status" -ne 0 || -z "$created_inode" ||
        "$created_type" != symbolic-link || "$created_target" != AGENTS.md ]]; then
    exit 91
  fi
  kill -TERM "$EXPECTED_ADAPTER_PID"
elif [[ "$effect" != pre || -n "$created_inode" || -n "$created_type" ||
        -n "$created_target" || "$real_status" != not-run ||
        -e "$destination_path" || -L "$destination_path" ]]; then
  exit 91
fi
exit 73
WRAPPER

  chmod +x "$test_root/stage-mktemp-bin/mktemp" "$test_root/stage-ln-bin/ln"
}

create_acquisition_lock_child_wrappers() {
  mkdir -p "$test_root/acquisition-lock-child-bin"

  cat > "$test_root/acquisition-lock-child-bin/link" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$ACQUISITION_LINK_COUNT_FILE" ]]; then
  count="$(cat "$ACQUISITION_LINK_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$ACQUISITION_LINK_COUNT_FILE"
if [[ "$count" -ne 2 ]]; then
  exec "$REAL_LINK" "$@"
fi

argument_count=$#
source_path="${1:-}"
destination_path="${2:-}"
claim_directory="$(dirname "$source_path")"
lock_directory="$(dirname "$destination_path")"
guard_path="$FAULT_TARGET/.research-repo-standard-adapter.guard"
extra_component="$ACQUISITION_EXTRA_COMPONENT"
case "$extra_component" in
  lock) extra_path="$lock_directory/foreign-extra" ;;
  claim) extra_path="$claim_directory/foreign-extra" ;;
  *) exit 91 ;;
esac
source_inode="$(ls -di "$source_path" 2> /dev/null | awk '{ print $1 }')"
source_checksum="$(LC_ALL=C cksum < "$source_path" | awk '{ print $1 ":" $2 }')"
source_value="$(cat "$source_path" 2> /dev/null)"
source_byte_count="$(LC_ALL=C wc -c < "$source_path" | tr -d '[:space:]')"
claim_directory_inode="$(ls -di "$claim_directory" 2> /dev/null | awk '{ print $1 }')"
lock_inode_before="$(ls -di "$lock_directory" 2> /dev/null | awk '{ print $1 }')"
guard_inode="$(ls -di "$guard_path" 2> /dev/null | awk '{ print $1 }')"
guard_checksum="$(LC_ALL=C cksum < "$guard_path" | awk '{ print $1 ":" $2 }')"
children_before="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"
claim_children_before="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"

"$REAL_LINK" "$@"
real_status=$?
owner_inode="$(ls -di "$destination_path" 2> /dev/null | awk '{ print $1 }')"
owner_checksum="$(LC_ALL=C cksum < "$destination_path" | awk '{ print $1 ":" $2 }')"
lock_inode_after_link="$(ls -di "$lock_directory" 2> /dev/null | awk '{ print $1 }')"
children_after_link="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"
claim_children_after_link="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"
printf 'foreign acquisition %s child\n' "$extra_component" > "$extra_path"
extra_status=$?
extra_inode="$(ls -di "$extra_path" 2> /dev/null | awk '{ print $1 }')"
extra_checksum="$(LC_ALL=C cksum < "$extra_path" | awk '{ print $1 ":" $2 }')"
lock_inode_after_extra="$(ls -di "$lock_directory" 2> /dev/null | awk '{ print $1 }')"
children_after_extra="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"
claim_children_after_extra="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -exec basename {} \; | \
  LC_ALL=C sort | paste -sd, -)"

{
  printf '%s\n' 'acquisition-owner-link-extra-child'
  printf 'extra_component=%s\n' "$extra_component"
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'source=%s\n' "$source_path"
  printf 'destination=%s\n' "$destination_path"
  printf 'source_inode=%s\n' "$source_inode"
  printf 'source_checksum=%s\n' "$source_checksum"
  printf 'source_value=%s\n' "$source_value"
  printf 'source_byte_count=%s\n' "$source_byte_count"
  printf 'claim_directory=%s\n' "$claim_directory"
  printf 'claim_directory_inode=%s\n' "$claim_directory_inode"
  printf 'guard=%s\n' "$guard_path"
  printf 'guard_inode=%s\n' "$guard_inode"
  printf 'guard_checksum=%s\n' "$guard_checksum"
  printf 'lock=%s\n' "$lock_directory"
  printf 'lock_inode_before=%s\n' "$lock_inode_before"
  printf 'lock_inode_after_link=%s\n' "$lock_inode_after_link"
  printf 'lock_inode_after_extra=%s\n' "$lock_inode_after_extra"
  printf 'owner_inode=%s\n' "$owner_inode"
  printf 'owner_checksum=%s\n' "$owner_checksum"
  printf 'children_before=%s\n' "$children_before"
  printf 'children_after_link=%s\n' "$children_after_link"
  printf 'children_after_extra=%s\n' "$children_after_extra"
  printf 'claim_children_before=%s\n' "$claim_children_before"
  printf 'claim_children_after_link=%s\n' "$claim_children_after_link"
  printf 'claim_children_after_extra=%s\n' "$claim_children_after_extra"
  printf 'extra_path=%s\n' "$extra_path"
  printf 'extra_inode=%s\n' "$extra_inode"
  printf 'extra_checksum=%s\n' "$extra_checksum"
  printf 'extra_status=%s\n' "$extra_status"
  printf 'pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=real-owner-link-then-foreign-extra-child'
  printf '%s\n' 'return_status=0'
} > "$ACQUISITION_MUTATION_MARKER"

expected_source_prefix="$FAULT_TARGET/.research-repo-standard-adapter.claim.$EXPECTED_ADAPTER_PID-"
source_nonce=${claim_directory#"$expected_source_prefix"}
expected_token_prefix="$EXPECTED_ADAPTER_PID:$EXPECTED_ADAPTER_ID:"
token_nonce=${source_value#"$expected_token_prefix"}
expected_byte_count=$((${#source_value} + 1))
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 2 ||
      "$argument_count" -ne 2 ||
      "$source_path" != "$claim_directory/owner" ||
      "$claim_directory" != "$expected_source_prefix$source_nonce" ||
      ! "$source_nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ ||
      "$destination_path" != "$FAULT_TARGET/.research-repo-standard-adapter.lock/owner" ||
      "$lock_directory" != "$FAULT_TARGET/.research-repo-standard-adapter.lock" ||
      ! "$claim_directory_inode" =~ ^[0-9]+$ || ! "$lock_inode_before" =~ ^[0-9]+$ ||
      "$lock_inode_after_link" != "$lock_inode_before" ||
      "$lock_inode_after_extra" != "$lock_inode_before" ||
      ! "$source_inode" =~ ^[0-9]+$ || "$guard_inode" != "$source_inode" ||
      "$source_value" != "$expected_token_prefix$token_nonce" ||
      ! "$token_nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ ||
      "$source_byte_count" -ne "$expected_byte_count" ||
      "$guard_checksum" != "$source_checksum" || "$real_status" -ne 0 ||
      "$owner_inode" != "$source_inode" || "$owner_checksum" != "$source_checksum" ||
      -n "$children_before" || "$children_after_link" != owner ||
      "$claim_children_before" != owner || "$claim_children_after_link" != owner ||
      "$extra_status" -ne 0 ||
      ! "$extra_inode" =~ ^[0-9]+$ ]]; then
  exit 91
fi
if [[ "$extra_component" == lock ]] &&
  { [[ "$children_after_extra" != foreign-extra,owner ]] ||
    [[ "$claim_children_after_extra" != owner ]] ||
    [[ "$extra_path" != "$lock_directory/foreign-extra" ]]; }; then
  exit 91
fi
if [[ "$extra_component" == claim ]] &&
  { [[ "$children_after_extra" != owner ]] ||
    [[ "$claim_children_after_extra" != foreign-extra,owner ]] ||
    [[ "$extra_path" != "$claim_directory/foreign-extra" ]]; }; then
  exit 91
fi
exit 0
WRAPPER

  cat > "$test_root/acquisition-lock-child-bin/mkdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
if [[ ! -f "$ACQUISITION_MUTATION_MARKER" ]]; then
  exec "$REAL_MKDIR" "$@"
fi
count="$(cat "$OUTPUT_MKDIR_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$OUTPUT_MKDIR_COUNT_FILE"
{
  printf '%s\n' 'unexpected-output-parent-attempt'
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$#"
  printf 'path=%s\n' "${1:-}"
  printf 'pid=%s\n' "$PPID"
  printf '%s\n' 'effect=pre'
  printf '%s\n' 'return_status=92'
} > "$OUTPUT_ATTEMPT_MARKER"
exit 92
WRAPPER

  cat > "$test_root/acquisition-lock-child-bin/mktemp" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count="$(cat "$OUTPUT_MKTEMP_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$OUTPUT_MKTEMP_COUNT_FILE"
{
  printf '%s\n' 'unexpected-stage-attempt'
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$#"
  printf 'argument_one=%s\n' "${1:-}"
  printf 'argument_two=%s\n' "${2:-}"
  printf 'pid=%s\n' "$PPID"
  printf '%s\n' 'effect=pre'
  printf '%s\n' 'return_status=93'
} > "$STAGE_ATTEMPT_MARKER"
exit 93
WRAPPER

  chmod +x "$test_root/acquisition-lock-child-bin/link" \
    "$test_root/acquisition-lock-child-bin/mkdir" \
    "$test_root/acquisition-lock-child-bin/mktemp"
}

create_changed_release_wrappers() {
  mkdir -p "$test_root/changed-release-bin"

  cat > "$test_root/changed-release-bin/link" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$RELEASE_LINK_COUNT_FILE" ]]; then
  count="$(cat "$RELEASE_LINK_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$RELEASE_LINK_COUNT_FILE"

source_path="$1"
destination_path="$2"
argument_count=$#
case "$PARTIAL_LINK_ROLE" in
  guard) fault_count=1 ;;
  owner | owner-missing-lock) fault_count=2 ;;
  *) fault_count=0 ;;
esac
if [[ "$fault_count" -eq 0 || "$count" -ne "$fault_count" ]]; then
  exec "$REAL_LINK" "$@"
fi

source_inode="$(ls -di "$source_path" 2>/dev/null | awk '{ print $1 }')"
claim_directory=''
claim_directory_inode=''
claim_owner_inode=''
claim_owner_checksum=''
extra_path=''
extra_inode=''
extra_status='not-run'
guard_inode=''
lock_path=''
lock_inode=''
lock_rmdir_status='not-run'
lock_after='present'
if [[ "${ADD_CLAIM_CHILD_ON_LINK_FAILURE:-0}" == 1 ]]; then
  claim_directory="$(dirname "$source_path")"
  claim_directory_inode="$(ls -di "$claim_directory" 2> /dev/null | awk '{ print $1 }')"
  claim_owner_inode="$source_inode"
  claim_owner_checksum="$(LC_ALL=C cksum < "$source_path" | awk '{ print $1 ":" $2 }')"
  extra_path="$claim_directory/foreign-extra"
  printf '%s\n' 'foreign partial-release claim child' > "$extra_path"
  extra_status=$?
  extra_inode="$(ls -di "$extra_path" 2> /dev/null | awk '{ print $1 }')"
  guard_inode="$(ls -di "$FAULT_TARGET/.research-repo-standard-adapter.guard" 2> /dev/null | awk '{ print $1 }')"
  lock_path="$FAULT_TARGET/.research-repo-standard-adapter.lock"
  lock_inode="$(ls -di "$lock_path" 2> /dev/null | awk '{ print $1 }')"
fi
if [[ "$PARTIAL_LINK_ROLE" == owner-missing-lock ]]; then
  lock_path="$FAULT_TARGET/.research-repo-standard-adapter.lock"
  lock_inode="$(ls -di "$lock_path" 2> /dev/null | awk '{ print $1 }')"
  if "$REAL_RMDIR" "$lock_path"; then
    lock_rmdir_status=0
  else
    lock_rmdir_status=$?
  fi
  if [[ ! -e "$lock_path" && ! -L "$lock_path" ]]; then
    lock_after=absent
  fi
fi
{
  printf '%s\n' 'partial-link-fault'
  printf 'role=%s\n' "$PARTIAL_LINK_ROLE"
  printf 'count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'source=%s\n' "$source_path"
  printf 'destination=%s\n' "$destination_path"
  printf 'source_inode=%s\n' "$source_inode"
  printf 'claim_directory=%s\n' "$claim_directory"
  printf 'claim_directory_inode=%s\n' "$claim_directory_inode"
  printf 'claim_owner_inode=%s\n' "$claim_owner_inode"
  printf 'claim_owner_checksum=%s\n' "$claim_owner_checksum"
  printf 'extra_path=%s\n' "$extra_path"
  printf 'extra_inode=%s\n' "$extra_inode"
  printf 'extra_status=%s\n' "$extra_status"
  printf 'guard_inode=%s\n' "$guard_inode"
  printf 'lock_path=%s\n' "$lock_path"
  printf 'lock_inode=%s\n' "$lock_inode"
  printf 'lock_rmdir_status=%s\n' "$lock_rmdir_status"
  printf 'lock_after=%s\n' "$lock_after"
  printf 'pid=%s\n' "$PPID"
  printf '%s\n' 'effect=pre'
  printf '%s\n' 'return_status=72'
} > "$RELEASE_LINK_MARKER"

case "$source_path" in
  "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*/owner) source_matches=1 ;;
  *) source_matches=0 ;;
esac
case "$PARTIAL_LINK_ROLE" in
  guard) expected_destination="$FAULT_TARGET/.research-repo-standard-adapter.guard" ;;
  owner | owner-missing-lock)
    expected_destination="$FAULT_TARGET/.research-repo-standard-adapter.lock/owner"
    ;;
esac
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne "$fault_count" ||
      "$argument_count" -ne 2 ||
      "$source_matches" -ne 1 || -z "$source_inode" ||
      "$destination_path" != "$expected_destination" ]]; then
  exit 91
fi
if [[ "${ADD_CLAIM_CHILD_ON_LINK_FAILURE:-0}" == 1 ]] &&
  { [[ ! "$claim_directory_inode" =~ ^[0-9]+$ ]] ||
    [[ ! "$claim_owner_inode" =~ ^[0-9]+$ ]] ||
    [[ ! "$extra_inode" =~ ^[0-9]+$ ]] || [[ "$extra_status" -ne 0 ]] ||
    [[ "$claim_owner_inode" != "$source_inode" ]]; }; then
  exit 91
fi
if [[ "$PARTIAL_LINK_ROLE" == owner-missing-lock ]] &&
  { [[ ! "$lock_inode" =~ ^[0-9]+$ ]] || [[ "$lock_rmdir_status" -ne 0 ]] ||
    [[ "$lock_after" != absent ]]; }; then
  exit 91
fi
exit 72
WRAPPER

  cat > "$test_root/changed-release-bin/mkdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$RELEASE_MKDIR_COUNT_FILE" ]]; then
  count="$(cat "$RELEASE_MKDIR_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$RELEASE_MKDIR_COUNT_FILE"
path="$1"

if [[ "$PARTIAL_MKDIR_FAULT" != lock || "$count" -ne 2 ]]; then
  exec "$REAL_MKDIR" "$@"
fi

{
  printf '%s\n' 'partial-mkdir-fault'
  printf '%s\n' 'role=lock'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$path"
  printf 'pid=%s\n' "$PPID"
  printf '%s\n' 'effect=pre'
  printf '%s\n' 'return_status=71'
} > "$RELEASE_MKDIR_MARKER"

if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" -ne 2 ||
      "$path" != "$FAULT_TARGET/.research-repo-standard-adapter.lock" ||
      -e "$path" || -L "$path" ]]; then
  exit 91
fi
exit 71
WRAPPER

  cat > "$test_root/changed-release-bin/rm" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$RELEASE_RM_COUNT_FILE" ]]; then
  count="$(cat "$RELEASE_RM_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$RELEASE_RM_COUNT_FILE"

path=''
for argument in "$@"; do
  path="$argument"
done
matched=0
case "$REPLACE_ROLE" in
  lock-owner)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.lock/owner" ]] &&
      matched=1
    ;;
  guard|partial-guard)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.guard" ]] &&
      matched=1
    ;;
  claim-owner|partial-claim-owner)
    case "$path" in
      "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*/owner) matched=1 ;;
    esac
    ;;
esac
if [[ "$matched" -eq 0 ]]; then
  exec "$REAL_RM" "$@"
fi

original_inode="$(ls -di "$path" 2>/dev/null | awk '{ print $1 }')"
parent_path="$(dirname "$path")"
parent_inode_before="$(ls -di "$parent_path" 2>/dev/null | awk '{ print $1 }')"
guard_path="$FAULT_TARGET/.research-repo-standard-adapter.guard"
guard_inode_before="$(ls -di "$guard_path" 2>/dev/null | awk '{ print $1 }')"
guard_value_before=''
if [[ -f "$guard_path" && ! -L "$guard_path" ]]; then
  guard_value_before="$(cat "$guard_path")"
fi

"$REAL_RM" "$@"
real_status=$?
if [[ "$real_status" -ne 0 || -e "$path" || -L "$path" ]]; then
  exit 92
fi
sentinel_content="foreign $REPLACE_ROLE sentinel"
printf '%s\n' "$sentinel_content" > "$path"
sentinel_inode="$(ls -di "$path" | awk '{ print $1 }')"

{
  printf '%s\n' 'changed-release-state'
  printf 'role=%s\n' "$REPLACE_ROLE"
  printf '%s\n' 'command=rm'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$path"
  printf 'original_inode=%s\n' "$original_inode"
  printf 'parent_inode_before=%s\n' "$parent_inode_before"
  printf 'sentinel_inode=%s\n' "$sentinel_inode"
  printf '%s\n' 'sentinel_type=regular-file'
  printf 'sentinel_content=%s\n' "$sentinel_content"
  printf 'guard_inode_before=%s\n' "$guard_inode_before"
  printf 'guard_value_before=%s\n' "$guard_value_before"
  printf 'pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=different-inode-replacement'
  printf '%s\n' 'return_status=73'
} > "$RELEASE_REPLACE_MARKER"

if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$count" -ne "$EXPECTED_REPLACE_COUNT" ||
      -z "$original_inode" || -z "$sentinel_inode" ||
      "$original_inode" == "$sentinel_inode" ]]; then
  exit 91
fi
exit 73
WRAPPER

  cat > "$test_root/changed-release-bin/rmdir" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
if [[ -f "$RELEASE_RMDIR_COUNT_FILE" ]]; then
  count="$(cat "$RELEASE_RMDIR_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$RELEASE_RMDIR_COUNT_FILE"

path="$1"
matched=0
case "$REPLACE_ROLE" in
  lock-directory|partial-lock-directory)
    [[ "$path" == "$FAULT_TARGET/.research-repo-standard-adapter.lock" ]] &&
      matched=1
    ;;
  claim-directory|partial-claim-directory)
    case "$path" in
      "$FAULT_TARGET"/.research-repo-standard-adapter.claim.*) matched=1 ;;
    esac
    ;;
esac
if [[ "$matched" -eq 0 ]]; then
  exec "$REAL_RMDIR" "$@"
fi

original_inode="$(ls -di "$path" 2>/dev/null | awk '{ print $1 }')"
guard_path="$FAULT_TARGET/.research-repo-standard-adapter.guard"
guard_inode_before="$(ls -di "$guard_path" 2>/dev/null | awk '{ print $1 }')"
guard_value_before=''
if [[ -f "$guard_path" && ! -L "$guard_path" ]]; then
  guard_value_before="$(cat "$guard_path")"
fi

"$REAL_RMDIR" "$@"
real_status=$?
if [[ "$real_status" -ne 0 || -e "$path" || -L "$path" ]]; then
  exit 92
fi
"$REAL_MKDIR" "$path"
sentinel_path="$path/foreign-sentinel"
sentinel_content="foreign $REPLACE_ROLE sentinel"
printf '%s\n' "$sentinel_content" > "$sentinel_path"
sentinel_inode="$(ls -di "$path" | awk '{ print $1 }')"
sentinel_file_inode="$(ls -di "$sentinel_path" | awk '{ print $1 }')"

{
  printf '%s\n' 'changed-release-state'
  printf 'role=%s\n' "$REPLACE_ROLE"
  printf '%s\n' 'command=rmdir'
  printf 'count=%s\n' "$count"
  printf 'path=%s\n' "$path"
  printf 'original_inode=%s\n' "$original_inode"
  printf 'sentinel_inode=%s\n' "$sentinel_inode"
  printf '%s\n' 'sentinel_type=directory'
  printf 'sentinel_path=%s\n' "$sentinel_path"
  printf 'sentinel_file_inode=%s\n' "$sentinel_file_inode"
  printf 'sentinel_content=%s\n' "$sentinel_content"
  printf 'guard_inode_before=%s\n' "$guard_inode_before"
  printf 'guard_value_before=%s\n' "$guard_value_before"
  printf 'pid=%s\n' "$PPID"
  printf 'real_status=%s\n' "$real_status"
  printf '%s\n' 'effect=different-inode-replacement'
  printf '%s\n' 'return_status=73'
} > "$RELEASE_REPLACE_MARKER"

if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ||
      "$count" -ne "$EXPECTED_REPLACE_COUNT" ||
      -z "$original_inode" || -z "$sentinel_inode" ||
      -z "$sentinel_file_inode" || "$original_inode" == "$sentinel_inode" ]]; then
  exit 91
fi
exit 73
WRAPPER

  chmod +x "$test_root/changed-release-bin/link" \
    "$test_root/changed-release-bin/mkdir" \
    "$test_root/changed-release-bin/rm" \
    "$test_root/changed-release-bin/rmdir"
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
        "$(marker_value invoker_pid "$marker")" == "$adapter_pid" &&
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
  child_count="$(find "$claim_path" -mindepth 1 -maxdepth 1 -print 2> /dev/null | wc -l | tr -d '[:space:]')"
  if [[ "$status" -eq 1 &&
        "$(cat "$count_file")" -eq 1 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        "$owner_path" == "$claim_path/owner" &&
        "$child_count" -eq 1 &&
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

run_exact_token_claim_file_collision_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "exact token claim file collision $label"
  output_file="$test_root/exact-token-claim-collision-$label.out"
  pid_file="$test_root/exact-token-claim-collision-$label.pid"
  marker="$test_root/exact-token-claim-collision-$label.marker"
  count_file="$test_root/exact-token-claim-collision-$label.count"
  status=0

  REAL_MKDIR="$(command -v mkdir)" \
    MKDIR_COUNT_FILE="$count_file" \
    FAULT_TARGET="$(cd "$fixture" && pwd -P)" \
    FAULT_MARKER="$marker" \
    EXPECTED_ADAPTER_ID="$adapter_id" \
    PATH="$test_root/exact-token-collision-claim-mkdir-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_path="$(marker_value path "$marker")"
  owner_path="$(marker_value owner "$marker")"
  expected_token="$(marker_value expected_token "$marker")"
  expected_diagnostic='failed to create adapter claim owner'
  [[ "$label" == claude ]] && expected_diagnostic='failed to write adapter acquisition claim'

  child_count="$(find "$claim_path" -mindepth 1 -maxdepth 1 -print 2> /dev/null | wc -l | tr -d '[:space:]')"
  if [[ "$status" -eq 1 &&
        "$(cat "$count_file")" -eq 1 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value argument_count "$marker")" -eq 1 &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$(marker_value invoker_pid "$marker")" == "$adapter_pid" &&
        "$(marker_value adapter_id "$marker")" == "$adapter_id" &&
        "$(marker_value real_status "$marker")" -eq 0 &&
        "$(marker_value effect "$marker")" == post-mkdir-pre-claim-file &&
        "$(marker_value return_status "$marker")" -eq 0 &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        -d "$claim_path" && ! -L "$claim_path" &&
        "$(inode_of "$claim_path")" == "$(marker_value directory_inode "$marker")" &&
        "$child_count" -eq 1 && "$owner_path" == "$claim_path/owner" &&
        -f "$owner_path" && ! -L "$owner_path" &&
        "$(inode_of "$owner_path")" == "$(marker_value owner_inode "$marker")" &&
        "$(cat "$owner_path")" == "$expected_token" &&
        "$(file_checksum "$owner_path")" == "$(marker_value owner_checksum "$marker")" &&
        "$(LC_ALL=C wc -c < "$owner_path" | tr -d '[:space:]')" == \
          "$(marker_value owner_byte_count "$marker")" &&
        ! -e "$fixture/.research-repo-standard-adapter.guard" &&
        ! -L "$fixture/.research-repo-standard-adapter.guard" &&
        ! -e "$fixture/.research-repo-standard-adapter.lock" &&
        ! -L "$fixture/.research-repo-standard-adapter.lock" ]] &&
      assert_no_outputs_or_stages "$fixture" &&
      grep -Fq "$expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label exact-token noclobber collision remains foreign"
  else
    fail "$label exact-token noclobber collision remains foreign"
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
        "$(cat "$count_file")" -eq 3 &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value argument_count "$marker")" -eq 1 &&
        "$(marker_value argument_one "$marker")" == -c &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$(marker_value wrapper_pid "$marker")" =~ ^[0-9]+$ &&
        "$(marker_value invoker_pid "$marker")" =~ ^[0-9]+$ &&
        "$(marker_value invoker_pid "$marker")" != "$adapter_pid" &&
        "$(marker_value invoker_parent_pid "$marker")" == "$adapter_pid" &&
        "$claim_path" == "$fixture"/.research-repo-standard-adapter.claim.*/owner &&
        "$marker_inode" =~ ^[0-9]+$ &&
        "$(marker_value stdin_inode "$marker")" == "$marker_inode" &&
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
  printf '%s\n' 0 > "$rm_count"
  printf '%s\n' 0 > "$rmdir_count"
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
      expected_cleanup_diagnostic="unable to remove adapter lock-owner"
      ;;
    lock-directory)
      path_pattern="$fixture/.research-repo-standard-adapter.lock"
      expected_cleanup_diagnostic="unable to remove adapter lock-directory"
      ;;
    claim-owner)
      path_pattern="$fixture/.research-repo-standard-adapter.claim.*/owner"
      expected_cleanup_diagnostic="unable to remove adapter claim owner"
      ;;
    claim-directory)
      path_pattern="$fixture/.research-repo-standard-adapter.claim.*"
      expected_cleanup_diagnostic="unable to remove adapter claim directory"
      ;;
    guard)
      path_pattern="$fixture/.research-repo-standard-adapter.guard"
      expected_cleanup_diagnostic="unable to remove adapter acquisition guard"
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
    lock-owner)
      claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
        -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
      guard_path="$fixture/.research-repo-standard-adapter.guard"
      lock_path="$fixture/.research-repo-standard-adapter.lock"
      if [[ -d "$lock_path" && ! -L "$lock_path" &&
            -f "$marker_path" && ! -L "$marker_path" &&
            "$(inode_of "$marker_path")" == "$marker_inode" &&
            -f "$guard_path" && ! -L "$guard_path" &&
            -f "$claim_owner" && ! -L "$claim_owner" &&
            "$(inode_of "$guard_path")" == "$marker_inode" &&
            "$(inode_of "$claim_owner")" == "$marker_inode" ]]; then
        residual_ok=1
      fi
      ;;
    lock-directory)
      claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
        -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
      guard_path="$fixture/.research-repo-standard-adapter.guard"
      lock_owner="$marker_path/owner"
      if [[ -d "$marker_path" && ! -L "$marker_path" &&
            "$(inode_of "$marker_path")" == "$marker_inode" &&
            -f "$guard_path" && ! -L "$guard_path" &&
            -f "$claim_owner" && ! -L "$claim_owner" &&
            -f "$lock_owner" && ! -L "$lock_owner" &&
            "$(inode_of "$guard_path")" == "$(inode_of "$claim_owner")" &&
            "$(inode_of "$guard_path")" == "$(inode_of "$lock_owner")" ]]; then
        residual_ok=1
      fi
      ;;
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
      grep -Fq "cleanup incomplete: $expected_cleanup_diagnostic: $marker_path" \
        "$output_file" &&
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

assert_mktemp_stage_marker() {
  marker="$1"
  expected_count="$2"
  expected_argument_count="$3"
  expected_argument_one="$4"
  expected_argument_two="$5"
  expected_template="$6"
  expected_type="$7"
  expected_pid="$8"
  expected_path_pattern="$9"

  [[ -f "$marker" ]] || return 1
  [[ "$(marker_value command "$marker")" == mktemp ]] || return 1
  [[ "$(marker_value count "$marker")" == "$expected_count" ]] || return 1
  [[ "$(marker_value argument_count "$marker")" == "$expected_argument_count" ]] ||
    return 1
  [[ "$(marker_value argument_one "$marker")" == "$expected_argument_one" ]] ||
    return 1
  [[ "$(marker_value argument_two "$marker")" == "$expected_argument_two" ]] ||
    return 1
  [[ "$(marker_value template "$marker")" == "$expected_template" ]] || return 1
  created_path="$(marker_value path "$marker")"
  [[ "$created_path" == $expected_path_pattern ]] || return 1
  [[ "$created_path" == "${expected_template%XXXXXX}"?????? ]] || return 1
  [[ "$(marker_value inode "$marker")" =~ ^[0-9]+$ ]] || return 1
  [[ "$(marker_value type "$marker")" == "$expected_type" ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value invoker_pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value real_status "$marker")" -eq 0 ]] || return 1
  [[ "$(marker_value effect "$marker")" == post ]] || return 1
  [[ "$(marker_value signal "$marker")" == TERM ]] || return 1
  [[ "$(marker_value return_status "$marker")" -eq 73 ]] || return 1
}

assert_pre_mktemp_stage_marker() {
  marker="$1"
  expected_count="$2"
  expected_argument_count="$3"
  expected_argument_one="$4"
  expected_argument_two="$5"
  expected_template="$6"
  expected_pid="$7"

  [[ -f "$marker" ]] || return 1
  [[ "$(marker_value command "$marker")" == mktemp ]] || return 1
  [[ "$(marker_value count "$marker")" == "$expected_count" ]] || return 1
  [[ "$(marker_value argument_count "$marker")" == "$expected_argument_count" ]] || return 1
  [[ "$(marker_value argument_one "$marker")" == "$expected_argument_one" ]] || return 1
  [[ "$(marker_value argument_two "$marker")" == "$expected_argument_two" ]] || return 1
  [[ "$(marker_value template "$marker")" == "$expected_template" ]] || return 1
  [[ -z "$(marker_value path "$marker")" && -z "$(marker_value inode "$marker")" ]] || return 1
  [[ -z "$(marker_value type "$marker")" ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value invoker_pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value real_status "$marker")" == not-run ]] || return 1
  [[ "$(marker_value effect "$marker")" == pre ]] || return 1
  [[ "$(marker_value signal "$marker")" == none ]] || return 1
  [[ "$(marker_value return_status "$marker")" -eq 73 ]]
}

run_mktemp_stage_creation_transition_case() {
  label="$1"
  stage_role="$2"
  set_adapter_metadata "$label"
  prepare_fixture "stage creation $label $stage_role"

  case "$stage_role" in
    canonical-file)
      expected_count=1
      expected_argument_count=1
      expected_argument_one="$fixture/agents/.code-simplifier.md.stage.XXXXXX"
      expected_argument_two=''
      expected_template="$expected_argument_one"
      expected_type='regular-file'
      ;;
    host-file)
      expected_count=2
      expected_argument_count=1
      case "$label" in
        claude)
          expected_argument_one="$fixture/.claude/agents/.code-simplifier.md.stage.XXXXXX"
          ;;
        codex)
          expected_argument_one="$fixture/.codex/agents/.code-simplifier.toml.stage.XXXXXX"
          ;;
      esac
      expected_argument_two=''
      expected_template="$expected_argument_one"
      expected_type='regular-file'
      ;;
    alias-directory)
      expected_count=3
      expected_argument_count=2
      expected_argument_one='-d'
      expected_argument_two="$fixture/.CLAUDE.md.stage.XXXXXX"
      expected_template="$expected_argument_two"
      expected_type='directory'
      ;;
    *)
      fail "$label unknown mktemp stage role $stage_role"
      return
      ;;
  esac

  output_file="$test_root/stage-create-$label-$stage_role.out"
  pid_file="$test_root/stage-create-$label-$stage_role.pid"
  marker="$test_root/stage-create-$label-$stage_role.marker"
  count_file="$test_root/stage-create-$label-$stage_role.count"
  status_file="$test_root/stage-create-$label-$stage_role.status"

  (
    status=0
    REAL_MKTEMP="$(command -v mktemp)" \
      STAGE_CREATE_COUNT_FILE="$count_file" \
      STAGE_CREATE_MARKER="$marker" \
      FAIL_ON_STAGE_CREATE_COUNT="$expected_count" \
      EXPECTED_STAGE_CREATE_COUNT="$expected_count" \
      EXPECTED_ARGUMENT_COUNT="$expected_argument_count" \
      EXPECTED_ARGUMENT_ONE="$expected_argument_one" \
      EXPECTED_ARGUMENT_TWO="$expected_argument_two" \
      EXPECTED_STAGE_TEMPLATE="$expected_template" \
      EXPECTED_CREATED_TYPE="$expected_type" \
      PATH="$test_root/stage-mktemp-bin:$PATH" \
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
    fail "$label post-effect nonzero TERM during $stage_role mktemp terminates"
    return
  fi
  wait "$runner_pid" 2>/dev/null || true

  status="$(cat "$status_file")"
  adapter_pid="$(cat "$pid_file")"
  path_pattern="${expected_template%XXXXXX}*"
  if [[ "$status" -eq 143 &&
        "$(cat "$count_file")" -eq "$expected_count" ]] &&
      assert_mktemp_stage_marker "$marker" "$expected_count" \
        "$expected_argument_count" "$expected_argument_one" "$expected_argument_two" \
        "$expected_template" "$expected_type" "$adapter_pid" "$path_pattern" &&
      assert_only_agents_file "$fixture" &&
      assert_serialization_absent "$fixture" &&
      ! grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass "$label post-effect nonzero TERM during $stage_role mktemp cleans exact effect"
  else
    fail "$label post-effect nonzero TERM during $stage_role mktemp cleans exact effect"
  fi
}

run_pre_mktemp_stage_creation_case() {
  label="$1"
  stage_role="$2"
  set_adapter_metadata "$label"
  prepare_fixture "pre stage creation $label $stage_role"

  case "$stage_role" in
    canonical-file)
      expected_count=1
      expected_argument_count=1
      expected_argument_one="$fixture/agents/.code-simplifier.md.stage.XXXXXX"
      expected_argument_two=''
      ;;
    host-file)
      expected_count=2
      expected_argument_count=1
      case "$label" in
        claude) expected_argument_one="$fixture/.claude/agents/.code-simplifier.md.stage.XXXXXX" ;;
        codex) expected_argument_one="$fixture/.codex/agents/.code-simplifier.toml.stage.XXXXXX" ;;
      esac
      expected_argument_two=''
      ;;
    alias-directory)
      expected_count=3
      expected_argument_count=2
      expected_argument_one=-d
      expected_argument_two="$fixture/.CLAUDE.md.stage.XXXXXX"
      ;;
  esac
  expected_template="$expected_argument_one"
  [[ "$expected_argument_one" == -d ]] && expected_template="$expected_argument_two"

  output_file="$test_root/pre-stage-create-$label-$stage_role.out"
  pid_file="$test_root/pre-stage-create-$label-$stage_role.pid"
  marker="$test_root/pre-stage-create-$label-$stage_role.marker"
  count_file="$test_root/pre-stage-create-$label-$stage_role.count"
  status=0
  REAL_MKTEMP="$(command -v mktemp)" \
    STAGE_CREATE_COUNT_FILE="$count_file" \
    STAGE_CREATE_MARKER="$marker" \
    STAGE_CREATE_EFFECT=pre \
    FAIL_ON_STAGE_CREATE_COUNT="$expected_count" \
    EXPECTED_STAGE_CREATE_COUNT="$expected_count" \
    EXPECTED_ARGUMENT_COUNT="$expected_argument_count" \
    EXPECTED_ARGUMENT_ONE="$expected_argument_one" \
    EXPECTED_ARGUMENT_TWO="$expected_argument_two" \
    EXPECTED_STAGE_TEMPLATE="$expected_template" \
    EXPECTED_CREATED_TYPE=unused \
    PATH="$test_root/stage-mktemp-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  if [[ "$status" -eq 1 && "$(cat "$count_file")" -eq "$expected_count" ]] &&
      assert_pre_mktemp_stage_marker "$marker" "$expected_count" "$expected_argument_count" \
        "$expected_argument_one" "$expected_argument_two" "$expected_template" "$adapter_pid" &&
      assert_only_agents_file "$fixture" && assert_serialization_absent "$fixture" &&
      ! grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass "$label pre-effect $stage_role mktemp failure leaves no transaction residue"
  else
    fail "$label pre-effect $stage_role mktemp failure leaves no transaction residue"
  fi
}

assert_ln_stage_marker() {
  marker="$1"
  expected_pid="$2"
  expected_destination_pattern="$3"

  [[ -f "$marker" ]] || return 1
  [[ "$(marker_value command "$marker")" == ln ]] || return 1
  [[ "$(marker_value count "$marker")" -eq 1 ]] || return 1
  [[ "$(marker_value argument_count "$marker")" -eq 3 ]] || return 1
  [[ "$(marker_value argument_one "$marker")" == -s ]] || return 1
  [[ "$(marker_value source "$marker")" == AGENTS.md ]] || return 1
  destination_path="$(marker_value destination "$marker")"
  [[ "$destination_path" == $expected_destination_pattern ]] || return 1
  [[ "$(marker_value path "$marker")" == "$destination_path" ]] || return 1
  [[ "$(marker_value inode "$marker")" =~ ^[0-9]+$ ]] || return 1
  [[ "$(marker_value type "$marker")" == symbolic-link ]] || return 1
  [[ "$(marker_value target "$marker")" == AGENTS.md ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value invoker_pid "$marker")" == "$expected_pid" ]] || return 1
  [[ "$(marker_value real_status "$marker")" -eq 0 ]] || return 1
  [[ "$(marker_value effect "$marker")" == post ]] || return 1
  [[ "$(marker_value signal "$marker")" == TERM ]] || return 1
  [[ "$(marker_value return_status "$marker")" -eq 73 ]] || return 1
}

run_alias_link_creation_transition_case() {
  set_adapter_metadata claude
  prepare_fixture 'stage creation claude alias link'

  output_file="$test_root/stage-create-claude-alias-link.out"
  pid_file="$test_root/stage-create-claude-alias-link.pid"
  marker="$test_root/stage-create-claude-alias-link.marker"
  count_file="$test_root/stage-create-claude-alias-link.count"
  status_file="$test_root/stage-create-claude-alias-link.status"
  destination_prefix="$fixture/.CLAUDE.md.stage."

  (
    status=0
    REAL_LN="$(command -v ln)" \
      STAGE_CREATE_COUNT_FILE="$count_file" \
      STAGE_CREATE_MARKER="$marker" \
      EXPECTED_DESTINATION_PREFIX="$destination_prefix" \
      PATH="$test_root/stage-ln-bin:$PATH" \
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
    fail 'claude post-effect nonzero TERM during alias ln creation terminates'
    return
  fi
  wait "$runner_pid" 2>/dev/null || true

  status="$(cat "$status_file")"
  adapter_pid="$(cat "$pid_file")"
  destination_pattern="${destination_prefix}??????/CLAUDE.md"
  if [[ "$status" -eq 143 && "$(cat "$count_file")" -eq 1 ]] &&
      assert_ln_stage_marker "$marker" "$adapter_pid" "$destination_pattern" &&
      assert_only_agents_file "$fixture" &&
      assert_serialization_absent "$fixture" &&
      ! grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass 'claude post-effect nonzero TERM during alias ln creation cleans exact symlink'
  else
    fail 'claude post-effect nonzero TERM during alias ln creation cleans exact symlink'
  fi
}

run_pre_alias_link_creation_case() {
  set_adapter_metadata claude
  prepare_fixture 'pre stage creation claude alias link'
  output_file="$test_root/pre-stage-create-claude-alias-link.out"
  pid_file="$test_root/pre-stage-create-claude-alias-link.pid"
  marker="$test_root/pre-stage-create-claude-alias-link.marker"
  count_file="$test_root/pre-stage-create-claude-alias-link.count"
  destination_prefix="$fixture/.CLAUDE.md.stage."
  status=0
  REAL_LN="$(command -v ln)" \
    STAGE_CREATE_COUNT_FILE="$count_file" \
    STAGE_CREATE_MARKER="$marker" \
    STAGE_CREATE_EFFECT=pre \
    EXPECTED_DESTINATION_PREFIX="$destination_prefix" \
    PATH="$test_root/stage-ln-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  destination_pattern="${destination_prefix}??????/CLAUDE.md"
  if [[ "$status" -eq 1 && "$(cat "$count_file")" -eq 1 &&
        "$(marker_value command "$marker")" == ln &&
        "$(marker_value count "$marker")" -eq 1 &&
        "$(marker_value argument_count "$marker")" -eq 3 &&
        "$(marker_value argument_one "$marker")" == -s &&
        "$(marker_value source "$marker")" == AGENTS.md &&
        "$(marker_value destination "$marker")" == $destination_pattern &&
        "$(marker_value path "$marker")" == "$(marker_value destination "$marker")" &&
        -z "$(marker_value inode "$marker")" && -z "$(marker_value type "$marker")" &&
        -z "$(marker_value target "$marker")" &&
        "$(marker_value pid "$marker")" == "$adapter_pid" &&
        "$(marker_value invoker_pid "$marker")" == "$adapter_pid" &&
        "$(marker_value real_status "$marker")" == not-run &&
        "$(marker_value effect "$marker")" == pre &&
        "$(marker_value signal "$marker")" == none &&
        "$(marker_value return_status "$marker")" -eq 73 ]] &&
      assert_only_agents_file "$fixture" && assert_serialization_absent "$fixture" &&
      ! grep -q '^installed ' "$output_file" &&
      ! grep -q 'cleanup incomplete' "$output_file"; then
    pass 'claude pre-effect alias ln failure leaves no transaction residue'
  else
    fail 'claude pre-effect alias ln failure leaves no transaction residue'
  fi
}

assert_changed_release_marker() {
  marker="$1"
  expected_role="$2"
  expected_command="$3"
  expected_count="$4"
  expected_pid="$5"
  expected_path_pattern="$6"

  [[ -f "$marker" ]] || return 1
  [[ "$(marker_value role "$marker")" == "$expected_role" ]] || return 1
  [[ "$(marker_value command "$marker")" == "$expected_command" ]] || return 1
  [[ "$(marker_value count "$marker")" -eq "$expected_count" ]] || return 1
  [[ "$(marker_value pid "$marker")" == "$expected_pid" ]] || return 1
  replaced_path="$(marker_value path "$marker")"
  [[ "$replaced_path" == $expected_path_pattern ]] || return 1
  original_inode="$(marker_value original_inode "$marker")"
  sentinel_inode="$(marker_value sentinel_inode "$marker")"
  [[ "$original_inode" =~ ^[0-9]+$ && "$sentinel_inode" =~ ^[0-9]+$ ]] ||
    return 1
  [[ "$original_inode" != "$sentinel_inode" ]] || return 1
  [[ "$(marker_value real_status "$marker")" -eq 0 ]] || return 1
  [[ "$(marker_value effect "$marker")" == different-inode-replacement ]] ||
    return 1
  [[ "$(marker_value return_status "$marker")" -eq 73 ]] || return 1

  sentinel_content="$(marker_value sentinel_content "$marker")"
  if [[ "$expected_command" == rm ]]; then
    [[ "$(marker_value sentinel_type "$marker")" == regular-file ]] || return 1
    [[ -f "$replaced_path" && ! -L "$replaced_path" ]] || return 1
    [[ "$(inode_of "$replaced_path")" == "$sentinel_inode" ]] || return 1
    [[ "$(cat "$replaced_path")" == "$sentinel_content" ]] || return 1
  else
    [[ "$(marker_value sentinel_type "$marker")" == directory ]] || return 1
    [[ -d "$replaced_path" && ! -L "$replaced_path" ]] || return 1
    [[ "$(inode_of "$replaced_path")" == "$sentinel_inode" ]] || return 1
    sentinel_path="$(marker_value sentinel_path "$marker")"
    [[ "$sentinel_path" == "$replaced_path/foreign-sentinel" ]] || return 1
    [[ -f "$sentinel_path" && ! -L "$sentinel_path" ]] || return 1
    [[ "$(inode_of "$sentinel_path")" == "$(marker_value sentinel_file_inode "$marker")" ]] ||
      return 1
    [[ "$(cat "$sentinel_path")" == "$sentinel_content" ]] || return 1
  fi
}

run_changed_release_state_case() {
  label="$1"
  release_role="$2"
  set_adapter_metadata "$label"
  prepare_fixture "changed release $label $release_role"

  case "$release_role" in
    lock-owner)
      expected_command=rm
      expected_count=1
      expected_path_pattern="$fixture/.research-repo-standard-adapter.lock/owner"
      expected_diagnostic='adapter lock owner changed during removal; retained for manual intervention'
      ;;
    lock-directory)
      expected_command=rmdir
      expected_count="$lock_directory_fault_count"
      expected_path_pattern="$fixture/.research-repo-standard-adapter.lock"
      expected_diagnostic='adapter lock changed during removal; retained for manual intervention'
      ;;
    guard)
      expected_command=rm
      expected_count=3
      expected_path_pattern="$fixture/.research-repo-standard-adapter.guard"
      expected_diagnostic='adapter acquisition guard changed during removal; retained for manual intervention'
      ;;
    claim-owner)
      expected_command=rm
      expected_count=2
      expected_path_pattern="$fixture/.research-repo-standard-adapter.claim.*/owner"
      expected_diagnostic='adapter claim owner changed during removal; retained for manual intervention'
      ;;
    claim-directory)
      expected_command=rmdir
      expected_count="$claim_directory_fault_count"
      expected_path_pattern="$fixture/.research-repo-standard-adapter.claim.*"
      expected_diagnostic='adapter claim directory changed during removal; retained for manual intervention'
      ;;
  esac

  output_file="$test_root/changed-release-$label-$release_role.out"
  pid_file="$test_root/changed-release-$label-$release_role.pid"
  marker="$test_root/changed-release-$label-$release_role.marker"
  rm_count="$test_root/changed-release-$label-$release_role.rm-count"
  rmdir_count="$test_root/changed-release-$label-$release_role.rmdir-count"
  link_count="$test_root/changed-release-$label-$release_role.link-count"
  link_marker="$test_root/changed-release-$label-$release_role.link-marker"
  mkdir_count="$test_root/changed-release-$label-$release_role.mkdir-count"
  mkdir_marker="$test_root/changed-release-$label-$release_role.mkdir-marker"
  status=0

  REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    REAL_LINK="$(command -v link)" \
    RELEASE_RM_COUNT_FILE="$rm_count" \
    RELEASE_RMDIR_COUNT_FILE="$rmdir_count" \
    RELEASE_LINK_COUNT_FILE="$link_count" \
    RELEASE_MKDIR_COUNT_FILE="$mkdir_count" \
    RELEASE_REPLACE_MARKER="$marker" \
    RELEASE_LINK_MARKER="$link_marker" \
    RELEASE_MKDIR_MARKER="$mkdir_marker" \
    FAULT_TARGET="$fixture" \
    REPLACE_ROLE="$release_role" \
    EXPECTED_REPLACE_COUNT="$expected_count" \
    PARTIAL_LINK_ROLE=none \
    PARTIAL_MKDIR_FAULT=none \
    PATH="$test_root/changed-release-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  held_guard_ok=0
  if [[ "$release_role" == guard ]]; then
    if [[ ! -e "$fixture/.research-repo-standard-adapter.lock" ]] &&
        ! find "$fixture" -mindepth 1 -maxdepth 1 \
          -name '.research-repo-standard-adapter.claim.*' -print -quit | grep -q .; then
      held_guard_ok=1
    fi
  else
    guard_path="$fixture/.research-repo-standard-adapter.guard"
    guard_inode_before="$(marker_value guard_inode_before "$marker")"
    guard_value_before="$(marker_value guard_value_before "$marker")"
    lock_state_ok=0
    case "$release_role" in
      claim-owner|claim-directory)
        [[ ! -e "$fixture/.research-repo-standard-adapter.lock" ]] && lock_state_ok=1
        ;;
      lock-owner|lock-directory)
        claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
          -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
        if [[ -f "$claim_owner" && ! -L "$claim_owner" &&
              "$(inode_of "$claim_owner")" == "$guard_inode_before" ]]; then
          lock_state_ok=1
        fi
        ;;
    esac
    if [[ -f "$guard_path" && ! -L "$guard_path" &&
          "$(inode_of "$guard_path")" == "$guard_inode_before" &&
          "$(cat "$guard_path")" == "$guard_value_before" &&
          "$guard_value_before" =~ ^$adapter_pid:$adapter_id:[0-9]+-[0-9]+-[0-9]+$ &&
          "$lock_state_ok" -eq 1 ]]; then
      held_guard_ok=1
    fi
  fi

  if [[ "$status" -eq 1 && "$held_guard_ok" -eq 1 ]] &&
      assert_changed_release_marker "$marker" "$release_role" "$expected_command" \
        "$expected_count" "$adapter_pid" "$expected_path_pattern" &&
      assert_outputs_valid "$fixture" "$host_profile_rel" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q . &&
      grep -Fq "cleanup incomplete: $expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label preserves foreign $release_role inode and reports changed release state"
  else
    fail "$label preserves foreign $release_role inode and reports changed release state"
  fi
}

run_changed_claim_directory_before_release_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "changed claim before release $label"

  output_file="$test_root/pre-release-claim-$label.out"
  pid_file="$test_root/pre-release-claim-$label.pid"
  mv_marker="$test_root/pre-release-claim-$label.mv-marker"
  pre_release_marker="$test_root/pre-release-claim-$label.marker"
  mv_count="$test_root/pre-release-claim-$label.mv-count"
  status=0
  case "$label" in
    claude) expected_destination="$fixture/CLAUDE.md" ;;
    codex) expected_destination="$fixture/.codex/agents/code-simplifier.toml" ;;
  esac

  MV_COUNT_FILE="$mv_count" \
    MV_FAULT_MARKER="$mv_marker" \
    FAIL_ON_MV_COUNT="$publish_count" \
    EXPECTED_MV_DESTINATION="$expected_destination" \
    EXPECTED_ADAPTER_PID='' \
    REAL_MV="$(command -v mv)" \
    REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    FAULT_TARGET="$fixture" \
    REPLACE_CLAIM_DIRECTORY_BEFORE_RELEASE=1 \
    PRE_RELEASE_MARKER="$pre_release_marker" \
    PATH="$test_root/fault-mv-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_directory="$(marker_value path "$pre_release_marker")"
  guard="$fixture/.research-repo-standard-adapter.guard"
  lock="$fixture/.research-repo-standard-adapter.lock"
  lock_owner="$lock/owner"
  sentinel="$claim_directory/foreign-sentinel"
  original_inode="$(marker_value original_inode "$pre_release_marker")"
  replacement_inode="$(marker_value replacement_inode "$pre_release_marker")"
  expected_diagnostic='adapter claim state changed; retained serialization for manual intervention'
  if [[ "$status" -eq 1 && "$(cat "$mv_count")" -eq "$publish_count" &&
        "$(marker_value count "$pre_release_marker")" -eq "$publish_count" &&
        "$(marker_value pid "$pre_release_marker")" == "$adapter_pid" &&
        "$claim_directory" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        "$original_inode" =~ ^[0-9]+$ && "$replacement_inode" =~ ^[0-9]+$ &&
        "$original_inode" != "$replacement_inode" &&
        "$(marker_value owner_rm_status "$pre_release_marker")" -eq 0 &&
        "$(marker_value directory_rmdir_status "$pre_release_marker")" -eq 0 &&
        "$(marker_value directory_after_rmdir "$pre_release_marker")" == absent &&
        "$(marker_value directory_mkdir_status "$pre_release_marker")" -eq 0 &&
        -d "$claim_directory" && ! -L "$claim_directory" &&
        "$(inode_of "$claim_directory")" == "$replacement_inode" &&
        -f "$sentinel" && "$(cat "$sentinel")" == 'foreign pre-release claim directory' &&
        -f "$guard" && -d "$lock" && ! -L "$lock" && -f "$lock_owner" &&
        "$(inode_of "$guard")" == "$(marker_value guard_inode "$pre_release_marker")" &&
        "$(inode_of "$lock")" == "$(marker_value lock_inode "$pre_release_marker")" &&
        "$(inode_of "$lock_owner")" == "$(marker_value lock_owner_inode "$pre_release_marker")" &&
        "$(inode_of "$guard")" == "$(inode_of "$lock_owner")" &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      grep -Fq "cleanup incomplete: $expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q .; then
    pass "$label validates claim-directory identity before dependent release"
  else
    fail "$label validates claim-directory identity before dependent release"
  fi
}

run_extra_claim_child_before_release_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "extra claim child before release $label"

  output_file="$test_root/pre-release-claim-child-$label.out"
  pid_file="$test_root/pre-release-claim-child-$label.pid"
  mv_marker="$test_root/pre-release-claim-child-$label.mv-marker"
  pre_release_marker="$test_root/pre-release-claim-child-$label.marker"
  mv_count="$test_root/pre-release-claim-child-$label.mv-count"
  status=0
  case "$label" in
    claude) expected_destination="$fixture/CLAUDE.md" ;;
    codex) expected_destination="$fixture/.codex/agents/code-simplifier.toml" ;;
  esac

  MV_COUNT_FILE="$mv_count" \
    MV_FAULT_MARKER="$mv_marker" \
    FAIL_ON_MV_COUNT="$publish_count" \
    EXPECTED_MV_DESTINATION="$expected_destination" \
    REAL_MV="$(command -v mv)" \
    FAULT_TARGET="$fixture" \
    ADD_CLAIM_CHILD_BEFORE_RELEASE=1 \
    PRE_RELEASE_MARKER="$pre_release_marker" \
    PATH="$test_root/fault-mv-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_directory="$(marker_value path "$pre_release_marker")"
  guard="$fixture/.research-repo-standard-adapter.guard"
  lock="$fixture/.research-repo-standard-adapter.lock"
  lock_owner="$lock/owner"
  claim_owner="$claim_directory/owner"
  extra_path="$(marker_value extra_path "$pre_release_marker")"
  expected_diagnostic='adapter claim state changed; retained serialization for manual intervention'
  if [[ "$status" -eq 1 && "$(cat "$mv_count")" -eq "$publish_count" &&
        "$(marker_value count "$pre_release_marker")" -eq "$publish_count" &&
        "$(marker_value pid "$pre_release_marker")" == "$adapter_pid" &&
        "$claim_directory" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        "$(marker_value claim_directory_inode "$pre_release_marker")" =~ ^[0-9]+$ &&
        "$(marker_value directory_inode_after "$pre_release_marker")" == \
          "$(marker_value claim_directory_inode "$pre_release_marker")" &&
        "$(marker_value extra_status "$pre_release_marker")" -eq 0 &&
        "$extra_path" == "$claim_directory/foreign-extra" &&
        -f "$extra_path" && ! -L "$extra_path" &&
        "$(inode_of "$extra_path")" == "$(marker_value extra_inode "$pre_release_marker")" &&
        "$(cat "$extra_path")" == 'foreign pre-release claim child' &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(inode_of "$claim_owner")" == \
          "$(marker_value claim_owner_inode "$pre_release_marker")" &&
        "$(find "$claim_directory" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" -eq 2 &&
        -f "$guard" && -d "$lock" && ! -L "$lock" && -f "$lock_owner" &&
        "$(inode_of "$guard")" == "$(marker_value guard_inode "$pre_release_marker")" &&
        "$(inode_of "$lock")" == "$(marker_value lock_inode "$pre_release_marker")" &&
        "$(inode_of "$lock_owner")" == "$(marker_value lock_owner_inode "$pre_release_marker")" &&
        "$(inode_of "$guard")" == "$(inode_of "$lock_owner")" &&
        "$(inode_of "$guard")" == "$(inode_of "$claim_owner")" &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      grep -Fq "cleanup incomplete: $expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q .; then
    pass "$label rejects an extra claim child before dependent release"
  else
    fail "$label rejects an extra claim child before dependent release"
  fi
}

run_acquisition_lock_child_case() {
  label="$1"
  extra_component="$2"
  set_adapter_metadata "$label"
  prepare_fixture "acquisition $extra_component child $label"

  outside_directory="$test_root/acquisition-$extra_component-child-outside-$label"
  mkdir "$outside_directory"
  outside_path="$outside_directory/sentinel"
  printf '%s\n' "outside acquisition $label sentinel" > "$outside_path"
  outside_inode="$(inode_of "$outside_path")"
  outside_checksum="$(file_checksum "$outside_path")"
  output_file="$test_root/acquisition-$extra_component-child-$label.out"
  pid_file="$test_root/acquisition-$extra_component-child-$label.pid"
  link_count="$test_root/acquisition-$extra_component-child-$label.link-count"
  mutation_marker="$test_root/acquisition-$extra_component-child-$label.marker"
  output_mkdir_count="$test_root/acquisition-$extra_component-child-$label.mkdir-count"
  output_mktemp_count="$test_root/acquisition-$extra_component-child-$label.mktemp-count"
  output_attempt_marker="$test_root/acquisition-$extra_component-child-$label.output-attempt"
  stage_attempt_marker="$test_root/acquisition-$extra_component-child-$label.stage-attempt"
  printf '%s\n' 0 > "$link_count"
  printf '%s\n' 0 > "$output_mkdir_count"
  printf '%s\n' 0 > "$output_mktemp_count"
  status=0

  REAL_LINK="$(command -v link)" \
    REAL_MKDIR="$(command -v mkdir)" \
    REAL_MKTEMP="$(command -v mktemp)" \
    ACQUISITION_LINK_COUNT_FILE="$link_count" \
    ACQUISITION_MUTATION_MARKER="$mutation_marker" \
    OUTPUT_MKDIR_COUNT_FILE="$output_mkdir_count" \
    OUTPUT_MKTEMP_COUNT_FILE="$output_mktemp_count" \
    OUTPUT_ATTEMPT_MARKER="$output_attempt_marker" \
    STAGE_ATTEMPT_MARKER="$stage_attempt_marker" \
    EXPECTED_ADAPTER_ID="$adapter_id" \
    ACQUISITION_EXTRA_COMPONENT="$extra_component" \
    FAULT_TARGET="$fixture" \
    PATH="$test_root/acquisition-lock-child-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_directory="$(marker_value claim_directory "$mutation_marker")"
  claim_owner="$claim_directory/owner"
  guard_path="$fixture/.research-repo-standard-adapter.guard"
  lock_directory="$fixture/.research-repo-standard-adapter.lock"
  lock_owner="$lock_directory/owner"
  case "$extra_component" in
    lock) extra_path="$lock_directory/foreign-extra" ;;
    claim) extra_path="$claim_directory/foreign-extra" ;;
  esac
  source_inode="$(marker_value source_inode "$mutation_marker")"
  source_checksum="$(marker_value source_checksum "$mutation_marker")"
  source_value="$(marker_value source_value "$mutation_marker")"
  source_byte_count="$(marker_value source_byte_count "$mutation_marker")"
  expected_token_prefix="$adapter_pid:$adapter_id:"
  token_nonce=${source_value#"$expected_token_prefix"}
  expected_lock_inventory="$lock_owner"
  expected_claim_inventory="$claim_owner"
  if [[ "$extra_component" == lock ]]; then
    expected_lock_inventory="$(printf '%s\n%s\n' "$extra_path" "$lock_owner" | LC_ALL=C sort)"
  else
    expected_claim_inventory="$(printf '%s\n%s\n' "$extra_path" "$claim_owner" | LC_ALL=C sort)"
  fi
  actual_lock_inventory="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null | \
    LC_ALL=C sort)"
  expected_top_inventory="$(printf '%s\n%s\n%s\n%s\n' "$fixture/AGENTS.md" \
    "$claim_directory" "$guard_path" "$lock_directory" | LC_ALL=C sort)"
  actual_top_inventory="$(find "$fixture" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort)"
  actual_claim_inventory="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null | \
    LC_ALL=C sort)"
  acquisition_child_inventory_ok=0
  if [[ "$extra_component" == lock &&
        "$(marker_value children_after_extra "$mutation_marker")" == foreign-extra,owner &&
        "$(marker_value claim_children_after_extra "$mutation_marker")" == owner ]]; then
    acquisition_child_inventory_ok=1
  elif [[ "$extra_component" == claim &&
          "$(marker_value children_after_extra "$mutation_marker")" == owner &&
          "$(marker_value claim_children_after_extra "$mutation_marker")" == foreign-extra,owner ]]; then
    acquisition_child_inventory_ok=1
  fi

  if [[ "$status" -eq 1 && "$(cat "$link_count")" -eq 2 &&
        "$(grep -c '^acquisition-owner-link-extra-child$' "$mutation_marker")" -eq 1 &&
        "$(marker_value extra_component "$mutation_marker")" == "$extra_component" &&
        "$(marker_value count "$mutation_marker")" -eq 2 &&
        "$(marker_value argument_count "$mutation_marker")" -eq 2 &&
        "$(marker_value pid "$mutation_marker")" == "$adapter_pid" &&
        "$(marker_value source "$mutation_marker")" == "$claim_owner" &&
        "$(marker_value destination "$mutation_marker")" == "$lock_owner" &&
        "$(marker_value real_status "$mutation_marker")" -eq 0 &&
        "$(marker_value effect "$mutation_marker")" == \
          real-owner-link-then-foreign-extra-child &&
        "$(marker_value return_status "$mutation_marker")" -eq 0 &&
        "$claim_directory" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        -d "$claim_directory" && ! -L "$claim_directory" &&
        "$(inode_of "$claim_directory")" == \
          "$(marker_value claim_directory_inode "$mutation_marker")" &&
        "$actual_claim_inventory" == "$expected_claim_inventory" &&
        -f "$claim_owner" && ! -L "$claim_owner" && "$source_inode" =~ ^[0-9]+$ &&
        "$(inode_of "$claim_owner")" == "$source_inode" &&
        "$(file_checksum "$claim_owner")" == "$source_checksum" &&
        "$(LC_ALL=C wc -c < "$claim_owner" | tr -d '[:space:]')" == \
          "$source_byte_count" &&
        "$(cat "$claim_owner")" == "$source_value" &&
        "$source_value" == "$expected_token_prefix$token_nonce" &&
        "$token_nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ &&
        -f "$guard_path" && ! -L "$guard_path" &&
        "$(marker_value guard "$mutation_marker")" == "$guard_path" &&
        "$(inode_of "$guard_path")" == "$source_inode" &&
        "$(marker_value guard_inode "$mutation_marker")" == "$source_inode" &&
        "$(file_checksum "$guard_path")" == "$source_checksum" &&
        "$(marker_value guard_checksum "$mutation_marker")" == "$source_checksum" &&
        -d "$lock_directory" && ! -L "$lock_directory" &&
        "$(marker_value lock "$mutation_marker")" == "$lock_directory" &&
        "$(marker_value lock_inode_before "$mutation_marker")" =~ ^[0-9]+$ &&
        "$(marker_value lock_inode_after_link "$mutation_marker")" == \
          "$(marker_value lock_inode_before "$mutation_marker")" &&
        "$(marker_value lock_inode_after_extra "$mutation_marker")" == \
          "$(marker_value lock_inode_before "$mutation_marker")" &&
        "$(inode_of "$lock_directory")" == \
          "$(marker_value lock_inode_before "$mutation_marker")" &&
        "$(marker_value children_before "$mutation_marker")" == '' &&
        "$(marker_value children_after_link "$mutation_marker")" == owner &&
        "$acquisition_child_inventory_ok" -eq 1 &&
        "$actual_lock_inventory" == "$expected_lock_inventory" &&
        -f "$lock_owner" && ! -L "$lock_owner" &&
        "$(inode_of "$lock_owner")" == "$source_inode" &&
        "$(marker_value owner_inode "$mutation_marker")" == "$source_inode" &&
        "$(file_checksum "$lock_owner")" == "$source_checksum" &&
        "$(marker_value owner_checksum "$mutation_marker")" == "$source_checksum" &&
        "$(LC_ALL=C wc -c < "$lock_owner" | tr -d '[:space:]')" == \
          "$source_byte_count" &&
        "$(cat "$lock_owner")" == "$source_value" &&
        -f "$extra_path" && ! -L "$extra_path" &&
        "$(marker_value extra_path "$mutation_marker")" == "$extra_path" &&
        "$(marker_value extra_status "$mutation_marker")" -eq 0 &&
        "$(inode_of "$extra_path")" == "$(marker_value extra_inode "$mutation_marker")" &&
        "$(file_checksum "$extra_path")" == "$(marker_value extra_checksum "$mutation_marker")" &&
        "$(cat "$extra_path")" == "foreign acquisition $extra_component child" &&
        "$(cat "$output_mkdir_count")" -eq 0 &&
        "$(cat "$output_mktemp_count")" -eq 0 &&
        ! -e "$output_attempt_marker" && ! -e "$stage_attempt_marker" &&
        "$actual_top_inventory" == "$expected_top_inventory" &&
        -f "$outside_path" && ! -L "$outside_path" &&
        "$(inode_of "$outside_path")" == "$outside_inode" &&
        "$(file_checksum "$outside_path")" == "$outside_checksum" &&
        "$(find "$outside_directory" -mindepth 1 -maxdepth 1 -print)" == "$outside_path" ]] &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q . &&
      grep -Fqx "$adapter_id: failed to verify adapter lock ownership" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label rejects an acquisition-time foreign $extra_component child before output creation"
  else
    fail "$label rejects an acquisition-time foreign $extra_component child before output creation"
  fi
}

run_extra_lock_child_before_release_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "extra lock child before release $label"

  output_file="$test_root/pre-release-lock-child-$label.out"
  pid_file="$test_root/pre-release-lock-child-$label.pid"
  mv_marker="$test_root/pre-release-lock-child-$label.mv-marker"
  pre_release_marker="$test_root/pre-release-lock-child-$label.marker"
  mv_count="$test_root/pre-release-lock-child-$label.mv-count"
  status=0
  case "$label" in
    claude)
      expected_destination="$fixture/CLAUDE.md"
      expected_source_pattern="$fixture/.CLAUDE.md.stage.??????/CLAUDE.md"
      expected_diagnostic='claude-code.sh: cleanup incomplete: adapter lock state changed; retained adapter lock for manual intervention'
      ;;
    codex)
      expected_destination="$fixture/.codex/agents/code-simplifier.toml"
      expected_source_pattern="$fixture/.codex/agents/.code-simplifier.toml.stage.??????"
      expected_diagnostic='codex.sh: cleanup incomplete: adapter lock state changed; retained adapter lock for manual intervention'
      ;;
  esac

  MV_COUNT_FILE="$mv_count" \
    MV_FAULT_MARKER="$mv_marker" \
    FAIL_ON_MV_COUNT="$publish_count" \
    EXPECTED_FINAL_PUBLISH_COUNT="$publish_count" \
    EXPECTED_FINAL_MV_SOURCE_PATTERN="$expected_source_pattern" \
    EXPECTED_MV_DESTINATION="$expected_destination" \
    EXPECTED_ADAPTER_ID="$adapter_id" \
    REAL_MV="$(command -v mv)" \
    FAULT_TARGET="$fixture" \
    ADD_LOCK_CHILD_BEFORE_RELEASE=1 \
    PRE_RELEASE_MARKER="$pre_release_marker" \
    PATH="$test_root/fault-mv-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  lock_directory="$fixture/.research-repo-standard-adapter.lock"
  lock_owner="$lock_directory/owner"
  extra_path="$lock_directory/foreign-extra"
  claim_directory="$(marker_value claim_directory "$pre_release_marker")"
  claim_owner="$claim_directory/owner"
  guard_path="$fixture/.research-repo-standard-adapter.guard"
  expected_lock_inventory="$(printf '%s\n%s\n' "$extra_path" "$lock_owner" | LC_ALL=C sort)"
  actual_lock_inventory="$(find "$lock_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null | \
    LC_ALL=C sort)"
  actual_claim_inventory="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null)"
  owner_inode_before="$(marker_value lock_owner_inode_before "$pre_release_marker")"
  owner_checksum_before="$(marker_value owner_checksum_before "$pre_release_marker")"
  owner_byte_count_before="$(marker_value owner_byte_count_before "$pre_release_marker")"
  owner_value="$(marker_value owner_value "$pre_release_marker")"
  owner_prefix="$adapter_pid:$adapter_id:"
  owner_nonce=${owner_value#"$owner_prefix"}
  lock_inode_before="$(marker_value lock_inode_before "$pre_release_marker")"

  if [[ "$status" -eq 1 && "$(cat "$mv_count")" -eq "$publish_count" &&
        "$(grep -c '^pre-release-lock-extra-child$' "$pre_release_marker")" -eq 1 &&
        "$(marker_value count "$pre_release_marker")" -eq "$publish_count" &&
        "$(marker_value argument_count "$pre_release_marker")" -eq 2 &&
        "$(marker_value pid "$pre_release_marker")" == "$adapter_pid" &&
        "$(marker_value source "$pre_release_marker")" == $expected_source_pattern &&
        "$(marker_value destination "$pre_release_marker")" == "$expected_destination" &&
        "$(marker_value source_inode "$pre_release_marker")" =~ ^[0-9]+$ &&
        "$(marker_value source_inode "$pre_release_marker")" == \
          "$(marker_value destination_inode "$pre_release_marker")" &&
        "$(marker_value real_status "$pre_release_marker")" -eq 0 &&
        "$(marker_value effect "$pre_release_marker")" == \
          foreign-extra-child-in-exact-lock-after-final-publication &&
        "$(marker_value return_status "$pre_release_marker")" -eq 1 &&
        "$(marker_value path "$pre_release_marker")" == "$lock_directory" &&
        "$lock_inode_before" =~ ^[0-9]+$ &&
        "$(marker_value lock_inode_after "$pre_release_marker")" == "$lock_inode_before" &&
        -d "$lock_directory" && ! -L "$lock_directory" &&
        "$(inode_of "$lock_directory")" == "$lock_inode_before" &&
        "$actual_lock_inventory" == "$expected_lock_inventory" &&
        "$(marker_value children_before "$pre_release_marker")" == owner &&
        "$(marker_value children_after "$pre_release_marker")" == foreign-extra,owner &&
        -f "$extra_path" && ! -L "$extra_path" &&
        "$(marker_value extra_path "$pre_release_marker")" == "$extra_path" &&
        "$(marker_value extra_status "$pre_release_marker")" -eq 0 &&
        "$(inode_of "$extra_path")" == "$(marker_value extra_inode "$pre_release_marker")" &&
        "$(file_checksum "$extra_path")" == "$(marker_value extra_checksum "$pre_release_marker")" &&
        "$(cat "$extra_path")" == 'foreign pre-release lock child' &&
        -f "$lock_owner" && ! -L "$lock_owner" && "$owner_inode_before" =~ ^[0-9]+$ &&
        "$(marker_value lock_owner "$pre_release_marker")" == "$lock_owner" &&
        "$(marker_value lock_owner_inode_after "$pre_release_marker")" == "$owner_inode_before" &&
        "$(inode_of "$lock_owner")" == "$owner_inode_before" &&
        "$(marker_value owner_byte_count_after "$pre_release_marker")" == \
          "$owner_byte_count_before" &&
        "$(LC_ALL=C wc -c < "$lock_owner" | tr -d '[:space:]')" == \
          "$owner_byte_count_before" &&
        "$(marker_value owner_checksum_after "$pre_release_marker")" == \
          "$owner_checksum_before" &&
        "$(marker_value adapter_id "$pre_release_marker")" == "$adapter_id" &&
        "$(file_checksum "$lock_owner")" == "$owner_checksum_before" &&
        "$(cat "$lock_owner")" == "$owner_value" &&
        "$owner_value" == "$owner_prefix$owner_nonce" &&
        "$owner_nonce" =~ ^[0-9]+-[0-9]+-[0-9]+$ &&
        "$(marker_value claim_directory_count "$pre_release_marker")" -eq 1 &&
        "$claim_directory" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        -d "$claim_directory" && ! -L "$claim_directory" &&
        "$(inode_of "$claim_directory")" == \
          "$(marker_value claim_directory_inode "$pre_release_marker")" &&
        "$actual_claim_inventory" == "$claim_owner" &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(marker_value claim_owner "$pre_release_marker")" == "$claim_owner" &&
        "$(inode_of "$claim_owner")" == "$owner_inode_before" &&
        "$(marker_value claim_owner_inode "$pre_release_marker")" == "$owner_inode_before" &&
        "$(file_checksum "$claim_owner")" == "$owner_checksum_before" &&
        "$(marker_value claim_owner_checksum_before "$pre_release_marker")" == \
          "$owner_checksum_before" &&
        -f "$guard_path" && ! -L "$guard_path" &&
        "$(marker_value guard "$pre_release_marker")" == "$guard_path" &&
        "$(inode_of "$guard_path")" == "$owner_inode_before" &&
        "$(marker_value guard_inode "$pre_release_marker")" == "$owner_inode_before" &&
        "$(file_checksum "$guard_path")" == "$owner_checksum_before" &&
        "$(marker_value guard_checksum_before "$pre_release_marker")" == \
          "$owner_checksum_before" &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      assert_mv_marker "$mv_marker" "$publish_count" "$adapter_pid" \
        "$expected_destination" "$expected_source_pattern" &&
      grep -Fqx "$expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q .; then
    pass "$label rejects a foreign extra child in the exact lock before release"
  else
    fail "$label rejects a foreign extra child in the exact lock before release"
  fi
}

assert_partial_link_marker() {
  partial_link_marker="$1"
  partial_link_expected_pid="$2"
  partial_link_target="$3"
  partial_link_role="$4"
  case "$partial_link_role" in
    guard)
      partial_link_expected_count=1
      partial_link_expected_destination="$partial_link_target/.research-repo-standard-adapter.guard"
      ;;
    owner | owner-missing-lock)
      partial_link_expected_count=2
      partial_link_expected_destination="$partial_link_target/.research-repo-standard-adapter.lock/owner"
      ;;
  esac
  [[ -f "$partial_link_marker" ]] || return 1
  [[ "$(marker_value role "$partial_link_marker")" == "$partial_link_role" ]] || return 1
  [[ "$(marker_value count "$partial_link_marker")" -eq "$partial_link_expected_count" ]] ||
    return 1
  [[ "$(marker_value argument_count "$partial_link_marker")" -eq 2 ]] || return 1
  [[ "$(marker_value pid "$partial_link_marker")" == "$partial_link_expected_pid" ]] ||
    return 1
  partial_link_source="$(marker_value source "$partial_link_marker")"
  [[ "$partial_link_source" == "$partial_link_target"/.research-repo-standard-adapter.claim.*/owner ]] ||
    return 1
  [[ "$(marker_value destination "$partial_link_marker")" == "$partial_link_expected_destination" ]] ||
    return 1
  [[ "$(marker_value source_inode "$partial_link_marker")" =~ ^[0-9]+$ ]] || return 1
  [[ "$(marker_value effect "$partial_link_marker")" == pre ]] || return 1
  [[ "$(marker_value return_status "$partial_link_marker")" -eq 72 ]] || return 1
  if [[ "$partial_link_role" == owner-missing-lock ]]; then
    [[ "$(marker_value lock_path "$partial_link_marker")" == \
      "$partial_link_target/.research-repo-standard-adapter.lock" ]] || return 1
    [[ "$(marker_value lock_inode "$partial_link_marker")" =~ ^[0-9]+$ ]] || return 1
    [[ "$(marker_value lock_rmdir_status "$partial_link_marker")" -eq 0 ]] || return 1
    [[ "$(marker_value lock_after "$partial_link_marker")" == absent ]] || return 1
  fi
}

assert_partial_mkdir_marker() {
  partial_mkdir_marker="$1"
  partial_mkdir_expected_pid="$2"
  partial_mkdir_target="$3"
  [[ -f "$partial_mkdir_marker" ]] || return 1
  [[ "$(marker_value role "$partial_mkdir_marker")" == lock ]] || return 1
  [[ "$(marker_value count "$partial_mkdir_marker")" -eq 2 ]] || return 1
  [[ "$(marker_value path "$partial_mkdir_marker")" == "$partial_mkdir_target/.research-repo-standard-adapter.lock" ]] ||
    return 1
  [[ "$(marker_value pid "$partial_mkdir_marker")" == "$partial_mkdir_expected_pid" ]] ||
    return 1
  [[ "$(marker_value effect "$partial_mkdir_marker")" == pre ]] || return 1
  [[ "$(marker_value return_status "$partial_mkdir_marker")" -eq 71 ]] || return 1
}

run_partial_changed_state_case() {
  label="$1"
  partial_role="$2"
  set_adapter_metadata "$label"
  prepare_fixture "partial release $label $partial_role"

  case "$partial_role" in
    partial-claim-owner)
      expected_command=rm
      expected_count=1
      expected_path_pattern="$fixture/.research-repo-standard-adapter.claim.*/owner"
      expected_diagnostic='adapter claim owner changed during removal; retained for manual intervention'
      link_fault_role=guard
      mkdir_fault_role=none
      ;;
    partial-claim-directory)
      expected_command=rmdir
      expected_count=1
      expected_path_pattern="$fixture/.research-repo-standard-adapter.claim.*"
      expected_diagnostic='adapter claim directory changed during removal; retained for manual intervention'
      link_fault_role=guard
      mkdir_fault_role=none
      ;;
    partial-lock-directory)
      expected_command=rmdir
      expected_count=1
      expected_path_pattern="$fixture/.research-repo-standard-adapter.lock"
      expected_diagnostic='adapter lock changed during removal; retained for manual intervention'
      link_fault_role=owner
      mkdir_fault_role=none
      ;;
    partial-guard)
      expected_command=rm
      expected_count=2
      expected_path_pattern="$fixture/.research-repo-standard-adapter.guard"
      expected_diagnostic='adapter acquisition guard changed during removal; retained for manual intervention'
      link_fault_role=none
      mkdir_fault_role=lock
      ;;
  esac

  output_file="$test_root/partial-release-$label-$partial_role.out"
  pid_file="$test_root/partial-release-$label-$partial_role.pid"
  marker="$test_root/partial-release-$label-$partial_role.marker"
  rm_count="$test_root/partial-release-$label-$partial_role.rm-count"
  rmdir_count="$test_root/partial-release-$label-$partial_role.rmdir-count"
  link_count="$test_root/partial-release-$label-$partial_role.link-count"
  link_marker="$test_root/partial-release-$label-$partial_role.link-marker"
  mkdir_count="$test_root/partial-release-$label-$partial_role.mkdir-count"
  mkdir_marker="$test_root/partial-release-$label-$partial_role.mkdir-marker"
  status=0

  REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    REAL_LINK="$(command -v link)" \
    RELEASE_RM_COUNT_FILE="$rm_count" \
    RELEASE_RMDIR_COUNT_FILE="$rmdir_count" \
    RELEASE_LINK_COUNT_FILE="$link_count" \
    RELEASE_MKDIR_COUNT_FILE="$mkdir_count" \
    RELEASE_REPLACE_MARKER="$marker" \
    RELEASE_LINK_MARKER="$link_marker" \
    RELEASE_MKDIR_MARKER="$mkdir_marker" \
    FAULT_TARGET="$fixture" \
    REPLACE_ROLE="$partial_role" \
    EXPECTED_REPLACE_COUNT="$expected_count" \
    PARTIAL_LINK_ROLE="$link_fault_role" \
    PARTIAL_MKDIR_FAULT="$mkdir_fault_role" \
    PATH="$test_root/changed-release-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_count="$(find "$fixture" -mindepth 1 -maxdepth 1 \
    -name '.research-repo-standard-adapter.claim.*' | wc -l | tr -d '[:space:]')"
  acquisition_marker_ok=0
  if [[ "$link_fault_role" != none ]]; then
    assert_partial_link_marker "$link_marker" "$adapter_pid" "$fixture" \
      "$link_fault_role" && acquisition_marker_ok=1
  else
    assert_partial_mkdir_marker "$mkdir_marker" "$adapter_pid" "$fixture" &&
      acquisition_marker_ok=1
  fi

  retained_ok=0
  replaced_path="$(marker_value path "$marker")"
  case "$partial_role" in
    partial-claim-owner)
      parent_inode_before="$(marker_value parent_inode_before "$marker")"
      if [[ "$claim_count" -eq 1 &&
            -d "$(dirname "$replaced_path")" &&
            "$(inode_of "$(dirname "$replaced_path")")" == "$parent_inode_before" &&
            ! -e "$fixture/.research-repo-standard-adapter.guard" &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" ]]; then
        retained_ok=1
      fi
      ;;
    partial-claim-directory)
      if [[ "$claim_count" -eq 1 &&
            ! -e "$fixture/.research-repo-standard-adapter.guard" &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" ]]; then
        retained_ok=1
      fi
      ;;
    partial-lock-directory)
      guard_path="$fixture/.research-repo-standard-adapter.guard"
      claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
        -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
      guard_inode_before="$(marker_value guard_inode_before "$marker")"
      guard_value_before="$(marker_value guard_value_before "$marker")"
      if [[ "$claim_count" -eq 1 &&
            -f "$guard_path" && ! -L "$guard_path" &&
            -f "$claim_owner" && ! -L "$claim_owner" &&
            "$(inode_of "$guard_path")" == "$guard_inode_before" &&
            "$(inode_of "$claim_owner")" == "$guard_inode_before" &&
            "$(cat "$guard_path")" == "$guard_value_before" &&
            "$guard_value_before" =~ ^$adapter_pid:$adapter_id:[0-9]+-[0-9]+-[0-9]+$ ]]; then
        retained_ok=1
      fi
      ;;
    partial-guard)
      if [[ "$claim_count" -eq 0 &&
            ! -e "$fixture/.research-repo-standard-adapter.lock" ]]; then
        retained_ok=1
      fi
      ;;
  esac

  if [[ "$status" -eq 1 && "$acquisition_marker_ok" -eq 1 &&
        "$retained_ok" -eq 1 &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      assert_changed_release_marker "$marker" "$partial_role" "$expected_command" "$expected_count" \
        "$adapter_pid" "$expected_path_pattern" &&
      grep -Fq "cleanup incomplete: $expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q .; then
    pass "$label partial release preserves foreign $partial_role inode with precise diagnostic"
  else
    fail "$label partial release preserves foreign $partial_role inode with precise diagnostic"
  fi
}

run_partial_extra_claim_child_case() {
  label="$1"
  link_fault_role="$2"
  set_adapter_metadata "$label"
  prepare_fixture "partial extra claim child $label $link_fault_role"

  output_file="$test_root/partial-extra-claim-child-$label-$link_fault_role.out"
  pid_file="$test_root/partial-extra-claim-child-$label-$link_fault_role.pid"
  link_marker="$test_root/partial-extra-claim-child-$label-$link_fault_role.link-marker"
  link_count="$test_root/partial-extra-claim-child-$label-$link_fault_role.link-count"
  mkdir_count="$test_root/partial-extra-claim-child-$label-$link_fault_role.mkdir-count"
  status=0

  REAL_LINK="$(command -v link)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    RELEASE_LINK_COUNT_FILE="$link_count" \
    RELEASE_LINK_MARKER="$link_marker" \
    RELEASE_MKDIR_COUNT_FILE="$mkdir_count" \
    FAULT_TARGET="$fixture" \
    PARTIAL_LINK_ROLE="$link_fault_role" \
    PARTIAL_MKDIR_FAULT=none \
    ADD_CLAIM_CHILD_ON_LINK_FAILURE=1 \
    PATH="$test_root/changed-release-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  claim_directory="$(marker_value claim_directory "$link_marker")"
  claim_owner="$(marker_value source "$link_marker")"
  extra_path="$(marker_value extra_path "$link_marker")"
  guard="$fixture/.research-repo-standard-adapter.guard"
  lock="$fixture/.research-repo-standard-adapter.lock"
  child_count="$(find "$claim_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null | wc -l | tr -d '[:space:]')"
  serialization_ok=0
  if [[ "$link_fault_role" == guard ]]; then
    if [[ ! -e "$guard" && ! -L "$guard" && ! -e "$lock" && ! -L "$lock" ]]; then
      serialization_ok=1
    fi
  elif [[ -f "$guard" && ! -L "$guard" &&
          "$(inode_of "$guard")" == "$(marker_value guard_inode "$link_marker")" &&
          -d "$lock" && ! -L "$lock" &&
          "$(inode_of "$lock")" == "$(marker_value lock_inode "$link_marker")" &&
          -z "$(find "$lock" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
    serialization_ok=1
  fi

  if [[ "$status" -eq 1 && "$serialization_ok" -eq 1 &&
        "$claim_directory" == "$fixture"/.research-repo-standard-adapter.claim.* &&
        -d "$claim_directory" && ! -L "$claim_directory" &&
        "$(inode_of "$claim_directory")" == "$(marker_value claim_directory_inode "$link_marker")" &&
        "$claim_owner" == "$claim_directory/owner" &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(inode_of "$claim_owner")" == "$(marker_value claim_owner_inode "$link_marker")" &&
        "$(file_checksum "$claim_owner")" == "$(marker_value claim_owner_checksum "$link_marker")" &&
        "$extra_path" == "$claim_directory/foreign-extra" &&
        -f "$extra_path" && ! -L "$extra_path" &&
        "$(inode_of "$extra_path")" == "$(marker_value extra_inode "$link_marker")" &&
        "$(cat "$extra_path")" == 'foreign partial-release claim child' &&
        "$(marker_value extra_status "$link_marker")" -eq 0 && "$child_count" -eq 2 &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      assert_partial_link_marker "$link_marker" "$adapter_pid" "$fixture" "$link_fault_role" &&
      grep -Fq 'cleanup incomplete: adapter claim state changed; retained serialization for manual intervention' \
        "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label preserves partial claim state with extra child after $link_fault_role-link failure"
  else
    fail "$label preserves partial claim state with extra child after $link_fault_role-link failure"
  fi
}

run_partial_missing_lock_case() {
  label="$1"
  set_adapter_metadata "$label"
  prepare_fixture "partial release $label missing lock"

  output_file="$test_root/partial-release-$label-missing-lock.out"
  pid_file="$test_root/partial-release-$label-missing-lock.pid"
  link_marker="$test_root/partial-release-$label-missing-lock.link-marker"
  link_count="$test_root/partial-release-$label-missing-lock.link-count"
  mkdir_count="$test_root/partial-release-$label-missing-lock.mkdir-count"
  status=0

  REAL_LINK="$(command -v link)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    RELEASE_LINK_COUNT_FILE="$link_count" \
    RELEASE_LINK_MARKER="$link_marker" \
    RELEASE_MKDIR_COUNT_FILE="$mkdir_count" \
    FAULT_TARGET="$fixture" \
    PARTIAL_LINK_ROLE=owner-missing-lock \
    PARTIAL_MKDIR_FAULT=none \
    PATH="$test_root/changed-release-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  guard_path="$fixture/.research-repo-standard-adapter.guard"
  claim_owner="$(find "$fixture" -mindepth 2 -maxdepth 2 \
    -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
  source_inode="$(marker_value source_inode "$link_marker")"
  if [[ "$status" -eq 1 && "$(cat "$link_count")" -eq 2 &&
        ! -e "$fixture/.research-repo-standard-adapter.lock" &&
        ! -L "$fixture/.research-repo-standard-adapter.lock" &&
        -f "$guard_path" && ! -L "$guard_path" &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(inode_of "$guard_path")" == "$source_inode" &&
        "$(inode_of "$claim_owner")" == "$source_inode" &&
        "$(cat "$guard_path")" =~ ^$adapter_pid:$adapter_id:[0-9]+-[0-9]+-[0-9]+$ &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      assert_partial_link_marker "$link_marker" "$adapter_pid" "$fixture" \
        owner-missing-lock &&
      grep -Fq 'cleanup incomplete: adapter lock changed before removal;' "$output_file" &&
      ! grep -q '^installed ' "$output_file" &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q .; then
    pass "$label partial release treats a missing owned lock as changed serialization"
  else
    fail "$label partial release treats a missing owned lock as changed serialization"
  fi
}

run_invalid_owner_token_case() {
  label="$1"
  token_case="$2"
  invalid_token="$3"
  set_adapter_metadata "$label"
  prepare_fixture "invalid token $label $token_case"

  lock_path="$fixture/.research-repo-standard-adapter.lock"
  owner_path="$lock_path/owner"
  mkdir "$lock_path"
  if [[ "$token_case" == missing-final-newline ]]; then
    printf '%s' "$invalid_token" > "$owner_path"
  else
    printf '%s\n' "$invalid_token" > "$owner_path"
  fi
  lock_inode="$(inode_of "$lock_path")"
  owner_inode="$(inode_of "$owner_path")"
  owner_checksum="$(file_checksum "$owner_path")"
  output_file="$test_root/invalid-token-$label-$token_case.out"
  status=0
  "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  if [[ "$status" -eq 1 &&
        -d "$lock_path" && ! -L "$lock_path" &&
        "$(inode_of "$lock_path")" == "$lock_inode" &&
        -f "$owner_path" && ! -L "$owner_path" &&
        "$(inode_of "$owner_path")" == "$owner_inode" &&
        "$(file_checksum "$owner_path")" == "$owner_checksum" &&
        "$(cat "$owner_path")" == "$invalid_token" &&
        ! -e "$fixture/.research-repo-standard-adapter.guard" &&
        ! -L "$fixture/.research-repo-standard-adapter.guard" &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      ! find "$fixture" -mindepth 1 -maxdepth 1 \
        -name '.research-repo-standard-adapter.claim.*' -print -quit | grep -q . &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q . &&
      grep -Fq 'adapter lock requires manual intervention' "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label rejects and preserves invalid owner token: $token_case"
  else
    fail "$label rejects and preserves invalid owner token: $token_case"
  fi
}

run_invalid_owner_token_matrix() {
  label="$1"
  set_adapter_metadata "$label"
  valid_pid=$$
  valid_nonce='1-2-3'
  for token_case in \
    empty-token numeric-only missing-pid zero-pid leading-zero-pid negative-pid \
    plus-pid alpha-pid empty-adapter arbitrary-adapter missing-nonce-delimiter \
    empty-nonce too-few-nonce-fields too-many-nonce-fields empty-nonce-1 \
    empty-nonce-2 empty-nonce-3 alpha-nonce-1 alpha-nonce-2 alpha-nonce-3 \
    negative-nonce-1 negative-nonce-2 negative-nonce-3 plus-nonce-1 \
    plus-nonce-2 plus-nonce-3 extra-colon prefix-space suffix-space second-line \
    missing-final-newline; do
    case "$token_case" in
      empty-token) invalid_token='' ;;
      numeric-only) invalid_token="$valid_pid" ;;
      missing-pid) invalid_token=":$adapter_id:$valid_nonce" ;;
      zero-pid) invalid_token="0:$adapter_id:$valid_nonce" ;;
      leading-zero-pid) invalid_token="0$valid_pid:$adapter_id:$valid_nonce" ;;
      negative-pid) invalid_token="-1:$adapter_id:$valid_nonce" ;;
      plus-pid) invalid_token="+1:$adapter_id:$valid_nonce" ;;
      alpha-pid) invalid_token="pid:$adapter_id:$valid_nonce" ;;
      empty-adapter) invalid_token="$valid_pid::$valid_nonce" ;;
      arbitrary-adapter) invalid_token="$valid_pid:other.sh:$valid_nonce" ;;
      missing-nonce-delimiter) invalid_token="$valid_pid:$adapter_id" ;;
      empty-nonce) invalid_token="$valid_pid:$adapter_id:" ;;
      too-few-nonce-fields) invalid_token="$valid_pid:$adapter_id:1-2" ;;
      too-many-nonce-fields) invalid_token="$valid_pid:$adapter_id:1-2-3-4" ;;
      empty-nonce-1) invalid_token="$valid_pid:$adapter_id:-2-3" ;;
      empty-nonce-2) invalid_token="$valid_pid:$adapter_id:1--3" ;;
      empty-nonce-3) invalid_token="$valid_pid:$adapter_id:1-2-" ;;
      alpha-nonce-1) invalid_token="$valid_pid:$adapter_id:x-2-3" ;;
      alpha-nonce-2) invalid_token="$valid_pid:$adapter_id:1-x-3" ;;
      alpha-nonce-3) invalid_token="$valid_pid:$adapter_id:1-2-x" ;;
      negative-nonce-1) invalid_token="$valid_pid:$adapter_id:-1-2-3" ;;
      negative-nonce-2) invalid_token="$valid_pid:$adapter_id:1--2-3" ;;
      negative-nonce-3) invalid_token="$valid_pid:$adapter_id:1-2--3" ;;
      plus-nonce-1) invalid_token="$valid_pid:$adapter_id:+1-2-3" ;;
      plus-nonce-2) invalid_token="$valid_pid:$adapter_id:1-+2-3" ;;
      plus-nonce-3) invalid_token="$valid_pid:$adapter_id:1-2-+3" ;;
      extra-colon) invalid_token="$valid_pid:$adapter_id:$valid_nonce:extra" ;;
      prefix-space) invalid_token=" $valid_pid:$adapter_id:$valid_nonce" ;;
      suffix-space) invalid_token="$valid_pid:$adapter_id:$valid_nonce " ;;
      second-line) invalid_token="$valid_pid:$adapter_id:$valid_nonce
trailing" ;;
      missing-final-newline) invalid_token="$valid_pid:$adapter_id:$valid_nonce" ;;
    esac
    run_invalid_owner_token_case "$label" "$token_case" "$invalid_token"
  done
}

run_guard_only_owner_case() {
  label="$1"
  owner_state="$2"
  set_adapter_metadata "$label"
  prepare_fixture "guard only $label $owner_state"

  case "$owner_state" in
    live)
      owner_pid=$$
      ;;
    dead)
      (exit 0) &
      owner_pid=$!
      wait "$owner_pid"
      ;;
  esac
  owner_token="$owner_pid:$adapter_id:0-0-0"
  guard_path="$fixture/.research-repo-standard-adapter.guard"
  printf '%s\n' "$owner_token" > "$guard_path"
  guard_inode="$(inode_of "$guard_path")"
  guard_checksum="$(file_checksum "$guard_path")"
  outside_path="$test_root/guard-only-outside-$label-$owner_state"
  printf '%s\n' "outside $label $owner_state sentinel" > "$outside_path"
  outside_inode="$(inode_of "$outside_path")"
  outside_checksum="$(file_checksum "$outside_path")"
  output_file="$test_root/guard-only-$label-$owner_state.out"
  status=0
  "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  case "$owner_state" in
    live)
      expected_diagnostic="adapter installation already in progress: $owner_token"
      ;;
    dead)
      expected_diagnostic='adapter acquisition guard requires manual intervention'
      ;;
  esac

  if [[ "$status" -eq 1 &&
        -f "$guard_path" && ! -L "$guard_path" &&
        "$(inode_of "$guard_path")" == "$guard_inode" &&
        "$(file_checksum "$guard_path")" == "$guard_checksum" &&
        "$(cat "$guard_path")" == "$owner_token" &&
        -f "$outside_path" && ! -L "$outside_path" &&
        "$(inode_of "$outside_path")" == "$outside_inode" &&
        "$(file_checksum "$outside_path")" == "$outside_checksum" &&
        ! -e "$fixture/.research-repo-standard-adapter.lock" &&
        ! -L "$fixture/.research-repo-standard-adapter.lock" &&
        ! -e "$fixture/agents" && ! -e "$fixture/.claude" &&
        ! -e "$fixture/.codex" && ! -e "$fixture/CLAUDE.md" ]] &&
      ! find "$fixture" -mindepth 1 -maxdepth 1 \
        -name '.research-repo-standard-adapter.claim.*' -print -quit | grep -q . &&
      ! find "$fixture" -name '*.stage.*' -print -quit | grep -q . &&
      grep -Fq "$expected_diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label preserves exact $owner_state guard-only owner without outside writes"
  else
    fail "$label preserves exact $owner_state guard-only owner without outside writes"
  fi
}

run_codex_cross_category_aggregation_case() {
  set_adapter_metadata codex
  prepare_fixture 'cross category aggregation codex'
  mkdir -p "$fixture/agents"
  cp "$SOURCE_PROFILE" "$fixture/agents/code-simplifier.md"
  canonical_inode="$(inode_of "$fixture/agents/code-simplifier.md")"
  canonical_checksum="$(file_checksum "$fixture/agents/code-simplifier.md")"

  output_file="$test_root/codex-cross-category.out"
  pid_file="$test_root/codex-cross-category.pid"
  mv_marker="$test_root/codex-cross-category.mv-marker"
  cleanup_marker="$test_root/codex-cross-category.cleanup-marker"
  mv_count="$test_root/codex-cross-category.mv-count"
  rm_count="$test_root/codex-cross-category.rm-count"
  rmdir_count="$test_root/codex-cross-category.rmdir-count"
  : > "$cleanup_marker"
  status=0

  REAL_MV="$(command -v mv)" \
    MV_COUNT_FILE="$mv_count" \
    FAIL_ON_MV_COUNT=1 \
    MV_FAULT_MARKER="$mv_marker" \
    EXPECTED_MV_DESTINATION="$fixture/.codex/agents/code-simplifier.toml" \
    REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    CLEANUP_RM_COUNT="$rm_count" \
    CLEANUP_RMDIR_COUNT="$rmdir_count" \
    FAULT_TARGET="$fixture" \
    FAULT_MARKER="$cleanup_marker" \
    FAULT_ROLE=multi \
    FAULT_EFFECT=pre \
    EXPECTED_FAULT_COUNT=0 \
    FAULT_PATH='' \
    MULTI_OUTPUT_PATH="$fixture/.codex/agents/code-simplifier.toml" \
    MULTI_OUTPUT_COUNT=1 \
    MULTI_STAGE_COUNT=2 \
    PATH="$test_root/fault-mv-bin:$test_root/cleanup-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  stage_path="$(sed -n '/^role=stage$/{n;n;n;s/^path=//p;}' "$cleanup_marker")"
  output_path="$(sed -n '/^role=output$/{n;n;n;s/^path=//p;}' "$cleanup_marker")"
  stage_inode="$(sed -n '/^role=stage$/{n;n;n;n;s/^inode_before=//p;}' "$cleanup_marker")"
  output_inode="$(sed -n '/^role=output$/{n;n;n;n;s/^inode_before=//p;}' "$cleanup_marker")"
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
        "$(grep -c '^count=2$' "$cleanup_marker")" -eq 1 &&
        "$output_path" == "$fixture/.codex/agents/code-simplifier.toml" &&
        "$stage_path" == "$fixture"/agents/.code-simplifier.md.stage.* &&
        "$stage_inode" =~ ^[0-9]+$ && "$output_inode" =~ ^[0-9]+$ ]]; then
    markers_ok=1
  fi

  retained_ok=0
  if [[ -f "$output_path" && ! -L "$output_path" &&
        "$(inode_of "$output_path")" == "$output_inode" &&
        -f "$stage_path" && ! -L "$stage_path" &&
        "$(inode_of "$stage_path")" == "$stage_inode" &&
        -f "$guard" && ! -L "$guard" &&
        -f "$lock_owner" && ! -L "$lock_owner" &&
        -f "$claim_owner" && ! -L "$claim_owner" &&
        "$(inode_of "$guard")" == "$(inode_of "$lock_owner")" &&
        "$(inode_of "$guard")" == "$(inode_of "$claim_owner")" &&
        "$(cat "$guard")" =~ ^$adapter_pid:codex.sh:[0-9]+-[0-9]+-[0-9]+$ &&
        "$(inode_of "$fixture/agents/code-simplifier.md")" == "$canonical_inode" &&
        "$(file_checksum "$fixture/agents/code-simplifier.md")" == "$canonical_checksum" ]]; then
    retained_ok=1
  fi

  if [[ "$status" -eq 1 && "$markers_ok" -eq 1 && "$retained_ok" -eq 1 &&
        "$(cat "$mv_count")" -eq 1 &&
        "$(cat "$rm_count")" -eq 2 &&
        "$(cat "$rmdir_count")" -eq 2 ]] &&
      assert_mv_marker "$mv_marker" 1 "$adapter_pid" \
        "$fixture/.codex/agents/code-simplifier.toml" \
        "$fixture/.codex/agents/.code-simplifier.toml.stage.*" &&
      grep -Fq "cleanup incomplete: unable to remove owned output: $output_path" \
        "$output_file" &&
      grep -Fq "cleanup incomplete: unable to remove stage: $stage_path" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass 'codex cleanup aggregates output and stage failures before retaining serialization'
  else
    fail 'codex cleanup aggregates output and stage failures before retaining serialization'
  fi
}

create_pre_release_state_wrappers() {
  mkdir -p "$test_root/pre-release-state-bin"

  cat > "$test_root/pre-release-state-bin/mutate-state" <<'WRAPPER'
#!/usr/bin/env bash
set -u

inode() { ls -di "$1" 2> /dev/null | awk '{ print $1 }'; }
checksum() { LC_ALL=C cksum < "$1" 2> /dev/null | awk '{ print $1 ":" $2 }'; }
exists() { [[ -e "$1" || -L "$1" ]]; }

claim_directory="$(find "$FAULT_TARGET" -mindepth 1 -maxdepth 1 \
  -type d -name '.research-repo-standard-adapter.claim.*' -print -quit)"
claim_owner="$claim_directory/owner"
guard="$FAULT_TARGET/.research-repo-standard-adapter.guard"
lock="$FAULT_TARGET/.research-repo-standard-adapter.lock"
lock_owner="$lock/owner"

claim_directory_inode="$(inode "$claim_directory")"
claim_owner_inode="$(inode "$claim_owner")"
claim_owner_checksum=''
[[ -f "$claim_owner" && ! -L "$claim_owner" ]] && claim_owner_checksum="$(checksum "$claim_owner")"
guard_inode="$(inode "$guard")"
guard_checksum=''
[[ -f "$guard" && ! -L "$guard" ]] && guard_checksum="$(checksum "$guard")"
lock_inode="$(inode "$lock")"
lock_owner_inode="$(inode "$lock_owner")"
lock_owner_checksum=''
[[ -f "$lock_owner" && ! -L "$lock_owner" ]] && lock_owner_checksum="$(checksum "$lock_owner")"

case "$MATRIX_COMPONENT" in
  claim-owner) mutation_path="$claim_owner"; mutation_kind=file ;;
  claim-directory) mutation_path="$claim_directory"; mutation_kind=directory ;;
  guard) mutation_path="$guard"; mutation_kind=file ;;
  lock-owner) mutation_path="$lock_owner"; mutation_kind=file ;;
  lock-directory) mutation_path="$lock"; mutation_kind=directory ;;
  *) exit 91 ;;
esac
original_inode="$(inode "$mutation_path")"
[[ "$original_inode" =~ ^[0-9]+$ ]] || exit 91

child_remove_status=not-run
remove_status=not-run
mkdir_status=not-run
if [[ "$mutation_kind" == directory ]]; then
  child_path="$mutation_path/owner"
  if exists "$child_path"; then
    "$REAL_RM" "$child_path"
    child_remove_status=$?
  fi
  "$REAL_RMDIR" "$mutation_path"
  remove_status=$?
else
  "$REAL_RM" "$mutation_path"
  remove_status=$?
fi
if [[ "$remove_status" -ne 0 ]] || exists "$mutation_path"; then
  exit 92
fi

sentinel_path=''
sentinel_inode=''
sentinel_checksum=''
replacement_inode=''
after=absent
if [[ "$MATRIX_MUTATION" == different ]]; then
  if [[ "$mutation_kind" == directory ]]; then
    "$REAL_MKDIR" "$mutation_path"
    mkdir_status=$?
    sentinel_path="$mutation_path/foreign-sentinel"
  else
    sentinel_path="$mutation_path"
    mkdir_status=not-needed
  fi
  printf 'foreign %s %s sentinel\n' "$MATRIX_MODE" "$MATRIX_COMPONENT" > "$sentinel_path"
  sentinel_inode="$(inode "$sentinel_path")"
  sentinel_checksum="$(checksum "$sentinel_path")"
  replacement_inode="$(inode "$mutation_path")"
  after=different
elif [[ "$MATRIX_MUTATION" != missing ]]; then
  exit 91
fi

{
  printf '%s\n' 'pre-release-state-mutation'
  printf 'mode=%s\n' "$MATRIX_MODE"
  printf 'component=%s\n' "$MATRIX_COMPONENT"
  printf 'mutation=%s\n' "$MATRIX_MUTATION"
  printf 'path=%s\n' "$mutation_path"
  printf 'kind=%s\n' "$mutation_kind"
  printf 'original_inode=%s\n' "$original_inode"
  printf 'after=%s\n' "$after"
  printf 'replacement_inode=%s\n' "$replacement_inode"
  printf 'sentinel_path=%s\n' "$sentinel_path"
  printf 'sentinel_inode=%s\n' "$sentinel_inode"
  printf 'sentinel_checksum=%s\n' "$sentinel_checksum"
  printf 'child_remove_status=%s\n' "$child_remove_status"
  printf 'remove_status=%s\n' "$remove_status"
  printf 'mkdir_status=%s\n' "$mkdir_status"
  printf 'claim_directory=%s\n' "$claim_directory"
  printf 'claim_directory_inode=%s\n' "$claim_directory_inode"
  printf 'claim_owner=%s\n' "$claim_owner"
  printf 'claim_owner_inode=%s\n' "$claim_owner_inode"
  printf 'claim_owner_checksum=%s\n' "$claim_owner_checksum"
  printf 'guard=%s\n' "$guard"
  printf 'guard_inode=%s\n' "$guard_inode"
  printf 'guard_checksum=%s\n' "$guard_checksum"
  printf 'lock=%s\n' "$lock"
  printf 'lock_inode=%s\n' "$lock_inode"
  printf 'lock_owner=%s\n' "$lock_owner"
  printf 'lock_owner_inode=%s\n' "$lock_owner_inode"
  printf 'lock_owner_checksum=%s\n' "$lock_owner_checksum"
  printf 'adapter_pid=%s\n' "$EXPECTED_ADAPTER_PID"
  printf '%s\n' 'effect=before-first-release-removal'
} > "$MATRIX_MARKER"

if [[ "$MATRIX_MUTATION" == different ]]; then
  [[ "$replacement_inode" =~ ^[0-9]+$ && "$sentinel_inode" =~ ^[0-9]+$ ]] || exit 91
  [[ "$replacement_inode" != "$original_inode" ]] || exit 91
fi
exit 0
WRAPPER

  cat > "$test_root/pre-release-state-bin/link" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
[[ ! -f "$MATRIX_LINK_COUNT_FILE" ]] || count="$(cat "$MATRIX_LINK_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MATRIX_LINK_COUNT_FILE"
argument_count=$#
source_path="${1:-}"
destination_path="${2:-}"
if [[ "$MATRIX_LINK_FAULT_COUNT" -eq 0 || "$count" -ne "$MATRIX_LINK_FAULT_COUNT" ]]; then
  exec "$REAL_LINK" "$@"
fi
expected_source_path="$(find "$FAULT_TARGET" -mindepth 2 -maxdepth 2 \
  -path '*/.research-repo-standard-adapter.claim.*/owner' -print -quit)"
[[ "$argument_count" -eq 2 && "$PPID" == "$EXPECTED_ADAPTER_PID" &&
  -n "$expected_source_path" && "$source_path" == "$expected_source_path" &&
  "$destination_path" == "$MATRIX_EXPECTED_DESTINATION" ]] || exit 91
"$MATRIX_MUTATOR"
mutation_status=$?
return_status=72
{
  printf '%s\n' 'fault_command=link'
  printf 'command_count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'source=%s\n' "$source_path"
  printf 'destination=%s\n' "$destination_path"
  printf '%s\n' 'real_status=not-run'
  printf 'mutation_status=%s\n' "$mutation_status"
  printf 'wrapper_ppid=%s\n' "$PPID"
  printf 'return_status=%s\n' "$return_status"
} >> "$MATRIX_MARKER"
[[ "$mutation_status" -eq 0 ]] || exit 91
exit "$return_status"
WRAPPER

  cat > "$test_root/pre-release-state-bin/mv" <<'WRAPPER'
#!/usr/bin/env bash
set -u
count=0
[[ ! -f "$MATRIX_MV_COUNT_FILE" ]] || count="$(cat "$MATRIX_MV_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MATRIX_MV_COUNT_FILE"
argument_count=$#
source_path="${1:-}"
destination_path="${2:-}"
if [[ "$count" -ne "$MATRIX_FINAL_MV_COUNT" ]]; then
  exec "$REAL_MV" "$@"
fi
source_nonce="${source_path#"$MATRIX_EXPECTED_SOURCE_PREFIX"}"
if [[ -n "$MATRIX_EXPECTED_SOURCE_SUFFIX" ]]; then
  source_nonce="${source_nonce%"$MATRIX_EXPECTED_SOURCE_SUFFIX"}"
fi
[[ "$argument_count" -eq 2 && "$PPID" == "$EXPECTED_ADAPTER_PID" &&
  "$source_path" == "$MATRIX_EXPECTED_SOURCE_PREFIX$source_nonce$MATRIX_EXPECTED_SOURCE_SUFFIX" &&
  "${#source_nonce}" -eq 6 && "$source_nonce" != */* &&
  "$destination_path" == "$MATRIX_EXPECTED_DESTINATION" ]] || exit 91
source_inode="$(ls -di "$source_path" 2> /dev/null | awk '{ print $1 }')"
"$REAL_MV" "$@"
real_status=$?
destination_inode="$(ls -di "$destination_path" 2> /dev/null | awk '{ print $1 }')"
"$MATRIX_MUTATOR"
mutation_status=$?
return_status=1
{
  printf '%s\n' 'fault_command=mv'
  printf 'command_count=%s\n' "$count"
  printf 'argument_count=%s\n' "$argument_count"
  printf 'source=%s\n' "$source_path"
  printf 'source_nonce=%s\n' "$source_nonce"
  printf 'destination=%s\n' "$destination_path"
  printf 'source_inode=%s\n' "$source_inode"
  printf 'destination_inode=%s\n' "$destination_inode"
  printf 'real_status=%s\n' "$real_status"
  printf 'mutation_status=%s\n' "$mutation_status"
  printf 'wrapper_ppid=%s\n' "$PPID"
  printf 'return_status=%s\n' "$return_status"
} >> "$MATRIX_MARKER"
[[ "$mutation_status" -eq 0 && "$real_status" -eq 0 &&
  "$source_inode" == "$destination_inode" ]] || exit 91
exit "$return_status"
WRAPPER

  chmod +x "$test_root/pre-release-state-bin/mutate-state" \
    "$test_root/pre-release-state-bin/link" "$test_root/pre-release-state-bin/mv"
}

assert_no_generated_state() {
  target="$1"
  [[ ! -e "$target/agents" && ! -L "$target/agents" ]] &&
    [[ ! -e "$target/.claude" && ! -L "$target/.claude" ]] &&
    [[ ! -e "$target/.codex" && ! -L "$target/.codex" ]] &&
    [[ ! -e "$target/CLAUDE.md" && ! -L "$target/CLAUDE.md" ]] &&
    ! find "$target" -name '*.stage.*' -print -quit | grep -q .
}

run_pre_release_state_case() {
  label="$1"
  mode="$2"
  component="$3"
  mutation="$4"
  set_adapter_metadata "$label"
  prepare_fixture "pre release state $label $mode $component $mutation"

  marker="$test_root/pre-release-state-$label-$mode-$component-$mutation.marker"
  output_file="$test_root/pre-release-state-$label-$mode-$component-$mutation.out"
  pid_file="$test_root/pre-release-state-$label-$mode-$component-$mutation.pid"
  link_count_file="$test_root/pre-release-state-$label-$mode-$component-$mutation.link-count"
  mv_count_file="$test_root/pre-release-state-$label-$mode-$component-$mutation.mv-count"
  case "$mode" in
    full)
      link_fault_count=0
      expected_destination="$fixture/$final_publish_rel"
      if [[ "$label" == claude ]]; then
        expected_source_prefix="$fixture/.CLAUDE.md.stage."
        expected_source_suffix=/CLAUDE.md
      else
        expected_source_prefix="$fixture/.codex/agents/.code-simplifier.toml.stage."
        expected_source_suffix=""
      fi
      ;;
    no-guard)
      link_fault_count=1
      expected_destination="$fixture/.research-repo-standard-adapter.guard"
      expected_source_prefix=""
      expected_source_suffix=""
      ;;
    partial-lock)
      link_fault_count=2
      expected_destination="$fixture/.research-repo-standard-adapter.lock/owner"
      expected_source_prefix=""
      expected_source_suffix=""
      ;;
  esac
  status=0
  REAL_LINK="$(command -v link)" \
    REAL_MV="$(command -v mv)" \
    REAL_RM="$(command -v rm)" \
    REAL_RMDIR="$(command -v rmdir)" \
    REAL_MKDIR="$(command -v mkdir)" \
    MATRIX_MUTATOR="$test_root/pre-release-state-bin/mutate-state" \
    MATRIX_MARKER="$marker" \
    MATRIX_LINK_COUNT_FILE="$link_count_file" \
    MATRIX_MV_COUNT_FILE="$mv_count_file" \
    MATRIX_LINK_FAULT_COUNT="$link_fault_count" \
    MATRIX_FINAL_MV_COUNT="$publish_count" \
    MATRIX_EXPECTED_SOURCE_PREFIX="$expected_source_prefix" \
    MATRIX_EXPECTED_SOURCE_SUFFIX="$expected_source_suffix" \
    MATRIX_EXPECTED_DESTINATION="$expected_destination" \
    MATRIX_MODE="$mode" \
    MATRIX_COMPONENT="$component" \
    MATRIX_MUTATION="$mutation" \
    FAULT_TARGET="$fixture" \
    PATH="$test_root/pre-release-state-bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$1"; export EXPECTED_ADAPTER_PID="$$"; exec "$2" "$3"' \
      bash "$pid_file" "$adapter" "$fixture" > "$output_file" 2>&1 || status=$?

  adapter_pid="$(cat "$pid_file")"
  mutation_path="$(marker_value path "$marker")"
  original_inode="$(marker_value original_inode "$marker")"
  claim_directory="$(marker_value claim_directory "$marker")"
  claim_owner="$(marker_value claim_owner "$marker")"
  guard="$(marker_value guard "$marker")"
  lock="$(marker_value lock "$marker")"
  lock_owner="$(marker_value lock_owner "$marker")"
  recorded_source="$(marker_value source "$marker")"
  recorded_source_nonce="${recorded_source#"$expected_source_prefix"}"
  if [[ -n "$expected_source_suffix" ]]; then
    recorded_source_nonce="${recorded_source_nonce%"$expected_source_suffix"}"
  fi

  marker_ok=0
  if [[ "$(grep -c '^pre-release-state-mutation$' "$marker" 2> /dev/null)" -eq 1 &&
        "$(marker_value mode "$marker")" == "$mode" &&
        "$(marker_value component "$marker")" == "$component" &&
        "$(marker_value mutation "$marker")" == "$mutation" &&
        "$original_inode" =~ ^[0-9]+$ &&
        "$(marker_value adapter_pid "$marker")" == "$adapter_pid" &&
        "$(marker_value wrapper_ppid "$marker")" == "$adapter_pid" &&
        "$(marker_value argument_count "$marker")" -eq 2 &&
        "$(marker_value mutation_status "$marker")" -eq 0 &&
        "$(marker_value effect "$marker")" == before-first-release-removal ]]; then
    if [[ "$mode" == full && "$(marker_value fault_command "$marker")" == mv &&
          "$(marker_value command_count "$marker")" -eq "$publish_count" &&
          "$recorded_source" == \
            "$expected_source_prefix$recorded_source_nonce$expected_source_suffix" &&
          "${#recorded_source_nonce}" -eq 6 && "$recorded_source_nonce" != */* &&
          "$(marker_value source_nonce "$marker")" == "$recorded_source_nonce" &&
          "$(marker_value destination "$marker")" == "$expected_destination" &&
          "$(marker_value real_status "$marker")" -eq 0 &&
          "$(marker_value return_status "$marker")" -eq 1 &&
          "$(marker_value source_inode "$marker")" == \
            "$(marker_value destination_inode "$marker")" ]]; then
      marker_ok=1
    elif [[ "$mode" != full && "$(marker_value fault_command "$marker")" == link &&
            "$(marker_value command_count "$marker")" -eq "$link_fault_count" &&
            "$(marker_value source "$marker")" == "$claim_owner" &&
            "$(marker_value destination "$marker")" == "$expected_destination" &&
            "$(marker_value real_status "$marker")" == not-run &&
            "$(marker_value return_status "$marker")" -eq 72 ]]; then
      marker_ok=1
    fi
  fi

  mutation_ok=0
  if [[ "$mutation" == missing && ! -e "$mutation_path" && ! -L "$mutation_path" &&
        "$(marker_value after "$marker")" == absent ]]; then
    mutation_ok=1
  elif [[ "$mutation" == different && "$(marker_value after "$marker")" == different &&
          "$(marker_value replacement_inode "$marker")" =~ ^[0-9]+$ &&
          "$(marker_value replacement_inode "$marker")" != "$original_inode" ]]; then
    sentinel_path="$(marker_value sentinel_path "$marker")"
    if [[ -f "$sentinel_path" && ! -L "$sentinel_path" &&
          "$(inode_of "$sentinel_path")" == "$(marker_value sentinel_inode "$marker")" &&
          "$(file_checksum "$sentinel_path")" == "$(marker_value sentinel_checksum "$marker")" ]]; then
      mutation_ok=1
    fi
  fi

  remaining_ok=1
  if [[ "$component" != claim-directory ]]; then
    [[ -d "$claim_directory" && ! -L "$claim_directory" &&
      "$(inode_of "$claim_directory")" == "$(marker_value claim_directory_inode "$marker")" ]] ||
      remaining_ok=0
  fi
  if [[ "$component" != claim-directory && "$component" != claim-owner ]]; then
    [[ -f "$claim_owner" && ! -L "$claim_owner" &&
      "$(inode_of "$claim_owner")" == "$(marker_value claim_owner_inode "$marker")" &&
      "$(file_checksum "$claim_owner")" == "$(marker_value claim_owner_checksum "$marker")" ]] ||
      remaining_ok=0
  fi
  if [[ "$mode" != no-guard && "$component" != guard ]]; then
    [[ -f "$guard" && ! -L "$guard" &&
      "$(inode_of "$guard")" == "$(marker_value guard_inode "$marker")" &&
      "$(file_checksum "$guard")" == "$(marker_value guard_checksum "$marker")" ]] ||
      remaining_ok=0
  elif [[ "$mode" == no-guard ]]; then
    [[ ! -e "$guard" && ! -L "$guard" ]] || remaining_ok=0
  fi
  if [[ "$mode" != no-guard && "$component" != lock-directory ]]; then
    [[ -d "$lock" && ! -L "$lock" &&
      "$(inode_of "$lock")" == "$(marker_value lock_inode "$marker")" ]] || remaining_ok=0
  elif [[ "$mode" == no-guard ]]; then
    [[ ! -e "$lock" && ! -L "$lock" ]] || remaining_ok=0
  fi
  if [[ "$mode" == full && "$component" != lock-directory && "$component" != lock-owner ]]; then
    [[ -f "$lock_owner" && ! -L "$lock_owner" &&
      "$(inode_of "$lock_owner")" == "$(marker_value lock_owner_inode "$marker")" &&
      "$(file_checksum "$lock_owner")" == "$(marker_value lock_owner_checksum "$marker")" ]] ||
      remaining_ok=0
  elif [[ "$mode" != full ]]; then
    [[ ! -e "$lock_owner" && ! -L "$lock_owner" ]] || remaining_ok=0
  fi

  diagnostic='adapter claim state changed; retained serialization for manual intervention'
  case "$component" in
    guard) diagnostic='adapter acquisition guard changed; retained serialization for manual intervention' ;;
    lock-owner) diagnostic='adapter lock owner changed; retained adapter lock for manual intervention' ;;
    lock-directory)
      if [[ "$mode" == full ]]; then
        if [[ "$label" == claude ]]; then
          diagnostic='adapter lock changed; retained serialization for manual intervention'
        else
          diagnostic='adapter lock state changed; retained adapter lock for manual intervention'
        fi
      elif [[ "$mutation" == missing ]]; then
        if [[ "$label" == claude ]]; then
          diagnostic='adapter lock changed before removal; retained for manual intervention'
        else
          diagnostic='adapter lock changed before removal; retained serialization for manual intervention'
        fi
      else
        if [[ "$label" == claude ]]; then
          diagnostic='adapter lock changed before removal; retained for manual intervention'
        else
          diagnostic='adapter lock state changed; retained adapter lock for manual intervention'
        fi
      fi
      ;;
  esac

  if [[ "$status" -eq 1 && "$marker_ok" -eq 1 && "$mutation_ok" -eq 1 &&
        "$remaining_ok" -eq 1 ]] &&
      assert_no_generated_state "$fixture" &&
      grep -Fq "cleanup incomplete: $diagnostic" "$output_file" &&
      ! grep -q '^installed ' "$output_file"; then
    pass "$label $mode $component $mutation is detected before dependent release"
  else
    fail "$label $mode $component $mutation is detected before dependent release"
  fi
}

create_claim_mkdir_wrappers
create_claim_wc_wrapper
create_cleanup_wrappers
create_mv_wrapper
create_stage_creation_wrappers
create_acquisition_lock_child_wrappers
create_changed_release_wrappers
create_pre_release_state_wrappers

for adapter_label in claude codex; do
  run_acquisition_lock_child_case "$adapter_label" lock
  run_acquisition_lock_child_case "$adapter_label" claim
done

for adapter_label in claude codex; do
  run_pre_effect_claim_mkdir_case "$adapter_label"
  run_claim_file_collision_case "$adapter_label"
  run_exact_token_claim_file_collision_case "$adapter_label"
  run_claim_file_transition_case "$adapter_label"
done

for adapter_label in claude codex; do
  set_adapter_metadata "$adapter_label"
  run_release_cleanup_case "$adapter_label" lock-owner pre 1 1 \
    "$pre_lock_owner_rmdir_total"
  run_release_cleanup_case "$adapter_label" lock-directory pre \
    "$lock_directory_fault_count" 1 "$lock_directory_fault_count"
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

for adapter_label in claude codex; do
  run_pre_mktemp_stage_creation_case "$adapter_label" canonical-file
  run_pre_mktemp_stage_creation_case "$adapter_label" host-file
  run_mktemp_stage_creation_transition_case "$adapter_label" canonical-file
  run_mktemp_stage_creation_transition_case "$adapter_label" host-file
done
run_pre_mktemp_stage_creation_case claude alias-directory
run_mktemp_stage_creation_transition_case claude alias-directory
run_pre_alias_link_creation_case
run_alias_link_creation_transition_case

for adapter_label in claude codex; do
  run_changed_release_state_case "$adapter_label" lock-owner
  run_changed_release_state_case "$adapter_label" lock-directory
  run_changed_release_state_case "$adapter_label" guard
  run_changed_release_state_case "$adapter_label" claim-owner
  run_changed_release_state_case "$adapter_label" claim-directory
  run_changed_claim_directory_before_release_case "$adapter_label"
  run_extra_claim_child_before_release_case "$adapter_label"
  run_extra_lock_child_before_release_case "$adapter_label"
done
for adapter_label in claude codex; do
  run_partial_changed_state_case "$adapter_label" partial-claim-owner
  run_partial_changed_state_case "$adapter_label" partial-claim-directory
  run_partial_changed_state_case "$adapter_label" partial-lock-directory
  run_partial_changed_state_case "$adapter_label" partial-guard
  run_partial_missing_lock_case "$adapter_label"
  run_partial_extra_claim_child_case "$adapter_label" guard
  run_partial_extra_claim_child_case "$adapter_label" owner
done

for adapter_label in claude codex; do
  for mutation in missing different; do
    for component in lock-owner lock-directory guard claim-owner claim-directory; do
      run_pre_release_state_case "$adapter_label" full "$component" "$mutation"
    done
    for component in claim-owner claim-directory; do
      run_pre_release_state_case "$adapter_label" no-guard "$component" "$mutation"
    done
    for component in guard lock-directory claim-owner claim-directory; do
      run_pre_release_state_case "$adapter_label" partial-lock "$component" "$mutation"
    done
  done
done

run_invalid_owner_token_matrix claude
run_invalid_owner_token_matrix codex

for adapter_label in claude codex; do
  run_guard_only_owner_case "$adapter_label" live
  run_guard_only_owner_case "$adapter_label" dead
done

run_codex_cross_category_aggregation_case

if [[ "$failures" -ne 0 ]]; then
  printf '%s adapter finalization test(s) failed\n' "$failures" >&2
  exit 1
fi

printf '%s\n' 'All adapter finalization tests passed'
