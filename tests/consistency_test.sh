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

# --- 3. host adapters are documented by the prerequisite owner ---
if grep -qs 'adapters/claude-code\.sh' "$ROOT/references/prerequisites.md" \
    && grep -qs 'adapters/codex\.sh' "$ROOT/references/prerequisites.md"; then
    pass "host adapters are documented by the prerequisite owner"
else
    fail "host adapters are documented by the prerequisite owner"
fi

# --- 4. portable simplifier profile is routed from AGENTS.md ---
if grep -qs 'agents/code-simplifier\.md' "$ROOT/AGENTS.md" \
    && [[ -f "$ROOT/agents/code-simplifier.md" ]]; then
    pass "portable simplifier profile is routed from AGENTS.md"
else
    fail "portable simplifier profile is routed from AGENTS.md"
fi

# --- 5. simplifier profile and policy are provider neutral ---
profile_ok=1
if grep -Eq '^model:' "$ROOT/agents/code-simplifier.md"; then
    fail "canonical simplifier profile must not select a provider model"
    profile_ok=0
fi
if grep -Eq '\.claude/agents|Claude Code|Anthropic|Codex|OpenAI' "$ROOT/agents/code-simplifier.md"; then
    fail "canonical simplifier profile must be host neutral"
    profile_ok=0
fi
(( profile_ok )) && pass "canonical simplifier profile is provider neutral"

policy_ok=1
if ! grep -qs 'independent code-simplification pass' "$ROOT/AGENTS.md"; then
    fail "AGENTS.md must require an independent code-simplification pass"
    policy_ok=0
fi
if grep -Eq '\.claude/agents/' "$ROOT/AGENTS.md"; then
    fail "AGENTS.md must resolve the simplifier through the current host adapter"
    policy_ok=0
fi
(( policy_ok )) && pass "AGENTS.md routes an independent host-neutral simplification pass"

# --- 6. removed generated documents are not prescribed by the standard ---
removed_docs_ok=1
for removed in PIPELINE DATA DECISIONS METHODS; do
    if grep -Rqs "docs/${removed}\.md" "$ROOT/AGENTS.md" "$ROOT/SKILL.md" "$ROOT/references"; then
        fail "removed generated document is still prescribed: docs/${removed}.md"
        removed_docs_ok=0
    fi
done
(( removed_docs_ok )) && pass "removed generated documents are not prescribed"

# --- 7. consequential decisions use the lab notebook ---
if grep -qs 'docs/lab_notebook\.md' "$ROOT/AGENTS.md" \
    && grep -Rqs 'docs/lab_notebook\.md' "$ROOT/references/analysis.md" \
        "$ROOT/references/configuration.md" "$ROOT/references/prerequisites.md"; then
    pass "lab notebook owns consequential decision records"
else
    fail "lab notebook owns consequential decision records"
fi

# --- 8. workflow routes figure work through the figure reference ---
if grep -qs 'references/figures\.md' "$ROOT/SKILL.md" \
    && grep -qis 'before.*plot' "$ROOT/SKILL.md"; then
    pass "SKILL.md routes plotting to the figure reference"
else
    fail "SKILL.md routes plotting to the figure reference"
fi

# --- 9. bootstrap delegates host prerequisites to their owner ---
if grep -qs 'references/prerequisites\.md' "$ROOT/references/bootstrap.md" \
    && ! grep -qs '^## Agent-skill preflight' "$ROOT/references/bootstrap.md"; then
    pass "bootstrap delegates host prerequisites"
else
    fail "bootstrap delegates host prerequisites"
fi

# --- 10. portable policy does not prescribe a specific host integration ---
if ! grep -Eq 'CLAUDE\.md.*symlink|\.claude/agents' "$ROOT/AGENTS.md"; then
    pass "AGENTS.md is host neutral"
else
    fail "AGENTS.md is host neutral"
fi

# --- 11. removed drift-check interfaces are absent from live documentation ---
removed_standard='standard'"-check"
removed_vendor='vendor\.sh '"--check"
removed_drift='drift '"checks"
drift_pattern="$removed_standard|$removed_vendor|$removed_drift"
drift_matches="$({
    grep -HnE "$drift_pattern" \
        "$ROOT/AGENTS.md" "$ROOT/SKILL.md" "$ROOT/README.md" "$ROOT/vendor.sh" \
        "$ROOT"/references/*.md "$ROOT"/tests/*.sh 2>/dev/null || true
} | grep -v '/tests/vendor_test\.sh:' \
    | grep -v '/tests/consistency_test\.sh:' || true)"
if [[ -z "$drift_matches" ]]; then
    pass "removed drift-check interfaces are absent from live documentation"
else
    fail "removed drift-check interfaces are absent from live documentation"
    printf '%s\n' "$drift_matches"
fi

# --- final ---
if (( FAILS > 0 )); then
    echo "$FAILS test(s) failed"
    exit 1
fi
echo "all consistency tests passed"
