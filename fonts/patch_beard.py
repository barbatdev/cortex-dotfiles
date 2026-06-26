#!/usr/bin/env python3
"""Patch a Nerd Font with the RefactorIA beard glyph.

Run with FontForge:
    fontforge -script dotfiles/fonts/patch_beard.py \
        --font ~/Library/Fonts/FiraCodeNerdFontMono-Regular.ttf \
        --svg ~/Downloads/refactoria/build/refactoria.svg \
        --output-dir ~/Downloads/refactoria/build
"""

from __future__ import annotations

import argparse
import os
import sys

import fontforge
import psMat


CODEPOINT = 0xF0F00
SCALE_FACTOR = 0.85
DESCENT_OFFSET_FACTOR = 0.5
DEFAULT_OUTPUT_NAME = "FiraCodeNerdFontMonoBeard-Reg.ttf"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Patch a font with the RefactorIA beard glyph.")
    parser.add_argument("--font", required=True, help="Source TTF/OTF font path.")
    parser.add_argument("--svg", required=True, help="SVG glyph path.")
    parser.add_argument("--output-dir", required=True, help="Directory for the patched TTF.")
    parser.add_argument("--output-name", default=DEFAULT_OUTPUT_NAME, help="Patched TTF file name.")
    parser.add_argument("--family-suffix", default="Beard", help="Suffix for the generated font family.")
    return parser.parse_args()


def set_font_names(font: fontforge.font, family_name: str, suffix: str) -> str:
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


def center_and_scale_glyph(font: fontforge.font, glyph: fontforge.glyph) -> None:
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
    glyph.transform(psMat.translate(-xmin, -ymin))
    glyph.transform(psMat.scale(scale))

    glyph_width = source_width * scale
    glyph_height = source_height * scale
    reference_width = font[ord("M")].width
    glyph.width = reference_width

    x_offset = (reference_width - glyph_width) / 2
    y_offset = -descent * DESCENT_OFFSET_FACTOR
    glyph.transform(psMat.translate(x_offset, y_offset))

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
    os.makedirs(args.output_dir, exist_ok=True)

    font = fontforge.open(os.path.expanduser(args.font))
    original_family = font.familyname
    new_family = set_font_names(font, original_family, args.family_suffix)

    glyph = font.createChar(CODEPOINT, "refactoria-beard")
    glyph.clear()
    glyph.importOutlines(args.svg)
    center_and_scale_glyph(font, glyph)

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
