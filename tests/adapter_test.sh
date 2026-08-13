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

canonical_name="$(awk '$1 == "name:" { print $2; exit }' "$ROOT/agents/code-simplifier.md")"
canonical_description="$(awk '
    /^description:/ { capture = 1; next }
    capture && /^[[:space:]]+[[:graph:]]/ {
        sub(/^[[:space:]]+/, "")
        text = text (text == "" ? "" : " ") $0
        next
    }
    capture { exit }
    END { print text }
' "$ROOT/agents/code-simplifier.md")"
toml_name="${canonical_name//\\/\\\\}"
toml_name="${toml_name//\"/\\\"}"
toml_description="${canonical_description//\\/\\\\}"
toml_description="${toml_description//\"/\\\"}"

target="$tmp/target"
mkdir "$target"
"$ROOT/vendor.sh" "$target" > /dev/null
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
expected_claude_frontmatter="name: $canonical_name"$'\n'"description: $canonical_description"
awk '
    delimiters < 2 && /^---$/ { delimiters++; next }
    delimiters >= 2 { print }
' "$ROOT/agents/code-simplifier.md" > "$tmp/canonical-simplifier-body"
awk '
    delimiters < 2 && /^---$/ { delimiters++; next }
    delimiters >= 2 { print }
' "$claude_profile" > "$tmp/claude-simplifier-body"
if [[ "$claude_frontmatter" == "$expected_claude_frontmatter" ]] &&
  cmp -s "$ROOT/agents/code-simplifier.md" "$target/agents/code-simplifier.md" &&
  cmp -s "$tmp/canonical-simplifier-body" "$tmp/claude-simplifier-body"; then
  pass "Claude adapter installs provider-neutral simplifier profile"
else
  fail "Claude adapter installs provider-neutral simplifier profile"
fi

claude_before="$(cksum "$target/CLAUDE.md" "$target/agents/code-simplifier.md" "$claude_profile")"
if "$ROOT/adapters/claude-code.sh" "$target" > /dev/null &&
  [[ "$(readlink "$target/CLAUDE.md" 2> /dev/null || true)" == "AGENTS.md" ]] &&
  [[ "$(cksum "$target/CLAUDE.md" "$target/agents/code-simplifier.md" "$claude_profile")" == "$claude_before" ]]; then
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
  grep -Fqx "name = \"$toml_name\"" "$codex_profile" &&
  grep -Fqx "description = \"$toml_description\"" "$codex_profile" &&
  grep -Eq '^[[:space:]]*developer_instructions[[:space:]]*=' "$codex_profile" &&
  grep -q 'agents/code-simplifier\.md' "$codex_profile" &&
  cmp -s "$ROOT/agents/code-simplifier.md" "$target/agents/code-simplifier.md" &&
  ! grep -Eq '^[[:space:]]*(model|model_reasoning_effort|sandbox_mode|mcp_servers|skills\.config)[[:space:]]*=' "$codex_profile"; then
  pass "Codex adapter installs provider-neutral simplifier profile"
else
  fail "Codex adapter installs provider-neutral simplifier profile"
fi

codex_before="$(cksum "$target/agents/code-simplifier.md" "$codex_profile")"
if "$ROOT/adapters/codex.sh" "$target" > /dev/null &&
  [[ "$(cksum "$target/agents/code-simplifier.md" "$codex_profile")" == "$codex_before" ]]; then
  pass "Codex adapter is idempotent"
else
  fail "Codex adapter is idempotent"
fi

claude_canonical_conflict="$tmp/claude-canonical-conflict"
mkdir -p "$claude_canonical_conflict/agents"
cp "$target/AGENTS.md" "$claude_canonical_conflict/AGENTS.md"
printf 'custom canonical Claude profile\n' > "$claude_canonical_conflict/agents/code-simplifier.md"
claude_canonical_before="$(cksum "$claude_canonical_conflict/agents/code-simplifier.md")"
if claude_canonical_error="$("$ROOT/adapters/claude-code.sh" "$claude_canonical_conflict" 2>&1)"; then
  fail "Claude adapter rejects a customized canonical profile"
elif grep -q 'refusing to replace customized' <<< "$claude_canonical_error" &&
  [[ "$(cksum "$claude_canonical_conflict/agents/code-simplifier.md")" == "$claude_canonical_before" ]]; then
  pass "Claude adapter preserves a customized canonical profile"
else
  fail "Claude adapter preserves a customized canonical profile"
fi

claude_host_conflict="$tmp/claude-host-conflict"
mkdir "$claude_host_conflict"
cp "$target/AGENTS.md" "$claude_host_conflict/AGENTS.md"
"$ROOT/adapters/claude-code.sh" "$claude_host_conflict" > /dev/null
printf 'custom Claude host profile\n' > "$claude_host_conflict/.claude/agents/code-simplifier.md"
claude_host_before="$(cksum "$claude_host_conflict/.claude/agents/code-simplifier.md")"
if claude_host_error="$("$ROOT/adapters/claude-code.sh" "$claude_host_conflict" 2>&1)"; then
  fail "Claude adapter rejects a customized host profile"
elif grep -q 'refusing to replace customized' <<< "$claude_host_error" &&
  [[ "$(cksum "$claude_host_conflict/.claude/agents/code-simplifier.md")" == "$claude_host_before" ]]; then
  pass "Claude adapter preserves a customized host profile"
else
  fail "Claude adapter preserves a customized host profile"
fi

claude_fresh_host_conflict="$tmp/claude-fresh-host-conflict"
mkdir -p "$claude_fresh_host_conflict/.claude/agents"
cp "$target/AGENTS.md" "$claude_fresh_host_conflict/AGENTS.md"
printf 'custom fresh Claude host profile\n' > "$claude_fresh_host_conflict/.claude/agents/code-simplifier.md"
claude_fresh_host_before="$(cksum "$claude_fresh_host_conflict/.claude/agents/code-simplifier.md")"
if claude_fresh_host_error="$("$ROOT/adapters/claude-code.sh" "$claude_fresh_host_conflict" 2>&1)"; then
  fail "Claude adapter rejects a fresh customized host profile"
elif grep -q 'refusing to replace customized' <<< "$claude_fresh_host_error" &&
  [[ "$(cksum "$claude_fresh_host_conflict/.claude/agents/code-simplifier.md")" == "$claude_fresh_host_before" ]] &&
  [[ ! -e "$claude_fresh_host_conflict/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_fresh_host_conflict/CLAUDE.md" ]]; then
  pass "Claude adapter leaves no declared output after a fresh host-profile conflict"
else
  fail "Claude adapter leaves no declared output after a fresh host-profile conflict"
fi

claude_dangling_host="$tmp/claude-dangling-host"
mkdir -p "$claude_dangling_host/.claude/agents"
cp "$target/AGENTS.md" "$claude_dangling_host/AGENTS.md"
ln -s custom-profile.md "$claude_dangling_host/.claude/agents/code-simplifier.md"
if claude_dangling_error="$("$ROOT/adapters/claude-code.sh" "$claude_dangling_host" 2>&1)"; then
  fail "Claude adapter rejects a dangling host-profile symlink"
elif grep -q 'refusing to replace customized' <<< "$claude_dangling_error" &&
  [[ -L "$claude_dangling_host/.claude/agents/code-simplifier.md" ]] &&
  [[ "$(readlink "$claude_dangling_host/.claude/agents/code-simplifier.md")" == "custom-profile.md" ]]; then
  pass "Claude adapter preserves a dangling host-profile symlink"
else
  fail "Claude adapter preserves a dangling host-profile symlink"
fi

codex_canonical_conflict="$tmp/codex-canonical-conflict"
mkdir "$codex_canonical_conflict"
cp "$target/AGENTS.md" "$codex_canonical_conflict/AGENTS.md"
"$ROOT/adapters/codex.sh" "$codex_canonical_conflict" > /dev/null
printf 'custom canonical Codex profile\n' > "$codex_canonical_conflict/agents/code-simplifier.md"
codex_canonical_before="$(cksum "$codex_canonical_conflict/agents/code-simplifier.md")"
if codex_canonical_error="$("$ROOT/adapters/codex.sh" "$codex_canonical_conflict" 2>&1)"; then
  fail "Codex adapter rejects a customized canonical profile"
elif grep -q 'refusing to replace customized' <<< "$codex_canonical_error" &&
  [[ "$(cksum "$codex_canonical_conflict/agents/code-simplifier.md")" == "$codex_canonical_before" ]]; then
  pass "Codex adapter preserves a customized canonical profile"
else
  fail "Codex adapter preserves a customized canonical profile"
fi

codex_toml_conflict="$tmp/codex-toml-conflict"
mkdir "$codex_toml_conflict"
cp "$target/AGENTS.md" "$codex_toml_conflict/AGENTS.md"
"$ROOT/adapters/codex.sh" "$codex_toml_conflict" > /dev/null
printf 'custom Codex TOML profile\n' > "$codex_toml_conflict/.codex/agents/code-simplifier.toml"
codex_toml_before="$(cksum "$codex_toml_conflict/.codex/agents/code-simplifier.toml")"
if codex_toml_error="$("$ROOT/adapters/codex.sh" "$codex_toml_conflict" 2>&1)"; then
  fail "Codex adapter rejects a customized TOML profile"
elif grep -q 'refusing to replace customized' <<< "$codex_toml_error" &&
  [[ "$(cksum "$codex_toml_conflict/.codex/agents/code-simplifier.toml")" == "$codex_toml_before" ]]; then
  pass "Codex adapter preserves a customized TOML profile"
else
  fail "Codex adapter preserves a customized TOML profile"
fi

codex_fresh_toml_conflict="$tmp/codex-fresh-toml-conflict"
mkdir -p "$codex_fresh_toml_conflict/.codex/agents"
cp "$target/AGENTS.md" "$codex_fresh_toml_conflict/AGENTS.md"
printf 'custom fresh Codex TOML profile\n' > "$codex_fresh_toml_conflict/.codex/agents/code-simplifier.toml"
codex_fresh_toml_before="$(cksum "$codex_fresh_toml_conflict/.codex/agents/code-simplifier.toml")"
if codex_fresh_toml_error="$("$ROOT/adapters/codex.sh" "$codex_fresh_toml_conflict" 2>&1)"; then
  fail "Codex adapter rejects a fresh customized TOML profile"
elif grep -q 'refusing to replace customized' <<< "$codex_fresh_toml_error" &&
  [[ "$(cksum "$codex_fresh_toml_conflict/.codex/agents/code-simplifier.toml")" == "$codex_fresh_toml_before" ]] &&
  [[ ! -e "$codex_fresh_toml_conflict/agents/code-simplifier.md" ]]; then
  pass "Codex adapter leaves no declared output after a fresh TOML conflict"
else
  fail "Codex adapter leaves no declared output after a fresh TOML conflict"
fi

codex_dangling_toml="$tmp/codex-dangling-toml"
mkdir -p "$codex_dangling_toml/.codex/agents"
cp "$target/AGENTS.md" "$codex_dangling_toml/AGENTS.md"
ln -s custom-profile.toml "$codex_dangling_toml/.codex/agents/code-simplifier.toml"
if codex_dangling_error="$("$ROOT/adapters/codex.sh" "$codex_dangling_toml" 2>&1)"; then
  fail "Codex adapter rejects a dangling TOML profile symlink"
elif grep -q 'refusing to replace customized' <<< "$codex_dangling_error" &&
  [[ -L "$codex_dangling_toml/.codex/agents/code-simplifier.toml" ]] &&
  [[ "$(readlink "$codex_dangling_toml/.codex/agents/code-simplifier.toml")" == "custom-profile.toml" ]]; then
  pass "Codex adapter preserves a dangling TOML profile symlink"
else
  fail "Codex adapter preserves a dangling TOML profile symlink"
fi

# Generated profiles must never be reached through symlinked output parents.
for parent in agents .claude .claude/agents; do
  fixture_name="${parent//\//-}"
  claude_parent_target="$tmp/claude-parent-$fixture_name"
  claude_parent_outside="$tmp/claude-parent-$fixture_name-outside"
  mkdir -p "$claude_parent_target" "$claude_parent_outside"
  cp "$target/AGENTS.md" "$claude_parent_target/AGENTS.md"
  case "$parent" in
    agents | .claude)
      ln -s "$claude_parent_outside" "$claude_parent_target/$parent"
      ;;
    .claude/agents)
      mkdir "$claude_parent_target/.claude"
      ln -s "$claude_parent_outside" "$claude_parent_target/.claude/agents"
      ;;
  esac
  if claude_parent_error="$("$ROOT/adapters/claude-code.sh" "$claude_parent_target" 2>&1)"; then
    fail "Claude adapter rejects symlinked $parent output parent"
  elif grep -q 'symlinked output parent' <<< "$claude_parent_error" &&
    [[ -z "$(find "$claude_parent_outside" -mindepth 1 -print -quit)" ]] &&
    [[ ! -e "$claude_parent_target/CLAUDE.md" && ! -L "$claude_parent_target/CLAUDE.md" ]] &&
    [[ ! -e "$claude_parent_target/agents/code-simplifier.md" ]] &&
    [[ ! -e "$claude_parent_target/.claude/agents/code-simplifier.md" ]]; then
    pass "Claude adapter contains symlinked $parent output parent"
  else
    fail "Claude adapter contains symlinked $parent output parent"
  fi
done

for parent in agents .codex .codex/agents; do
  fixture_name="${parent//\//-}"
  codex_parent_target="$tmp/codex-parent-$fixture_name"
  codex_parent_outside="$tmp/codex-parent-$fixture_name-outside"
  mkdir -p "$codex_parent_target" "$codex_parent_outside"
  cp "$target/AGENTS.md" "$codex_parent_target/AGENTS.md"
  case "$parent" in
    agents | .codex)
      ln -s "$codex_parent_outside" "$codex_parent_target/$parent"
      ;;
    .codex/agents)
      mkdir "$codex_parent_target/.codex"
      ln -s "$codex_parent_outside" "$codex_parent_target/.codex/agents"
      ;;
  esac
  if codex_parent_error="$("$ROOT/adapters/codex.sh" "$codex_parent_target" 2>&1)"; then
    fail "Codex adapter rejects symlinked $parent output parent"
  elif grep -q 'symlinked output parent' <<< "$codex_parent_error" &&
    [[ -z "$(find "$codex_parent_outside" -mindepth 1 -print -quit)" ]] &&
    [[ ! -e "$codex_parent_target/agents/code-simplifier.md" ]] &&
    [[ ! -e "$codex_parent_target/.codex/agents/code-simplifier.toml" ]]; then
    pass "Codex adapter contains symlinked $parent output parent"
  else
    fail "Codex adapter contains symlinked $parent output parent"
  fi
done

# Byte-identical symlinks at generated-profile leaves remain customized artifacts.
claude_canonical_link="$tmp/claude-identical-canonical-link"
mkdir -p "$claude_canonical_link/agents"
cp "$target/AGENTS.md" "$claude_canonical_link/AGENTS.md"
ln -s "$ROOT/agents/code-simplifier.md" "$claude_canonical_link/agents/code-simplifier.md"
if claude_canonical_link_error="$("$ROOT/adapters/claude-code.sh" "$claude_canonical_link" 2>&1)"; then
  fail "Claude adapter rejects a byte-identical canonical-profile symlink"
elif grep -q 'refusing to replace customized' <<< "$claude_canonical_link_error" &&
  [[ -L "$claude_canonical_link/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_canonical_link/.claude/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_canonical_link/CLAUDE.md" && ! -L "$claude_canonical_link/CLAUDE.md" ]]; then
  pass "Claude adapter preserves a byte-identical canonical-profile symlink"
else
  fail "Claude adapter preserves a byte-identical canonical-profile symlink"
fi

claude_host_link="$tmp/claude-identical-host-link"
mkdir -p "$claude_host_link/.claude/agents"
cp "$target/AGENTS.md" "$claude_host_link/AGENTS.md"
ln -s "$claude_profile" "$claude_host_link/.claude/agents/code-simplifier.md"
if claude_host_link_error="$("$ROOT/adapters/claude-code.sh" "$claude_host_link" 2>&1)"; then
  fail "Claude adapter rejects a byte-identical host-profile symlink"
elif grep -q 'refusing to replace customized' <<< "$claude_host_link_error" &&
  [[ -L "$claude_host_link/.claude/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_host_link/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_host_link/CLAUDE.md" && ! -L "$claude_host_link/CLAUDE.md" ]]; then
  pass "Claude adapter preserves a byte-identical host-profile symlink"
else
  fail "Claude adapter preserves a byte-identical host-profile symlink"
fi

codex_canonical_link="$tmp/codex-identical-canonical-link"
mkdir -p "$codex_canonical_link/agents"
cp "$target/AGENTS.md" "$codex_canonical_link/AGENTS.md"
ln -s "$ROOT/agents/code-simplifier.md" "$codex_canonical_link/agents/code-simplifier.md"
if codex_canonical_link_error="$("$ROOT/adapters/codex.sh" "$codex_canonical_link" 2>&1)"; then
  fail "Codex adapter rejects a byte-identical canonical-profile symlink"
elif grep -q 'refusing to replace customized' <<< "$codex_canonical_link_error" &&
  [[ -L "$codex_canonical_link/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_canonical_link/.codex/agents/code-simplifier.toml" ]]; then
  pass "Codex adapter preserves a byte-identical canonical-profile symlink"
else
  fail "Codex adapter preserves a byte-identical canonical-profile symlink"
fi

codex_host_link="$tmp/codex-identical-host-link"
mkdir -p "$codex_host_link/.codex/agents"
cp "$target/AGENTS.md" "$codex_host_link/AGENTS.md"
ln -s "$codex_profile" "$codex_host_link/.codex/agents/code-simplifier.toml"
if codex_host_link_error="$("$ROOT/adapters/codex.sh" "$codex_host_link" 2>&1)"; then
  fail "Codex adapter rejects a byte-identical TOML-profile symlink"
elif grep -q 'refusing to replace customized' <<< "$codex_host_link_error" &&
  [[ -L "$codex_host_link/.codex/agents/code-simplifier.toml" ]] &&
  [[ ! -e "$codex_host_link/agents/code-simplifier.md" ]]; then
  pass "Codex adapter preserves a byte-identical TOML-profile symlink"
else
  fail "Codex adapter preserves a byte-identical TOML-profile symlink"
fi

# A partial staging copy must never become a declared output.
partial_cp_bin="$tmp/partial-cp-bin"
mkdir "$partial_cp_bin"
cat > "$partial_cp_bin/cp" << 'EOF'
#!/usr/bin/env bash
printf 'partial copy\n' > "$2"
exit 1
EOF
chmod +x "$partial_cp_bin/cp"

claude_cp_failure="$tmp/claude-cp-failure"
mkdir "$claude_cp_failure"
cp "$target/AGENTS.md" "$claude_cp_failure/AGENTS.md"
if PATH="$partial_cp_bin:$PATH" "$ROOT/adapters/claude-code.sh" "$claude_cp_failure" > /dev/null 2>&1; then
  fail "Claude adapter aborts after a partial staging copy"
elif [[ ! -e "$claude_cp_failure/CLAUDE.md" && ! -L "$claude_cp_failure/CLAUDE.md" ]] &&
  [[ ! -e "$claude_cp_failure/agents/code-simplifier.md" && ! -L "$claude_cp_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_cp_failure/.claude/agents/code-simplifier.md" && ! -L "$claude_cp_failure/.claude/agents/code-simplifier.md" ]] &&
  [[ -z "$(find "$claude_cp_failure" -name '*.stage.*' -print -quit)" ]]; then
  pass "Claude adapter cleans a partial staging copy"
else
  fail "Claude adapter cleans a partial staging copy"
fi

codex_cp_failure="$tmp/codex-cp-failure"
mkdir "$codex_cp_failure"
cp "$target/AGENTS.md" "$codex_cp_failure/AGENTS.md"
if PATH="$partial_cp_bin:$PATH" "$ROOT/adapters/codex.sh" "$codex_cp_failure" > /dev/null 2>&1; then
  fail "Codex adapter aborts after a partial staging copy"
elif [[ ! -e "$codex_cp_failure/agents/code-simplifier.md" && ! -L "$codex_cp_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_cp_failure/.codex/agents/code-simplifier.toml" && ! -L "$codex_cp_failure/.codex/agents/code-simplifier.toml" ]] &&
  [[ -z "$(find "$codex_cp_failure" -name '*.stage.*' -print -quit)" ]]; then
  pass "Codex adapter cleans a partial staging copy"
else
  fail "Codex adapter cleans a partial staging copy"
fi

# Failure on the second atomic publish must roll back the first publish and Claude alias.
real_mv="$(command -v mv)"
second_mv_bin="$tmp/second-mv-bin"
mkdir "$second_mv_bin"
cat > "$second_mv_bin/mv" << 'EOF'
#!/usr/bin/env bash
set -eu
count=0
if [[ -f "$MV_COUNT_FILE" ]]; then
  count="$(cat "$MV_COUNT_FILE")"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"
if [[ "$count" -eq 2 ]]; then
  exit 1
fi
exec "$REAL_MV" "$@"
EOF
chmod +x "$second_mv_bin/mv"

claude_mv_failure="$tmp/claude-mv-failure"
mkdir "$claude_mv_failure"
cp "$target/AGENTS.md" "$claude_mv_failure/AGENTS.md"
claude_mv_count="$tmp/claude-mv-count"
if MV_COUNT_FILE="$claude_mv_count" REAL_MV="$real_mv" PATH="$second_mv_bin:$PATH" \
  "$ROOT/adapters/claude-code.sh" "$claude_mv_failure" > /dev/null 2>&1; then
  fail "Claude adapter aborts when the second publish fails"
elif [[ ! -e "$claude_mv_failure/CLAUDE.md" && ! -L "$claude_mv_failure/CLAUDE.md" ]] &&
  [[ ! -e "$claude_mv_failure/agents/code-simplifier.md" && ! -L "$claude_mv_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_mv_failure/.claude/agents/code-simplifier.md" && ! -L "$claude_mv_failure/.claude/agents/code-simplifier.md" ]] &&
  [[ -z "$(find "$claude_mv_failure" -name '*.stage.*' -print -quit)" ]]; then
  pass "Claude adapter rolls back a failed publish transaction"
else
  fail "Claude adapter rolls back a failed publish transaction"
fi

codex_mv_failure="$tmp/codex-mv-failure"
mkdir "$codex_mv_failure"
cp "$target/AGENTS.md" "$codex_mv_failure/AGENTS.md"
codex_mv_count="$tmp/codex-mv-count"
if MV_COUNT_FILE="$codex_mv_count" REAL_MV="$real_mv" PATH="$second_mv_bin:$PATH" \
  "$ROOT/adapters/codex.sh" "$codex_mv_failure" > /dev/null 2>&1; then
  fail "Codex adapter aborts when the second publish fails"
elif [[ ! -e "$codex_mv_failure/agents/code-simplifier.md" && ! -L "$codex_mv_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_mv_failure/.codex/agents/code-simplifier.toml" && ! -L "$codex_mv_failure/.codex/agents/code-simplifier.toml" ]] &&
  [[ -z "$(find "$codex_mv_failure" -name '*.stage.*' -print -quit)" ]]; then
  pass "Codex adapter rolls back a failed publish transaction"
else
  fail "Codex adapter rolls back a failed publish transaction"
fi

# Rollback removes only outputs created by that invocation.
first_mv_bin="$tmp/first-mv-bin"
mkdir "$first_mv_bin"
cat > "$first_mv_bin/mv" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$first_mv_bin/mv"

claude_existing="$tmp/claude-existing-before-failure"
mkdir -p "$claude_existing/agents"
cp "$target/AGENTS.md" "$claude_existing/AGENTS.md"
cp "$ROOT/agents/code-simplifier.md" "$claude_existing/agents/code-simplifier.md"
ln -s AGENTS.md "$claude_existing/CLAUDE.md"
claude_existing_before="$(cksum "$claude_existing/agents/code-simplifier.md")"
if PATH="$first_mv_bin:$PATH" "$ROOT/adapters/claude-code.sh" "$claude_existing" > /dev/null 2>&1; then
  fail "Claude adapter reports a host publish failure with pre-existing outputs"
elif [[ "$(cksum "$claude_existing/agents/code-simplifier.md")" == "$claude_existing_before" ]] &&
  [[ "$(readlink "$claude_existing/CLAUDE.md")" == "AGENTS.md" ]] &&
  [[ ! -e "$claude_existing/.claude/agents/code-simplifier.md" ]]; then
  pass "Claude adapter preserves pre-existing outputs during rollback"
else
  fail "Claude adapter preserves pre-existing outputs during rollback"
fi

codex_existing="$tmp/codex-existing-before-failure"
mkdir -p "$codex_existing/agents"
cp "$target/AGENTS.md" "$codex_existing/AGENTS.md"
cp "$ROOT/agents/code-simplifier.md" "$codex_existing/agents/code-simplifier.md"
codex_existing_before="$(cksum "$codex_existing/agents/code-simplifier.md")"
if PATH="$first_mv_bin:$PATH" "$ROOT/adapters/codex.sh" "$codex_existing" > /dev/null 2>&1; then
  fail "Codex adapter reports a TOML publish failure with a pre-existing output"
elif [[ "$(cksum "$codex_existing/agents/code-simplifier.md")" == "$codex_existing_before" ]] &&
  [[ ! -e "$codex_existing/.codex/agents/code-simplifier.toml" ]]; then
  pass "Codex adapter preserves a pre-existing output during rollback"
else
  fail "Codex adapter preserves a pre-existing output during rollback"
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
