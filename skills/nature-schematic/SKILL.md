---
name: nature-schematic
description:
  Use when making, revising or reviewing a scientific schematic, such as a mechanism, pathway,
  workflow, model architecture, disease progression, multi-organ overview or graphical abstract, for
  a paper, review or grant, especially in the style of Nature figures. Not for plots of data.
---

# Nature-style schematics

Build a schematic as editable vector art in the style recorded in
[references/style.md](references/style.md). No image-generation model takes part. Every shape is
drawn in code or comes from an asset whose source, licence and credit line you record.

In a repository that follows `research-repo-standard`, its `references/figures.md` owns paths,
names, export formats and records.

## Brief

Before drawing, write `brief.md` from the source:

- the one claim a reader should take away
- each entity and compartment, with its exact label
- each relation, with its endpoints, type, certainty and place in the source, such as "cGAS makes
  cGAMP (section 2, paragraph 1)"
- what the source leaves open and the drawing must not decide, such as where on a route a step
  happens
- the width, 89 mm for one column or 183 mm for two. The height follows the chosen option, up to 247
  mm.

Everything drawn is an entity or relation in the brief. If nothing relates to anything, say so and
suggest a table. If the user is unavailable, make their choices and record why in the brief.

## Drawing

View the six [bundled examples](assets/examples/) before drawing, with any examples or assets the
user supplies. Where the two differ, follow the user's. Take style from the style record and the
examples, never their artwork.

Write Python that outputs SVG, with text as text. Draw organs, cells and molecules as paths, and
prefer a simple shape drawn well to a detailed one drawn badly. A box marks a group or boundary the
source defines, never every step. Each line style, tint and mark has one meaning, and a key in the
figure names each one that is not labelled in place.

Review renders are PNGs at final size and 300 dpi, each with a label list from the script that gives
every text and its size in points. If nothing can render the SVG, say so and stop.

## Steps

Reviewers are fresh subagents: pickers, critics and judges. Give the examples to every reviewer,
with the brief, the style record, each render's size, dpi and label list, and the opening and its
own section of [references/reviewer.md](references/reviewer.md). Save each report under `review/`.
If the host cannot start subagents, say so, review from the PNG alone yourself, and label the
delivery self-reviewed.

1. **Options.** Draw three options as rough drafts in `options/`: placed, labelled and connected,
   without polish. They share the science and differ broadly in composition, orientation, centre,
   amount of context and rendering, from full illustration to spare diagram. Three pickers rank them
   independently, lettered in a different random order for each. The lowest rank sum wins, and first
   places break a tie. If the user is there, show them the options and the ranking, which they may
   overrule. Apply the pickers' fixes for the winner.

2. **Rounds.** Run five rounds on the winner, one after another.
   - Review. A critic gets the current PNG and `settled.md`, without earlier renders or your
     commentary.
   - Revise. Check each claim against the PNG and the brief before acting. Fix confirmed blockers
     first, then the named repairs. Record each rejected claim in `settled.md`, with its reason.
     Save the script and render as `rounds/N.py` and `rounds/N.png`.
   - Compare. A judge gets the renders from before and after the round as X and Y in random order.
     Keep the revision if the judge prefers it, or calls a tie and it fixed a confirmed blocker, and
     add its design decisions to `settled.md`. Otherwise discard it. A discarded round still counts,
     and the next round skips review and tries another repair from the same report, or gets a fresh
     review if none is left.

   After round five, one more critic checks the kept render. Fix confirmed defects that a small edit
   can fix, check the edit against the brief, and keep it unless a judge prefers the render before
   it. If a confirmed blocker remains, label the delivery a draft in your report.

3. **Deliver** the SVG, PDF and a PNG at 300 dpi or more, with the build script, brief, options,
   rounds and reports. Add a log of each round's blockers and judge verdict, and a draft caption
   that repeats the key. Reopen the exports and check size, appearance and that text is still text.
   Report what you could not verify.
