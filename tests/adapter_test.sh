#!/usr/bin/env bash
# Tests for optional host adapters. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

target="$tmp/target"
mkdir "$target"
"$ROOT/vendor.sh" "$target" >/dev/null
rm -f "$target/CLAUDE.md"

"$ROOT/adapters/claude-code.sh" "$target" >/dev/null
if [[ "$(readlink "$target/CLAUDE.md" 2>/dev/null || true)" == "AGENTS.md" ]]; then
    pass "Claude adapter creates relative policy alias"
else
    fail "Claude adapter creates relative policy alias"
fi

if [[ -f "$target/.claude/agents/code-simplifier.md" ]] \
    && ! grep -Eq '^model:' "$target/.claude/agents/code-simplifier.md"; then
    pass "Claude adapter installs provider-neutral simplifier profile"
else
    fail "Claude adapter installs provider-neutral simplifier profile"
fi

"$ROOT/adapters/codex.sh" "$target" >/dev/null
codex_profile="$target/.codex/agents/code-simplifier.toml"
if [[ -f "$codex_profile" ]] \
    && grep -Eq '^[[:space:]]*name[[:space:]]*=' "$codex_profile" \
    && grep -Eq '^[[:space:]]*description[[:space:]]*=' "$codex_profile" \
    && grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' "$codex_profile" \
    && grep -q 'agents/code-simplifier\.md' "$codex_profile" \
    && [[ ! -e "$target/CODEX.md" ]] \
    && ! grep -Eq '^[[:space:]]*(model|model_reasoning_effort)[[:space:]]*=' "$codex_profile"; then
    pass "Codex adapter installs provider-neutral simplifier profile"
else
    fail "Codex adapter installs provider-neutral simplifier profile"
fi

if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all adapter tests passed"
