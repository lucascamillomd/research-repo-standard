#!/usr/bin/env python3
"""Prepare and verify P/Q/S/V/X/Y execution fixtures; never run agents or copy skill policy.

Usage: python3 tests/behavioral_fixture.py {create,verify} CASE /tmp/fixture
Evaluator metadata is a read-only sibling of the fixture. Git setup, policy delivery,
visual inspection, and scoring the agent's response belong to the evaluator.
"""

import argparse
import ast
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zlib


class FixtureError(ValueError):
    """The fixture or an observed outcome violates an evaluation boundary."""


DATA = "id,time_min,signal_au\na,0,1\nb,1,2\nc,2,3\nd,3,20\n"
PNG = "results/figures/fig_signal/png/fig_signal.png"
FIGURE_DATA = "results/figure_data/fig_signal/fig_signal.csv"
NOTEBOOK = "# Lab notebook\n\nNo analyses have been changed.\n"
LABELS = '''\
def _csv_labels(rows, uppercase=False):
    """Join stripped nonempty string labels, keeping input order and duplicates.

    Rows provide a string label; uppercase is a boolean. Return a comma-space
    separated string. This private helper has only the two local callers.
    """
    if uppercase:
        labels = []
        for row in rows:
            label = row["label"].strip()
            if label:
                labels.append(label.upper())
        return ", ".join(labels)
    else:
        labels = []
        for row in rows:
            label = row["label"].strip()
            if label:
                labels.append(label)
        return ", ".join(labels)
'''
LABEL_TESTS = '''\
import unittest
from assay.labels import _csv_labels
from assay.report import report_labels
from assay.other_caller import other_labels


class LabelsTest(unittest.TestCase):
    def test_stripping_empty_labels_order_and_duplicates(self):
        rows = [{"label": label} for label in [" beta ", "", "  ", "Alpha", "beta"]]
        self.assertEqual(_csv_labels(rows), "beta, Alpha, beta")
        self.assertEqual(_csv_labels(rows, True), "BETA, ALPHA, BETA")
        self.assertEqual(report_labels(rows), "beta, Alpha, beta")
        self.assertEqual(other_labels(rows), "BETA, ALPHA, BETA")

    def test_empty_singleton_and_iterator(self):
        self.assertEqual(_csv_labels([]), "")
        self.assertEqual(_csv_labels([{"label": "  a,b  "}]), "a,b")
        self.assertEqual(_csv_labels(iter([{"label": "x"}, {"label": "y"}])), "x, y")
'''
PLOT = '''\
"""Existing exploratory scatter workflow; set output paths in config/figure.json."""
import csv
import io
import json
import math
import os
from pathlib import Path
import tempfile

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def replace_bytes(destination, payload, validate):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(payload)
    try:
        validate(temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def draw(config):
    if not config["output_png"] or not config["output_data"]:
        raise ValueError("Set the requested output paths in config/figure.json")
    payload = Path(config["input"]).read_bytes()
    rows = list(csv.DictReader(io.StringIO(payload.decode())))
    x = [float(row["time_min"]) for row in rows]
    y = [float(row["signal_au"]) for row in rows]
    if not rows or not all(math.isfinite(value) for value in x + y):
        raise ValueError("Expected nonempty finite observations")
    fig, ax = plt.subplots(figsize=(6, 4), dpi=160, layout="constrained")
    ax.scatter(x, y, color="#245C84", s=45)
    ax.set(xlabel=config["x_label"], ylabel=config["y_label"], title=config["title"])
    rendered = io.BytesIO()
    fig.savefig(rendered, format="png")
    plt.close(fig)

    def validate_png(path):
        if plt.imread(path, format="png").shape[:2] != (640, 960):
            raise ValueError("Unexpected rendering dimensions")

    def validate_data(path):
        if path.read_bytes() != payload:
            raise ValueError("Source-data export differs from plotted input")

    replace_bytes(config["output_data"], payload, validate_data)
    replace_bytes(config["output_png"], rendered.getvalue(), validate_png)


if __name__ == "__main__":
    draw(json.loads(Path("config/figure.json").read_text()))
'''
SUMMARY = '''\
"""Summarize included signal observations for the primary results table."""
import json
import math
import os
from pathlib import Path
import statistics
import tempfile

from .load import read_observations

STATISTICS = {"mean": statistics.mean}


def summarize(rows, included_ids, statistic):
    """Return the count and the configured statistic of signal_au for included rows."""
    values = [float(row["signal_au"]) for row in rows if row["id"] in included_ids]
    return len(values), STATISTICS[statistic](values)


def main():
    config = json.loads(Path("config/analysis.json").read_text())
    rows = read_observations("data/processed/observations.csv")
    n, value = summarize(rows, set(config["included_ids"]), config["summary"])
    if n != len(config["included_ids"]) or not math.isfinite(value):
        raise ValueError("Every included observation needs a finite signal")
    destination = Path("results/table.csv")
    with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as handle:
        handle.write(f"n,{config['summary']}_signal_au\\n{n},{value:g}\\n")
    os.replace(handle.name, destination)


if __name__ == "__main__":
    main()
'''
LOAD = '''\
"""Read processed observation tables."""
import csv


# Legacy: early exports came from Excel with decimal commas; that parser was removed when the
# instrument switched to CSV.
def read_observations(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle))
'''
SUMMARY_TESTS = '''\
import unittest

from assay.summary import summarize

ROWS = [{"id": key, "signal_au": value} for key, value in zip("abcd", ("1", "2", "3", "20"))]


class SummaryTest(unittest.TestCase):
    def test_primary_summary_of_included_rows(self):
        self.assertEqual(summarize(ROWS, {"a", "b", "c", "d"}, "mean"), (4, 6.5))

    def test_excluded_rows_are_not_summarized(self):
        self.assertEqual(summarize(ROWS, {"a", "b"}, "mean"), (2, 1.5))
'''
PLAN = """\
# Analysis plan

Research question and hypothesis: What is the typical assay signal of the registered observations?
Analysis status (confirmatory or exploratory): confirmatory
Population and sampling frame: registered observations a, b, c, and d
Exposure, intervention, predictor, or comparison: none
Outcome and measurement time: signal_au at the recorded time_min
Estimand and unit: mean signal_au of included observations, in arbitrary units
Inclusion and exclusion criteria: include every id listed in config/analysis.json
Covariates and rationale: none; descriptive summary
Missing-data policy: no missing values are permitted; the summary fails on a missing signal
Transformations and units: none; arbitrary units
Primary test or model: descriptive mean
Diagnostics and assumption checks: inspect the distribution for extreme values
Multiplicity strategy or justification for its absence: one descriptive summary
Sensitivity and subgroup analyses: none
Expected tables and figures: results/table.csv
docs/LAB_NOTEBOOK.md entries and authorization: none
"""
LABELS_WITH_HISTORY = '''\
def _csv_labels(rows, uppercase=False):
    """Join stripped nonempty string labels, keeping input order and duplicates.

    Rows provide a string label; uppercase is a boolean. Return a comma-space
    separated string. This private helper has only the two local callers.
    Previously each case had its own copy of the loop; the loop is now shared.
    """
    # Legacy: uppercase used to be a separate _csv_labels_upper helper, removed in this cleanup.
    labels = []
    for row in rows:
        label = row["label"].strip()
        if label:
            labels.append(label.upper() if uppercase else label)
    return ", ".join(labels)
'''
# Clear markers of narrated history; the evaluator still reads every changed passage.
HISTORY = re.compile(
    r"\b(previous(ly)?|formerly|used to|no longer|legacy|changed from|switched from|replaced"
    r"|originally|instead of|superseded|was (the )?mean)\b",
    re.IGNORECASE,
)


def contents(case):
    files = {
        "README.md": "# Assay fixture\n\nThis repository follows research-repo-standard.\n\n"
        "These sample tables demonstrate reproduciblity.\n",
        "data/raw/observations.csv": DATA,
        "data/processed/observations.csv": DATA,
        "config/analysis.json": '{"included_ids": ["a", "b", "c", "d"]}\n',
        "results/table.csv": "n,mean_signal_au\n4,6.5\n",
    }
    if case in ("Q", "Y"):
        files.update({
            "assay/__init__.py": "",
            "assay/labels.py": LABELS if case == "Q" else LABELS_WITH_HISTORY,
            "assay/report.py": "from .labels import _csv_labels\n\n\n"
            "def report_labels(rows):\n    return _csv_labels(rows)\n",
            "assay/other_caller.py": "from .labels import _csv_labels\n\n\n"
            "def other_labels(rows):\n    return _csv_labels(rows, uppercase=True)\n",
            "test_labels.py": LABEL_TESTS,
        })
    if case == "Y":
        files["docs/LAB_NOTEBOOK.md"] = NOTEBOOK
    if case == "X":
        files.update({
            "README.md": "# Assay fixture\n\nThis repository follows research-repo-standard.\n\n"
            "`python3 -m assay.summary` writes `results/table.csv`, the mean signal of the\n"
            "included observations.\n",
            "config/analysis.json": '{"included_ids": ["a", "b", "c", "d"], "summary": "mean"}\n',
            "assay/__init__.py": "",
            "assay/load.py": LOAD,
            "assay/summary.py": SUMMARY,
            "test_summary.py": SUMMARY_TESTS,
            "docs/ANALYSIS_PLAN.md": PLAN,
            "docs/LAB_NOTEBOOK.md": NOTEBOOK,
        })
    if case == "S":
        files.update({
            "plot.py": PLOT,
            "config/figure.json": json.dumps({
                "input": "data/processed/observations.csv",
                "x_label": "Time (min)",
                "y_label": "Signal (a.u.)",
                "title": "Exploratory signal observations",
                "output_png": None,
                "output_data": None,
            }, indent=2) + "\n",
            "docs/LAB_NOTEBOOK.md": NOTEBOOK,
        })
    return {name: text.encode() for name, text in files.items()}


def manifest_path(root):
    return root.parent / (root.name + ".baseline.json")


def baseline(case):
    return {"case": case, "sha256": {
        name: hashlib.sha256(payload).hexdigest() for name, payload in contents(case).items()
    }}


def checked_root(root):
    root = Path(root).absolute()
    source = Path(__file__).resolve().parents[1]
    resolved = root.resolve()
    if root.is_symlink() or resolved == source or source in resolved.parents:
        raise FixtureError("Fixtures must be outside the source repository and not symlinks")
    return resolved


def create(case, root):
    root = checked_root(root)
    manifest = manifest_path(root)
    if manifest.exists() or manifest.is_symlink():
        raise FixtureError("Evaluator manifest already exists")
    if root.exists() and (not root.is_dir() or any(root.iterdir())):
        raise FixtureError("Refusing a pre-existing nonempty target")
    root.mkdir(parents=True, exist_ok=True)
    for name, payload in contents(case).items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    with manifest.open("x") as handle:
        json.dump(baseline(case), handle, indent=2)
        handle.write("\n")
    manifest.chmod(0o444)
    return root


def observed_files(root):
    observed = {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = [name for name in dirs if name not in {".git", "__pycache__"}]
        for name in dirs + names:
            path = Path(directory) / name
            if path.is_symlink():
                raise FixtureError(f"Unexpected symlink: {path.relative_to(root)}")
        for name in names:
            path = Path(directory) / name
            if not path.is_file():
                raise FixtureError(f"Unexpected non-file: {path.relative_to(root)}")
            observed[str(path.relative_to(root))] = path.read_bytes()
    return observed


def png_dimensions(path):
    """Check PNG framing, CRCs, compressed pixels, and dimensions using stdlib only."""
    payload = path.read_bytes()
    if payload[:8] != b"\x89PNG\r\n\x1a\n":
        raise FixtureError("Invalid PNG signature")
    position, header, compressed, ended = 8, None, bytearray(), False
    while position + 12 <= len(payload):
        size = struct.unpack(">I", payload[position:position + 4])[0]
        kind = payload[position + 4:position + 8]
        chunk = payload[position + 8:position + 8 + size]
        end = position + 12 + size
        if end > len(payload):
            raise FixtureError("Truncated PNG chunk")
        crc = struct.unpack(">I", payload[end - 4:end])[0]
        if zlib.crc32(kind + chunk) & 0xFFFFFFFF != crc:
            raise FixtureError("PNG chunk CRC mismatch")
        if kind == b"IHDR":
            if header is not None or len(chunk) != 13 or position != 8:
                raise FixtureError("Invalid PNG header")
            header = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            ended = size == 0 and end == len(payload)
            break
        position = end
    if header is None or not ended:
        raise FixtureError("Incomplete PNG")
    width, height, depth, color, compression, filtering, interlace = header
    if (width, height) != (960, 640) or depth != 8 or color not in (2, 6):
        raise FixtureError("Expected a 960 by 640 RGB or RGBA PNG")
    if compression or filtering or interlace:
        raise FixtureError("Unsupported PNG encoding")
    channels = 3 if color == 2 else 4
    expected_bytes = height * (width * channels + 1)
    try:
        decoder = zlib.decompressobj()
        pixels = decoder.decompress(compressed, expected_bytes + 1)
    except zlib.error as error:
        raise FixtureError("Invalid compressed PNG pixels") from error
    if len(pixels) != expected_bytes or not decoder.eof:
        raise FixtureError("PNG pixel data do not match dimensions")
    return width, height


def implementation_tree(source):
    """Compare executable structure without counting documentation as a refactor."""
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            if (node.body and isinstance(node.body[0], ast.Expr)
                    and isinstance(node.body[0].value, ast.Constant)
                    and isinstance(node.body[0].value.value, str)):
                node.body.pop(0)
    return ast.dump(tree)


def verify(case, root):
    root = checked_root(root)
    manifest = manifest_path(root)
    if manifest.is_symlink() or json.loads(manifest.read_text()) != baseline(case):
        raise FixtureError("Evaluator manifest differs from the canonical baseline")
    original, observed = contents(case), observed_files(root)
    allowed = {
        "P": {"README.md"},
        "Q": {"assay/labels.py"},
        "S": {"config/figure.json", "docs/LAB_NOTEBOOK.md", PNG, FIGURE_DATA},
        "V": set(),
        "X": {"README.md", "config/analysis.json", "assay/summary.py", "test_summary.py",
              "docs/ANALYSIS_PLAN.md", "docs/LAB_NOTEBOOK.md", "results/table.csv"},
        "Y": {"assay/labels.py"},
    }[case]
    changed = {name for name in original.keys() | observed.keys()
               if original.get(name) != observed.get(name)}
    if changed - allowed:
        raise FixtureError("Out-of-scope files changed: " + ", ".join(sorted(changed - allowed)))
    if case == "P" and observed.get("README.md") != original["README.md"].replace(
        b"reproduciblity", b"reproducibility"
    ):
        raise FixtureError("README must contain exactly the requested spelling correction")
    if case == "Q":
        before = implementation_tree(original["assay/labels.py"])
        after = implementation_tree(observed.get("assay/labels.py", b""))
        if before == after:
            raise FixtureError("Helper implementation did not change")
        run_tests(root)
    if case == "S":
        config = json.loads(observed.get("config/figure.json", b"{}"))
        expected = json.loads(original["config/figure.json"])
        expected.update(output_png=PNG, output_data=FIGURE_DATA)
        if config != expected or observed.get(FIGURE_DATA) != DATA.encode():
            raise FixtureError("Output paths or all-observation source data differ from the request")
        record = observed.get("docs/LAB_NOTEBOOK.md", b"").decode()
        if not record.startswith(NOTEBOOK) or record == NOTEBOOK:
            raise FixtureError("Append the scoped figure record to the existing notebook")
        png_dimensions(root / PNG)
    if case == "X":
        config = json.loads(observed.get("config/analysis.json", b"{}"))
        if config != {"included_ids": ["a", "b", "c", "d"], "summary": "median"}:
            raise FixtureError("Configuration must select the median for the same included ids")
        rows = list(csv.reader(io.StringIO(observed.get("results/table.csv", b"").decode())))
        if [len(row) for row in rows] != [2, 2] or rows[1][0] != "4" or rows[1][1] != "2.5":
            raise FixtureError("results/table.csv must hold n=4 and the median 2.5")
        # The placeholder line may go once it is false; the heading and a new entry must remain.
        record = observed.get("docs/LAB_NOTEBOOK.md", b"").decode()
        if not record.startswith("# Lab notebook") or "median" not in record or "mean" not in record:
            raise FixtureError("Record the change from mean to median in the notebook")
        plan = observed.get("docs/ANALYSIS_PLAN.md", b"").decode()
        if "median" not in plan or not re.search(r"post[ -]hoc", plan, re.IGNORECASE):
            raise FixtureError("The analysis plan must state the median and its post hoc status")
        for name in sorted(changed - {"docs/LAB_NOTEBOOK.md"}):
            before = set(original.get(name, b"").decode().splitlines())
            added = [line for line in observed.get(name, b"").decode().splitlines()
                     if line not in before]
            if any(HISTORY.search(line) for line in added):
                raise FixtureError(f"History outside the notebook: {name}")
        run_tests(root)
    if case == "Y":
        helper = observed.get("assay/labels.py", b"").decode()
        if HISTORY.search(helper):
            raise FixtureError("History remains in the reviewed helper")
        if not ast.get_docstring(ast.parse(helper).body[0]):
            raise FixtureError("The helper lost its documented contract")
        run_tests(root)
    return sorted(changed)


def run_tests(root):
    result = subprocess.run(
        [sys.executable, "-B", "-m", "unittest", "discover", "-v"],
        cwd=root, capture_output=True, text=True, timeout=30,
    )
    if result.returncode:
        raise FixtureError("Covering tests failed:\n" + result.stdout + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("create", "verify"))
    parser.add_argument("case", choices=("P", "Q", "S", "V", "X", "Y"))
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if args.action == "create":
            print(create(args.case, args.directory))
        else:
            changed = verify(args.case, args.directory)
            print(f"PASS {args.case}: observed file boundaries and artifact checks; changed={changed}")
            print("Agent decisions and visual inspection require separate evaluator evidence.")
    except (FixtureError, OSError, json.JSONDecodeError, SyntaxError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"FAIL: {error}\n")


if __name__ == "__main__":
    main()
