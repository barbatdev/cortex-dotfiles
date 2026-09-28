#!/usr/bin/env python3
"""Focused checks for the portable RefactorIA CLI assets."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STATUSLINE = ROOT / "claude/statusline-command.sh"
HELP_PROFILE = ROOT / "fish/functions/help-profile.fish"
EXPECTED_STATUSLINE_SHA = "8b3524b8f1c9279f19986dbef7be0e3230d9044868d6f21b44b5ad85c40e454c"
ANSI_SGR = re.compile(r"\x1b\[[0-9;]*m")
ACCENT = "\033[1;38;2;255;107;138m"
BOLD = "\033[1m"


class TestFailure(RuntimeError):
    """Raised when a focused asset check fails."""


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise TestFailure(f"required command not found: {name}")
    return path


def run_checked(command: list[str], *, env: dict[str, str], input_text: str = "") -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        input=input_text,
        capture_output=True,
        check=False,
        cwd=ROOT,
        env=env,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise TestFailure(
            f"command failed ({result.returncode}): {' '.join(command)}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )
    return result


def statusline_payload(workspace: Path, used_percentage: int | None) -> str:
    context_window: dict[str, int] = {}
    if used_percentage is not None:
        context_window["used_percentage"] = used_percentage
    return json.dumps(
        {
            "workspace": {"current_dir": str(workspace)},
            "context_window": context_window,
            "rate_limits": {"five_hour": {"used_percentage": 42}},
            "model": {"display_name": "claude-test"},
            "effort": {"level": "high"},
        }
    )


def run_statusline(bash: str, workspace: Path, used_percentage: int | None, env: dict[str, str]) -> str:
    result = run_checked(
        [bash, str(STATUSLINE)],
        env=env,
        input_text=statusline_payload(workspace, used_percentage),
    )
    return result.stdout


def strip_ansi(value: str) -> str:
    return ANSI_SGR.sub("", value)


def assert_statusline_case(
    bash: str,
    workspace: Path,
    used_percentage: int | None,
    env: dict[str, str],
) -> None:
    output = run_statusline(bash, workspace, used_percentage, env)
    clean = strip_ansi(output)
    segments = clean.split(" · ")
    if len(segments) != 5:
        raise TestFailure(f"expected five statusline segments, got {len(segments)}: {clean!r}")

    if used_percentage is None:
        expected_bar = "[░░░░░░░░] ctx --"
        expected_filled = 0
        if ACCENT in output or BOLD in output:
            raise TestFailure("missing context unexpectedly used a threshold color")
    else:
        expected_filled = (used_percentage * 8 + 50) // 100
        expected_bar = (
            "["
            + "█" * expected_filled
            + "░" * (8 - expected_filled)
            + f"] {used_percentage}% ctx"
        )
        expected_color = ACCENT if used_percentage >= 80 else BOLD
        if expected_color not in output:
            raise TestFailure(f"missing expected ANSI threshold color at {used_percentage}%")
        unexpected_color = BOLD if expected_color == ACCENT else ACCENT
        if unexpected_color in output:
            raise TestFailure(f"unexpected ANSI threshold color at {used_percentage}%")

    if segments != [expected_bar, "claude-test (high)", "workspace", "main*", "5h 42%"]:
        raise TestFailure(f"unexpected statusline segments at {used_percentage!r}: {segments!r}")
    if output.count("█") != expected_filled:
        raise TestFailure(f"expected {expected_filled} filled glyphs at {used_percentage!r}")
    if output.count("░") != 8 - expected_filled:
        raise TestFailure(f"expected {8 - expected_filled} empty glyphs at {used_percentage!r}")


def test_statusline() -> None:
    if not STATUSLINE.is_file():
        raise TestFailure(f"missing statusline source: {STATUSLINE}")
    actual_sha = hashlib.sha256(STATUSLINE.read_bytes()).hexdigest()
    if actual_sha != EXPECTED_STATUSLINE_SHA:
        raise TestFailure(f"statusline SHA mismatch: expected {EXPECTED_STATUSLINE_SHA}, got {actual_sha}")
    source = STATUSLINE.read_text(encoding="utf-8")
    for forbidden in ("/Users/", "/home/", "SECRET", "TOKEN"):
        if forbidden in source:
            raise TestFailure(f"statusline source contains forbidden host/secret marker: {forbidden}")

    bash = require_tool("bash")
    require_tool("git")
    require_tool("jq")
    with tempfile.TemporaryDirectory(prefix="refactoria-statusline-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        home = temporary_root / "home"
        workspace = temporary_root / "workspace"
        home.mkdir()
        workspace.mkdir()

        env = os.environ.copy()
        env.update(
            {
                "HOME": str(home),
                "LC_ALL": "C.UTF-8",
                "LANG": "C.UTF-8",
                "TERM": "dumb",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": str(home / "gitconfig"),
            }
        )
        run_checked([require_tool("git"), "init", "-q", "-b", "main", str(workspace)], env=env)
        (workspace / "dirty.txt").write_text("dirty\n", encoding="utf-8")

        for used_percentage in (None, 0, 25, 79, 80, 95, 100):
            assert_statusline_case(bash, workspace, used_percentage, env)


def command_line_present(lines: list[str], command: str) -> bool:
    return any(line.strip().startswith(command) for line in lines)


def test_dynamic_help_filter() -> None:
    fish = shutil.which("fish")
    if fish is None:
        print("SKIP dynamic Fish help filter: fish binary not found")
        return

    with tempfile.TemporaryDirectory(prefix="refactoria-help-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        home = temporary_root / "home"
        bin_directory = temporary_root / "bin"
        home.mkdir()
        bin_directory.mkdir()
        for command in ("git-workdev", "dev", "cc"):
            executable = bin_directory / command
            executable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            executable.chmod(0o755)

        env = os.environ.copy()
        env.update(
            {
                "HOME": str(home),
                "PATH": str(bin_directory),
                "COLUMNS": "80",
                "TERM": "dumb",
                "LC_ALL": "C.UTF-8",
                "LANG": "C.UTF-8",
            }
        )
        result = run_checked(
            [
                fish,
                "--no-config",
                "-c",
                'source "$argv[1]"; help-profile',
                str(HELP_PROFILE),
            ],
            env=env,
        )
        lines = strip_ansi(result.stdout).splitlines()
        for command in ("git-workdev", "dev", "cc [path]"):
            if not command_line_present(lines, command):
                raise TestFailure(f"available helper missing from Fish help: {command}")
        for command in ("git-personaldev", "clone-workdev", "barbat", "oc [path]", "herdr-orient"):
            if command_line_present(lines, command):
                raise TestFailure(f"unavailable helper was displayed in Fish help: {command}")


def main() -> None:
    test_statusline()
    test_dynamic_help_filter()
    print("PASS RefactorIA asset checks")


if __name__ == "__main__":
    try:
        main()
    except TestFailure as error:
        raise SystemExit(f"FAIL: {error}") from error
