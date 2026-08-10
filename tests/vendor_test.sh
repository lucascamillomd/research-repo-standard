#!/usr/bin/env bash
# Tests for vendor.sh. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- 1. fresh vendor copies AGENTS.md and symlinks CLAUDE.md ---
t1="$tmp/fresh"; mkdir "$t1"
"$ROOT/vendor.sh" "$t1" >/dev/null
if diff -q "$ROOT/AGENTS.md" "$t1/AGENTS.md" >/dev/null \
   && [[ "$(readlink "$t1/CLAUDE.md")" == "AGENTS.md" ]]; then
    pass "fresh vendor"
else
    fail "fresh vendor"
fi

# --- 2. re-vendor preserves a modified '## This repository' section, no .bak ---
awk '/^## This repository$/{print; print ""; print "CUSTOM-MARKER project identity line."; next} {print}' \
    "$t1/AGENTS.md" > "$t1/AGENTS.md.new" && mv "$t1/AGENTS.md.new" "$t1/AGENTS.md"
"$ROOT/vendor.sh" "$t1" >/dev/null
if grep -q 'CUSTOM-MARKER' "$t1/AGENTS.md"; then
    pass "re-vendor preserves the This repository section"
else
    fail "re-vendor preserves the This repository section"
fi
if [[ -e "$t1/AGENTS.md.bak" ]]; then
    fail "re-vendor must not leave AGENTS.md.bak"
else
    pass "no .bak litter"
fi

# --- 3. a source missing a boundary heading aborts, target untouched ---
bad="$tmp/badsrc"; mkdir "$bad"
cp "$ROOT/vendor.sh" "$bad/vendor.sh"
grep -vx '## Using this standard' "$ROOT/AGENTS.md" > "$bad/AGENTS.md"
t3="$tmp/badtarget"; mkdir "$t3"
echo "sentinel" > "$t3/AGENTS.md"
if "$bad/vendor.sh" "$t3" >/dev/null 2>&1; then
    fail "corrupted source must abort"
else
    pass "corrupted source aborts"
fi
if [[ "$(cat "$t3/AGENTS.md")" == "sentinel" ]]; then
    pass "aborted vendor leaves target untouched"
else
    fail "aborted vendor leaves target untouched"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all tests passed"
