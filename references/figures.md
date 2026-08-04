<!-- standard_version: 2026.08.04 -->

# Reference: plot and figure contract

Read before writing any plotting code, and again during QA. `AGENTS.md` states the
rules; this expands the contract template and the QA checklist.

## Scope

Every plot — exploratory, diagnostic, analytical, supplementary, or manuscript-bound —
must:

1. use the `nature-figure` skill
2. use Python exclusively for plotting, previewing, exporting, and visual QA
3. define the complete figure contract before plotting
4. be implemented through importable functions under `src/<package_name>/figures/`
5. have traceable source data
6. pass the complete export and QA contract

Exploratory and diagnostic plots are not exempt. Their scientific role may be
"diagnostic" or "exploratory," but they still require the contract, exports, source
data, and QA.

Passing bootstrap discovery does not replace task-time invocation of `nature-figure`
for each plotting task. Before writing plotting code, that invocation must succeed. If
`nature-figure` is missing or its task-time invocation fails, apply the repository-wide
hard prerequisite gate: stop all file-changing work and report the exact blocker.

Never use R or another language to render a preview, fallback, assembly, or substitute
plot. If Python or a required Python plotting dependency is unavailable, stop the
plotting task before writing plotting code or rendering and report the exact blocker.

Matplotlib and Seaborn are the default stack. A specialized Python library may be used
only when scientifically necessary and when it meets the same editable-export and QA
requirements. Interactive-first output is never the final manuscript artifact.

## Pre-plot contract

Record in `docs/FIGURE_CONTRACT.md` **before** writing plotting code:

```text
Figure identifier:
Core conclusion:
Scientific role:
Figure archetype:
Target journal or output:
Backend: Python
Final size:
Panel map:
Evidence hierarchy:
Statistics needed:
Source data needed:
Image-integrity notes:
Reviewer risk:
Required export formats:
```

The core conclusion is one sentence with a verb. Every panel provides a unique piece of
evidence — remove or merge a panel when hiding it would not weaken the argument.
Classify the figure as a quantitative grid, schematic-led composite, image plate plus
quantification, or asymmetric mixed-modality figure.

The panel map identifies atomic panels by their semantic asset names. It may record
provisional manuscript letters separately, but those letters never become part of the
atomic asset names or renders.

## Atomic panels and source data

Each panel has an explicit function or specification, is independently reproducible,
reads a declared validated input, uses deterministic semantic naming
(`mf1_{short_descriptive_name}`, `edf1_{short_descriptive_name}`), omits manuscript
panel letters from both filename and rendered plot, exposes the statistics shown, maps
to a source-data file, and exports without depending on a previously mutated plotting
session.

```text
results/
├── figures/main_figure_1/
│   ├── svg/mf1_hazard_ratio_distribution.svg
│   ├── pdf/mf1_hazard_ratio_distribution.pdf
│   ├── tiff/mf1_hazard_ratio_distribution.tiff
│   └── png/mf1_hazard_ratio_distribution.png
└── source_data/main_figure_1/
    ├── mf1_hazard_ratio_distribution.csv
    └── README.md
```

Source data is tidy, documented, and sufficient to recreate the quantitative panel.

Assembly, when required, comes after all atomic panel exporters in Stage 07. It
consumes existing panels and never redraws them or changes their scientific encoding.
Panel letters are applied only at assembly and must not rename or alter the underlying
assets.

## Exports

Editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each format in its own
lowercase extension-named directory:
`results/figures/<figure_id>/<format>/<asset>.<format>`. Never place exported files
directly in `results/figures/<figure_id>/`. Journal-specific requirements may add
delivery formats but do not remove the editable working exports.

## Shared style

Centralize palettes, typography, dimensions, and export defaults in
`src/<package_name>/figures/common/style.py`; export and validation contracts in the
same `common/` package.

Use a consistent sans-serif stack led by Arial or Helvetica; editable text in SVG and
PDF; restrained, semantically consistent color families; a non-color encoding wherever
red/green confusion is possible; no rainbow color maps; direct labels or one shared
legend; text readable at final output size; minimal non-data ink; and panel hierarchy
that reflects evidence hierarchy.

The same condition, method, or cohort keeps the same encoding across panels and
figures unless the contract documents a compelling exception.

## QA checklist

Inspect the rendered outputs — open the SVG and PDF. A successful `savefig` call is
not evidence of a correct export.

- the one-sentence conclusion and panel evidence map still hold
- final physical dimensions are correct
- text is readable at final size
- SVG/PDF text is selectable and editable
- fonts, colors, line widths, and method encodings are consistent
- labels, legends, annotations, and error bars do not overlap or clip
- atomic panels contain no manuscript panel letter
- panel letters in an assembled figure are correct and consistently placed
- axes that invite comparison use defensible scales
- red/green is not the only distinction
- grayscale interpretation remains possible where needed
- `n`, replicate definitions, center, spread, tests, corrections, and comparisons are
  documented
- source-data files reproduce all quantitative marks
- raster resolution is sufficient
- image panels have calibrated scale bars where applicable
- crop, contrast, gamma, pseudo-color, stitching, and image reuse are documented
- a skeptical reviewer's most likely challenge has been addressed or disclosed
