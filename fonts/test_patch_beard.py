#!/usr/bin/env python3
"""Dependency-light tests for the deterministic Braille-to-SVG conversion."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from patch_beard import BRAILLE_BASE, braille_to_svg, parse_braille_rows  # noqa: E402


ASSET = ROOT / "assets" / "refactoria-braille.txt"
SVG = ROOT / "fonts" / "refactoria-isotipo.svg"


def assert_raises(expected: type[BaseException], callback) -> None:
    try:
        callback()
    except expected:
        return
    raise AssertionError(f"expected {expected.__name__}")


def main() -> int:
    rows = parse_braille_rows(ASSET.read_text(encoding="utf-8"))
    assert len(rows) == 36
    assert {len(row) for row in rows} == {56}
    assert all(BRAILLE_BASE <= ord(char) <= BRAILLE_BASE + 0xFF for row in rows for char in row)

    svg = braille_to_svg(rows)
    assert svg == braille_to_svg(rows), "conversion must be deterministic"
    assert '<path fill="#000000"' in svg
    assert "<image" not in svg
    assert svg.count("M ") > 1000, "the canonical silhouette must retain its active dots"

    full_cell = braille_to_svg(["⣿"])
    assert full_cell.count("M ") == 8
    assert_raises(ValueError, lambda: parse_braille_rows("not braille"))
    assert_raises(ValueError, lambda: braille_to_svg(["⠀"]))

    if SVG.exists():
        assert SVG.read_text(encoding="utf-8") == svg, "checked-in SVG must be reproducible from the asset"

    print("patch_beard conversion tests: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
