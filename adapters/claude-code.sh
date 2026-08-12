#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

if [[ -L "$TARGET/CLAUDE.md" ]]; then
  if [[ "$(readlink "$TARGET/CLAUDE.md")" != "AGENTS.md" ]]; then
    echo "$(basename "$0"): refusing to replace existing CLAUDE.md symlink" >&2
    exit 1
  fi
elif [[ -e "$TARGET/CLAUDE.md" ]]; then
  echo "$(basename "$0"): refusing to replace existing CLAUDE.md" >&2
  exit 1
else
  ln -s AGENTS.md "$TARGET/CLAUDE.md"
fi

mkdir -p "$TARGET/.claude/agents"
{
  cat << 'EOF'
---
name: code-simplifier
description: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.
---
EOF
  awk '
        delimiters < 2 && /^---$/ { delimiters++; next }
        delimiters >= 2 { print }
    ' "$SRC/agents/code-simplifier.md"
} > "$TARGET/.claude/agents/code-simplifier.md"
printf 'installed Claude Code adapter -> %s\n' "$TARGET"
