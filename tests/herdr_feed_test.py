"""Herdr Desktop mods carry one byte-identical Gentle Shell feed reader.

A mod cannot import outside its folder, so every refactoria mod that reads
sessions keeps its own ./feed.js; refactoria-spaces holds the canonical copy.
"""

import pathlib
import unittest

MODS = pathlib.Path(__file__).resolve().parent.parent / "herdr" / "desktop" / "mods"
CANONICAL = MODS / "refactoria-spaces" / "feed.js"


class FeedCopiesTest(unittest.TestCase):
    def test_canonical_reader_exists_and_leads(self):
        text = CANONICAL.read_text()
        self.assertIn('export const FEED_LEADER = "refactoria-spaces";', text)
        self.assertIn('export const FEEDS_KEY = "refactoria.feeds";', text)

    def test_every_copy_matches_the_canonical_one(self):
        canonical = CANONICAL.read_bytes()
        for copy in MODS.glob("*/feed.js"):
            with self.subTest(mod=copy.parent.name):
                self.assertEqual(copy.read_bytes(), canonical)

    def test_spaces_and_agents_share_one_state_model(self):
        # The space dots and the agent cards must reduce state the same way.
        agents = MODS / "refactoria-agents" / "model.js"
        spaces = MODS / "refactoria-spaces" / "model.js"
        self.assertEqual(spaces.read_bytes(), agents.read_bytes())

    def test_every_mod_importing_the_reader_carries_it(self):
        for main in MODS.glob("*/main.js"):
            if '"./feed.js"' in main.read_text():
                with self.subTest(mod=main.parent.name):
                    self.assertTrue((main.parent / "feed.js").is_file())


if __name__ == "__main__":
    unittest.main()
