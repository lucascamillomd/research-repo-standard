# Reference: plot and figure contract

`AGENTS.md` supplies normative figure requirements; this reference is the procedural expansion and
sole owner of detailed atomic asset naming, export paths, assembly conventions, the contract
template, and the QA checklist. Read this reference before: planning a figure; writing plotting
code; modifying figure outputs; performing QA.

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

The core conclusion is one sentence with a verb. Every panel provides a unique piece of evidence —
remove or merge a panel when hiding it would not weaken the argument. Classify the figure as a
quantitative grid, schematic-led composite, image plate plus quantification, or asymmetric
mixed-modality figure.

The panel map identifies atomic panels by their semantic asset names. It may record provisional
manuscript letters separately, but those letters never become part of the atomic asset names or
renders.

## Atomic panels and source data

Publication figures use identifiers such as `main_figure_1` and `extended_data_figure_1`; their
atomic assets use the corresponding deterministic semantic stems `mf1_{short_descriptive_name}` and
`edf1_{short_descriptive_name}`. Each panel has an explicit function or specification, is
independently reproducible, reads a declared validated input, omits manuscript panel letters from
both filename and rendered plot, exposes the statistics shown, maps to a source-data file, and
exports without depending on a previously mutated plotting session. Use the same atomic stem for
SVG, PDF, TIFF, PNG, and the panel's source-data file.

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

Assembly, when required, comes after all atomic panel exporters in Stage 07. It consumes existing
panels and never redraws them or changes their scientific encoding. Panel letters are applied only
at assembly and must not rename or alter the underlying assets.

## Exports

Editable SVG, editable PDF, 600 dpi TIFF, PNG preview. Each format in its own lowercase
extension-named directory: `results/figures/<figure_id>/<format>/<asset>.<format>`. Never place
exported files directly in `results/figures/<figure_id>/`. Journal-specific requirements may add
delivery formats but do not remove the editable working exports.

## Shared style

Centralize palettes, typography, dimensions, and export defaults in
`src/<package_name>/figures/common/style.py`; export and validation contracts in the same `common/`
package.

Use a consistent sans-serif with editable text in SVG and PDF; restrained, semantically consistent
color families; a non-color encoding wherever red/green confusion is possible; no rainbow color
maps; direct labels or one shared legend; text readable at final output size; minimal non-data ink;
and panel hierarchy that reflects evidence hierarchy.

The same condition, method, or cohort keeps the same encoding across panels and figures unless the
contract documents a compelling exception.

## QA checklist

Inspect the rendered outputs — open the SVG and PDF. A successful `savefig` call is not evidence of
a correct export.

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
- `n`, replicate definitions, center, spread, tests, corrections, and comparisons are documented
- source-data files reproduce all quantitative marks
- raster resolution is sufficient
- image panels have calibrated scale bars where applicable
- crop, contrast, gamma, pseudo-color, stitching, and image reuse are documented
- a skeptical reviewer's most likely challenge has been addressed or disclosed
