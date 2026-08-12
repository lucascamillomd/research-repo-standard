#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shell_files=(vendor.sh adapters/*.sh tests/*.sh tools/*.sh)

case "${1:-}" in
  format)
    mise exec -- npm ci
    mise exec -- npm run format:markdown
    mise exec -- shfmt -w -i 2 -ci -sr "${shell_files[@]}"
    ;;
  lint)
    mise exec -- npm ci
    mise exec -- npm run check:markdown-format
    mise exec -- npm run lint:markdown
    mise exec -- shellcheck "${shell_files[@]}"
    mise exec -- shfmt -d -i 2 -ci -sr "${shell_files[@]}"
    bash -n "${shell_files[@]}"
    ;;
  check)
    "$0" lint
    bash tests/vendor_test.sh
    bash tests/adapter_test.sh
    bash tests/consistency_test.sh
    bash tests/quality_test.sh
    git diff --check
    ;;
  *)
    echo "usage: tools/quality.sh {format|lint|check}" >&2
    exit 2
    ;;
esac
