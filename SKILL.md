---
name: research-repo-standard
description: The operating standard for reproducible research repositories — those supporting a scientific analysis, study, or paper. Use it whenever setting up such a repository (bootstrap interview, scaffolding, uv/Ruff/ty/pre-commit/CI configuration), and whenever working inside one: registering a dataset or writing schema validation, planning or reporting a confirmatory analysis, defining a figure contract or running figure QA, or vendoring and re-vendoring the standard into a project. Consult it even when the user never names the standard — any request to set up a research repo, add a dataset to config/datasets.yaml, write an analysis plan, check reproducibility, or produce publication figures and tables should go through it.
standard_version: 2026.07.25
---

# Research repository standard

Two modes.

**Bootstrapping** — the repository does not exist yet. Follow the sequence below.

**Governance** — the repository exists and vendors `AGENTS.md`, which is already in
context and self-sufficient for the rules. Load a reference here only for detail it
deliberately omits:

| Reference | Read when |
|---|---|
| `references/bootstrap.md` | writing tool config, CI, or a Makefile that does not exist yet |
| `references/data.md` | registering a dataset, defining a schema, writing validation |
| `references/analysis.md` | planning or reporting a confirmatory analysis |
| `references/figures.md` | before writing any plotting code, and again during figure QA |

Do not restate `AGENTS.md` back to the user — they already have it.

## Bootstrapping sequence

1. **Interview.** Ask for any answer below that cannot be inferred safely. Do not
   scaffold first.
2. **Read `AGENTS.md`** in this skill so the structure you create matches what will
   govern the repository.
3. **Scaffold** the directory structure (`AGENTS.md` → Repository layout).
4. **Configure tooling** from `references/bootstrap.md`.
5. **Vendor**: `./vendor.sh <target-repo>` — copies `AGENTS.md` and symlinks
   `CLAUDE.md` to it. Nothing else is vendored; this skill holds the rest.
6. **Fill in** the `## This repository` section of the vendored `AGENTS.md`.
7. **Report** what was created, what was assumed, and what remains unresolved.

## Interview

1. What is the primary research question and intended scientific claim?
2. Should the license be MIT, or should the repository remain unlicensed/proprietary?
3. Which currently supported stable Python minor version?
4. What datasets are expected?
5. Which workflow stages are needed, and which processed-data checkpoint can be shared?
6. Are R or other non-Python tools required, and can they run in a pinned container?
7. What are the expected tables, plots, reports, and publication targets?
8. Which steps cannot be automated because of licensing, compute, or external
   environment constraints?
9. What verification can run in public CI, and what requires external inputs or tools?

**Do not create a `LICENSE` until question 2 is answered.** Do not assume a company or
otherwise private repository should use MIT. If no choice is available, leave the
repository unlicensed and report that as unresolved.

## Drift

A repository vendors `AGENTS.md` at the version stamped in its first line. When this
source changes, vendored copies do not — that is intended, since a project may
legitimately refine the standard for its own science. `make standard-check` in a
governed repository reports the difference; it does not resolve it.
