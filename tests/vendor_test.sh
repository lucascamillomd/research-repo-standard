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
err3="$("$bad/vendor.sh" "$t3" 2>&1 >/dev/null)" && t3_ok=0 || t3_ok=$?
if [[ "$t3_ok" -ne 0 ]]; then
    pass "corrupted source aborts"
else
    fail "corrupted source must abort"
fi
if echo "$err3" | grep -q "must contain '## This repository' followed by '## Using this standard'"; then
    pass "corrupted source prints diagnostic"
else
    fail "corrupted source prints diagnostic"
fi
if [[ "$(cat "$t3/AGENTS.md")" == "sentinel" ]]; then
    pass "aborted vendor leaves target untouched"
else
    fail "aborted vendor leaves target untouched"
fi

# --- 4. a target with '## This repository' but no '## Using this standard' aborts ---
t4="$tmp/badtarget2"; mkdir "$t4"
printf '## This repository\n\nSome content.\n' > "$t4/AGENTS.md"
err4="$("$ROOT/vendor.sh" "$t4" 2>&1 >/dev/null)" && t4_ok=0 || t4_ok=$?
if [[ "$t4_ok" -ne 0 ]]; then
    pass "malformed target aborts"
else
    fail "malformed target must abort"
fi
if echo "$err4" | grep -q "## Using this standard"; then
    pass "malformed target prints diagnostic"
else
    fail "malformed target prints diagnostic"
fi
if grep -q 'Some content' "$t4/AGENTS.md"; then
    pass "aborted malformed-target vendor leaves target untouched"
else
    fail "aborted malformed-target vendor leaves target untouched"
fi

# --- 4. --check: clean vendor exits 0, edited target exits 1 ---
if "$ROOT/vendor.sh" --check "$t1" >/dev/null 2>&1; then
    pass "--check clean"
else
    fail "--check clean"
fi
echo "local drift line" >> "$t1/AGENTS.md"
"$ROOT/vendor.sh" --check "$t1" >/dev/null 2>&1
rc=$?
if [[ "$rc" -eq 1 ]]; then
    pass "--check reports drift with exit 1"
else
    fail "--check reports drift with exit 1 (got $rc)"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all tests passed"
