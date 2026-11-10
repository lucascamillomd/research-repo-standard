---
name: nature-schematic
description:
  Use when making, revising or reviewing a scientific schematic, such as a mechanism, pathway,
  workflow, model architecture, disease progression, multi-organ overview or graphical abstract, for
  a paper, review or grant, especially in the style of Nature figures. Not for plots of data.
---

# Nature-style schematics

A schematic explains a relation. Build it as editable vector art in the style recorded in
[references/style.md](references/style.md). No image-generation model takes part: every shape is
drawn in code, or comes from an asset whose source, licence and credit line you record.

In a repository that follows `research-repo-standard`, its `references/figures.md` owns paths,
names, export formats and records. This skill owns how the schematic is designed, drawn and
reviewed.

## Brief

Before drawing, write `brief.md` from the source:

- the one claim a reader should take away
- the entities, compartments included, each with its exact label text
- each relation with its endpoints, type and certainty, and where the source states it, such as
  "cGAS makes cGAMP (section 2, paragraph 1)"
- what the source leaves open, which the drawing must not decide, such as where on a route a step
  happens
- the final width: 89 mm for one column or 183 mm for two. The height follows the chosen option, no
  more than the width unless the content runs vertically, up to 247 mm

Everything drawn is an entity or relation in the brief. A number appears only when the source gives
it. If nothing relates to anything, say so and suggest a table.

Where this skill asks the user to choose and nobody is there, choose yourself and record the choice
and why in `notes.md`.

## Build

Write Python that outputs SVG, with text as text. Render with what the environment has, such as
CairoSVG, rsvg-convert, Inkscape or a headless browser, and record which in `notes.md`. The reviews
need renders, so if nothing can render, say so and stop. Review renders are PNGs at final size and
300 dpi. With each render, have the script write a label list, one row per text with its size in
points.

Draw organs, cells and molecules as paths in the script, in the style record's rendering. A simple
shape drawn well beats a detailed one drawn badly. View the six [bundled examples](assets/examples/)
before drawing, with any example figures or assets the user supplies, and give the examples to every
reviewer. The user's examples lead where the two differ.

Reviewers are fresh subagents. Give each one the render's label list with the opening and its own
section of [references/reviewer.md](references/reviewer.md), and save each report as it comes back
under `review/`. If the host cannot start subagents, say so, review from the PNG alone yourself, and
label the delivery self-reviewed.

1. **Options.** Draw three options as rough drafts in `options/`: placed, labelled and connected,
   without polish. They share the science and differ broadly in design: the composition type from
   the style record, the orientation, what sits at the centre, how much surrounding context is
   drawn, and the rendering, from fuller illustration to sparer diagram. No two should read as small
   edits of each other. Check each against the brief and remove whatever the brief lacks.

   Three pickers choose. Give each the options under letters in its own random order, with the
   brief, the style record and the examples. Score first, second and third as 1, 2 and 3 and take
   the lowest sum, breaking a tie by first places. If the user is there, show them the options and
   the ranking; they may overrule it. Apply the pickers' fixes for the winner before round one.

2. **Review loop.** Run five rounds on the chosen option, one after another. A round reviews the
   current render, revises it, then compares.
   - Review. A scorer and an adversary work in parallel, each with the PNG, its size and dpi, the
     label list, the brief, the style record, the examples and `settled.md`. Neither sees the
     other's report, earlier renders or your reasoning.
   - Revise. Check each adversary claim against the PNG and the brief before acting, since its job
     is to over-report. Fix confirmed blockers first, then the scorer's repairs. Record in
     `settled.md` each claim you rejected and each design decision you made, with its reason, so
     later reviewers do not reopen it. Save the script and render as `rounds/N.py` and
     `rounds/N.png`.
   - Compare. A judge gets the render from before the round and the one after it as X and Y in
     random order. Keep the revision when the judge prefers it, or calls a tie and the revision
     fixed a confirmed blocker. Otherwise discard it. A discarded round still counts. The next round
     skips its review and revises the same render from the same reviews with a different repair.

   After round five, one more adversary checks the current render. Fix confirmed defects that a
   small edit can fix, and have a judge confirm the edit did not make the figure worse. A confirmed
   blocker that remains makes the delivery a draft, and the report says so.

3. **Deliver** the SVG, PDF and a PNG at 300 dpi or more, with the build script, brief, options,
   rounds, reviewer reports, a review log of each round's scores, blockers and judge verdict, and a
   draft caption that repeats the key. Reopen the exports and check size, appearance and that text
   is still text. Report what you could not verify.

## Rules

- Give the main relationship visual priority. Comparable objects keep comparable sizes.
- A box marks a group or boundary the source defines, never every step.
- Each line style, tint and mark has one meaning, such as process, inhibition or movement. A key in
  the figure names each one that is not labelled in place.
- Take style from the style record and the examples, never their artwork.
