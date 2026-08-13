<!-- standard_version: 2026.08.13 -->

# research-repo-standard

An operating standard for reproducible repositories that support a scientific analysis, study, or
paper.

## How it works

The standard has two modes:

- **Bootstrapping:** the `research-repo-standard` skill guides the design and creation of a new
  research repository.
- **Governance:** an existing repository vendors `AGENTS.md`, the portable governed policy applied
  by supported agent hosts.

`vendor.sh` writes only `AGENTS.md`. After vendoring, the selected adapter installs the canonical
simplifier profile and host-specific integration. `SKILL.md` steps 7–8 own core vendoring and
optional adapter integration. `references/prerequisites.md` owns host skill installation and
verification only.

## Repository structure

```text
AGENTS.md                  standard vendored into research repositories
Makefile                   source-repo help/test/format wrapper
SKILL.md                   skill entry point for bootstrap and on-demand guidance
references/
  analysis.md              analysis planning, reporting, and critique
  bootstrap.md             initial tool configuration and scaffolding
  configuration.md         configuration ownership, loading, and provenance
  data.md                  data registry, schemas, validation, and dictionaries
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

This is not the generated-repository workflow interface.

## Vendor into a project

```bash
~/research-repo-standard/vendor.sh /path/to/repo
```

Then follow `SKILL.md` steps 7–8 to complete the vendored `AGENTS.md` repository section and install
the selected adapter, if any.

`make test` runs the source-repository vendor, adapter, and consistency checks. `make format` wraps
the skill Markdown files.
