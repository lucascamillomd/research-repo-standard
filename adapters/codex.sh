#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_expected_file() {
  source_file=$1
  destination_file=$2
  if [[ -e "$destination_file" || -L "$destination_file" ]] && ! cmp -s "$source_file" "$destination_file"; then
    echo "$(basename "$0"): refusing to replace customized ${destination_file#"$TARGET"/}" >&2
    exit 1
  fi
}

install_expected_file() {
  source_file=$1
  destination_file=$2
  check_expected_file "$source_file" "$destination_file"
  if [[ ! -e "$destination_file" && ! -L "$destination_file" ]]; then
    cp "$source_file" "$destination_file"
  fi
}

usage() {
  echo "usage: $(basename "$0") <target-repo>" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
  echo "$(basename "$0"): not a directory: $TARGET" >&2
  exit 1
fi
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  echo "$(basename "$0"): vendor AGENTS.md before installing a host adapter" >&2
  exit 1
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
  echo "$(basename "$0"): canonical simplifier metadata is incomplete" >&2
  exit 1
fi

escaped_name="${canonical_name//\\/\\\\}"
escaped_name="${escaped_name//\"/\\\"}"
escaped_description="${canonical_description//\\/\\\\}"
escaped_description="${escaped_description//\"/\\\"}"
canonical_destination="$TARGET/agents/code-simplifier.md"
host_profile="$TARGET/.codex/agents/code-simplifier.toml"
temporary_host_profile="$(mktemp "$TARGET/.code-simplifier.XXXXXX")"
trap 'rm -f "$temporary_host_profile"' EXIT
{
  printf 'name = "%s"\n' "$escaped_name"
  printf 'description = "%s"\n' "$escaped_description"
  printf '%s\n' 'developer_instructions = "Read and apply agents/code-simplifier.md before reviewing changed code. Preserve behavior exactly, follow AGENTS.md, edit only within the delegated scope, and rerun covering tests after any edit."'
} > "$temporary_host_profile"

check_expected_file "$canonical_profile" "$canonical_destination"
check_expected_file "$temporary_host_profile" "$host_profile"

mkdir -p "$TARGET/.codex/agents" "$TARGET/agents"
install_expected_file "$canonical_profile" "$canonical_destination"
if [[ ! -e "$host_profile" && ! -L "$host_profile" ]]; then
  mv "$temporary_host_profile" "$host_profile"
fi
printf 'installed Codex custom agent -> %s\n' "$TARGET/.codex/agents/code-simplifier.toml"
