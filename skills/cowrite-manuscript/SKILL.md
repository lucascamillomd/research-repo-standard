---
name: cowrite-manuscript
description:
  Use when the user wants to write, continue or restructure a LaTeX manuscript with you, such as a
  paper, brief communication or preprint, including "let's write up the paper". Writes one paragraph
  at a time with the user in `docs/manuscript/`. Not for polishing finished prose or answering
  reviewers.
---

# Co-write a manuscript

The user is the author. Write one paragraph at a time with them. Never draft ahead of the paragraph
in hand.

## Start

Ask which journal and which article type, unless the user gave both. Write nothing until you know
them.

Read the journal's current instructions for that type. Note its limits on words, abstract, display
items, references, sections and legends, with the page and the date. A limit you could not read, or
one from memory, is unverified. Say so.

## Layout

Create what is missing under `docs/manuscript/`. Leave existing files alone, except to add `bundle/`
to `.gitignore`.

```text
docs/manuscript/
├── main.tex            title, authors, abstract, main text and main display items
├── methods.tex
├── declarations.tex    availability, acknowledgements, contributions, competing interests
├── supplementary.tex   compiles on its own
├── preamble.tex        packages and formatting
├── references.bib
├── build.sh            copy of this skill's assets/build.sh
├── .gitignore          ignores bundle/
├── figures/            the PDF of each figure the manuscript includes
├── tables/             each table the manuscript includes
└── bundle/             ignored by git: LaTeX build files and TODO.md
```

`main.tex` inputs `methods.tex` and `declarations.tex`. A new `.tex` file holds structure and no
prose. `figures/` and `tables/` hold copies of finished results. Change a figure or table where it
is made, then copy it again. `build.sh` compiles in `bundle/` and puts the PDFs beside `main.tex`.

In a repository that follows `research-repo`, a new claim, result or figure goes through that skill
first. Its `references/figures.md` owns where figure files come from.

## To-do list

Write `bundle/TODO.md` with the limits and one checkbox per step, in this order. Skip sections the
article type lacks.

1. Main text: introduction and results
2. Discussion
3. Abstract and title
4. Methods
5. Declarations, supplement and references
6. Figure and table legends, last
7. Checks

Tick each box when its step is done. In a later session, resume at the first open box.

## Each section

1. **Outline.** Read the results. Propose one line per paragraph, `P0`, `P1` and so on. Each line
   says what the paragraph claims and the result, figure or table behind it. Draft nothing until the
   user approves the outline.
2. **Paragraphs.** Take one paragraph per turn, in order. Read the file again first, because the
   user edits it too.
   - To suggest a paragraph, write it in plain prose into the `.tex` file and show it in your reply.
   - When the user wrote the paragraph, leave their wording. Report a number that differs from its
     results file, a claim the evidence does not carry, a sentence that needs a source, and length
     against the limit. Rewrite only if asked.
   - Add what helps the next step, such as a likely reviewer question or the words left. Then stop.
     Stay on the paragraph until the user accepts it or moves on.
3. **Build.** Build the PDF, fix LaTeX errors and tick the box.

## Facts

- Take every number from a results file and name the file. If a result does not exist, say so and
  wait.
- Cite only a reference you have checked exists and supports the sentence. Otherwise leave a visible
  to-do.
- Author details, funding, ethics and accession numbers come from the user. Leave a visible to-do
  for each one missing.

## Skills

Resolve each skill by exact name when its step comes. If one is missing, say so and continue without
it. In a repository that follows `research-repo`, follow its `references/prerequisites.md` instead.

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

Before you call the manuscript done, verify the references, audit the statistics, run a mock review,
and count words, display items and references against the limits. List every to-do left in the text.
