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

check_output_parent "$agents_directory"
check_output_parent "$codex_directory"
check_output_parent "$codex_agents_directory"

canonical_stage=""
host_stage=""
created_canonical=0
created_host=0
created_agents_directory=0
created_codex_directory=0
created_codex_agents_directory=0
transaction_complete=0

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  [[ -n "$canonical_stage" ]] && rm -f "$canonical_stage"
  [[ -n "$host_stage" ]] && rm -f "$host_stage"
  if ((transaction_complete == 0)); then
    ((created_host)) && rm -f "$host_profile"
    ((created_canonical)) && rm -f "$canonical_destination"
    ((created_codex_agents_directory)) && rmdir "$codex_agents_directory" 2> /dev/null
    ((created_codex_directory)) && rmdir "$codex_directory" 2> /dev/null
    ((created_agents_directory)) && rmdir "$agents_directory" 2> /dev/null
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

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
  if ! mv "$canonical_stage" "$canonical_destination"; then
    fail "failed to publish canonical simplifier profile"
  fi
  canonical_stage=""
  created_canonical=1
fi
check_expected_file "$host_stage" "$host_profile"
if [[ ! -e "$host_profile" && ! -L "$host_profile" ]]; then
  if ! mv "$host_stage" "$host_profile"; then
    fail "failed to publish Codex simplifier profile"
  fi
  host_stage=""
  created_host=1
fi
transaction_complete=1
printf 'installed Codex custom agent -> %s\n' "$host_profile"
