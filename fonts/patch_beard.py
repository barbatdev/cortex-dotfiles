#!/usr/bin/env python3
"""Patch a Nerd Font with the RefactorIA beard glyph.

The canonical site artwork is stored as Braille text in the repository.  When
``--braille`` is supplied, this script turns that text into a deterministic,
monochrome SVG made only from Braille dot rectangles before importing it into
FontForge.  ``--svg`` remains available for trusted external vector sources.

Canonical repository regeneration:
    fontforge -script fonts/patch_beard.py \
        --font ~/Library/Fonts/FiraCodeNerdFontMono-Regular.ttf \
        --braille assets/refactoria-braille.txt \
        --svg fonts/refactoria-isotipo.svg \
        --output-dir fonts
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
from typing import Any, Sequence


CODEPOINT = 0xF0F00
SCALE_FACTOR = 0.85
DESCENT_OFFSET_FACTOR = 0.5
DEFAULT_OUTPUT_NAME = "FiraCodeNerdFontMonoBeard-Reg.ttf"
BRAILLE_BASE = 0x2800
BRAILLE_CELL_WIDTH = 0.48
BRAILLE_DOT_X = (0.10, 0.55)
BRAILLE_DOT_Y = (0.04, 0.28, 0.52, 0.76)
BRAILLE_DOT_WIDTH = 0.32
BRAILLE_DOT_HEIGHT = 0.17
BRAILLE_DOTS = (
    (0x01, 0, 0),
    (0x02, 0, 1),
    (0x04, 0, 2),
    (0x40, 0, 3),
    (0x08, 1, 0),
    (0x10, 1, 1),
    (0x20, 1, 2),
    (0x80, 1, 3),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Patch a font with the RefactorIA beard glyph.")
    parser.add_argument("--font", required=True, help="Source TTF/OTF font path.")
    parser.add_argument("--svg", required=True, help="SVG glyph path (generated when --braille is supplied).")
    parser.add_argument("--braille", help="Canonical Braille text used to generate --svg deterministically.")
    parser.add_argument("--output-dir", required=True, help="Directory for the patched TTF.")
    parser.add_argument("--output-name", default=DEFAULT_OUTPUT_NAME, help="Patched TTF file name.")
    parser.add_argument("--family-suffix", default="Beard", help="Suffix for the generated font family.")
    return parser.parse_args()


def parse_braille_rows(text: str) -> list[str]:
    """Validate canonical Braille rows and pad short rows with blank cells."""
    rows = text.splitlines()
    if not rows:
        raise ValueError("Braille source is empty")
    if any(any(not BRAILLE_BASE <= ord(char) <= BRAILLE_BASE + 0xFF for char in row) for row in rows):
        raise ValueError("Braille source contains a non-Braille character")
    width = max(len(row) for row in rows)
    if width == 0:
        raise ValueError("Braille source has no cells")
    return [row.ljust(width, chr(BRAILLE_BASE)) for row in rows]


def _active_bounds(rows: Sequence[str]) -> tuple[int, int, int, int]:
    active = [
        (x, y)
        for y, row in enumerate(rows)
        for x, char in enumerate(row)
        if ord(char) - BRAILLE_BASE
    ]
    if not active:
        raise ValueError("Braille source has no active dots")
    xs = [point[0] for point in active]
    ys = [point[1] for point in active]
    return min(xs), min(ys), max(xs), max(ys)


def _number(value: float) -> str:
    """Format SVG coordinates without platform-dependent float spellings."""
    return f"{value:.4f}".rstrip("0").rstrip(".") or "0"


def braille_to_svg(rows: Sequence[str]) -> str:
    """Return a deterministic monochrome SVG silhouette from Braille rows.

    Each active Braille dot becomes one filled vector rectangle.  The fixed
    horizontal cell factor keeps the full site silhouette inside a monospaced
    font cell after the existing isotropic FontForge scaling.
    """
    normalized = parse_braille_rows("\n".join(rows))
    min_x, min_y, max_x, max_y = _active_bounds(normalized)
    canvas_width = (max_x - min_x + 1) * BRAILLE_CELL_WIDTH
    canvas_height = max_y - min_y + 1
    rectangles: list[str] = []

    for y, row in enumerate(normalized):
        for x, char in enumerate(row):
            bits = ord(char) - BRAILLE_BASE
            if not bits:
                continue
            local_x = x - min_x
            local_y = y - min_y
            for mask, dot_column, dot_row in BRAILLE_DOTS:
                if bits & mask:
                    x0 = (local_x + BRAILLE_DOT_X[dot_column]) * BRAILLE_CELL_WIDTH
                    y0 = local_y + BRAILLE_DOT_Y[dot_row]
                    width = BRAILLE_DOT_WIDTH * BRAILLE_CELL_WIDTH
                    height = BRAILLE_DOT_HEIGHT
                    x1 = x0 + width
                    y1 = y0 + height
                    rectangles.append(
                        "M {x0} {y0} H {x1} V {y1} H {x0} Z".format(
                            x0=_number(x0),
                            y0=_number(y0),
                            x1=_number(x1),
                            y1=_number(y1),
                        )
                    )

    if not rectangles:
        raise ValueError("Braille source has no vector rectangles")

    path = " ".join(rectangles)
    return "\n".join(
        (
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {_number(canvas_width)} {_number(canvas_height)}">',
            f'<path fill="#000000" d="{path}"/>',
            "</svg>",
            "",
        )
    )


def write_braille_svg(braille_path: str | os.PathLike[str], svg_path: str | os.PathLike[str]) -> None:
    """Generate the repository SVG from the canonical Braille source."""
    text = Path(braille_path).read_text(encoding="utf-8")
    svg = braille_to_svg(parse_braille_rows(text))
    destination = Path(svg_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(svg, encoding="utf-8")


def set_font_names(font: Any, family_name: str, suffix: str) -> str:
    new_family = f"{family_name} {suffix}"
    style = font.fontname.split("-")[-1] if "-" in font.fontname else "Regular"
    compact_family = new_family.replace(" ", "")
    compact_style = style.replace(" ", "")

    font.familyname = new_family
    font.fullname = f"{new_family} {style}"
    font.fontname = f"{compact_family}-{compact_style}"
    font.appendSFNTName("English (US)", "Family", new_family)
    font.appendSFNTName("English (US)", "Fullname", font.fullname)
    font.appendSFNTName("English (US)", "PostScriptName", font.fontname)
    font.appendSFNTName("English (US)", "Preferred Family", new_family)
    font.appendSFNTName("English (US)", "Preferred Styles", style)
    return new_family


def center_and_scale_glyph(font: Any, glyph: Any, ps_mat: Any) -> None:
    ascent = font.ascent
    descent = font.descent
    line_height = ascent + descent
    target_height = line_height * SCALE_FACTOR

    glyph.removeOverlap()
    glyph.correctDirection()
    xmin, ymin, xmax, ymax = glyph.boundingBox()
    source_width = xmax - xmin
    source_height = ymax - ymin
    if source_width <= 0 or source_height <= 0:
        raise RuntimeError(f"Invalid glyph bounds: {glyph.boundingBox()}")

    scale = target_height / source_height
    glyph.transform(ps_mat.translate(-xmin, -ymin))
    glyph.transform(ps_mat.scale(scale))

    glyph_width = source_width * scale
    glyph_height = source_height * scale
    reference_width = font[ord("M")].width

    x_offset = (reference_width - glyph_width) / 2
    y_offset = -descent * DESCENT_OFFSET_FACTOR
    glyph.transform(ps_mat.translate(x_offset, y_offset))
    # FontForge may round the advance during a transform; restore the source
    # mono-cell width after all outline transforms are complete.
    glyph.width = reference_width

    print("Patch debug:")
    print(f"  em_size={font.em}")
    print(f"  ascent={ascent}")
    print(f"  descent={descent}")
    print(f"  line_height={line_height}")
    print(f"  target_height={target_height:.2f}")
    print(f"  source_bbox={(xmin, ymin, xmax, ymax)}")
    print(f"  source_width={source_width:.2f}")
    print(f"  source_height={source_height:.2f}")
    print(f"  scale={scale:.6f}")
    print(f"  glyph_width={glyph_width:.2f}")
    print(f"  glyph_height={glyph_height:.2f}")
    print(f"  reference_width_M={reference_width}")
    print(f"  x_offset={x_offset:.2f}")
    print(f"  y_offset={y_offset:.2f}")
    print(f"  final_bbox={glyph.boundingBox()}")


def main() -> int:
    args = parse_args()
    if args.braille:
        write_braille_svg(args.braille, args.svg)

    # FontForge supplies these modules only when this file is run via
    # ``fontforge -script``; the pure conversion helpers stay stdlib-only.
    import fontforge  # type: ignore[import-not-found]
    import psMat  # type: ignore[import-not-found]

    os.makedirs(args.output_dir, exist_ok=True)
    font = fontforge.open(os.path.expanduser(args.font))
    original_family = font.familyname
    new_family = set_font_names(font, original_family, args.family_suffix)

    glyph = font.createChar(CODEPOINT, "refactoria-beard")
    glyph.clear()
    glyph.importOutlines(os.path.expanduser(args.svg))
    center_and_scale_glyph(font, glyph, psMat)

    output_path = os.path.join(args.output_dir, args.output_name)
    font.generate(output_path)
    font.close()

    print(f"  original_family={original_family}")
    print(f"  new_family={new_family}")
    print(f"  codepoint=U+{CODEPOINT:05X}")
    print(f"  output_path={output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
