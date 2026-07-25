#!/usr/bin/env bash
# Vendor the standard into a target repository.
#
# Copies AGENTS.md and points CLAUDE.md at it. Nothing else is vendored --
# references/ stays in the skill and loads on demand.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
    echo "usage: vendor.sh <target-repo>" >&2
    exit 2
fi

TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
    echo "vendor.sh: not a directory: $TARGET" >&2
    exit 1
fi

if [[ -e "$TARGET/AGENTS.md" ]]; then
    # Preserve the per-repo section; it is the only part expected to differ.
    cp "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.bak"
    echo "existing AGENTS.md saved to AGENTS.md.bak -- restore its '## This repository' section"
fi

cp "$SRC/AGENTS.md" "$TARGET/AGENTS.md"

# CLAUDE.md is a symlink so there is one file, not two that can disagree.
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"

echo "vendored $(grep -o 'standard_version: [0-9.]*' "$SRC/AGENTS.md" | head -1) -> $TARGET"
echo "next: fill in the '## This repository' section of $TARGET/AGENTS.md"
