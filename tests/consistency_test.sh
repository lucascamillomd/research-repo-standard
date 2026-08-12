#!/usr/bin/env bash
# Consistency tests for the standard's documentation web. Plain bash; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILS=$((FAILS+1)); }

# --- 1. every references/*.md path named in SKILL.md exists ---
refs_ok=1
while IFS= read -r ref; do
    if [[ ! -f "$ROOT/$ref" ]]; then
        fail "SKILL.md names missing file: $ref"
        refs_ok=0
    fi
done < <(grep -o 'references/[a-z-]*\.md' "$ROOT/SKILL.md" | sort -u)
(( refs_ok )) && pass "SKILL.md reference paths exist"

# --- 2. repo paths inside GitHub blob URLs exist in this repository ---
urls_ok=1
while IFS= read -r path; do
    if [[ ! -f "$ROOT/$path" ]]; then
        fail "blob URL points at missing file: $path"
        urls_ok=0
    fi
done < <(grep -rho 'research-repo-standard/blob/main/[A-Za-z0-9/._-]*' \
             "$ROOT"/*.md "$ROOT"/references/*.md \
         | sed 's|research-repo-standard/blob/main/||' | sort -u)
(( urls_ok )) && pass "GitHub blob URLs resolve to repository files"

# --- 3. vendor.sh --check exit codes match bootstrap.md documentation ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/empty"
"$ROOT/vendor.sh" --check "$tmp/empty" >/dev/null 2>&1
rc=$?
if [[ "$rc" -eq 2 ]]; then
    pass "--check with no AGENTS.md exits 2 as documented"
else
    fail "--check with no AGENTS.md exits 2 as documented (got $rc)"
fi

# --- 4. canonical code-simplifier profile exists where AGENTS.md points ---
if [[ -f "$ROOT/agents/code-simplifier.md" ]]; then
    pass "canonical code-simplifier profile present"
else
    fail "canonical code-simplifier profile present"
fi

# --- 5. removed generated documents are not prescribed by the standard ---
removed_docs_ok=1
for removed in PIPELINE DATA DECISIONS METHODS; do
    if grep -Rqs "docs/${removed}\.md" "$ROOT/AGENTS.md" "$ROOT/SKILL.md" "$ROOT/references"; then
        fail "removed generated document is still prescribed: docs/${removed}.md"
        removed_docs_ok=0
    fi
done
(( removed_docs_ok )) && pass "removed generated documents are not prescribed"

# --- 6. consequential decisions use the lab notebook ---
if grep -qs 'docs/lab_notebook\.md' "$ROOT/AGENTS.md" \
    && grep -Rqs 'docs/lab_notebook\.md' "$ROOT/references/analysis.md" \
        "$ROOT/references/configuration.md" "$ROOT/references/prerequisites.md"; then
    pass "lab notebook owns consequential decision records"
else
    fail "lab notebook owns consequential decision records"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all consistency tests passed"
