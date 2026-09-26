#!/usr/bin/env python3
"""Check the plugin and marketplace manifests that Claude Code and Codex install from.

These checks pin the layout both hosts read. They do not install the plugin; a real host
install and smoke test remain separate manual checks.
"""

import json
from pathlib import Path
import unittest


SOURCE = Path(__file__).resolve().parents[1]
NAME = "research-repo-standard"


def load(relative_path):
    return json.loads((SOURCE / relative_path).read_text())


class PluginManifests(unittest.TestCase):
    def test_marketplace_lists_this_repository_as_its_plugin(self):
        marketplace = load(".claude-plugin/marketplace.json")
        self.assertEqual(marketplace["name"], NAME)
        self.assertTrue(marketplace["owner"]["name"])
        entries = marketplace["plugins"]
        self.assertEqual([entry["name"] for entry in entries], [NAME])
        # Both hosts resolve "./" to the marketplace root, so the repository is its own plugin.
        self.assertEqual(entries[0]["source"], "./")

    def test_plugin_manifest_names_the_plugin(self):
        self.assertEqual(load(".claude-plugin/plugin.json")["name"], NAME)

    def test_installs_track_commits(self):
        # A version pins installs until it changes; without one, updates follow new commits.
        self.assertNotIn("version", load(".claude-plugin/plugin.json"))
        for entry in load(".claude-plugin/marketplace.json")["plugins"]:
            self.assertNotIn("version", entry)

    def test_skill_and_profile_sit_where_both_hosts_load_them(self):
        skill = SOURCE / "skills" / NAME / "SKILL.md"
        self.assertTrue(skill.read_text().startswith(f"---\nname: {NAME}\n"))
        self.assertTrue((SOURCE / "skills" / NAME / "references" / "prerequisites.md").is_file())
        self.assertTrue((SOURCE / "agents" / "research-code-simplifier.md").is_file())
        # Codex loads plugin skills only from skills/; a root copy would be a second, stale source.
        self.assertFalse((SOURCE / "SKILL.md").exists())
        self.assertFalse((SOURCE / "references").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
