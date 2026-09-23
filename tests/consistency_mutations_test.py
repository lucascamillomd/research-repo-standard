#!/usr/bin/env python3
"""Test documentation guards against isolated source snapshots, never target repositories.

These tests prove that selected safeguard removals are detected and harmless formatting
is accepted. They do not execute a research workflow or certify agent behavior.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest


SOURCE = Path(__file__).resolve().parents[1]
CHECKER = SOURCE / "tests" / "consistency_test.sh"


class ConsistencyMutations(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="rrs-source-snapshot-")
        self.addCleanup(self.temporary.cleanup)
        self.snapshot = Path(self.temporary.name) / "source"
        shutil.copytree(
            SOURCE,
            self.snapshot,
            ignore=shutil.ignore_patterns(".git", ".venv", "node_modules", "__pycache__"),
        )

    def run_checker(self):
        environment = os.environ.copy()
        environment["RRS_TEST_ROOT"] = str(self.snapshot)
        return subprocess.run(
            ["/bin/bash", str(CHECKER)],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

    def remove_paragraph(self, relative_path, marker):
        path = self.snapshot / relative_path
        blocks = re.split(r"(\n\s*\n)", path.read_text())
        matches = [index for index in range(0, len(blocks), 2) if marker in blocks[index]]
        self.assertEqual(len(matches), 1, f"Expected one paragraph containing {marker!r}")
        blocks[matches[0]] = ""
        path.write_text("".join(blocks))

    def remove_phrase(self, relative_path, pattern):
        path = self.snapshot / relative_path
        changed, count = re.subn(pattern, "", path.read_text(), flags=re.DOTALL)
        self.assertEqual(count, 1, f"Expected one occurrence of {pattern!r}")
        path.write_text(changed)

    def assert_rejected_by(self, contract):
        result = self.run_checker()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"FAIL: {contract}", result.stdout, result.stdout + result.stderr)

    def test_current_source_passes(self):
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_heading_renames_and_prose_reflow_are_accepted(self):
        # Preserve YAML frontmatter and fenced code; rename headings without retaining titles.
        # Reflow body paragraphs to a substantially different width, without changing words.
        paths = list(self.snapshot.glob("*.md"))
        for directory in ("references", "agents", "tests"):
            paths.extend((self.snapshot / directory).glob("*.md"))
        for path in paths:
            source = path.read_text()
            frontmatter = ""
            if source.startswith("---\n"):
                _, frontmatter_body, source = source.split("---", 2)
                frontmatter = "---" + frontmatter_body + "---"
            blocks = re.split(r"(```.*?```)", source, flags=re.DOTALL)
            for index in range(0, len(blocks), 2):
                blocks[index] = re.sub(r"^#{1,6} .*", "## Renamed section", blocks[index], flags=re.M)
                paragraphs = re.split(r"(\n\s*\n)", blocks[index])
                for item in range(0, len(paragraphs), 2):
                    paragraph = paragraphs[item]
                    if not paragraph.lstrip().startswith(("#", "|", "-", ">")) and not re.search(
                        r"^\s*\d+\.", paragraph, re.M
                    ):
                        paragraphs[item] = textwrap.fill(
                            " ".join(paragraph.split()), width=57,
                            break_long_words=False, break_on_hyphens=False,
                        )
                blocks[index] = "".join(paragraphs)
            path.write_text(frontmatter + "".join(blocks))
        result = self.run_checker()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_broad_discovery_is_not_hidden_by_body_scope(self):
        self.remove_phrase("SKILL.md", r" in repositories that already follow it")
        self.assert_rejected_by("selective-discovery")

    def test_raw_immutability_removal(self):
        self.remove_phrase("SKILL.md", r"\*\*Raw data is immutable\.\*\*")
        self.assert_rejected_by("scientific-safety")

    def test_transactional_replacement_removal(self):
        self.remove_phrase("SKILL.md", r"A failed run preserves.*?declared destination\.")
        self.assert_rejected_by("transactional-output")

    def test_rule_parameter_invalidation_removal(self):
        self.remove_paragraph("references/configuration.md", "Package functions never")
        self.assert_rejected_by("explicit-rule-params")

    def test_effective_configuration_guard_removal(self):
        self.remove_paragraph("references/configuration.md", "`--config` and `--configfile`")
        self.assert_rejected_by("override-rejection")

    def test_manifest_ordering_and_ancient_edge_removal(self):
        self.remove_paragraph("references/configuration.md", "A manifest rule takes")
        self.assert_rejected_by("manifest-provenance")

    def test_implicit_data_correction_boundary_removal(self):
        self.remove_phrase("references/data.md", r"Validation makes no implicit correction\.")
        self.assert_rejected_by("correction-free-validation")

    def test_training_leakage_boundary_removal(self):
        self.remove_paragraph("references/analysis.md", "For predictive work")
        self.assert_rejected_by("training-leakage")

    def test_publication_editable_delivery_removal(self):
        self.remove_paragraph("references/figures.md", "export editable SVG and PDF")
        self.assert_rejected_by("publication-figure-contract")

    def test_unavailable_host_boundary_removal(self):
        self.remove_paragraph("references/prerequisites.md", "An unavailable host or resolver")
        self.assert_rejected_by("real-host-proof")

    def test_target_policy_prohibition_removal(self):
        self.remove_phrase(
            "references/prerequisites.md",
            r"Never\s+create or modify a target `AGENTS\.md`, `CLAUDE\.md`, or `CODEX\.md`\.",
        )
        self.assert_rejected_by("canonical-installation")

    def test_failure_only_review_waiver_removal(self):
        self.remove_phrase(
            "references/governance.md",
            r"Only when resolution, invocation, or independent-agent launch fails in this session may the user\s+explicitly waive or defer a scientific critique or simplifier pass\.",
        )
        self.assert_rejected_by("scoped-waiver")

    def test_project_history_boundary_removal(self):
        self.remove_paragraph("SKILL.md", "only file that records")
        self.assert_rejected_by("current-state-text")

    def test_public_api_compatibility_boundary_removal(self):
        self.remove_phrase(
            "agents/research-code-simplifier.md",
            r"If compatibility is unknown, leave the code\s+unchanged and report the boundary\.",
        )
        self.assert_rejected_by("simplifier-supported-use")


if __name__ == "__main__":
    unittest.main(verbosity=2)
