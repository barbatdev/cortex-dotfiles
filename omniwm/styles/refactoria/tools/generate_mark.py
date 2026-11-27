#!/usr/bin/env python3
"""Bake the official SVG's group transform into native API 1 path coordinates.

From the repository root:
    python3 -B omniwm/styles/refactoria/tools/generate_mark.py
    python3 -B omniwm/styles/refactoria/tools/generate_mark.py --check

Only the supplied asset's M/m, L/l, C/c and Z/z subset is accepted. Every
control/end point and both closed subpaths survive; no geometry is rounded.
"""
import argparse
from decimal import Decimal
import hashlib
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path('design/refactoria-design-system/project/assets/Logos/refactoria-mark-light.svg')
OUTPUT = Path('omniwm/styles/refactoria/lib/mark.luau')
TOKEN = re.compile(r'[A-Za-z]|[-+]?(?:\d+(?:\.\d*)?|\.\d+)')


def number(value):
    """Emit an exact decimal, never a binary float or rounded coordinate."""
    text = format(value, 'f')
    return text.rstrip('0').rstrip('.') if '.' in text else text


def transform_path(source):
    """Return absolute M/L/C/Z commands after x'=x/10, y'=1254-y/10.

    Relative cubic controls all use the same pre-command origin. A close resets
    the origin for the following relative move; extra move pairs become lines.
    Reject unsupported commands or incomplete operands instead of dropping them.
    """
    tokens = []
    end = 0
    for match in TOKEN.finditer(source):
        if source[end:match.start()].strip(' \t\r\n,'):
            raise ValueError('Invalid SVG path token')
        tokens.append(match.group())
        end = match.end()
    if source[end:].strip(' \t\r\n,') or not tokens:
        raise ValueError('Invalid or empty SVG path')

    current = (Decimal(0), Decimal(0))
    start = None
    command = None
    index = 0
    result = []
    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
            if command not in 'MmLlCcZz':
                raise ValueError('Unsupported SVG command: ' + command)
        elif command is None:
            raise ValueError('SVG path needs a command')
        if command in 'Zz':
            if start is None:
                raise ValueError('Close before move')
            result.append('Z')
            current = start
            command = None
            continue
        if start is None and command not in 'Mm':
            raise ValueError('SVG path must start with move')
        count = 6 if command in 'Cc' else 2
        operands = tokens[index:index + count]
        if len(operands) != count or any(token.isalpha() for token in operands):
            raise ValueError('Incomplete SVG command: ' + command)
        points = list(map(Decimal, operands))
        if command.islower():
            points = [value + current[i % 2] for i, value in enumerate(points)]
        current = tuple(points[-2:])
        if command in 'Mm':
            start = current
        mapped = [value / 10 if i % 2 == 0 else 1254 - value / 10
                  for i, value in enumerate(points)]
        result.append(command.upper() + ' ' + ' '.join(map(number, mapped)))
        index += count
        if command in 'Mm':
            command = 'l' if command == 'm' else 'L'
    return '\n'.join(result)


def generate(raw):
    """Generate a self-contained Luau module from the exact official SVG shape."""
    svg = ET.fromstring(raw)
    group = svg.find('{*}g')
    if (svg.attrib.get('viewBox') != '238 130 777 1000'
            or len(svg) != 1 or group is None or len(group) != 1
            or group.attrib.get('transform') !=
            'translate(0.000000,1254.000000) scale(0.100000,-0.100000)'
            or group[0].tag != '{http://www.w3.org/2000/svg}path'
            or set(group[0].attrib) != {'d'}):
        raise ValueError('Official SVG structure/transform changed; inspect before regenerating')
    path = transform_path(group[0].attrib['d'])
    digest = hashlib.sha256(raw).hexdigest()
    return f'''-- Generated from the official full-beard asset; do not edit coordinates.
-- Source: {SOURCE.as_posix()}
-- Source SHA-256: {digest}
-- Regenerate: python3 -B omniwm/styles/refactoria/tools/generate_mark.py
-- Transform baked exactly: x'=x/10; y'=1254-y/10. Original viewBox retained.
-- Native nonzero fill preserves both subpaths; user-selected accent replaces light fill.
return {{
    w = 17.094, -- 22 * 777 / 1000 points, without aspect distortion
    h = 22,
    viewBox = {{ 238, 130, 777, 1000 }},
    d = [[
{path}
]],
}}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true',
                        help='verify the generated module without writing files')
    args = parser.parse_args()
    content = generate((ROOT / SOURCE).read_bytes())
    output = ROOT / OUTPUT
    if args.check:
        if not output.is_file() or output.read_text() != content:
            print('Official mark is stale; run the regeneration command', file=sys.stderr)
            return 1
        print('Official mark is up to date')
    else:
        output.write_text(content)
        print('Generated ' + OUTPUT.as_posix())
    return 0


if __name__ == '__main__':
    sys.exit(main())
