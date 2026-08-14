#!/usr/bin/env bash

rrs_stage=''
rrs_stage_inode=''
rrs_anchor=''
rrs_destination=''
rrs_pending_signal=0
rrs_committed=0
rrs_in_transition=0
rrs_render_fd_open=0
RRS_ADAPTER_PID=$$
export RRS_ADAPTER_PID

rrs_inode_of() { LC_ALL=C ls -di "$1" 2>/dev/null | awk '{ print $1 }'; }
rrs_path_exists() { [[ -e "$1" || -L "$1" ]]; }
rrs_receive_signal() {
  rrs_signal_status=$1
  if ((rrs_in_transition)); then
    rrs_pending_signal=$rrs_signal_status
  else
    exit "$rrs_signal_status"
  fi
}
rrs_refresh_commit() {
  rrs_committed=0
  if [[ -n "$rrs_stage_inode" && -f "$rrs_destination" && ! -L "$rrs_destination" ]] &&
    [[ "$(rrs_inode_of "$rrs_destination")" == "$rrs_stage_inode" ]]; then
    rrs_committed=1
  fi
}
rrs_honor_signal() {
  if ((rrs_pending_signal != 0)); then
    exit "$rrs_pending_signal"
  fi
}
rrs_on_exit() {
  rrs_status=$?
  trap - EXIT HUP INT TERM
  ((rrs_pending_signal != 0)) && rrs_status=$rrs_pending_signal
  rrs_close_render_handle
  rrs_refresh_commit
  if ! rrs_cleanup_anchor; then
    ((rrs_status == 0)) && rrs_status=1
  fi
  if ! rrs_cleanup_stage; then
    ((rrs_status == 0)) && rrs_status=1
  fi
  exit "$rrs_status"
}
trap 'rrs_receive_signal 129' HUP
trap 'rrs_receive_signal 130' INT
trap 'rrs_receive_signal 143' TERM
trap 'rrs_on_exit' EXIT

rrs_cleanup_stage() {
  rrs_current_inode=''
  rrs_rm_status=0
  [[ -n "$rrs_stage" ]] || return 0
  rrs_path_exists "$rrs_stage" || return 0
  rrs_current_inode="$(rrs_inode_of "$rrs_stage")" || rrs_current_inode=''
  if [[ -z "$rrs_stage_inode" || -z "$rrs_current_inode" ||
    "$rrs_current_inode" != "$rrs_stage_inode" ]]; then
    printf '%s: refusing to remove changed staging file: %s\n' "${0##*/}" "$rrs_stage" >&2
    return 1
  fi
  rm -f "$rrs_stage" 2>/dev/null || rrs_rm_status=$?
  if ! rrs_path_exists "$rrs_stage"; then
    rrs_stage=''
    rrs_stage_inode=''
    return 0
  fi
  rrs_current_inode="$(rrs_inode_of "$rrs_stage")" || rrs_current_inode=''
  if [[ -z "$rrs_current_inode" || "$rrs_current_inode" != "$rrs_stage_inode" ]]; then
    printf '%s: staging file changed during cleanup; preserving replacement: %s\n' \
      "${0##*/}" "$rrs_stage" >&2
    return 1
  fi
  printf '%s: unable to remove owned staging file: %s (rm status %s)\n' \
    "${0##*/}" "$rrs_stage" "$rrs_rm_status" >&2
  return 1
}
rrs_cleanup_anchor() {
  rrs_current_inode=''
  rrs_rm_status=0
  [[ -n "$rrs_anchor" ]] || return 0
  rrs_path_exists "$rrs_anchor" || return 0
  rrs_current_inode="$(rrs_inode_of "$rrs_anchor")" || rrs_current_inode=''
  if [[ -z "$rrs_stage_inode" || -z "$rrs_current_inode" ||
    "$rrs_current_inode" != "$rrs_stage_inode" ]]; then
    printf '%s: refusing to remove changed staging anchor: %s\n' \
      "${0##*/}" "$rrs_anchor" >&2
    return 1
  fi
  rm -f "$rrs_anchor" 2>/dev/null || rrs_rm_status=$?
  if ! rrs_path_exists "$rrs_anchor"; then
    rrs_anchor=''
    return 0
  fi
  rrs_current_inode="$(rrs_inode_of "$rrs_anchor")" || rrs_current_inode=''
  if [[ -z "$rrs_current_inode" || "$rrs_current_inode" != "$rrs_stage_inode" ]]; then
    printf '%s: staging anchor changed during cleanup; preserving replacement: %s\n' \
      "${0##*/}" "$rrs_anchor" >&2
    return 1
  fi
  printf '%s: unable to remove owned staging anchor: %s (rm status %s)\n' \
    "${0##*/}" "$rrs_anchor" "$rrs_rm_status" >&2
  return 1
}

rrs_extract_name() { awk '$1 == "name:" { print $2; exit }' "$1"; }
rrs_extract_description() {
  awk '
    /^description:/ {
      capture = 1
      sub(/^description:[[:space:]]*/, "")
      if ($0 != "") text = $0
      next
    }
    capture && /^[[:space:]]+/ {
      sub(/^[[:space:]]+/, "")
      text = text (text == "" ? "" : " ") $0
      next
    }
    capture { exit }
    END { print text }
  ' "$1"
}
rrs_extract_body() {
  awk 'delimiters < 2 && /^---$/ { delimiters++; next } delimiters >= 2 { print }' "$1"
}
rrs_fail_status() {
  rrs_status=$1
  shift
  ((rrs_status != 0)) || rrs_status=1
  printf '%s: %s\n' "${0##*/}" "$*" >&2
  exit "$rrs_status"
}
rrs_validate_source_profile() {
  rrs_source_profile=$1
  [[ -f "$rrs_source_profile" && ! -L "$rrs_source_profile" ]] ||
    rrs_fail_status 1 'canonical profile is not a regular file'
  [[ "$(sed -n '1p' "$rrs_source_profile")" == --- ]] ||
    rrs_fail_status 1 'canonical profile frontmatter is invalid'
  [[ "$(awk '/^---$/ { count++ } END { print count }' "$rrs_source_profile")" == 2 ]] ||
    rrs_fail_status 1 'canonical profile must have exactly two frontmatter delimiters'
  rrs_name="$(rrs_extract_name "$rrs_source_profile")"
  rrs_description="$(rrs_extract_description "$rrs_source_profile")"
  [[ "$rrs_name" == research-code-simplifier ]] ||
    rrs_fail_status 1 'canonical profile name is invalid'
  [[ -n "$rrs_description" ]] || rrs_fail_status 1 'canonical description is empty'
  rrs_extract_body "$rrs_source_profile" | awk 'NF { found=1 } END { exit(found ? 0 : 1) }' ||
    rrs_fail_status 1 'canonical body is empty'
  rrs_extract_body "$rrs_source_profile" | grep -Fq research-repo-standard ||
    rrs_fail_status 1 'canonical body must invoke research-repo-standard'
  ! grep -Fq "'''" "$rrs_source_profile" ||
    rrs_fail_status 1 'canonical profile contains reserved TOML delimiter'
}

rrs_toml_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
rrs_extract_toml_body() {
  awk -v quote="'''" '
    $0 == "developer_instructions = " quote { capture=1; next }
    capture && $0 == quote { closed=1; next }
    capture && !closed { print }
    END { if (!capture || !closed) exit 1 }
  ' "$1"
}
rrs_render_claude() {
  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$rrs_name"
    printf 'description: %s\n' "$rrs_description"
    printf '%s\n' '---'
    rrs_extract_body "$rrs_source_profile"
  } >&3
}
rrs_render_codex() {
  rrs_escaped_name="$(printf '%s\n' "$rrs_name" | rrs_toml_escape)"
  rrs_escaped_description="$(printf '%s\n' "$rrs_description" | rrs_toml_escape)"
  {
    printf 'name = "%s"\n' "$rrs_escaped_name"
    printf 'description = "%s"\n' "$rrs_escaped_description"
    printf '%s\n' "developer_instructions = '''"
    rrs_extract_body "$rrs_source_profile"
    printf '%s\n' "'''"
  } >&3
}
rrs_validate_render() {
  rrs_host=$1
  [[ -s "$rrs_anchor" ]] || return 1
  case "$rrs_host" in
    claude-code)
      [[ "$(rrs_extract_name "$rrs_anchor")" == "$rrs_name" ]] &&
        [[ "$(rrs_extract_description "$rrs_anchor")" == "$rrs_description" ]] &&
        cmp -s <(rrs_extract_body "$rrs_source_profile") <(rrs_extract_body "$rrs_anchor")
      ;;
    codex)
      [[ "$(sed -n '1p' "$rrs_anchor")" == "name = \"$rrs_escaped_name\"" ]] &&
        [[ "$(sed -n '2p' "$rrs_anchor")" == "description = \"$rrs_escaped_description\"" ]] &&
        cmp -s <(rrs_extract_body "$rrs_source_profile") <(rrs_extract_toml_body "$rrs_anchor")
      ;;
  esac
}

rrs_verify_directory() {
  rrs_target_root=$1
  rrs_path=$2
  [[ ! -L "$rrs_path" ]] || rrs_fail_status 1 "refusing symlinked output parent: $rrs_path"
  [[ -d "$rrs_path" ]] || rrs_fail_status 1 "output parent is not a directory: $rrs_path"
  rrs_physical="$(cd "$rrs_path" 2>/dev/null && pwd -P)" ||
    rrs_fail_status 1 "cannot resolve output parent: $rrs_path"
  case "$rrs_physical" in
    "$rrs_target_root" | "$rrs_target_root"/*) ;;
    *) rrs_fail_status 1 "output parent escapes target: $rrs_path" ;;
  esac
  [[ "$rrs_physical" == "$rrs_path" ]] ||
    rrs_fail_status 1 "output parent is not physically contained as declared: $rrs_path"
}
rrs_ensure_directory() {
  rrs_target_root=$1
  rrs_path=$2
  rrs_mkdir_status=0
  if ! rrs_path_exists "$rrs_path"; then
    mkdir "$rrs_path" 2>/dev/null || rrs_mkdir_status=$?
  fi
  if ((rrs_mkdir_status != 0)) && { [[ -L "$rrs_path" ]] || [[ ! -d "$rrs_path" ]]; }; then
    rrs_fail_status "$rrs_mkdir_status" "failed to create output parent: $rrs_path"
  fi
  rrs_verify_directory "$rrs_target_root" "$rrs_path"
}
rrs_stage_is_owned() {
  [[ -n "$rrs_stage_inode" && -f "$rrs_stage" && ! -L "$rrs_stage" ]] &&
    [[ "$(rrs_inode_of "$rrs_stage")" == "$rrs_stage_inode" ]]
}
rrs_anchor_is_owned() {
  [[ -n "$rrs_stage_inode" && -f "$rrs_anchor" && ! -L "$rrs_anchor" ]] &&
    [[ "$(rrs_inode_of "$rrs_anchor")" == "$rrs_stage_inode" ]]
}
rrs_close_render_handle() {
  if ((rrs_render_fd_open)); then
    exec 3>&-
    rrs_render_fd_open=0
  fi
}
rrs_open_render_handle() {
  rrs_handle_inode=''
  if ! exec 3>> "$rrs_anchor"; then
    rrs_fail_status 1 'unable to open staging anchor for rendering'
  fi
  rrs_render_fd_open=1
  rrs_handle_inode="$(rrs_inode_of /dev/fd/3)" || rrs_handle_inode=''
  if [[ -z "$rrs_handle_inode" || "$rrs_handle_inode" != "$rrs_stage_inode" ]]; then
    rrs_close_render_handle
    rrs_fail_status 1 'staging anchor changed before rendering'
  fi
}
rrs_create_stage() {
  rrs_parent=$1
  rrs_candidate=''
  rrs_mktemp_status=0
  rrs_in_transition=1
  rrs_candidate="$(mktemp "$rrs_parent/.research-code-simplifier.stage.XXXXXX" 2>/dev/null)" ||
    rrs_mktemp_status=$?
  if ((rrs_mktemp_status == 0)) && [[ "${rrs_candidate%/*}" == "$rrs_parent" &&
    -f "$rrs_candidate" && ! -L "$rrs_candidate" ]]; then
    case "${rrs_candidate##*/}" in
      .research-code-simplifier.stage.?*)
        rrs_stage=$rrs_candidate
        rrs_stage_inode="$(rrs_inode_of "$rrs_stage")" || rrs_stage_inode=''
        ;;
    esac
  fi
  rrs_in_transition=0
  rrs_honor_signal
  ((rrs_mktemp_status == 0)) ||
    rrs_fail_status "$rrs_mktemp_status" \
      'failed to create staging file; any reported artifact is unclaimed and preserved'
  [[ -n "$rrs_stage" && -n "$rrs_stage_inode" ]] ||
    rrs_fail_status 1 'mktemp returned an unsafe or unverifiable staging file'
}
rrs_create_anchor() {
  rrs_link_status=0
  rrs_anchor="$rrs_stage.anchor"
  rrs_path_exists "$rrs_anchor" &&
    rrs_fail_status 1 'refusing pre-existing staging anchor'
  rrs_in_transition=1
  /bin/ln "$rrs_stage" "$rrs_anchor" 2>/dev/null || rrs_link_status=$?
  rrs_in_transition=0
  rrs_honor_signal
  ((rrs_link_status == 0)) || rrs_fail_status "$rrs_link_status" 'failed to bind staging anchor'
  rrs_anchor_is_owned || rrs_fail_status 1 'staging file changed while binding render anchor'
}
# Apple Bash and portable macOS utilities cannot hard-link from an open file descriptor. This
# verified hard-link anchor keeps replacement of the recorded stage from changing published bytes.
# A same-user process that deliberately replaces the anchor itself in the remaining check-to-ln
# interval is an operating-system boundary; the adjacent identity checks detect, but cannot make
# that out-of-band pathname mutation impossible.
rrs_destination_is_exact() {
  [[ -f "$rrs_destination" && ! -L "$rrs_destination" ]] &&
    cmp -s "$rrs_anchor" "$rrs_destination"
}
rrs_publish_stage() {
  rrs_link_status=0
  if rrs_path_exists "$rrs_destination"; then
    [[ ! -L "$rrs_destination" && -f "$rrs_destination" ]] ||
      rrs_fail_status 1 "refusing non-regular destination: $rrs_destination"
    rrs_destination_is_exact ||
      rrs_fail_status 1 "refusing customized destination: $rrs_destination"
    return
  fi
  rrs_in_transition=1
  ln "$rrs_anchor" "$rrs_destination" 2>/dev/null || rrs_link_status=$?
  rrs_refresh_commit
  rrs_in_transition=0
  rrs_honor_signal
  if ((rrs_committed)); then
    ((rrs_link_status == 0)) || {
      printf '%s: publication command failed after commit; destination retained\n' \
        "${0##*/}" >&2
      exit "$rrs_link_status"
    }
    return
  fi
  if rrs_path_exists "$rrs_destination"; then
    rrs_destination_is_exact && return
    rrs_fail_status 1 "publication conflict; destination retained: $rrs_destination"
  fi
  ((rrs_link_status != 0)) || rrs_link_status=1
  rrs_fail_status "$rrs_link_status" 'create-only publication failed without destination'
}
install_research_code_simplifier() {
  rrs_host=${1-}
  rrs_target_input=${2-}
  rrs_source_profile=${3-}
  [[ $# -eq 3 ]] || rrs_fail_status 2 'expected HOST TARGET SOURCE_PROFILE'
  RRS_ADAPTER_PID=$$
  export RRS_ADAPTER_PID
  trap 'rrs_receive_signal 129' HUP
  trap 'rrs_receive_signal 130' INT
  trap 'rrs_receive_signal 143' TERM
  trap 'rrs_on_exit' EXIT
  case "$rrs_host" in
    claude-code) rrs_host_root=.claude; rrs_extension=md ;;
    codex) rrs_host_root=.codex; rrs_extension=toml ;;
    *) rrs_fail_status 2 "unsupported host: $rrs_host" ;;
  esac
  rrs_validate_source_profile "$rrs_source_profile"
  [[ -d "$rrs_target_input" ]] || rrs_fail_status 1 'target is not a directory'
  rrs_target_root="$(cd "$rrs_target_input" && pwd -P)" || rrs_fail_status 1 'cannot resolve target'
  [[ "$rrs_target_root" != / ]] || rrs_fail_status 1 'refusing filesystem root'
  rrs_ensure_directory "$rrs_target_root" "$rrs_target_root/$rrs_host_root"
  rrs_parent="$rrs_target_root/$rrs_host_root/agents"
  rrs_ensure_directory "$rrs_target_root" "$rrs_parent"
  rrs_destination="$rrs_parent/research-code-simplifier.$rrs_extension"
  [[ ! -L "$rrs_destination" ]] || rrs_fail_status 1 'refusing destination symlink'
  rrs_create_stage "$rrs_parent"
  rrs_create_anchor
  rrs_stage_is_owned || rrs_fail_status 1 'staging file changed before rendering'
  rrs_open_render_handle
  rrs_stage_is_owned || {
    rrs_close_render_handle
    rrs_fail_status 1 'staging file changed before rendering'
  }
  rrs_render_status=0
  case "$rrs_host" in
    claude-code) rrs_render_claude || rrs_render_status=$? ;;
    codex) rrs_render_codex || rrs_render_status=$? ;;
  esac
  rrs_close_render_handle
  ((rrs_render_status == 0)) || rrs_fail_status "$rrs_render_status" 'failed to render profile'
  rrs_stage_is_owned || rrs_fail_status 1 'staging file changed during rendering'
  rrs_anchor_is_owned || rrs_fail_status 1 'staging anchor changed during rendering'
  rrs_validate_render "$rrs_host" || rrs_fail_status 1 'rendered profile failed validation'
  rrs_verify_directory "$rrs_target_root" "$rrs_parent"
  rrs_stage_is_owned || rrs_fail_status 1 'staging file changed after validation'
  rrs_anchor_is_owned || rrs_fail_status 1 'staging anchor changed after validation'
  rrs_publish_stage
  rrs_anchor_is_owned || rrs_fail_status 1 'staging anchor changed during publication'
  rrs_stage_is_owned ||
    rrs_fail_status 1 'staging file changed during publication; validated destination retained'
  exit 0
}
