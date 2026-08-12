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

mkdir -p "$TARGET/.codex/agents" "$TARGET/agents"
cp "$SRC/agents/code-simplifier.md" "$TARGET/agents/code-simplifier.md"
cat > "$TARGET/.codex/agents/code-simplifier.toml" <<'EOF'
name = "code-simplifier"
description = "Simplifies recently modified code while preserving exact behavior."
developer_instructions = "Read and apply agents/code-simplifier.md before reviewing changed code. Preserve behavior exactly, follow AGENTS.md, edit only within the delegated scope, and rerun covering tests after any edit."
EOF
printf 'installed Codex custom agent -> %s\n' "$TARGET/.codex/agents/code-simplifier.toml"
