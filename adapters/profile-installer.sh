#!/usr/bin/env bash
# Transactional installer for the research-code-simplifier host profile: validate the canonical
# profile, render it to the host format in a temporary file inside the destination directory,
# validate the rendered artifact, then publish it with an atomic same-directory rename. A failed
# run removes its own temporary file and never leaves a partial destination. An existing
# destination is kept: identical bytes succeed idempotently; customized bytes fail loudly.

rrs_stage=''

rrs_fail_status() {
  rrs_status=$1
  shift
  ((rrs_status != 0)) || rrs_status=1
  printf '%s: %s\n' "${0##*/}" "$*" >&2
  exit "$rrs_status"
}

rrs_cleanup() {
  [[ -n "$rrs_stage" ]] && rm -f "$rrs_stage"
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
rrs_extract_toml_body() {
  awk -v quote="'''" '
    $0 == "developer_instructions = " quote { capture=1; next }
    capture && $0 == quote { closed=1; next }
    capture && !closed { print }
    END { if (!capture || !closed) exit 1 }
  ' "$1"
}
rrs_toml_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }

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

rrs_ensure_directory() {
  rrs_target_root=$1
  rrs_path=$2
  if [[ ! -e "$rrs_path" && ! -L "$rrs_path" ]]; then
    mkdir "$rrs_path" 2>/dev/null || true
  fi
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

rrs_render_claude() {
  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$rrs_name"
    printf 'description: %s\n' "$rrs_description"
    printf '%s\n' '---'
    rrs_extract_body "$rrs_source_profile"
  } > "$rrs_stage"
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
  } > "$rrs_stage"
}
rrs_validate_render() {
  rrs_host=$1
  [[ -s "$rrs_stage" ]] || return 1
  case "$rrs_host" in
    claude-code)
      [[ "$(rrs_extract_name "$rrs_stage")" == "$rrs_name" ]] &&
        [[ "$(rrs_extract_description "$rrs_stage")" == "$rrs_description" ]] &&
        cmp -s <(rrs_extract_body "$rrs_source_profile") <(rrs_extract_body "$rrs_stage")
      ;;
    codex)
      [[ "$(sed -n '1p' "$rrs_stage")" == "name = \"$rrs_escaped_name\"" ]] &&
        [[ "$(sed -n '2p' "$rrs_stage")" == "description = \"$rrs_escaped_description\"" ]] &&
        cmp -s <(rrs_extract_body "$rrs_source_profile") <(rrs_extract_toml_body "$rrs_stage")
      ;;
  esac
}

install_research_code_simplifier() {
  rrs_host=${1-}
  rrs_target_input=${2-}
  [[ $# -eq 3 ]] || rrs_fail_status 2 'expected HOST TARGET SOURCE_PROFILE'
  trap 'rrs_cleanup' EXIT HUP INT TERM
  case "$rrs_host" in
    claude-code) rrs_host_root=.claude; rrs_extension=md ;;
    codex) rrs_host_root=.codex; rrs_extension=toml ;;
    *) rrs_fail_status 2 "unsupported host: $rrs_host" ;;
  esac
  rrs_validate_source_profile "$3"
  [[ -d "$rrs_target_input" ]] || rrs_fail_status 1 'target is not a directory'
  rrs_target_root="$(cd "$rrs_target_input" && pwd -P)" || rrs_fail_status 1 'cannot resolve target'
  [[ "$rrs_target_root" != / ]] || rrs_fail_status 1 'refusing filesystem root'
  rrs_ensure_directory "$rrs_target_root" "$rrs_target_root/$rrs_host_root"
  rrs_parent="$rrs_target_root/$rrs_host_root/agents"
  rrs_ensure_directory "$rrs_target_root" "$rrs_parent"
  rrs_destination="$rrs_parent/research-code-simplifier.$rrs_extension"
  [[ ! -L "$rrs_destination" ]] || rrs_fail_status 1 'refusing destination symlink'
  rrs_stage="$(mktemp "$rrs_parent/.research-code-simplifier.stage.XXXXXX")" ||
    rrs_fail_status 1 'failed to create staging file'
  case "$rrs_host" in
    claude-code) rrs_render_claude ;;
    codex) rrs_render_codex ;;
  esac || rrs_fail_status 1 'failed to render profile'
  rrs_validate_render "$rrs_host" || rrs_fail_status 1 'rendered profile failed validation'
  if [[ -e "$rrs_destination" ]]; then
    [[ -f "$rrs_destination" && ! -L "$rrs_destination" ]] ||
      rrs_fail_status 1 "refusing non-regular destination: $rrs_destination"
    cmp -s "$rrs_stage" "$rrs_destination" ||
      rrs_fail_status 1 "refusing customized destination: $rrs_destination"
    return 0
  fi
  mv "$rrs_stage" "$rrs_destination" || rrs_fail_status 1 'failed to publish profile'
  rrs_stage=''
}
