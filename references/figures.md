# Reference: plot and figure contract

This contract owns figure planning, the Python plotting implementation, source data, detailed atomic
asset naming, export paths, assembly conventions, cross-figure encoding, and rendered-output QA.
Load it and invoke exact `nature-figure` before planning a figure, writing plotting code, changing
figure outputs, or performing QA.

Begin every figure-work plan or report with this completed preflight record:

```text
Figure contract source loaded: references/figures.md
Figure skill invoked: nature-figure
```

## Pre-plot contract

Record and approve the following complete template in `docs/FIGURE_CONTRACT.md` before plotting:

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

The core conclusion is one sentence with a verb. Every panel provides unique evidence; remove or
merge a panel when hiding it would not weaken the argument. Classify the figure as a quantitative
grid, schematic-led composite, image plate plus quantification, or asymmetric mixed-modality figure.

The panel map identifies atomic panels by semantic asset names. It may record provisional manuscript
letters separately, but those letters never become part of the atomic asset names or renders.

## Python implementation and source data

Python is the plotting backend. Do not switch languages or render a fallback preview in another
runtime. Implement testable, importable functions under `src/<package_name>/figures/<figure_id>/`;
keep stage scripts as thin orchestration entry points. Shared style, export, and validation
utilities live under `src/<package_name>/figures/common/{style,export,validation}.py`.

Each quantitative panel has traceable publication source data under
`results/source_data/<figure_id>/`. Source data is tidy, documented, sufficient to recreate every
quantitative mark, and exported as CSV or TSV with a README when interpretation needs explanation.

## Atomic panels and naming

Publication figures use identifiers such as `main_figure_1` and `extended_data_figure_1`. Their
atomic assets use deterministic semantic stems `mf1_{short_descriptive_name}` and
`edf1_{short_descriptive_name}`. Each panel:

- has an explicit function or specification;
- reads a declared, validated input;
- is independently reproducible without a previously mutated plotting session;
- exposes the statistics shown and maps to a source-data file;
- omits manuscript panel letters from its filename and rendered plot; and
- uses the same atomic stem for SVG, PDF, TIFF, PNG, and its source-data file.

Use the same atomic stem for every format and the corresponding source-data file.

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

Export and validate atomic panels before assembly. Assembly, when required, runs after all atomic
panel exporters, consumes existing panels, and never redraws them or changes their scientific
encoding. Panel letters are applied only at assembly and must not rename or alter the underlying
assets.

## Exports

Export editable SVG and PDF, 600 dpi TIFF, and a PNG preview. Put each format in its own lowercase
extension-named directory: `results/figures/<figure_id>/<format>/<asset>.<format>`. Never place
exports directly in `results/figures/<figure_id>/`. Journal requirements may add delivery formats
but do not remove the editable working exports.

## Shared style and cross-figure encoding

Centralize palettes, typography, dimensions, and export defaults in
`src/<package_name>/figures/common/style.py`. Use editable text in SVG and PDF, a consistent
sans-serif, restrained semantic color families, non-color encodings wherever color alone may fail,
no rainbow color maps, direct labels or one shared legend, readable final-size text, minimal
non-data ink, and a panel hierarchy that reflects the evidence hierarchy.

The same condition, method, cohort, control, and statistical meaning keeps the same color, marker,
line, and ordering across panels and figures. A compelling exception must be documented in the
figure contract before implementation.

## QA checklist

Open and visually inspect both the rendered SVG and rendered PDF. File existence, a successful
`savefig` call, or inspection of only the PNG preview is not evidence of correct editable exports.
Inspect at final physical size and record the QA outcome in `docs/FIGURE_CONTRACT.md`.

- the one-sentence conclusion and panel evidence map still hold;
- final physical dimensions are correct;
- text is readable, selectable, and editable where expected;
- fonts, colors, line widths, and method encodings are consistent;
- labels, legends, annotations, and error bars do not overlap or clip;
- atomic panels contain no manuscript panel letter;
- assembled panel letters are correct and consistently placed;
- axes that invite comparison use defensible scales;
- red/green is not the only distinction and grayscale interpretation remains possible where needed;
- `n`, replicate definitions, center, spread, tests, corrections, and comparisons are documented;
- source-data files reproduce every quantitative mark;
- raster resolution is sufficient and TIFF output is 600 dpi;
- image panels have calibrated scale bars where applicable;
- crop, contrast, gamma, pseudo-color, stitching, and image reuse are documented; and
- a skeptical reviewer's most likely challenge has been addressed or disclosed.
