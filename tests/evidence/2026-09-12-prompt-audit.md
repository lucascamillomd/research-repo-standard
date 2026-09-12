# Prompt audit: Astra and Fable 5.1

Audit date: 2026-09-12. Baseline: `f91caa09e362acf5e4e9416735c110aad93bc1f3`. This is a
non-normative audit record, not an instruction file for a target repository.

## Scope and result

The requested scope is all 14 Markdown files tracked at the baseline commit. The targets are GPT-6
Astra and Claude Fable 5.1. The product remains host-neutral; model choice and API settings belong
to the host. No production request builder or API model-call site exists in this repository.

No active skill, reference, or profile instruction warranted removal. The user chose to delete both
outdated historical documents rather than retain them with notices. The original contents remain in
Git history. Both findings were medium-confidence Group 1d / Group 2 matches; Groups 3 and 4 had no
actionable findings. No demonstrated model failure is claimed.

## Method and provenance

Applied the official
[Claude prompt-audit procedure](https://github.com/anthropics/skills/blob/main/skills/claude-api/shared/prompt-audit.md),
including its keep list, and the
[Fable 5.1 migration guidance](https://github.com/anthropics/skills/blob/main/skills/claude-api/shared/model-migration.md).
Compared them with
[OpenAI's Astra guide](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)
and the installed `skill-creator` instructions. Inventory, signal searches, reference ownership,
tests, and git blame informed each decision; an independent Codex agent also reviewed all 14 files.

Git history records an earlier Fable prompting update (`55d8535`) and prompt audit (`dc5afbc`).
Those commits explain several retained rules; they do not establish current model validation. The
two historical documents have been unchanged since their August 20 creation commits, `96017bb0` and
`f026fcf1`.

Claude Code 2.1.269 was available and authenticated. A read-only invocation of
`/claude-api prompt-audit` with requested model `claude-fable-5-1` returned `is_error: true` and
"You're out of usage credits." Its `modelUsage` was empty. No native audit, slash-command
resolution, or Fable behavior test completed. The published procedure was applied in Codex; it was
not simulated as a successful Claude run.

## Inventory and disposition

| Baseline Markdown file                                                | Disposition and retained purpose                                                              |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `AGENTS.md`                                                           | Keep source authority, contextual reading, and honest contract evaluation.                    |
| `README.md`                                                           | Keep source setup, host routing, and verification boundaries.                                 |
| `SKILL.md`                                                            | Keep selective discovery, scientific impact gates, scoped authorization, and safety floor.    |
| `agents/research-code-simplifier.md`                                  | Keep supported-use evidence, public compatibility, and varied examples.                       |
| `references/analysis.md`                                              | Keep inference, leakage, reporting, and independent scientific review requirements.           |
| `references/bootstrap.md`                                             | Keep supplied-decision reuse and concrete scaffold, runtime, and reproduction contracts.      |
| `references/configuration.md`                                         | Keep ownership, explicit rule parameters, override rejection, and provenance edges.           |
| `references/data.md`                                                  | Keep raw-data, registry, schema, validation, and data-use contracts.                          |
| `references/figures.md`                                               | Keep delivery scope, source data, editable publication formats, and visual QA.                |
| `references/governance.md`                                            | Keep authorization, records, proportionate review, and waiver boundaries.                     |
| `references/prerequisites.md`                                         | Keep exact host resolution, provenance, profile installation, and real smoke-test boundaries. |
| `tests/skill_pressure_scenarios.md`                                   | Keep evaluator rubrics and dated results as evaluation material.                              |
| `docs/superpowers/plans/2026-08-20-snakemake-orchestration.md`        | Deleted at the user's request; retained in Git history.                                       |
| `docs/superpowers/specs/2026-08-20-snakemake-orchestration-design.md` | Deleted at the user's request; retained in Git history.                                       |

## Findings and original recommendations

The notice recommendations below preceded the user's explicit decision to remove the files.
Locations refer to the baseline commit, not the final checkout.

### Historical plan reads as a current execution request

- **Location:** `docs/superpowers/plans/2026-08-20-snakemake-orchestration.md:3`, with related
  constraints at baseline lines 16 and 19.
- **Evidence:** "REQUIRED SUB-SKILL", "implement this plan task-by-task", references to
  `tests/adapter_test.sh`, and "≤ 10 `Label:` slots".
- **Pattern:** Group 1d fossils and Group 2 time-sensitive/history content.
- **Why it matters:** The plan's opening can be retrieved without the source authority notice.
  Literal execution would invoke retired tests and restore obsolete formatting constraints. Both
  target guides favor relevant current context; the Fable audit specifically calls out dated
  workflow instructions. Source `AGENTS.md` already defines the correct precedence.
- **Confidence:** Medium. The stale references are verified; no target-model regression is claimed.
- **Action:** Add a historical-status notice and links to the existing normative owners. Preserve
  the body as a record, including its original commands and unchecked boxes.

### Historical design describes an old state as current

- **Location:** `docs/superpowers/specs/2026-08-20-snakemake-orchestration-design.md:4`, with its
  architecture description at baseline line 8.
- **Evidence:** "Status: approved in discussion; pending spec review" and "currently uses Make as
  both the public workflow interface and the pipeline runner".
- **Pattern:** Group 1d migration-relative phrasing and Group 2 time-sensitive/history content.
- **Why it matters:** Standalone retrieval can present a past status and superseded architecture as
  the maintained product. Contextual labeling lets either model use the document as history while
  routing current decisions to the live contracts.
- **Confidence:** Medium. The contextual mismatch is verified; native Fable behavior is untested.
- **Action:** Add the same historical notice. Keep the original status and account unchanged inside
  that historical context.

## Retained content and non-applicable checks

Research safeguards are domain requirements, not generic model coaching. Full scientific gates,
immutable raw data, transactional output replacement, missingness reporting, independent critique,
and supported-use evidence stay. Numbered configuration and installation steps protect fragile
mechanisms. Runtime/package pins support reproducible checks. The simplifier's examples specify real
compatibility boundaries; rubric language belongs to the evaluator and is withheld from agents.

Completion guidance has scoped authorization and Scenario L coverage. Retaining it is consistent
with the Astra guide's Persistence section and the Fable 5.1 migration guide's long-horizon
execution guidance; removing it merely because it resembles emphasis would ignore that purpose. No
active guidance forces reasoning disclosure, suppresses progress updates, bans useful formatting, or
pins a model. API-prefill, sampling, cache ordering, token-accounting, and deterministic model-loop
checks have no production request builder to act on. The single canonical specialist profile is not
a redundant agent roster. No API configuration or provider conversion is proposed.

## Final disposition and verification

The user explicitly requested removal of the two outdated files, followed by commit and push. Both
files are deleted. Their baseline versions remain retrievable from Git at
`f91caa09e362acf5e4e9416735c110aad93bc1f3`. Source instructions describe any future design archive
conditionally; no normative skill or scientific procedure changed.

Before the deletion request, Scenario W scored **4/4** on the baseline and **4/4** on the notice
candidate with fresh agents, the same prompt, and a hidden rubric. Those results remain historical
policy assessments of the earlier snapshots. They do not establish behavior after deletion, executed
research workflows, or native Fable validation.

The earlier notice candidate passed 74 consistency groups, 28 Python tests, formatting, Bash syntax
validation, skill-creator's validator, and diff checks. Final deletion checks use `make format`,
`make test`, and `git diff --check`, plus a reference scan confirming the removed paths occur only
as historical audit/evaluation evidence.

The [machine-readable evidence](2026-09-12-prompt-audit.json) preserves the earlier snapshot hashes,
responses, criterion assessments, guide hashes, and unsuccessful native Claude result. Its candidate
is explicitly marked superseded by the user-requested deletion. Fable 5.1 runtime behavior and real
host-resolver/profile smoke tests remain unverified.
