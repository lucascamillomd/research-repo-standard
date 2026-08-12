#!/usr/bin/env bash
set -euo pipefail

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

mkdir -p "$TARGET/.codex/agents"
cat > "$TARGET/.codex/agents/code-simplifier.toml" <<'EOF'
name = "code-simplifier"
description = "Simplifies recently modified code while preserving behavior and repository policy."
developer_instructions = "Read and apply agents/code-simplifier.md before reviewing recently modified code. Preserve behavior, follow the effective AGENTS.md policy, run relevant tests, and report significant refinements."
EOF
printf 'installed Codex adapter -> %s\n' "$TARGET"
