#!/usr/bin/env bash
# Structural and semantic-presence checks, not a substitute for blind behavioral evaluation.
# RRS_TEST_ROOT is used only by isolated source-snapshot mutation tests.
set -u
ROOT="${RRS_TEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FAILS=0
pass() { printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }
flat() { tr '\n' ' ' < "$ROOT/$1" | tr -s '[:space:]' ' '; }
require() {
  local id="$1" file="$2" body pattern matched=1
  shift 2
  if [[ ! -f "$ROOT/$file" ]]; then fail "$id (missing $file)"; return; fi
  body="$(flat "$file")"
  for pattern in "$@"; do
    if ! grep -Eqi -- "$pattern" <<< "$body"; then
      printf '  missing meaning anchor in %s: %s\n' "$file" "$pattern"
      matched=0
    fi
  done
  if ((matched)); then pass "$id"; else fail "$id"; fi
}
forbid() {
  local id="$1" file="$2" pattern="$3"
  if grep -Eqi -- "$pattern" <<< "$(flat "$file")"; then fail "$id"; else pass "$id"; fi
}
# An owner can route to another procedure without duplicating its detailed grammar.
owned() {
  local id="$1" owner="$2" pattern="$3" file duplicates=0
  for file in AGENTS.md README.md SKILL.md references/*.md agents/*.md; do
    [[ "$file" == "$owner" ]] && continue
    if grep -Eqi -- "$pattern" <<< "$(flat "$file")"; then duplicates=1; fi
  done
  if ((duplicates)); then fail "$id"; else pass "$id"; fi
}
cd "$ROOT" || exit 1

# Structural checks pin identities and valid resources, never prose headings or line counts.
require skill-identity SKILL.md 'name: research-repo-standard' 'description:'
require profile-identity agents/research-code-simplifier.md 'name: research-code-simplifier' 'description:'
links_ok=1
while IFS= read -r path; do
  if [[ ! -f "$ROOT/$path" ]]; then fail "missing-resource: $path"; links_ok=0; fi
done < <(grep -Eho 'references/[a-z-]+\.md|agents/research-code-simplifier\.md' \
  SKILL.md references/*.md README.md | sort -u)
while IFS= read -r path; do
  if [[ ! -f "$ROOT/$path" ]]; then fail "missing-blob-target: $path"; links_ok=0; fi
done < <(grep -Eho 'research-repo-standard/blob/main/[A-Za-z0-9/._-]+' \
  ./*.md references/*.md | sed 's|research-repo-standard/blob/main/||' | sort -u)
((links_ok)) && pass valid-reference-targets
for retired in vendor.sh adapters tests/vendor_test.sh tests/adapter_test.sh; do
  if [[ -e "$ROOT/$retired" ]]; then fail "retired-integration: $retired"; fi
done
if grep -ERqi 'post-vendor|standard_version|adapters/|profile-installer|agents/code-simplifier\.(md|toml)|source_data|results/reports' \
  AGENTS.md README.md SKILL.md Makefile references agents; then
  fail retired-production-integration
else pass retired-production-integration; fi

# Discovery and routing; the references own detailed procedures.
description="$(awk '
  /^description:/ { capture = 1; sub(/^description:[[:space:]]*/, ""); print; next }
  capture && (/^---$/ || /^[a-zA-Z_]+:/) { exit }
  capture { print }
' SKILL.md | tr '\n' ' ' | tr -s '[:space:]' ' ')"
if grep -Eqi 'bootstrap' <<< "$description" &&
  grep -Eqi 'adopt' <<< "$description" &&
  grep -Eqi 'repositories that (already )?follow' <<< "$description"; then
  pass selective-discovery
else fail selective-discovery; fi
require scope-boundary SKILL.md 'ordinary task.*ungoverned.*does not.*adoption' \
  'user instructions|explicit user' 'precedence|take precedence'
require proactive-questions SKILL.md '(ask|question).*understand' '(assum|overlook|blind spot)' \
  '(ask|question).*proactiv' '(even if|even when|without).*(proceed|block)'
owned proactive-questions-owner SKILL.md '(ask|question).*proactiv.*(proceed|block)'
require contextual-routing SKILL.md 'relevant|applicable' 'section' \
  'references/governance\.md' 'references/prerequisites\.md' 'references/bootstrap\.md' \
  'references/configuration\.md' 'references/data\.md' 'references/analysis\.md' 'references/figures\.md'
forbid no-whole-reference-reading SKILL.md 'read it completely|read every.*reference completely'
require source-maintenance AGENTS.md 'source repository|source-repository' 'SKILL\.md.*maintained product' \
  'test-first' 'meaning' 'blind.*scenario' 'hidden.*rubric' 'passing baseline' 'GREEN' \
  'make format' 'make test' 'git diff --check' 'non-normative'
require scientific-safety SKILL.md 'raw data.*immutable' 'data/raw/' \
  '(remov|disabl|skip|loosen).*check.*weaken' 'covering tests' \
  'estimand.*authoriz' 'exploratory.*confirmatory' 'complete-case' 'missingness.*before' 'criteria.*code'
require transactional-output SKILL.md 'temporar.*validat.*replac' 'failed run.*preserv.*existing' \
  '(no|never).*partial output'
require configuration-floor SKILL.md 'result-affecting setting.*one.*owner' \
  'fail.*before.*comput' '(never|not).*hidden.*default' 'nondeterminis' 'deterministic'
require four-impact-paths SKILL.md 'full gate' 'standard gate' 'light path' 'no gate' \
  'scientific.*(meaning|impact)' 'estimand' 'study design' 'inclusion' 'missing-data policy' \
  'data contract' 'pipeline structure' 'claim scope' '(uncertain|unsure).*full gate'
require full-gate SKILL.md 'superpowers:brainstorming' 'specification.*commit|commit.*specification' \
  'superpowers:writing-plans' '(not implement until.*plan|plan.*before.*implement)'
require authorized-proportionate-work SKILL.md '(existing authorization|already authorized)' \
  'standard gate.*authoriz' 'docs/LAB_NOTEBOOK\.md' 'test' \
  '(no|without).*specification.*plan' 'light path.*simplifier' \
  '(delet|disabl|skip|loosen|relax).*never.*light path' 'unchanged.*approv'
require adoption-assessment references/governance.md 'adoption' 'read-only' 'complian' 'gap' \
  '(each|every|item).*evidence' 'migration' 'references/configuration\.md' 'legacy'
require current-state-text SKILL.md 'LAB_NOTEBOOK\.md.{0,30}only.{0,40}histor' \
  'every other file.{0,120}as it is now' 'earlier versions' 'legacy' \
  'no notebook entry.{0,40}no history note' '(exploratory|post hoc).{0,60}current.{0,40}stay' \
  'unrelated files.{0,20}follow-up'
owned project-history-owner SKILL.md 'only file that records.{0,20}histor'
require inspected-completion SKILL.md 'format.*lint.*test' 'inspect.*artifact' 'exit code' \
  'git status' 'raw' 'unrelated work' 'boundar' 'waived|waiver' 'whole task'

# Governance: authorization carries forward; scientific forks and destruction remain explicit.
require governance-authorization references/governance.md 'routine.*implementation' \
  '(already authorized|existing authorization|preserve that authorization)' 'scientific meaning' 'declared contract' 'scope' \
  'external' 'destruct' '(consult|ask)' 'independent work'
require scientific-record references/governance.md 'docs/LAB_NOTEBOOK\.md' \
  'decision.*rationale.*authorization.*affected.*superseded' \
  'committed, pushed, or shared' 'docs/ANALYSIS_PLAN\.md' 'post hoc'
require destruction-boundary references/governance.md 'explicit authorization' \
  '(destruction|destructive|deletion)' 'target' 'recoverab' \
  'authorized regeneration.*covers.*replacement.*declared outputs' '(another|additional|second).*confirmation'
require coherent-review references/governance.md 'research-code-simplifier' \
  'coherent (unit|batch|change)' 'profile.*(owns|limits|supported)' 're-?run.*covering (tests|checks)' \
  'self-(pass|review).*(never|not|cannot).*substitut'
forbid no-per-task-ceremony references/governance.md 'after (each|every) (completed )?plan task.*before.*next'
require scoped-waiver references/governance.md 'scientific critique' 'simplifier' \
  'only (when|after).*fail' 'this session' 'explicit' 'scope' 'completion report' \
  'docs/LAB_NOTEBOOK\.md' 'smoke test' '(never|not).*validation'
require bounded-cleanup references/governance.md '(pre-existing|unrelated) (bug|defect)' 'follow-up' \
  'scratch' 'commit' 'tests.*(only|where|risk|behavior|contract)'
owned notebook-field-owner references/governance.md 'decision, rationale,.*authorization.*superseded'

# Host contracts: first-use provenance, conditional capabilities, and actual endpoint evidence.
require conditional-resolution references/prerequisites.md '(before|when).*depends on|dependent work' \
  'superpowers:brainstorming' 'superpowers:writing-plans' 'scientific-critical-thinking' 'nature-figure' \
  'host.*native' 'exact.*name' 'provenance' 'invocation' 'first use|first-use' \
  'file.*(not|never).*resol' 'not silently install.*imitate.*substitute' \
  'missing.*blocks only.*depends'
forbid no-unconditional-preflight references/prerequisites.md 'resolve.*before a bootstrap interview|superpowers.*whole package'
require authorized-recovery references/prerequisites.md 'authoriz.*(installation|recovery)' \
  'global agent configuration.*authoriz' 'resolver tried' \
  'https://github.com/obra/superpowers' 'scientific-agent-skills' 'nature-skills' \
  'restart.*session' '(not repeat|resume).*design|resume from.*blocked'
require delegated-resolution references/prerequisites.md 'delegat.*resolv' \
  'parent.*(not|never).*infer|never infer.*parent' 'governance\.md'
require canonical-installation references/prerequisites.md 'agent writes.*profile' \
  'provenance-verified.*source' 'agents/research-code-simplifier\.md' \
  '\.claude/agents/research-code-simplifier\.md' '\.codex/agents/research-code-simplifier\.toml' \
  'verbatim' 'same name, description, and body' 'only the selected host' 'none when no host' \
  'never.*(create|modify).*target.*AGENTS\.md.*CLAUDE\.md.*CODEX\.md' \
  'never overwrite.*customized.*explicit authorization'
require legacy-detection references/prerequisites.md 'detect.*earlier integration' \
  'resolves to.*customized' 'leave.*unchanged' 'legacy policy' 'alias' 'generic simplifier'
require real-host-proof references/prerequisites.md 'real smoke test' \
  'research-repo-standard.*provenance' 'research-code-simplifier.*profile path' \
  'launch.*profile.*delegated.*resolved and invoked' \
  'unavailable.*manual.*boundar.*not.*simulat' 'unavailable.*recovery'
require readonly-target-policy AGENTS.md '(never|not).*copies.*AGENTS\.md.*README\.md.*SKILL\.md' \
  '(never|not).*creates or modifies.*target.*AGENTS\.md.*CLAUDE\.md.*CODEX\.md' \
  'host agent, never a shell script'
require readme-integration README.md 'research-repo-standard' 'references/prerequisites\.md' \
  '\.claude/agents/research-code-simplifier\.md' '\.codex/agents/research-code-simplifier\.toml' \
  'legacy' 'explicit authorization' 'Makefile'
forbid host-neutral-profile agents/research-code-simplifier.md \
  'model:|\.claude/agents|Claude Code|Anthropic|Codex|OpenAI'
require simplifier-supported-use agents/research-code-simplifier.md \
  'explicitly delegates' 'research-repo-standard' 'supported' 'callers.*wrappers' 'private' 'unsupported' \
  'public' 'scientific' 'behavior difference' '(unknown|uncertain).*leave|leave.*(unknown|uncertain)' \
  'tests.*behavioral contract before editing' 'without weakening' 'rerun covering tests' 'no justified edit succeeds'
require simplifier-current-comments agents/research-code-simplifier.md \
  'comments that.{0,60}earlier versions'
require attributed-examples agents/research-code-simplifier.md 'requests \(Apache-2.0\)' 'PSF license'
forbid profile-defers-domain-grammar agents/research-code-simplifier.md \
  'config/analysis\.yaml|random_seed:|datasets\.yaml|mf1_|edf1_|sf1_'

# Bootstrap retains the concrete workflow contract while using supplied design decisions.
require contextual-bootstrap references/bootstrap.md 'supplied|already.*provided|existing.*answers' \
  'research question' 'claim' 'exploratory' 'host' 'license' 'dataset' 'randomness' \
  'external runtime' 'journal' 'CI' 'boundar' 'critique' 'no.figure' \
  'specification' 'implementation plan' 'references/prerequisites\.md' \
  'not silently choose.*scientific claim.*license.*host integration' \
  'only version control.*path.*specification' 'no host selected.*write no profile'
require bootstrap-scaffold references/bootstrap.md 'only.*approved' 'workflow/Snakefile' 'rule all' \
  'configfile' 'input:' 'output:' 'log:' 'params:' 'body.*single call' 'no scientific logic' \
  'src/<package_name>/' 'schemas/' 'no R.*unless|no.*runtime support unless'
require python-default-and-lock references/bootstrap.md 'latest stable Python minor' 'default' \
  'approved.*(compatibility|version|constraint)|compatibility.*approved' '.python-version' 'project.requires-python' \
  'uv init --package --build-backend hatch' 'never hand-edit' 'uv lock' 'uv sync --locked' \
  'compatibility bounds' 'exact.*version.*(demonstrated|constraint)' 'isolated environment.*approved'
require bootstrap-configuration-routing references/bootstrap.md 'references/configuration\.md' \
  '\.env.example.*only when.*environment variables' 'safe variable names.*placeholders'
require tools-and-hooks references/bootstrap.md 'line-length = 100' 'target-version' 'python-version' \
  'stable rules only' 'safe automatic fixes' 'per-file type exceptions' 'pre-commit install' \
  'private keys' 'large-file guard' 'local hooks' 'locked Ruff version' 'not run pytest in pre-commit'
require ci-contract references/bootstrap.md 'ci.yml' 'every push and pull request' \
  'uv lock --check.*uv sync --locked.*pre-commit run.*ty check.*make test' \
  '--frozen.*not enough' 'permitted fixture|permitted.*checkpoint' 'CI never reads.*data/raw/'
require ignore-contract references/bootstrap.md '\.gitignore.*\.env.*tmp/.*logs/.*\.venv/.*\.snakemake/.*data/' \
  'explicit negation' 'config/datasets\.yaml' 'large-file guard' '(LFS|DVC).*approved design' \
  'results/.*not ignored'
require logging-contract references/bootstrap.md 'configures no sink at import time' \
  'one console sink and one file sink' 'params.log_level' 'never source logging verbosity from the environment' \
  'logs resolved parameters.*inputs.*outputs.*failed' \
  'log_appender\(appender_tee\(log_path\)\)' 'log_threshold\(log_level\)'
require make-and-raw-safety references/bootstrap.md 'Make.*public workflow interface' 'Snakemake.*pipeline engine' \
  'DEFAULT_GOAL := help' 'setup:' 'test:' 'pipeline:' 'verify-results:' \
  'phony one-line wrappers' 'snakemake --cores all' 'do not use.*snakemake --delete-all-output' \
  'cleanup.*cannot reach.*data/raw/'
require external-runtime-boundary references/bootstrap.md 'R container.*only when.*approved design' \
  'renv.lock' 'CRAN' 'Bioconductor' 'checked-in wrapper' 'mount only required' 'testthat' \
  'not create an R package by default'
require generated-readme references/bootstrap.md 'project README records' 'research question' 'analysis status' \
  'prerequisites.*pinned Python' 'required skills.*separated.*packages' 'source and provenance' \
  'recovery' 'make pipeline' 'expected tables.*figures.*provenance' 'licensing.*manual.*boundar'

# Configuration's non-obvious Snakemake and provenance invariants remain exact operational contracts.
require setting-ownership references/configuration.md 'first matching bucket' 'mutually exclusive' \
  'credentials.*secrets.*absolute roots.*GPU selection.*environment' \
  'derived.*computed, never configured' 'paths.py' 'never.*duplicate|not duplicate' \
  'registry.*config/datasets.yaml' 'researcher-editable.*config/analysis.yaml' 'named Python constant'
require declared-seed-default references/configuration.md 'random_seed' '42' 'default' \
  'approved.*seed|seed.*approved' 'propagat.*every stochastic' 'not add.*seed.*deterministic'
require config-loading references/configuration.md 'configfile: "config/analysis.yaml"' \
  'snakemake.utils.validate' 'additionalProperties: false' 'unknown fields.*missing required.*invalid' \
  'before any job runs' 'functions never receive or read.*config'
require explicit-rule-params references/configuration.md 'result-affecting value.*params:.*explicit typed function arguments' \
  'rules never read.*config.*inside rule bodies' 'never narrow.*--rerun-triggers.*params.*code'
require override-rejection references/configuration.md '--config.*--configfile.*banned' \
  'parse time.*before the DAG' 're-reads.*YAML.*fails.*effective.*diverges' \
  'environment variables never override scientific settings' 'never reads.*os.environ.*result-affecting'
require config-containment references/configuration.md 'containment checks.*raw-data protections' \
  'no configuration may redirect.*outside' 'never credentials' 'never.*secret values|without recording secret values'
require manifest-provenance references/configuration.md 'manifest rule.*both configuration files as inputs' \
  'SHA-256.*validated effective values' 'redacted presence, never by value' \
  'every result-producing rule.*manifest as an.*ancient\(\).*input' \
  'manifest exists before any result job' 'mtime.*invalidating unchanged' 'separate versioned.*computed'
require config-migration references/configuration.md 'not bulk-migrate' 'adoption-mode' \
  'tests before relocating' 'must not change any effective value' 'gate.*SKILL.md' 'docs/LAB_NOTEBOOK.md'
require config-integration-tests references/configuration.md 'integration tests.*execute Snakemake' \
  'parallel scheduling' 'unchanged settings not invalidating unrelated work' 'hidden result-affecting Python defaults' \
  'precedence collisions' 'provenance failure'
owned configuration-bucket-owner references/configuration.md 'first matching bucket|bucket-5 constants'
owned skill-source-owner references/prerequisites.md 'github.com/(obra/superpowers|k-dense-ai/scientific-agent-skills|Yuan1z0825/nature-skills)'

# Data and scientific inference retain their complete validation and reporting boundaries.
require data-registry references/data.md 'config/datasets.yaml.*mandatory' 'received-form description' \
  'acquisition method' 'source version' 'row grain' 'data-use restrictions' 'machine-readable data dictionary' \
  'optional SHA-256' 'published digest' 'local raw data never needs a checksum' \
  'per-dataset.*README.md.*optional'
require correction-free-validation references/data.md 'validate every dataset before analysis' \
  'required and unexpected columns' 'dtypes.*category.*units' 'ranges.*cross-field' \
  'identifier uniqueness' 'nullability.*sentinel' 'join cardinality.*unmatched-key' 'ordering invariants' \
  'absent checksum is not a validation failure' 'dataset identifier.*violated rule' \
  'validation makes no implicit correction' 'downstream stages.*new outputs'
require shared-data-dictionary references/data.md 'every analysis-ready dataset.*machine-readable' \
  'scientific meaning.*type.*unit.*missing-value.*provenance.*derivation' 'validation read the same.*definitions'
require confirmatory-plan references/analysis.md 'before implementing a confirmatory analysis' \
  'docs/ANALYSIS_PLAN.md' 'estimand and unit' 'inclusion and exclusion' 'missing-data policy' \
  'multiplicity' 'sensitivity and subgroup' 'post hoc.*before presenting'
require inference-reporting references/analysis.md 'effect estimate and unit.*uncertainty.*sample size' \
  'exact test or model.*assumptions.*diagnostics.*multiplicity' 'p-value alone is insufficient' \
  'missingness and attrition' 'technical or biological'
require training-leakage references/analysis.md \
  'preprocessing.*normalization.*imputation.*feature selection.*tuning.*only the data permitted by the training design' \
  'metrics with uncertainty.*external-validation boundary'
require independent-science references/analysis.md 'before deciding or implementing.*scientific judgment' \
  'one design or coherent batch' 'independent agent, separate from the implementing agent' \
  'scientific-critical-thinking' 'without implementing the task' 'dependent decisions wait' \
  'material finding.*recorded rationale' 'governance.md' 'guidance, not evidence'

# Exploratory work keeps traceability and observed QA; publication keeps editable delivery.
require scoped-figures references/figures.md 'exploratory' 'publication' \
  'nature-figure' 'PNG' 'requested format' 'traceab' 'visually inspect' \
  'Python.*default|default.*Python' 'approved.*backend|backend.*approved'
require publication-figure-contract references/figures.md 'docs/FIGURE_CONTRACT.md' 'core conclusion' \
  'evidence hierarchy' 'panel map' 'image-integrity' 'reviewer risk' 'required export formats' \
  'editable SVG and PDF.*600 dpi TIFF.*PNG' 'journal.*never removes.*editable' \
  'visually inspect.*rendered SVG.*rendered PDF' 'file existence.*not evidence|existence.*not evidence'
require figure-data references/figures.md 'results/figure_data/<figure_id>/' 'tidy CSV or TSV' \
  'individual observations, not the summary alone' 'estimate.*uncertainty.*`n`' \
  'restriction.*finest permitted aggregate' 'every quantitative mark'
require figure-naming-and-assembly references/figures.md 'main_figure_<n>' 'extended_data_figure_<n>' \
  'supplementary_figure_<n>' 'mf1_\{short_descriptive_name\}' 'edf1_\{short_descriptive_name\}' \
  'sf1_\{short_descriptive_name\}' 'fig_<short_descriptive_name>' 'slot.*rename' \
  'results/figures/<figure_id>/<format>/' 'same atomic stem' 'after all atomic panel' \
  'never redraws' 'figure identifier as stem' 'panel letters are applied only at assembly'
require figure-encoding-and-qa references/figures.md 'thin orchestration' 'same.*color.*marker.*ordering' \
  'perceptually uniform' 'diverging.*scientifically meaningful midpoint' 'never use rainbow' \
  'overlap or clip' 'defensible scales' 'replicate definitions' 'scale bars' 'gamma.*stitching.*reuse'
owned figure-grammar-owner references/figures.md 'mf[0-9]+_|edf[0-9]+_|sf[0-9]+_|short_descriptive_name|hazard_ratio_distribution'

# Evidence provenance stays inspectable; scenario names, numbering, and record layout may evolve.
require pressure-evidence tests/skill_pressure_scenarios.md 'rubric.*hidden|hidden.*rubric' \
  '[0-9]+/[0-9]+' 'RED|baseline' 'manual verification boundar' \
  'blob/[0-9a-f]{40}/tests/skill_pressure_scenarios.md' 'Snakemake' '--config' \
  'environment' 'skip-mark' 'whole task' 'exploratory' 'GREEN'

if ((FAILS)); then printf '%s test(s) failed\n' "$FAILS"; exit 1; fi
printf 'all consistency tests passed\n'
