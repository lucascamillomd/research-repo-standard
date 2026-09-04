"""Execute the profile examples against their stated compatibility boundaries."""

import itertools
import re
import shlex
import unittest
from pathlib import Path


PROFILE = Path(__file__).resolve().parents[1] / "agents/research-code-simplifier.md"


def load_examples():
    blocks = re.findall(r"```python\n(.*?)```", PROFILE.read_text(), re.DOTALL)
    if len(blocks) != 6:
        raise AssertionError("Expected three before/after pairs in the canonical profile")
    examples = []
    for block in blocks:
        namespace = {
            "islice": itertools.islice,
            "_find_unsafe": re.compile(r"[^\w@%+=:,./-]", re.ASCII).search,
        }
        exec(compile(block, str(PROFILE), "exec"), namespace)
        examples.append(namespace)
    return examples


class SimplifierExamplesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.examples = load_examples()

    def test_slices_preserve_supported_results(self):
        before, after = [example["iter_slices"] for example in self.examples[:2]]
        for string in ("", "a", "abcdef", "αβγ"):
            for length in (None, -1, 0, 1, 2, 20):
                with self.subTest(string=string, length=length):
                    self.assertEqual(list(before(string, length)), list(after(string, length)))

    def test_slices_document_changed_error_behavior(self):
        before, after = [example["iter_slices"] for example in self.examples[:2]]
        self.assertEqual(list(before("abc", 1.5)), [])
        with self.assertRaises(TypeError):
            list(after("abc", 1.5))

    def test_take_preserves_results_and_iterator_consumption(self):
        before, after = [example["take"] for example in self.examples[2:4]]
        for count in (0, 1, 3, 10):
            left, right = iter(range(5)), iter(range(5))
            self.assertEqual(before(count, left), after(count, right))
            self.assertEqual(list(left), list(right))

    def test_take_documents_removed_private_behavior(self):
        before, after = [example["take"] for example in self.examples[2:4]]
        self.assertEqual(before("2", range(5)), [0, 1])
        with self.assertRaises(ValueError):
            after("2", range(5))
        self.assertEqual(before(2, range(5), as_tuple=True), (0, 1))
        with self.assertRaises(TypeError):
            after(2, range(5), as_tuple=True)

    def test_quote_preserves_shell_round_trip(self):
        before, after = [example["quote"] for example in self.examples[4:]]
        for string in ("", "plain", "two words", "a'b", 'a"b', "$x; rm", "a\nb", "αβ"):
            with self.subTest(string=string):
                self.assertEqual(before(string), after(string))
                self.assertEqual(shlex.split(after(string)), [string])


if __name__ == "__main__":
    unittest.main()
