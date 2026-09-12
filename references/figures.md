# Reference: plot and figure contract

This contract owns figure delivery scope, plotting, traceable figure data, asset naming, assembly,
and rendered-output QA. Read the shared sections and those for the requested delivery scope.

## Scope

**Exploratory delivery** produces the requested artifact, such as a single PNG for a lab meeting,
with traceable source data, exploratory labeling, accurate units and statistics, and visual
inspection of that actual rendering. Reuse the user's supplied axes, plot type, inputs, and output
path. Record the figure identifier, inputs, transformation, units, output, and exploratory status in
the existing figure record or notebook; a separate full figure contract and another approval are not
required. Do not invent a conclusion or promote the plot to confirmatory evidence.

**Publication delivery** requires the pre-plot contract, editable exports and publication QA below.
Resolve and invoke `nature-figure` for publication figure strategy or delivery, using
`references/prerequisites.md`. Promoting an exploratory figure to publication triggers these
requirements; calling a publication deliverable a draft does not waive them.

Choose scope from the requested use and existing project contract. A quick exploratory PNG request
does not require publication exports or the publication figure skill. Existing approved delivery
requirements continue to apply unless the user changes them. Scientific decisions in either scope
follow SKILL.md's gates and `references/analysis.md`; selecting a new exclusion or model is not a
routine styling choice.

## Pre-plot contract

For publication delivery, record this contract in `docs/FIGURE_CONTRACT.md` before plotting. Reuse
an approved contract or supplied decisions; obtain approval only for unresolved material choices
under the applicable gate:

```text
Figure identifier:
Core conclusion:
Scientific role:
Figure archetype:
Target journal or output:
Backend:
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

## Implementation and figure data

Python is the default plotting backend. Preserve an approved alternative or the user's explicit
backend choice and record it with its runtime and reproduction command. A failed renderer does not
authorize switching backends silently. In Python, implement testable, importable functions under
`src/<package_name>/figures/<figure_id>/` with shared utilities under
`src/<package_name>/figures/common/{style,export,validation}.py`. An approved alternative uses its
project's tested modules. Keep Snakemake rules as thin orchestration entry points.

Each quantitative panel exports its figure data as tidy CSV or TSV under
`results/figure_data/<figure_id>/`. The data recreate every quantitative mark. For a bar, box,
violin, or mean with error bars, they include the individual observations, not the summary alone. A
model-estimate mark carries the estimate, its uncertainty, and `n`. When a data-use restriction
forbids releasing observations, record the restriction in the figure record and export the finest
permitted aggregate. Add a `README.md` when columns, units, or derivation need explanation. Build
the journal's "Source Data" submission from these files in whatever container it requires.

## Atomic panels and naming

Figure identifiers are `main_figure_<n>`, `extended_data_figure_<n>`, and
`supplementary_figure_<n>`. Atomic asset stems are the identifier's initials and number plus a
descriptive name: `mf1_{short_descriptive_name}`, `edf1_{short_descriptive_name}`,
`sf1_{short_descriptive_name}`. A figure without a manuscript slot, exploratory ones included, uses
`fig_<short_descriptive_name>` as identifier and stem prefix. When it gets a slot, rename it in the
figure record, the `src/<package_name>/figures/<figure_id>/` package, and the `results/figures/` and
`results/figure_data/` paths together. Each panel:

- has an explicit function or specification;
- reads a declared, validated input;
- reproduces on its own, without state from an earlier plotting session;
- exposes the statistics shown and maps to a figure-data file;
- omits manuscript panel letters from its filename and rendered plot; and
- uses the same atomic stem for its figure-data file and for every requested export format.

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

For publication delivery, export editable SVG and PDF, 600 dpi TIFF, and a PNG preview. Exploratory
delivery exports only the requested formats. Each format has its own directory named by lowercase
extension: `results/figures/<figure_id>/<format>/<asset>.<format>`. Never place exports directly in
`results/figures/<figure_id>/`. For publication, a journal may add delivery formats; it never
removes the editable exports. Preserve an explicitly requested existing output path for exploratory
work; new assets use the naming convention above.

## Assembly

For publication delivery, assemble when the panel map places more than one atomic panel in a figure
and the contract records no polish deferral. Assembly runs after all atomic panel exporters and
after the panels pass validation. It reuses the exported panels and never redraws them or changes
their scientific encoding. Export the assembled figure in the same four formats and per-format
directories, with the figure identifier as stem, for example
`results/figures/main_figure_1/svg/main_figure_1.svg`.

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
line, and ordering across panels and figures. Document any compelling exception in the figure record
before implementing it.

## QA checklist

For either scope, open and visually inspect the actual requested renderings and verify the data
behind every quantitative mark. Apply the relevant checklist items below; record outcomes in the
figure record. For publication delivery, inspect both rendered SVG and rendered PDF at final
physical size and record the outcome in `docs/FIGURE_CONTRACT.md`. File existence, a successful
export call, or a PNG preview alone is not evidence of correct editable exports. An inaccessible
renderer remains an explicit QA boundary, never an inferred pass.

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
