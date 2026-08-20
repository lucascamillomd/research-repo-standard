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

# --- 3. source instructions are local and the skill owns portable policy ---
agents_lines="$(wc -l < "$ROOT/AGENTS.md" | tr -d ' ')"
if [[ "$agents_lines" -le 35 ]] &&
  grep -Eqi 'SKILL\.md[^.]*maintained' "$ROOT/AGENTS.md" &&
  ! grep -Eq 'data/raw/|Repository layout|Seed 42|portable governed policy' "$ROOT/AGENTS.md"; then
  pass "AGENTS.md contains only concise source-repository instructions"
else
  fail "AGENTS.md must be concise source-only guidance with SKILL.md as the product"
fi

skill_core_ok=1
for heading in \
  '## Applicability and precedence' \
  '## Required skills and modification gates' \
  '## Reference routing' \
  '## Safety floor' \
  '## Bootstrapping sequence' \
  '## Adopting an existing repository' \
  '## Governed work' \
  '## Completion'; do
  grep -Fqx "$heading" "$ROOT/SKILL.md" || skill_core_ok=0
done
for required in \
  'superpowers:brainstorming' \
  'scientific-critical-thinking' \
  'nature-figure' \
  'research-code-simplifier' \
  'data/raw/' \
  'Seed 42' \
  'docs/LAB_NOTEBOOK.md' \
  'transactionally'; do
  grep -Fq "$required" "$ROOT/SKILL.md" || skill_core_ok=0
done
if ((skill_core_ok)); then
  pass "SKILL.md owns the normative core and required gates"
else
  fail "SKILL.md must own every normative heading, safety invariant, and required skill"
fi

safety_floor_section="$(awk '
    /^## Safety floor$/ { capture = 1; next }
    capture && /^## Bootstrapping sequence$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
safety_floor_text="$(tr '\n' ' ' <<< "$safety_floor_section" | tr -s '[:space:]' ' ')"
safety_floor_ok=1
grep -Eqi 'result-affecting setting[^.]*one[^.]*owner|one[^.]*owner[^.]*result-affecting setting' \
  <<< "$safety_floor_text" || safety_floor_ok=0
grep -Fq 'before computation' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'Seed 42' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'deterministic' <<< "$safety_floor_text" || safety_floor_ok=0
# the nondeterminism and hidden-default invariants stay in the floor itself
grep -Eqi 'nondeterministic boundaries' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'never hidden in a code default' <<< "$safety_floor_text" || safety_floor_ok=0
# ownership bucket mechanics belong to references/configuration.md, not the floor
if grep -Eq 'paths\.py|versioned YAML|environment variable' <<< "$safety_floor_text"; then
  safety_floor_ok=0
fi
# the required-skills section owns skill gating; the floor must not restate it
if grep -Eqi 'Required skills are gates' <<< "$safety_floor_text"; then
  safety_floor_ok=0
fi
if ((safety_floor_ok)); then
  pass "safety floor keeps scientific invariants and defers configuration mechanics"
else
  fail "safety floor must state one-owner and seed invariants without restating configuration mechanics or skill gating"
fi

description_text="$(awk '
    /^description:/ { capture = 1; sub(/^description:[[:space:]]*/, ""); }
    capture && /^---$/ { exit }
    capture { print }
' "$ROOT/SKILL.md" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ //')"
if [[ "$description_text" == "Use when"* ]] &&
  grep -Eqi 'not for general-purpose' <<< "$description_text"; then
  pass "SKILL.md description states triggering conditions and its carve-out"
else
  fail "SKILL.md description must start with triggering conditions and keep the carve-out"
fi

skill_text="$(tr '\n' ' ' < "$ROOT/SKILL.md" | tr -s '[:space:]' ' ')"
# each routing row keeps its reference and the domain terms that trigger it, not exact wording
routing_ok=1
check_routing_row() {
  local reference="$1"
  shift
  local row
  row="$(grep -F "\`$reference\`" "$ROOT/SKILL.md" | grep -F '|' | head -1)"
  [[ -n "$row" ]] || return 1
  local term
  for term in "$@"; do
    grep -Eqi "$term" <<< "$row" || return 1
  done
}
check_routing_row 'references/prerequisites.md' 'unresolved|resolution' 'install' 'host' ||
  routing_ok=0
check_routing_row 'references/bootstrap.md' 'structure|scaffold' 'CI' 'documentation' ||
  routing_ok=0
check_routing_row 'references/configuration.md' 'settings' 'paths' 'provenance' || routing_ok=0
check_routing_row 'references/data.md' 'data' 'validat' 'contract' || routing_ok=0
check_routing_row 'references/analysis.md' 'estimand' 'missing' 'model' 'report' || routing_ok=0
check_routing_row 'references/figures.md' 'figure' 'plot' 'QA' || routing_ok=0
if ((routing_ok)); then
  pass "SKILL.md routes all six domain references by semantic trigger"
else
  fail "SKILL.md must preserve every approved reference trigger group"
fi

# --- 3b. modification gates stay proportionate to what a change can break ---
gate_section="$(awk '
    /^## Required skills and modification gates$/ { capture = 1; next }
    capture && /^## Reference routing$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
gate_text="$(tr '\n' ' ' <<< "$gate_section" | tr -s '[:space:]' ' ')"
gate_ok=1
for path_label in '**Full gate:**' '**Standard gate:**' '**Light path:**' '**No gate:**'; do
  grep -Fq "$path_label" <<< "$gate_text" || gate_ok=0
done
# the full gate is scoped to design-level decisions and owns their list
grep -Eqi 'design-level' <<< "$gate_text" || gate_ok=0
for design_item in 'estimand' 'study design' 'data contract' 'pipeline structure' 'claim scope'; do
  grep -Fqi "$design_item" <<< "$gate_text" || gate_ok=0
done
# an uncertain classification resolves to the full gate rather than the loosest path
grep -Eqi 'when uncertain[^.]*full gate' <<< "$gate_text" || gate_ok=0
# classification keys to scientific meaning, not to which file carries the edit
grep -Eqi 'not by which file' <<< "$gate_text" || gate_ok=0
grep -Eqi 'configuration value that changes an estimand' <<< "$gate_text" || gate_ok=0
standard_gate_text="$(awk '
    /^- \*\*Standard gate:\*\*/ { capture = 1; print; next }
    capture && /^- \*\*/ { exit }
    capture { print }
' <<< "$gate_section" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'authoriz' <<< "$standard_gate_text" || gate_ok=0
grep -Fq 'docs/LAB_NOTEBOOK.md' <<< "$standard_gate_text" || gate_ok=0
grep -Eqi 'test' <<< "$standard_gate_text" || gate_ok=0
# governed work owns the entry field set; the standard-gate bullet only points at it
grep -Eqi 'described under Governed work' <<< "$standard_gate_text" || gate_ok=0
if grep -Eqi 'rationale[^.]*authorization source' <<< "$standard_gate_text"; then
  gate_ok=0
fi
# the middle notch deliberately carries no specification or plan ceremony
grep -Eqi 'no specification|without a specification|no plan|without a plan' \
  <<< "$standard_gate_text" || gate_ok=0
# the governed-work authorization prose defers to that single list instead of restating it
if grep -Eqi 'authoriz[^.]*estimand[^.]*(study design|inclusion|data contract)' <<< "$skill_text"; then
  gate_ok=0
fi
grep -Eqi 'authorization before[^.]*design-level' <<< "$skill_text" || gate_ok=0
if ((gate_ok)); then
  pass "SKILL.md classifies changes into four proportionate paths with one design-level list"
else
  fail "SKILL.md must offer full, standard, light, and no-gate paths that escalate upward from one design-level list"
fi

# --- 3c. independent review and interview cadence scale with the work ---
proportion_ok=1
# the simplifier pass batches per unit of work and any skip is explicit and recorded
grep -Eqi 'once per coherent unit' <<< "$skill_text" || proportion_ok=0
grep -Eqi 'waive|waiver' <<< "$skill_text" || proportion_ok=0
grep -Fq 'completion report' <<< "$skill_text" || proportion_ok=0
grep -Eqi 'self-pass' <<< "$skill_text" || proportion_ok=0
# brevity may batch only the mechanical interview topics, and only with confirmation
bootstrap_step_two="$(awk '
    /^2\. \*\*Interview one question at a time\.\*\*/ { capture = 1 }
    capture && /^3\. / { exit }
    capture { print }
' "$ROOT/SKILL.md" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'brevity|keep the interview short' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'mechanical' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'explicit confirmation' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'one at a time' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'silent' <<< "$bootstrap_step_two" || proportion_ok=0
# batching covers those two mechanical topics and nothing else
grep -Eqi 'those two topics only' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'every other numbered topic' <<< "$bootstrap_step_two" || proportion_ok=0
# the scenario rubric must score the same relaxed cadence, not the old never-bundle rule
scenario_c_rubric="$(awk '
    /^## Scenario C — deterministic bootstrap$/ { found = 1 }
    found && /^### Evaluator rubric/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/tests/skill_pressure_scenarios.md" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'scientific topics one at a time' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'mechanical topics' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'explicit confirmation' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'self-select' <<< "$scenario_c_rubric" || proportion_ok=0
if ((proportion_ok)); then
  pass "simplifier review batches per unit of work and brevity relaxes only mechanical interview topics"
else
  fail "simplifier review must batch with a recorded waiver and brevity must batch only mechanical interview topics"
fi

# --- 3ca. critique, plan amendment, and the scoped simplifier waiver ---
governed_section="$(awk '
    /^## Governed work$/ { capture = 1; next }
    capture && /^## Completion$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
governed_text="$(tr '\n' ' ' <<< "$governed_section" | tr -s '[:space:]' ' ')"
governed_ok=1
# the critique keys to dependent scientific judgment at every gate, not only design level
grep -Eqi 'depends on a scientific judgment under review' <<< "$governed_text" || governed_ok=0
grep -Eqi 'not only at design level' <<< "$governed_text" || governed_ok=0
grep -Eqi 'covariate sets, thresholds, model settings' <<< "$governed_text" || governed_ok=0
# the analysis plan is amended before affected results are presented
grep -Fq 'docs/ANALYSIS_PLAN.md' <<< "$governed_text" || governed_ok=0
grep -Eqi 'post hoc status' <<< "$governed_text" || governed_ok=0
grep -Fq 'references/analysis.md' <<< "$governed_text" || governed_ok=0
# the simplifier waiver applies only when resolution or delegation actually fails
grep -Eqi 'only when the profile cannot be resolved' <<< "$governed_text" || governed_ok=0
grep -Eqi 'not a general opt-out' <<< "$governed_text" || governed_ok=0
grep -Eqi 'waived and recorded' <<< "$skill_text" || governed_ok=0
grep -Eqi 'waives or defers' "$ROOT/references/prerequisites.md" || governed_ok=0
if ((governed_ok)); then
  pass "governed work critiques dependent judgments, amends the plan, and scopes the waiver"
else
  fail "governed work must critique every dependent scientific judgment, amend the analysis plan, and allow the waiver only on a resolution failure"
fi

# --- 3d. adoption mode assesses an existing repository before changing it ---
adoption_section="$(awk '
    /^## Adopting an existing repository$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/SKILL.md")"
adoption_text="$(tr '\n' ' ' <<< "$adoption_section" | tr -s '[:space:]' ' ')"
adoption_ok=1
[[ -n "$adoption_text" ]] || adoption_ok=0
# the applicability framing names adoption alongside the other modes
grep -Eqi 'adoption mode' <<< "$skill_text" || adoption_ok=0
# the walk covers the floor and every reference contract, with evidence and a verdict per item
grep -Eqi 'safety floor' <<< "$adoption_text" || adoption_ok=0
grep -Eqi 'routing.table' <<< "$adoption_text" || adoption_ok=0
grep -Eqi 'complian|gap' <<< "$adoption_text" || adoption_ok=0
grep -Eqi 'evidence' <<< "$adoption_text" || adoption_ok=0
# configuration migration keeps its single owner
grep -Fq 'references/configuration.md' <<< "$adoption_text" || adoption_ok=0
# the review changes nothing; adoption work still passes through the gates
grep -Eqi 'change nothing|changes? nothing|read-only' <<< "$adoption_text" || adoption_ok=0
grep -Eqi 'gate' <<< "$adoption_text" || adoption_ok=0
# it stays choreography rather than a second copy of the contracts
[[ "$(grep -c . <<< "$adoption_section")" -le 20 ]] || adoption_ok=0
if ((adoption_ok)); then
  pass "adoption mode assesses each contract with evidence before any gated migration"
else
  fail "adoption mode must walk floor and references with evidence, change nothing, and defer to the gates"
fi

# --- 4. canonical simplifier profile has the collision-safe identity ---
if [[ -f "$ROOT/agents/research-code-simplifier.md" ]] &&
  grep -Fqx 'name: research-code-simplifier' "$ROOT/agents/research-code-simplifier.md" &&
  grep -Fq 'research-repo-standard' "$ROOT/agents/research-code-simplifier.md"; then
  pass "canonical simplifier profile uses the collision-safe identity"
else
  fail "canonical simplifier profile must use research-code-simplifier and invoke the skill"
fi

# --- 5. simplifier profile and policy are provider neutral ---
profile_ok=1
if grep -Eq '^model:' "$ROOT/agents/research-code-simplifier.md"; then
  fail "canonical simplifier profile must not select a provider model"
  profile_ok=0
fi
if grep -Eq '\.claude/agents|Claude Code|Anthropic|Codex|OpenAI' \
  "$ROOT/agents/research-code-simplifier.md"; then
  fail "canonical simplifier profile must be host neutral"
  profile_ok=0
fi
((profile_ok)) && pass "canonical simplifier profile is provider neutral"

# --- 5a. simplifier profile teaches with attributed before/after examples ---
if grep -Fqx '## Before and after examples' "$ROOT/agents/research-code-simplifier.md" &&
  grep -Fq 'From requests (Apache-2.0)' "$ROOT/agents/research-code-simplifier.md"; then
  pass "simplifier profile shows attributed before/after simplification examples"
else
  fail "simplifier profile must show attributed before/after simplification examples"
fi

# --- 6. live bootstrap and README use the skill-native integration path ---
integration_docs_ok=1
readme_text="$(tr '\n' ' ' < "$ROOT/README.md")"
bootstrap_text="$(tr '\n' ' ' < "$ROOT/references/bootstrap.md")"
integration_text="$readme_text $bootstrap_text"
for obsolete in 'vendor.sh' 'tests/vendor_test.sh' 'After core vendoring' '`SKILL.md` steps 7–8'; do
  if grep -Fq "$obsolete" <<< "$integration_text"; then
    integration_docs_ok=0
  fi
done
for required in \
  '.claude/agents/research-code-simplifier.md' \
  '.codex/agents/research-code-simplifier.toml' \
  'host-native smoke test' \
  'research-code-simplifier'; do
  grep -Fq "$required" <<< "$readme_text" || integration_docs_ok=0
done
grep -Eqi 'resolve[^.]*research-repo-standard[^.]*exact name|exact name[^.]*research-repo-standard' \
  <<< "$readme_text" || integration_docs_ok=0
for required in \
  'host-native smoke test' \
  'research-repo-standard' \
  'research-code-simplifier'; do
  grep -Fq "$required" <<< "$bootstrap_text" || integration_docs_ok=0
done
grep -Eqi 'core scaffold' <<< "$bootstrap_text" || integration_docs_ok=0
if ((integration_docs_ok)); then
  pass "bootstrap and README expose only the live skill-native integration path"
else
  fail "bootstrap and README must resolve the skill, name both host profile outputs, and require host smoke testing"
fi

# --- 7. removed workflows and superseded process artifacts stay absent ---
removed_paths_ok=1
for removed_path in \
  vendor.sh \
  adapters \
  tests/vendor_test.sh \
  tests/adapter_test.sh \
  tests/adapter_safety_test.sh \
  tests/adapter_finalization_test.sh \
  docs/superpowers/plans/2026-08-13-adapter-transaction-version-removal.md \
  docs/superpowers/plans/2026-08-13-contract-harmonization.md \
  docs/superpowers/specs/2026-08-13-adapter-transaction-version-removal-design.md \
  docs/superpowers/specs/2026-08-13-contract-harmonization-design.md; do
  if [[ -e "$ROOT/$removed_path" ]]; then
    fail "obsolete workflow or process artifact remains: $removed_path"
    removed_paths_ok=0
  fi
done
((removed_paths_ok)) && pass "obsolete workflows and superseded process artifacts are absent"

production_paths=(
  "$ROOT/AGENTS.md"
  "$ROOT/SKILL.md"
  "$ROOT/README.md"
  "$ROOT/Makefile"
  "$ROOT/references"
  "$ROOT/agents"
)
stale_surface_ok=1
if grep -ERn 'post-vendor|vendors? `AGENTS.md`|copies only AGENTS.md|standard_version' \
  "${production_paths[@]}"; then
  stale_surface_ok=0
fi
if grep -ERn \
  'agents/code-simplifier.md|\.claude/agents/code-simplifier.md|\.codex/agents/code-simplifier.toml' \
  "${production_paths[@]}"; then
  stale_surface_ok=0
fi
if ((stale_surface_ok)); then
  pass "production surface contains no stale vendoring, version, or generic-profile terminology"
else
  fail "production surface must contain no stale vendoring, version, or generic-profile terminology"
fi

# the retired shell-script machinery must not silently return to any production surface
if grep -ERn 'adapters/|profile-installer' "${production_paths[@]}"; then
  fail "production surfaces must not reference adapters/ machinery paths"
else
  pass "production surfaces contain no adapters/ machinery paths"
fi

# the renamed figure_data directory and dropped reports directory must not regress
if grep -ERn 'source_data|results/reports' "${production_paths[@]}"; then
  fail "production surfaces must not use the retired source_data or results/reports names"
else
  pass "production surfaces contain no retired source_data or results/reports names"
fi

readme_surface_ok=1
grep -Fq '.claude/agents/research-code-simplifier.md' "$ROOT/README.md" || readme_surface_ok=0
grep -Fq '.codex/agents/research-code-simplifier.toml' "$ROOT/README.md" || readme_surface_ok=0
grep -Fq 'Makefile' "$ROOT/README.md" || readme_surface_ok=0
grep -Eqi 'detect[^.]*legacy policy, alias, and generic simplifier artifacts' <<< "$readme_text" ||
  readme_surface_ok=0
grep -Eqi 'explicit authorization[^.]*remov|remov[^.]*explicit authorization' <<< "$readme_text" ||
  readme_surface_ok=0
if ((readme_surface_ok)); then
  pass "README documents host outputs and detection-first legacy cleanup"
else
  fail "README must document host outputs and detection-first legacy cleanup"
fi

snakemake_surface_ok=1
grep -Fq 'uv, Snakemake, and Make' "$ROOT/SKILL.md" || snakemake_surface_ok=0
grep -Eqi 'Snakemake workflow' "$ROOT/SKILL.md" || snakemake_surface_ok=0
grep -Fq 'Snakemake rules as thin orchestration' "$ROOT/references/figures.md" ||
  snakemake_surface_ok=0
grep -Fq 'make pipeline' "$ROOT/references/bootstrap.md" || snakemake_surface_ok=0
if grep -Eqi 'stage scripts' "$ROOT/SKILL.md" "$ROOT/references/figures.md" \
  "$ROOT/references/bootstrap.md"; then
  snakemake_surface_ok=0
fi
if ((snakemake_surface_ok)); then
  pass "skill surfaces route Snakemake orchestration consistently"
else
  fail "skill surfaces must route Snakemake orchestration consistently"
fi

bootstrap_integration_section="$(awk '
    /^## Selected host integration$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
bootstrap_integration_text="$(tr '\n' ' ' <<< "$bootstrap_integration_section" | tr -s '[:space:]' ' ')"
bootstrap_source_ok=1
grep -Eqi 'provenance-verified.*(skill )?source.*(resolver|resolution)|resolver.*provenance-verified.*(skill )?source' \
  <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
grep -Fq 'agents/research-code-simplifier.md' <<< "$bootstrap_integration_text" ||
  bootstrap_source_ok=0
grep -Fq 'references/prerequisites.md' <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
grep -Fq 'only the selected host' <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
if ((bootstrap_source_ok)); then
  pass "bootstrap derives the host profile from the provenance-verified canonical source"
else
  fail "bootstrap must derive only the selected host profile from the provenance-verified canonical source"
fi

# --- 8. bootstrap delegates host prerequisites to their owner ---
if grep -qs 'references/prerequisites\.md' "$ROOT/references/bootstrap.md"; then
  pass "bootstrap delegates host prerequisites"
else
  fail "bootstrap delegates host prerequisites"
fi

# --- 9. bootstrap questions and runtime contracts remain explicit ---
bootstrap_contract_ok=1
interview_section="$(awk '
    /^### Interview$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/SKILL.md")"
grep -Fq 'host profile' <<< "$interview_section" || bootstrap_contract_ok=0
# superpowers is required as a whole package; its skills are still invoked by exact name
grep -Eqi 'superpowers. package as a whole' <<< "$skill_text" || bootstrap_contract_ok=0
grep -Eqi 'superpowers. \(whole package\)' "$ROOT/references/prerequisites.md" ||
  bootstrap_contract_ok=0
# the Python version is never an interview decision; bootstrap pins the latest stable minor
grep -Fqi 'Python minor' <<< "$interview_section" && bootstrap_contract_ok=0
grep -Eqi 'latest stable Python minor' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
# the question list defers cadence to the bootstrapping step rather than stating a second rule
grep -Eqi 'cadence rules in step 2' <<< "$interview_section" || bootstrap_contract_ok=0
# the scientific topics stay separately numbered questions, whatever their wording
for numbered_topic in \
  '^[0-9]+\. [^?]*identity' \
  '^[0-9]+\. [^?]*research question' \
  '^[0-9]+\. [^?]*exploratory'; do
  grep -Eqi "$numbered_topic" <<< "$interview_section" || bootstrap_contract_ok=0
done
if grep -Eqi 'identity[^.?]*,[^.?]*research question' <<< "$interview_section"; then
  bootstrap_contract_ok=0
fi
grep -Fq '### Bootstrap execution record' "$ROOT/SKILL.md" || bootstrap_contract_ok=0
# planning before answers exist reproduces the record with pending fields and asks one question
grep -Eqi 'reproduc[^.]*record[^.]*pending' <<< "$skill_text" || bootstrap_contract_ok=0
grep -Eqi 'exactly one[^.]*question' <<< "$skill_text" || bootstrap_contract_ok=0
grep -Eqi 'gate-artifact' <<< "$skill_text" || bootstrap_contract_ok=0

# the execution record stays a compact checklist of the failure modes under pressure
bootstrap_record="$(awk '
    /^### Bootstrap execution record$/ { found = 1; next }
    found && /^```text$/ { capture = 1; next }
    capture && /^```$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
bootstrap_record_text="$(tr '\n' ' ' <<< "$bootstrap_record" | tr -s '[:space:]' ' ')"
# slots are counted by their labels, so a wrapped continuation line is not a separate slot
record_slots="$(grep -cE '^[A-Za-z][A-Za-z ]*:' <<< "$bootstrap_record")"
[[ "$record_slots" -ge 1 && "$record_slots" -le 10 ]] || bootstrap_contract_ok=0
grep -Eqi 'does not satisfy the record' <<< "$skill_text" || bootstrap_contract_ok=0
for required_pattern in \
  'AGENTS\.md.*CLAUDE\.md.*CODEX\.md' \
  'shared top-level simplifier' \
  'Seed 42' \
  'deterministic' \
  'smoke test' \
  'boundar' \
  'artifacts inspected' \
  'design approval|approved[^;]*design' \
  'gate-artifact' \
  'specification' \
  'plan' \
  'critique' \
  'figure strategy' \
  'core contracts' \
  'README'; do
  grep -Eqi "$required_pattern" <<< "$bootstrap_record_text" || bootstrap_contract_ok=0
done
# the gate slot carries the whole sequence: approval, gate artifacts, committed spec, ready plan
record_gate_slot="$(awk '
    /^Gate:/ { capture = 1; print; next }
    capture && /^[A-Za-z][A-Za-z ]*:/ { exit }
    capture { print }
' <<< "$bootstrap_record" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
for gate_slot_pattern in \
  'design approval|approved[^;]*design' \
  'gate-artifact' \
  'commit[a-z]*[^;]*(specification|spec)|specification[^;]*commit' \
  'review' \
  'plan'; do
  grep -Eqi "$gate_slot_pattern" <<< "$record_gate_slot" || bootstrap_contract_ok=0
done
# the boundaries slot owns reporting assumptions and manual or external boundaries
record_boundaries_slot="$(awk '
    /^Boundaries:/ { capture = 1; print; next }
    capture && /^[A-Za-z][A-Za-z ]*:/ { exit }
    capture { print }
' <<< "$bootstrap_record" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'boundar' <<< "$record_boundaries_slot" || bootstrap_contract_ok=0
grep -Eqi 'assumption' <<< "$record_boundaries_slot" || bootstrap_contract_ok=0
# a separate completion slot binds inspecting real generated artifacts to claiming completion
record_completion_slot="$(awk '
    /^Completion:/ { capture = 1; print; next }
    capture && /^[A-Za-z][A-Za-z ]*:/ { exit }
    capture { print }
' <<< "$bootstrap_record" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'inspect' <<< "$record_completion_slot" || bootstrap_contract_ok=0
grep -Eqi 'inspect[a-z]*[^;]*complet|complet[^;]*inspect' <<< "$record_completion_slot" ||
  bootstrap_contract_ok=0
# the scaffold slot names R explicitly rather than a generic runtime category
record_scaffold_slot="$(awk '
    /^Scaffold:/ { capture = 1; print; next }
    capture && /^[A-Za-z][A-Za-z ]*:/ { exit }
    capture { print }
' <<< "$bootstrap_record" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eq 'no unapproved R support' <<< "$record_scaffold_slot" || bootstrap_contract_ok=0
# the numbered sequence itself ends with the artifact-inspection and reporting step
bootstrap_sequence_section="$(awk '
    /^## Bootstrapping sequence$/ { capture = 1; next }
    capture && /^### / { exit }
    capture { print }
' "$ROOT/SKILL.md")"
bootstrap_step_ten="$(awk '
    /^10\. / { capture = 1; print; next }
    capture && /^[0-9]+\. / { exit }
    capture { print }
' <<< "$bootstrap_sequence_section" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'inspect' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
grep -Eqi 'generated artifacts' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
grep -Eqi 'exit codes' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
grep -Eqi 'boundar' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
# the numbered interview above owns topic coverage; the record must not restate it
if grep -Eqi 'identity/purpose|research question/intended claim|supported Python minor' \
  <<< "$bootstrap_record_text"; then
  bootstrap_contract_ok=0
fi
for required in \
  'agents/research-code-simplifier.md' \
  'references/prerequisites.md' \
  'only the selected host' \
  'smoke test'; do
  grep -Fq "$required" <<< "$skill_text" || bootstrap_contract_ok=0
done
grep -Fq 'target-version = "py3XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'python-version = "3.XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'uv init --package --build-backend hatch' "$ROOT/references/bootstrap.md" ||
  bootstrap_contract_ok=0
grep -Fq 'coverage' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
grep -Eq '^test-r:' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
if ((bootstrap_contract_ok)); then
  pass "bootstrap interview, placeholders, and runtime contracts are explicit"
else
  fail "bootstrap interview, placeholders, and runtime contracts are explicit"
fi

workflow_scaffold_ok=1
grep -Fq 'workflow/Snakefile' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'rules/' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'schemas/' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Eqi 'body is a single call into' "$ROOT/references/bootstrap.md" ||
  workflow_scaffold_ok=0
grep -Eq '^pipeline:' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
grep -Fq 'snakemake --cores all' "$ROOT/references/bootstrap.md" || workflow_scaffold_ok=0
if grep -Eq 'scripts/0[0-9]_|numbered stage' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if grep -Eqi 'need not pretend' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if grep -Fq 'snakemake --delete-all-output' "$ROOT/references/bootstrap.md" &&
  ! grep -Eqi 'do not use .snakemake --delete-all-output' "$ROOT/references/bootstrap.md"; then
  workflow_scaffold_ok=0
fi
if ((workflow_scaffold_ok)); then
  pass "bootstrap scaffold owns the Snakemake workflow layout behind the Make interface"
else
  fail "bootstrap scaffold must own the Snakemake workflow layout behind the Make interface"
fi

rule_logging_section="$(awk '
    /^## Rule logging$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
rule_logging_text="$(tr '\n' ' ' <<< "$rule_logging_section" | tr -s '[:space:]' ' ')"
logging_ownership_ok=1
grep -Fq 'params.log_level' <<< "$rule_logging_section" || logging_ownership_ok=0
grep -Eqi "declared in the rule.+params" <<< "$rule_logging_text" || logging_ownership_ok=0
grep -Eqi 'never source logging verbosity from the environment' \
  <<< "$rule_logging_text" || logging_ownership_ok=0
if grep -Fq 'os.environ.get("LOG_LEVEL"' <<< "$rule_logging_section"; then
  logging_ownership_ok=0
fi
if ((logging_ownership_ok)); then
  pass "rule logging receives its classified operational setting explicitly"
else
  fail "rule logging must not create an environment-owned operational setting"
fi

# --- 10. final-review ownership corrections remain aligned ---
final_review_contract_ok=1
if grep -Eqi 'stop before[^.]*repository mutation' "$ROOT/references/prerequisites.md"; then
  final_review_contract_ok=0
fi
grep -Eqi 'researcher-editable' "$ROOT/references/configuration.md" || final_review_contract_ok=0
grep -Eqi 'named Python constant|not a researcher-editable setting' \
  "$ROOT/references/configuration.md" || final_review_contract_ok=0
grep -Eq '^## Shared planning companion$' "$ROOT/references/prerequisites.md" ||
  final_review_contract_ok=0
if grep -Eq 'data[^[:space:]]*.*fixtures|data reference.*fixtures' "$ROOT/README.md"; then
  final_review_contract_ok=0
fi
grep -Eqi 'independently resolve[^.]*simplifier' <<< "$skill_text" || final_review_contract_ok=0
grep -Eqi 'blocked' <<< "$skill_text" || final_review_contract_ok=0
if ((final_review_contract_ok)); then
  pass "final-review ownership corrections stay aligned"
else
  fail "final-review ownership corrections stay aligned"
fi

# --- 11. every reference owns one complete, focused domain contract ---
prerequisites_text="$(tr '\n' ' ' < "$ROOT/references/prerequisites.md" | tr -s '[:space:]' ' ')"
host_profile_instruction_ok=1
for required in \
  'agents/research-code-simplifier.md' \
  '.claude/agents/research-code-simplifier.md' \
  '.codex/agents/research-code-simplifier.toml' \
  'only the selected host'; do
  grep -Fq "$required" <<< "$prerequisites_text" || host_profile_instruction_ok=0
done
grep -Eqi 'verbatim' <<< "$prerequisites_text" || host_profile_instruction_ok=0
grep -Eqi 'same name, description, and body' <<< "$prerequisites_text" ||
  host_profile_instruction_ok=0
if ((host_profile_instruction_ok)); then
  pass "prerequisite reference owns deriving each host profile from the canonical profile"
else
  fail "prerequisite reference must tell the agent to derive only the selected host profile from the canonical profile"
fi

if grep -Fq 'src/<package_name>/' "$ROOT/references/bootstrap.md" &&
  grep -Fq 'uv sync --locked' "$ROOT/references/bootstrap.md" &&
  grep -Eqi 'reproduction path' "$ROOT/references/bootstrap.md"; then
  pass "bootstrap reference owns scaffold, locked environment, and reproduction guidance"
else
  fail "bootstrap reference must own scaffold, locked environment, and reproduction guidance"
fi

if grep -Fq 'random_seed: 42' "$ROOT/references/configuration.md" &&
  grep -Eqi 'deterministic' "$ROOT/references/configuration.md"; then
  pass "configuration reference owns deterministic and stochastic seed decisions"
else
  fail "configuration reference must own deterministic and stochastic seed decisions"
fi

configuration_decision_section="$(awk '
    /^## Ownership decision$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/configuration.md")"
configuration_decision_text="$(tr '\n' ' ' <<< "$configuration_decision_section" |
  tr -s '[:space:]' ' ')"
configuration_precedence_ok=1
grep -Eqi 'first matching.*mutually exclusive|mutually exclusive.*first matching' \
  <<< "$configuration_decision_text" || configuration_precedence_ok=0
grep -Eqi 'credentials.*secrets.*machine-specific.*GPU selection.*environment variable.*derived.*paths\.py.*researcher-editable.*scientific.*operational.*analysis\.yaml.*implementation.*constant' \
  <<< "$configuration_decision_text" || configuration_precedence_ok=0
if ((configuration_precedence_ok)); then
  pass "configuration classifier uses exclusive environment-paths-YAML-code precedence"
else
  fail "configuration classifier must keep sensitive, derived, editable, and code buckets exclusive"
fi

snakemake_config_ok=1
grep -Fq 'configfile' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'snakemake.utils.validate' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'additionalProperties: false' "$ROOT/references/configuration.md" ||
  snakemake_config_ok=0
grep -Eqi 'parse time[^.]*before the DAG|before the DAG[^.]*parse time' \
  "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Fq 'ancient()' "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Eqi 'declared in that rule.+params:|params:.+explicit typed function arguments' \
  "$ROOT/references/configuration.md" || snakemake_config_ok=0
grep -Eqi 'never narrow .--rerun-triggers' "$ROOT/references/configuration.md" ||
  snakemake_config_ok=0
if grep -Eqi 'immutable typed' "$ROOT/references/configuration.md"; then
  snakemake_config_ok=0
fi
if ((snakemake_config_ok)); then
  pass "configuration contract owns Snakemake-native loading, override guard, and provenance edges"
else
  fail "configuration contract must own Snakemake-native loading, override guard, and provenance edges"
fi

# each contract keeps one owner: bootstrap and analysis defer instead of restating
dedupe_ok=1
bootstrap_configuration_section="$(awk '
    /^## Configuration$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
bootstrap_configuration_text="$(tr '\n' ' ' <<< "$bootstrap_configuration_section" |
  tr -s '[:space:]' ' ')"
grep -Fq 'references/configuration.md' <<< "$bootstrap_configuration_text" || dedupe_ok=0
grep -Fq '.env.example' <<< "$bootstrap_configuration_text" || dedupe_ok=0
# the ownership buckets themselves belong to references/configuration.md
if grep -Eqi 'versioned YAML|implementation constants|classify those buckets|remain in code' \
  <<< "$bootstrap_configuration_text"; then
  dedupe_ok=0
fi
# references/prerequisites.md owns skill provenance; analysis.md names only the exact skill
grep -Fq 'scientific-critical-thinking' "$ROOT/references/analysis.md" || dedupe_ok=0
if grep -Eqi 'k-dense-ai|scientific-agent-skills' "$ROOT/references/analysis.md"; then
  dedupe_ok=0
fi
grep -Eqi 'scientific-agent-skills' "$ROOT/references/prerequisites.md" || dedupe_ok=0
if ((dedupe_ok)); then
  pass "bootstrap defers configuration ownership and analysis defers skill provenance"
else
  fail "bootstrap must defer configuration ownership and analysis must defer skill provenance"
fi

data_checksum_text="$(tr '\n' ' ' < "$ROOT/references/data.md" | tr -s '[:space:]' ' ')"
data_checksum_ok=1
# checksums are an optional registry field, verified against a published digest where one exists
grep -Eqi 'optional[^.]*checksum|checksum[^.]*optional' <<< "$data_checksum_text" || data_checksum_ok=0
grep -Fq 'published digest' <<< "$data_checksum_text" || data_checksum_ok=0
# a dataset without a checksum still validates; local raw data never needs one
grep -Eqi 'not a validation failure' <<< "$data_checksum_text" || data_checksum_ok=0
grep -Fq 'machine-readable data dictionary' "$ROOT/references/data.md" || data_checksum_ok=0
if ((data_checksum_ok)); then
  pass "data reference keeps checksums optional and owns machine-readable dictionaries"
else
  fail "data reference must keep checksums optional and own machine-readable dictionaries"
fi

if grep -Fq '## Analysis-plan template' "$ROOT/references/analysis.md"; then
  pass "analysis reference owns the complete analysis-plan template"
else
  fail "analysis reference must own the complete analysis-plan template"
fi

figures_text="$(tr '\n' ' ' < "$ROOT/references/figures.md" | tr -s '[:space:]' ' ')"
figures_contract_ok=1
grep -Eqi 'visually inspect[^.]*SVG[^.]*PDF' <<< "$figures_text" || figures_contract_ok=0
grep -Fq 'nature-figure' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'before planning a figure' <<< "$figures_text" || figures_contract_ok=0
# exploratory or deadline framing changes approval speed, not the required contract and exports
grep -Eqi 'figure work regardless of framing' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'exploratory' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'four required export formats' <<< "$figures_text" || figures_contract_ok=0
# the obligation stays prose; no echoed preflight template
if grep -Eqi 'Figure contract source loaded|Figure skill invoked' <<< "$figures_text"; then
  figures_contract_ok=0
fi
if ((figures_contract_ok)); then
  pass "figure reference requires its own load and nature-figure without an echo template"
else
  fail "figure reference must require loading itself and nature-figure in prose, with no preflight echo"
fi

reference_ownership_ok=1
for reference in "$ROOT"/references/*.md; do
  if grep -Eqi 'AGENTS\.md owns|procedural expansion|floor items|post-vendor|adapter.*install[^.]*skill|skill.*install[^.]*adapter' \
    "$reference"; then
    fail "reference contains deferred ownership or adapter-owned skill installation: ${reference#"$ROOT/"}"
    reference_ownership_ok=0
  fi
done
((reference_ownership_ok)) && pass "references own focused procedures without deferred policy ownership"

# --- 12. detailed figure naming has one canonical owner ---
figure_owner="$ROOT/references/figures.md"
if grep -Fqs 'mf1_{short_descriptive_name}' "$figure_owner" &&
  grep -Fqs 'edf1_{short_descriptive_name}' "$figure_owner" &&
  grep -Fqs 'svg/mf1_hazard_ratio_distribution.svg' "$figure_owner" &&
  grep -Fqs 'pdf/mf1_hazard_ratio_distribution.pdf' "$figure_owner" &&
  grep -Fqs 'tiff/mf1_hazard_ratio_distribution.tiff' "$figure_owner" &&
  grep -Fqs 'png/mf1_hazard_ratio_distribution.png' "$figure_owner" &&
  grep -Fqs 'mf1_hazard_ratio_distribution.csv' "$figure_owner" &&
  grep -Fqs 'results/figures/<figure_id>/<format>/' "$figure_owner" &&
  grep -Fqs 'results/figure_data/<figure_id>/' "$figure_owner" &&
  grep -Eqis 'letters[^.]*(never|not)[^.]*asset name' "$figure_owner" &&
  grep -Eqis 'same[^.]*stem[^.]*format' "$figure_owner" &&
  grep -Eqis 'panel letters are applied only' "$figure_owner"; then
  pass "figure reference owns detailed atomic asset naming"
else
  fail "figure reference must own detailed naming, shared stems, export paths, and panel lettering"
fi

figure_duplicates="$(
  grep -HnE 'mf[0-9]+_|edf[0-9]+_|short_descriptive_name|hazard_ratio_distribution' \
    "$ROOT/AGENTS.md" "$ROOT/SKILL.md" "$ROOT/README.md" \
    "$ROOT/agents/research-code-simplifier.md" \
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

# --- 13. simplifier profile delegates naming and configuration policy ---
if ! grep -Eq 'config/analysis\.yaml|random_seed:|test_[a-z]|datasets\.yaml' \
  "$ROOT/agents/research-code-simplifier.md"; then
  pass "simplifier profile contains no independent configuration or test-naming grammar"
else
  fail "simplifier profile must delegate configuration and test-naming grammar to repository authorities"
fi

# --- 14. governed work and delegated simplification resolve exact identities ---
governed_resolution_ok=1
governed_record="$(awk '
    /^### Governed-work invocation record$/ { found = 1; next }
    found && /^```text$/ { capture = 1; next }
    capture && /^```$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
governed_record_text="$(tr '\n' ' ' <<< "$governed_record" | tr -s '[:space:]' ' ')"
for required in 'research-repo-standard' 'host-native resolver' 'provenance' 'invoked'; do
  grep -Fq "$required" <<< "$governed_record_text" || governed_resolution_ok=0
done
if ((governed_resolution_ok)); then
  pass "governed work records exact standard resolution and invocation before classification"
else
  fail "governed work must record exact standard resolution and invocation before classification"
fi

simplifier_resolution_ok=1
simplifier_record="$(awk '
    /delegated diff/ { found = 1; next }
    found && /^```text$/ { capture = 1; next }
    capture && /^```$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
simplifier_record_text="$(tr '\n' ' ' <<< "$simplifier_record" | tr -s '[:space:]' ' ')"
for required in 'research-code-simplifier' 'host-native resolver' 'profile path' 'invoked'; do
  grep -Fq "$required" <<< "$simplifier_record_text" || simplifier_resolution_ok=0
done
if ((simplifier_resolution_ok)); then
  pass "delegated simplifier adds exact host-native profile resolution and invocation"
else
  fail "delegated simplifier must add exact host-native profile resolution and invocation"
fi

# --- 15. pressure evidence uses the independently scored Task 6 A/D reruns ---
pressure_results="$(awk '
    /^## GREEN results$/ { capture = 1 }
    capture { print }
' "$ROOT/tests/skill_pressure_scenarios.md")"
pressure_results_text="$(tr '\n' ' ' <<< "$pressure_results" | tr -s '[:space:]' ' ')"
pressure_evidence_ok=1
for required in \
  'task6_pressure_a_green' \
  'task6_pressure_d' \
  '27/27' \
  '/.worktrees/skill-native-governance/SKILL.md' \
  'research-repo-standard' \
  'research-code-simplifier'; do
  grep -Fq "$required" <<< "$pressure_results_text" || pressure_evidence_ok=0
done
# the reruns stayed uncoached and the installed-host resolver is still reported as a boundary
grep -Eqi 'no required invocation statement' <<< "$pressure_results_text" || pressure_evidence_ok=0
grep -Eqi 'installed-host provenance[^.]*boundary' <<< "$pressure_results_text" ||
  pressure_evidence_ok=0
grep -Eqi 'through the host-native resolver' <<< "$pressure_results_text" || pressure_evidence_ok=0
grep -Eqi 'was invoked' <<< "$pressure_results_text" || pressure_evidence_ok=0
# stored transcripts are dated against the contract they were scored under
grep -Eqi 'Archive note \(2026-08-14\)' <<< "$pressure_results_text" || pressure_evidence_ok=0
grep -Eqi 'working-tree .?SKILL\.md.? is the current contract' <<< "$pressure_results_text" ||
  pressure_evidence_ok=0
if grep -Eq 'task5_counted_a|task5_fix1_d' <<< "$pressure_results_text"; then
  pressure_evidence_ok=0
fi
if ((pressure_evidence_ok)); then
  pass "pressure evidence records uncoached Task 6 A/D reruns and the installed-host boundary"
else
  fail "pressure evidence must use the Task 6 A/D reruns without overstating host resolution"
fi

# --- 15a. the Snakemake pressure scenarios stay pinned ---
snakemake_scenarios_ok=1
for heading in \
  '## Scenario E — logic in a rule body' \
  '## Scenario F — quick config override' \
  '## Scenario G — environment-sourced setting'; do
  grep -Fq "$heading" "$ROOT/tests/skill_pressure_scenarios.md" || snakemake_scenarios_ok=0
done
if ((snakemake_scenarios_ok)); then
  pass "pressure scenarios cover Snakemake rule, override, and environment contracts"
else
  fail "pressure scenarios must cover Snakemake rule, override, and environment contracts"
fi

# --- final ---
if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all consistency tests passed"
