#!/usr/bin/env python3
"""Tests for scripts/sync-pi-model-profiles.py (run: python3 tests/sync_pi_model_profiles_test.py)."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "sync-pi-model-profiles.py"

REPO = {
    "kind": "gentle-pi.agent_model_profiles",
    "version": 1,
    "active": "openai",
    "profiles": {
        "openai": {
            "orchestrator": {"model": "openai/gpt-6.1-sol", "thinking": "low"},
            "review-risk": {"model": "openai/gpt-6-astra", "thinking": "high"},
            "gentle-ai-verify": {"model": "openai/gpt-6.1-terra", "thinking": "medium"},
        }
    },
}

AGENT_MD = "---\nname: review-risk\nmodel: openai/gpt-6.1-sol\nthinking: low\ntools: []\n---\nBody model: untouched\n"


class SyncPiModelProfilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.source = self.base / "profiles.json"
        self.source.write_text(json.dumps(REPO))
        self.home = self.base / "home"
        agent = self.home / "agent"
        (agent / "agents").mkdir(parents=True)
        (agent / "settings.json").write_text(json.dumps({"theme": "refactoria", "defaultModel": "gpt-5.5", "defaultProvider": "openai"}))
        (agent / "subagents.json").write_text(json.dumps({"default_effort": "high", "model_profiles": {"review-risk": {"model": "openai/gpt-6.1-sol", "effort": "low"}, "kb-feeder": {"model": "openai/gpt-6-luna"}}}))
        (agent / "agents" / "review-risk.md").write_text(AGENT_MD)
        (self.home / "gentle-ai").mkdir()
        (self.home / "gentle-ai" / "profiles.json").write_text(json.dumps({"kind": "gentle-pi.agent_model_profiles", "version": 1, "active": "openai", "profiles": {"current": {}, "local-only": {"orchestrator": {"model": "nan/glm5.3"}}, "openai": {"orchestrator": {"model": "openai/gpt-5.5"}}}}))

    def tearDown(self):
        self.tmp.cleanup()

    def run_sync(self, *extra):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), "--source", str(self.source), "--home", str(self.home), *extra], capture_output=True, text=True, check=True)

    def read(self, rel):
        return (self.home / rel).read_text()

    def test_merges_store_and_keeps_local_profiles(self):
        self.run_sync()
        store = json.loads(self.read("gentle-ai/profiles.json"))
        self.assertEqual(store["profiles"]["openai"], REPO["profiles"]["openai"])
        self.assertIn("local-only", store["profiles"])
        self.assertIn("current", store["profiles"])
        self.assertEqual(store["active"], "openai")

    def test_materializes_active_profile(self):
        self.run_sync()
        settings = json.loads(self.read("agent/settings.json"))
        self.assertEqual((settings["defaultProvider"], settings["defaultModel"], settings["defaultThinkingLevel"]), ("openai", "gpt-6.1-sol", "low"))
        self.assertEqual(settings["theme"], "refactoria")
        sub = json.loads(self.read("agent/subagents.json"))
        self.assertEqual(sub["model_profiles"]["review-risk"], {"model": "openai/gpt-6-astra", "effort": "high"})
        self.assertEqual(sub["model_profiles"]["gentle-ai-verify"], {"model": "openai/gpt-6.1-terra", "effort": "medium"})
        self.assertEqual(sub["model_profiles"]["kb-feeder"], {"model": "openai/gpt-6-luna"})
        self.assertEqual(sub["default_effort"], "high")
        md = self.read("agent/agents/review-risk.md")
        self.assertIn("model: openai/gpt-6-astra\nthinking: high\n", md)
        self.assertTrue(md.endswith("Body model: untouched\n"))

    def test_second_run_is_a_no_op(self):
        self.run_sync()
        out = self.run_sync().stdout
        self.assertIn("changed 0 file(s)", out)

    def test_dry_run_writes_nothing(self):
        before = self.read("agent/subagents.json")
        out = self.run_sync("--dry-run").stdout
        self.assertIn("would change", out)
        self.assertEqual(self.read("agent/subagents.json"), before)
        self.assertEqual(list(self.home.rglob("*.bak-profiles-*")), [])

    def test_home_without_store_keeps_its_routing(self):
        (self.home / "gentle-ai" / "profiles.json").unlink()
        before = {rel: self.read(rel) for rel in ("agent/settings.json", "agent/subagents.json", "agent/agents/review-risk.md")}
        self.run_sync()
        store = json.loads(self.read("gentle-ai/profiles.json"))
        self.assertEqual(store["active"], "current")
        self.assertEqual(store["profiles"]["current"], {})
        self.assertIn("openai", store["profiles"])
        self.assertEqual({rel: self.read(rel) for rel in before}, before)

    def test_home_without_agent_dir_is_skipped(self):
        empty = self.base / "empty"
        empty.mkdir()
        out = subprocess.run([sys.executable, "-I", str(SCRIPT), "--source", str(self.source), "--home", str(empty)], capture_output=True, text=True, check=True).stdout
        self.assertIn("changed 0 file(s)", out)
        self.assertFalse((empty / "gentle-ai").exists())


if __name__ == "__main__":
    unittest.main()
