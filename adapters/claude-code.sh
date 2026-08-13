#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script_name="$(basename "$0")"
adapter_id=claude-code.sh

fail() {
  printf '%s: %s\n' "$script_name" "$1" >&2
  exit 1
}

usage() {
  printf 'usage: %s <target-repo>\n' "$script_name" >&2
  exit 2
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

inode_of() {
  LC_ALL=C ls -di "$1" | awk '{ print $1 }'
}

check_output_parent() {
  directory=$1
  if [[ -L "$directory" ]]; then
    fail "refusing symlinked output parent ${directory#"$TARGET"/}"
  fi
  if [[ -e "$directory" && ! -d "$directory" ]]; then
    fail "output parent is not a directory: ${directory#"$TARGET"/}"
  fi
}

verify_physical_parent() {
  directory=$1
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
  expected_file=$1
  destination_file=$2
  if [[ -L "$destination_file" ]]; then
    fail "refusing to replace customized ${destination_file#"$TARGET"/}: generated profile is a symlink"
  fi
  if [[ -e "$destination_file" ]] &&
    { [[ ! -f "$destination_file" ]] || ! cmp -s "$expected_file" "$destination_file"; }; then
    fail "refusing to replace customized ${destination_file#"$TARGET"/}"
  fi
}

check_policy_alias() {
  if [[ -L "$policy_alias" ]]; then
    if [[ "$(readlink "$policy_alias")" != "AGENTS.md" ]]; then
      fail "refusing to replace existing CLAUDE.md symlink"
    fi
  elif [[ -e "$policy_alias" ]]; then
    fail "refusing to replace existing CLAUDE.md"
  fi
}

read_exact_token_file() {
  token_path=$1
  token_file_value=""
  if [[ ! -f "$token_path" || -L "$token_path" ]] ||
    ! IFS= read -r token_file_value < "$token_path"; then
    return 1
  fi
  token_byte_count=""
  if token_byte_count="$(LC_ALL=C wc -c < "$token_path" | tr -d '[:space:]')"; then
    :
  else
    # Filesystem evidence, not an injected post-effect command status, decides
    # whether a creation transition owns this exact token file.
    :
  fi
  [[ "$token_byte_count" =~ ^[0-9]+$ ]] || return 1
  ((token_byte_count == ${#token_file_value} + 1))
}

is_exact_token_inode() {
  token_path=$1
  expected_inode=$2
  [[ -n "$expected_inode" ]] && read_exact_token_file "$token_path" &&
    [[ "$token_file_value" == "$lock_token" ]] &&
    [[ "$(inode_of "$token_path" 2> /dev/null)" == "$expected_inode" ]]
}

inspect_existing_owner() {
  owner_path=$1
  if ! read_exact_token_file "$owner_path" ||
    [[ ! "$token_file_value" =~ ^([1-9][0-9]*):(claude-code\.sh|codex\.sh):[0-9]+-[0-9]+-[0-9]+$ ]]; then
    fail "$2 requires manual intervention"
  fi
  existing_lock_pid="${BASH_REMATCH[1]}"
  if kill -0 "$existing_lock_pid" 2> /dev/null; then
    fail "adapter installation already in progress: $token_file_value"
  fi
  fail "$2 requires manual intervention"
}

handle_signal() {
  signal_status=$1
  if ((creation_transition)); then
    if ((pending_signal_status == 0)); then
      pending_signal_status=$signal_status
    fi
    return
  fi
  exit "$signal_status"
}

honor_pending_signal() {
  if ((pending_signal_status)); then
    exit "$pending_signal_status"
  fi
}

# The caller proves no-follow absence immediately before this transition.
create_directory_transition() {
  creation_path=$1
  inode_variable=$2
  creation_status=0
  observed_inode=""
  creation_transition=1
  if mkdir "$creation_path" 2> /dev/null; then
    creation_status=0
  else
    creation_status=$?
  fi
  if [[ -d "$creation_path" && ! -L "$creation_path" ]]; then
    observed_inode="$(inode_of "$creation_path" 2> /dev/null)"
    [[ "$observed_inode" =~ ^[0-9]+$ ]] || observed_inode=""
  fi
  if [[ -n "$observed_inode" ]]; then
    printf -v "$inode_variable" '%s' "$observed_inode"
  fi
  creation_transition=0
  honor_pending_signal
  ((creation_status == 0)) && [[ -n "$observed_inode" ]]
}

create_claim_file() {
  claim_status=0
  observed_claim_inode=""
  creation_transition=1
  set -C
  if printf '%s\n' "$lock_token" > "$adapter_claim_file"; then
    claim_status=0
  else
    claim_status=$?
  fi
  set +C
  if read_exact_token_file "$adapter_claim_file" && [[ "$token_file_value" == "$lock_token" ]]; then
    observed_claim_inode="$(inode_of "$adapter_claim_file" 2> /dev/null)"
    [[ "$observed_claim_inode" =~ ^[0-9]+$ ]] || observed_claim_inode=""
  fi
  if [[ -n "$observed_claim_inode" ]]; then
    claim_file_inode=$observed_claim_inode
  fi
  creation_transition=0
  honor_pending_signal
  ((claim_status == 0)) && [[ -n "$claim_file_inode" ]]
}

link_claim_transition() {
  link_destination=$1
  inode_variable=$2
  link_status=0
  linked_inode=""
  creation_transition=1
  if link "$adapter_claim_file" "$link_destination" 2> /dev/null; then
    link_status=0
  else
    link_status=$?
  fi
  if is_exact_token_inode "$link_destination" "$claim_file_inode"; then
    linked_inode="$(inode_of "$link_destination" 2> /dev/null)"
  fi
  if [[ -n "$linked_inode" ]]; then
    printf -v "$inode_variable" '%s' "$linked_inode"
    if [[ "$link_destination" == "$adapter_lock_owner" ]] &&
      [[ -n "$lock_directory_inode" ]] &&
      [[ -d "$adapter_lock" && ! -L "$adapter_lock" ]] &&
      [[ "$(inode_of "$adapter_lock" 2> /dev/null)" == "$lock_directory_inode" ]] &&
      is_exact_token_inode "$adapter_guard" "$claim_file_inode"; then
      lock_owned=1
    fi
  fi
  creation_transition=0
  honor_pending_signal
  ((link_status == 0)) && [[ -n "$linked_inode" ]]
}

inspect_existing_lock() {
  if [[ -L "$adapter_lock" || ! -d "$adapter_lock" ]]; then
    fail "adapter lock requires manual intervention"
  fi
  inspect_existing_owner "$adapter_lock_owner" "adapter lock"
}

acquire_adapter_lock() {
  if path_exists "$adapter_claim_directory"; then
    fail "adapter acquisition claim requires manual intervention"
  fi
  if ! create_directory_transition "$adapter_claim_directory" claim_directory_inode; then
    fail "failed to create adapter acquisition claim"
  fi
  if ! create_claim_file; then
    fail "failed to write adapter acquisition claim"
  fi

  if path_exists "$adapter_guard"; then
    # A lock predates this claim. Inspect it first so concurrent readers of a
    # stale or malformed lock report that stable state, not each other's guard.
    if path_exists "$adapter_lock"; then
      inspect_existing_lock
    fi
    inspect_existing_owner "$adapter_guard" "adapter acquisition guard"
  fi
  if ! link_claim_transition "$adapter_guard" guard_inode; then
    if [[ -n "$guard_inode" ]]; then
      fail "failed to publish adapter acquisition guard"
    fi
    if path_exists "$adapter_guard"; then
      if path_exists "$adapter_lock"; then
        inspect_existing_lock
      fi
      inspect_existing_owner "$adapter_guard" "adapter acquisition guard"
    fi
    fail "adapter acquisition requires regular-file hard-link support"
  fi

  if path_exists "$adapter_lock"; then
    inspect_existing_lock
  fi
  if ! create_directory_transition "$adapter_lock" lock_directory_inode; then
    if [[ -z "$lock_directory_inode" ]]; then
      inspect_existing_lock
    fi
    fail "failed to create adapter lock directory"
  fi

  if path_exists "$adapter_lock_owner"; then
    fail "adapter lock requires manual intervention"
  fi
  if ! link_claim_transition "$adapter_lock_owner" lock_owner_inode; then
    if [[ -n "$lock_owner_inode" ]]; then
      fail "failed to publish adapter lock owner"
    fi
    fail "adapter acquisition requires regular-file hard-link support"
  fi

  if [[ ! -d "$adapter_lock" || -L "$adapter_lock" ]] ||
    [[ "$(inode_of "$adapter_lock" 2> /dev/null)" != "$lock_directory_inode" ]] ||
    ! is_exact_token_inode "$adapter_guard" "$claim_file_inode" ||
    ! is_exact_token_inode "$adapter_lock_owner" "$claim_file_inode" ||
    ! is_exact_token_inode "$adapter_claim_file" "$claim_file_inode"; then
    fail "failed to verify adapter lock ownership"
  fi
  lock_owned=1
}

create_output_parent() {
  output_directory=$1
  inode_variable=$2
  check_output_parent "$output_directory"
  if [[ ! -d "$output_directory" ]]; then
    if path_exists "$output_directory"; then
      fail "output parent is not a directory: ${output_directory#"$TARGET"/}"
    fi
    if ! create_directory_transition "$output_directory" "$inode_variable"; then
      fail "failed to create output parent ${output_directory#"$TARGET"/}"
    fi
  fi
  verify_physical_parent "$output_directory"
}

cleanup_error() {
  cleanup_failed=1
  printf '%s: cleanup incomplete: %s\n' "$script_name" "$1" >&2
}

remove_owned_path() {
  owned_path=$1
  expected_inode=$2
  cleanup_label=$3
  [[ -n "$expected_inode" ]] || return 0
  path_exists "$owned_path" || return 0
  current_inode="$(inode_of "$owned_path" 2> /dev/null)"
  [[ "$current_inode" == "$expected_inode" ]] || return 0
  rm -f "$owned_path" 2> /dev/null
  if path_exists "$owned_path" &&
    [[ "$(inode_of "$owned_path" 2> /dev/null)" == "$expected_inode" ]]; then
    cleanup_error "unable to remove $cleanup_label: $owned_path"
    return 1
  fi
  return 0
}

directory_is_empty() {
  [[ -z "$(find "$1" -mindepth 1 -print -quit 2> /dev/null)" ]]
}

remove_owned_directory() {
  owned_directory=$1
  expected_inode=$2
  cleanup_label=$3
  [[ -n "$expected_inode" ]] || return 0
  path_exists "$owned_directory" || return 0
  if [[ ! -d "$owned_directory" || -L "$owned_directory" ]] ||
    [[ "$(inode_of "$owned_directory" 2> /dev/null)" != "$expected_inode" ]]; then
    return 0
  fi
  # A foreign or preserved different-inode artifact may make an owned parent nonempty.
  directory_is_empty "$owned_directory" || return 0
  rmdir "$owned_directory" 2> /dev/null
  if [[ -d "$owned_directory" && ! -L "$owned_directory" ]] &&
    [[ "$(inode_of "$owned_directory" 2> /dev/null)" == "$expected_inode" ]] &&
    directory_is_empty "$owned_directory"; then
    cleanup_error "unable to remove $cleanup_label: $owned_directory"
    return 1
  fi
  return 0
}

restore_lock_owner() {
  if [[ -d "$adapter_lock" && ! -L "$adapter_lock" ]] &&
    [[ "$(inode_of "$adapter_lock" 2> /dev/null)" == "$lock_directory_inode" ]] &&
    ! path_exists "$adapter_lock_owner"; then
    link "$adapter_guard" "$adapter_lock_owner" 2> /dev/null || true
  fi
}

release_serialization() {
  if ((lock_owned)); then
    # All three regular-file names are hard links. Check the lock-owner path
    # first so a byte mutation receives the most precise actionable diagnosis.
    if ! is_exact_token_inode "$adapter_lock_owner" "$lock_owner_inode"; then
      cleanup_error "adapter lock owner changed; retained adapter lock for manual intervention"
      return 1
    fi
    if ! is_exact_token_inode "$adapter_guard" "$guard_inode" ||
      ! is_exact_token_inode "$adapter_claim_file" "$claim_file_inode" ||
      [[ ! -d "$adapter_lock" || -L "$adapter_lock" ]] ||
      [[ "$(inode_of "$adapter_lock" 2> /dev/null)" != "$lock_directory_inode" ]]; then
      cleanup_error "adapter serialization evidence changed; retained adapter lock for manual intervention"
      return 1
    fi
    rm -f "$adapter_lock_owner" 2> /dev/null
    if path_exists "$adapter_lock_owner" &&
      [[ "$(inode_of "$adapter_lock_owner" 2> /dev/null)" == "$lock_owner_inode" ]]; then
      cleanup_error "unable to remove adapter lock-owner: $adapter_lock_owner"
      return 1
    fi
    rmdir "$adapter_lock" 2> /dev/null
    if [[ -d "$adapter_lock" && ! -L "$adapter_lock" ]] &&
      [[ "$(inode_of "$adapter_lock" 2> /dev/null)" == "$lock_directory_inode" ]]; then
      restore_lock_owner
      cleanup_error "unable to remove adapter lock-directory: $adapter_lock"
      return 1
    fi
  elif [[ -n "$lock_directory_inode" ]]; then
    remove_owned_directory "$adapter_lock" "$lock_directory_inode" "adapter lock-directory" || return 1
  fi

  remove_owned_path "$adapter_claim_file" "$claim_file_inode" "adapter claim owner" || return 1
  remove_owned_directory "$adapter_claim_directory" "$claim_directory_inode" \
    "adapter claim directory" || return 1
  remove_owned_path "$adapter_guard" "$guard_inode" "adapter acquisition guard" || return 1
  return 0
}

cleanup() {
  status=$?
  trap - EXIT
  trap '' HUP INT TERM
  set +e
  cleanup_failed=0

  if ((transaction_complete == 0)); then
    remove_owned_path "$host_profile" "$host_inode" "owned output"
    remove_owned_path "$canonical_destination" "$canonical_inode" "owned output"
    remove_owned_path "$policy_alias" "$alias_inode" "owned output"
  fi

  remove_owned_path "$canonical_stage" "$canonical_stage_inode" "stage"
  remove_owned_path "$host_stage" "$host_stage_inode" "stage"
  remove_owned_path "$alias_stage" "$alias_stage_inode" "stage"
  remove_owned_directory "$alias_staging_directory" "$alias_staging_directory_inode" \
    "alias staging directory"

  if ((transaction_complete == 0)); then
    remove_owned_directory "$claude_agents_directory" "$claude_agents_directory_inode" \
      "output parent"
    remove_owned_directory "$claude_directory" "$claude_directory_inode" "output parent"
    remove_owned_directory "$agents_directory" "$agents_directory_inode" "output parent"
  fi

  if ((cleanup_failed == 0)); then
    release_serialization
  fi

  if ((cleanup_failed)); then
    if [[ -n "$guard_inode" ]] && is_exact_token_inode "$adapter_guard" "$guard_inode"; then
      printf '%s: cleanup incomplete: retained adapter lock for manual intervention: %s\n' \
        "$script_name" "$adapter_lock" >&2
    fi
    if ((status == 0)); then
      status=1
    fi
  elif ((status == 0)); then
    printf 'installed Claude Code adapter -> %s\n' "$TARGET"
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

policy_alias="$TARGET/CLAUDE.md"
agents_directory="$TARGET/agents"
claude_directory="$TARGET/.claude"
claude_agents_directory="$claude_directory/agents"
canonical_destination="$agents_directory/code-simplifier.md"
host_profile="$claude_agents_directory/code-simplifier.md"
adapter_lock="$TARGET/.research-repo-standard-adapter.lock"
adapter_lock_owner="$adapter_lock/owner"
adapter_guard="$TARGET/.research-repo-standard-adapter.guard"
lock_nonce="$(date +%s)-$RANDOM-$RANDOM"
lock_token="$$:$adapter_id:$lock_nonce"
adapter_claim_directory="$TARGET/.research-repo-standard-adapter.claim.$$-$lock_nonce"
adapter_claim_file="$adapter_claim_directory/owner"

# All declared destinations are validated before the first mutation.
check_output_parent "$agents_directory"
check_output_parent "$claude_directory"
check_output_parent "$claude_agents_directory"
check_policy_alias

canonical_stage=""
canonical_stage_inode=""
host_stage=""
host_stage_inode=""
alias_staging_directory=""
alias_staging_directory_inode=""
alias_stage=""
alias_stage_inode=""
canonical_inode=""
host_inode=""
alias_inode=""
agents_directory_inode=""
claude_directory_inode=""
claude_agents_directory_inode=""
claim_directory_inode=""
claim_file_inode=""
guard_inode=""
lock_directory_inode=""
lock_owner_inode=""
lock_owned=0
creation_transition=0
pending_signal_status=0
transaction_complete=0

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

acquire_adapter_lock

create_output_parent "$agents_directory" agents_directory_inode
create_output_parent "$claude_directory" claude_directory_inode
check_output_parent "$claude_agents_directory"
create_output_parent "$claude_agents_directory" claude_agents_directory_inode

canonical_stage="$(mktemp "$agents_directory/.code-simplifier.md.stage.XXXXXX")"
canonical_stage_inode="$(inode_of "$canonical_stage")"
if ! cp "$canonical_profile" "$canonical_stage"; then
  fail "failed to stage canonical simplifier profile"
fi
if ! cmp -s "$canonical_profile" "$canonical_stage"; then
  fail "staged canonical simplifier profile is incomplete"
fi
chmod 0644 "$canonical_stage"

host_stage="$(mktemp "$claude_agents_directory/.code-simplifier.md.stage.XXXXXX")"
host_stage_inode="$(inode_of "$host_stage")"
{
  printf '%s\n' '---' "name: $canonical_name" "description: $canonical_description" '---'
  awk '
        delimiters < 2 && /^---$/ { delimiters++; next }
        delimiters >= 2 { print }
    ' "$canonical_profile"
} > "$host_stage"
chmod 0644 "$host_stage"

alias_staging_directory="$(mktemp -d "$TARGET/.CLAUDE.md.stage.XXXXXX")"
alias_staging_directory_inode="$(inode_of "$alias_staging_directory")"
alias_stage="$alias_staging_directory/CLAUDE.md"
ln -s AGENTS.md "$alias_stage"
alias_stage_inode="$(inode_of "$alias_stage")"

check_policy_alias
check_expected_file "$canonical_stage" "$canonical_destination"
check_expected_file "$host_stage" "$host_profile"
verify_physical_parent "$agents_directory"
verify_physical_parent "$claude_directory"
verify_physical_parent "$claude_agents_directory"

check_expected_file "$canonical_stage" "$canonical_destination"
if ! path_exists "$canonical_destination"; then
  canonical_inode=$canonical_stage_inode
  if ! mv "$canonical_stage" "$canonical_destination"; then
    fail "failed to publish canonical simplifier profile"
  fi
fi
check_expected_file "$host_stage" "$host_profile"
if ! path_exists "$host_profile"; then
  host_inode=$host_stage_inode
  if ! mv "$host_stage" "$host_profile"; then
    fail "failed to publish Claude simplifier profile"
  fi
fi
check_policy_alias
if ! path_exists "$policy_alias"; then
  alias_inode=$alias_stage_inode
  if ! mv "$alias_stage" "$policy_alias"; then
    fail "failed to publish Claude policy alias"
  fi
fi
transaction_complete=1
