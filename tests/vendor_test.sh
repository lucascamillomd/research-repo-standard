#!/usr/bin/env bash
# Tests for vendor.sh. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS+1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- 1. fresh vendor copies only portable AGENTS.md ---
t1="$tmp/fresh"
mkdir "$t1"
"$ROOT/vendor.sh" "$t1" >/dev/null
if diff -q "$ROOT/AGENTS.md" "$t1/AGENTS.md" >/dev/null \
    && [[ ! -e "$t1/CLAUDE.md" ]] \
    && [[ ! -e "$t1/CODEX.md" ]]; then
    pass "fresh portable vendor"
else
    fail "fresh portable vendor"
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

# --- deleted interface: --check is rejected as usage ---
set +e
check_output="$("$ROOT/vendor.sh" --check "$t1" 2>&1)"
check_rc=$?
set -e
if [[ "$check_rc" -eq 2 ]] && grep -q 'usage: vendor.sh <target-repo>' <<<"$check_output"; then
    pass "removed --check interface is rejected"
else
    fail "removed --check interface is rejected"
fi

# --- 5. staging happens inside the target for same-filesystem replacement ---
real_mv="$(command -v mv)"
mkdir "$tmp/bin"
cat > "$tmp/bin/mv" <<'EOF'
#!/usr/bin/env bash
set -e
args=("$@")
count=${#args[@]}
source=${args[$((count - 2))]}
destination=${args[$((count - 1))]}
source_parent="$(cd "$(dirname "$source")/.." && pwd -P)"
destination_dir="$(cd "$(dirname "$destination")" && pwd -P)"
printf '%s\n%s\n%s\n' "$source_parent" "$destination_dir" "$(basename "$destination")" > "$MV_LOG"
exec "$REAL_MV" "$@"
EOF
chmod +x "$tmp/bin/mv"
t5="$tmp/staging-target"; mkdir "$t5"
MV_LOG="$tmp/mv.log" REAL_MV="$real_mv" PATH="$tmp/bin:$PATH" \
    "$ROOT/vendor.sh" "$t5" >/dev/null
{
    IFS= read -r source_parent
    IFS= read -r destination_dir
    IFS= read -r destination_name
} < "$tmp/mv.log"
target_dir="$(cd "$t5" && pwd -P)"
if [[ "$source_parent" == "$target_dir" ]] \
    && [[ "$destination_dir" == "$target_dir" ]] \
    && [[ "$destination_name" == "AGENTS.md" ]]; then
    pass "vendor stages beside the destination"
else
    fail "vendor stages beside the destination"
fi

# --- 6. every standard file carries a version stamp in its first 5 lines ---
stamp_ok=1
for f in "$ROOT"/AGENTS.md "$ROOT"/SKILL.md "$ROOT"/README.md "$ROOT"/references/*.md "$ROOT"/agents/*.md; do
    if ! head -5 "$f" | grep -q 'standard_version:'; then
        fail "missing standard_version stamp: ${f#"$ROOT"/}"
        stamp_ok=0
    fi
done
if (( stamp_ok )); then
    pass "version stamps present"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all tests passed"
