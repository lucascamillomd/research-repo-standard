#!/usr/bin/env bash
# Vendor the standard into a target repository.
#
# Copies AGENTS.md and points CLAUDE.md at it. Nothing else is vendored --
# references/ stays in the skill and loads on demand.
#
# Re-vendoring preserves the target's "## This repository" section. That section
# is the project's identity and the only part expected to differ from this
# source; wiping it on every update would make the maintenance loop (edit here,
# vendor forward) destructive by default.
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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The section body is spliced through files rather than an awk -v variable:
# the awk shipped with macOS rejects newlines in -v values, so a multi-line
# section silently breaks the substitution there.
if [[ -f "$TARGET/AGENTS.md" ]]; then
    awk '/^## This repository$/{s=1;next} /^## Using this standard$/{s=0} s' \
        "$TARGET/AGENTS.md" > "$work/section"
else
    : > "$work/section"
fi

if [[ -s "$work/section" ]]; then
    cp "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.bak"
    # Source, split around the per-repo section, with the target's section between.
    awk '{print} /^## This repository$/{exit}'  "$SRC/AGENTS.md" > "$work/head"
    awk '/^## Using this standard$/{f=1} f'     "$SRC/AGENTS.md" > "$work/tail"
    cat "$work/head" "$work/section" "$work/tail" > "$work/AGENTS.md"
else
    cp "$SRC/AGENTS.md" "$work/AGENTS.md"
fi

# Move into place only after the whole file is built, so a failure partway
# through cannot leave a half-written standard behind.
mv "$work/AGENTS.md" "$TARGET/AGENTS.md"

# CLAUDE.md is a symlink so there is one file, not two that can disagree.
ln -sfn AGENTS.md "$TARGET/CLAUDE.md"

version="$(sed -n '1s/.*standard_version: \([0-9.]*\).*/\1/p' "$SRC/AGENTS.md")"
echo "vendored standard_version: $version -> $TARGET"

if [[ -s "$work/section" ]]; then
    echo "preserved the existing '## This repository' section (backup: AGENTS.md.bak)"
else
    echo "next: fill in the '## This repository' section of $TARGET/AGENTS.md"
fi
