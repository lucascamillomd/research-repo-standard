"""Test isolated fixture boundaries and observable scoring, without live agents."""

import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

import behavioral_fixture as fixtures


class BehavioralFixtureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "fixture"

    def test_creation_refuses_nonempty_target_and_keeps_manifest_outside(self):
        fixtures.create("P", self.root)
        self.assertNotIn(fixtures.manifest_path(self.root), self.root.rglob("*"))
        self.assertEqual(fixtures.manifest_path(self.root).stat().st_mode & 0o222, 0)
        with self.assertRaises(fixtures.FixtureError):
            fixtures.create("P", self.root)

    def test_source_tree_cannot_be_a_target(self):
        with self.assertRaises(fixtures.FixtureError):
            fixtures.create("P", Path(__file__).parent / "fixture-do-not-create")

    def test_typo_requires_exact_change_and_rejects_extra_files(self):
        fixtures.create("P", self.root)
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("P", self.root)
        readme = self.root / "README.md"
        readme.write_text(readme.read_text().replace("reproduciblity", "reproducibility"))
        fixtures.verify("P", self.root)
        (self.root / "unsolicited.txt").write_text("extra scope")
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("P", self.root)

    def test_manifest_cannot_redefine_the_baseline(self):
        fixtures.create("V", self.root)
        manifest = fixtures.manifest_path(self.root)
        manifest.chmod(0o644)
        payload = json.loads(manifest.read_text())
        payload["case"] = "P"
        manifest.write_text(json.dumps(payload))
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("V", self.root)

    def test_unauthorized_exclusion_and_symlink_are_detected(self):
        fixtures.create("V", self.root)
        fixtures.verify("V", self.root)
        config = self.root / "config/analysis.json"
        config.write_text('{"included_ids": ["a", "b", "c"]}\n')
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("V", self.root)
        config.unlink()
        config.symlink_to(fixtures.manifest_path(self.root))
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("V", self.root)

    def test_refactor_must_change_code_and_preserve_unchanged_tests(self):
        fixtures.create("Q", self.root)
        helper = self.root / "assay/labels.py"
        helper.write_text(helper.read_text() + "\n# A comment is not a refactor.\n")
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("Q", self.root)
        helper.write_text(fixtures.LABELS.replace("Join stripped nonempty", "Return stripped nonempty"))
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("Q", self.root)
        helper.write_text(
            'def _csv_labels(rows, uppercase=False):\n'
            '    labels = [row["label"].strip() for row in rows]\n'
            '    return ", ".join(label.upper() if uppercase else label\n'
            '                     for label in labels if label)\n'
        )
        fixtures.verify("Q", self.root)
        (self.root / "test_labels.py").write_text("# deleted checks\n")
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("Q", self.root)

    def test_png_checks_reject_missing_or_truncated_renderings(self):
        fixtures.create("S", self.root)
        with self.assertRaises(fixtures.FixtureError):
            fixtures.verify("S", self.root)
        candidate = Path(self.tmp.name) / "broken.png"
        candidate.write_bytes(b"\x89PNG\r\n\x1a\n")
        with self.assertRaises(fixtures.FixtureError):
            fixtures.png_dimensions(candidate)

    def test_png_dimensions_require_valid_crc_and_complete_pixels(self):
        def chunk(kind, payload):
            return (struct.pack(">I", len(payload)) + kind + payload
                    + struct.pack(">I", zlib.crc32(kind + payload)))

        header = struct.pack(">IIBBBBB", 960, 640, 8, 6, 0, 0, 0)
        pixels = (b"\x00" + b"\x80\x80\x80\xff" * 960) * 640
        rendered = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                    + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))
        candidate = Path(self.tmp.name) / "valid.png"
        candidate.write_bytes(rendered)
        self.assertEqual(fixtures.png_dimensions(candidate), (960, 640))
        candidate.write_bytes(rendered[:-1] + b"\x00")
        with self.assertRaises(fixtures.FixtureError):
            fixtures.png_dimensions(candidate)


if __name__ == "__main__":
    unittest.main()
