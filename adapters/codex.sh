#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script_name="$(basename "$0")"
adapter_id=codex.sh

fail() {
  printf '%s: %s\n' "$script_name" "$1" >&2
  exit 1
}

usage() {
  echo "usage: $script_name <target-repo>" >&2
  exit 2
}

check_output_parent() {
  local directory=$1
  if [[ -L "$directory" ]]; then
    fail "refusing symlinked output parent ${directory#"$TARGET"/}"
  fi
  if [[ -e "$directory" && ! -d "$directory" ]]; then
    fail "output parent is not a directory: ${directory#"$TARGET"/}"
  fi
}

verify_physical_parent() {
  local directory=$1
  local physical_directory
  physical_directory="$(cd "$directory" && pwd -P)" ||
    fail "cannot resolve output parent ${directory#"$TARGET"/}"
  case "$physical_directory" in
    "$TARGET" | "$TARGET"/*) ;;
    *) fail "output parent escapes canonical target: ${directory#"$TARGET"/}" ;;
  esac
  if [[ "$physical_directory" != "$directory" ]]; then
    fail "output parent is not physically contained as declared: ${directory#"$TARGET"/}"
  fi
}

check_expected_file() {
  local expected_file=$1
  local destination_file=$2
  if [[ -L "$destination_file" ]]; then
    fail "refusing to replace customized ${destination_file#"$TARGET"/}: generated profile is a symlink"
  fi
  if [[ -e "$destination_file" ]] &&
    { [[ ! -f "$destination_file" ]] || ! cmp -s "$expected_file" "$destination_file"; }; then
    fail "refusing to replace customized ${destination_file#"$TARGET"/}"
  fi
}

path_is_absent() {
  [[ ! -e "$1" && ! -L "$1" ]]
}

inode_of() {
  LC_ALL=C ls -di "$1" | awk '{ print $1 }'
}

read_exact_token_file() {
  local path=$1
  local byte_count
  exact_token_value=""
  if [[ ! -f "$path" || -L "$path" ]] ||
    ! IFS= read -r exact_token_value < "$path"; then
    return 1
  fi
  byte_count=""
  if byte_count="$(LC_ALL=C wc -c < "$path")"; then
    :
  else
    # Filesystem evidence, not an injected post-effect command status, decides
    # whether a creation transition owns this exact token file.
    :
  fi
  byte_count=${byte_count//[[:space:]]/}
  [[ "$byte_count" =~ ^[0-9]+$ ]] || return 1
  ((byte_count == ${#exact_token_value} + 1))
}

token_is_valid() {
  [[ "$1" =~ ^([1-9][0-9]*):(claude-code\.sh|codex\.sh):[0-9]+-[0-9]+-[0-9]+$ ]]
}

handle_signal() {
  local status=$1
  if ((creation_transition)); then
    if ((pending_signal_status == 0)); then
      pending_signal_status=$status
    fi
    return
  fi
  exit "$status"
}

finish_creation_transition() {
  local signal_status
  creation_transition=0
  signal_status=$pending_signal_status
  if ((signal_status)); then
    exit "$signal_status"
  fi
}

create_owned_directory() {
  local path=$1
  local inode_variable=$2
  local command_status=0
  local observed_inode=""
  path_is_absent "$path" || return 1
  creation_transition=1
  if mkdir "$path" 2> /dev/null; then
    command_status=0
  else
    command_status=$?
  fi
  if [[ -d "$path" && ! -L "$path" ]]; then
    observed_inode="$(inode_of "$path" 2> /dev/null)" || observed_inode=""
  fi
  if [[ -n "$observed_inode" ]]; then
    printf -v "$inode_variable" '%s' "$observed_inode"
  fi
  finish_creation_transition
  ((command_status == 0)) && [[ -n "$observed_inode" ]]
}

create_temporary_file() {
  local template=$1
  local path_variable=$2
  local inode_variable=$3
  local command_status=0
  local observed_path=""
  local observed_inode=""
  local expected_prefix=${template%XXXXXX}
  creation_transition=1
  if observed_path="$(mktemp "$template")"; then
    command_status=0
  else
    command_status=$?
  fi
  if [[ "$observed_path" == "$expected_prefix"?????? ]] &&
    [[ -f "$observed_path" && ! -L "$observed_path" ]]; then
    observed_inode="$(inode_of "$observed_path" 2> /dev/null)" || observed_inode=""
  fi
  if [[ -n "$observed_inode" ]]; then
    printf -v "$path_variable" '%s' "$observed_path"
    printf -v "$inode_variable" '%s' "$observed_inode"
  fi
  finish_creation_transition
  ((command_status == 0)) && [[ -n "$observed_inode" ]]
}

create_claim_file() {
  local command_status=0
  local observed_inode=""
  local observed_value=""
  path_is_absent "$claim_file" || return 1
  creation_transition=1
  set -C
  if printf '%s\n' "$lock_token" > "$claim_file"; then
    command_status=0
  else
    command_status=$?
  fi
  set +C
  if read_exact_token_file "$claim_file"; then
    observed_value=$exact_token_value
    observed_inode="$(inode_of "$claim_file" 2> /dev/null)" || observed_inode=""
  fi
  if ((command_status == 0)) &&
    [[ -n "$observed_inode" && "$observed_value" == "$lock_token" ]]; then
    claim_file_inode=$observed_inode
  fi
  finish_creation_transition
  ((command_status == 0)) && [[ -n "$claim_file_inode" ]]
}

link_claim_to() {
  local destination=$1
  local inode_variable=$2
  local command_status=0
  local observed_inode=""
  path_is_absent "$destination" || return 1
  creation_transition=1
  if link "$claim_file" "$destination" 2> /dev/null; then
    command_status=0
  else
    command_status=$?
  fi
  if read_exact_token_file "$destination"; then
    observed_inode="$(inode_of "$destination" 2> /dev/null)" || observed_inode=""
    if [[ "$observed_inode" != "$claim_file_inode" || "$exact_token_value" != "$lock_token" ]]; then
      observed_inode=""
    fi
  fi
  if [[ -n "$observed_inode" ]]; then
    printf -v "$inode_variable" '%s' "$observed_inode"
  fi
  finish_creation_transition
  ((command_status == 0)) && [[ -n "$observed_inode" ]]
}

inspect_existing_lock() {
  local existing_token
  local existing_pid
  if [[ -L "$adapter_lock" || ! -d "$adapter_lock" ]] ||
    ! read_exact_token_file "$adapter_lock_owner"; then
    fail "adapter lock requires manual intervention"
  fi
  existing_token=$exact_token_value
  if ! token_is_valid "$existing_token"; then
    fail "adapter lock requires manual intervention"
  fi
  existing_pid=${BASH_REMATCH[1]}
  if kill -0 "$existing_pid" 2> /dev/null; then
    fail "adapter installation already in progress: $existing_token"
  fi
  fail "adapter lock requires manual intervention"
}

inspect_existing_guard() {
  local existing_token
  local existing_pid
  if ! read_exact_token_file "$adapter_guard"; then
    fail "adapter acquisition guard requires manual intervention"
  fi
  existing_token=$exact_token_value
  if ! token_is_valid "$existing_token"; then
    fail "adapter acquisition guard requires manual intervention"
  fi
  existing_pid=${BASH_REMATCH[1]}
  if kill -0 "$existing_pid" 2> /dev/null; then
    fail "adapter installation already in progress: $existing_token"
  fi
  fail "adapter acquisition guard requires manual intervention"
}

verify_owned_regular() {
  local path=$1
  local expected_inode=$2
  local expected_value=$3
  local current_inode
  read_exact_token_file "$path" || return 1
  [[ "$exact_token_value" == "$expected_value" ]] || return 1
  current_inode="$(inode_of "$path" 2> /dev/null)" || return 1
  [[ "$current_inode" == "$expected_inode" ]]
}

verify_owned_directory() {
  local path=$1
  local expected_inode=$2
  local current_inode
  [[ -d "$path" && ! -L "$path" ]] || return 1
  current_inode="$(inode_of "$path" 2> /dev/null)" || return 1
  [[ "$current_inode" == "$expected_inode" ]]
}

acquire_adapter_lock() {
  if ! path_is_absent "$claim_directory"; then
    fail "adapter acquisition claim requires manual intervention"
  fi
  if ! create_owned_directory "$claim_directory" claim_directory_inode; then
    fail "failed to create exclusive adapter claim"
  fi
  if ! create_claim_file; then
    fail "failed to create adapter claim owner"
  fi

  if ! path_is_absent "$adapter_guard"; then
    if ! path_is_absent "$adapter_lock"; then
      inspect_existing_lock
    fi
    inspect_existing_guard
  fi
  if ! link_claim_to "$adapter_guard" adapter_guard_inode; then
    if [[ -n "$adapter_guard_inode" ]]; then
      fail "failed to finalize adapter acquisition guard"
    fi
    if ! path_is_absent "$adapter_guard"; then
      if ! path_is_absent "$adapter_lock"; then
        inspect_existing_lock
      fi
      inspect_existing_guard
    fi
    fail "adapter hard-link operation is unsupported"
  fi

  if ! path_is_absent "$adapter_lock"; then
    inspect_existing_lock
  fi
  if ! create_owned_directory "$adapter_lock" adapter_lock_inode; then
    fail "failed to create adapter lock"
  fi
  if ! link_claim_to "$adapter_lock_owner" adapter_lock_owner_inode; then
    if [[ -n "$adapter_lock_owner_inode" ]]; then
      fail "failed to finalize adapter lock owner"
    fi
    fail "adapter hard-link operation is unsupported"
  fi
  if ! lock_directory_is_exact ||
    ! verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token" ||
    ! verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token" ||
    ! verify_owned_regular "$adapter_lock_owner" "$adapter_lock_owner_inode" "$lock_token" ||
    ! claim_directory_is_exact; then
    fail "failed to verify adapter lock ownership"
  fi
}

mark_cleanup_error() {
  cleanup_failed=1
  printf '%s: cleanup incomplete: %s\n' "$script_name" "$1" >&2
}

remove_owned_artifact() {
  local path=$1
  local expected_inode=$2
  local label=$3
  local current_inode
  [[ -n "$expected_inode" ]] || return 0
  path_is_absent "$path" && return 0
  current_inode="$(inode_of "$path" 2> /dev/null)" || return 0
  [[ "$current_inode" == "$expected_inode" ]] || return 0
  rm "$path" 2> /dev/null
  path_is_absent "$path" && return 0
  current_inode="$(inode_of "$path" 2> /dev/null)" || return 0
  [[ "$current_inode" != "$expected_inode" ]] && return 0
  mark_cleanup_error "unable to remove $label: $path"
  return 1
}

remove_owned_parent() {
  local path=$1
  local expected_inode=$2
  local current_inode
  [[ -n "$expected_inode" ]] || return 0
  path_is_absent "$path" && return 0
  verify_owned_directory "$path" "$expected_inode" || return 0
  rmdir "$path" 2> /dev/null
  path_is_absent "$path" && return 0
  current_inode="$(inode_of "$path" 2> /dev/null)" || return 0
  [[ "$current_inode" != "$expected_inode" ]] && return 0
  if [[ -n "$(find "$path" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
    return 0
  fi
  mark_cleanup_error "unable to remove output parent: $path"
  return 1
}

remove_claim_without_guard() {
  if [[ -n "$claim_file_inode" ]]; then
    if ! verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token"; then
      mark_cleanup_error "adapter claim owner changed before removal; retained for manual intervention"
      return 1
    fi
    rm "$claim_file" 2> /dev/null
    if ! path_is_absent "$claim_file"; then
      if verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token"; then
        mark_cleanup_error "unable to remove adapter claim owner: $claim_file"
      else
        mark_cleanup_error "adapter claim owner changed during removal; retained for manual intervention"
      fi
      return 1
    fi
  fi
  if [[ -n "$claim_directory_inode" ]]; then
    if ! verify_owned_directory "$claim_directory" "$claim_directory_inode" ||
      [[ -n "$(find "$claim_directory" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
      mark_cleanup_error "adapter claim directory changed before removal; retained for manual intervention"
      return 1
    fi
    rmdir "$claim_directory" 2> /dev/null
    if ! path_is_absent "$claim_directory"; then
      if verify_owned_directory "$claim_directory" "$claim_directory_inode" &&
        [[ -z "$(find "$claim_directory" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
        mark_cleanup_error "unable to remove adapter claim directory: $claim_directory"
      else
        mark_cleanup_error "adapter claim directory changed during removal; retained for manual intervention"
      fi
      return 1
    fi
  fi
  return 0
}

claim_directory_is_exact() {
  verify_owned_directory "$claim_directory" "$claim_directory_inode" &&
    [[ "$(find "$claim_directory" -mindepth 1 -maxdepth 1 -print 2> /dev/null)" == \
      "$claim_file" ]]
}

claim_state_is_exact_for_release() {
  if [[ -z "$claim_directory_inode" ]]; then
    [[ -z "$claim_file_inode" ]]
    return
  fi
  verify_owned_directory "$claim_directory" "$claim_directory_inode" || return 1
  if [[ -n "$claim_file_inode" ]]; then
    claim_directory_is_exact &&
      verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token"
  else
    [[ -z "$(find "$claim_directory" -mindepth 1 -print -quit 2> /dev/null)" ]]
  fi
}

lock_directory_is_exact() {
  lock_directory_identity_is_exact &&
    [[ "$(find "$adapter_lock" -mindepth 1 -maxdepth 1 -print 2> /dev/null)" == \
      "$adapter_lock_owner" ]]
}

lock_directory_identity_is_exact() {
  verify_owned_directory "$adapter_lock" "$adapter_lock_inode"
}

restore_lock_owner() {
  local restored_inode=""
  if path_is_absent "$adapter_lock_owner"; then
    link "$adapter_guard" "$adapter_lock_owner" 2> /dev/null || true
  fi
  if read_exact_token_file "$adapter_lock_owner"; then
    restored_inode="$(inode_of "$adapter_lock_owner" 2> /dev/null)" || restored_inode=""
  fi
  if [[ "$restored_inode" == "$adapter_guard_inode" && "$exact_token_value" == "$lock_token" ]]; then
    adapter_lock_owner_inode=$restored_inode
    return 0
  fi
  mark_cleanup_error "unable to restore adapter lock owner: $adapter_lock_owner"
  return 1
}

release_partial_serialization() {
  if [[ -n "$adapter_lock_inode" ]] && verify_owned_directory "$adapter_lock" "$adapter_lock_inode"; then
    if [[ -n "$(find "$adapter_lock" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
      mark_cleanup_error "adapter lock state changed; retained adapter lock for manual intervention"
      return 1
    fi
    rmdir "$adapter_lock" 2> /dev/null
    if ! path_is_absent "$adapter_lock"; then
      if verify_owned_directory "$adapter_lock" "$adapter_lock_inode" &&
        [[ -z "$(find "$adapter_lock" -mindepth 1 -print -quit 2> /dev/null)" ]]; then
        mark_cleanup_error "unable to remove adapter lock-directory: $adapter_lock"
      else
        mark_cleanup_error "adapter lock changed during removal; retained for manual intervention"
      fi
      return 1
    fi
  elif [[ -n "$adapter_lock_inode" ]]; then
    if path_is_absent "$adapter_lock"; then
      mark_cleanup_error "adapter lock changed before removal; retained serialization for manual intervention"
    else
      mark_cleanup_error "adapter lock state changed; retained adapter lock for manual intervention"
    fi
    return 1
  fi
  remove_claim_without_guard || return 1
  if verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
    rm "$adapter_guard" 2> /dev/null
    if ! path_is_absent "$adapter_guard"; then
      if verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
        mark_cleanup_error "unable to remove adapter acquisition guard: $adapter_guard"
      else
        mark_cleanup_error \
          "adapter acquisition guard changed during removal; retained for manual intervention"
      fi
      return 1
    fi
  else
    mark_cleanup_error "adapter acquisition guard changed; retained for manual intervention"
    return 1
  fi
  return 0
}

release_owned_serialization() {
  if ! lock_directory_identity_is_exact; then
    mark_cleanup_error "adapter lock state changed; retained adapter lock for manual intervention"
    return 1
  fi
  if ! verify_owned_regular "$adapter_lock_owner" "$adapter_lock_owner_inode" "$lock_token"; then
    mark_cleanup_error "adapter lock owner changed; retained adapter lock for manual intervention"
    return 1
  fi
  if ! lock_directory_is_exact; then
    mark_cleanup_error "adapter lock state changed; retained adapter lock for manual intervention"
    return 1
  fi
  if ! verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
    mark_cleanup_error "adapter acquisition guard changed; retained serialization for manual intervention"
    return 1
  fi
  if ! claim_directory_is_exact ||
    ! verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token"; then
    mark_cleanup_error "adapter claim state changed; retained serialization for manual intervention"
    return 1
  fi

  rm "$adapter_lock_owner" 2> /dev/null
  if verify_owned_regular "$adapter_lock_owner" "$adapter_lock_owner_inode" "$lock_token"; then
    mark_cleanup_error "unable to remove adapter lock-owner: $adapter_lock_owner"
    return 1
  fi
  if ! path_is_absent "$adapter_lock_owner"; then
    mark_cleanup_error "adapter lock owner changed during removal; retained for manual intervention"
    return 1
  fi

  rmdir "$adapter_lock" 2> /dev/null
  if verify_owned_directory "$adapter_lock" "$adapter_lock_inode"; then
    mark_cleanup_error "unable to remove adapter lock-directory: $adapter_lock"
    restore_lock_owner || true
    return 1
  fi
  if ! path_is_absent "$adapter_lock"; then
    mark_cleanup_error "adapter lock changed during removal; retained for manual intervention"
    return 1
  fi

  rm "$claim_file" 2> /dev/null
  if verify_owned_regular "$claim_file" "$claim_file_inode" "$lock_token"; then
    mark_cleanup_error "unable to remove adapter claim owner: $claim_file"
    return 1
  fi
  if ! path_is_absent "$claim_file"; then
    mark_cleanup_error "adapter claim owner changed during removal; retained for manual intervention"
    return 1
  fi
  rmdir "$claim_directory" 2> /dev/null
  if verify_owned_directory "$claim_directory" "$claim_directory_inode"; then
    mark_cleanup_error "unable to remove adapter claim directory: $claim_directory"
    return 1
  fi
  if ! path_is_absent "$claim_directory"; then
    mark_cleanup_error "adapter claim directory changed during removal; retained for manual intervention"
    return 1
  fi

  rm "$adapter_guard" 2> /dev/null
  if verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
    mark_cleanup_error "unable to remove adapter acquisition guard: $adapter_guard"
    return 1
  fi
  if ! path_is_absent "$adapter_guard"; then
    mark_cleanup_error "adapter acquisition guard changed during removal; retained for manual intervention"
    return 1
  fi
  return 0
}

release_serialization() {
  if [[ -n "$adapter_lock_owner_inode" ]]; then
    release_owned_serialization
    return
  fi
  if [[ -n "$adapter_guard_inode" ]] &&
    ! verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
    mark_cleanup_error "adapter acquisition guard changed; retained serialization for manual intervention"
    return 1
  fi
  if ! claim_state_is_exact_for_release; then
    mark_cleanup_error "adapter claim state changed; retained serialization for manual intervention"
    return 1
  fi
  if [[ -z "$adapter_guard_inode" ]]; then
    remove_claim_without_guard
    return
  fi
  release_partial_serialization
}

cleanup() {
  local status=$?
  trap - EXIT
  trap '' HUP INT TERM
  set +e
  cleanup_failed=0

  if ((transaction_complete == 0)); then
    remove_owned_artifact "$host_profile" "$host_inode" "owned output" || true
    remove_owned_artifact "$canonical_destination" "$canonical_inode" "owned output" || true
  fi
  remove_owned_artifact "$canonical_stage" "$canonical_stage_inode" "stage" || true
  remove_owned_artifact "$host_stage" "$host_stage_inode" "stage" || true
  if ((transaction_complete == 0)); then
    remove_owned_parent "$codex_agents_directory" "$codex_agents_directory_inode" || true
    remove_owned_parent "$codex_directory" "$codex_directory_inode" || true
    remove_owned_parent "$agents_directory" "$agents_directory_inode" || true
  fi

  if ((cleanup_failed == 0)); then
    release_serialization || true
  fi
  if ((cleanup_failed)); then
    if [[ -n "$adapter_guard_inode" ]] &&
      verify_owned_regular "$adapter_guard" "$adapter_guard_inode" "$lock_token"; then
      printf '%s: cleanup incomplete: retained adapter lock for manual intervention: %s\n' \
        "$script_name" "$adapter_lock" >&2
    fi
    if ((status == 0)); then
      status=1
    fi
  elif ((status == 0)); then
    printf '%s\n' "$success_message"
  fi
  exit "$status"
}

[[ $# -eq 1 ]] || usage
requested_target=$1

if [[ ! -d "$requested_target" ]]; then
  fail "not a directory: $requested_target"
fi
TARGET="$(cd "$requested_target" && pwd -P)" || fail "cannot resolve target: $requested_target"
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  fail "vendor AGENTS.md before installing a host adapter"
fi

canonical_profile="$SRC/agents/code-simplifier.md"
canonical_name="$(awk '$1 == "name:" { print $2; exit }' "$canonical_profile")"
canonical_description="$(awk '
    /^description:/ { capture = 1; next }
    capture && /^[[:space:]]+[[:graph:]]/ {
        sub(/^[[:space:]]+/, "")
        text = text (text == "" ? "" : " ") $0
        next
    }
    capture { exit }
    END { print text }
' "$canonical_profile")"
if [[ -z "$canonical_name" || -z "$canonical_description" ]]; then
  fail "canonical simplifier metadata is incomplete"
fi

escaped_name="${canonical_name//\\/\\\\}"
escaped_name="${escaped_name//\"/\\\"}"
escaped_description="${canonical_description//\\/\\\\}"
escaped_description="${escaped_description//\"/\\\"}"
agents_directory="$TARGET/agents"
codex_directory="$TARGET/.codex"
codex_agents_directory="$codex_directory/agents"
canonical_destination="$agents_directory/code-simplifier.md"
host_profile="$codex_agents_directory/code-simplifier.toml"
adapter_lock="$TARGET/.research-repo-standard-adapter.lock"
adapter_lock_owner="$adapter_lock/owner"
adapter_guard="$TARGET/.research-repo-standard-adapter.guard"
lock_nonce="$(date +%s)-$RANDOM-$RANDOM"
lock_token="$$:$adapter_id:$lock_nonce"
claim_directory="$TARGET/.research-repo-standard-adapter.claim.$$-$lock_nonce"
claim_file="$claim_directory/owner"

check_output_parent "$agents_directory"
check_output_parent "$codex_directory"
check_output_parent "$codex_agents_directory"

canonical_stage=""
host_stage=""
canonical_stage_inode=""
host_stage_inode=""
canonical_inode=""
host_inode=""
agents_directory_inode=""
codex_directory_inode=""
codex_agents_directory_inode=""
claim_directory_inode=""
claim_file_inode=""
adapter_guard_inode=""
adapter_lock_inode=""
adapter_lock_owner_inode=""
exact_token_value=""
creation_transition=0
pending_signal_status=0
cleanup_failed=0
transaction_complete=0
success_message="installed Codex custom agent -> $host_profile"

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

acquire_adapter_lock

if [[ ! -d "$agents_directory" ]]; then
  create_owned_directory "$agents_directory" agents_directory_inode ||
    fail "failed to create output parent agents"
fi
verify_physical_parent "$agents_directory"

if [[ ! -d "$codex_directory" ]]; then
  create_owned_directory "$codex_directory" codex_directory_inode ||
    fail "failed to create output parent .codex"
fi
verify_physical_parent "$codex_directory"
check_output_parent "$codex_agents_directory"
if [[ ! -d "$codex_agents_directory" ]]; then
  create_owned_directory "$codex_agents_directory" codex_agents_directory_inode ||
    fail "failed to create output parent .codex/agents"
fi
verify_physical_parent "$codex_agents_directory"

if ! create_temporary_file "$agents_directory/.code-simplifier.md.stage.XXXXXX" \
  canonical_stage canonical_stage_inode; then
  fail "failed to create canonical simplifier stage"
fi
if ! cp "$canonical_profile" "$canonical_stage"; then
  fail "failed to stage canonical simplifier profile"
fi
if ! cmp -s "$canonical_profile" "$canonical_stage"; then
  fail "staged canonical simplifier profile is incomplete"
fi
chmod 0644 "$canonical_stage"

if ! create_temporary_file "$codex_agents_directory/.code-simplifier.toml.stage.XXXXXX" \
  host_stage host_stage_inode; then
  fail "failed to create Codex simplifier stage"
fi
{
  printf 'name = "%s"\n' "$escaped_name"
  printf 'description = "%s"\n' "$escaped_description"
  printf '%s\n' 'developer_instructions = "Read and apply agents/code-simplifier.md before reviewing changed code. Preserve behavior exactly, follow AGENTS.md, edit only within the delegated scope, and rerun covering tests after any edit."'
} > "$host_stage"
chmod 0644 "$host_stage"

check_expected_file "$canonical_stage" "$canonical_destination"
check_expected_file "$host_stage" "$host_profile"
verify_physical_parent "$agents_directory"
verify_physical_parent "$codex_directory"
verify_physical_parent "$codex_agents_directory"

check_expected_file "$canonical_stage" "$canonical_destination"
if path_is_absent "$canonical_destination"; then
  canonical_inode=$canonical_stage_inode
  if ! mv "$canonical_stage" "$canonical_destination"; then
    fail "failed to publish canonical simplifier profile"
  fi
fi
check_expected_file "$host_stage" "$host_profile"
if path_is_absent "$host_profile"; then
  host_inode=$host_stage_inode
  if ! mv "$host_stage" "$host_profile"; then
    fail "failed to publish Codex simplifier profile"
  fi
fi
transaction_complete=1
