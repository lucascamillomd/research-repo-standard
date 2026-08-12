<!-- standard_version: 2026.08.12 -->

# research-repo-standard

An operating standard for reproducible repositories that support a scientific
analysis, study, or paper.

## How it works

The standard has two modes:

- **Bootstrapping:** the `research-repo-standard` skill guides the design and
  creation of a new research repository.
- **Governance:** an existing repository vendors `AGENTS.md`, which provides the
  self-contained rules that collaborators, CI, and agents follow.

Only `AGENTS.md` is copied into governed repositories. Supporting detail remains
in this source repository and is loaded through the skill when needed.

## Repository structure

```text
AGENTS.md                  standard vendored into research repositories
SKILL.md                   skill entry point for bootstrap and on-demand guidance
references/
  analysis.md              analysis planning, reporting, and critique
  bootstrap.md             initial tool configuration and scaffolding
  configuration.md         configuration ownership, loading, and provenance
  data.md                  data registry, schemas, validation, and fixtures
  figures.md               figure contracts, exports, and QA
  prerequisites.md         required skills, installation, and verification
agents/
  code-simplifier.md       post-change simplification agent profile
tests/
  consistency_test.sh      checks links and cross-file consistency
  vendor_test.sh           tests vendoring and drift checks
vendor.sh                  copies the standard into a target repository
```

## Vendor into a project

```bash
~/research-repo-standard/vendor.sh /path/to/repo
```

Then complete the `## This repository` section in the vendored `AGENTS.md`.
