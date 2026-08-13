#!/usr/bin/env bash
# Fault-injection tests for staging, create-only publication, signals, and cleanup.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ORIGINAL_PATH=$PATH
REAL_MKTEMP="$(command -v mktemp)"
FAILS=0

pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}
run_case() {
  case_name=$1
  shift
  if "$@"; then pass "$case_name"; else fail "$case_name"; fi
}
inode_of() { LC_ALL=C ls -di "$1" | awk '{ print $1 }'; }
path_exists() { [[ -e "$1" || -L "$1" ]]; }

test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
fault_bin="$test_root/fault-bin"
mkdir "$fault_bin"
trap 'rm -rf "$test_root"' EXIT

cat > "$fault_bin/ln" <<'DOUBLE'
#!/usr/bin/env bash
set -u
mode=${RRS_LN_MODE-${RRS_FAULT_MODE-none}}
if [[ "${RRS_FAULT_OPERATION-none}" != ln && -z "${RRS_LN_MODE-}" ]]; then
  exec /bin/ln "$@"
fi
marker=${RRS_LN_MARKER-${RRS_FAULT_MARKER:?}}
count_file=${RRS_LN_COUNT-${RRS_FAULT_COUNT:?}}
count=1
[[ -f "$count_file" ]] && count=$(($(cat "$count_file") + 1))
printf '%s\n' "$count" > "$count_file"
write_marker() {
  {
    printf 'operation=ln\ncount=%s\npid=%s\nppid=%s\nsource=%s\ndestination=%s\n' \
      "$count" "$$" "${RRS_ADAPTER_PID:?}" "$1" "$2"
    [[ -n "${3-}" ]] && printf 'effect_inode=%s\n' "$3"
    printf 'return_status=%s\n' "$4"
  } > "$marker"
}
case "$mode" in
  pre-fail)
    write_marker "$1" "$2" '' 71
    exit 71
    ;;
  collision)
    printf 'competitor\n' > "$2"
    write_marker "$1" "$2" "$(LC_ALL=C ls -di "$2" | awk '{ print $1 }')" 72
    exit 72
    ;;
  pre-HUP|pre-INT|pre-TERM)
    signal=${mode#pre-}
    write_marker "$1" "$2" '' 73
    kill -"$signal" "$RRS_ADAPTER_PID"
    exit 73
    ;;
  post-fail|post-HUP|post-INT|post-TERM)
    /bin/ln "$1" "$2" || exit 74
    effect_inode="$(LC_ALL=C ls -di "$2" | awk '{ print $1 }')"
    write_marker "$1" "$2" "$effect_inode" 75
    case "$mode" in
      post-HUP) kill -HUP "$RRS_ADAPTER_PID" ;;
      post-INT) kill -INT "$RRS_ADAPTER_PID" ;;
      post-TERM) kill -TERM "$RRS_ADAPTER_PID" ;;
    esac
    exit 75
    ;;
  *) exec /bin/ln "$@" ;;
esac
DOUBLE

cat > "$fault_bin/mktemp" <<'DOUBLE'
#!/usr/bin/env bash
set -u
template=${1-}
case "$template" in
  *.research-code-simplifier.stage.XXXXXX) ;;
  *) exec "$REAL_MKTEMP" "$@" ;;
esac
mode=${RRS_MKTEMP_MODE-${RRS_FAULT_MODE-none}}
if [[ "${RRS_FAULT_OPERATION-none}" != mktemp && -z "${RRS_MKTEMP_MODE-}" ]]; then
  stage_path="$($REAL_MKTEMP "$template")" || exit $?
  printf '%s\n' "$stage_path" > "${RRS_STAGE_RECORD:?}"
  printf '%s\n' "$stage_path"
  exit 0
fi
marker=${RRS_MKTEMP_MARKER-${RRS_FAULT_MARKER:?}}
count_file=${RRS_MKTEMP_COUNT-${RRS_FAULT_COUNT:?}}
count=1
[[ -f "$count_file" ]] && count=$(($(cat "$count_file") + 1))
printf '%s\n' "$count" > "$count_file"
write_marker() {
  {
    printf 'operation=mktemp\ncount=%s\npid=%s\nppid=%s\ntemplate=%s\n' \
      "$count" "$$" "${RRS_ADAPTER_PID:?}" "$template"
    [[ -n "${1-}" ]] && printf 'path=%s\neffect_inode=%s\n' "$1" "$2"
    printf 'return_status=%s\n' "$3"
  } > "$marker"
}
case "$mode" in
  pre-fail)
    write_marker '' '' 70
    exit 70
    ;;
  post-fail|post-TERM)
    stage_path="$($REAL_MKTEMP "$template")" || exit $?
    printf '%s\n' "$stage_path" > "${RRS_STAGE_RECORD:?}"
    stage_inode="$(LC_ALL=C ls -di "$stage_path" | awk '{ print $1 }')"
    write_marker "$stage_path" "$stage_inode" 76
    printf '%s\n' "$stage_path"
    [[ "$mode" == post-TERM ]] && kill -TERM "$RRS_ADAPTER_PID"
    exit 76
    ;;
  *)
    stage_path="$($REAL_MKTEMP "$template")" || exit $?
    printf '%s\n' "$stage_path" > "${RRS_STAGE_RECORD:?}"
    printf '%s\n' "$stage_path"
    ;;
esac
DOUBLE

cat > "$fault_bin/rm" <<'DOUBLE'
#!/usr/bin/env bash
set -u
path=''
for argument in "$@"; do path=$argument; done
recorded=''
[[ -f "${RRS_STAGE_RECORD-}" ]] && recorded="$(cat "$RRS_STAGE_RECORD")"
mode=${RRS_RM_MODE-${RRS_FAULT_MODE-none}}
if [[ "${RRS_FAULT_OPERATION-none}" != rm && -z "${RRS_RM_MODE-}" ]] ||
  [[ -z "$recorded" || "$path" != "$recorded" ]]; then
  exec /bin/rm "$@"
fi
marker=${RRS_RM_MARKER-${RRS_FAULT_MARKER:?}}
count_file=${RRS_RM_COUNT-${RRS_FAULT_COUNT:?}}
count=1
[[ -f "$count_file" ]] && count=$(($(cat "$count_file") + 1))
printf '%s\n' "$count" > "$count_file"
write_marker() {
  {
    printf 'operation=rm\ncount=%s\npid=%s\nppid=%s\npath=%s\n' \
      "$count" "$$" "${RRS_ADAPTER_PID:?}" "$path"
    [[ -n "${1-}" ]] && printf 'effect_inode=%s\n' "$1"
    printf 'return_status=%s\n' "$2"
  } > "$marker"
}
case "$mode" in
  fail)
    write_marker '' 77
    exit 77
    ;;
  replace)
    /bin/rm -f "$path" || exit 79
    printf 'foreign replacement\n' > "$path"
    effect_inode="$(LC_ALL=C ls -di "$path" | awk '{ print $1 }')"
    write_marker "$effect_inode" 78
    exit 78
    ;;
  *) exec /bin/rm "$@" ;;
esac
DOUBLE
chmod +x "$fault_bin/ln" "$fault_bin/mktemp" "$fault_bin/rm"

adapter_for() {
  case "$1" in
    claude-code) printf '%s\n' "$ROOT/adapters/claude-code.sh" ;;
    codex) printf '%s\n' "$ROOT/adapters/codex.sh" ;;
  esac
}
destination_for() {
  case "$1" in
    claude-code) printf '%s/.claude/agents/research-code-simplifier.md\n' "$2" ;;
    codex) printf '%s/.codex/agents/research-code-simplifier.toml\n' "$2" ;;
  esac
}
assert_marker() {
  marker=$1 operation=$2 count=$3 adapter_pid=$4
  [[ -f "$marker" ]] &&
    grep -Fqx "operation=$operation" "$marker" &&
    grep -Fqx "count=$count" "$marker" &&
    grep -Fqx "ppid=$adapter_pid" "$marker" &&
    grep -Eq '^pid=[1-9][0-9]*$' "$marker"
}
marker_value() { awk -F= -v key="$2" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$1"; }
assert_stage_absent() {
  fixture=$1
  ! find "$fixture" -mindepth 1 -name '.research-code-simplifier.stage.*' \
    -print -quit | grep -q .
}
assert_no_old_transaction_artifacts() {
  fixture=$1
  ! find "$fixture" -mindepth 1 \
    \( -name '.research-repo-standard-adapter.lock' \
      -o -name '.research-repo-standard-adapter.guard' \
      -o -name '.research-repo-standard-adapter.claim.*' \) \
    -print -quit | grep -q .
}

run_fault_case() {
  case_name=$1 adapter=$2 mode=$3 expected_status=$4 host=$5
  fixture="$test_root/$case_name"
  marker="$test_root/$case_name.marker"
  count_file="$test_root/$case_name.count"
  output="$test_root/$case_name.output"
  stage_record="$test_root/$case_name.stage"
  mkdir "$fixture"
  set +e
  PATH="$fault_bin:$ORIGINAL_PATH" REAL_MKTEMP="$REAL_MKTEMP" \
    RRS_FAULT_OPERATION=ln RRS_FAULT_MODE="$mode" \
    RRS_FAULT_MARKER="$marker" RRS_FAULT_COUNT="$count_file" \
    RRS_STAGE_RECORD="$stage_record" \
    "$adapter" "$fixture" > "$output" 2>&1
  actual_status=$?
  set -e
  [[ "$actual_status" -eq "$expected_status" ]] || return 1
  [[ -f "$marker" ]] || return 1
  adapter_pid="$(awk -F= '$1 == "ppid" { print $2; exit }' "$marker")"
  [[ "$adapter_pid" =~ ^[1-9][0-9]*$ ]] || return 1
  assert_marker "$marker" ln 1 "$adapter_pid" || return 1
  stage_path="$(cat "$stage_record")"
  destination="$(destination_for "$host" "$fixture")"
  [[ "$(marker_value "$marker" source)" == "$stage_path" ]] || return 1
  [[ "$(marker_value "$marker" destination)" == "$destination" ]] || return 1
  case "$mode" in
    pre-fail)
      [[ "$(marker_value "$marker" return_status)" == 71 ]] &&
        ! path_exists "$destination" && assert_stage_absent "$fixture"
      ;;
    collision)
      [[ "$(marker_value "$marker" return_status)" == 72 ]] &&
        [[ "$(cat "$destination")" == competitor ]] &&
        [[ "$(marker_value "$marker" effect_inode)" == "$(inode_of "$destination")" ]] &&
        assert_stage_absent "$fixture"
      ;;
    post-fail)
      [[ "$(marker_value "$marker" return_status)" == 75 ]] &&
        [[ -f "$destination" && ! -L "$destination" ]] &&
        [[ "$(marker_value "$marker" effect_inode)" == "$(inode_of "$destination")" ]] &&
        assert_stage_absent "$fixture"
      ;;
    pre-HUP|pre-INT|pre-TERM)
      [[ "$(marker_value "$marker" return_status)" == 73 ]] &&
        ! path_exists "$destination" && assert_stage_absent "$fixture"
      ;;
    post-HUP|post-INT|post-TERM)
      [[ "$(marker_value "$marker" return_status)" == 75 ]] &&
        [[ -f "$destination" && ! -L "$destination" ]] &&
        [[ "$(marker_value "$marker" effect_inode)" == "$(inode_of "$destination")" ]] &&
        assert_stage_absent "$fixture"
      ;;
  esac && assert_no_old_transaction_artifacts "$fixture"
}

run_mktemp_fault_case() {
  case_name=$1 adapter=$2 mode=$3 expected_status=$4 host=$5
  fixture="$test_root/$case_name"
  marker="$test_root/$case_name.marker"
  count_file="$test_root/$case_name.count"
  output="$test_root/$case_name.output"
  stage_record="$test_root/$case_name.stage"
  mkdir "$fixture"
  set +e
  PATH="$fault_bin:$ORIGINAL_PATH" REAL_MKTEMP="$REAL_MKTEMP" \
    RRS_FAULT_OPERATION=mktemp RRS_FAULT_MODE="$mode" \
    RRS_FAULT_MARKER="$marker" RRS_FAULT_COUNT="$count_file" \
    RRS_STAGE_RECORD="$stage_record" \
    "$adapter" "$fixture" > "$output" 2>&1
  actual_status=$?
  set -e
  [[ "$actual_status" -eq "$expected_status" ]] || return 1
  [[ -f "$marker" ]] || return 1
  adapter_pid="$(awk -F= '$1 == "ppid" { print $2; exit }' "$marker")"
  [[ "$adapter_pid" =~ ^[1-9][0-9]*$ ]] || return 1
  assert_marker "$marker" mktemp 1 "$adapter_pid" || return 1
  expected_template="$(destination_for "$host" "$fixture")"
  expected_template="${expected_template%/*}/.research-code-simplifier.stage.XXXXXX"
  [[ "$(marker_value "$marker" template)" == "$expected_template" ]] || return 1
  ! path_exists "$(destination_for "$host" "$fixture")" || return 1
  case "$mode" in
    pre-fail)
      [[ "$(marker_value "$marker" return_status)" == 70 ]] &&
        [[ ! -e "$stage_record" ]] && assert_stage_absent "$fixture"
      ;;
    post-fail|post-TERM)
      stage_path="$(cat "$stage_record")"
      [[ "$(marker_value "$marker" path)" == "$stage_path" ]] &&
        [[ "$(marker_value "$marker" effect_inode)" == "$(inode_of "$stage_path")" ]] &&
        [[ "$(marker_value "$marker" return_status)" == 76 ]] &&
        [[ -f "$stage_path" ]] || return 1
      if [[ "$mode" == post-fail ]]; then
        grep -Fq 'unclaimed and preserved' "$output"
      else
        # The pending signal is honored before ordinary failure reporting.
        true
      fi
      ;;
  esac && assert_no_old_transaction_artifacts "$fixture"
}

run_cleanup_fault_case() {
  case_name=$1 adapter=$2 phase=$3 mode=$4 expected_status=$5 host=$6
  fixture="$test_root/$case_name"
  ln_marker="$test_root/$case_name.ln.marker"
  ln_count="$test_root/$case_name.ln.count"
  rm_marker="$test_root/$case_name.rm.marker"
  rm_count="$test_root/$case_name.rm.count"
  output="$test_root/$case_name.output"
  stage_record="$test_root/$case_name.stage"
  mkdir "$fixture"
  ln_mode=none
  [[ "$phase" == before ]] && ln_mode=pre-fail
  set +e
  PATH="$fault_bin:$ORIGINAL_PATH" REAL_MKTEMP="$REAL_MKTEMP" \
    RRS_FAULT_OPERATION=cleanup RRS_LN_MODE="$ln_mode" RRS_RM_MODE="$mode" \
    RRS_LN_MARKER="$ln_marker" RRS_LN_COUNT="$ln_count" \
    RRS_RM_MARKER="$rm_marker" RRS_RM_COUNT="$rm_count" \
    RRS_FAULT_MARKER="$rm_marker" RRS_FAULT_COUNT="$rm_count" \
    RRS_STAGE_RECORD="$stage_record" \
    "$adapter" "$fixture" > "$output" 2>&1
  actual_status=$?
  set -e
  [[ "$actual_status" -eq "$expected_status" ]] || return 1
  [[ -f "$rm_marker" ]] || return 1
  adapter_pid="$(awk -F= '$1 == "ppid" { print $2; exit }' "$rm_marker")"
  [[ "$adapter_pid" =~ ^[1-9][0-9]*$ ]] || return 1
  assert_marker "$rm_marker" rm 1 "$adapter_pid" || return 1
  stage_path="$(cat "$stage_record")"
  [[ "$(marker_value "$rm_marker" path)" == "$stage_path" ]] || return 1
  destination="$(destination_for "$host" "$fixture")"
  if [[ "$phase" == before ]]; then
    assert_marker "$ln_marker" ln 1 "$adapter_pid" || return 1
    [[ "$(marker_value "$ln_marker" source)" == "$stage_path" ]] || return 1
    [[ "$(marker_value "$ln_marker" destination)" == "$destination" ]] || return 1
    [[ "$(marker_value "$ln_marker" return_status)" == 71 ]] || return 1
    ! path_exists "$destination" || return 1
  else
    [[ -f "$destination" && ! -L "$destination" ]] || return 1
  fi
  case "$mode" in
    fail)
      [[ "$(marker_value "$rm_marker" return_status)" == 77 ]] &&
        [[ -f "$stage_path" ]] &&
        grep -Fq 'unable to remove owned staging file' "$output"
      ;;
    replace)
      [[ "$(marker_value "$rm_marker" return_status)" == 78 ]] &&
        [[ "$(cat "$stage_path")" == 'foreign replacement' ]] &&
        [[ "$(marker_value "$rm_marker" effect_inode)" == "$(inode_of "$stage_path")" ]] &&
        grep -Fq 'staging file changed during cleanup; preserving replacement' "$output"
      ;;
  esac && assert_no_old_transaction_artifacts "$fixture"
}

malformed_canonical_is_rejected() {
  host=$1
  copy_root="$test_root/malformed-source-$host"
  mkdir -p "$copy_root/adapters" "$copy_root/agents" "$copy_root/target"
  cp "$ROOT/adapters/profile-installer.sh" "$ROOT/adapters/$host.sh" "$copy_root/adapters/" \
    2>/dev/null || return 1
  cat > "$copy_root/agents/research-code-simplifier.md" <<'PROFILE'
---
name: wrong-profile-name
description: malformed copied canonical profile
---

Resolve and invoke research-repo-standard.
PROFILE
  set +e
  "$copy_root/adapters/$host.sh" "$copy_root/target" >"$copy_root/output" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] &&
    grep -Fq 'canonical profile name is invalid' "$copy_root/output" &&
    ! path_exists "$(destination_for "$host" "$copy_root/target")" &&
    assert_stage_absent "$copy_root/target"
}

for host in claude-code codex; do
  adapter="$(adapter_for "$host")"
  run_case "$host rejects a malformed copied canonical profile" \
    malformed_canonical_is_rejected "$host"
  run_case "$host reports stage mktemp pre-effect failure" \
    run_mktemp_fault_case "$host-mktemp-pre" "$adapter" pre-fail 70 "$host"
  run_case "$host preserves unclaimed stage evidence after mktemp post-effect failure" \
    run_mktemp_fault_case "$host-mktemp-post" "$adapter" post-fail 76 "$host"
  run_case "$host honors TERM after mktemp post-effect failure" \
    run_mktemp_fault_case "$host-mktemp-post-term" "$adapter" post-TERM 143 "$host"

  run_case "$host handles pre-effect link failure" \
    run_fault_case "$host-ln-pre-fail" "$adapter" pre-fail 71 "$host"
  run_case "$host preserves a concurrent publication collision" \
    run_fault_case "$host-ln-collision" "$adapter" collision 1 "$host"
  run_case "$host retains a committed destination after post-effect link failure" \
    run_fault_case "$host-ln-post-fail" "$adapter" post-fail 75 "$host"
  for signal in HUP INT TERM; do
    status=129
    [[ "$signal" == INT ]] && status=130
    [[ "$signal" == TERM ]] && status=143
    run_case "$host honors $signal before the link effect" \
      run_fault_case "$host-ln-pre-$signal" "$adapter" "pre-$signal" "$status" "$host"
    run_case "$host honors $signal after retaining the link effect" \
      run_fault_case "$host-ln-post-$signal" "$adapter" "post-$signal" "$status" "$host"
  done

  run_case "$host reports cleanup failure before commit and preserves owned evidence" \
    run_cleanup_fault_case "$host-cleanup-before-fail" "$adapter" before fail 71 "$host"
  run_case "$host reports cleanup failure after commit and retains destination" \
    run_cleanup_fault_case "$host-cleanup-after-fail" "$adapter" after fail 1 "$host"
  run_case "$host preserves a foreign stage replacement before commit" \
    run_cleanup_fault_case "$host-cleanup-before-replace" "$adapter" before replace 71 "$host"
  run_case "$host preserves a foreign stage replacement after commit" \
    run_cleanup_fault_case "$host-cleanup-after-replace" "$adapter" after replace 1 "$host"
done

if ((FAILS > 0)); then
  printf '%s test(s) failed\n' "$FAILS"
  exit 1
fi
printf 'all adapter safety tests passed\n'
