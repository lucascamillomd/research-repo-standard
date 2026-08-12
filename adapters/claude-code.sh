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

mkdir -p "$TARGET/.claude/agents"
sed '/^model:/d' "$SRC/agents/code-simplifier.md" \
    > "$TARGET/.claude/agents/code-simplifier.md"
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"
printf 'installed Claude Code adapter -> %s\n' "$TARGET"
