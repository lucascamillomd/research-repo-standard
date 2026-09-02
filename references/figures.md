# Reference: plot and figure contract

This contract owns figure planning, Python plotting, figure data, atomic asset naming, export paths,
assembly, cross-figure encoding, and rendered-output QA. Load it and invoke exact `nature-figure`
before planning a figure, writing plotting code, changing figure outputs, or running QA.

## Scope

A figure produced from repository data is figure work regardless of framing. "Exploratory", "quick",
"draft", or a deadline changes how fast this contract is approved, not whether the contract, the
traceable figure data, the four required export formats, and the rendered SVG and PDF inspection
happen. Publication polish means journal sizing, final typography, and assembly. Deferring it is a
user scope decision only after the contract records the deferral and the editable exports still
exist.

## Pre-plot contract

Before plotting, fill every field of this template in `docs/FIGURE_CONTRACT.md` and get it approved:

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

The panel map identifies atomic panels by asset name and may record provisional manuscript letters
separately.

## Python implementation and figure data

Python is the plotting backend. Do not switch languages or render a fallback preview in another
runtime. Implement testable, importable functions under `src/<package_name>/figures/<figure_id>/`;
keep Snakemake rules as thin orchestration entry points. Shared style, export, and validation
utilities live under `src/<package_name>/figures/common/{style,export,validation}.py`.

Each quantitative panel exports its figure data as tidy CSV or TSV under
`results/figure_data/<figure_id>/`. The data recreate every quantitative mark. For a bar, box,
violin, or mean with error bars, they include the individual observations, not the summary alone. A
model-estimate mark carries the estimate, its uncertainty, and `n`. When a data-use restriction
forbids releasing observations, record the restriction under `Figure data needed:` in the contract
and export the finest permitted aggregate. Add a `README.md` when columns, units, or derivation need
explanation. Build the journal's "Source Data" submission from these files in whatever container it
requires.

## Atomic panels and naming

Figure identifiers are `main_figure_<n>`, `extended_data_figure_<n>`, and
`supplementary_figure_<n>`. Atomic asset stems are the identifier's initials and number plus a
descriptive name: `mf1_{short_descriptive_name}`, `edf1_{short_descriptive_name}`,
`sf1_{short_descriptive_name}`. A figure without a manuscript slot, exploratory ones included, uses
`fig_<short_descriptive_name>` as identifier and stem prefix. When it gets a slot, rename it in
`docs/FIGURE_CONTRACT.md`, the `src/<package_name>/figures/<figure_id>/` package, and the
`results/figures/` and `results/figure_data/` paths together. Each panel:

- has an explicit function or specification;
- reads a declared, validated input;
- reproduces on its own, without state from an earlier plotting session;
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
    └── README.md   # when columns need explanation
```

## Exports

Export editable SVG and PDF, 600 dpi TIFF, and a PNG preview. Each format has its own directory
named by lowercase extension: `results/figures/<figure_id>/<format>/<asset>.<format>`. Never place
exports directly in `results/figures/<figure_id>/`. A journal may add delivery formats; it never
removes the editable exports.

## Assembly

Assemble when the panel map places more than one atomic panel in a figure and the contract records
no polish deferral. Assembly runs after all atomic panel exporters and after the panels pass
validation. It reuses the exported panels and never redraws them or changes their scientific
encoding. Export the assembled figure in the same four formats and per-format directories, with the
figure identifier as stem, for example `results/figures/main_figure_1/svg/main_figure_1.svg`.

Panel letters are applied only at assembly and never change an asset name or its content.

## Shared style and cross-figure encoding

Centralize palettes, typography, dimensions, and export defaults in
`src/<package_name>/figures/common/style.py`. Use editable text in SVG and PDF, a consistent
sans-serif, restrained semantic color families, non-color encodings wherever color alone may fail,
direct labels or one shared legend, readable final-size text, minimal non-data ink, and a panel
hierarchy that reflects the evidence hierarchy. Use perceptually uniform sequential maps for
magnitudes. Use a diverging map only when the data have a scientifically meaningful midpoint, and
center the scale on it. Never use rainbow maps.

The same condition, method, cohort, control, and statistical meaning keeps the same color, marker,
line, and ordering across panels and figures. Document any compelling exception in the figure
contract before implementing it.

## QA checklist

Open and visually inspect both the rendered SVG and rendered PDF at final physical size. File
existence, a successful `savefig` call, or inspection of only the PNG preview is not evidence of
correct editable exports. Record the QA outcome in `docs/FIGURE_CONTRACT.md`.

- the one-sentence conclusion and panel evidence map still hold;
- final physical dimensions are correct;
- text is readable, selectable, and editable where expected;
- fonts, colors, line widths, and method encodings are consistent;
- labels, legends, annotations, and error bars do not overlap or clip;
- atomic panels contain no manuscript panel letter;
- assembled panel letters are correct and consistently placed;
- axes that invite comparison use defensible scales;
- red/green is never the only distinction and the figure still reads in grayscale where needed;
- `n`, replicate definitions, center, spread, tests, corrections, and comparisons are documented;
- figure-data files reproduce every quantitative mark;
- raster resolution is sufficient and TIFF output is 600 dpi;
- image panels have calibrated scale bars where applicable;
- crop, contrast, gamma, pseudo-color, stitching, and image reuse are documented; and
- a skeptical reviewer's most likely challenge has been addressed or disclosed.
