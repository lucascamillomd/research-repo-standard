#!/usr/bin/env bash
# Consistency tests for the standard's documentation web. Plain bash; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}

# --- 1. every references/*.md path named in SKILL.md exists ---
refs_ok=1
while IFS= read -r ref; do
  if [[ ! -f "$ROOT/$ref" ]]; then
    fail "SKILL.md names missing file: $ref"
    refs_ok=0
  fi
done < <(grep -o 'references/[a-z-]*\.md' "$ROOT/SKILL.md" | sort -u)
((refs_ok)) && pass "SKILL.md reference paths exist"

# --- 2. repo paths inside GitHub blob URLs exist in this repository ---
urls_ok=1
while IFS= read -r path; do
  if [[ ! -f "$ROOT/$path" ]]; then
    fail "blob URL points at missing file: $path"
    urls_ok=0
  fi
done < <(grep -rho 'research-repo-standard/blob/main/[A-Za-z0-9/._-]*' \
  "$ROOT"/*.md "$ROOT"/references/*.md |
  sed 's|research-repo-standard/blob/main/||' | sort -u)
((urls_ok)) && pass "GitHub blob URLs resolve to repository files"

# --- 3. bootstrap owns post-vendor host adapter integration ---
adapter_owner_ok=1
for adapter in './adapters/claude-code.sh' './adapters/codex.sh'; do
  grep -Fqs "$adapter" "$ROOT/SKILL.md" || adapter_owner_ok=0
done
if grep -Eq '^## (Install the selected project host adapter|Delegated-agent verification)' \
  "$ROOT/references/prerequisites.md"; then
  adapter_owner_ok=0
fi
if ((adapter_owner_ok)); then
  pass "bootstrap owns post-vendor host adapter integration"
else
  fail "bootstrap must own post-vendor host adapter integration"
fi

# --- 4. portable simplifier profile is routed from AGENTS.md ---
if grep -qs 'agents/code-simplifier\.md' "$ROOT/AGENTS.md" &&
  [[ -f "$ROOT/agents/code-simplifier.md" ]]; then
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
((profile_ok)) && pass "canonical simplifier profile is provider neutral"

policy_ok=1
if ! tr '\n' ' ' < "$ROOT/AGENTS.md" | grep -qs 'independent code-simplification pass'; then
  fail "AGENTS.md must require an independent code-simplification pass"
  policy_ok=0
fi
if grep -Eq '\.claude/agents/' "$ROOT/AGENTS.md"; then
  fail "AGENTS.md must resolve the simplifier through the current host adapter"
  policy_ok=0
fi
((policy_ok)) && pass "AGENTS.md routes an independent host-neutral simplification pass"

# --- 6. policy documents the source-repository role and required invariants ---
if grep -q 'This repository distributes the portable standard' "$ROOT/AGENTS.md" &&
  grep -q 'agents/' "$ROOT/AGENTS.md"; then
  pass "source role and canonical agent-profile path are documented"
else
  fail "source role and canonical agent-profile path are documented"
fi

if grep -q 'preprocessing, normalization, imputation, feature selection, and tuning' \
  "$ROOT/AGENTS.md"; then
  pass "predictive leakage policy names normalization"
else
  fail "predictive leakage policy names normalization"
fi

if grep -q 'Required skills are gates\. A missing skill blocks only its dependent work\.' \
  "$ROOT/AGENTS.md"; then
  pass "required-skill floor is concise"
else
  fail "required-skill floor is concise"
fi

# --- 7. consequential decisions use the lab notebook ---
if grep -qs 'docs/lab_notebook\.md' "$ROOT/AGENTS.md" &&
  grep -Rqs 'docs/lab_notebook\.md' "$ROOT/references/analysis.md" \
    "$ROOT/references/configuration.md" "$ROOT/references/prerequisites.md"; then
  pass "lab notebook owns consequential decision records"
else
  fail "lab notebook owns consequential decision records"
fi

# --- 8. policy routing and figure procedure use the same triggers ---
figure_trigger_ok=1
for file in "$ROOT/AGENTS.md" "$ROOT/references/figures.md"; do
  for trigger in 'planning a figure' 'writing plotting code' 'modifying figure outputs' 'performing QA'; do
    if ! grep -Fq "$trigger" "$file"; then
      fail "missing figure trigger in ${file#"$ROOT"/}: $trigger"
      figure_trigger_ok=0
    fi
  done
done
if ((figure_trigger_ok)); then
  pass "figure procedure triggers stay aligned"
fi

# --- 9. bootstrap delegates host prerequisites to their owner ---
if grep -qs 'references/prerequisites\.md' "$ROOT/references/bootstrap.md"; then
  pass "bootstrap delegates host prerequisites"
else
  fail "bootstrap delegates host prerequisites"
fi

# --- 10. bootstrap questions and examples require explicit runtime answers ---
bootstrap_contract_ok=1
for required in 'Python minor' 'host adapter'; do
  grep -Fq "$required" "$ROOT/SKILL.md" || bootstrap_contract_ok=0
done
grep -Fq 'target-version = "py3XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'python-version = "3.XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'coverage' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
grep -Eq '^test-r:' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
if ((bootstrap_contract_ok)); then
  pass "bootstrap answers and placeholders are explicit"
else
  fail "bootstrap answers and placeholders are explicit"
fi

# --- 11. README routes simplifier and adapter ownership correctly ---
readme_text="$(tr '\n' ' ' < "$ROOT/README.md")"
if grep -Eqs 'selected adapter[^.]*canonical simplifier' <<< "$readme_text" &&
  ! grep -Eqs 'bootstrap[^.]*seed[^.]*simplifier' <<< "$readme_text"; then
  pass "README assigns simplifier installation to the selected adapter"
else
  fail "README must assign simplifier installation only to the selected adapter"
fi

if grep -Fqs '`SKILL.md` steps 7–8' "$ROOT/README.md" &&
  grep -Fqs '`references/prerequisites.md`' "$ROOT/README.md" &&
  grep -Eqs 'host skill[^.]*install[^.]*verif' <<< "$readme_text" &&
  ! grep -Eqs 'adapter[^.]*references/prerequisites' <<< "$readme_text"; then
  pass "README routes vendor integration to SKILL.md and host skills to prerequisites"
else
  fail "README must route vendor integration to SKILL.md and host skills to prerequisites"
fi

# --- 12. portable policy does not prescribe a specific host integration ---
if ! grep -Eq 'CLAUDE\.md.*symlink|\.claude/agents' "$ROOT/AGENTS.md"; then
  pass "AGENTS.md is host neutral"
else
  fail "AGENTS.md is host neutral"
fi

# --- 13. detailed figure naming has one canonical owner ---
figure_owner="$ROOT/references/figures.md"
if grep -Fqs 'mf1_{short_descriptive_name}' "$figure_owner" &&
  grep -Fqs 'edf1_{short_descriptive_name}' "$figure_owner" &&
  grep -Fqs 'svg/mf1_hazard_ratio_distribution.svg' "$figure_owner" &&
  grep -Fqs 'pdf/mf1_hazard_ratio_distribution.pdf' "$figure_owner" &&
  grep -Fqs 'tiff/mf1_hazard_ratio_distribution.tiff' "$figure_owner" &&
  grep -Fqs 'png/mf1_hazard_ratio_distribution.png' "$figure_owner" &&
  grep -Fqs 'mf1_hazard_ratio_distribution.csv' "$figure_owner" &&
  grep -Fqs 'letters never become part of the atomic asset names or' "$figure_owner" &&
  grep -Fqs 'Use the same atomic stem for' "$figure_owner" &&
  grep -Fqs 'Panel letters are applied only' "$figure_owner" &&
  grep -Fqs 'extension-named directory' "$figure_owner"; then
  pass "figure reference owns detailed atomic asset naming"
else
  fail "figure reference must own detailed naming, shared stems, export paths, and panel lettering"
fi

figure_duplicates="$(
  grep -HnE 'mf[0-9]+_|edf[0-9]+_|short_descriptive_name|hazard_ratio_distribution' \
    "$ROOT/AGENTS.md" "$ROOT/SKILL.md" "$ROOT/README.md" "$ROOT/agents/code-simplifier.md" \
    "$ROOT/references/analysis.md" "$ROOT/references/bootstrap.md" \
    "$ROOT/references/configuration.md" "$ROOT/references/data.md" \
    "$ROOT/references/prerequisites.md" 2> /dev/null || true
)"
if [[ -z "$figure_duplicates" ]]; then
  pass "detailed figure asset grammar occurs only in the figure reference"
else
  fail "detailed figure asset grammar must occur only in references/figures.md"
  printf '%s\n' "$figure_duplicates"
fi

if grep -Fqs 'main_figure_1' "$ROOT/AGENTS.md" &&
  grep -Fqs 'extended_data_figure_2' "$ROOT/AGENTS.md"; then
  pass "AGENTS.md keeps general publication identifiers"
else
  fail "AGENTS.md must keep general publication identifiers"
fi

# --- 14. domain references declare the policy/procedure boundary ---
for reference in configuration data analysis; do
  if grep -Fqs "\`AGENTS.md\` owns the normative portable policy" "$ROOT/references/$reference.md" &&
    grep -Fqs 'procedural expansion' "$ROOT/references/$reference.md"; then
    pass "$reference reference declares normative policy and procedural ownership"
  else
    fail "$reference reference must identify AGENTS.md as policy owner and itself as procedural expansion"
  fi
done

# --- 15. simplifier profile delegates naming and configuration policy ---
if ! grep -Eq 'config/analysis\.yaml|random_seed:|test_[a-z]|datasets\.yaml' \
  "$ROOT/agents/code-simplifier.md"; then
  pass "simplifier profile contains no independent configuration or test-naming grammar"
else
  fail "simplifier profile must delegate configuration and test-naming grammar to repository authorities"
fi

# --- 16. deterministic workflows do not acquire unused seed settings ---
if tr '\n' ' ' < "$ROOT/references/configuration.md" |
  grep -Fqs 'Do not invent a seed field for a fully deterministic workflow.'; then
  pass "configuration forbids unused deterministic-workflow seed fields"
else
  fail "configuration must forbid unused deterministic-workflow seed fields"
fi

# --- final ---
if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all consistency tests passed"
