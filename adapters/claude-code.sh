#!/usr/bin/env bash
set -u
[[ $# -eq 1 ]] || { printf 'usage: claude-code.sh <target-repo>\n' >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/profile-installer.sh"
install_research_code_simplifier 'claude-code' "$1" \
  "$SCRIPT_DIR/../agents/research-code-simplifier.md"
