#!/usr/bin/env bash
# Tests for vendor.sh. Plain bash + temp dirs; no framework.
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

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# --- 1. fresh vendor copies only portable AGENTS.md ---
t1="$tmp/fresh"
mkdir "$t1"
fresh_stdout="$tmp/fresh.stdout"
fresh_stderr="$tmp/fresh.stderr"
"$ROOT/vendor.sh" "$t1" > "$fresh_stdout" 2> "$fresh_stderr"
fresh_status=$?
top_level_count="$(find "$t1" -mindepth 1 -maxdepth 1 | wc -l | tr -d '[:space:]')"
if [[ "$fresh_status" -eq 0 ]]; then
  pass "fresh portable vendor exits successfully"
else
  fail "fresh portable vendor exits successfully"
fi
if cmp -s "$ROOT/AGENTS.md" "$t1/AGENTS.md" &&
  [[ "$top_level_count" -eq 1 ]]; then
  pass "fresh portable vendor contains only AGENTS.md"
else
  fail "fresh portable vendor contains only AGENTS.md"
fi
expected_fresh_output="$(printf 'vendored AGENTS.md -> %s\nnext: fill in the '\''## This repository'\'' section of %s/AGENTS.md' "$t1" "$t1")"
if [[ "$(cat "$fresh_stdout")" == "$expected_fresh_output" ]] &&
  [[ ! -s "$fresh_stderr" ]]; then
  pass "fresh portable vendor prints version-neutral success output"
else
  fail "fresh portable vendor prints version-neutral success output"
fi

# --- 2. re-vendor replaces stale canonical content and preserves the complete local section ---
local_section="$tmp/local-section.expected"
{
  printf '\n'
  printf 'CUSTOM-MARKER project identity line.\n'
  printf 'Reader start: `README.md` and `make help`.\n'
  printf '\n'
  printf '### Local boundaries\n'
  printf '\n'
  printf -- '- Keep this complete multi-line section byte-for-byte.\n'
  printf '\n'
} > "$local_section"
canonical_head="$tmp/canonical.head"
canonical_tail="$tmp/canonical.tail"
stale_tail="$tmp/stale.tail"
awk '{print} /^## This repository$/{exit}' "$ROOT/AGENTS.md" > "$canonical_head"
awk '/^## Using this standard$/{f=1} f' "$ROOT/AGENTS.md" > "$canonical_tail"
{
  cat "$canonical_tail"
  printf '\nSTALE-CANONICAL-CONTENT\n'
} > "$stale_tail"
{
  cat "$canonical_head"
  cat "$local_section"
  cat "$stale_tail"
} > "$t1/AGENTS.md.new" && mv "$t1/AGENTS.md.new" "$t1/AGENTS.md"
stale_target="$tmp/stale-target.before"
cp "$t1/AGENTS.md" "$stale_target"
expected_revendor="$tmp/revendor.expected"
{
  cat "$canonical_head"
  cat "$local_section"
  cat "$canonical_tail"
} > "$expected_revendor"
"$ROOT/vendor.sh" "$t1" > /dev/null 2>&1
revendor_status=$?
actual_local_section="$tmp/local-section.actual"
awk '/^## This repository$/{s=1;next} /^## Using this standard$/{s=0} s' \
  "$t1/AGENTS.md" > "$actual_local_section"
if [[ "$revendor_status" -eq 0 ]]; then
  pass "re-vendor exits successfully"
else
  fail "re-vendor exits successfully"
fi
if grep -Fqx 'STALE-CANONICAL-CONTENT' "$stale_target" &&
  ! cmp -s "$stale_target" "$t1/AGENTS.md" &&
  ! grep -Fq 'STALE-CANONICAL-CONTENT' "$t1/AGENTS.md" &&
  cmp -s "$expected_revendor" "$t1/AGENTS.md" &&
  cmp -s "$local_section" "$actual_local_section"; then
  pass "re-vendor replaces canonical bytes and preserves the complete This repository section"
else
  fail "re-vendor replaces canonical bytes and preserves the complete This repository section"
fi

# --- 3. a source missing a boundary heading aborts, target untouched ---
bad="$tmp/badsrc"
mkdir "$bad"
cp "$ROOT/vendor.sh" "$bad/vendor.sh"
grep -vx '## Using this standard' "$ROOT/AGENTS.md" > "$bad/AGENTS.md"
t3="$tmp/badtarget"
mkdir "$t3"
echo "sentinel" > "$t3/AGENTS.md"
corrupt_source_status=0
err3="$("$bad/vendor.sh" "$t3" 2>&1 > /dev/null)" || corrupt_source_status=$?
if [[ "$corrupt_source_status" -eq 1 ]]; then
  pass "corrupted source aborts"
else
  fail "corrupted source must abort with status 1"
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
t4="$tmp/badtarget2"
mkdir "$t4"
printf '## This repository\n\nSome content.\n' > "$t4/AGENTS.md"
malformed_target_before="$tmp/malformed-target.before"
cp "$t4/AGENTS.md" "$malformed_target_before"
malformed_target_inode="$(inode_of "$t4/AGENTS.md")"
malformed_status=0
err4="$("$ROOT/vendor.sh" "$t4" 2>&1 > /dev/null)" || malformed_status=$?
if [[ "$malformed_status" -eq 1 ]]; then
  pass "malformed target aborts"
else
  fail "malformed target must abort with status 1"
fi
if echo "$err4" | grep -q "## Using this standard"; then
  pass "malformed target prints diagnostic"
else
  fail "malformed target prints diagnostic"
fi
if cmp -s "$malformed_target_before" "$t4/AGENTS.md" &&
  [[ "$(inode_of "$t4/AGENTS.md")" == "$malformed_target_inode" ]]; then
  pass "aborted malformed-target vendor preserves target bytes and inode"
else
  fail "aborted malformed-target vendor preserves target bytes and inode"
fi

# --- 5. staging happens inside the target for same-filesystem replacement ---
real_mv="$(command -v mv)"
mkdir "$tmp/bin"
cat > "$tmp/bin/mv" << 'EOF'
#!/usr/bin/env bash
set -eu
[[ $# -eq 2 ]] || exit 97
count=0
if [[ -f "$MV_COUNT_FILE" ]]; then
  IFS= read -r count < "$MV_COUNT_FILE"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"
source=$1
destination=$2
destination_dir="$(cd "$(dirname "$destination")" && pwd -P)"
probe="$destination_dir/.vendor-same-filesystem-probe"
ln "$source" "$probe"
rm "$probe"
printf 'external-effect=staging-rename\ncount=%s\nsource=%s\ndestination=%s\npid=%s\n' \
  "$count" "$source" "$destination" "$PPID" > "$MV_EFFECT_MARKER"
exec "$REAL_MV" "$source" "$destination"
EOF
chmod +x "$tmp/bin/mv"
t5="$tmp/staging-target"
mkdir "$t5"
staging_count="$tmp/staging-mv.count"
staging_marker="$tmp/staging-mv.marker"
MV_COUNT_FILE="$staging_count" MV_EFFECT_MARKER="$staging_marker" \
  REAL_MV="$real_mv" PATH="$tmp/bin:$PATH" \
  "$ROOT/vendor.sh" "$t5" > /dev/null 2>&1 &
staging_vendor_pid=$!
wait "$staging_vendor_pid"
staging_status=$?
if [[ "$staging_status" -eq 0 ]]; then
  pass "same-filesystem staging vendor exits successfully"
else
  fail "same-filesystem staging vendor exits successfully"
fi
staging_source=""
if [[ -f "$staging_marker" ]]; then
  staging_source="$(sed -n 's/^source=//p' "$staging_marker")"
fi
staging_source_dir="$(dirname "$staging_source")"
target_dir="$(cd "$t5" && pwd -P)"
expected_staging_marker="$(printf 'external-effect=staging-rename\ncount=1\nsource=%s\ndestination=%s\npid=%s' \
  "$staging_source" "$t5/AGENTS.md" "$staging_vendor_pid")"
if [[ "$(cat "$staging_count" 2> /dev/null)" == "1" ]] &&
  [[ "$(cat "$staging_marker" 2> /dev/null)" == "$expected_staging_marker" ]] &&
  [[ "$(dirname "$staging_source_dir")" == "$target_dir" ]] &&
  [[ "$(basename "$staging_source_dir")" == .vendor.?????? ]] &&
  [[ "$(basename "$staging_source")" == "AGENTS.md" ]] &&
  cmp -s "$ROOT/AGENTS.md" "$t5/AGENTS.md"; then
  pass "vendor stages beside the destination with exact rename evidence"
else
  fail "vendor stages beside the destination with exact rename evidence"
fi

# --- 6. a failed final replacement preserves the previous target and cleans staging ---
t6="$tmp/failed-replacement"
mkdir "$t6"
cp "$ROOT/AGENTS.md" "$t6/AGENTS.md"
awk '/^## This repository$/{print; print ""; print "PREVIOUS-TARGET-IDENTITY"; next} {print}' \
  "$t6/AGENTS.md" > "$t6/AGENTS.md.previous" && mv "$t6/AGENTS.md.previous" "$t6/AGENTS.md"
previous_checksum="$(cksum "$t6/AGENTS.md")"
previous_inode="$(inode_of "$t6/AGENTS.md")"
mkdir "$tmp/fail-bin"
cat > "$tmp/fail-bin/mv" << 'EOF'
#!/usr/bin/env bash
set -u
[[ $# -eq 2 ]] || exit 97
count=0
if [[ -f "$MV_COUNT_FILE" ]]; then
  IFS= read -r count < "$MV_COUNT_FILE"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$MV_COUNT_FILE"
printf 'external-effect=failed-final-rename\ncount=%s\nsource=%s\ndestination=%s\npid=%s\n' \
  "$count" "$1" "$2" "$PPID" > "$MV_EFFECT_MARKER"
exit 1
EOF
chmod +x "$tmp/fail-bin/mv"
failed_count="$tmp/failed-mv.count"
failed_marker="$tmp/failed-mv.marker"
MV_COUNT_FILE="$failed_count" MV_EFFECT_MARKER="$failed_marker" \
  PATH="$tmp/fail-bin:$PATH" "$ROOT/vendor.sh" "$t6" \
  > /dev/null 2>&1 &
failed_vendor_pid=$!
wait "$failed_vendor_pid"
failed_status=$?
if [[ "$failed_status" -eq 1 ]]; then
  pass "failed final replacement exits with status 1"
else
  fail "failed final replacement must abort"
fi
failed_source=""
if [[ -f "$failed_marker" ]]; then
  failed_source="$(sed -n 's/^source=//p' "$failed_marker")"
fi
failed_source_dir="$(dirname "$failed_source")"
failed_target_dir="$(cd "$t6" && pwd -P)"
expected_failed_marker="$(printf 'external-effect=failed-final-rename\ncount=1\nsource=%s\ndestination=%s\npid=%s' \
  "$failed_source" "$t6/AGENTS.md" "$failed_vendor_pid")"
if [[ "$(cat "$failed_count" 2> /dev/null)" == "1" ]] &&
  [[ "$(cat "$failed_marker" 2> /dev/null)" == "$expected_failed_marker" ]] &&
  [[ "$(dirname "$failed_source_dir")" == "$failed_target_dir" ]] &&
  [[ "$(basename "$failed_source_dir")" == .vendor.?????? ]] &&
  [[ "$(basename "$failed_source")" == "AGENTS.md" ]]; then
  pass "failed final replacement records the exact rename call"
else
  fail "failed final replacement records the exact rename call"
fi
if [[ "$(cksum "$t6/AGENTS.md")" == "$previous_checksum" ]] &&
  [[ "$(inode_of "$t6/AGENTS.md")" == "$previous_inode" ]] &&
  ! compgen -G "$t6/.vendor.*" > /dev/null; then
  pass "failed final replacement preserves target checksum and inode and cleans staging"
else
  fail "failed final replacement preserves target checksum and inode and cleans staging"
fi

# --- final ---
if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all tests passed"
