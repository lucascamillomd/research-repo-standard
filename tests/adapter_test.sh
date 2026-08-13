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
tmp="$(cd "$tmp" && pwd -P)"
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
  [[ "$(cksum "$target/CLAUDE.md" "$target/agents/code-simplifier.md" "$claude_profile")" == "$claude_before" ]] &&
  [[ ! -e "$target/.research-repo-standard-adapter.lock" && ! -L "$target/.research-repo-standard-adapter.lock" ]]; then
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
  [[ "$(cksum "$target/agents/code-simplifier.md" "$codex_profile")" == "$codex_before" ]] &&
  [[ ! -e "$target/.research-repo-standard-adapter.lock" && ! -L "$target/.research-repo-standard-adapter.lock" ]]; then
  pass "Codex adapter is idempotent"
else
  fail "Codex adapter is idempotent"
fi

# Claude and Codex must serialize through one target-local lock.
real_cp="$(command -v cp)"
blocking_cp_bin="$tmp/blocking-cp-bin"
mkdir "$blocking_cp_bin"
cat > "$blocking_cp_bin/cp" << 'EOF'
#!/usr/bin/env bash
set -eu
printf 'owner reached staging copy\n' > "$BLOCK_READY"
while [[ ! -f "$BLOCK_RELEASE" ]]; do
  sleep 0.01
done
exec "$REAL_CP" "$@"
EOF
chmod +x "$blocking_cp_bin/cp"

shared_lock_target="$tmp/shared lock target"
mkdir "$shared_lock_target"
cp "$target/AGENTS.md" "$shared_lock_target/AGENTS.md"
shared_lock="$shared_lock_target/.research-repo-standard-adapter.lock"
block_ready="$tmp/block-ready"
block_release="$tmp/block-release"
BLOCK_READY="$block_ready" BLOCK_RELEASE="$block_release" REAL_CP="$real_cp" \
  PATH="$blocking_cp_bin:$PATH" "$ROOT/adapters/claude-code.sh" "$shared_lock_target" \
    > "$tmp/shared-lock-owner.out" 2>&1 &
lock_owner_pid=$!
lock_ready=0
for ((attempt = 0; attempt < 500; attempt++)); do
  if [[ -f "$block_ready" && -L "$shared_lock" ]]; then
    lock_ready=1
    break
  fi
  sleep 0.01
done
lock_token_before="$(readlink "$shared_lock" 2> /dev/null || true)"
contender_status=0
contender_error="$("$ROOT/adapters/codex.sh" "$shared_lock_target" 2>&1)" || contender_status=$?
lock_token_after="$(readlink "$shared_lock" 2> /dev/null || true)"
if ((lock_ready)) && [[ "$lock_token_before" == "$lock_owner_pid:claude-code.sh" ]] &&
  [[ "$contender_status" -ne 0 ]] &&
  grep -q "adapter installation already in progress: $lock_token_before" <<< "$contender_error" &&
  [[ "$lock_token_after" == "$lock_token_before" ]] &&
  [[ ! -e "$shared_lock_target/.codex" && ! -L "$shared_lock_target/.codex" ]]; then
  pass "Claude and Codex adapters contend on one live lock"
else
  fail "Claude and Codex adapters contend on one live lock"
fi
touch "$block_release"
lock_owner_status=0
wait "$lock_owner_pid" || lock_owner_status=$?
if [[ "$lock_owner_status" -eq 0 ]] &&
  [[ ! -e "$shared_lock" && ! -L "$shared_lock" ]] &&
  [[ -f "$shared_lock_target/agents/code-simplifier.md" ]] &&
  [[ -f "$shared_lock_target/.claude/agents/code-simplifier.md" ]] &&
  [[ "$(readlink "$shared_lock_target/CLAUDE.md" 2> /dev/null || true)" == "AGENTS.md" ]]; then
  pass "Adapter releases its live lock after success"
else
  fail "Adapter releases its live lock after success"
fi

stale_lock_target="$tmp/stale-lock-target"
mkdir "$stale_lock_target"
cp "$target/AGENTS.md" "$stale_lock_target/AGENTS.md"
ln -s '99999999:claude-code.sh' "$stale_lock_target/.research-repo-standard-adapter.lock"
if "$ROOT/adapters/codex.sh" "$stale_lock_target" > /dev/null &&
  [[ ! -e "$stale_lock_target/.research-repo-standard-adapter.lock" ]] &&
  [[ ! -L "$stale_lock_target/.research-repo-standard-adapter.lock" ]] &&
  [[ -f "$stale_lock_target/agents/code-simplifier.md" ]] &&
  [[ -f "$stale_lock_target/.codex/agents/code-simplifier.toml" ]]; then
  pass "Adapter safely reclaims a verifiably stale lock"
else
  fail "Adapter safely reclaims a verifiably stale lock"
fi

unknown_lock_target="$tmp/unknown-lock-target"
mkdir "$unknown_lock_target"
cp "$target/AGENTS.md" "$unknown_lock_target/AGENTS.md"
ln -s 'unknown-owner' "$unknown_lock_target/.research-repo-standard-adapter.lock"
unknown_lock_status=0
unknown_lock_error="$("$ROOT/adapters/claude-code.sh" "$unknown_lock_target" 2>&1)" ||
  unknown_lock_status=$?
if [[ "$unknown_lock_status" -ne 0 ]] &&
  grep -q 'cannot verify adapter lock owner: unknown-owner' <<< "$unknown_lock_error" &&
  [[ "$(readlink "$unknown_lock_target/.research-repo-standard-adapter.lock")" == "unknown-owner" ]] &&
  [[ ! -e "$unknown_lock_target/agents" && ! -L "$unknown_lock_target/agents" ]] &&
  [[ ! -e "$unknown_lock_target/.claude" && ! -L "$unknown_lock_target/.claude" ]]; then
  pass "Adapter preserves an unverifiable lock before creating output parents"
else
  fail "Adapter preserves an unverifiable lock before creating output parents"
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
  [[ -z "$(find "$claude_cp_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ ! -e "$claude_cp_failure/.research-repo-standard-adapter.lock" && ! -L "$claude_cp_failure/.research-repo-standard-adapter.lock" ]]; then
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
  [[ -z "$(find "$codex_cp_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ ! -e "$codex_cp_failure/.research-repo-standard-adapter.lock" && ! -L "$codex_cp_failure/.research-repo-standard-adapter.lock" ]]; then
  pass "Codex adapter cleans a partial staging copy"
else
  fail "Codex adapter cleans a partial staging copy"
fi

# A post-effect failure or signal must roll back every publish owned by the invocation.
real_mv="$(command -v mv)"
post_effect_mv_bin="$tmp/post-effect-mv-bin"
mkdir "$post_effect_mv_bin"
cat > "$post_effect_mv_bin/mv" << 'EOF'
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$MV_COUNT_FILE" ]] || count="$(cat "$MV_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"
source_inode="$(LC_ALL=C ls -di "$1" | awk '{ print $1 }')"
if ! "$REAL_MV" "$@"; then
  printf 'real-mv-failed count=%s\n' "$count" > "$MV_EFFECT_MARKER"
  exit 1
fi
if [[ "$count" -eq "$FAIL_ON_COUNT" ]]; then
  destination_inode="$(LC_ALL=C ls -di "$2" | awk '{ print $1 }')"
  if [[ "$2" != "$EXPECTED_DESTINATION" || "$destination_inode" != "$source_inode" ]]; then
    printf 'unexpected-effect count=%s source_inode=%s destination_inode=%s destination=%s\n' \
      "$count" "$source_inode" "$destination_inode" "$2" > "$MV_EFFECT_MARKER"
    exit 1
  fi
  if [[ "$FAULT_MODE" == "signal" ]]; then
    if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ]]; then
      printf 'unexpected-parent count=%s expected=%s actual=%s\n' \
        "$count" "$EXPECTED_ADAPTER_PID" "$PPID" > "$MV_EFFECT_MARKER"
      exit 1
    fi
    printf 'post-effect signal count=%s inode=%s\n' "$count" "$destination_inode" > "$MV_EFFECT_MARKER"
    if ! kill -TERM "$PPID"; then
      printf 'signal-delivery-failed count=%s pid=%s\n' "$count" "$PPID" > "$MV_EFFECT_MARKER"
      exit 1
    fi
    exit 0
  fi
  printf 'post-effect count=%s inode=%s\n' "$count" "$destination_inode" > "$MV_EFFECT_MARKER"
  exit 1
fi
EOF
chmod +x "$post_effect_mv_bin/mv"

claude_effect_failure="$tmp/claude effect failure"
mkdir "$claude_effect_failure"
cp "$target/AGENTS.md" "$claude_effect_failure/AGENTS.md"
claude_effect_policy_before="$(cksum "$claude_effect_failure/AGENTS.md")"
claude_effect_policy_inode="$(LC_ALL=C ls -di "$claude_effect_failure/AGENTS.md" | awk '{ print $1 }')"
claude_effect_count="$tmp/claude-effect-count"
claude_effect_marker="$tmp/claude-effect-marker"
claude_effect_status=0
MV_COUNT_FILE="$claude_effect_count" MV_EFFECT_MARKER="$claude_effect_marker" \
  EXPECTED_DESTINATION="$claude_effect_failure/CLAUDE.md" FAIL_ON_COUNT=3 FAULT_MODE=fail \
  REAL_MV="$real_mv" PATH="$post_effect_mv_bin:$PATH" \
  bash -c 'export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/claude-code.sh" "$claude_effect_failure" > /dev/null 2>&1 ||
  claude_effect_status=$?
if [[ "$claude_effect_status" -ne 0 ]] &&
  [[ -f "$claude_effect_count" ]] && [[ "$(cat "$claude_effect_count")" == "3" ]] &&
  [[ -f "$claude_effect_marker" ]] &&
  grep -Eq '^post-effect count=3 inode=[0-9]+$' "$claude_effect_marker" &&
  [[ "$(cksum "$claude_effect_failure/AGENTS.md")" == "$claude_effect_policy_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$claude_effect_failure/AGENTS.md" | awk '{ print $1 }')" == "$claude_effect_policy_inode" ]] &&
  [[ ! -e "$claude_effect_failure/CLAUDE.md" && ! -L "$claude_effect_failure/CLAUDE.md" ]] &&
  [[ ! -e "$claude_effect_failure/agents/code-simplifier.md" && ! -L "$claude_effect_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_effect_failure/.claude/agents/code-simplifier.md" && ! -L "$claude_effect_failure/.claude/agents/code-simplifier.md" ]] &&
  [[ -z "$(find "$claude_effect_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ -z "$(find "$claude_effect_failure" -mindepth 1 ! -path "$claude_effect_failure/AGENTS.md" -print -quit)" ]]; then
  pass "Claude adapter rolls back a post-effect publish failure"
else
  fail "Claude adapter rolls back a post-effect publish failure"
fi

codex_effect_failure="$tmp/codex effect failure"
mkdir "$codex_effect_failure"
cp "$target/AGENTS.md" "$codex_effect_failure/AGENTS.md"
codex_effect_policy_before="$(cksum "$codex_effect_failure/AGENTS.md")"
codex_effect_policy_inode="$(LC_ALL=C ls -di "$codex_effect_failure/AGENTS.md" | awk '{ print $1 }')"
codex_effect_count="$tmp/codex-effect-count"
codex_effect_marker="$tmp/codex-effect-marker"
codex_effect_status=0
MV_COUNT_FILE="$codex_effect_count" MV_EFFECT_MARKER="$codex_effect_marker" \
  EXPECTED_DESTINATION="$codex_effect_failure/.codex/agents/code-simplifier.toml" \
  FAIL_ON_COUNT=2 FAULT_MODE=fail REAL_MV="$real_mv" PATH="$post_effect_mv_bin:$PATH" \
  bash -c 'export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/codex.sh" "$codex_effect_failure" > /dev/null 2>&1 || codex_effect_status=$?
if [[ "$codex_effect_status" -ne 0 ]] &&
  [[ -f "$codex_effect_count" ]] && [[ "$(cat "$codex_effect_count")" == "2" ]] &&
  [[ -f "$codex_effect_marker" ]] &&
  grep -Eq '^post-effect count=2 inode=[0-9]+$' "$codex_effect_marker" &&
  [[ "$(cksum "$codex_effect_failure/AGENTS.md")" == "$codex_effect_policy_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$codex_effect_failure/AGENTS.md" | awk '{ print $1 }')" == "$codex_effect_policy_inode" ]] &&
  [[ ! -e "$codex_effect_failure/agents/code-simplifier.md" && ! -L "$codex_effect_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_effect_failure/.codex/agents/code-simplifier.toml" && ! -L "$codex_effect_failure/.codex/agents/code-simplifier.toml" ]] &&
  [[ -z "$(find "$codex_effect_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ -z "$(find "$codex_effect_failure" -mindepth 1 ! -path "$codex_effect_failure/AGENTS.md" -print -quit)" ]]; then
  pass "Codex adapter rolls back a post-effect publish failure"
else
  fail "Codex adapter rolls back a post-effect publish failure"
fi

claude_signal_failure="$tmp/claude signal failure"
mkdir "$claude_signal_failure"
cp "$target/AGENTS.md" "$claude_signal_failure/AGENTS.md"
claude_signal_policy_before="$(cksum "$claude_signal_failure/AGENTS.md")"
claude_signal_policy_inode="$(LC_ALL=C ls -di "$claude_signal_failure/AGENTS.md" | awk '{ print $1 }')"
claude_signal_count="$tmp/claude-signal-count"
claude_signal_marker="$tmp/claude-signal-marker"
claude_signal_status=0
MV_COUNT_FILE="$claude_signal_count" MV_EFFECT_MARKER="$claude_signal_marker" \
  EXPECTED_DESTINATION="$claude_signal_failure/CLAUDE.md" FAIL_ON_COUNT=3 FAULT_MODE=signal \
  REAL_MV="$real_mv" PATH="$post_effect_mv_bin:$PATH" \
  bash -c 'export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/claude-code.sh" "$claude_signal_failure" > /dev/null 2>&1 ||
  claude_signal_status=$?
if [[ "$claude_signal_status" -ne 0 ]] &&
  [[ -f "$claude_signal_count" ]] && [[ "$(cat "$claude_signal_count")" == "3" ]] &&
  [[ -f "$claude_signal_marker" ]] &&
  grep -Eq '^post-effect signal count=3 inode=[0-9]+$' "$claude_signal_marker" &&
  [[ "$(cksum "$claude_signal_failure/AGENTS.md")" == "$claude_signal_policy_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$claude_signal_failure/AGENTS.md" | awk '{ print $1 }')" == "$claude_signal_policy_inode" ]] &&
  [[ ! -e "$claude_signal_failure/CLAUDE.md" && ! -L "$claude_signal_failure/CLAUDE.md" ]] &&
  [[ ! -e "$claude_signal_failure/agents/code-simplifier.md" && ! -L "$claude_signal_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$claude_signal_failure/.claude/agents/code-simplifier.md" && ! -L "$claude_signal_failure/.claude/agents/code-simplifier.md" ]] &&
  [[ -z "$(find "$claude_signal_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ -z "$(find "$claude_signal_failure" -mindepth 1 ! -path "$claude_signal_failure/AGENTS.md" -print -quit)" ]]; then
  pass "Claude adapter rolls back after a post-effect TERM"
else
  fail "Claude adapter rolls back after a post-effect TERM"
fi

codex_signal_failure="$tmp/codex signal failure"
mkdir "$codex_signal_failure"
cp "$target/AGENTS.md" "$codex_signal_failure/AGENTS.md"
codex_signal_policy_before="$(cksum "$codex_signal_failure/AGENTS.md")"
codex_signal_policy_inode="$(LC_ALL=C ls -di "$codex_signal_failure/AGENTS.md" | awk '{ print $1 }')"
codex_signal_count="$tmp/codex-signal-count"
codex_signal_marker="$tmp/codex-signal-marker"
codex_signal_status=0
MV_COUNT_FILE="$codex_signal_count" MV_EFFECT_MARKER="$codex_signal_marker" \
  EXPECTED_DESTINATION="$codex_signal_failure/.codex/agents/code-simplifier.toml" \
  FAIL_ON_COUNT=2 FAULT_MODE=signal REAL_MV="$real_mv" PATH="$post_effect_mv_bin:$PATH" \
  bash -c 'export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/codex.sh" "$codex_signal_failure" > /dev/null 2>&1 || codex_signal_status=$?
if [[ "$codex_signal_status" -ne 0 ]] &&
  [[ -f "$codex_signal_count" ]] && [[ "$(cat "$codex_signal_count")" == "2" ]] &&
  [[ -f "$codex_signal_marker" ]] &&
  grep -Eq '^post-effect signal count=2 inode=[0-9]+$' "$codex_signal_marker" &&
  [[ "$(cksum "$codex_signal_failure/AGENTS.md")" == "$codex_signal_policy_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$codex_signal_failure/AGENTS.md" | awk '{ print $1 }')" == "$codex_signal_policy_inode" ]] &&
  [[ ! -e "$codex_signal_failure/agents/code-simplifier.md" && ! -L "$codex_signal_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_signal_failure/.codex/agents/code-simplifier.toml" && ! -L "$codex_signal_failure/.codex/agents/code-simplifier.toml" ]] &&
  [[ -z "$(find "$codex_signal_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ -z "$(find "$codex_signal_failure" -mindepth 1 ! -path "$codex_signal_failure/AGENTS.md" -print -quit)" ]]; then
  pass "Codex adapter rolls back after a post-effect TERM"
else
  fail "Codex adapter rolls back after a post-effect TERM"
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
claude_existing_inode="$(LC_ALL=C ls -di "$claude_existing/agents/code-simplifier.md" | awk '{ print $1 }')"
claude_existing_alias_inode="$(LC_ALL=C ls -di "$claude_existing/CLAUDE.md" | awk '{ print $1 }')"
if PATH="$first_mv_bin:$PATH" "$ROOT/adapters/claude-code.sh" "$claude_existing" > /dev/null 2>&1; then
  fail "Claude adapter reports a host publish failure with pre-existing outputs"
elif [[ "$(cksum "$claude_existing/agents/code-simplifier.md")" == "$claude_existing_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$claude_existing/agents/code-simplifier.md" | awk '{ print $1 }')" == "$claude_existing_inode" ]] &&
  [[ "$(LC_ALL=C ls -di "$claude_existing/CLAUDE.md" | awk '{ print $1 }')" == "$claude_existing_alias_inode" ]] &&
  [[ "$(readlink "$claude_existing/CLAUDE.md")" == "AGENTS.md" ]] &&
  [[ ! -e "$claude_existing/.claude" && ! -L "$claude_existing/.claude" ]] &&
  [[ -z "$(find "$claude_existing" -name '*.stage.*' -print -quit)" ]] &&
  [[ ! -e "$claude_existing/.research-repo-standard-adapter.lock" && ! -L "$claude_existing/.research-repo-standard-adapter.lock" ]]; then
  pass "Claude adapter preserves pre-existing outputs during rollback"
else
  fail "Claude adapter preserves pre-existing outputs during rollback"
fi

codex_existing="$tmp/codex-existing-before-failure"
mkdir -p "$codex_existing/agents"
cp "$target/AGENTS.md" "$codex_existing/AGENTS.md"
cp "$ROOT/agents/code-simplifier.md" "$codex_existing/agents/code-simplifier.md"
codex_existing_before="$(cksum "$codex_existing/agents/code-simplifier.md")"
codex_existing_inode="$(LC_ALL=C ls -di "$codex_existing/agents/code-simplifier.md" | awk '{ print $1 }')"
if PATH="$first_mv_bin:$PATH" "$ROOT/adapters/codex.sh" "$codex_existing" > /dev/null 2>&1; then
  fail "Codex adapter reports a TOML publish failure with a pre-existing output"
elif [[ "$(cksum "$codex_existing/agents/code-simplifier.md")" == "$codex_existing_before" ]] &&
  [[ "$(LC_ALL=C ls -di "$codex_existing/agents/code-simplifier.md" | awk '{ print $1 }')" == "$codex_existing_inode" ]] &&
  [[ ! -e "$codex_existing/.codex" && ! -L "$codex_existing/.codex" ]] &&
  [[ -z "$(find "$codex_existing" -name '*.stage.*' -print -quit)" ]] &&
  [[ ! -e "$codex_existing/.research-repo-standard-adapter.lock" && ! -L "$codex_existing/.research-repo-standard-adapter.lock" ]]; then
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
