"""Public-CLI tests for bin/gs-official using a temp HOME and PATH shims."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "bin" / "gs-official"

SHIM = """#!/bin/sh
echo "{name} $*" >> "$GS_TEST_LOG"
{body}
"""


class GsOfficialTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name) / "home"
        self.shims = Path(self.tmp.name) / "shims"
        self.ai_bin = self.home / ".local" / "bin"
        self.log = Path(self.tmp.name) / "calls.log"
        for d in (self.shims, self.ai_bin):
            d.mkdir(parents=True)
        self.log.touch()
        self.shim(self.shims, "gentle-shell",
                  'case "$1" in --version) echo "gentle-shell 9.9.9";; esac')
        self.shim(self.shims, "go",
                  'if [ "$1" = version ]; then echo "  build vcs.revision=abc123"; fi')
        self.shim(self.ai_bin, "gentle-ai",
                  'if [ "$1" = version ]; then echo "gentle-ai dev"; fi')
        self.shim(self.ai_bin, "engram",
                  'if [ "$1" = version ]; then echo "engram 3.0.0-dev"; fi')

    def tearDown(self):
        self.tmp.cleanup()

    def shim(self, directory, name, body):
        path = directory / name
        path.write_text(SHIM.format(name=name, body=body))
        path.chmod(0o755)
        return path

    def run_gs(self, *args, path=None):
        env = {
            "HOME": str(self.home),
            "PATH": path or f"{self.ai_bin}:{self.shims}:/usr/bin:/bin",
            "GS_TEST_LOG": str(self.log),
        }
        return subprocess.run([str(SCRIPT), *args], env=env,
                              capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines()

    # S5: default launch forwards arguments unchanged and preserves exit status.
    def test_launch_forwards_args_and_exit_status(self):
        self.shim(self.shims, "gentle-shell", 'echo out; echo err >&2; exit 7')
        result = self.run_gs("--model", "a b", "x")
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (7, "out\n", "err\n"))
        self.assertEqual(self.calls(), ["gentle-shell --model a b x"])

    def test_launch_without_args_adds_no_flags(self):
        result = self.run_gs()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.calls(), ["gentle-shell "])

    def test_help_is_documented_and_launches_nothing(self):
        result = self.run_gs("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("gs sync", result.stdout)
        self.assertEqual(self.calls(), [])

    # S3/S4/S2: sync updates both from main and syncs Claude Code only.
    def test_sync_runs_main_updates_then_claude_code_sync(self):
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 0, result.stderr)
        ai = self.ai_bin / "gentle-ai"
        engram = self.ai_bin / "engram"
        self.assertEqual(self.calls(), [
            "gentle-shell upgrade --channel main",
            "go install github.com/gentleman-programming/gentle-ai/v4/cmd/gentle-ai@main",
            "gentle-ai sync --agents claude-code",
            "go install github.com/Gentleman-Programming/engram/v3/cmd/engram@main",
            "gentle-shell --version",
            "gentle-ai version",
            f"go version -m {ai}",
            "engram version",
            f"go version -m {engram}",
        ])
        self.assertIn("vcs.revision=abc123", result.stdout)
        self.assertIn("gentle-shell 9.9.9", result.stdout)
        self.assertIn("engram 3.0.0-dev", result.stdout)
        self.assertIn("restart the Engram service", result.stdout)

    def test_sync_installs_into_resolved_gentle_ai_dir(self):
        self.shim(self.shims, "go",
                  'if [ "$1" = install ]; then echo "GOBIN=$GOBIN" >> "$GS_TEST_LOG"; fi')
        self.run_gs("sync")
        self.assertIn(f"GOBIN={self.ai_bin.resolve()}", self.calls())

    def test_sync_rejects_extra_args(self):
        result = self.run_gs("sync", "--force")
        self.assertEqual(result.returncode, 2)
        self.assertIn("takes no arguments", result.stderr)
        self.assertEqual(self.calls(), [])

    # Preflight: refuse to replace binaries outside the expected owned bin.
    def test_sync_refuses_symlinked_gentle_ai(self):
        real = self.shim(self.shims, "gentle-ai-real", "")
        (self.ai_bin / "gentle-ai").unlink()
        (self.ai_bin / "gentle-ai").symlink_to(real)
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("symlink", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_sync_refuses_gentle_ai_outside_expected_bin(self):
        (self.ai_bin / "gentle-ai").unlink()
        self.shim(self.shims, "gentle-ai", "")
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("expected", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_sync_fails_when_go_missing(self):
        (self.shims / "go").unlink()
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("go not found", result.stderr)
        self.assertEqual(self.calls(), [])

    # S3: failures are fail-fast with no stable fallback.
    def test_sync_fails_fast_on_shell_upgrade_failure(self):
        self.shim(self.shims, "gentle-shell",
                  'echo upgrade-broke >&2; exit 5')
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 5)
        self.assertIn("upgrade-broke", result.stderr)
        self.assertIn("'gentle-shell upgrade --channel main' failed with exit 5", result.stderr)
        self.assertEqual(self.calls(), ["gentle-shell upgrade --channel main"])

    def test_sync_fails_fast_on_go_install_failure(self):
        self.shim(self.shims, "go", 'exit 3')
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 3)
        self.assertNotIn("gentle-ai sync --agents claude-code", self.calls())


    # Engram follows main like Gentle AI, with the same fail-closed target.
    def test_sync_refuses_symlinked_engram(self):
        real = self.shim(self.shims, "engram-real", "")
        (self.ai_bin / "engram").unlink()
        (self.ai_bin / "engram").symlink_to(real)
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("engram is a symlink", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_sync_refuses_engram_outside_expected_bin(self):
        (self.ai_bin / "engram").unlink()
        self.shim(self.shims, "engram", "")
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("engram is not in the expected directory", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_sync_fails_when_engram_missing(self):
        (self.ai_bin / "engram").unlink()
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 1)
        self.assertIn("engram not found", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_sync_fails_fast_on_engram_install_failure(self):
        self.shim(self.shims, "go",
                  'case "$*" in *engram*) echo engram-broke >&2; exit 4;; esac')
        result = self.run_gs("sync")
        self.assertEqual(result.returncode, 4)
        self.assertIn("engram-broke", result.stderr)
        self.assertNotIn("gentle-shell --version", self.calls())
        self.assertNotIn("restart the Engram service", result.stdout)


if __name__ == "__main__":
    unittest.main()
