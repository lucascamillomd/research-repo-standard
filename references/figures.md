# Reference: plot and figure contract

This contract owns figure planning, the Python plotting implementation, figure data, detailed atomic
asset naming, export paths, assembly conventions, cross-figure encoding, and rendered-output QA.
Load it and invoke exact `nature-figure` before planning a figure, writing plotting code, changing
figure outputs, or performing QA.

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
Figure data needed:
Image-integrity notes:
Reviewer risk:
Required export formats:
```

The core conclusion is one sentence with a verb. Every panel provides unique evidence; remove or
merge a panel when hiding it would not weaken the argument. Classify the figure as a quantitative
grid, schematic-led composite, image plate plus quantification, or asymmetric mixed-modality figure.

The panel map identifies atomic panels by semantic asset names. It may record provisional manuscript
letters separately, but those letters never become part of the atomic asset names or renders.

A figure produced from repository data is figure work regardless of framing. "Exploratory", "quick",
"draft", or a deadline changes how fast this contract is approved, not whether the contract, the
traceable figure data, the four required export formats, and the rendered SVG and PDF inspection
happen. Publication polish means journal sizing, final typography, and assembly. Deferring it is a
user scope decision only after the contract records the deferral and the editable exports still
exist.

## Python implementation and figure data

Python is the plotting backend. Do not switch languages or render a fallback preview in another
runtime. Implement testable, importable functions under `src/<package_name>/figures/<figure_id>/`;
keep Snakemake rules as thin orchestration entry points. Shared style, export, and validation
utilities live under `src/<package_name>/figures/common/{style,export,validation}.py`.

Each quantitative panel has traceable publication figure data under
`results/figure_data/<figure_id>/`. Figure data is tidy, documented, sufficient to recreate every
quantitative mark, and exported as CSV or TSV with a README when interpretation needs explanation.
These files serve as the journal-facing "Source Data" exports submitted with the manuscript.

## Atomic panels and naming

Publication figures use identifiers such as `main_figure_1` and `extended_data_figure_1`. Their
atomic assets use deterministic semantic stems `mf1_{short_descriptive_name}` and
`edf1_{short_descriptive_name}`. Each panel:

- has an explicit function or specification;
- reads a declared, validated input;
- is independently reproducible without a previously mutated plotting session;
- exposes the statistics shown and maps to a figure-data file;
- omits manuscript panel letters from its filename and rendered plot; and
- uses the same atomic stem for its figure-data file and for every format: SVG, PDF, TIFF, PNG.

```text
results/
├── figures/main_figure_1/
│   ├── svg/mf1_hazard_ratio_distribution.svg
│   ├── pdf/mf1_hazard_ratio_distribution.pdf
│   ├── tiff/mf1_hazard_ratio_distribution.tiff
│   └── png/mf1_hazard_ratio_distribution.png
└── figure_data/main_figure_1/
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
line, and ordering across panels and figures. Document any compelling exception in the
figure contract before implementing it.

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
- figure-data files reproduce every quantitative mark;
- raster resolution is sufficient and TIFF output is 600 dpi;
- image panels have calibrated scale bars where applicable;
- crop, contrast, gamma, pseudo-color, stitching, and image reuse are documented; and
- a skeptical reviewer's most likely challenge has been addressed or disclosed.
