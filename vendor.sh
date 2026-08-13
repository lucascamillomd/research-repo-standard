#!/usr/bin/env bash
# Vendor the portable standard into a target repository.
#
# Copies AGENTS.md only. Detailed references remain in the skill, while optional
# host integration is installed separately through adapters/.
#
# Re-vendoring preserves the target's "## This repository" section. That
# section is the project's identity and the only part expected to differ from
# this source; wiping it on every update would make the maintenance loop
# (edit here, vendor forward) destructive by default.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: vendor.sh <target-repo>" >&2
  exit 2
}

# The splice below assumes these two headings exist in this order; without the
# check, a renamed heading would silently produce a corrupted vendored file.
verify_source() {
  local this using
  this="$(grep -nx '## This repository' "$SRC/AGENTS.md" | head -1 | cut -d: -f1 || true)"
  using="$(grep -nx '## Using this standard' "$SRC/AGENTS.md" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$this" || -z "$using" ]] || ((this >= using)); then
    echo "vendor.sh: source AGENTS.md must contain '## This repository' followed by '## Using this standard'; aborting" >&2
    exit 1
  fi
}

# When the target already has '## This repository', its AGENTS.md must also
# have a following '## Using this standard'; otherwise the section-extraction
# awk would slurp everything to EOF and corrupt the splice.
verify_target() {
  local target="$1" this using
  [[ -f "$target/AGENTS.md" ]] || return 0
  this="$(grep -nx '## This repository' "$target/AGENTS.md" | head -1 | cut -d: -f1 || true)"
  [[ -n "$this" ]] || return 0
  using="$(grep -nx '## Using this standard' "$target/AGENTS.md" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$using" ]] || ((this >= using)); then
    echo "vendor.sh: target AGENTS.md has '## This repository' but no following '## Using this standard'; refusing to splice" >&2
    exit 1
  fi
}

# Build the vendored AGENTS.md into $1 for target $2, preserving the target's
# "## This repository" section when it has one.
#
# The section body is spliced through files rather than an awk -v variable:
# the awk shipped with macOS rejects newlines in -v values, so a multi-line
# section silently breaks the substitution there.
build_vendored() {
  local out="$1" target="$2" work
  work="$(dirname "$out")"
  if [[ -f "$target/AGENTS.md" ]]; then
    awk '/^## This repository$/{s=1;next} /^## Using this standard$/{s=0} s' \
      "$target/AGENTS.md" > "$work/section"
  else
    : > "$work/section"
  fi
  if [[ -s "$work/section" ]]; then
    awk '{print} /^## This repository$/{exit}' "$SRC/AGENTS.md" > "$work/head"
    awk '/^## Using this standard$/{f=1} f' "$SRC/AGENTS.md" > "$work/tail"
    cat "$work/head" "$work/section" "$work/tail" > "$out"
  else
    cp "$SRC/AGENTS.md" "$out"
  fi
}

[[ $# -eq 1 ]] || usage
TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
  echo "vendor.sh: not a directory: $TARGET" >&2
  exit 1
fi

verify_source
verify_target "$TARGET"

# Stage beside the destination so the final rename stays on one filesystem and
# cannot degrade into an interruptible cross-filesystem copy.
work="$(mktemp -d "$TARGET/.vendor.XXXXXX")"
trap 'rm -rf "$work"' EXIT

build_vendored "$work/AGENTS.md" "$TARGET"

# Move into place only after the whole file is built, so a failure partway
# through cannot leave a half-written standard behind. The target is a git
# repository; git is the backup, so no .bak file is written.
mv "$work/AGENTS.md" "$TARGET/AGENTS.md"

echo "vendored AGENTS.md -> $TARGET"

if [[ -s "$work/section" ]]; then
  echo "preserved the existing '## This repository' section"
else
  echo "next: fill in the '## This repository' section of $TARGET/AGENTS.md"
fi
