#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script_name="$(basename "$0")"

fail() {
  printf '%s: %s\n' "$script_name" "$1" >&2
  exit 1
}

usage() {
  echo "usage: $script_name <target-repo>" >&2
  exit 2
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

release_adapter_lock() {
  if ((lock_owned)) && [[ -d "$adapter_lock" && ! -L "$adapter_lock" ]] &&
    [[ -f "$adapter_lock_owner" && ! -L "$adapter_lock_owner" ]] &&
    [[ "$(cat "$adapter_lock_owner" 2> /dev/null || true)" == "$lock_token" ]]; then
    rm -f "$adapter_lock_owner"
    rmdir "$adapter_lock" 2> /dev/null
  fi
}

handle_signal() {
  if ((acquisition_transition)); then
    pending_signal_status=$1
    return
  fi
  exit "$1"
}

acquire_adapter_lock() {
  lock_mkdir_succeeded=0
  acquisition_transition=1
  if mkdir "$adapter_lock" 2> /dev/null; then
    lock_mkdir_succeeded=1
    created_lock_directory=1
  fi
  acquisition_transition=0
  if ((pending_signal_status)); then
    exit "$pending_signal_status"
  fi
  if ((lock_mkdir_succeeded == 0)); then
    if [[ -L "$adapter_lock" || ! -d "$adapter_lock" ]] ||
      [[ ! -f "$adapter_lock_owner" || -L "$adapter_lock_owner" ]]; then
      fail "adapter lock requires manual intervention"
    fi
    existing_lock_token="$(cat "$adapter_lock_owner" 2> /dev/null || true)"
    if [[ ! "$existing_lock_token" =~ ^([0-9]+):(claude-code\.sh|codex\.sh):[0-9]+-[0-9]+-[0-9]+$ ]]; then
      fail "adapter lock requires manual intervention"
    fi
    existing_lock_pid="${BASH_REMATCH[1]}"
    if kill -0 "$existing_lock_pid" 2> /dev/null; then
      fail "adapter installation already in progress: $existing_lock_token"
    fi
    fail "adapter lock requires manual intervention"
  fi
  if ! printf '%s\n' "$lock_token" > "$adapter_lock_owner"; then
    fail "failed to write adapter lock owner"
  fi
  if [[ ! -f "$adapter_lock_owner" || -L "$adapter_lock_owner" ]] ||
    [[ "$(cat "$adapter_lock_owner" 2> /dev/null || true)" != "$lock_token" ]]; then
    fail "failed to verify adapter lock owner"
  fi
  lock_owned=1
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
lock_nonce="$(date +%s)-$RANDOM-$RANDOM"
lock_token="$$:$script_name:$lock_nonce"

check_output_parent "$agents_directory"
check_output_parent "$claude_directory"
check_output_parent "$claude_agents_directory"
check_policy_alias

canonical_stage=""
host_stage=""
alias_staging_directory=""
alias_stage=""
canonical_inode=""
host_inode=""
alias_inode=""
acquisition_transition=0
pending_signal_status=0
created_lock_directory=0
lock_owned=0
created_agents_directory=0
created_claude_directory=0
created_claude_agents_directory=0
transaction_complete=0

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  if ((transaction_complete == 0)); then
    remove_if_owned "$host_profile" "$host_inode"
    remove_if_owned "$canonical_destination" "$canonical_inode"
    remove_if_owned "$policy_alias" "$alias_inode"
  fi
  [[ -n "$canonical_stage" ]] && rm -f "$canonical_stage"
  [[ -n "$host_stage" ]] && rm -f "$host_stage"
  [[ -n "$alias_stage" ]] && rm -f "$alias_stage"
  [[ -n "$alias_staging_directory" ]] && rmdir "$alias_staging_directory" 2> /dev/null
  if ((transaction_complete == 0)); then
    ((created_claude_agents_directory)) && rmdir "$claude_agents_directory" 2> /dev/null
    ((created_claude_directory)) && rmdir "$claude_directory" 2> /dev/null
    ((created_agents_directory)) && rmdir "$agents_directory" 2> /dev/null
  fi
  release_adapter_lock
  if ((created_lock_directory)) && ((lock_owned == 0)); then
    rmdir "$adapter_lock" 2> /dev/null
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'handle_signal 1' HUP INT TERM

acquire_adapter_lock

if [[ ! -d "$agents_directory" ]]; then
  mkdir "$agents_directory"
  created_agents_directory=1
fi
verify_physical_parent "$agents_directory"

if [[ ! -d "$claude_directory" ]]; then
  mkdir "$claude_directory"
  created_claude_directory=1
fi
verify_physical_parent "$claude_directory"
check_output_parent "$claude_agents_directory"
if [[ ! -d "$claude_agents_directory" ]]; then
  mkdir "$claude_agents_directory"
  created_claude_agents_directory=1
fi
verify_physical_parent "$claude_agents_directory"

canonical_stage="$(mktemp "$agents_directory/.code-simplifier.md.stage.XXXXXX")"
if ! cp "$canonical_profile" "$canonical_stage"; then
  fail "failed to stage canonical simplifier profile"
fi
if ! cmp -s "$canonical_profile" "$canonical_stage"; then
  fail "staged canonical simplifier profile is incomplete"
fi
chmod 0644 "$canonical_stage"

host_stage="$(mktemp "$claude_agents_directory/.code-simplifier.md.stage.XXXXXX")"
{
  printf '%s\n' '---' "name: $canonical_name" "description: $canonical_description" '---'
  awk '
        delimiters < 2 && /^---$/ { delimiters++; next }
        delimiters >= 2 { print }
    ' "$canonical_profile"
} > "$host_stage"
chmod 0644 "$host_stage"

alias_staging_directory="$(mktemp -d "$TARGET/.CLAUDE.md.stage.XXXXXX")"
alias_stage="$alias_staging_directory/CLAUDE.md"
ln -s AGENTS.md "$alias_stage"

check_policy_alias
check_expected_file "$canonical_stage" "$canonical_destination"
check_expected_file "$host_stage" "$host_profile"
verify_physical_parent "$agents_directory"
verify_physical_parent "$claude_directory"
verify_physical_parent "$claude_agents_directory"

check_expected_file "$canonical_stage" "$canonical_destination"
if [[ ! -e "$canonical_destination" && ! -L "$canonical_destination" ]]; then
  canonical_inode="$(inode_of "$canonical_stage")"
  if ! mv "$canonical_stage" "$canonical_destination"; then
    fail "failed to publish canonical simplifier profile"
  fi
fi
check_expected_file "$host_stage" "$host_profile"
if [[ ! -e "$host_profile" && ! -L "$host_profile" ]]; then
  host_inode="$(inode_of "$host_stage")"
  if ! mv "$host_stage" "$host_profile"; then
    fail "failed to publish Claude simplifier profile"
  fi
fi
check_policy_alias
if [[ ! -e "$policy_alias" && ! -L "$policy_alias" ]]; then
  alias_inode="$(inode_of "$alias_stage")"
  if ! mv "$alias_stage" "$policy_alias"; then
    fail "failed to publish Claude policy alias"
  fi
fi
transaction_complete=1
printf 'installed Claude Code adapter -> %s\n' "$TARGET"
