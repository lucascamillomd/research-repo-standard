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
inode_of() {
  LC_ALL=C ls -di "$1" | awk '{ print $1 }'
}

serialization_is_retained() {
  serialization_fixture=$1
  serialization_lock="$serialization_fixture/.research-repo-standard-adapter.lock"
  serialization_guard="$serialization_fixture/.research-repo-standard-adapter.guard"
  [[ -d "$serialization_lock" && ! -L "$serialization_lock" ]] || return 1
  [[ -f "$serialization_lock/owner" && ! -L "$serialization_lock/owner" ]] || return 1
  [[ -f "$serialization_guard" && ! -L "$serialization_guard" ]] || return 1
  serialization_owner_inode="$(inode_of "$serialization_lock/owner")"
  serialization_guard_inode="$(inode_of "$serialization_guard")"
  [[ "$serialization_owner_inode" == "$serialization_guard_inode" ]] || return 1
  serialization_claim="$(find "$serialization_fixture" -maxdepth 2 \
    -path "$serialization_fixture/.research-repo-standard-adapter.claim.*/owner" -print -quit)"
  [[ -n "$serialization_claim" && -f "$serialization_claim" && ! -L "$serialization_claim" ]] ||
    return 1
  [[ "$(inode_of "$serialization_claim")" == "$serialization_guard_inode" ]]
}

path_fingerprint() {
  fingerprint_path=$1
  if [[ -L "$fingerprint_path" ]]; then
    printf 'link|%s|%s\n' "$(inode_of "$fingerprint_path")" "$(readlink "$fingerprint_path")"
  elif [[ -f "$fingerprint_path" ]]; then
    printf 'file|%s|%s\n' "$(inode_of "$fingerprint_path")" "$(cksum "$fingerprint_path")"
  elif [[ -d "$fingerprint_path" ]]; then
    printf 'directory|%s\n' "$(inode_of "$fingerprint_path")"
    find "$fingerprint_path" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort |
      while IFS= read -r fingerprint_child; do
        printf '%s|' "$(basename "$fingerprint_child")"
        if [[ -L "$fingerprint_child" ]]; then
          printf 'link|%s|%s\n' "$(inode_of "$fingerprint_child")" \
            "$(readlink "$fingerprint_child")"
        elif [[ -f "$fingerprint_child" ]]; then
          printf 'file|%s|%s\n' "$(inode_of "$fingerprint_child")" \
            "$(cksum "$fingerprint_child")"
        elif [[ -d "$fingerprint_child" ]]; then
          printf 'directory|%s\n' "$(inode_of "$fingerprint_child")"
        else
          printf 'other|%s\n' "$(inode_of "$fingerprint_child")"
        fi
      done
  elif [[ -e "$fingerprint_path" ]]; then
    printf 'other|%s\n' "$(inode_of "$fingerprint_path")"
  else
    printf 'absent\n'
  fi
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
count=0
[[ ! -f "$BLOCK_COUNT" ]] || count="$(cat "$BLOCK_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$BLOCK_COUNT"
printf 'blocking-copy\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
  "$count" "$1" "$2" "$PPID" > "$BLOCK_READY"
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
shared_lock_owner="$shared_lock/owner"
block_ready="$tmp/block-ready"
block_release="$tmp/block-release"
block_count="$tmp/block-count"
BLOCK_READY="$block_ready" BLOCK_RELEASE="$block_release" BLOCK_COUNT="$block_count" REAL_CP="$real_cp" \
  PATH="$blocking_cp_bin:$PATH" "$ROOT/adapters/claude-code.sh" "$shared_lock_target" \
    > "$tmp/shared-lock-owner.out" 2>&1 &
lock_owner_pid=$!
lock_ready=0
for ((attempt = 0; attempt < 500; attempt++)); do
  if [[ -f "$block_ready" && -d "$shared_lock" && ! -L "$shared_lock" && -f "$shared_lock_owner" ]]; then
    lock_ready=1
    break
  fi
  sleep 0.01
done
lock_token_before="$(cat "$shared_lock_owner" 2> /dev/null || true)"
lock_owner_inode_before="$(inode_of "$shared_lock_owner" 2> /dev/null)"
contender_status=0
contender_error="$("$ROOT/adapters/codex.sh" "$shared_lock_target" 2>&1)" || contender_status=$?
lock_token_after="$(cat "$shared_lock_owner" 2> /dev/null || true)"
lock_owner_inode_after="$(inode_of "$shared_lock_owner" 2> /dev/null)"
if ((lock_ready)) && [[ "$lock_token_before" =~ ^${lock_owner_pid}:claude-code\.sh:[0-9]+-[0-9]+-[0-9]+$ ]] &&
  grep -Fqx 'blocking-copy' "$block_ready" && grep -Fqx 'count=1' "$block_ready" &&
  grep -Fqx "source=$ROOT/agents/code-simplifier.md" "$block_ready" &&
  grep -Eq "^destination=$shared_lock_target/agents/\.code-simplifier\.md\.stage\.[[:alnum:]]+$" "$block_ready" &&
  grep -Fqx "ppid=$lock_owner_pid" "$block_ready" && [[ "$(cat "$block_count")" == "1" ]] &&
  [[ "$contender_status" -ne 0 ]] &&
  grep -q "adapter installation already in progress: $lock_token_before" <<< "$contender_error" &&
  [[ "$lock_token_after" == "$lock_token_before" ]] &&
  [[ "$lock_owner_inode_after" == "$lock_owner_inode_before" ]] &&
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

# A second owned lock must use the exact grammar and a distinct nonce.
second_lock_target="$tmp/second lock target"
mkdir "$second_lock_target"
cp "$target/AGENTS.md" "$second_lock_target/AGENTS.md"
second_block_ready="$tmp/second-block-ready"
second_block_release="$tmp/second-block-release"
second_block_count="$tmp/second-block-count"
BLOCK_READY="$second_block_ready" BLOCK_RELEASE="$second_block_release" BLOCK_COUNT="$second_block_count" REAL_CP="$real_cp" \
  PATH="$blocking_cp_bin:$PATH" "$ROOT/adapters/codex.sh" "$second_lock_target" \
    > "$tmp/second-lock-owner.out" 2>&1 &
second_lock_pid=$!
second_lock="$second_lock_target/.research-repo-standard-adapter.lock"
second_lock_owner="$second_lock/owner"
second_lock_ready=0
for ((attempt = 0; attempt < 500; attempt++)); do
  if [[ -f "$second_block_ready" && -f "$second_lock_owner" && ! -L "$second_lock" ]]; then
    second_lock_ready=1
    break
  fi
  sleep 0.01
done
second_lock_token="$(cat "$second_lock_owner" 2> /dev/null || true)"
if ((second_lock_ready)) && grep -Fqx 'blocking-copy' "$second_block_ready" &&
  grep -Fqx 'count=1' "$second_block_ready" &&
  grep -Fqx "source=$ROOT/agents/code-simplifier.md" "$second_block_ready" &&
  grep -Eq "^destination=$second_lock_target/agents/\.code-simplifier\.md\.stage\.[[:alnum:]]+$" "$second_block_ready" &&
  grep -Fqx "ppid=$second_lock_pid" "$second_block_ready" && [[ "$(cat "$second_block_count")" == "1" ]] &&
  [[ "$second_lock_token" =~ ^${second_lock_pid}:codex\.sh:[0-9]+-[0-9]+-[0-9]+$ ]] &&
  [[ "${second_lock_token##*:}" != "${lock_token_before##*:}" ]]; then
  pass "Adapter lock tokens use exact names and unique nonces"
else
  fail "Adapter lock tokens use exact names and unique nonces"
fi
touch "$second_block_release"
wait "$second_lock_pid" || fail "Adapter releases the second owned lock"
if [[ ! -e "$second_lock" && ! -L "$second_lock" ]]; then
  pass "Adapter releases the second owned lock"
else
  fail "Adapter releases the second owned lock"
fi

# Cleanup must preserve an owned lock whose owner bytes change before release.
run_changed_owner_case() {
  adapter=$1
  adapter_id=$2
  adapter_label=$3
  host_root=$4
  host_profile_relative=$5
  changed_owner_target="$tmp/changed-owner-$adapter_label"
  mkdir "$changed_owner_target"
  cp "$target/AGENTS.md" "$changed_owner_target/AGENTS.md"
  changed_owner_ready="$tmp/changed-owner-$adapter_label.ready"
  changed_owner_release="$tmp/changed-owner-$adapter_label.release"
  changed_owner_count="$tmp/changed-owner-$adapter_label.count"
  changed_owner_output="$tmp/changed-owner-$adapter_label.out"
  BLOCK_READY="$changed_owner_ready" BLOCK_RELEASE="$changed_owner_release" \
    BLOCK_COUNT="$changed_owner_count" REAL_CP="$real_cp" PATH="$blocking_cp_bin:$PATH" \
    "$adapter" "$changed_owner_target" > "$changed_owner_output" 2>&1 &
  changed_owner_pid=$!
  changed_owner_lock="$changed_owner_target/.research-repo-standard-adapter.lock"
  changed_owner_file="$changed_owner_lock/owner"
  changed_owner_lock_ready=0
  for ((attempt = 0; attempt < 500; attempt++)); do
    if [[ -f "$changed_owner_ready" && -f "$changed_owner_file" && ! -L "$changed_owner_lock" ]]; then
      changed_owner_lock_ready=1
      break
    fi
    sleep 0.01
  done
  changed_owner_token="$(cat "$changed_owner_file" 2> /dev/null || true)"
  printf '\n' >> "$changed_owner_file"
  changed_owner_inode="$(inode_of "$changed_owner_file" 2> /dev/null)"
  changed_owner_checksum="$(cksum "$changed_owner_file" 2> /dev/null)"
  touch "$changed_owner_release"
  changed_owner_status=0
  wait "$changed_owner_pid" || changed_owner_status=$?
  if ((changed_owner_lock_ready)) && [[ "$changed_owner_status" -eq 1 ]] &&
    [[ "$changed_owner_token" =~ ^${changed_owner_pid}:${adapter_id//./\.}:[0-9]+-[0-9]+-[0-9]+$ ]] &&
    grep -Fq 'cleanup incomplete: adapter lock owner changed; retained adapter lock for manual intervention' \
      "$changed_owner_output" && ! grep -q '^installed ' "$changed_owner_output" &&
    grep -Fqx 'blocking-copy' "$changed_owner_ready" && grep -Fqx 'count=1' "$changed_owner_ready" &&
    grep -Fqx "source=$ROOT/agents/code-simplifier.md" "$changed_owner_ready" &&
    grep -Eq "^destination=$changed_owner_target/agents/\.code-simplifier\.md\.stage\.[[:alnum:]]+$" \
      "$changed_owner_ready" && grep -Fqx "ppid=$changed_owner_pid" "$changed_owner_ready" &&
    [[ -d "$changed_owner_lock" && ! -L "$changed_owner_lock" ]] &&
    [[ -f "$changed_owner_file" && ! -L "$changed_owner_file" ]] &&
    [[ "$(inode_of "$changed_owner_file")" == "$changed_owner_inode" ]] &&
    [[ "$(cksum "$changed_owner_file")" == "$changed_owner_checksum" ]] &&
    [[ -f "$changed_owner_target/agents/code-simplifier.md" ]] &&
    [[ -f "$changed_owner_target/$host_profile_relative" ]] &&
    [[ -d "$changed_owner_target/$host_root" ]] &&
    serialization_is_retained "$changed_owner_target" &&
    { [[ "$adapter_label" != Claude ]] ||
      [[ "$(readlink "$changed_owner_target/CLAUDE.md" 2> /dev/null || true)" == AGENTS.md ]]; }; then
    pass "$adapter_label adapter fails closed on byte-changed lock owner"
  else
    fail "$adapter_label adapter fails closed on byte-changed lock owner"
  fi
}

run_changed_owner_case "$ROOT/adapters/claude-code.sh" claude-code.sh Claude .claude \
  .claude/agents/code-simplifier.md
run_changed_owner_case "$ROOT/adapters/codex.sh" codex.sh Codex .codex \
  .codex/agents/code-simplifier.toml

# Invocation basenames are diagnostic only; lock protocol IDs stay canonical.
run_protocol_id_case() {
  adapter_id=$1
  adapter_label=$2
  invocation_mode=$3
  source_fixture="$tmp/protocol-$adapter_label-$invocation_mode-source"
  protocol_target="$tmp/protocol-$adapter_label-$invocation_mode-target"
  mkdir -p "$source_fixture/adapters" "$source_fixture/agents" "$protocol_target"
  cp "$ROOT/agents/code-simplifier.md" "$source_fixture/agents/code-simplifier.md"
  cp "$ROOT/adapters/$adapter_id" "$source_fixture/adapters/$adapter_id"
  chmod +x "$source_fixture/adapters/$adapter_id"
  invocation="$source_fixture/adapters/renamed-$adapter_id"
  if [[ "$invocation_mode" == copy ]]; then
    cp "$source_fixture/adapters/$adapter_id" "$invocation"
    chmod +x "$invocation"
  else
    ln -s "$adapter_id" "$invocation"
  fi
  cp "$target/AGENTS.md" "$protocol_target/AGENTS.md"
  protocol_ready="$tmp/protocol-$adapter_label-$invocation_mode.ready"
  protocol_release="$tmp/protocol-$adapter_label-$invocation_mode.release"
  protocol_count="$tmp/protocol-$adapter_label-$invocation_mode.count"
  protocol_output="$tmp/protocol-$adapter_label-$invocation_mode.out"
  BLOCK_READY="$protocol_ready" BLOCK_RELEASE="$protocol_release" BLOCK_COUNT="$protocol_count" \
    REAL_CP="$real_cp" PATH="$blocking_cp_bin:$PATH" \
    "$invocation" "$protocol_target" > "$protocol_output" 2>&1 &
  protocol_pid=$!
  protocol_owner="$protocol_target/.research-repo-standard-adapter.lock/owner"
  protocol_ready_state=0
  for ((attempt = 0; attempt < 500; attempt++)); do
    if [[ -f "$protocol_ready" && -f "$protocol_owner" ]]; then
      protocol_ready_state=1
      break
    fi
    sleep 0.01
  done
  protocol_token="$(cat "$protocol_owner" 2> /dev/null || true)"
  case "$adapter_id" in
    claude-code.sh) contender="$ROOT/adapters/codex.sh" ;;
    codex.sh) contender="$ROOT/adapters/claude-code.sh" ;;
  esac
  protocol_contender_status=0
  protocol_contender_error="$("$contender" "$protocol_target" 2>&1)" || protocol_contender_status=$?
  touch "$protocol_release"
  protocol_status=0
  wait "$protocol_pid" || protocol_status=$?
  if ((protocol_ready_state)) && [[ "$protocol_status" -eq 0 ]] &&
    [[ "$protocol_contender_status" -ne 0 ]] &&
    [[ "$protocol_token" =~ ^${protocol_pid}:${adapter_id//./\.}:[0-9]+-[0-9]+-[0-9]+$ ]] &&
    grep -Fq "adapter installation already in progress: $protocol_token" <<< "$protocol_contender_error" &&
    grep -Fqx 'blocking-copy' "$protocol_ready" && grep -Fqx 'count=1' "$protocol_ready" &&
    grep -Fqx "source=$source_fixture/agents/code-simplifier.md" "$protocol_ready" &&
    grep -Eq "^destination=$protocol_target/agents/\.code-simplifier\.md\.stage\.[[:alnum:]]+$" \
      "$protocol_ready" && [[ "$(cat "$protocol_count")" == 1 ]] &&
    grep -Fqx "ppid=$protocol_pid" "$protocol_ready" &&
    [[ ! -e "$protocol_target/.research-repo-standard-adapter.lock" ]] &&
    [[ ! -e "$protocol_target/.research-repo-standard-adapter.guard" ]] &&
    [[ -z "$(find "$protocol_target" -maxdepth 1 -name '.research-repo-standard-adapter.claim.*' -print -quit)" ]]; then
    pass "$adapter_label $invocation_mode invocation keeps canonical protocol ID"
  else
    fail "$adapter_label $invocation_mode invocation keeps canonical protocol ID"
  fi
}

for protocol_mode in copy symlink; do
  run_protocol_id_case claude-code.sh Claude "$protocol_mode"
  run_protocol_id_case codex.sh Codex "$protocol_mode"
done

# A signal plus nonzero return after any exact mkdir effect must wait for inode bookkeeping.
real_mkdir="$(command -v mkdir)"
signal_mkdir_bin="$tmp/signal-mkdir-bin"
mkdir "$signal_mkdir_bin"
cat > "$signal_mkdir_bin/mkdir" << 'EOF'
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$MKDIR_COUNT_FILE" ]] || count="$(cat "$MKDIR_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MKDIR_COUNT_FILE"
path=$1
case "$EXPECTED_PATH_KIND" in
  exact) [[ "$path" == "$EXPECTED_PATH" ]] || exec "$REAL_MKDIR" "$@" ;;
  claim) [[ "$path" == "$EXPECTED_PATH"/.research-repo-standard-adapter.claim.* ]] ||
      exec "$REAL_MKDIR" "$@" ;;
esac
if ! "$REAL_MKDIR" "$@"; then
  printf 'real-mkdir-failed\ncount=%s\npath=%s\nppid=%s\n' \
    "$count" "$path" "$PPID" > "$MKDIR_EFFECT_MARKER"
  exit 1
fi
directory_inode="$(LC_ALL=C ls -di "$path" | awk '{ print $1 }')"
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" || "$count" != "$EXPECTED_COUNT" ]]; then
  printf 'unexpected-effect\ncount=%s\ninode=%s\npath=%s\nppid=%s\nsignal=%s\nreturn_status=%s\n' \
    "$count" "$directory_inode" "$path" "$PPID" "$FAULT_SIGNAL" "$FAULT_RETURN_STATUS" \
    > "$MKDIR_EFFECT_MARKER"
  exit 1
fi
printf 'post-effect mkdir\ncount=%s\ninode=%s\npath=%s\nppid=%s\nsignal=%s\nreturn_status=%s\n' \
  "$count" "$directory_inode" "$path" "$PPID" "$FAULT_SIGNAL" "$FAULT_RETURN_STATUS" \
  > "$MKDIR_EFFECT_MARKER"
if ! kill -"$FAULT_SIGNAL" "$PPID"; then
  printf 'signal-delivery-failed\ncount=%s\npid=%s\nsignal=%s\n' \
    "$count" "$PPID" "$FAULT_SIGNAL" > "$MKDIR_EFFECT_MARKER"
  exit 1
fi
exit "$FAULT_RETURN_STATUS"
EOF
chmod +x "$signal_mkdir_bin/mkdir"

run_signal_after_mkdir() {
  adapter=$1
  adapter_name=$2
  case_name=$3
  expected_path_kind=$4
  expected_relative=$5
  expected_count=$6
  fault_signal=$7
  expected_status=$8
  fixture="$tmp/mkdir-$adapter_name-$case_name-$fault_signal"
  marker="$tmp/mkdir-$adapter_name-$case_name-$fault_signal.marker"
  count_file="$tmp/mkdir-$adapter_name-$case_name-$fault_signal.count"
  output="$tmp/mkdir-$adapter_name-$case_name-$fault_signal.out"
  adapter_pid_file="$tmp/mkdir-$adapter_name-$case_name-$fault_signal.pid"
  expected_path=$fixture
  [[ "$expected_path_kind" == claim ]] || expected_path="$fixture/$expected_relative"
  mkdir "$fixture"
  cp "$target/AGENTS.md" "$fixture/AGENTS.md"

  adapter_status=0
  REAL_MKDIR="$real_mkdir" MKDIR_EFFECT_MARKER="$marker" MKDIR_COUNT_FILE="$count_file" \
    EXPECTED_PATH="$expected_path" EXPECTED_PATH_KIND="$expected_path_kind" \
    EXPECTED_COUNT="$expected_count" FAULT_SIGNAL="$fault_signal" FAULT_RETURN_STATUS=73 \
    ADAPTER_PID_FILE="$adapter_pid_file" PATH="$signal_mkdir_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' \
      _ "$adapter" "$fixture" > "$output" 2>&1 || adapter_status=$?
  adapter_pid="$(cat "$adapter_pid_file" 2> /dev/null || true)"

  marker_path="$(sed -n 's/^path=//p' "$marker" 2> /dev/null)"
  path_ok=0
  if [[ "$expected_path_kind" == claim ]]; then
    [[ "$marker_path" == "$fixture"/.research-repo-standard-adapter.claim.* ]] && path_ok=1
  else
    [[ "$marker_path" == "$expected_path" ]] && path_ok=1
  fi
  if [[ "$adapter_status" -eq "$expected_status" ]] && ((path_ok)) &&
    [[ -f "$marker" ]] && grep -Fqx 'post-effect mkdir' "$marker" &&
    grep -Fqx "count=$expected_count" "$marker" && grep -Eq '^inode=[0-9]+$' "$marker" &&
    grep -Fqx "ppid=$adapter_pid" "$marker" && grep -Fqx "signal=$fault_signal" "$marker" &&
    grep -Fqx 'return_status=73' "$marker" && [[ "$(cat "$count_file")" == "$expected_count" ]] &&
    [[ -z "$(find "$fixture" -mindepth 1 ! -path "$fixture/AGENTS.md" -print -quit)" ]]; then
    pass "$adapter_name adapter records $case_name mkdir before $fault_signal cleanup"
  else
    fail "$adapter_name adapter records $case_name mkdir before $fault_signal cleanup"
  fi
}

for mkdir_adapter_case in Claude Codex; do
  case "$mkdir_adapter_case" in
    Claude)
      mkdir_adapter="$ROOT/adapters/claude-code.sh"
      host_root=.claude
      ;;
    Codex)
      mkdir_adapter="$ROOT/adapters/codex.sh"
      host_root=.codex
      ;;
  esac
  run_signal_after_mkdir "$mkdir_adapter" "$mkdir_adapter_case" claim claim '' 1 TERM 143
  for mkdir_signal in HUP TERM INT; do
    case "$mkdir_signal" in
      HUP) mkdir_signal_status=129 ;;
      TERM) mkdir_signal_status=143 ;;
      INT) mkdir_signal_status=130 ;;
    esac
    run_signal_after_mkdir "$mkdir_adapter" "$mkdir_adapter_case" lock exact \
      .research-repo-standard-adapter.lock 2 "$mkdir_signal" "$mkdir_signal_status"
  done
  run_signal_after_mkdir "$mkdir_adapter" "$mkdir_adapter_case" agents-parent exact agents 3 TERM 143
  run_signal_after_mkdir "$mkdir_adapter" "$mkdir_adapter_case" host-parent exact "$host_root" 4 TERM 143
  run_signal_after_mkdir "$mkdir_adapter" "$mkdir_adapter_case" nested-parent exact \
    "$host_root/agents" 5 TERM 143
done

# Predictable claim paths fail closed for every no-follow path shape.
run_claim_collision_case() {
  adapter=$1
  adapter_label=$2
  collision_kind=$3
  fixture="$tmp/claim-$adapter_label-$collision_kind"
  claim_path_file="$tmp/claim-$adapter_label-$collision_kind.path"
  claim_state_file="$tmp/claim-$adapter_label-$collision_kind.state"
  output="$tmp/claim-$adapter_label-$collision_kind.out"
  outside="$tmp/claim-$adapter_label-$collision_kind-outside"
  mkdir "$fixture" "$outside"
  cp "$target/AGENTS.md" "$fixture/AGENTS.md"
  printf 'outside marker\n' > "$outside/marker"
  outside_before="$(cksum "$outside/marker")"
  collision_status=0
  CLAIM_PATH_FILE="$claim_path_file" CLAIM_STATE_FILE="$claim_state_file" \
    COLLISION_KIND="$collision_kind" \
    ADAPTER_PATH="$adapter" FIXTURE_PATH="$fixture" OUTSIDE_PATH="$outside" \
    /bin/bash -c '
      date() { printf "%s\n" 1700000000; }
      RANDOM=7319
      first_random=$RANDOM
      second_random=$RANDOM
      claim="$FIXTURE_PATH/.research-repo-standard-adapter.claim.$$-1700000000-$first_random-$second_random"
      case "$COLLISION_KIND" in
        regular) printf "foreign claim\n" > "$claim" ;;
        directory) mkdir "$claim"; printf "preserve\n" > "$claim/marker" ;;
        dangling) ln -s missing-claim "$claim" ;;
        internal)
          mkdir "$FIXTURE_PATH/claim-source"
          printf "internal marker\n" > "$FIXTURE_PATH/claim-source/marker"
          ln -s claim-source "$claim"
          ;;
        external) ln -s "$OUTSIDE_PATH" "$claim" ;;
      esac
      printf "%s\n" "$claim" > "$CLAIM_PATH_FILE"
      {
        printf "inode=%s\n" "$(LC_ALL=C ls -di "$claim" | awk "{ print \$1 }")"
        if [[ -L "$claim" ]]; then
          printf "target=%s\n" "$(readlink "$claim")"
        elif [[ -f "$claim" ]]; then
          printf "checksum=%s\n" "$(cksum "$claim")"
        elif [[ -f "$claim/marker" ]]; then
          printf "marker_checksum=%s\n" "$(cksum "$claim/marker")"
        fi
      } > "$CLAIM_STATE_FILE"
      RANDOM=7319
      source "$ADAPTER_PATH" "$FIXTURE_PATH"
    ' > "$output" 2>&1 || collision_status=$?
  claim_path="$(cat "$claim_path_file" 2> /dev/null || true)"
  claim_inode_before="$(sed -n 's/^inode=//p' "$claim_state_file" 2> /dev/null)"
  claim_shape_ok=0
  case "$collision_kind" in
    regular)
      [[ -f "$claim_path" && ! -L "$claim_path" ]] &&
        [[ "$(inode_of "$claim_path")" == "$claim_inode_before" ]] &&
        [[ "$(cksum "$claim_path")" == \
          "$(sed -n 's/^checksum=//p' "$claim_state_file")" ]] && claim_shape_ok=1
      ;;
    directory)
      [[ -d "$claim_path" && ! -L "$claim_path" ]] &&
        [[ "$(inode_of "$claim_path")" == "$claim_inode_before" ]] &&
        [[ "$(cksum "$claim_path/marker")" == \
          "$(sed -n 's/^marker_checksum=//p' "$claim_state_file")" ]] && claim_shape_ok=1
      ;;
    dangling)
      [[ -L "$claim_path" && "$(inode_of "$claim_path")" == "$claim_inode_before" ]] &&
        [[ "$(readlink "$claim_path")" == \
          "$(sed -n 's/^target=//p' "$claim_state_file")" ]] && claim_shape_ok=1
      ;;
    internal)
      [[ -L "$claim_path" && "$(inode_of "$claim_path")" == "$claim_inode_before" ]] &&
        [[ "$(readlink "$claim_path")" == \
          "$(sed -n 's/^target=//p' "$claim_state_file")" ]] &&
        [[ "$(cat "$fixture/claim-source/marker")" == 'internal marker' ]] && claim_shape_ok=1
      ;;
    external)
      [[ -L "$claim_path" && "$(inode_of "$claim_path")" == "$claim_inode_before" ]] &&
        [[ "$(readlink "$claim_path")" == \
          "$(sed -n 's/^target=//p' "$claim_state_file")" ]] && claim_shape_ok=1
      ;;
  esac
  if [[ "$collision_status" -eq 1 ]] &&
    grep -Fq 'adapter acquisition claim requires manual intervention' "$output" &&
    ((claim_shape_ok)) && [[ "$(cksum "$outside/marker")" == "$outside_before" ]] &&
    [[ ! -e "$fixture/.research-repo-standard-adapter.guard" ]] &&
    [[ ! -e "$fixture/.research-repo-standard-adapter.lock" ]] &&
    [[ ! -e "$fixture/agents" ]] && [[ ! -e "$fixture/.claude" ]] &&
    [[ ! -e "$fixture/.codex" ]] && ! grep -q '^installed ' "$output"; then
    pass "$adapter_label adapter preserves $collision_kind claim collision"
  else
    fail "$adapter_label adapter preserves $collision_kind claim collision"
  fi
}

for claim_adapter_case in Claude Codex; do
  case "$claim_adapter_case" in
    Claude) claim_adapter="$ROOT/adapters/claude-code.sh" ;;
    Codex) claim_adapter="$ROOT/adapters/codex.sh" ;;
  esac
  for claim_collision_kind in regular directory dangling internal external; do
    run_claim_collision_case "$claim_adapter" "$claim_adapter_case" "$claim_collision_kind"
  done
done

# Guard and owner hard links use an exact two-path primitive and record post-effect signals.
real_link="$(command -v link)"
fault_link_bin="$tmp/fault-link-bin"
mkdir "$fault_link_bin"
cat > "$fault_link_bin/link" << 'EOF'
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$LINK_COUNT_FILE" ]] || count="$(cat "$LINK_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$LINK_COUNT_FILE"
source=$1
destination=$2
if [[ "$count" -ne "$LINK_FAIL_ON_COUNT" ]]; then
  exec "$REAL_LINK" "$@"
fi
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ]]; then
  printf 'unexpected-parent\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
    "$count" "$source" "$destination" "$PPID" > "$LINK_EFFECT_MARKER"
  exit 1
fi
if [[ "$LINK_FAULT_MODE" == pre ]]; then
  printf 'pre-effect link\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
    "$count" "$source" "$destination" "$PPID" > "$LINK_EFFECT_MARKER"
  exit 71
fi
"$REAL_LINK" "$source" "$destination"
source_inode="$(LC_ALL=C ls -di "$source" | awk '{ print $1 }')"
destination_inode="$(LC_ALL=C ls -di "$destination" | awk '{ print $1 }')"
printf 'post-effect link\ncount=%s\nsource=%s\ndestination=%s\nsource_inode=%s\ndestination_inode=%s\nppid=%s\nsignal=%s\nreturn_status=73\n' \
  "$count" "$source" "$destination" "$source_inode" "$destination_inode" "$PPID" \
  "$FAULT_SIGNAL" > "$LINK_EFFECT_MARKER"
if ! kill -"$FAULT_SIGNAL" "$PPID"; then
  printf 'signal-delivery-failed\ncount=%s\npid=%s\nsignal=%s\n' \
    "$count" "$PPID" "$FAULT_SIGNAL" > "$LINK_EFFECT_MARKER"
  exit 1
fi
exit 73
EOF
chmod +x "$fault_link_bin/link"

run_link_fault_case() {
  adapter=$1
  adapter_label=$2
  link_role=$3
  fault_mode=$4
  link_count=$5
  expected_status=$6
  link_fixture="$tmp/link-$adapter_label-$link_role-$fault_mode"
  mkdir "$link_fixture"
  cp "$target/AGENTS.md" "$link_fixture/AGENTS.md"
  link_marker="$tmp/link-$adapter_label-$link_role-$fault_mode.marker"
  link_count_file="$tmp/link-$adapter_label-$link_role-$fault_mode.count"
  link_pid_file="$tmp/link-$adapter_label-$link_role-$fault_mode.pid"
  link_output="$tmp/link-$adapter_label-$link_role-$fault_mode.out"
  link_status=0
  LINK_EFFECT_MARKER="$link_marker" LINK_COUNT_FILE="$link_count_file" \
    LINK_FAIL_ON_COUNT="$link_count" LINK_FAULT_MODE="$fault_mode" FAULT_SIGNAL=TERM \
    REAL_LINK="$real_link" ADAPTER_PID_FILE="$link_pid_file" PATH="$fault_link_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' \
      _ "$adapter" "$link_fixture" > "$link_output" 2>&1 || link_status=$?
  link_pid="$(cat "$link_pid_file" 2> /dev/null || true)"
  link_source="$(sed -n 's/^source=//p' "$link_marker" 2> /dev/null)"
  case "$link_role" in
    guard) expected_link_destination="$link_fixture/.research-repo-standard-adapter.guard" ;;
    owner) expected_link_destination="$link_fixture/.research-repo-standard-adapter.lock/owner" ;;
  esac
  link_evidence_ok=0
  if [[ "$link_status" -eq "$expected_status" ]] && [[ "$(cat "$link_count_file" 2> /dev/null)" == "$link_count" ]] &&
    grep -Fqx "$fault_mode-effect link" "$link_marker" && grep -Fqx "count=$link_count" "$link_marker" &&
    [[ "$link_source" == "$link_fixture"/.research-repo-standard-adapter.claim.*/owner ]] &&
    grep -Fqx "destination=$expected_link_destination" "$link_marker" &&
    grep -Fqx "ppid=$link_pid" "$link_marker"; then
    if [[ "$fault_mode" == post ]]; then
      source_inode="$(sed -n 's/^source_inode=//p' "$link_marker")"
      destination_inode="$(sed -n 's/^destination_inode=//p' "$link_marker")"
      [[ "$source_inode" =~ ^[0-9]+$ && "$source_inode" == "$destination_inode" ]] &&
        grep -Fqx 'signal=TERM' "$link_marker" && grep -Fqx 'return_status=73' "$link_marker" &&
        link_evidence_ok=1
    else
      link_evidence_ok=1
    fi
  fi
  unsupported_diagnostic_ok=1
  if [[ "$fault_mode" == pre ]]; then
    unsupported_diagnostic_ok=0
    case "$adapter_label" in
      Claude)
        grep -Fq 'adapter acquisition requires regular-file hard-link support' \
          "$link_output" && unsupported_diagnostic_ok=1
        ;;
      Codex)
        grep -Fq 'adapter hard-link operation is unsupported' \
          "$link_output" && unsupported_diagnostic_ok=1
        ;;
    esac
  fi
  if ((link_evidence_ok)) && ((unsupported_diagnostic_ok)) &&
    [[ -z "$(find "$link_fixture" -mindepth 1 ! -path "$link_fixture/AGENTS.md" -print -quit)" ]] &&
    ! grep -q '^installed ' "$link_output"; then
    pass "$adapter_label adapter handles $fault_mode-effect $link_role link fault"
  else
    fail "$adapter_label adapter handles $fault_mode-effect $link_role link fault"
  fi
}

for link_adapter_case in Claude Codex; do
  case "$link_adapter_case" in
    Claude) link_adapter="$ROOT/adapters/claude-code.sh" ;;
    Codex) link_adapter="$ROOT/adapters/codex.sh" ;;
  esac
  run_link_fault_case "$link_adapter" "$link_adapter_case" guard pre 1 1
  run_link_fault_case "$link_adapter" "$link_adapter_case" guard post 1 143
  run_link_fault_case "$link_adapter" "$link_adapter_case" owner pre 2 1
  run_link_fault_case "$link_adapter" "$link_adapter_case" owner post 2 143
done

assert_lock_refused_without_output() {
  fixture=$1
  expected_diagnostic=$2
  label=$3
  for adapter_case in Claude Codex; do
    adapter_fixture="$tmp/lock-matrix-${fixture##*/}-$adapter_case"
    cp -R "$fixture" "$adapter_fixture"
    lock_relative=.research-repo-standard-adapter.lock
    external_owner_original=''
    external_lock_original=''
    if [[ -L "$adapter_fixture/$lock_relative" ]]; then
      original_lock_target="$(readlink "$fixture/$lock_relative")"
      case "$original_lock_target" in
        /*)
          external_lock_original=$original_lock_target
          rm "$adapter_fixture/$lock_relative"
          ln -s "$external_lock_original" "$adapter_fixture/$lock_relative"
          ;;
      esac
    elif [[ -L "$adapter_fixture/$lock_relative/owner" ]]; then
      original_owner_target="$(readlink "$fixture/$lock_relative/owner")"
      case "$original_owner_target" in
        /*)
          external_owner_original=$original_owner_target
          rm "$adapter_fixture/$lock_relative/owner"
          ln -s "$external_owner_original" "$adapter_fixture/$lock_relative/owner"
          ;;
      esac
    fi
    lock_fingerprint_before="$(path_fingerprint "$adapter_fixture/$lock_relative")"
    owner_fingerprint_before="$(path_fingerprint "$adapter_fixture/$lock_relative/owner")"
    external_owner_before=''
    external_lock_before=''
    [[ -z "$external_owner_original" ]] ||
      external_owner_before="$(path_fingerprint "$external_owner_original")"
    [[ -z "$external_lock_original" ]] ||
      external_lock_before="$(path_fingerprint "$external_lock_original")"
    case "$adapter_case" in
      Claude) adapter="$ROOT/adapters/claude-code.sh" ;;
      Codex) adapter="$ROOT/adapters/codex.sh" ;;
    esac
    status=0
    error="$("$adapter" "$adapter_fixture" 2>&1)" || status=$?
    if [[ "$status" -ne 0 ]] && grep -q "$expected_diagnostic" <<< "$error" &&
      [[ ! -e "$adapter_fixture/agents" && ! -L "$adapter_fixture/agents" ]] &&
      [[ ! -e "$adapter_fixture/.claude" && ! -L "$adapter_fixture/.claude" ]] &&
      [[ ! -e "$adapter_fixture/CLAUDE.md" && ! -L "$adapter_fixture/CLAUDE.md" ]] &&
      [[ ! -e "$adapter_fixture/.codex" && ! -L "$adapter_fixture/.codex" ]] &&
      [[ ! -e "$adapter_fixture/.research-repo-standard-adapter.guard" &&
        ! -L "$adapter_fixture/.research-repo-standard-adapter.guard" ]] &&
      [[ -z "$(find "$adapter_fixture" -maxdepth 1 -name '.research-repo-standard-adapter.claim.*' -print -quit)" ]] &&
      [[ -z "$(find "$adapter_fixture" -name '*.stage.*' -print -quit)" ]] &&
      [[ "$(path_fingerprint "$adapter_fixture/$lock_relative")" == "$lock_fingerprint_before" ]] &&
      [[ "$(path_fingerprint "$adapter_fixture/$lock_relative/owner")" == "$owner_fingerprint_before" ]] &&
      { [[ -z "$external_owner_original" ]] ||
        [[ "$(path_fingerprint "$external_owner_original")" == "$external_owner_before" ]]; } &&
      { [[ -z "$external_lock_original" ]] ||
        [[ "$(path_fingerprint "$external_lock_original")" == "$external_lock_before" ]]; }; then
      pass "$adapter_case: $label"
    else
      fail "$adapter_case: $label"
    fi
  done
}

regular_lock_target="$tmp/regular-lock-target"
mkdir "$regular_lock_target"
cp "$target/AGENTS.md" "$regular_lock_target/AGENTS.md"
printf 'regular lock\n' > "$regular_lock_target/.research-repo-standard-adapter.lock"
regular_lock_before="$(cksum "$regular_lock_target/.research-repo-standard-adapter.lock")"
regular_lock_inode="$(inode_of "$regular_lock_target/.research-repo-standard-adapter.lock")"
assert_lock_refused_without_output "$regular_lock_target" 'adapter lock requires manual intervention' \
  "Adapter preserves a regular-file lock path"
if [[ "$(cksum "$regular_lock_target/.research-repo-standard-adapter.lock")" == "$regular_lock_before" ]] &&
  [[ "$(inode_of "$regular_lock_target/.research-repo-standard-adapter.lock")" == "$regular_lock_inode" ]]; then
  pass "Regular-file lock identity remains unchanged"
else
  fail "Regular-file lock identity remains unchanged"
fi

ordinary_lock_target="$tmp/ordinary-lock-target"
mkdir -p "$ordinary_lock_target/.research-repo-standard-adapter.lock"
cp "$target/AGENTS.md" "$ordinary_lock_target/AGENTS.md"
printf 'preserve me\n' > "$ordinary_lock_target/.research-repo-standard-adapter.lock/marker"
ordinary_marker_before="$(cksum "$ordinary_lock_target/.research-repo-standard-adapter.lock/marker")"
assert_lock_refused_without_output "$ordinary_lock_target" 'adapter lock requires manual intervention' \
  "Adapter preserves an ordinary lock directory"
if [[ "$(cksum "$ordinary_lock_target/.research-repo-standard-adapter.lock/marker")" == "$ordinary_marker_before" ]] &&
  [[ ! -e "$ordinary_lock_target/.research-repo-standard-adapter.lock/owner" ]]; then
  pass "Adapter creates nothing inside an ordinary lock directory"
else
  fail "Adapter creates nothing inside an ordinary lock directory"
fi

missing_owner_target="$tmp/missing-owner-target"
missing_owner_lock="$missing_owner_target/.research-repo-standard-adapter.lock"
mkdir -p "$missing_owner_lock"
cp "$target/AGENTS.md" "$missing_owner_target/AGENTS.md"
missing_owner_inode="$(inode_of "$missing_owner_lock")"
assert_lock_refused_without_output "$missing_owner_target" 'adapter lock requires manual intervention' \
  "Adapter preserves a missing-owner lock directory"
if [[ -d "$missing_owner_lock" && ! -L "$missing_owner_lock" ]] &&
  [[ "$(inode_of "$missing_owner_lock")" == "$missing_owner_inode" ]] &&
  [[ -z "$(find "$missing_owner_lock" -mindepth 1 -print -quit)" ]]; then
  pass "Missing-owner lock retains exact empty directory identity"
else
  fail "Missing-owner lock retains exact empty directory identity"
fi

owner_directory_target="$tmp/owner-directory-target"
mkdir -p "$owner_directory_target/.research-repo-standard-adapter.lock/owner"
cp "$target/AGENTS.md" "$owner_directory_target/AGENTS.md"
owner_directory_inode="$(inode_of "$owner_directory_target/.research-repo-standard-adapter.lock/owner")"
assert_lock_refused_without_output "$owner_directory_target" \
  'adapter lock requires manual intervention' 'owner directory is preserved'
if [[ -d "$owner_directory_target/.research-repo-standard-adapter.lock/owner" ]] &&
  [[ "$(inode_of "$owner_directory_target/.research-repo-standard-adapter.lock/owner")" == \
    "$owner_directory_inode" ]]; then
  pass "owner directory identity remains unchanged"
else
  fail "owner directory identity remains unchanged"
fi

owner_dangling_target="$tmp/owner-dangling-target"
mkdir -p "$owner_dangling_target/.research-repo-standard-adapter.lock"
cp "$target/AGENTS.md" "$owner_dangling_target/AGENTS.md"
ln -s missing-owner "$owner_dangling_target/.research-repo-standard-adapter.lock/owner"
assert_lock_refused_without_output "$owner_dangling_target" \
  'adapter lock requires manual intervention' 'dangling owner symlink is preserved'
if [[ "$(readlink "$owner_dangling_target/.research-repo-standard-adapter.lock/owner")" == \
  missing-owner ]]; then
  pass "dangling owner symlink identity remains unchanged"
else
  fail "dangling owner symlink identity remains unchanged"
fi

owner_external_target="$tmp/owner-external-target"
owner_external_file="$tmp/owner-external-file"
mkdir -p "$owner_external_target/.research-repo-standard-adapter.lock"
cp "$target/AGENTS.md" "$owner_external_target/AGENTS.md"
printf 'external owner\n' > "$owner_external_file"
owner_external_checksum="$(cksum "$owner_external_file")"
owner_external_inode="$(inode_of "$owner_external_file")"
ln -s "$owner_external_file" "$owner_external_target/.research-repo-standard-adapter.lock/owner"
assert_lock_refused_without_output "$owner_external_target" \
  'adapter lock requires manual intervention' 'external owner symlink is preserved'
if [[ "$(readlink "$owner_external_target/.research-repo-standard-adapter.lock/owner")" == \
  "$owner_external_file" ]] && [[ "$(cksum "$owner_external_file")" == "$owner_external_checksum" ]] &&
  [[ "$(inode_of "$owner_external_file")" == "$owner_external_inode" ]]; then
  pass "adapter writes nothing through an external owner symlink"
else
  fail "adapter writes nothing through an external owner symlink"
fi

for token_case in numeric-only zero-pid leading-zero-pid empty-adapter arbitrary-adapter extra-suffix; do
  malformed_target="$tmp/malformed-$token_case-target"
  mkdir -p "$malformed_target/.research-repo-standard-adapter.lock"
  cp "$target/AGENTS.md" "$malformed_target/AGENTS.md"
  case "$token_case" in
    numeric-only) malformed_token='12345' ;;
    zero-pid) malformed_token='0:claude-code.sh:123-456-789' ;;
    leading-zero-pid) malformed_token="0$$:claude-code.sh:123-456-789" ;;
    empty-adapter) malformed_token="$$::123-456-789" ;;
    arbitrary-adapter) malformed_token="$$:other.sh:123-456-789" ;;
    extra-suffix) malformed_token="$$:claude-code.sh:123-456-789:extra" ;;
  esac
  printf '%s\n' "$malformed_token" > "$malformed_target/.research-repo-standard-adapter.lock/owner"
  malformed_inode="$(inode_of "$malformed_target/.research-repo-standard-adapter.lock/owner")"
  assert_lock_refused_without_output "$malformed_target" 'adapter lock requires manual intervention' \
    "Adapter rejects $token_case lock token grammar"
  if [[ "$(cat "$malformed_target/.research-repo-standard-adapter.lock/owner")" == "$malformed_token" ]] &&
    [[ "$(inode_of "$malformed_target/.research-repo-standard-adapter.lock/owner")" == "$malformed_inode" ]]; then
    pass "Adapter preserves $token_case lock token"
  else
    fail "Adapter preserves $token_case lock token"
  fi
done

live_owner_target="$tmp/live-owner-target"
mkdir -p "$live_owner_target/.research-repo-standard-adapter.lock"
cp "$target/AGENTS.md" "$live_owner_target/AGENTS.md"
live_owner_token="$$:codex.sh:123-456-789"
printf '%s\n' "$live_owner_token" > "$live_owner_target/.research-repo-standard-adapter.lock/owner"
live_owner_inode="$(inode_of "$live_owner_target/.research-repo-standard-adapter.lock/owner")"
assert_lock_refused_without_output "$live_owner_target" "adapter installation already in progress: $live_owner_token" \
  "Same-PID contender preserves a never-acquired live lock"
if [[ "$(cat "$live_owner_target/.research-repo-standard-adapter.lock/owner")" == "$live_owner_token" ]] &&
  [[ "$(inode_of "$live_owner_target/.research-repo-standard-adapter.lock/owner")" == "$live_owner_inode" ]]; then
  pass "Never-acquired live lock identity remains unchanged"
else
  fail "Never-acquired live lock identity remains unchanged"
fi

dead_owner_target="$tmp/dead-owner-target"
mkdir -p "$dead_owner_target/.research-repo-standard-adapter.lock"
cp "$target/AGENTS.md" "$dead_owner_target/AGENTS.md"
dead_owner_token='99999999:claude-code.sh:123-456-789'
printf '%s\n' "$dead_owner_token" > "$dead_owner_target/.research-repo-standard-adapter.lock/owner"
dead_owner_inode="$(inode_of "$dead_owner_target/.research-repo-standard-adapter.lock/owner")"
assert_lock_refused_without_output "$dead_owner_target" 'adapter lock requires manual intervention' \
  "Nonzero owner liveness preserves a stale lock"
if [[ "$(cat "$dead_owner_target/.research-repo-standard-adapter.lock/owner")" == "$dead_owner_token" ]] &&
  [[ "$(inode_of "$dead_owner_target/.research-repo-standard-adapter.lock/owner")" == "$dead_owner_inode" ]]; then
  pass "Dead-PID lock is never reclaimed"
else
  fail "Dead-PID lock is never reclaimed"
fi

stale_claude_status=0
stale_codex_status=0
"$ROOT/adapters/claude-code.sh" "$dead_owner_target" > "$tmp/stale-claude.out" 2>&1 &
stale_claude_pid=$!
"$ROOT/adapters/codex.sh" "$dead_owner_target" > "$tmp/stale-codex.out" 2>&1 &
stale_codex_pid=$!
wait "$stale_claude_pid" || stale_claude_status=$?
wait "$stale_codex_pid" || stale_codex_status=$?
if [[ "$stale_claude_status" -ne 0 && "$stale_codex_status" -ne 0 ]] &&
  grep -q 'adapter lock requires manual intervention' "$tmp/stale-claude.out" &&
  grep -q 'adapter lock requires manual intervention' "$tmp/stale-codex.out" &&
  [[ "$(cat "$dead_owner_target/.research-repo-standard-adapter.lock/owner")" == "$dead_owner_token" ]] &&
  [[ "$(inode_of "$dead_owner_target/.research-repo-standard-adapter.lock/owner")" == "$dead_owner_inode" ]]; then
  pass "Simultaneous stale-lock contenders both fail without mutation"
else
  fail "Simultaneous stale-lock contenders both fail without mutation"
fi

dangling_lock_target="$tmp/dangling-lock-target"
mkdir "$dangling_lock_target"
cp "$target/AGENTS.md" "$dangling_lock_target/AGENTS.md"
ln -s missing-lock-directory "$dangling_lock_target/.research-repo-standard-adapter.lock"
assert_lock_refused_without_output "$dangling_lock_target" 'adapter lock requires manual intervention' \
  "Adapter preserves a dangling lock symlink"
[[ "$(readlink "$dangling_lock_target/.research-repo-standard-adapter.lock")" == 'missing-lock-directory' ]] ||
  fail "Adapter preserves dangling lock symlink identity"

directory_lock_target="$tmp/directory-lock-target"
mkdir -p "$directory_lock_target/lock-source"
cp "$target/AGENTS.md" "$directory_lock_target/AGENTS.md"
ln -s lock-source "$directory_lock_target/.research-repo-standard-adapter.lock"
assert_lock_refused_without_output "$directory_lock_target" 'adapter lock requires manual intervention' \
  "Adapter preserves a directory lock symlink"
if [[ "$(readlink "$directory_lock_target/.research-repo-standard-adapter.lock")" == 'lock-source' ]] &&
  [[ -z "$(find "$directory_lock_target/lock-source" -mindepth 1 -print -quit)" ]]; then
  pass "Adapter writes nothing through a directory lock symlink"
else
  fail "Adapter writes nothing through a directory lock symlink"
fi

external_lock_target="$tmp/external-lock-target"
external_lock_directory="$tmp/external-lock-directory"
mkdir "$external_lock_target" "$external_lock_directory"
cp "$target/AGENTS.md" "$external_lock_target/AGENTS.md"
ln -s "$external_lock_directory" "$external_lock_target/.research-repo-standard-adapter.lock"
assert_lock_refused_without_output "$external_lock_target" 'adapter lock requires manual intervention' \
  "Adapter preserves an external directory lock symlink"
if [[ "$(readlink "$external_lock_target/.research-repo-standard-adapter.lock")" == "$external_lock_directory" ]] &&
  [[ -z "$(find "$external_lock_directory" -mindepth 1 -print -quit)" ]]; then
  pass "Adapter writes nothing outside the target through a lock symlink"
else
  fail "Adapter writes nothing outside the target through a lock symlink"
fi

assert_guard_refused_without_output() {
  fixture=$1
  expected_diagnostic=$2
  label=$3
  for guard_adapter_case in Claude Codex; do
    guard_fixture="$tmp/guard-matrix-${fixture##*/}-$guard_adapter_case"
    cp -R "$fixture" "$guard_fixture"
    guard="$guard_fixture/.research-repo-standard-adapter.guard"
    guard_fingerprint_before="$(path_fingerprint "$guard")"
    guard_outside_path=''
    guard_outside_before=''
    if [[ -L "$guard" ]]; then
      case "$(readlink "$guard")" in
        /*)
          guard_outside_path="$(readlink "$guard")"
          guard_outside_before="$(path_fingerprint "$guard_outside_path")"
          ;;
      esac
    fi
    case "$guard_adapter_case" in
      Claude) guard_adapter="$ROOT/adapters/claude-code.sh" ;;
      Codex) guard_adapter="$ROOT/adapters/codex.sh" ;;
    esac
    guard_status=0
    guard_error="$("$guard_adapter" "$guard_fixture" 2>&1)" || guard_status=$?
    if [[ "$guard_status" -ne 0 ]] && grep -Fq "$expected_diagnostic" <<< "$guard_error" &&
      [[ ! -e "$guard_fixture/.research-repo-standard-adapter.lock" &&
        ! -L "$guard_fixture/.research-repo-standard-adapter.lock" ]] &&
      [[ ! -e "$guard_fixture/agents" && ! -L "$guard_fixture/agents" ]] &&
      [[ ! -e "$guard_fixture/.claude" && ! -L "$guard_fixture/.claude" ]] &&
      [[ ! -e "$guard_fixture/CLAUDE.md" && ! -L "$guard_fixture/CLAUDE.md" ]] &&
      [[ ! -e "$guard_fixture/.codex" && ! -L "$guard_fixture/.codex" ]] &&
      [[ -z "$(find "$guard_fixture" -maxdepth 1 \
        -name '.research-repo-standard-adapter.claim.*' -print -quit)" ]] &&
      [[ "$(path_fingerprint "$guard")" == "$guard_fingerprint_before" ]] &&
      { [[ -z "$guard_outside_path" ]] ||
        [[ "$(path_fingerprint "$guard_outside_path")" == "$guard_outside_before" ]]; }; then
      pass "$guard_adapter_case: $label"
    else
      fail "$guard_adapter_case: $label"
    fi
  done
}

guard_regular_target="$tmp/guard-regular-target"
mkdir "$guard_regular_target"
cp "$target/AGENTS.md" "$guard_regular_target/AGENTS.md"
printf 'foreign guard\n' > "$guard_regular_target/.research-repo-standard-adapter.guard"
assert_guard_refused_without_output "$guard_regular_target" \
  'adapter acquisition guard requires manual intervention' 'regular guard is preserved'

guard_directory_target="$tmp/guard-directory-target"
mkdir -p "$guard_directory_target/.research-repo-standard-adapter.guard"
cp "$target/AGENTS.md" "$guard_directory_target/AGENTS.md"
printf 'preserve\n' > "$guard_directory_target/.research-repo-standard-adapter.guard/marker"
guard_directory_marker_before="$(cksum "$guard_directory_target/.research-repo-standard-adapter.guard/marker")"
assert_guard_refused_without_output "$guard_directory_target" \
  'adapter acquisition guard requires manual intervention' 'guard directory is preserved'
if [[ "$(cksum "$guard_directory_target/.research-repo-standard-adapter.guard/marker")" == \
  "$guard_directory_marker_before" ]] &&
  [[ -z "$(find "$guard_directory_target/.research-repo-standard-adapter.guard" -mindepth 1 \
    ! -name marker -print -quit)" ]]; then
  pass "guard directory receives no claim link"
else
  fail "guard directory receives no claim link"
fi

guard_dangling_target="$tmp/guard-dangling-target"
mkdir "$guard_dangling_target"
cp "$target/AGENTS.md" "$guard_dangling_target/AGENTS.md"
ln -s missing-guard "$guard_dangling_target/.research-repo-standard-adapter.guard"
assert_guard_refused_without_output "$guard_dangling_target" \
  'adapter acquisition guard requires manual intervention' 'dangling guard symlink is preserved'

guard_internal_target="$tmp/guard-internal-target"
mkdir "$guard_internal_target" "$guard_internal_target/guard-source"
cp "$target/AGENTS.md" "$guard_internal_target/AGENTS.md"
ln -s guard-source "$guard_internal_target/.research-repo-standard-adapter.guard"
assert_guard_refused_without_output "$guard_internal_target" \
  'adapter acquisition guard requires manual intervention' 'internal guard symlink is preserved'
if [[ -z "$(find "$guard_internal_target/guard-source" -mindepth 1 -print -quit)" ]]; then
  pass "adapter writes nothing through an internal guard symlink"
else
  fail "adapter writes nothing through an internal guard symlink"
fi

guard_external_target="$tmp/guard-external-target"
guard_external_directory="$tmp/guard-external-directory"
mkdir "$guard_external_target" "$guard_external_directory"
cp "$target/AGENTS.md" "$guard_external_target/AGENTS.md"
ln -s "$guard_external_directory" "$guard_external_target/.research-repo-standard-adapter.guard"
assert_guard_refused_without_output "$guard_external_target" \
  'adapter acquisition guard requires manual intervention' 'external guard symlink is preserved'
if [[ -z "$(find "$guard_external_directory" -mindepth 1 -print -quit)" ]]; then
  pass "adapter writes nothing outside through an external guard symlink"
else
  fail "adapter writes nothing outside through an external guard symlink"
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

# Every output-parent level also rejects and preserves an ordinary file.
run_file_parent_case() {
  adapter=$1
  adapter_label=$2
  parent=$3
  fixture_name="${parent//\//-}"
  parent_fixture="$tmp/file-parent-$adapter_label-$fixture_name"
  mkdir "$parent_fixture"
  cp "$target/AGENTS.md" "$parent_fixture/AGENTS.md"
  case "$parent" in
    */*) mkdir -p "$parent_fixture/${parent%/*}" ;;
  esac
  printf 'foreign parent file\n' > "$parent_fixture/$parent"
  parent_before="$(path_fingerprint "$parent_fixture/$parent")"
  parent_status=0
  parent_error="$("$adapter" "$parent_fixture" 2>&1)" || parent_status=$?
  if [[ "$parent_status" -eq 1 ]] &&
    grep -Fq "output parent is not a directory: $parent" <<< "$parent_error" &&
    [[ "$(path_fingerprint "$parent_fixture/$parent")" == "$parent_before" ]] &&
    [[ ! -e "$parent_fixture/.research-repo-standard-adapter.lock" ]] &&
    [[ ! -e "$parent_fixture/.research-repo-standard-adapter.guard" ]] &&
    [[ -z "$(find "$parent_fixture" -maxdepth 1 \
      -name '.research-repo-standard-adapter.claim.*' -print -quit)" ]] &&
    [[ ! -e "$parent_fixture/CLAUDE.md" ]] &&
    [[ ! -e "$parent_fixture/agents/code-simplifier.md" ]] &&
    [[ ! -e "$parent_fixture/.claude/agents/code-simplifier.md" ]] &&
    [[ ! -e "$parent_fixture/.codex/agents/code-simplifier.toml" ]]; then
    pass "$adapter_label adapter preserves ordinary-file $parent output parent"
  else
    fail "$adapter_label adapter preserves ordinary-file $parent output parent"
  fi
}

for file_parent_adapter_case in Claude Codex; do
  case "$file_parent_adapter_case" in
    Claude)
      file_parent_adapter="$ROOT/adapters/claude-code.sh"
      file_parent_host=.claude
      ;;
    Codex)
      file_parent_adapter="$ROOT/adapters/codex.sh"
      file_parent_host=.codex
      ;;
  esac
  run_file_parent_case "$file_parent_adapter" "$file_parent_adapter_case" agents
  run_file_parent_case "$file_parent_adapter" "$file_parent_adapter_case" "$file_parent_host"
  run_file_parent_case "$file_parent_adapter" "$file_parent_adapter_case" \
    "$file_parent_host/agents"
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
set -eu
count=0
[[ ! -f "$CP_COUNT_FILE" ]] || count="$(cat "$CP_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$CP_COUNT_FILE"
if [[ "$PPID" != "$EXPECTED_ADAPTER_PID" ]]; then
  printf 'unexpected-parent\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
    "$count" "$1" "$2" "$PPID" > "$CP_EFFECT_MARKER"
  exit 1
fi
printf 'partial copy\n' > "$2"
partial_inode="$(LC_ALL=C ls -di "$2" | awk '{ print $1 }')"
printf 'partial-copy\ncount=%s\nsource=%s\ndestination=%s\ninode=%s\nppid=%s\n' \
  "$count" "$1" "$2" "$partial_inode" "$PPID" > "$CP_EFFECT_MARKER"
exit 1
EOF
chmod +x "$partial_cp_bin/cp"

claude_cp_failure="$tmp/claude-cp-failure"
mkdir "$claude_cp_failure"
cp "$target/AGENTS.md" "$claude_cp_failure/AGENTS.md"
claude_cp_count="$tmp/claude-cp.count"
claude_cp_marker="$tmp/claude-cp.marker"
claude_cp_output="$tmp/claude-cp.out"
claude_cp_pid_file="$tmp/claude-cp.pid"
claude_cp_status=0
CP_COUNT_FILE="$claude_cp_count" CP_EFFECT_MARKER="$claude_cp_marker" \
  ADAPTER_PID_FILE="$claude_cp_pid_file" PATH="$partial_cp_bin:$PATH" \
  bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
  "$ROOT/adapters/claude-code.sh" "$claude_cp_failure" \
  > "$claude_cp_output" 2>&1 || claude_cp_status=$?
claude_cp_destination="$(sed -n 's/^destination=//p' "$claude_cp_marker" 2> /dev/null)"
if [[ "$claude_cp_status" -eq 0 ]]; then
  fail "Claude adapter aborts after a partial staging copy"
elif [[ "$claude_cp_status" -eq 1 ]] && [[ "$(cat "$claude_cp_count" 2> /dev/null)" == "1" ]] &&
  grep -Fqx 'partial-copy' "$claude_cp_marker" && grep -Fqx 'count=1' "$claude_cp_marker" &&
  grep -Fqx "source=$ROOT/agents/code-simplifier.md" "$claude_cp_marker" &&
  [[ "$claude_cp_destination" == "$claude_cp_failure"/agents/.code-simplifier.md.stage.* ]] &&
  grep -Eq '^inode=[0-9]+$' "$claude_cp_marker" &&
  grep -Fqx "ppid=$(cat "$claude_cp_pid_file")" "$claude_cp_marker" &&
  [[ ! -e "$claude_cp_failure/CLAUDE.md" && ! -L "$claude_cp_failure/CLAUDE.md" ]] &&
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
codex_cp_count="$tmp/codex-cp.count"
codex_cp_marker="$tmp/codex-cp.marker"
codex_cp_output="$tmp/codex-cp.out"
codex_cp_pid_file="$tmp/codex-cp.pid"
codex_cp_status=0
CP_COUNT_FILE="$codex_cp_count" CP_EFFECT_MARKER="$codex_cp_marker" \
  ADAPTER_PID_FILE="$codex_cp_pid_file" PATH="$partial_cp_bin:$PATH" \
  bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
  "$ROOT/adapters/codex.sh" "$codex_cp_failure" \
  > "$codex_cp_output" 2>&1 || codex_cp_status=$?
codex_cp_destination="$(sed -n 's/^destination=//p' "$codex_cp_marker" 2> /dev/null)"
if [[ "$codex_cp_status" -eq 0 ]]; then
  fail "Codex adapter aborts after a partial staging copy"
elif [[ "$codex_cp_status" -eq 1 ]] && [[ "$(cat "$codex_cp_count" 2> /dev/null)" == "1" ]] &&
  grep -Fqx 'partial-copy' "$codex_cp_marker" && grep -Fqx 'count=1' "$codex_cp_marker" &&
  grep -Fqx "source=$ROOT/agents/code-simplifier.md" "$codex_cp_marker" &&
  [[ "$codex_cp_destination" == "$codex_cp_failure"/agents/.code-simplifier.md.stage.* ]] &&
  grep -Eq '^inode=[0-9]+$' "$codex_cp_marker" &&
  grep -Fqx "ppid=$(cat "$codex_cp_pid_file")" "$codex_cp_marker" &&
  [[ ! -e "$codex_cp_failure/agents/code-simplifier.md" && ! -L "$codex_cp_failure/agents/code-simplifier.md" ]] &&
  [[ ! -e "$codex_cp_failure/.codex/agents/code-simplifier.toml" && ! -L "$codex_cp_failure/.codex/agents/code-simplifier.toml" ]] &&
  [[ -z "$(find "$codex_cp_failure" -name '*.stage.*' -print -quit)" ]] &&
  [[ ! -e "$codex_cp_failure/.research-repo-standard-adapter.lock" && ! -L "$codex_cp_failure/.research-repo-standard-adapter.lock" ]]; then
  pass "Codex adapter cleans a partial staging copy"
else
  fail "Codex adapter cleans a partial staging copy"
fi

# A post-effect failure or signal must roll back only invocation-owned inodes.
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
source=$1
destination=$2
expected_adapter_pid=${EXPECTED_ADAPTER_PID:-}
if [[ -n "${EXPECTED_ADAPTER_PID_FILE:-}" ]]; then
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    [[ ! -s "$EXPECTED_ADAPTER_PID_FILE" ]] || break
    sleep 0.01
  done
  expected_adapter_pid="$(cat "$EXPECTED_ADAPTER_PID_FILE" 2> /dev/null || true)"
fi
source_inode="$(LC_ALL=C ls -di "$source" | awk '{ print $1 }')"
if ! "$REAL_MV" "$@"; then
  printf 'real-mv-failed\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
    "$count" "$source" "$destination" "$PPID" > "$MV_EFFECT_MARKER"
  exit 1
fi
if [[ "$count" -eq "$FAIL_ON_COUNT" ]]; then
  destination_inode="$(LC_ALL=C ls -di "$destination" | awk '{ print $1 }')"
  if [[ "$destination" != "$EXPECTED_DESTINATION" || "$destination_inode" != "$source_inode" ||
    "$PPID" != "$expected_adapter_pid" ]]; then
    printf 'unexpected-effect\ncount=%s\nsource=%s\ndestination=%s\nsource_inode=%s\ndestination_inode=%s\nppid=%s\n' \
      "$count" "$source" "$destination" "$source_inode" "$destination_inode" "$PPID" \
      > "$MV_EFFECT_MARKER"
    exit 1
  fi
  current_inode=$destination_inode
  if [[ "$FAULT_MODE" == replace-* ]]; then
    sentinel_stage="$(dirname "$destination")/.different-inode-sentinel.$$"
    printf '%s\n' "$SENTINEL_CONTENT" > "$sentinel_stage"
    sentinel_inode="$(LC_ALL=C ls -di "$sentinel_stage" | awk '{ print $1 }')"
    "$REAL_MV" "$sentinel_stage" "$destination"
    current_inode="$(LC_ALL=C ls -di "$destination" | awk '{ print $1 }')"
    if [[ "$current_inode" != "$sentinel_inode" || "$current_inode" == "$destination_inode" ]]; then
      printf 'sentinel-replacement-failed\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
        "$count" "$source" "$destination" "$PPID" > "$MV_EFFECT_MARKER"
      exit 1
    fi
  fi
  printf 'post-effect\nmode=%s\ncount=%s\nsource=%s\ndestination=%s\nowned_inode=%s\ncurrent_inode=%s\nppid=%s\nsignal=%s\n' \
    "$FAULT_MODE" "$count" "$source" "$destination" "$destination_inode" "$current_inode" \
    "$PPID" "${FAULT_SIGNAL:-none}" > "$MV_EFFECT_MARKER"
  case "$FAULT_MODE" in
    signal | replace-signal)
      if ! kill -"$FAULT_SIGNAL" "$expected_adapter_pid"; then
        printf 'signal-delivery-failed\ncount=%s\npid=%s\nsignal=%s\n' \
          "$count" "$expected_adapter_pid" "$FAULT_SIGNAL" > "$MV_EFFECT_MARKER"
        exit 1
      fi
      exit 0
      ;;
    fail | replace-fail) exit 1 ;;
  esac
fi
EOF
chmod +x "$post_effect_mv_bin/mv"

run_post_effect_case() {
  adapter=$1
  adapter_label=$2
  publish_count=$3
  destination_relative=$4
  host_profile_relative=$5
  fault_mode=$6
  fault_signal=$7
  expected_status=$8
  case_label="$adapter_label-$fault_mode-${fault_signal:-none}"
  effect_fixture="$tmp/post-effect-$case_label"
  mkdir "$effect_fixture"
  cp "$target/AGENTS.md" "$effect_fixture/AGENTS.md"
  policy_checksum="$(cksum "$effect_fixture/AGENTS.md")"
  policy_inode="$(inode_of "$effect_fixture/AGENTS.md")"
  effect_count="$tmp/$case_label.count"
  effect_marker="$tmp/$case_label.marker"
  effect_pid_file="$tmp/$case_label.pid"
  effect_output="$tmp/$case_label.out"
  expected_destination="$effect_fixture/$destination_relative"
  sentinel_content="different-inode sentinel $case_label"
  effect_status=0
  MV_COUNT_FILE="$effect_count" MV_EFFECT_MARKER="$effect_marker" \
    EXPECTED_DESTINATION="$expected_destination" FAIL_ON_COUNT="$publish_count" \
    FAULT_MODE="$fault_mode" FAULT_SIGNAL="$fault_signal" SENTINEL_CONTENT="$sentinel_content" \
    REAL_MV="$real_mv" ADAPTER_PID_FILE="$effect_pid_file" PATH="$post_effect_mv_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' \
      _ "$adapter" "$effect_fixture" > "$effect_output" 2>&1 || effect_status=$?
  effect_pid="$(cat "$effect_pid_file" 2> /dev/null || true)"
  effect_source="$(sed -n 's/^source=//p' "$effect_marker" 2> /dev/null)"
  owned_inode="$(sed -n 's/^owned_inode=//p' "$effect_marker" 2> /dev/null)"
  current_inode="$(sed -n 's/^current_inode=//p' "$effect_marker" 2> /dev/null)"
  common_ok=0
  if [[ "$effect_status" -eq "$expected_status" ]] && [[ "$(cat "$effect_count" 2> /dev/null)" == "$publish_count" ]] &&
    grep -Fqx 'post-effect' "$effect_marker" && grep -Fqx "mode=$fault_mode" "$effect_marker" &&
    grep -Fqx "count=$publish_count" "$effect_marker" &&
    grep -Fqx "destination=$expected_destination" "$effect_marker" &&
    grep -Fqx "ppid=$effect_pid" "$effect_marker" && grep -Fqx "signal=${fault_signal:-none}" "$effect_marker" &&
    [[ "$owned_inode" =~ ^[0-9]+$ ]] && [[ "$current_inode" =~ ^[0-9]+$ ]] &&
    [[ "$(cksum "$effect_fixture/AGENTS.md")" == "$policy_checksum" ]] &&
    [[ "$(inode_of "$effect_fixture/AGENTS.md")" == "$policy_inode" ]] &&
    [[ -z "$(find "$effect_fixture" -name '*.stage.*' -print -quit)" ]] &&
    [[ ! -e "$effect_fixture/.research-repo-standard-adapter.lock" ]] &&
    [[ ! -e "$effect_fixture/.research-repo-standard-adapter.guard" ]] &&
    [[ -z "$(find "$effect_fixture" -maxdepth 1 -name '.research-repo-standard-adapter.claim.*' -print -quit)" ]] &&
    ! grep -q '^installed ' "$effect_output"; then
    case "$adapter_label" in
      Claude) [[ "$effect_source" == "$effect_fixture"/.CLAUDE.md.stage.*/CLAUDE.md ]] && common_ok=1 ;;
      Codex) [[ "$effect_source" == "$effect_fixture"/.codex/agents/.code-simplifier.toml.stage.* ]] && common_ok=1 ;;
    esac
  fi
  result_ok=0
  if [[ "$fault_mode" == replace-* ]]; then
    sentinel_parent_ok=0
    case "$adapter_label" in
      Claude)
        [[ ! -e "$effect_fixture/agents" && ! -L "$effect_fixture/agents" ]] &&
          [[ ! -e "$effect_fixture/.claude" && ! -L "$effect_fixture/.claude" ]] &&
          sentinel_parent_ok=1
        ;;
      Codex)
        [[ ! -e "$effect_fixture/agents" && ! -L "$effect_fixture/agents" ]] &&
          [[ -d "$effect_fixture/.codex/agents" && ! -L "$effect_fixture/.codex/agents" ]] &&
          [[ "$(find "$effect_fixture/.codex/agents" -mindepth 1 -maxdepth 1 -print)" == \
            "$expected_destination" ]] && sentinel_parent_ok=1
        ;;
    esac
    if ((common_ok)) && [[ "$owned_inode" != "$current_inode" ]] &&
      ((sentinel_parent_ok)) &&
      [[ -f "$expected_destination" && ! -L "$expected_destination" ]] &&
      [[ "$(cat "$expected_destination")" == "$sentinel_content" ]] &&
      [[ "$(inode_of "$expected_destination")" == "$current_inode" ]] &&
      [[ ! -e "$effect_fixture/agents/code-simplifier.md" ]] &&
      { [[ "$destination_relative" == "$host_profile_relative" ]] ||
        [[ ! -e "$effect_fixture/$host_profile_relative" ]]; }; then
      result_ok=1
    fi
  elif ((common_ok)) && [[ "$owned_inode" == "$current_inode" ]] &&
    [[ ! -e "$effect_fixture/$destination_relative" && ! -L "$effect_fixture/$destination_relative" ]] &&
    [[ ! -e "$effect_fixture/agents/code-simplifier.md" ]] &&
    [[ ! -e "$effect_fixture/$host_profile_relative" ]] &&
    [[ ! -e "$effect_fixture/agents" && ! -L "$effect_fixture/agents" ]] &&
    { [[ "$adapter_label" == Claude && ! -e "$effect_fixture/.claude" ]] ||
      [[ "$adapter_label" == Codex && ! -e "$effect_fixture/.codex" ]]; }; then
    result_ok=1
  fi
  if ((result_ok)); then
    pass "$adapter_label adapter handles post-effect $fault_mode ${fault_signal:-failure}"
  else
    fail "$adapter_label adapter handles post-effect $fault_mode ${fault_signal:-failure}"
  fi
}

for adapter_signal in HUP TERM INT; do
  case "$adapter_signal" in
    HUP) adapter_signal_status=129 ;;
    TERM) adapter_signal_status=143 ;;
    INT) adapter_signal_status=130 ;;
  esac
  run_post_effect_case "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md \
    .claude/agents/code-simplifier.md signal "$adapter_signal" "$adapter_signal_status"
  run_post_effect_case "$ROOT/adapters/codex.sh" Codex 2 .codex/agents/code-simplifier.toml \
    .codex/agents/code-simplifier.toml signal "$adapter_signal" "$adapter_signal_status"
done
run_post_effect_case "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md \
  .claude/agents/code-simplifier.md fail '' 1
run_post_effect_case "$ROOT/adapters/codex.sh" Codex 2 .codex/agents/code-simplifier.toml \
  .codex/agents/code-simplifier.toml fail '' 1
run_post_effect_case "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md \
  .claude/agents/code-simplifier.md replace-fail '' 1
run_post_effect_case "$ROOT/adapters/codex.sh" Codex 2 .codex/agents/code-simplifier.toml \
  .codex/agents/code-simplifier.toml replace-fail '' 1
run_post_effect_case "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md \
  .claude/agents/code-simplifier.md replace-signal TERM 143
run_post_effect_case "$ROOT/adapters/codex.sh" Codex 2 .codex/agents/code-simplifier.toml \
  .codex/agents/code-simplifier.toml replace-signal TERM 143

# Cleanup failures are aggregated and retain exact invocation-owned serialization.
cleanup_fault_bin="$tmp/cleanup-fault-bin"
mkdir "$cleanup_fault_bin"
real_rm="$(command -v rm)"
real_rmdir="$(command -v rmdir)"
cat > "$cleanup_fault_bin/rm" << 'EOF'
#!/usr/bin/env bash
set -eu
path=''
for argument in "$@"; do
  path=$argument
done
count=0
[[ ! -f "$CLEANUP_RM_COUNT" ]] || count="$(cat "$CLEANUP_RM_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$CLEANUP_RM_COUNT"
if [[ -n "${FAIL_RM_PATTERN:-}" && "$path" == $FAIL_RM_PATTERN ]]; then
  printf 'cleanup-rm\ncount=%s\npath=%s\nppid=%s\n' "$count" "$path" "$PPID" \
    >> "$CLEANUP_EFFECT_MARKER"
  exit 74
fi
exec "$REAL_RM" "$@"
EOF
cat > "$cleanup_fault_bin/rmdir" << 'EOF'
#!/usr/bin/env bash
set -eu
path=$1
count=0
[[ ! -f "$CLEANUP_RMDIR_COUNT" ]] || count="$(cat "$CLEANUP_RMDIR_COUNT")"
count=$((count + 1))
printf '%s\n' "$count" > "$CLEANUP_RMDIR_COUNT"
if [[ -n "${FAIL_RMDIR_PATTERN:-}" && "$path" == $FAIL_RMDIR_PATTERN ]]; then
  printf 'cleanup-rmdir\ncount=%s\npath=%s\nppid=%s\n' "$count" "$path" "$PPID" \
    >> "$CLEANUP_EFFECT_MARKER"
  exit 75
fi
exec "$REAL_RMDIR" "$@"
EOF
chmod +x "$cleanup_fault_bin/rm" "$cleanup_fault_bin/rmdir"

run_stage_cleanup_failure() {
  adapter=$1
  adapter_label=$2
  host_profile_relative=$3
  expected_stage_count=$4
  cleanup_fixture="$tmp/cleanup-stage-$adapter_label"
  mkdir "$cleanup_fixture"
  cp "$target/AGENTS.md" "$cleanup_fixture/AGENTS.md"
  "$adapter" "$cleanup_fixture" > /dev/null
  output_before="$(cksum "$cleanup_fixture/agents/code-simplifier.md" \
    "$cleanup_fixture/$host_profile_relative")"
  cleanup_marker="$tmp/cleanup-stage-$adapter_label.marker"
  cleanup_rm_count="$tmp/cleanup-stage-$adapter_label.rm-count"
  cleanup_rmdir_count="$tmp/cleanup-stage-$adapter_label.rmdir-count"
  cleanup_pid_file="$tmp/cleanup-stage-$adapter_label.pid"
  cleanup_output="$tmp/cleanup-stage-$adapter_label.out"
  cleanup_status=0
  CLEANUP_EFFECT_MARKER="$cleanup_marker" CLEANUP_RM_COUNT="$cleanup_rm_count" \
    CLEANUP_RMDIR_COUNT="$cleanup_rmdir_count" FAIL_RM_PATTERN="$cleanup_fixture/*.stage.*" \
    FAIL_RMDIR_PATTERN='' REAL_RM="$real_rm" REAL_RMDIR="$real_rmdir" \
    ADAPTER_PID_FILE="$cleanup_pid_file" PATH="$cleanup_fault_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; exec "$@"' _ \
      "$adapter" "$cleanup_fixture" > "$cleanup_output" 2>&1 || cleanup_status=$?
  cleanup_pid="$(cat "$cleanup_pid_file")"
  stage_residue_count="$(find "$cleanup_fixture" \( -type f -o -type l \) \
    -path '*.stage.*' | wc -l | tr -d '[:space:]')"
  marker_stage_count="$(grep -c '^cleanup-rm$' "$cleanup_marker" 2> /dev/null || true)"
  diagnostic_stage_count="$(grep -c 'cleanup incomplete: unable to remove stage:' \
    "$cleanup_output" 2> /dev/null || true)"
  if [[ "$cleanup_status" -eq 1 ]] && [[ "$stage_residue_count" -eq "$expected_stage_count" ]] &&
    [[ "$marker_stage_count" -eq "$expected_stage_count" &&
      "$diagnostic_stage_count" -eq "$expected_stage_count" ]] &&
    grep -Fqx "ppid=$cleanup_pid" "$cleanup_marker" &&
    [[ "$(cksum "$cleanup_fixture/agents/code-simplifier.md" \
      "$cleanup_fixture/$host_profile_relative")" == "$output_before" ]] &&
    serialization_is_retained "$cleanup_fixture" && ! grep -q '^installed ' "$cleanup_output"; then
    pass "$adapter_label adapter aggregates stage cleanup failures and retains serialization"
  else
    fail "$adapter_label adapter aggregates stage cleanup failures and retains serialization"
  fi
}

run_stage_cleanup_failure "$ROOT/adapters/claude-code.sh" Claude \
  .claude/agents/code-simplifier.md 3
run_stage_cleanup_failure "$ROOT/adapters/codex.sh" Codex \
  .codex/agents/code-simplifier.toml 2

run_lock_cleanup_failure() {
  adapter=$1
  adapter_label=$2
  host_profile_relative=$3
  cleanup_role=$4
  cleanup_fixture="$tmp/cleanup-$cleanup_role-$adapter_label"
  mkdir "$cleanup_fixture"
  cp "$target/AGENTS.md" "$cleanup_fixture/AGENTS.md"
  cleanup_marker="$tmp/cleanup-$cleanup_role-$adapter_label.marker"
  cleanup_rm_count="$tmp/cleanup-$cleanup_role-$adapter_label.rm-count"
  cleanup_rmdir_count="$tmp/cleanup-$cleanup_role-$adapter_label.rmdir-count"
  cleanup_pid_file="$tmp/cleanup-$cleanup_role-$adapter_label.pid"
  cleanup_output="$tmp/cleanup-$cleanup_role-$adapter_label.out"
  fail_rm_pattern=''
  fail_rmdir_pattern=''
  case "$cleanup_role" in
    lock-owner) fail_rm_pattern="$cleanup_fixture/.research-repo-standard-adapter.lock/owner" ;;
    lock-directory) fail_rmdir_pattern="$cleanup_fixture/.research-repo-standard-adapter.lock" ;;
  esac
  cleanup_status=0
  CLEANUP_EFFECT_MARKER="$cleanup_marker" CLEANUP_RM_COUNT="$cleanup_rm_count" \
    CLEANUP_RMDIR_COUNT="$cleanup_rmdir_count" FAIL_RM_PATTERN="$fail_rm_pattern" \
    FAIL_RMDIR_PATTERN="$fail_rmdir_pattern" REAL_RM="$real_rm" REAL_RMDIR="$real_rmdir" \
    ADAPTER_PID_FILE="$cleanup_pid_file" PATH="$cleanup_fault_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; exec "$@"' _ \
      "$adapter" "$cleanup_fixture" > "$cleanup_output" 2>&1 || cleanup_status=$?
  cleanup_pid="$(cat "$cleanup_pid_file")"
  case "$cleanup_role" in
    lock-owner)
      cleanup_marker_kind=cleanup-rm
      cleanup_expected_path="$cleanup_fixture/.research-repo-standard-adapter.lock/owner"
      ;;
    lock-directory)
      cleanup_marker_kind=cleanup-rmdir
      cleanup_expected_path="$cleanup_fixture/.research-repo-standard-adapter.lock"
      ;;
  esac
  if [[ "$cleanup_status" -eq 1 ]] && grep -Fqx "$cleanup_marker_kind" "$cleanup_marker" &&
    grep -Fqx "path=$cleanup_expected_path" "$cleanup_marker" &&
    grep -Fqx "ppid=$cleanup_pid" "$cleanup_marker" &&
    grep -Fq "cleanup incomplete: unable to remove adapter $cleanup_role:" "$cleanup_output" &&
    [[ -f "$cleanup_fixture/agents/code-simplifier.md" ]] &&
    [[ -f "$cleanup_fixture/$host_profile_relative" ]] &&
    serialization_is_retained "$cleanup_fixture" && ! grep -q '^installed ' "$cleanup_output"; then
    pass "$adapter_label adapter fails closed on $cleanup_role cleanup error"
  else
    fail "$adapter_label adapter fails closed on $cleanup_role cleanup error"
  fi
}

for cleanup_adapter_case in Claude Codex; do
  case "$cleanup_adapter_case" in
    Claude)
      cleanup_adapter="$ROOT/adapters/claude-code.sh"
      cleanup_host_profile=.claude/agents/code-simplifier.md
      ;;
    Codex)
      cleanup_adapter="$ROOT/adapters/codex.sh"
      cleanup_host_profile=.codex/agents/code-simplifier.toml
      ;;
  esac
  run_lock_cleanup_failure "$cleanup_adapter" "$cleanup_adapter_case" \
    "$cleanup_host_profile" lock-owner
  run_lock_cleanup_failure "$cleanup_adapter" "$cleanup_adapter_case" \
    "$cleanup_host_profile" lock-directory
done

run_directory_cleanup_failure() {
  adapter=$1
  adapter_label=$2
  publish_count=$3
  destination_relative=$4
  nested_parent_relative=$5
  cleanup_fixture="$tmp/cleanup-directory-$adapter_label"
  mkdir "$cleanup_fixture"
  cp "$target/AGENTS.md" "$cleanup_fixture/AGENTS.md"
  effect_count="$tmp/cleanup-directory-$adapter_label.mv-count"
  effect_marker="$tmp/cleanup-directory-$adapter_label.mv-marker"
  cleanup_marker="$tmp/cleanup-directory-$adapter_label.marker"
  cleanup_rm_count="$tmp/cleanup-directory-$adapter_label.rm-count"
  cleanup_rmdir_count="$tmp/cleanup-directory-$adapter_label.rmdir-count"
  cleanup_pid_file="$tmp/cleanup-directory-$adapter_label.pid"
  cleanup_output="$tmp/cleanup-directory-$adapter_label.out"
  cleanup_status=0
  MV_COUNT_FILE="$effect_count" MV_EFFECT_MARKER="$effect_marker" \
    EXPECTED_DESTINATION="$cleanup_fixture/$destination_relative" FAIL_ON_COUNT="$publish_count" \
    FAULT_MODE=fail FAULT_SIGNAL='' SENTINEL_CONTENT=unused REAL_MV="$real_mv" \
    CLEANUP_EFFECT_MARKER="$cleanup_marker" CLEANUP_RM_COUNT="$cleanup_rm_count" \
    CLEANUP_RMDIR_COUNT="$cleanup_rmdir_count" FAIL_RM_PATTERN='' \
    FAIL_RMDIR_PATTERN="$cleanup_fixture/$nested_parent_relative" REAL_RM="$real_rm" \
    REAL_RMDIR="$real_rmdir" ADAPTER_PID_FILE="$cleanup_pid_file" \
    PATH="$cleanup_fault_bin:$post_effect_mv_bin:$PATH" \
    bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' \
      _ "$adapter" "$cleanup_fixture" > "$cleanup_output" 2>&1 || cleanup_status=$?
  cleanup_pid="$(cat "$cleanup_pid_file")"
  if [[ "$cleanup_status" -eq 1 ]] && grep -Fqx 'post-effect' "$effect_marker" &&
    grep -Fqx 'cleanup-rmdir' "$cleanup_marker" &&
    grep -Fqx "path=$cleanup_fixture/$nested_parent_relative" "$cleanup_marker" &&
    grep -Fqx "ppid=$cleanup_pid" "$cleanup_marker" &&
    grep -Fq "cleanup incomplete: unable to remove output parent: $cleanup_fixture/$nested_parent_relative" \
      "$cleanup_output" && [[ -d "$cleanup_fixture/$nested_parent_relative" ]] &&
    [[ -z "$(find "$cleanup_fixture/$nested_parent_relative" -mindepth 1 -print -quit)" ]] &&
    serialization_is_retained "$cleanup_fixture" && ! grep -q '^installed ' "$cleanup_output"; then
    pass "$adapter_label adapter retains lock after output-parent cleanup failure"
  else
    fail "$adapter_label adapter retains lock after output-parent cleanup failure"
  fi
}

run_directory_cleanup_failure "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md .claude/agents
run_directory_cleanup_failure "$ROOT/adapters/codex.sh" Codex 2 \
  .codex/agents/code-simplifier.toml .codex/agents

run_output_cleanup_failure() {
  adapter=$1
  adapter_label=$2
  publish_count=$3
  destination_relative=$4
  cleanup_fixture="$tmp/cleanup-output-$adapter_label"
  mkdir "$cleanup_fixture"
  cp "$target/AGENTS.md" "$cleanup_fixture/AGENTS.md"
  effect_count="$tmp/cleanup-output-$adapter_label.mv-count"
  effect_marker="$tmp/cleanup-output-$adapter_label.mv-marker"
  cleanup_marker="$tmp/cleanup-output-$adapter_label.marker"
  cleanup_rm_count="$tmp/cleanup-output-$adapter_label.rm-count"
  cleanup_rmdir_count="$tmp/cleanup-output-$adapter_label.rmdir-count"
  cleanup_pid_file="$tmp/cleanup-output-$adapter_label.pid"
  cleanup_output="$tmp/cleanup-output-$adapter_label.out"
  cleanup_destination="$cleanup_fixture/$destination_relative"
  cleanup_status=0
  MV_COUNT_FILE="$effect_count" MV_EFFECT_MARKER="$effect_marker" \
    EXPECTED_DESTINATION="$cleanup_destination" FAIL_ON_COUNT="$publish_count" \
    FAULT_MODE=signal FAULT_SIGNAL=TERM SENTINEL_CONTENT=unused REAL_MV="$real_mv" \
    CLEANUP_EFFECT_MARKER="$cleanup_marker" CLEANUP_RM_COUNT="$cleanup_rm_count" \
    CLEANUP_RMDIR_COUNT="$cleanup_rmdir_count" FAIL_RM_PATTERN="$cleanup_destination" \
    FAIL_RMDIR_PATTERN='' REAL_RM="$real_rm" REAL_RMDIR="$real_rmdir" \
    EXPECTED_ADAPTER_PID_FILE="$cleanup_pid_file" \
    PATH="$cleanup_fault_bin:$post_effect_mv_bin:$PATH" \
    "$adapter" "$cleanup_fixture" > "$cleanup_output" 2>&1 &
  cleanup_process_pid=$!
  printf '%s\n' "$cleanup_process_pid" > "$cleanup_pid_file"
  wait "$cleanup_process_pid" || cleanup_status=$?
  cleanup_pid="$(cat "$cleanup_pid_file")"
  owned_inode="$(sed -n 's/^owned_inode=//p' "$effect_marker" 2> /dev/null)"
  if [[ "$cleanup_status" -eq 143 ]] && grep -Fqx 'post-effect' "$effect_marker" &&
    grep -Fqx 'signal=TERM' "$effect_marker" && grep -Fqx 'cleanup-rm' "$cleanup_marker" &&
    grep -Fqx "path=$cleanup_destination" "$cleanup_marker" &&
    grep -Fqx "ppid=$cleanup_pid" "$cleanup_marker" &&
    grep -Fq "cleanup incomplete: unable to remove owned output: $cleanup_destination" \
      "$cleanup_output" && [[ -e "$cleanup_destination" || -L "$cleanup_destination" ]] &&
    [[ "$(inode_of "$cleanup_destination")" == "$owned_inode" ]] &&
    [[ ! -e "$cleanup_fixture/agents/code-simplifier.md" ]] &&
    serialization_is_retained "$cleanup_fixture" && ! grep -q '^installed ' "$cleanup_output"; then
    pass "$adapter_label adapter preserves TERM status after owned-output cleanup failure"
  else
    fail "$adapter_label adapter preserves TERM status after owned-output cleanup failure"
  fi
}

run_output_cleanup_failure "$ROOT/adapters/claude-code.sh" Claude 3 CLAUDE.md
run_output_cleanup_failure "$ROOT/adapters/codex.sh" Codex 2 \
  .codex/agents/code-simplifier.toml

# Claude's target-local alias staging directory is also finalized before success.
alias_cleanup_fixture="$tmp/cleanup-alias-staging-Claude"
mkdir "$alias_cleanup_fixture"
cp "$target/AGENTS.md" "$alias_cleanup_fixture/AGENTS.md"
alias_cleanup_marker="$tmp/cleanup-alias-staging.marker"
alias_cleanup_rm_count="$tmp/cleanup-alias-staging.rm-count"
alias_cleanup_rmdir_count="$tmp/cleanup-alias-staging.rmdir-count"
alias_cleanup_pid_file="$tmp/cleanup-alias-staging.pid"
alias_cleanup_output="$tmp/cleanup-alias-staging.out"
alias_cleanup_status=0
CLEANUP_EFFECT_MARKER="$alias_cleanup_marker" CLEANUP_RM_COUNT="$alias_cleanup_rm_count" \
  CLEANUP_RMDIR_COUNT="$alias_cleanup_rmdir_count" FAIL_RM_PATTERN='' \
  FAIL_RMDIR_PATTERN="$alias_cleanup_fixture/.CLAUDE.md.stage.*" REAL_RM="$real_rm" \
  REAL_RMDIR="$real_rmdir" ADAPTER_PID_FILE="$alias_cleanup_pid_file" \
  PATH="$cleanup_fault_bin:$PATH" \
  bash -c 'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; exec "$@"' _ \
    "$ROOT/adapters/claude-code.sh" "$alias_cleanup_fixture" > "$alias_cleanup_output" 2>&1 ||
  alias_cleanup_status=$?
alias_cleanup_pid="$(cat "$alias_cleanup_pid_file")"
alias_staging_path="$(sed -n 's/^path=//p' "$alias_cleanup_marker" 2> /dev/null)"
if [[ "$alias_cleanup_status" -eq 1 ]] && grep -Fqx 'cleanup-rmdir' "$alias_cleanup_marker" &&
  [[ "$alias_staging_path" == "$alias_cleanup_fixture"/.CLAUDE.md.stage.* ]] &&
  grep -Fqx "ppid=$alias_cleanup_pid" "$alias_cleanup_marker" &&
  grep -Fq 'cleanup incomplete: unable to remove alias staging directory:' "$alias_cleanup_output" &&
  [[ -d "$alias_staging_path" ]] && serialization_is_retained "$alias_cleanup_fixture" &&
  ! grep -q '^installed ' "$alias_cleanup_output"; then
  pass "Claude adapter retains lock after alias-staging cleanup failure"
else
  fail "Claude adapter retains lock after alias-staging cleanup failure"
fi

# Rollback removes only outputs created by that invocation.
first_mv_bin="$tmp/first-mv-bin"
mkdir "$first_mv_bin"
cat > "$first_mv_bin/mv" << 'EOF'
#!/usr/bin/env bash
set -eu
count=0
[[ ! -f "$MV_PRE_COUNT_FILE" ]] || count="$(cat "$MV_PRE_COUNT_FILE")"
count=$((count + 1))
printf '%s\n' "$count" > "$MV_PRE_COUNT_FILE"
printf 'pre-effect-mv\ncount=%s\nsource=%s\ndestination=%s\nppid=%s\n' \
  "$count" "$1" "$2" "$PPID" > "$MV_PRE_MARKER"
[[ "$PPID" == "$EXPECTED_ADAPTER_PID" ]] || exit 1
exit 1
EOF
chmod +x "$first_mv_bin/mv"

claude_existing="$tmp/claude-existing-before-failure"
mkdir -p "$claude_existing/agents"
cp "$target/AGENTS.md" "$claude_existing/AGENTS.md"
cp "$ROOT/agents/code-simplifier.md" "$claude_existing/agents/code-simplifier.md"
ln -s AGENTS.md "$claude_existing/CLAUDE.md"
claude_existing_before="$(cksum "$claude_existing/agents/code-simplifier.md")"
claude_existing_inode="$(inode_of "$claude_existing/agents/code-simplifier.md")"
claude_existing_alias_inode="$(inode_of "$claude_existing/CLAUDE.md")"
claude_pre_count="$tmp/claude-pre-mv.count"
claude_pre_marker="$tmp/claude-pre-mv.marker"
claude_pre_pid="$tmp/claude-pre-mv.pid"
claude_pre_status=0
MV_PRE_COUNT_FILE="$claude_pre_count" MV_PRE_MARKER="$claude_pre_marker" ADAPTER_PID_FILE="$claude_pre_pid" \
  PATH="$first_mv_bin:$PATH" bash -c \
    'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/claude-code.sh" "$claude_existing" > /dev/null 2>&1 || claude_pre_status=$?
claude_pre_source="$(sed -n 's/^source=//p' "$claude_pre_marker" 2> /dev/null)"
if [[ "$claude_pre_status" -eq 0 ]]; then
  fail "Claude adapter reports a host publish failure with pre-existing outputs"
elif [[ "$claude_pre_status" -eq 1 ]] && [[ "$(cat "$claude_pre_count" 2> /dev/null)" == "1" ]] &&
  grep -Fqx 'pre-effect-mv' "$claude_pre_marker" && grep -Fqx 'count=1' "$claude_pre_marker" &&
  [[ "$claude_pre_source" == "$claude_existing"/.claude/agents/.code-simplifier.md.stage.* ]] &&
  grep -Fqx "destination=$claude_existing/.claude/agents/code-simplifier.md" "$claude_pre_marker" &&
  grep -Fqx "ppid=$(cat "$claude_pre_pid")" "$claude_pre_marker" &&
  [[ "$(cksum "$claude_existing/agents/code-simplifier.md")" == "$claude_existing_before" ]] &&
  [[ "$(inode_of "$claude_existing/agents/code-simplifier.md")" == "$claude_existing_inode" ]] &&
  [[ "$(inode_of "$claude_existing/CLAUDE.md")" == "$claude_existing_alias_inode" ]] &&
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
codex_existing_inode="$(inode_of "$codex_existing/agents/code-simplifier.md")"
codex_pre_count="$tmp/codex-pre-mv.count"
codex_pre_marker="$tmp/codex-pre-mv.marker"
codex_pre_pid="$tmp/codex-pre-mv.pid"
codex_pre_status=0
MV_PRE_COUNT_FILE="$codex_pre_count" MV_PRE_MARKER="$codex_pre_marker" ADAPTER_PID_FILE="$codex_pre_pid" \
  PATH="$first_mv_bin:$PATH" bash -c \
    'printf "%s\n" "$$" > "$ADAPTER_PID_FILE"; export EXPECTED_ADAPTER_PID=$$; exec "$@"' _ \
    "$ROOT/adapters/codex.sh" "$codex_existing" > /dev/null 2>&1 || codex_pre_status=$?
codex_pre_source="$(sed -n 's/^source=//p' "$codex_pre_marker" 2> /dev/null)"
if [[ "$codex_pre_status" -eq 0 ]]; then
  fail "Codex adapter reports a TOML publish failure with a pre-existing output"
elif [[ "$codex_pre_status" -eq 1 ]] && [[ "$(cat "$codex_pre_count" 2> /dev/null)" == "1" ]] &&
  grep -Fqx 'pre-effect-mv' "$codex_pre_marker" && grep -Fqx 'count=1' "$codex_pre_marker" &&
  [[ "$codex_pre_source" == "$codex_existing"/.codex/agents/.code-simplifier.toml.stage.* ]] &&
  grep -Fqx "destination=$codex_existing/.codex/agents/code-simplifier.toml" "$codex_pre_marker" &&
  grep -Fqx "ppid=$(cat "$codex_pre_pid")" "$codex_pre_marker" &&
  [[ "$(cksum "$codex_existing/agents/code-simplifier.md")" == "$codex_existing_before" ]] &&
  [[ "$(inode_of "$codex_existing/agents/code-simplifier.md")" == "$codex_existing_inode" ]] &&
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
