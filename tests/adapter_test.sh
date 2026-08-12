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

claude_profile="$target/.claude/agents/code-simplifier.md"
claude_expected="$tmp/claude-expected.md"
{
    cat <<'EOF'
---
name: code-simplifier
description: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.
---
EOF
    awk '
        delimiters < 2 && /^---$/ { delimiters++; next }
        delimiters >= 2 { print }
    ' "$ROOT/agents/code-simplifier.md"
} > "$claude_expected"
if cmp -s "$claude_expected" "$claude_profile" \
    && ! grep -Eq '^model:' "$claude_profile"; then
    pass "Claude adapter installs provider-neutral simplifier profile"
else
    fail "Claude adapter installs provider-neutral simplifier profile"
fi

claude_before="$(cksum "$claude_profile")"
"$ROOT/adapters/claude-code.sh" "$target" >/dev/null
if [[ "$(readlink "$target/CLAUDE.md" 2>/dev/null || true)" == "AGENTS.md" ]] \
    && [[ "$(cksum "$claude_profile")" == "$claude_before" ]]; then
    pass "Claude adapter is idempotent"
else
    fail "Claude adapter is idempotent"
fi

"$ROOT/adapters/codex.sh" "$target" >/dev/null
codex_profile="$target/.codex/agents/code-simplifier.toml"
if [[ -f "$codex_profile" ]] \
    && grep -Eq '^[[:space:]]*name[[:space:]]*=' "$codex_profile" \
    && grep -Eq '^[[:space:]]*description[[:space:]]*=' "$codex_profile" \
    && grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' "$codex_profile" \
    && grep -q 'agents/code-simplifier\.md' "$codex_profile" \
    && cmp -s "$ROOT/agents/code-simplifier.md" "$target/agents/code-simplifier.md" \
    && [[ ! -e "$target/CODEX.md" ]] \
    && ! grep -Eq '^[[:space:]]*(model|model_reasoning_effort|sandbox_mode|mcp_servers|skills\.config)[[:space:]]*=' "$codex_profile"; then
    pass "Codex adapter installs provider-neutral simplifier profile"
else
    fail "Codex adapter installs provider-neutral simplifier profile"
fi

codex_before="$(cksum "$codex_profile" "$target/agents/code-simplifier.md")"
"$ROOT/adapters/codex.sh" "$target" >/dev/null
if [[ "$(cksum "$codex_profile" "$target/agents/code-simplifier.md")" == "$codex_before" ]] \
    && [[ ! -e "$target/CODEX.md" ]]; then
    pass "Codex adapter is idempotent"
else
    fail "Codex adapter is idempotent"
fi

missing="$tmp/missing"
mkdir "$missing"
if "$ROOT/adapters/claude-code.sh" "$missing" >/dev/null 2>&1; then
    fail "Claude adapter requires vendored AGENTS.md"
else
    pass "Claude adapter requires vendored AGENTS.md"
fi
if "$ROOT/adapters/codex.sh" "$missing" >/dev/null 2>&1; then
    fail "Codex adapter requires vendored AGENTS.md"
else
    pass "Codex adapter requires vendored AGENTS.md"
fi

if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all adapter tests passed"
