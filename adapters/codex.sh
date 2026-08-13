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
  if ((lock_acquisition_started)) && [[ -L "$adapter_lock" ]] &&
    [[ "$(readlink "$adapter_lock")" == "$lock_token" ]]; then
    rm -f "$adapter_lock"
  fi
}

acquire_adapter_lock() {
  lock_acquisition_started=1
  for attempt in 1 2; do
    if ln -s "$lock_token" "$adapter_lock" 2> /dev/null; then
      return
    fi
    if [[ ! -L "$adapter_lock" ]]; then
      fail "refusing unverifiable adapter lock path"
    fi
    existing_lock_token="$(readlink "$adapter_lock")"
    existing_lock_pid="${existing_lock_token%%:*}"
    if [[ ! "$existing_lock_pid" =~ ^[0-9]+$ ]]; then
      fail "cannot verify adapter lock owner: $existing_lock_token"
    fi
    if kill -0 "$existing_lock_pid" 2> /dev/null; then
      fail "adapter installation already in progress: $existing_lock_token"
    fi
    if [[ "$(readlink "$adapter_lock" 2> /dev/null || true)" != "$existing_lock_token" ]]; then
      fail "adapter lock owner changed during stale-lock verification"
    fi
    rm -f "$adapter_lock"
  done
  fail "could not acquire adapter lock"
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
lock_token="$$:$script_name"

check_output_parent "$agents_directory"
check_output_parent "$codex_directory"
check_output_parent "$codex_agents_directory"

canonical_stage=""
host_stage=""
canonical_inode=""
host_inode=""
lock_acquisition_started=0
created_agents_directory=0
created_codex_directory=0
created_codex_agents_directory=0
transaction_complete=0

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  if ((transaction_complete == 0)); then
    remove_if_owned "$host_profile" "$host_inode"
    remove_if_owned "$canonical_destination" "$canonical_inode"
  fi
  [[ -n "$canonical_stage" ]] && rm -f "$canonical_stage"
  [[ -n "$host_stage" ]] && rm -f "$host_stage"
  if ((transaction_complete == 0)); then
    ((created_codex_agents_directory)) && rmdir "$codex_agents_directory" 2> /dev/null
    ((created_codex_directory)) && rmdir "$codex_directory" 2> /dev/null
    ((created_agents_directory)) && rmdir "$agents_directory" 2> /dev/null
  fi
  release_adapter_lock
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

acquire_adapter_lock

if [[ ! -d "$agents_directory" ]]; then
  mkdir "$agents_directory"
  created_agents_directory=1
fi
verify_physical_parent "$agents_directory"

if [[ ! -d "$codex_directory" ]]; then
  mkdir "$codex_directory"
  created_codex_directory=1
fi
verify_physical_parent "$codex_directory"
check_output_parent "$codex_agents_directory"
if [[ ! -d "$codex_agents_directory" ]]; then
  mkdir "$codex_agents_directory"
  created_codex_agents_directory=1
fi
verify_physical_parent "$codex_agents_directory"

canonical_stage="$(mktemp "$agents_directory/.code-simplifier.md.stage.XXXXXX")"
if ! cp "$canonical_profile" "$canonical_stage"; then
  fail "failed to stage canonical simplifier profile"
fi
if ! cmp -s "$canonical_profile" "$canonical_stage"; then
  fail "staged canonical simplifier profile is incomplete"
fi
chmod 0644 "$canonical_stage"

host_stage="$(mktemp "$codex_agents_directory/.code-simplifier.toml.stage.XXXXXX")"
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
    fail "failed to publish Codex simplifier profile"
  fi
fi
transaction_complete=1
printf 'installed Codex custom agent -> %s\n' "$host_profile"
