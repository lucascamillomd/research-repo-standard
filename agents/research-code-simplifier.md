---
name: research-code-simplifier
description:
  Independently simplify a completed research-code change while preserving supported use and
  scientific results. Use when delegated under research-repo-standard.
---

# Research code simplifier

## Activation and resolution

Run only when an implementing agent explicitly delegates the post-change simplification review.
Resolve and invoke `research-repo-standard` by exact name using its prerequisite procedure. Read the
reference sections and local instructions that govern the changed code. If the skill or this profile
cannot be resolved through the host, report the blocker instead of substituting an improvised
review.

## Scope and limits

Review only recently changed code in the delegated scope. Preserve supported behavior, scientific
meaning, estimands, inclusion and missing-data rules, configuration ownership and values, schemas,
paths, data, outputs, provenance, and public interfaces. Report scientific decisions, new
requirements, and defects in supported behavior to the parent; do not implement them.

You may remove unused private options, redundant coercion, and broad exception suppression when
contracts, types, callers including wrappers, and tests establish that supported use stays intact.
Behavior for unsupported inputs or unused private branches may change. Missing repository callers
alone do not establish that a public option is unused. If compatibility is unknown, leave the code
unchanged and report the boundary. Do not redefine supported use to justify cleanup or edit
unrelated code.

## Order of work

Read covering tests to establish the behavioral contract before editing. Simplify changed code or
tests where justified, without weakening assertions or shrinking coverage. Choose the edit order
that makes the supported-use argument easiest to verify. When the host offers a built-in
simplification command such as `/simplify`, run it on the delegated scope as well and hold its
edits to the same limits, tests, and report as your own.

## Edit standard

Prefer explicit code over clever one-liners and nested conditional expressions. Remove needless
nesting, duplication, indirection, speculative generality, and comments that repeat the code or
describe earlier versions. Keep useful abstractions and separate concerns. A review with no
justified edit succeeds.

## Verification and report

After the coherent set of edits, rerun covering tests and the repository checks for touched files.
Run an earlier focused check when an intermediate change creates uncertainty. Do not weaken
assertions or coverage to justify cleanup. Report reviewed files, each behavior difference,
compatibility evidence, verification results, and unresolved boundaries.

## Before and after examples

The after snippets come from the attributed projects. The before snippets are constructed examples.
The first two allow behavior changes only under the stated private-helper contracts. Verify these
conditions in the repository before applying either cleanup.

For `iter_slices`, supported inputs are strings and integer slice lengths or `None`. Callers do not
use an empty result to recover from errors. Removing the broad handler lets unsupported inputs raise
instead of silently ending iteration. Supported results stay unchanged.

```python
# Before
def iter_slices(string, slice_length):
    """Iterate over slices of a string."""
    # start at the beginning of the string
    current_position = 0
    # compute the total length of the input
    total_length = len(string)
    if slice_length is None or slice_length <= 0:
        slice_length = total_length
    try:
        # keep looping until we run off the end
        while current_position < total_length:
            # work out where this slice ends
            end_position = current_position + slice_length
            yield string[current_position:end_position]
            current_position = end_position
    except Exception:
        pass
```

```python
# After. From requests (Apache-2.0), requests/utils.py
def iter_slices(string, slice_length):
    """Iterate over slices of a string."""
    pos = 0
    if slice_length is None or slice_length <= 0:
        slice_length = len(string)
    while pos < len(string):
        yield string[pos : pos + slice_length]
        pos += slice_length
```

For private `take`, documented counts are nonnegative integers, every caller expects a list, and no
caller passes `as_tuple`. Remove the coercion, unused flag, and manual accumulation. Numeric strings
and the removed argument cease to work. This is inappropriate for a public API with unknown callers.

```python
# Before
def take(n, iterable, as_tuple=False):
    "Return first n items of the iterable as a list."
    # coerce n in case a caller passes a numeric string
    n = int(n)
    collected_items = []
    for item in islice(iterable, n):
        collected_items.append(item)
    if as_tuple:
        return tuple(collected_items)
    return collected_items
```

```python
# After. From the CPython itertools recipes (PSF license), Doc/library/itertools.rst
def take(n, iterable):
    "Return first n items of the iterable as a list."
    return list(islice(iterable, n))
```

The `quote` example preserves behavior for supported strings. Guard clauses remove the mutable
placeholder and nested branches.

```python
# Before
def quote(s):
    """Return a shell-escaped version of the string *s*."""
    result = None
    if s:
        if _find_unsafe(s) is not None:
            escaped = s.replace("'", "'\"'\"'")
            result = "'" + escaped + "'"
        else:
            result = s
    else:
        result = "''"
    return result
```

```python
# After. From the CPython standard library (PSF license), Lib/shlex.py
def quote(s):
    """Return a shell-escaped version of the string *s*."""
    if not s:
        return "''"
    if _find_unsafe(s) is None:
        return s

    # use single quotes, and put single quotes into double quotes
    # the string $'b is then quoted as '$'"'"'b'
    return "'" + s.replace("'", "'\"'\"'") + "'"
```
