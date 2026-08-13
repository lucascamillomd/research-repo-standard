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
canonical_standard_version="$(awk '$1 == "standard_version:" { print $2; exit }' "$canonical_profile")"
if [[ -z "$canonical_name" || -z "$canonical_description" || -z "$canonical_standard_version" ]]; then
  fail "canonical simplifier metadata is incomplete"
fi

policy_alias="$TARGET/CLAUDE.md"
agents_directory="$TARGET/agents"
claude_directory="$TARGET/.claude"
claude_agents_directory="$claude_directory/agents"
canonical_destination="$agents_directory/code-simplifier.md"
host_profile="$claude_agents_directory/code-simplifier.md"

check_output_parent "$agents_directory"
check_output_parent "$claude_directory"
check_output_parent "$claude_agents_directory"
check_policy_alias

canonical_stage=""
host_stage=""
created_alias=0
created_canonical=0
created_host=0
created_agents_directory=0
created_claude_directory=0
created_claude_agents_directory=0
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
    ((created_alias)) && rm -f "$policy_alias"
    ((created_claude_agents_directory)) && rmdir "$claude_agents_directory" 2> /dev/null
    ((created_claude_directory)) && rmdir "$claude_directory" 2> /dev/null
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

check_policy_alias
check_expected_file "$canonical_stage" "$canonical_destination"
check_expected_file "$host_stage" "$host_profile"
verify_physical_parent "$agents_directory"
verify_physical_parent "$claude_directory"
verify_physical_parent "$claude_agents_directory"

check_policy_alias
if [[ ! -e "$policy_alias" && ! -L "$policy_alias" ]]; then
  ln -s AGENTS.md "$policy_alias"
  created_alias=1
fi
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
    fail "failed to publish Claude simplifier profile"
  fi
  host_stage=""
  created_host=1
fi
transaction_complete=1
printf 'installed Claude Code adapter -> %s\n' "$TARGET"
