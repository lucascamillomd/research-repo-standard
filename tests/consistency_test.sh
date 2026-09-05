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

# Read a Markdown section from stdin, excluding its heading unless requested.
section() {
  awk '
    BEGIN { start = ARGV[1]; stop = ARGV[2]; include = ARGV[3]; ARGC = 1 }
    $0 ~ start { capture = 1; if (include) print; next }
    capture && stop != "" && $0 ~ stop { exit }
    capture { print }
  ' "$1" "${2:-}" "${3:-0}"
}
flat() { tr '\n' ' ' | tr -s '[:space:]' ' '; }
report() {
  if (($1)); then pass "$2"; else fail "$3"; fi
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

# the source repository works test-first: meaning anchors, a failing blind scenario, a recorded GREEN
agents_text="$(flat < "$ROOT/AGENTS.md")"
agents_test_first_ok=1
grep -Eqi 'test-first' <<< "$agents_text" || agents_test_first_ok=0
grep -Eqi 'meaning[^.]*(never|not)[^.]*exact sentence' <<< "$agents_text" || agents_test_first_ok=0
grep -Eqi 'blind scenario[^.]*hidden rubric' <<< "$agents_text" || agents_test_first_ok=0
grep -Eqi 'fresh agent fails' <<< "$agents_text" || agents_test_first_ok=0
grep -Eq 'GREEN' <<< "$agents_text" || agents_test_first_ok=0
report "$agents_test_first_ok" \
  "AGENTS.md defines test-first maintenance for this documentation repository" \
  "AGENTS.md must require meaning anchors, a failing blind scenario before behavior changes, and a recorded GREEN score"

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
  'superpowers:writing-plans' \
  'scientific-critical-thinking' \
  'nature-figure' \
  'research-code-simplifier' \
  'data/raw/' \
  'Seed 42' \
  'docs/LAB_NOTEBOOK.md' \
  'transactionally'; do
  grep -Fq "$required" "$ROOT/SKILL.md" || skill_core_ok=0
done
report "$skill_core_ok" \
  "SKILL.md owns the normative core and required gates" \
  "SKILL.md must own every normative heading, safety invariant, and required skill"

safety_floor_section="$(section '^## Safety floor$' '^## Bootstrapping sequence$' < "$ROOT/SKILL.md")"
safety_floor_text="$(flat <<< "$safety_floor_section")"
safety_floor_ok=1
grep -Eqi 'result-affecting setting[^.]*one[^.]*owner|one[^.]*owner[^.]*result-affecting setting' \
  <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'fail[^.]*before[^.]*comput' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'Seed 42' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'deterministic' <<< "$safety_floor_text" || safety_floor_ok=0
# removing, disabling, skipping, or loosening a check counts as weakening it
grep -Eqi '(remov|disabl|skip|loosen)[^.]*check[^.]*weaken' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi '(checks[^.]*covering tests|includes[^.]*covering tests)' <<< "$safety_floor_text" || safety_floor_ok=0
# the nondeterminism and hidden-default invariants stay in the floor itself
grep -Eqi 'nondeterminis[a-z]*[^.]*(boundar|declar)|declar[^.]*nondeterminis' \
  <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi '(never|not)[^.]*(hidden|buried|concealed)[^.]*default' <<< "$safety_floor_text" ||
  safety_floor_ok=0
# raw immutability, authorized estimand change, exploratory/confirmatory labeling, and
# missingness-before-exclusion stay in the floor itself (items 1, 3, 4, 5)
grep -Eqi 'raw data[^.]*immutable' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'data/raw/[^.]*(never|ever) modified' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'estimand[^.]*authoriz' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'exploratory[^.]*confirmatory' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'complete-case' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'missingness[^.]*before' <<< "$safety_floor_text" || safety_floor_ok=0
grep -Eqi 'criteria[^.]*code' <<< "$safety_floor_text" || safety_floor_ok=0
# ownership bucket mechanics belong to references/configuration.md, not the floor
if grep -Eq 'paths\.py|versioned YAML|environment variable' <<< "$safety_floor_text"; then
  safety_floor_ok=0
fi
# the required-skills section owns skill gating; the floor must not restate it
if grep -Eqi 'Required skills are gates' <<< "$safety_floor_text"; then
  safety_floor_ok=0
fi
report "$safety_floor_ok" \
  "safety floor keeps scientific invariants and defers configuration mechanics" \
  "safety floor must state raw-immutability, gate, authorization, labeling, missingness, seed, and one-owner invariants without restating configuration mechanics or skill gating"

description_text="$(awk '
    /^description:/ { capture = 1; sub(/^description:[[:space:]]*/, ""); }
    capture && /^---$/ { exit }
    capture { print }
' "$ROOT/SKILL.md" | flat | sed 's/^ //')"
if [[ "$description_text" == "Use when"* ]] &&
  grep -Eqi 'not for general-purpose' <<< "$description_text"; then
  pass "SKILL.md description states triggering conditions and its carve-out"
else
  fail "SKILL.md description must start with triggering conditions and keep the carve-out"
fi

skill_text="$(flat < "$ROOT/SKILL.md")"
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
# the bootstrap row fires on changes to its owned contracts, not only on creation
check_routing_row 'references/bootstrap.md' 'creating or changing' 'structure|scaffold' \
  'dependenc' 'uv\.lock' 'rule logging' 'CI' 'documentation' || routing_ok=0
check_routing_row 'references/configuration.md' 'settings' 'paths' 'provenance' || routing_ok=0
check_routing_row 'references/data.md' 'data' 'validat' 'contract' || routing_ok=0
check_routing_row 'references/analysis.md' 'estimand' 'missing' 'model' 'report' || routing_ok=0
check_routing_row 'references/figures.md' 'figure' 'plot' 'QA' || routing_ok=0
report "$routing_ok" \
  "SKILL.md routes all six domain references by semantic trigger" \
  "SKILL.md must preserve every approved reference trigger group"

# --- 3b. modification gates stay proportionate to what a change can break ---
gate_section="$(section '^## Required skills and modification gates$' '^## Reference routing$' < "$ROOT/SKILL.md")"
gate_text="$(flat <<< "$gate_section")"
gate_ok=1
for path_label in 'Full gate' 'Standard gate' 'Light path' 'No gate'; do
  grep -Eq "\*\*${path_label}[.:]\*\*" <<< "$gate_text" || gate_ok=0
done
# the full gate is scoped to design-level decisions and owns their list
grep -Eqi 'design-level' <<< "$gate_text" || gate_ok=0
for design_item in 'estimand' 'study design' 'data contract' 'pipeline structure' 'claim scope'; do
  grep -Fqi "$design_item" <<< "$gate_text" || gate_ok=0
done
# an uncertain classification resolves to the full gate rather than the loosest path
grep -Eqi '(uncertain|unsure|in doubt)[^.]*full gate' <<< "$gate_text" || gate_ok=0
# classification keys to scientific meaning, not to which file carries the edit
grep -Eqi '(scientific|meaning)[^.]*not[^.]*file' <<< "$gate_text" || gate_ok=0
# the required-skills section alone owns the rule that a file on disk is not resolution
resolution_rule_ok=1
grep -Eqi '(file on disk|file presence|presence alone)[^.]*(not|never)[^.]*resol' <<< "$gate_text" ||
  resolution_rule_ok=0
resolution_rule_copies="$(
  grep -HnEi 'file on disk|file presence|presence alone|named after a skill' \
    "$ROOT/SKILL.md" "$ROOT/README.md" "$ROOT"/references/*.md 2> /dev/null | grep -c . || true
)"
[[ "$resolution_rule_copies" == 1 ]] || resolution_rule_ok=0
report "$resolution_rule_ok" \
  "required-skills section alone owns the file-presence resolution rule" \
  "SKILL.md required-skills section must state once that a file on disk is not resolution, with no copy in README or references"
grep -Eqi 'configuration[^.]*estimand[^.]*design-level' <<< "$gate_text" || gate_ok=0
# gutting a check never rides the light path; regeneration requires the approved state unchanged
grep -Eqi '(delet|disabl|skip|loosen|relax)[^.]*never[^.]*light path' <<< "$gate_text" || gate_ok=0
grep -Eqi 'unchanged[^.]*approv' <<< "$gate_text" || gate_ok=0
# the full gate names brainstorming, then a committed and reviewed specification, then
# writing-plans as the plan producer; implementation waits for that plan
full_gate_text="$(section '^- \*\*Full gate[.:]\*\*' '^- \*\*' 1 <<< "$gate_section" | flat)"
grep -Fq 'superpowers:brainstorming' <<< "$full_gate_text" || gate_ok=0
grep -Eqi 'specification[^.]*commit' <<< "$full_gate_text" || gate_ok=0
grep -Fq 'superpowers:writing-plans' <<< "$full_gate_text" || gate_ok=0
grep -Eqi 'not implement until[^.]*plan|plan[^.]*before implement' <<< "$full_gate_text" || gate_ok=0
grep -Fq '## Scenario K — failing test maintenance' "$ROOT/tests/skill_pressure_scenarios.md" || gate_ok=0
grep -Eqi 'skip-mark' "$ROOT/tests/skill_pressure_scenarios.md" || gate_ok=0
standard_gate_text="$(section '^- \*\*Standard gate[.:]\*\*' '^- \*\*' 1 <<< "$gate_section" | flat)"
grep -Eqi 'authoriz' <<< "$standard_gate_text" || gate_ok=0
grep -Fq 'docs/LAB_NOTEBOOK.md' <<< "$standard_gate_text" || gate_ok=0
grep -Eqi 'test' <<< "$standard_gate_text" || gate_ok=0
# governed work owns the entry field set; the standard-gate bullet only points at it
grep -Eqi 'entry[^.]*Governed work|Governed work[^.]*entry' <<< "$standard_gate_text" || gate_ok=0
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
report "$gate_ok" \
  "SKILL.md classifies changes into four proportionate paths with one design-level list" \
  "SKILL.md must offer full, standard, light, and no-gate paths that escalate upward from one design-level list"

# --- 3c. independent review and interview cadence scale with the work ---
proportion_ok=1
# the simplifier pass runs per completed plan task, batches ad-hoc work, and any skip is recorded
grep -Eqi 'once per coherent (unit|batch)' <<< "$skill_text" || proportion_ok=0
grep -Eqi 'after (each|every) (completed |finished )?plan task[^.]*before (starting|beginning) the next' \
  <<< "$skill_text" || proportion_ok=0
grep -Eqi '(end-of-plan|combined diff)[^.]*(does not|never|cannot) satisf' <<< "$skill_text" ||
  proportion_ok=0
# the plan-task cadence scenario stays pinned with its refusal anchor
grep -Fq '## Scenario H — plan-task simplifier cadence' "$ROOT/tests/skill_pressure_scenarios.md" || proportion_ok=0
grep -Eqi 'end-of-plan pass' "$ROOT/tests/skill_pressure_scenarios.md" || proportion_ok=0
grep -Eqi 'waive|waiver' <<< "$skill_text" || proportion_ok=0
grep -Fq 'completion report' <<< "$skill_text" || proportion_ok=0
grep -Eqi 'self-(pass|review)[^.]*(never|not|cannot)[^.]*substitut' <<< "$skill_text" ||
  proportion_ok=0
bootstrap_sequence_section="$(section '^## Bootstrapping sequence$' '^### ' < "$ROOT/SKILL.md")"
# brevity may batch only the mechanical interview topics, and only with confirmation
bootstrap_step_two="$(section '^2\. ' '^[0-9]+\. ' 1 <<< "$bootstrap_sequence_section" | flat)"
grep -Eqi 'brevity|keep the interview short' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'mechanical' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'explicit confirmation' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'one at a time' <<< "$bootstrap_step_two" || proportion_ok=0
grep -Eqi 'silent' <<< "$bootstrap_step_two" || proportion_ok=0
# batching covers those two mechanical topics and nothing else
grep -Eqi '(every|all) other[^.]*(topic|question)[^.]*one at a time' <<< "$bootstrap_step_two" ||
  proportion_ok=0
# the scenario rubric must score the same relaxed cadence, not the old never-bundle rule
scenario_c_rubric="$(awk '
    /^## Scenario C — deterministic bootstrap$/ { found = 1 }
    found && /^### Evaluator rubric/ { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
' "$ROOT/tests/skill_pressure_scenarios.md" | flat)"
grep -Eqi 'scientific topics one at a time' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'mechanical topics' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'explicit confirmation' <<< "$scenario_c_rubric" || proportion_ok=0
grep -Eqi 'self-select' <<< "$scenario_c_rubric" || proportion_ok=0
report "$proportion_ok" \
  "simplifier review runs per plan task, batches ad-hoc work, and brevity relaxes only mechanical interview topics" \
  "simplifier review must run per plan task, batch ad-hoc work with a recorded waiver, and brevity must batch only mechanical interview topics"

# --- 3ca. critique, plan amendment, and the scoped simplifier waiver ---
governed_section="$(section '^## Governed work$' '^## Completion$' < "$ROOT/SKILL.md")"
governed_text="$(flat <<< "$governed_section")"
governed_ok=1
# the critique keys to dependent scientific judgment at every gate, not only design level
grep -Eqi 'depends on a scientific judgment' <<< "$governed_text" || governed_ok=0
grep -Eqi 'every gate' <<< "$governed_text" || governed_ok=0
grep -Eqi 'covariate sets[^.]*thresholds[^.]*model settings' <<< "$governed_text" || governed_ok=0
# findings arrive before the dependent decision or implementation, never keyed to presentation;
# analysis.md owns the procedure
critique_text="$(section '^### Independent critique$' '^##' < "$ROOT/SKILL.md" | flat)"
grep -Eqi 'findings[^.]*before[^.]*(decid|implement)' <<< "$critique_text" || governed_ok=0
grep -Eqi 'before[^.]*presented' <<< "$critique_text" && governed_ok=0
grep -Eqi 'analysis\.md[^.]*(procedure|batching|disposition)' <<< "$critique_text" || governed_ok=0
# a mid-implementation fork stops for user options instead of a silent fallback
grep -Eqi 'stop and consult' <<< "$governed_text" || governed_ok=0
grep -Eqi 'two to four concrete options' <<< "$governed_text" || governed_ok=0
grep -Eqi "host's question tool" <<< "$governed_text" || governed_ok=0
grep -Eqi 'never committed' <<< "$governed_text" || governed_ok=0
grep -Eqi 'plan never made' <<< "$governed_text" || governed_ok=0
# committed result artifacts count as presented, and the deadline is never agent-chosen
grep -Eqi 'committed, pushed, or shared' <<< "$governed_text" || governed_ok=0
grep -Fq '## Scenario J — committed but unpresented results' "$ROOT/tests/skill_pressure_scenarios.md" || governed_ok=0
# the fork scenario stays pinned with its refusal anchors
grep -Fq '## Scenario I — mid-task design fork' "$ROOT/tests/skill_pressure_scenarios.md" || governed_ok=0
grep -Eqi 'silently pick a fallback' "$ROOT/tests/skill_pressure_scenarios.md" || governed_ok=0
grep -Fq 'AskUserQuestion' "$ROOT/tests/skill_pressure_scenarios.md" || governed_ok=0
# the analysis plan is amended before affected results are presented
grep -Fq 'docs/ANALYSIS_PLAN.md' <<< "$governed_text" || governed_ok=0
grep -Eqi 'post hoc status' <<< "$governed_text" || governed_ok=0
grep -Fq 'references/analysis.md' <<< "$governed_text" || governed_ok=0
# the simplifier waiver applies only when resolution or delegation actually fails
grep -Eqi 'only when[^.]*(resolution|invocation|launch)[^.]*fails' <<< "$governed_text" || governed_ok=0
grep -Eqi 'self-pass never substitutes' <<< "$governed_text" || governed_ok=0
grep -Fq 'Review waivers' "$ROOT/references/prerequisites.md" || governed_ok=0
report "$governed_ok" \
  "governed work critiques dependent judgments, consults on mid-implementation forks, amends the plan, and scopes the waiver" \
  "governed work must critique every dependent scientific judgment, stop and consult on mid-implementation forks, amend the analysis plan, and allow the waiver only on a resolution failure"

# --- 3cb. records, destruction, change discipline, and simplifier mechanics stay owned by Governed work ---
records_ok=1
# the notebook entry field set is stated once, under Governed work
grep -Eqi 'decision[^.]*rationale[^.]*authorization[^.]*affected[^.]*superseded' <<< "$governed_text" ||
  records_ok=0
# destruction is explicit, narrowly targeted, and states recoverability
grep -Eqi '(never|not) implied' <<< "$governed_text" || records_ok=0
grep -Eqi '(delet|destr|force-push)[^.]*explicit authorization' <<< "$governed_text" || records_ok=0
grep -Eqi 'recoverab' <<< "$governed_text" || records_ok=0
# narrower task wording never dodges a contract; the routing intro owns that rule
grep -Eqi 'narrow[a-z]*[^.]*wording' <<< "$skill_text" || records_ok=0
# fork scripts are deleted, and later passes review the chosen option rather than choosing it
grep -Eqi 'delete[^.]*script' <<< "$governed_text" || records_ok=0
grep -Eqi '(critique|simplifier)[^.]*never choose' <<< "$governed_text" || records_ok=0
# the profile owns permitted behavior changes; covering tests re-run after edits
grep -Eqi 'profile[^.]*owns[^.]*behavior' <<< "$governed_text" || records_ok=0
grep -Eqi 're-?run[^.]*covering tests' <<< "$governed_text" || records_ok=0
report "$records_ok" \
  "governed work owns the notebook field set, explicit destruction, and simplifier mechanics" \
  "governed work must own the notebook entry field set, require explicit narrowly-targeted destruction with recoverability stated, forbid task-wording dodges, delete fork scripts, keep later passes from choosing the option, and defer cleanup boundaries to the profile with covering tests re-run"

# --- 3d. adoption mode assesses an existing repository before changing it ---
adoption_section="$(section '^## Adopting an existing repository$' '^## ' < "$ROOT/SKILL.md")"
adoption_text="$(flat <<< "$adoption_section")"
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
# host-integration items cite the detection-first legacy-artifact report prerequisites.md owns
grep -Eqi 'legacy[^.]*prerequisites\.md' <<< "$adoption_text" || adoption_ok=0
# the review changes nothing; adoption work still passes through the gates
grep -Eqi 'change nothing|changes? nothing|read-only' <<< "$adoption_text" || adoption_ok=0
grep -Eqi 'gate' <<< "$adoption_text" || adoption_ok=0
# it stays choreography rather than a second copy of the contracts
[[ "$(grep -c . <<< "$adoption_section")" -le 20 ]] || adoption_ok=0
report "$adoption_ok" \
  "adoption mode assesses each contract with evidence before any gated migration" \
  "adoption mode must walk floor and references with evidence, change nothing, and defer to the gates"

# --- 3e. completion verifies interfaces, inspects artifacts, checks git state, and refuses unwaived gates ---
completion_section="$(section '^## Completion$' '^## ' < "$ROOT/SKILL.md")"
completion_text="$(flat <<< "$completion_section")"
completion_ok=1
[[ -n "$completion_text" ]] || completion_ok=0
# the repository's own interfaces run first
grep -Eqi 'format[a-z]*[^.]*lint[^.]*test' <<< "$completion_text" || completion_ok=0
# artifacts are inspected; exit codes are not evidence
grep -Eqi 'exit (code|status)' <<< "$completion_text" || completion_ok=0
# git state is checked with raw inputs and unrelated work unchanged
grep -Fq 'git status' <<< "$completion_text" || completion_ok=0
grep -Eqi 'raw' <<< "$completion_text" || completion_ok=0
grep -Eqi 'unrelated work' <<< "$completion_text" || completion_ok=0
# the report names skips and boundaries and requires the real smoke test
grep -Eqi 'skipped and why' <<< "$completion_text" || completion_ok=0
grep -Eqi 'boundar' <<< "$completion_text" || completion_ok=0
grep -Eqi 'smoke test' <<< "$completion_text" || completion_ok=0
# an unresolved gate blocks completion unless it was waived and recorded
grep -Eqi 'waiv[a-z]*[^.]*record|record[a-z]*[^.]*waiv' <<< "$completion_text" || completion_ok=0
report "$completion_ok" \
  "completion verifies interfaces, inspects artifacts over exit codes, checks git state, reports boundaries, and refuses unwaived gates" \
  "completion must run repository interfaces, inspect artifacts over exit codes, check git status with raw inputs and unrelated work unchanged, report skips and boundaries, require the smoke test, and refuse unwaived gates"

# --- 3f. autonomy, scope, reference reading, and whole-task reporting ---
autonomy_ok=1
# the named gates and consultation points are the only stops; a stated step is carried out
grep -Eqi '(gates?|consultation points?)[^.]*only[^.]*stop' <<< "$governed_text" || autonomy_ok=0
grep -Eqi '(stated|announced|described)[^.]*step[^.]*(undone|unfinished)' <<< "$governed_text" ||
  autonomy_ok=0
# a run's length or the clock never hands part of the job back
grep -Eqi 'complete[^.]*authorized step[^.]*long run' <<< "$governed_text" || autonomy_ok=0
# a blocker needs a failed attempt in this session, never an assumption
grep -Eqi 'assumed limit[^.]*not a (stop|blocker)' <<< "$governed_text" || autonomy_ok=0
grep -Eqi 'blocker[^.]*only after[^.]*attempt fails' <<< "$governed_text" || autonomy_ok=0
# a mid-task question waits until the independent work is done
grep -Eqi '(does not|not|independent of)[^.]*depend[^.]*answer' <<< "$governed_text" || autonomy_ok=0
# the existing stop rules stay intact
grep -Eqi 'either is unclear, stop and ask' <<< "$governed_text" || autonomy_ok=0
grep -Eqi 'one question at a time' <<< "$skill_text" || autonomy_ok=0
# change discipline scopes fixes and tests to the task
discipline_text="$(section '^### Change discipline$' '^##' < "$ROOT/SKILL.md" | flat)"
grep -Eqi '(pre-existing|unrelated) bug' <<< "$discipline_text" || autonomy_ok=0
grep -Eqi 'follow-up[^.]*completion report|completion report[^.]*follow-up' <<< "$discipline_text" ||
  autonomy_ok=0
grep -Eqi '(not|never) fix[^.]*unless[^.]*cannot work' <<< "$discipline_text" || autonomy_ok=0
grep -Eqi 'tests? only where' <<< "$discipline_text" || autonomy_ok=0
grep -Eqi 'neighbou?ring test' <<< "$discipline_text" || autonomy_ok=0
grep -Eqi '(never|not) commit[^.]*scratch|scratch[^.]*(never|not) commit' <<< "$discipline_text" ||
  autonomy_ok=0
# familiarity never skips a reference; the routing intro owns that rule
routing_intro="$(section '^## Reference routing$' '^\|' < "$ROOT/SKILL.md" | flat)"
grep -Eqi 'familiar[a-z]*[^.]*(not|never)[^.]*(skip|reason)' <<< "$routing_intro" || autonomy_ok=0
grep -Eqi '(this|the current) session' <<< "$routing_intro" || autonomy_ok=0
# the completion report covers the whole task and stands alone
grep -Eqi 'whole task' <<< "$completion_text" || autonomy_ok=0
grep -Eqi 'stands? on its own|saw nothing else' <<< "$completion_text" || autonomy_ok=0
grep -Eqi 'verified and how' <<< "$completion_text" || autonomy_ok=0
# the whole-task scenario stays pinned with its refusal anchors
grep -Fq '## Scenario L — authorized whole task' "$ROOT/tests/skill_pressure_scenarios.md" || autonomy_ok=0
grep -Eqi 'never end the turn with a described next step' "$ROOT/tests/skill_pressure_scenarios.md" ||
  autonomy_ok=0
report "$autonomy_ok" \
  "governed work stops only at named gates, scopes fixes and tests to the task, reads references each session, and reports the whole task" \
  "governed work must stop only at named gates and consultation points, carry out stated steps, report unrelated bugs as follow-ups, scope tests to repository practice, forbid familiarity as a reason to skip a reference, and cover the whole task in the completion report"

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
report "$integration_docs_ok" \
  "bootstrap and README expose only the live skill-native integration path" \
  "bootstrap and README must resolve the skill, name both host profile outputs, and require host smoke testing"

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
report "$stale_surface_ok" \
  "production surface contains no stale vendoring, version, or generic-profile terminology" \
  "production surface must contain no stale vendoring, version, or generic-profile terminology"

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
report "$readme_surface_ok" \
  "README documents host outputs and detection-first legacy cleanup" \
  "README must document host outputs and detection-first legacy cleanup"

# the detection procedure itself lives in prerequisites.md: path, resolved path, customized or not
if grep -Eqi 'legacy policy' "$ROOT/references/prerequisites.md" &&
  grep -Eqi 'resolves to[^.]*customized' "$ROOT/references/prerequisites.md"; then
  pass "prerequisites own detection-first legacy artifact reporting"
else
  fail "prerequisites must own detection-first legacy artifact reporting"
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
report "$snakemake_surface_ok" \
  "skill surfaces route Snakemake orchestration consistently" \
  "skill surfaces must route Snakemake orchestration consistently"

bootstrap_integration_section="$(section '^## Selected host integration$' '^## ' < "$ROOT/references/bootstrap.md")"
bootstrap_integration_text="$(flat <<< "$bootstrap_integration_section")"
bootstrap_source_ok=1
# The bootstrap reference routes to the owner instead of repeating its source rules.
grep -Fq 'references/prerequisites.md' <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
grep -Eqi 'selected[^.]*research-code-simplifier' <<< "$bootstrap_integration_text" || bootstrap_source_ok=0
grep -Eqi 'provenance-verified.*(skill )?source' \
  "$ROOT/references/prerequisites.md" || bootstrap_source_ok=0
grep -Fq 'agents/research-code-simplifier.md' "$ROOT/references/prerequisites.md" || bootstrap_source_ok=0
grep -Eqi 'only the selected host[^.]*profile' \
  "$ROOT/references/prerequisites.md" || bootstrap_source_ok=0
report "$bootstrap_source_ok" \
  "bootstrap derives the host profile from the provenance-verified canonical source" \
  "bootstrap must derive only the selected host profile from the provenance-verified canonical source"

# --- 8. bootstrap delegates host prerequisites to their owner ---
if grep -qs 'references/prerequisites\.md' "$ROOT/references/bootstrap.md"; then
  pass "bootstrap delegates host prerequisites"
else
  fail "bootstrap delegates host prerequisites"
fi

# --- 9. bootstrap questions and runtime contracts remain explicit ---
bootstrap_contract_ok=1
interview_section="$(section '^### Interview$' '^## ' < "$ROOT/SKILL.md")"
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
# the interview topics stay separately numbered questions, whatever their wording
for numbered_topic in \
  '^[0-9]+\. [^?]*identity' \
  '^[0-9]+\. [^?]*research question' \
  '^[0-9]+\. [^?]*exploratory' \
  '^[0-9]+\. [^?]*license' \
  '^[0-9]+\. [^?]*dataset' \
  '^[0-9]+\. [^?]*workflow stage' \
  '^[0-9]+\. [^?]*(container|non-Python)' \
  '^[0-9]+\. [^?]*public CI' \
  '^[0-9]+\. [^?]*journal'; do
  grep -Eqi "$numbered_topic" <<< "$interview_section" || bootstrap_contract_ok=0
done
# the workflow-stage question elicits whether any stage needs randomness
interview_text="$(flat <<< "$interview_section")"
grep -Eqi 'workflow stage[^?]*randomness' <<< "$interview_text" || bootstrap_contract_ok=0
if grep -Eqi 'identity[^.?]*,[^.?]*research question' <<< "$interview_section"; then
  bootstrap_contract_ok=0
fi
grep -Fq '### Bootstrap execution record' "$ROOT/SKILL.md" || bootstrap_contract_ok=0
# planning before answers exist reproduces the record with pending fields and asks one question
grep -Eqi 'reproduc[^.]*record[^.]*pending' <<< "$skill_text" || bootstrap_contract_ok=0
grep -Eqi 'exactly one[^.]*question' <<< "$skill_text" || bootstrap_contract_ok=0
grep -Eqi 'gate-artifact' <<< "$skill_text" || bootstrap_contract_ok=0

# the execution record stays a compact checklist of the failure modes under pressure
bootstrap_record="$(section '^### Bootstrap execution record$' < "$ROOT/SKILL.md" | section '^```text$' '^```$')"
bootstrap_record_text="$(flat <<< "$bootstrap_record")"
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
record_gate_slot="$(section '^Gate:' '^[A-Za-z][A-Za-z ]*:' 1 <<< "$bootstrap_record" | flat)"
for gate_slot_pattern in \
  'design approval|approved[^;]*design' \
  'gate-artifact' \
  'commit[a-z]*[^;]*(specification|spec)|specification[^;]*commit' \
  'review' \
  'plan'; do
  grep -Eqi "$gate_slot_pattern" <<< "$record_gate_slot" || bootstrap_contract_ok=0
done
# the boundaries slot owns reporting assumptions and manual or external boundaries
record_boundaries_slot="$(section '^Boundaries:' '^[A-Za-z][A-Za-z ]*:' 1 <<< "$bootstrap_record" | flat)"
grep -Eqi 'boundar' <<< "$record_boundaries_slot" || bootstrap_contract_ok=0
grep -Eqi 'assumption' <<< "$record_boundaries_slot" || bootstrap_contract_ok=0
# a separate completion slot binds inspecting real generated artifacts to claiming completion
record_completion_slot="$(section '^Completion:' '^[A-Za-z][A-Za-z ]*:' 1 <<< "$bootstrap_record" | flat)"
grep -Eqi 'inspect' <<< "$record_completion_slot" || bootstrap_contract_ok=0
grep -Eqi 'inspect[a-z]*[^;]*complet|complet[^;]*inspect' <<< "$record_completion_slot" ||
  bootstrap_contract_ok=0
# the scaffold slot names R explicitly rather than a generic runtime category
record_scaffold_slot="$(section '^Scaffold:' '^[A-Za-z][A-Za-z ]*:' 1 <<< "$bootstrap_record" | flat)"
grep -Eq 'no unapproved R support' <<< "$record_scaffold_slot" || bootstrap_contract_ok=0
# the numbered sequence itself ends with the artifact-inspection and reporting step
bootstrap_step_ten="$(section '^10\. ' '^[0-9]+\. ' 1 <<< "$bootstrap_sequence_section" | flat)"
grep -Eqi 'inspect' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
grep -Eqi 'generated artifacts' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
grep -Eqi 'exit codes[^.]*alone[^.]*artifacts' <<< "$completion_text" || bootstrap_contract_ok=0
grep -Eqi 'boundar' <<< "$bootstrap_step_ten" || bootstrap_contract_ok=0
# the smoke-test step defers unavailable-host reporting to the prerequisite reference that owns it
bootstrap_step_nine="$(section '^9\. ' '^[0-9]+\. ' 1 <<< "$bootstrap_sequence_section" | flat)"
grep -Fq 'references/prerequisites.md' <<< "$bootstrap_step_nine" &&
  grep -Eqi 'unavailable[^.]*manual boundar' <<< "$bootstrap_step_nine" ||
  bootstrap_contract_ok=0
# the numbered interview above owns topic coverage; the record must not restate it
if grep -Eqi 'identity/purpose|research question/intended claim|supported Python minor' \
  <<< "$bootstrap_record_text"; then
  bootstrap_contract_ok=0
fi
# Prerequisites owns installation details and all three real-host checks.
for required in 'agents/research-code-simplifier.md' 'only the selected host' 'launch the profile'; do
  grep -Fq "$required" "$ROOT/references/prerequisites.md" || bootstrap_contract_ok=0
done
grep -Fq 'references/prerequisites.md' <<< "$bootstrap_sequence_section" || bootstrap_contract_ok=0
grep -Fq 'target-version = "py3XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'python-version = "3.XY"' "$ROOT/references/bootstrap.md" || bootstrap_contract_ok=0
grep -Fq 'uv init --package --build-backend hatch' "$ROOT/references/bootstrap.md" ||
  bootstrap_contract_ok=0
grep -Fq 'coverage' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
grep -Eq '^test-r:' "$ROOT/references/bootstrap.md" && bootstrap_contract_ok=0
report "$bootstrap_contract_ok" \
  "bootstrap interview, placeholders, and runtime contracts are explicit" \
  "bootstrap interview, placeholders, and runtime contracts are explicit"

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
report "$workflow_scaffold_ok" \
  "bootstrap scaffold owns the Snakemake workflow layout behind the Make interface" \
  "bootstrap scaffold must own the Snakemake workflow layout behind the Make interface"

# the CI configuration is part of the core scaffold, with a fixed job order and no raw-data access
ci_section="$(section '^## Continuous integration$' '^## ' < "$ROOT/references/bootstrap.md")"
ci_text="$(flat <<< "$ci_section")"
ci_scaffold_ok=1
grep -Fq 'ci.yml' "$ROOT/references/bootstrap.md" || ci_scaffold_ok=0
grep -Eqi 'core scaffold' <<< "$ci_text" || ci_scaffold_ok=0
grep -Eq 'uv lock --check.*uv sync --locked.*pre-commit run.*ty check.*make test' <<< "$ci_text" ||
  ci_scaffold_ok=0
grep -Eqi 'question 11' <<< "$ci_text" || ci_scaffold_ok=0
grep -Eqi 'boundar' <<< "$ci_text" || ci_scaffold_ok=0
grep -Eqi 'never reads[^.]*data/raw/|data/raw/[^.]*never' <<< "$ci_text" || ci_scaffold_ok=0
report "$ci_scaffold_ok" \
  "bootstrap scaffold owns the CI configuration with a fixed job order" \
  "bootstrap must scaffold CI running lock check, locked sync, pre-commit, ty, and tests in order, keep external steps as README boundaries, and never read raw data"

# the ignore policy has one owner: fixed entry set, explicit un-ignore, registered fixtures, results/ tracked
ignore_section="$(section '^## Ignore policy$' '^## ' < "$ROOT/references/bootstrap.md")"
ignore_text="$(flat <<< "$ignore_section")"
ignore_policy_ok=1
grep -Fq '.gitignore' <<< "$ignore_text" || ignore_policy_ok=0
for ignored in '.env' 'tmp/' 'logs/' '.venv/' '.snakemake/' 'data/'; do
  grep -Fq "$ignored" <<< "$ignore_text" || ignore_policy_ok=0
done
grep -Eqi 'negation' <<< "$ignore_text" || ignore_policy_ok=0
grep -Fq 'config/datasets.yaml' <<< "$ignore_text" || ignore_policy_ok=0
grep -Eqi 'large-file' <<< "$ignore_text" || ignore_policy_ok=0
grep -Eqi '(LFS|DVC)[^.]*approved design' <<< "$ignore_text" || ignore_policy_ok=0
grep -Eqi 'results/[^.]*not ignored' <<< "$ignore_text" || ignore_policy_ok=0
report "$ignore_policy_ok" \
  "bootstrap owns the ignore policy with explicit un-ignore and registered fixtures" \
  "bootstrap must own a fixed gitignore entry set, un-ignore fixtures by explicit negation and register them, gate LFS or DVC on the approved design, and keep results/ tracked"

rule_logging_section="$(section '^## Rule logging$' '^## ' < "$ROOT/references/bootstrap.md")"
rule_logging_text="$(flat <<< "$rule_logging_section")"
logging_ownership_ok=1
grep -Fq 'params.log_level' <<< "$rule_logging_section" || logging_ownership_ok=0
grep -Eqi "declared in the rule.+params" <<< "$rule_logging_text" || logging_ownership_ok=0
grep -Eqi 'never source logging verbosity from the environment' \
  <<< "$rule_logging_text" || logging_ownership_ok=0
if grep -Fq 'os.environ.get("LOG_LEVEL"' <<< "$rule_logging_section"; then
  logging_ownership_ok=0
fi
report "$logging_ownership_ok" \
  "rule logging receives its classified operational setting explicitly" \
  "rule logging must not create an environment-owned operational setting"

# the R snippet receives the log path and level from the rule, never hardcoded values
r_runtime_section="$(section '^## Conditional external runtimes$' '^## ' < "$ROOT/references/bootstrap.md")"
r_runtime_text="$(flat <<< "$r_runtime_section")"
r_logging_ok=1
grep -Fq 'log_appender(appender_tee(log_path))' <<< "$r_runtime_text" || r_logging_ok=0
grep -Fq 'log_threshold(log_level)' <<< "$r_runtime_text" || r_logging_ok=0
grep -Eqi 'log:[^.]*params:' <<< "$r_runtime_text" || r_logging_ok=0
grep -Eq 'log_threshold\("|appender_tee\("' <<< "$r_runtime_text" && r_logging_ok=0
report "$r_logging_ok" \
  "R rule logging takes its log path and level from the rule" \
  "the R logging snippet must take the log path from log: and log_level from params:, never hardcoded values"

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
grep -Eqi 'independent[^.]*simplifier[^.]*resolution|independently resolve[^.]*simplifier' <<< "$skill_text" || final_review_contract_ok=0
grep -Eqi 'blocked' <<< "$skill_text" || final_review_contract_ok=0
report "$final_review_contract_ok" \
  "final-review ownership corrections stay aligned" \
  "final-review ownership corrections stay aligned"

# --- 11. every reference owns one complete, focused domain contract ---
prerequisites_text="$(flat < "$ROOT/references/prerequisites.md")"
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
report "$host_profile_instruction_ok" \
  "prerequisite reference owns deriving each host profile from the canonical profile" \
  "prerequisite reference must tell the agent to derive only the selected host profile from the canonical profile"

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

configuration_decision_section="$(section '^## Ownership decision$' '^## ' < "$ROOT/references/configuration.md")"
configuration_decision_text="$(flat <<< "$configuration_decision_section")"
configuration_precedence_ok=1
grep -Eqi 'first matching.*mutually exclusive|mutually exclusive.*first matching' \
  <<< "$configuration_decision_text" || configuration_precedence_ok=0
# each numbered bucket carries its own terms; order inside a bucket is free
bucket() {
  awk -v n="$1" '$0 ~ "^" n "\\. " { c = 1; print; next } c && /^[0-9]\. / { exit } c { print }' \
    <<< "$configuration_decision_section" | flat
}
for term in credentials secrets machine-specific 'GPU selection' 'environment variable'; do
  grep -Fqi "$term" <<< "$(bucket 1)" || configuration_precedence_ok=0
done
for term in derived paths.py; do
  grep -Fqi "$term" <<< "$(bucket 2)" || configuration_precedence_ok=0
done
for term in datasets.yaml; do
  grep -Fqi "$term" <<< "$(bucket 3)" || configuration_precedence_ok=0
done
for term in researcher-editable scientific operational analysis.yaml; do
  grep -Fqi "$term" <<< "$(bucket 4)" || configuration_precedence_ok=0
done
for term in implementation constant; do
  grep -Fqi "$term" <<< "$(bucket 5)" || configuration_precedence_ok=0
done
report "$configuration_precedence_ok" \
  "configuration classifier uses exclusive environment-paths-YAML-code precedence" \
  "configuration classifier must keep sensitive, derived, editable, and code buckets exclusive"

# the established-repository migration pins behavior before relocating and maps gates through SKILL.md
migration_section="$(section '^## Established repositories$' '^## ' < "$ROOT/references/configuration.md")"
migration_text="$(flat <<< "$migration_section")"
migration_ok=1
grep -Eqi 'adoption-mode' <<< "$migration_text" || migration_ok=0
grep -Eqi 'tests[^.]*before relocat' <<< "$migration_text" || migration_ok=0
grep -Eqi '(must|does) not change any effective value' <<< "$migration_text" || migration_ok=0
grep -Eqi 'gate[^.]*SKILL\.md' <<< "$migration_text" || migration_ok=0
grep -Fq 'docs/LAB_NOTEBOOK.md' <<< "$migration_text" || migration_ok=0
grep -Eqi 'six-step' "$ROOT/references/configuration.md" && migration_ok=0
report "$migration_ok" \
  "configuration migration pins tests before relocation and routes value changes through SKILL.md gates" \
  "configuration migration must apply in adoption mode, pin behavior with tests before relocating, keep effective values unchanged, and route intentional changes through SKILL.md gates"

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
report "$snakemake_config_ok" \
  "configuration contract owns Snakemake-native loading, override guard, and provenance edges" \
  "configuration contract must own Snakemake-native loading, override guard, and provenance edges"

# each contract keeps one owner: bootstrap and analysis defer instead of restating
dedupe_ok=1
bootstrap_configuration_section="$(section '^## Configuration$' '^## ' < "$ROOT/references/bootstrap.md")"
bootstrap_configuration_text="$(flat <<< "$bootstrap_configuration_section")"
grep -Fq 'references/configuration.md' <<< "$bootstrap_configuration_text" || dedupe_ok=0
grep -Fq '.env.example' <<< "$bootstrap_configuration_text" || dedupe_ok=0
# the ownership buckets themselves belong to references/configuration.md
if grep -Eqi 'versioned YAML|implementation constants|classify those buckets|remain in code' \
  <<< "$bootstrap_configuration_text"; then
  dedupe_ok=0
fi
# the scratch-location rule belongs to the Ignore policy section, not Configuration
grep -Fq 'tmp/' <<< "$bootstrap_configuration_text" && dedupe_ok=0
# references/prerequisites.md owns skill provenance; analysis.md names only the exact skill
grep -Fq 'scientific-critical-thinking' "$ROOT/references/analysis.md" || dedupe_ok=0
if grep -Eqi 'k-dense-ai|scientific-agent-skills' "$ROOT/references/analysis.md"; then
  dedupe_ok=0
fi
grep -Eqi 'scientific-agent-skills' "$ROOT/references/prerequisites.md" || dedupe_ok=0
report "$dedupe_ok" \
  "bootstrap defers configuration ownership and analysis defers skill provenance" \
  "bootstrap must defer configuration ownership and analysis must defer skill provenance"

data_checksum_text="$(flat < "$ROOT/references/data.md")"
data_checksum_ok=1
# checksums are an optional registry field, verified against a published digest where one exists
grep -Eqi 'optional[^.]*checksum|checksum[^.]*optional' <<< "$data_checksum_text" || data_checksum_ok=0
grep -Fq 'published digest' <<< "$data_checksum_text" || data_checksum_ok=0
# a dataset without a checksum still validates; local raw data never needs one
grep -Eqi 'not a validation failure' <<< "$data_checksum_text" || data_checksum_ok=0
grep -Fq 'machine-readable data dictionary' "$ROOT/references/data.md" || data_checksum_ok=0
report "$data_checksum_ok" \
  "data reference keeps checksums optional and owns machine-readable dictionaries" \
  "data reference must keep checksums optional and own machine-readable dictionaries"

if grep -Fq '## Analysis-plan template' "$ROOT/references/analysis.md"; then
  pass "analysis reference owns the complete analysis-plan template"
else
  fail "analysis reference must own the complete analysis-plan template"
fi

figures_text="$(flat < "$ROOT/references/figures.md")"
figures_contract_ok=1
grep -Eqi 'visually inspect[^.]*SVG[^.]*PDF' <<< "$figures_text" || figures_contract_ok=0
grep -Fq 'nature-figure' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'before planning a figure' <<< "$figures_text" || figures_contract_ok=0
# exploratory or deadline framing changes approval speed, not the required contract and exports
grep -Eqi 'figure work regardless of framing' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'exploratory' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'four required export formats' <<< "$figures_text" || figures_contract_ok=0
# figure data carries the observations behind summary marks, not the summary alone
grep -Eqi 'individual observations' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'not the summary alone' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'estimate[^.]*uncertainty[^.]*`n`' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'finest permitted aggregate' <<< "$figures_text" || figures_contract_ok=0
# color maps match the data structure; rainbow stays banned
grep -Eqi 'perceptually uniform' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'diverging[^.]*midpoint' <<< "$figures_text" || figures_contract_ok=0
grep -Eqi 'never[^.]*rainbow|rainbow[^.]*never|no rainbow' <<< "$figures_text" || figures_contract_ok=0
# the obligation stays prose; no echoed preflight template
if grep -Eqi 'Figure contract source loaded|Figure skill invoked' <<< "$figures_text"; then
  figures_contract_ok=0
fi
report "$figures_contract_ok" \
  "figure reference requires its own load and nature-figure without an echo template" \
  "figure reference must require loading itself and nature-figure in prose, with no preflight echo"

# the analysis reference owns uncertainty reporting, batched independent critique, and leakage checks
analysis_text="$(flat < "$ROOT/references/analysis.md")"
analysis_contract_ok=1
grep -Eqi 'effect estimate[^.]*uncertainty' <<< "$analysis_text" || analysis_contract_ok=0
grep -Eqi 'p-value alone is insufficient' <<< "$analysis_text" || analysis_contract_ok=0
grep -Eqi 'one design or coherent batch' <<< "$analysis_text" || analysis_contract_ok=0
grep -Eqi 'independent agent, separate from the implementing agent' <<< "$analysis_text" ||
  analysis_contract_ok=0
grep -Eqi 'without implementing the task' <<< "$analysis_text" || analysis_contract_ok=0
grep -Fq 'Review waivers' <<< "$analysis_text" &&
  grep -Eqi 'self-pass never substitutes' <<< "$governed_text" || analysis_contract_ok=0
grep -Eqi 'only the data permitted by the training design' <<< "$analysis_text" ||
  analysis_contract_ok=0
report "$analysis_contract_ok" \
  "analysis reference owns uncertainty reporting, batched independent critique, and training-leakage checks" \
  "analysis reference must own uncertainty reporting, batched independent critique, and training-leakage checks"

# the figure reference pins the Python backend and the 600 dpi TIFF export
figures_backend_ok=1
grep -Eqi 'Python is the plotting backend' <<< "$figures_text" || figures_backend_ok=0
grep -Eqi '(do not|never) switch languages' <<< "$figures_text" || figures_backend_ok=0
grep -Eqi '600 ?dpi' <<< "$figures_text" || figures_backend_ok=0
report "$figures_backend_ok" \
  "figure reference pins the Python backend and 600 dpi TIFF export" \
  "figure reference must pin the Python backend and 600 dpi TIFF export"

# the prerequisite reference owns host-native resolution, authorized recovery, and one writing-plans resolution
prerequisites_resolution_ok=1
grep -Eqi 'authorization before[^.]*recovery' <<< "$prerequisites_text" ||
  prerequisites_resolution_ok=0
planning_companion_text="$(section '^## Shared planning companion$' '^## ' < "$ROOT/references/prerequisites.md" | flat)"
grep -Eqi 'preflight-resolved[^.]*writing-plans' <<< "$planning_companion_text" ||
  prerequisites_resolution_ok=0
grep -Eqi 're-?resolv|resolv[^.]*again|at planning time' <<< "$planning_companion_text" &&
  prerequisites_resolution_ok=0
smoke_test_text="$(section '^## Selected-host smoke test$' '^## ' < "$ROOT/references/prerequisites.md" | flat)"
grep -Eqi 'unavailable[^.]*(manual[^.]*boundar)[^.]*(not|never)[^.]*simulat' <<< "$smoke_test_text" ||
  prerequisites_resolution_ok=0
grep -Eqi 'unavailable[^.]*recovery' <<< "$smoke_test_text" || prerequisites_resolution_ok=0
simulation_rule_copies="$(
  grep -HnEi 'simulat' "$ROOT/SKILL.md" "$ROOT/README.md" "$ROOT"/references/*.md \
    "$ROOT"/agents/*.md 2> /dev/null | grep -c . || true
)"
[[ "$simulation_rule_copies" == 1 ]] || prerequisites_resolution_ok=0
report "$prerequisites_resolution_ok" \
  "prerequisite reference owns host-native resolution and authorized recovery" \
  "prerequisite reference must own host-native resolution, authorized recovery, the single manual-boundary rule for an unavailable host, and a single preflight resolution of writing-plans"

# the data reference keeps the registry mandatory and validation free of implicit correction
data_registry_ok=1
grep -Eqi 'datasets\.yaml[^.]*mandatory' <<< "$data_checksum_text" || data_registry_ok=0
grep -Eqi 'no implicit correction' <<< "$data_checksum_text" || data_registry_ok=0
report "$data_registry_ok" \
  "data reference keeps the registry mandatory and validation correction-free" \
  "data reference must keep the registry mandatory and validation correction-free"

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

# identifiers cover supplementary and slotless figures; assembly exports the composite under the identifier stem
figure_identifier_ok=1
grep -Fq 'supplementary_figure_<n>' "$figure_owner" || figure_identifier_ok=0
grep -Fq 'sf1_{short_descriptive_name}' "$figure_owner" || figure_identifier_ok=0
grep -Fq 'fig_<short_descriptive_name>' "$figure_owner" || figure_identifier_ok=0
grep -Eqi 'slot[^.]*rename|rename[^.]*slot' <<< "$figures_text" || figure_identifier_ok=0
assembly_text="$(section '^## Assembly$' '^## ' < "$figure_owner" | flat)"
grep -Eqi 'after all atomic panel' <<< "$assembly_text" || figure_identifier_ok=0
grep -Eqi 'never redraw' <<< "$assembly_text" || figure_identifier_ok=0
grep -Eqi 'figure identifier as[^.]*stem' <<< "$assembly_text" || figure_identifier_ok=0
grep -Fq 'main_figure_1/svg/main_figure_1.svg' <<< "$assembly_text" || figure_identifier_ok=0
report "$figure_identifier_ok" \
  "figure reference names every figure class and owns assembly output" \
  "figure reference must define supplementary and slotless identifiers and own assembly order, panel reuse, and the composite stem"

figure_duplicates="$(
  grep -HnE 'mf[0-9]+_|edf[0-9]+_|sf[0-9]+_|short_descriptive_name|hazard_ratio_distribution' \
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
governed_record="$(section '^### Governed-work invocation record$' < "$ROOT/SKILL.md" | section '^```text$' '^```$')"
governed_record_text="$(flat <<< "$governed_record")"
for required in 'research-repo-standard' 'host-native resolver' 'provenance' 'invoked'; do
  grep -Fqi "$required" <<< "$governed_record_text" || governed_resolution_ok=0
done
report "$governed_resolution_ok" \
  "governed work records exact standard resolution and invocation before classification" \
  "governed work must record exact standard resolution and invocation before classification"

simplifier_resolution_ok=1
simplifier_record="$(section '^### Simplifier review$' < "$ROOT/SKILL.md" | section '^```text$' '^```$')"
simplifier_record_text="$(flat <<< "$simplifier_record")"
for required in 'research-code-simplifier' 'host-native resolver' 'profile path' 'invoked'; do
  grep -Fqi "$required" <<< "$simplifier_record_text" || simplifier_resolution_ok=0
done
report "$simplifier_resolution_ok" \
  "delegated simplifier adds exact host-native profile resolution and invocation" \
  "delegated simplifier must add exact host-native profile resolution and invocation"

# --- 15. evaluation records retain scores, provenance, and verification limits ---
pressure_results_text="$(section '^## GREEN results$' < "$ROOT/tests/skill_pressure_scenarios.md" | flat)"
pressure_evidence_ok=1
for pattern in '[0-9]+/[0-9]+' 'rubrics[^.]*hidden' 'RED' 'manual verification boundar' 'blob/[0-9a-f]{40}/tests/skill_pressure_scenarios.md'; do
  grep -Eqi "$pattern" <<< "$pressure_results_text" || pressure_evidence_ok=0
done
report "$pressure_evidence_ok" \
  "pressure evidence records scores, hidden rubrics, archived provenance, and host boundaries" \
  "pressure evidence must retain scores, hidden-rubric context, archived provenance, and honest host boundaries"

# --- 15a. the Snakemake pressure scenarios stay pinned ---
snakemake_scenarios_ok=1
for heading in \
  '## Scenario E — logic in a rule body' \
  '## Scenario F — quick config override' \
  '## Scenario G — environment-sourced setting'; do
  grep -Fq "$heading" "$ROOT/tests/skill_pressure_scenarios.md" || snakemake_scenarios_ok=0
done
report "$snakemake_scenarios_ok" \
  "pressure scenarios cover Snakemake rule, override, and environment contracts" \
  "pressure scenarios must cover Snakemake rule, override, and environment contracts"

# --- bounded cleanup, authorized replacement, and shared review waivers ---
cleanup_text="$(flat < "$ROOT/agents/research-code-simplifier.md")"
cleanup_ok=1
grep -Eqi 'light path.*simplifier profile' <<< "$gate_text" || cleanup_ok=0
for concept in 'supported' 'callers' 'private' 'unsupported' 'public' 'scientific' 'behavior difference'; do
  grep -Fqi "$concept" <<< "$cleanup_text" || cleanup_ok=0
done
grep -Eqi 'may (remove|change)[^.]*unused' <<< "$cleanup_text" || cleanup_ok=0
grep -Eqi '(unknown|uncertain)[^.]*leave|leave[^.]*(unknown|uncertain)' <<< "$cleanup_text" || cleanup_ok=0
if grep -Eqi 'preserve behavior exactly|preserving exact behavior|each before is the same behavior' <<< "$cleanup_text"; then
  cleanup_ok=0
fi
report "$cleanup_ok" \
  "simplifier allows evidenced private cleanup while preserving supported and scientific contracts" \
  "simplifier must bound behavior changes by supported callers and report differences without claiming universal equivalence"

replacement_ok=1
# Destruction owns the exception; the no-gate path references it.
grep -Eqi 'authorized regeneration[^.]*covers[^.]*replacement[^.]*declared outputs' <<< "$governed_text" || replacement_ok=0
grep -Eqi '(another|additional|second)[^.]*confirmation' <<< "$governed_text" || replacement_ok=0
grep -Eqi 'failed run[^.]*preserv[^.]*existing' <<< "$skill_text" || replacement_ok=0
report "$replacement_ok" \
  "authorized regeneration includes transactional replacement of declared outputs" \
  "regeneration must reuse authorization only for declared outputs and preserve existing output on failure"

waiver_text="$(section '^### Review waivers$' '^##' < "$ROOT/SKILL.md" | flat)"
waiver_ok=1
for concept in 'scientific critique' 'simplifier' 'fails' 'this session' 'explicit' 'scope' 'completion report' 'docs/LAB_NOTEBOOK.md' 'smoke test'; do
  grep -Fqi "$concept" <<< "$waiver_text" || waiver_ok=0
done
for ref in analysis prerequisites; do
  grep -Fq 'Review waivers' "$ROOT/references/$ref.md" || waiver_ok=0
done
grep -Eqi 'never[^.]*validation|not[^.]*validation' <<< "$waiver_text" || waiver_ok=0
report "$waiver_ok" \
  "one waiver procedure covers failed scientific and simplifier reviews without relaxing checks" \
  "SKILL.md must own scoped failure-only review waivers with records and honest verification boundaries"

# --- final ---
if ((FAILS > 0)); then
  echo "$FAILS test(s) failed"
  exit 1
fi
echo "all consistency tests passed"
