#!/usr/bin/env bash
# Tests for optional host adapters. Plain bash + temp dirs; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

target="$tmp/target"
mkdir "$target"
"$ROOT/vendor.sh" "$target" > /dev/null
rm -f "$target/CLAUDE.md"

"$ROOT/adapters/claude-code.sh" "$target" > /dev/null
if [[ "$(readlink "$target/CLAUDE.md" 2> /dev/null || true)" == "AGENTS.md" ]]; then
  pass "Claude adapter creates relative policy alias"
else
  fail "Claude adapter creates relative policy alias"
fi

claude_profile="$target/.claude/agents/code-simplifier.md"
claude_frontmatter="$(
  awk '
        NR == 1 && /^---$/ { in_frontmatter = 1; next }
        in_frontmatter && /^---$/ { exit }
        in_frontmatter { print }
    ' "$claude_profile"
)"
expected_claude_frontmatter=$'name: code-simplifier\ndescription: Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.'
awk '
    delimiters < 2 && /^---$/ { delimiters++; next }
    delimiters >= 2 { print }
' "$ROOT/agents/code-simplifier.md" > "$tmp/canonical-simplifier-body"
awk '
    delimiters < 2 && /^---$/ { delimiters++; next }
    delimiters >= 2 { print }
' "$claude_profile" > "$tmp/claude-simplifier-body"
if [[ "$claude_frontmatter" == "$expected_claude_frontmatter" ]] &&
  cmp -s "$tmp/canonical-simplifier-body" "$tmp/claude-simplifier-body"; then
  pass "Claude adapter installs provider-neutral simplifier profile"
else
  fail "Claude adapter installs provider-neutral simplifier profile"
fi

claude_before="$(cksum "$claude_profile")"
"$ROOT/adapters/claude-code.sh" "$target" > /dev/null
if [[ "$(readlink "$target/CLAUDE.md" 2> /dev/null || true)" == "AGENTS.md" ]] &&
  [[ "$(cksum "$claude_profile")" == "$claude_before" ]]; then
  pass "Claude adapter accepts the exact policy alias idempotently"
else
  fail "Claude adapter accepts the exact policy alias idempotently"
fi

claude_file_conflict="$tmp/claude-file-conflict"
mkdir "$claude_file_conflict"
cp "$target/AGENTS.md" "$claude_file_conflict/AGENTS.md"
printf 'custom Claude instructions\n' > "$claude_file_conflict/CLAUDE.md"
if claude_file_error="$("$ROOT/adapters/claude-code.sh" "$claude_file_conflict" 2>&1)"; then
  fail "Claude adapter rejects a conflicting policy file"
elif grep -q 'refusing to replace existing CLAUDE.md' <<< "$claude_file_error" &&
  [[ "$(cat "$claude_file_conflict/CLAUDE.md")" == "custom Claude instructions" ]]; then
  pass "Claude adapter preserves a conflicting policy file"
else
  fail "Claude adapter preserves a conflicting policy file"
fi

claude_link_conflict="$tmp/claude-link-conflict"
mkdir "$claude_link_conflict"
cp "$target/AGENTS.md" "$claude_link_conflict/AGENTS.md"
ln -s OTHER.md "$claude_link_conflict/CLAUDE.md"
if claude_link_error="$("$ROOT/adapters/claude-code.sh" "$claude_link_conflict" 2>&1)"; then
  fail "Claude adapter rejects a conflicting policy symlink"
elif grep -q 'refusing to replace existing CLAUDE.md symlink' <<< "$claude_link_error" &&
  [[ "$(readlink "$claude_link_conflict/CLAUDE.md")" == "OTHER.md" ]]; then
  pass "Claude adapter preserves a conflicting policy symlink"
else
  fail "Claude adapter preserves a conflicting policy symlink"
fi

"$ROOT/adapters/codex.sh" "$target" > /dev/null
codex_profile="$target/.codex/agents/code-simplifier.toml"
if [[ -f "$codex_profile" ]] &&
  grep -Eq '^[[:space:]]*name[[:space:]]*=' "$codex_profile" &&
  grep -Eq '^[[:space:]]*description[[:space:]]*=' "$codex_profile" &&
  grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' "$codex_profile" &&
  grep -q 'agents/code-simplifier\.md' "$codex_profile" &&
  cmp -s "$ROOT/agents/code-simplifier.md" "$target/agents/code-simplifier.md" &&
  [[ ! -e "$target/CODEX.md" ]] &&
  ! grep -Eq '^[[:space:]]*(model|model_reasoning_effort|sandbox_mode|mcp_servers|skills\.config)[[:space:]]*=' "$codex_profile"; then
  pass "Codex adapter installs provider-neutral simplifier profile"
else
  fail "Codex adapter installs provider-neutral simplifier profile"
fi

codex_before="$(cksum "$codex_profile" "$target/agents/code-simplifier.md")"
"$ROOT/adapters/codex.sh" "$target" > /dev/null
if [[ "$(cksum "$codex_profile" "$target/agents/code-simplifier.md")" == "$codex_before" ]] &&
  [[ ! -e "$target/CODEX.md" ]]; then
  pass "Codex adapter is idempotent"
else
  fail "Codex adapter is idempotent"
fi

missing="$tmp/missing"
mkdir "$missing"
if "$ROOT/adapters/claude-code.sh" "$missing" > /dev/null 2>&1; then
  fail "Claude adapter requires vendored AGENTS.md"
else
  pass "Claude adapter requires vendored AGENTS.md"
fi
if "$ROOT/adapters/codex.sh" "$missing" > /dev/null 2>&1; then
  fail "Codex adapter requires vendored AGENTS.md"
else
  pass "Codex adapter requires vendored AGENTS.md"
fi

if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all adapter tests passed"
