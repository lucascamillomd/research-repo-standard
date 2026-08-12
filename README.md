<!-- standard_version: 2026.08.12 -->

# research-repo-standard

An operating standard for reproducible repositories that support a scientific
analysis, study, or paper.

## How it works

The standard has two modes:

- **Bootstrapping:** the `research-repo-standard` skill guides the design and
  creation of a new research repository.
- **Governance:** an existing repository vendors `AGENTS.md`, the portable governed
  policy applied by supported agent hosts.

Core vendoring copies only `AGENTS.md`. Optional, user-selected adapters install host
integration separately, and bootstrap may seed the canonical simplifier profile for an
adapter without making it part of portable vendoring. Supporting detail remains in this
source repository and is loaded through the skill when needed.

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
  vendor_test.sh           tests portable vendoring and replacement safety
  adapter_test.sh          tests optional host integration
adapters/                  installs optional host integration
vendor.sh                  copies only AGENTS.md into a target repository
```

## Vendor into a project

```bash
~/research-repo-standard/vendor.sh /path/to/repo
```

Then complete the `## This repository` section in the vendored `AGENTS.md`. If the
user selected a supported host adapter, install it separately as documented in
`references/prerequisites.md`.

`make check` is the aggregate source-repository validation entry point once the quality
toolchain is installed.
