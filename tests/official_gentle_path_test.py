"""Isolated tests for the optional migrated-host PATH fragment."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FRAGMENT = ROOT / 'zsh/scripts/official-gentle-path.zsh'
BOOTSTRAP = ROOT / 'zsh/zshrc'


class OfficialPathTests(unittest.TestCase):
    def test_fragment_is_silent_idempotent_and_prefers_official_bins(self):
        with tempfile.TemporaryDirectory() as home:
            for name in ['.local/bin', 'npm-global/bin', '.local/share/pnpm/bin']:
                (Path(home) / name).mkdir(parents=True, exist_ok=True)
            command = 'source "$1"; source "$1"; print -r -- "$PATH"'
            result = subprocess.run(['zsh', '-dfc', command, 'test', str(FRAGMENT)],
                                    env={'HOME': home, 'PATH': '/usr/bin:/bin'},
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stderr, '')
            self.assertEqual(result.stdout, ':'.join([
                home+'/.local/bin', home+'/.local/share/pnpm/bin',
                home+'/npm-global/bin', '/usr/bin', '/bin'])+'\n')

    def test_bootstrap_keeps_unmigrated_hosts_unchanged(self):
        with tempfile.TemporaryDirectory() as home:
            result = subprocess.run(['zsh', '-dfc', 'source "$1"; print -r -- "$PATH"',
                                     'test', str(BOOTSTRAP)],
                                    env={'HOME': home, 'PATH': '/usr/bin:/bin'},
                                    text=True, capture_output=True)
            self.assertEqual((result.returncode, result.stdout, result.stderr),
                             (0, '/usr/bin:/bin\n', ''))

    def test_bootstrap_loads_opt_in_fragment_after_other_integrations(self):
        with tempfile.TemporaryDirectory() as home:
            folder = Path(home)/'.config/cortex-dotfiles/shell'
            folder.mkdir(parents=True)
            (folder/'official-gentle-path.zsh').write_text('export OFFICIAL_GENTLE_LOADED=yes\n')
            result = subprocess.run(['zsh', '-dfc', 'source "$1"; print -r -- "${OFFICIAL_GENTLE_LOADED:-no}"',
                                     'test', str(BOOTSTRAP)],
                                    env={'HOME': home, 'PATH': '/usr/bin:/bin'},
                                    text=True, capture_output=True)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, 'yes\n', ''))


if __name__ == '__main__':
    unittest.main()
