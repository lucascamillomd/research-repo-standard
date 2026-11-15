---
name: cowrite-manuscript
description:
  Use when the user wants to write, continue or restructure a LaTeX manuscript with you, such as a
  paper, brief communication, letter or preprint, including "let's write up the paper" or "let's
  write the methods". Writes one paragraph at a time with the user and keeps the manuscript in
  `docs/manuscript/`. Not for polishing finished prose or answering reviewers.
---

# Co-write a manuscript

The user is the author. Write with them one paragraph at a time, so that every paragraph is one they
wrote or chose. Never draft ahead of the paragraph in hand.

## Start

Ask which journal and which article type, unless the user gave them. Write nothing before you know
both.

Then read the journal's current instructions for that type and note its limits: words, abstract,
display items, references, sections and legend length, with the page and the date you read it. If
you cannot read them, say so and list the limits as unverified. A limit from memory is unverified.

## Layout

Create what is missing under `docs/manuscript/`. Leave existing files as they are, except to add
`bundle/` to `.gitignore`:

```text
docs/manuscript/
├── main.tex            title, authors, abstract, main text and main display items
├── methods.tex
├── declarations.tex    availability, acknowledgements, contributions, competing interests
├── supplementary.tex   also compiles on its own
├── preamble.tex        packages and formatting
├── references.bib
├── build.sh            copy of this skill's assets/build.sh
├── .gitignore          ignores bundle/
├── figures/            the PDF of each figure the manuscript includes
├── tables/             each table the manuscript includes
└── bundle/             ignored by git: LaTeX build files and TODO.md
```

`main.tex` inputs `methods.tex` and `declarations.tex`. A new `.tex` file holds structure and no
prose. `figures/` and `tables/` hold copies of finished results: change a figure or table where it
is made, then copy it again. `build.sh` compiles `main.tex` and `supplementary.tex` in `bundle/` and
puts the PDFs beside `main.tex`.

In a repository that follows `research-repo`, the manuscript reports its approved analyses. A new
claim, result or figure goes through that skill first, and its `references/figures.md` owns where
figure files come from.

## To-do list

Write `bundle/TODO.md`: the limits, then one checkbox per step in this order, without the sections
the article type lacks.

1. Main text: introduction and results
2. Discussion
3. Abstract and title
4. Methods
5. Declarations, supplement and references
6. Figure and table legends, last
7. Checks

Tick a box when its step is done. In a later session, read the list and resume at the first open
box.

## Each section

1. **Outline.** Read the results, then propose one line per paragraph: `P0`, what it says and the
   result, figure or table it rests on, then `P1`, and so on. The user changes or approves it. Draft
   nothing before that.
2. **Paragraphs,** one per turn and in order. Read the file again first, because the user edits it
   too.
   - Suggest the paragraph in plain, direct prose: put it in the `.tex` file and show it in your
     reply. The user edits it or tells you what to change.
   - When the user wrote the paragraph, leave their wording. Say what you found: a number that
     differs from its results file, a claim the evidence does not carry, a sentence that needs a
     source, length against the limit. Rewrite only if asked.
   - Add anything useful for the next step, such as what a reviewer may ask or the words left. Then
     stop for the user. Stay on a paragraph until they accept it or say to move on.
3. **Build** the PDF, fix LaTeX errors and tick the box.

## Facts

- Every number comes from a results file, which you name. If a result does not exist, say so and
  wait for it.
- Cite only a reference you have checked exists and supports the sentence. Otherwise leave a visible
  to-do in the text.
- Author details, funding, ethics and accession numbers come from the user. Leave a visible to-do
  for each one missing.

## Skills

Resolve each skill by its exact name when its step comes. If one is missing, say so and continue
without it. In a repository that follows `research-repo`, follow its `references/prerequisites.md`
instead.

| Step                                      | Skill                 |
| ----------------------------------------- | --------------------- |
| Outlines, paragraph suggestions, abstract | `nature-writing`      |
| Tightening a settled paragraph on request | `nature-polishing`    |
| Statistics in methods and legends         | `nature-statistics`   |
| Finding a source for a sentence           | `nature-citation`     |
| Checking `references.bib`                 | `nature-ref-verifier` |
| Data and code availability                | `nature-data`         |
| Figures and their legends                 | `nature-figure`       |
| Mock review at the checks step            | `nature-reviewer`     |

## Checks

Before calling the manuscript done, verify the references, audit the statistics, run a mock review,
count words, display items and references against the limits, and list every to-do left in the text.
Report what is open.
