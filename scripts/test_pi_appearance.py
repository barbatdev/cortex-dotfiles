#!/usr/bin/env python3
"""Focused tests for the Pi appearance merge."""
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/pi_appearance.py"
SOURCE = ROOT / "pi/appearance.json"


def run(target: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(SOURCE), str(target), *extra],
        capture_output=True,
        text=True,
    )


def write(path: Path, text: str, mode: int = 0o600) -> None:
    path.write_text(text)
    path.chmod(mode)


def test_merges_only_appearance_keys_and_keeps_the_rest() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "settings.json"
        write(target, json.dumps({"packages": ["a"], "theme": "dark", "defaultModel": "m"}, indent=2) + "\n")
        result = run(target)
        assert result.returncode == 0, result.stderr
        data = json.loads(target.read_text())
        assert list(data) == ["packages", "theme", "defaultModel", "showHardwareCursor"], list(data)
        assert data["theme"] == "refactoria"
        assert data["showHardwareCursor"] is True
        assert data["packages"] == ["a"] and data["defaultModel"] == "m"
        assert "updated" in result.stdout


def test_second_run_changes_nothing() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "settings.json"
        write(target, '{"theme": "dark"}\n')
        assert run(target).returncode == 0
        before = target.read_bytes()
        mtime = target.stat().st_mtime_ns
        result = run(target)
        assert result.returncode == 0, result.stderr
        assert target.read_bytes() == before
        assert target.stat().st_mtime_ns == mtime
        assert "already" in result.stdout


def test_malformed_target_is_left_untouched() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "settings.json"
        write(target, '{"theme": ')
        result = run(target)
        assert result.returncode == 1
        assert target.read_text() == '{"theme": '
        assert "malformed" in result.stderr


def test_permissions_are_preserved() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "settings.json"
        write(target, '{"theme": "dark"}\n', mode=0o600)
        assert run(target).returncode == 0
        assert stat.S_IMODE(target.stat().st_mode) == 0o600


def test_dry_run_writes_nothing() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "settings.json"
        write(target, '{"theme": "dark"}\n')
        result = run(target, "--dry-run")
        assert result.returncode == 0, result.stderr
        assert target.read_text() == '{"theme": "dark"}\n'
        assert "Would" in result.stdout


def test_missing_target_is_created_with_the_appearance_keys() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "agent" / "settings.json"
        result = run(target)
        assert result.returncode == 0, result.stderr
        assert json.loads(target.read_text()) == {"theme": "refactoria", "showHardwareCursor": True}
        assert stat.S_IMODE(target.stat().st_mode) == 0o600


def main() -> None:
    test_merges_only_appearance_keys_and_keeps_the_rest()
    test_second_run_changes_nothing()
    test_malformed_target_is_left_untouched()
    test_permissions_are_preserved()
    test_dry_run_writes_nothing()
    test_missing_target_is_created_with_the_appearance_keys()
    print("PASS Pi appearance merge tests")


if __name__ == "__main__":
    main()
