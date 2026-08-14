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
  grep -Fq 'SKILL.md is the maintained product' "$ROOT/AGENTS.md" &&
  ! grep -Eq 'data/raw/|Repository layout|Seed 42|portable governed policy' "$ROOT/AGENTS.md"; then
  pass "AGENTS.md contains only concise source-repository instructions"
else
  fail "AGENTS.md must be concise source-only guidance with SKILL.md as the product"
fi

skill_core_ok=1
for heading in \
  '## Applicability and precedence' \
  '## Required skills and modification gates' \
  '## Safety floor' \
  '## Bootstrapping sequence' \
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
  'docs/lab_notebook.md' \
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
  grep -Fq 'Not for general-purpose software projects' <<< "$description_text"; then
  pass "SKILL.md description states triggering conditions and its carve-out"
else
  fail "SKILL.md description must start with triggering conditions and keep the carve-out"
fi

skill_text="$(tr '\n' ' ' < "$ROOT/SKILL.md" | tr -s '[:space:]' ' ')"
routing_ok=1
for trigger in \
  'a required capability is unresolved, installation or recovery is requested, or host integration must be verified' \
  'creating repository structure, tool configuration, CI, the Make interface, or initial project documentation' \
  'classifying, loading, using, changing, or overriding settings, paths, or provenance' \
  'acquiring, registering, preprocessing, describing, validating, or contracting data' \
  'scientific planning, estimands, design, inclusion, missingness, modeling, implementation, interpretation, or reporting' \
  'planning a figure, writing plotting code, changing figure outputs, or performing QA'; do
  grep -Fq "$trigger" <<< "$skill_text" || routing_ok=0
done
if ((routing_ok)); then
  pass "SKILL.md routes all six domain references by semantic trigger"
else
  fail "SKILL.md must preserve every approved reference trigger group"
fi

# --- 3b. modification gates stay proportionate to what a change can break ---
gate_section="$(awk '
    /^## Required skills and modification gates$/ { capture = 1; next }
    capture && /^## Safety floor$/ { exit }
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
# an unclear classification escalates upward rather than defaulting to the loosest path
grep -Eqi 'stricter' <<< "$gate_text" || gate_ok=0
standard_gate_text="$(awk '
    /^- \*\*Standard gate:\*\*/ { capture = 1; print; next }
    capture && /^- \*\*/ { exit }
    capture { print }
' <<< "$gate_section" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
grep -Eqi 'authoriz' <<< "$standard_gate_text" || gate_ok=0
grep -Fq 'docs/lab_notebook.md' <<< "$standard_gate_text" || gate_ok=0
grep -Eqi 'test' <<< "$standard_gate_text" || gate_ok=0
# the middle notch deliberately carries no specification or plan ceremony
grep -Eqi 'no specification|without a specification|no plan|without a plan' \
  <<< "$standard_gate_text" || gate_ok=0
# the governed-work authorization prose defers to that single list instead of restating it
if grep -Eq 'Obtain authorization before changing an estimand' <<< "$skill_text"; then
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

adapter_runtime_ok=1
for adapter in claude-code codex; do
  grep -Fq 'source "$SCRIPT_DIR/profile-installer.sh"' "$ROOT/adapters/$adapter.sh" ||
    adapter_runtime_ok=0
  grep -Fq "install_research_code_simplifier '$adapter'" "$ROOT/adapters/$adapter.sh" ||
    adapter_runtime_ok=0
  if grep -Eq 'AGENTS\.md|CLAUDE\.md|CODEX\.md|agents/code-simplifier|shared' \
    "$ROOT/adapters/$adapter.sh"; then
    adapter_runtime_ok=0
  fi
done
if [[ -f "$ROOT/adapters/profile-installer.sh" ]] &&
  grep -Fq 'install_research_code_simplifier()' "$ROOT/adapters/profile-installer.sh" &&
  ((adapter_runtime_ok)); then
  pass "host adapters source one common installer with fixed host identities"
else
  fail "host adapters must source the common installer and install only their fixed host profile"
fi

if ! grep -Eq 'AGENTS\.md|CLAUDE\.md|CODEX\.md|agents/code-simplifier|target policy|shared profile' \
  "$ROOT/adapters/profile-installer.sh" "$ROOT/adapters/claude-code.sh" \
  "$ROOT/adapters/codex.sh" 2> /dev/null; then
  pass "adapter runtime contains no target-policy or shared-profile logic"
else
  fail "adapter runtime must not contain target-policy or shared-profile logic"
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
  'Resolve `research-repo-standard` by exact name through the selected host' \
  './adapters/codex.sh <target-repo>' \
  './adapters/claude-code.sh <target-repo>' \
  'host-native smoke test' \
  'research-code-simplifier'; do
  grep -Fq "$required" <<< "$readme_text" || integration_docs_ok=0
done
for required in \
  'After the core scaffold is complete' \
  'host-native smoke test' \
  'research-repo-standard' \
  'research-code-simplifier'; do
  grep -Fq "$required" <<< "$bootstrap_text" || integration_docs_ok=0
done
if ((integration_docs_ok)); then
  pass "bootstrap and README expose only the live skill-native integration path"
else
  fail "bootstrap and README must resolve the skill, run a direct adapter, and require host smoke testing"
fi

# --- 7. removed workflows and superseded process artifacts stay absent ---
removed_paths_ok=1
for removed_path in \
  vendor.sh \
  tests/vendor_test.sh \
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
if [[ ! -f "$ROOT/tests/adapter_safety_test.sh" ]]; then
  fail "focused adapter safety suite is missing: tests/adapter_safety_test.sh"
  removed_paths_ok=0
fi
((removed_paths_ok)) && pass "obsolete workflows and superseded process artifacts are absent"

production_paths=(
  "$ROOT/AGENTS.md"
  "$ROOT/SKILL.md"
  "$ROOT/README.md"
  "$ROOT/Makefile"
  "$ROOT/references"
  "$ROOT/agents"
  "$ROOT/adapters"
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

bootstrap_integration_section="$(awk '
    /^## Selected host integration$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
bootstrap_integration_text="$(tr '\n' ' ' <<< "$bootstrap_integration_section" | tr -s '[:space:]' ' ')"
bootstrap_source_ok=1
grep -Eqi 'provenance-verified.*(skill )?source.*(resolver|resolution)|resolver.*provenance-verified.*(skill )?source' \
  <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
grep -Eq 'research_standard_source=' <<< "$bootstrap_integration_section" || bootstrap_source_ok=0
grep -Eq 'target_repo=' <<< "$bootstrap_integration_section" || bootstrap_source_ok=0
grep -Fq '"$research_standard_source/adapters/codex.sh" "$target_repo"' \
  <<< "$bootstrap_integration_section" || bootstrap_source_ok=0
grep -Fq '"$research_standard_source/adapters/claude-code.sh" "$target_repo"' \
  <<< "$bootstrap_integration_section" || bootstrap_source_ok=0
if grep -Eq '^\./adapters/(codex|claude-code)\.sh' <<< "$bootstrap_integration_section"; then
  bootstrap_source_ok=0
fi
if ((bootstrap_source_ok)); then
  pass "bootstrap invokes only provenance-verified skill-source adapters against the target"
else
  fail "bootstrap must resolve the standard source and invoke its selected adapter against the target"
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
for required in 'currently supported Python minor' 'host adapter'; do
  grep -Fq "$required" <<< "$interview_section" || bootstrap_contract_ok=0
done
for required in \
  '1. What is the project identity and purpose?' \
  '2. What is the primary research question and intended scientific claim?' \
  '3. Is the current status exploratory or confirmatory?'; do
  grep -Fqx "$required" <<< "$interview_section" || bootstrap_contract_ok=0
done
if grep -Fq 'project identity and purpose, primary research question' <<< "$interview_section"; then
  bootstrap_contract_ok=0
fi
for required in \
  '### Bootstrap execution record' \
  'the response first reproduces this record with undecided' \
  'asks exactly one next question'; do
  grep -Fq "$required" "$ROOT/SKILL.md" || bootstrap_contract_ok=0
done
grep -Eqi 'gate-artifact' <<< "$skill_text" || bootstrap_contract_ok=0

# the execution record stays a compact checklist of the failure modes under pressure
bootstrap_record="$(awk '
    /^### Bootstrap execution record$/ { found = 1; next }
    found && /^```text$/ { capture = 1; next }
    capture && /^```$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
bootstrap_record_text="$(tr '\n' ' ' <<< "$bootstrap_record" | tr -s '[:space:]' ' ')"
record_slots="$(grep -c . <<< "$bootstrap_record")"
[[ "$record_slots" -ge 1 && "$record_slots" -le 6 ]] || bootstrap_contract_ok=0
for required_pattern in \
  'AGENTS\.md.*CLAUDE\.md.*CODEX\.md' \
  'shared top-level simplifier' \
  'Seed 42' \
  'deterministic' \
  'smoke test' \
  'boundar' \
  'artifacts inspected'; do
  grep -Eqi "$required_pattern" <<< "$bootstrap_record_text" || bootstrap_contract_ok=0
done
# the numbered interview above owns topic coverage; the record must not restate it
if grep -Eqi 'identity/purpose|research question/intended claim|supported Python minor' \
  <<< "$bootstrap_record_text"; then
  bootstrap_contract_ok=0
fi
for required in 'adapters/codex.sh' 'adapters/claude-code.sh' 'smoke test'; do
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

stage_logging_section="$(awk '
    /^## Stage logging$/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/references/bootstrap.md")"
stage_logging_text="$(tr '\n' ' ' <<< "$stage_logging_section" | tr -s '[:space:]' ' ')"
logging_ownership_ok=1
grep -Fq 'stage_config.log_level' <<< "$stage_logging_section" || logging_ownership_ok=0
grep -Eqi 'validated.*passed explicitly|passed explicitly.*validated' \
  <<< "$stage_logging_text" || logging_ownership_ok=0
if grep -Fq 'os.environ.get("LOG_LEVEL"' <<< "$stage_logging_section"; then
  logging_ownership_ok=0
fi
if ((logging_ownership_ok)); then
  pass "bootstrap logging receives its classified operational setting explicitly"
else
  fail "bootstrap logging must not create an environment-owned operational setting"
fi

# --- 10. final-review ownership corrections remain aligned ---
final_review_contract_ok=1
if grep -Fq 'stop before repository mutations' "$ROOT/references/prerequisites.md"; then
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
for required in 'independently resolve' 'future code changes' 'blocked'; do
  grep -Fq "$required" <<< "$skill_text" || final_review_contract_ok=0
done
if ((final_review_contract_ok)); then
  pass "final-review ownership corrections stay aligned"
else
  fail "final-review ownership corrections stay aligned"
fi

# --- 11. every reference owns one complete, focused domain contract ---
if grep -Fq -- '--agent <codex|claude-code>' "$ROOT/references/prerequisites.md"; then
  pass "prerequisite reference owns the portable selected-host installer form"
else
  fail "prerequisite reference must own the portable selected-host installer form"
fi

if grep -Fq 'src/<package_name>/' "$ROOT/references/bootstrap.md" &&
  grep -Fq 'uv sync --locked' "$ROOT/references/bootstrap.md" &&
  grep -Fq 'shortest reproduction path' "$ROOT/references/bootstrap.md"; then
  pass "bootstrap reference owns scaffold, locked environment, and reproduction guidance"
else
  fail "bootstrap reference must own scaffold, locked environment, and reproduction guidance"
fi

if grep -Fq 'Do not invent a seed field for a fully deterministic workflow.' \
  "$ROOT/references/configuration.md" &&
  grep -Fq 'random_seed: 42' "$ROOT/references/configuration.md"; then
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

if grep -Fq 'SHA-256' "$ROOT/references/data.md" &&
  grep -Fq 'machine-readable data dictionary' "$ROOT/references/data.md"; then
  pass "data reference owns checksums and machine-readable dictionaries"
else
  fail "data reference must own checksums and machine-readable dictionaries"
fi

if grep -Fq '## Analysis-plan template' "$ROOT/references/analysis.md"; then
  pass "analysis reference owns the complete analysis-plan template"
else
  fail "analysis reference must own the complete analysis-plan template"
fi

figures_text="$(tr '\n' ' ' < "$ROOT/references/figures.md" | tr -s '[:space:]' ' ')"
figures_contract_ok=1
grep -Fq 'Open and visually inspect both the rendered SVG and rendered PDF' \
  "$ROOT/references/figures.md" || figures_contract_ok=0
grep -Fq 'nature-figure' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'before planning a figure' <<< "$figures_text" || figures_contract_ok=0
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
grep -Fqx \
  'Standard skill: exact research-repo-standard; host-native resolver; source provenance; invoked' \
  <<< "$governed_record" || governed_resolution_ok=0
if ((governed_resolution_ok)); then
  pass "governed work records exact standard resolution and invocation before classification"
else
  fail "governed work must record exact standard resolution and invocation before classification"
fi

simplifier_resolution_ok=1
simplifier_record="$(awk '
    /^Before inspecting the delegated diff, the reviewer reports this additional resolution record:$/ {
      found = 1
      next
    }
    found && /^```text$/ { capture = 1; next }
    capture && /^```$/ { exit }
    capture { print }
' "$ROOT/SKILL.md")"
simplifier_record_text="$(tr '\n' ' ' <<< "$simplifier_record" | tr -s '[:space:]' ' ')"
grep -Fq \
  'Simplifier profile: exact research-code-simplifier; host-native resolver; resolved profile path; invoked' \
  <<< "$simplifier_record_text" || simplifier_resolution_ok=0
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
  'Total: **27/27 mandatory criteria passed.**' \
  'no required invocation statement or rubric-overlapping wording' \
  'Real installed-host provenance remains a post-integration smoke-test boundary' \
  'resolved through the host-native resolver to `/Users/lucascamillo/research-repo-standard/.worktrees/skill-native-governance/SKILL.md` and was invoked' \
  'I resolve and invoke the exact `research-repo-standard` skill and the exact `research-code-simplifier` profile'; do
  grep -Fq "$required" <<< "$pressure_results_text" || pressure_evidence_ok=0
done
if grep -Eq 'task5_counted_a|task5_fix1_d' <<< "$pressure_results_text"; then
  pressure_evidence_ok=0
fi
if ((pressure_evidence_ok)); then
  pass "pressure evidence records uncoached Task 6 A/D reruns and the installed-host boundary"
else
  fail "pressure evidence must use the Task 6 A/D reruns without overstating host resolution"
fi

# --- final ---
if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all consistency tests passed"
