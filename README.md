<!-- standard_version: 2026.08.10 -->

# research-repo-standard

Operating standard for reproducible research repositories — those that support a
scientific analysis or paper.

Canonical source. Edit here, then vendor forward.

## Layout

```
AGENTS.md              the standard; the only file vendored into a project
SKILL.md               skill entry point (bootstrap + on-demand reference)
references/
  bootstrap.md         tool config to write when it does not exist yet
  prerequisites.md     required agent skills, installation, verification
  configuration.md     YAML ownership, loading, paths, overrides, provenance
  data.md              registry, schemas, validation, fixtures
  analysis.md          analysis plan, statistical reporting, critique
  figures.md           figure contract, exports, QA checklist
vendor.sh              copy AGENTS.md into a target repository
```

## Two modes

**Bootstrapping** — no repository yet, so nothing can be vendored. The skill carries
the interview and scaffolding.

**Governance** — the repository vendors `AGENTS.md`, which is always in context there
and self-sufficient for the rules. `references/` holds only the detail `AGENTS.md`
deliberately omits, loaded on demand.

Only `AGENTS.md` is vendored. That keeps a governed repository self-contained for
collaborators, CI, and agents that never load skills, without duplicating the
reference material into every project.

## Hard prerequisites

Repository bootstrap and later governed modifications require these discoverable agent
skills:

- `superpowers:brainstorming`
- `scientific-critical-thinking`
- `nature-figure`

Bootstrap actively uses all three. Missing prerequisites stop work before repository
changes; they are not installed by uv or `make setup`. See
[`references/prerequisites.md`](references/prerequisites.md) for authoritative sources,
host-specific installation, verification, and resumption.

## Configuration source of truth

`AGENTS.md` owns the configuration ownership rules;
[`references/configuration.md`](references/configuration.md) holds the full
contract — ownership, overrides, provenance, and migration.

## Install as a Claude skill

```bash
ln -s ~/research-repo-standard ~/.claude/skills/research-repo-standard
```

## Vendor into a project

```bash
~/research-repo-standard/vendor.sh /path/to/repo
```

Then fill in the `## This repository` section of the vendored `AGENTS.md`.

## Versioning

Every file carries `standard_version`. Vendored copies keep the version they were
vendored at; `make standard-check` in a governed repository (backed by
`vendor.sh --check`) reports drift against this source without resolving it — a
project may legitimately refine the standard for its own science.

## Design

Written against the context-engineering guidance for Claude 5 generation models:
judgment over blanket prohibitions, one source per rule, and progressive disclosure
over front-loading. A short list of integrity rules stays absolute — raw-data
immutability, never weakening a verification gate, authorization for estimand changes,
transactional outputs, honest reporting of what was verified — because silent
reproducibility erosion is the failure this standard exists to prevent.
