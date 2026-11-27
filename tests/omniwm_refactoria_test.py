"""Offline package checks; optional real Luau execution, never a Python behavior port.
Run: python3 -B tests/omniwm_refactoria_test.py
Pinned upstream verification: add --tagged-api (public, read-only HTTP).
"""
from decimal import Decimal
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
import unittest
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
STYLE = ROOT / 'omniwm/styles/refactoria'
REV = 'bf118cca1449468397dee3662acbba5544657545'
TAGGED = '--tagged-api' in sys.argv
if TAGGED:
    sys.argv.remove('--tagged-api')


def toml(name):
    return tomllib.loads((STYLE / name).read_text())


def dark_tokens():
    """Read the canonical CSS default theme, resolving aliases and RGBA hex."""
    css = (ROOT / 'design/refactoria-design-system/project/tokens.css').read_text()
    root = re.search(r':root\s*\{(.*?)\n\}', css, re.S).group(1)
    tokens = dict(re.findall(r'--([\w-]+):\s*([^;]+);', root))

    def resolve(name):
        value = tokens[name].strip()
        alias = re.fullmatch(r'var\(--([\w-]+)\)', value)
        if alias:
            return resolve(alias[1])
        rgba = re.fullmatch(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)', value)
        if rgba:
            r, g, b = map(int, rgba.groups()[:3])
            return f'#{r:02x}{g:02x}{b:02x}{round(float(rgba[4]) * 255):02x}'
        return value.lower()

    return resolve


class PackageTests(unittest.TestCase):
    def test_official_mark_exact_geometry_and_size(self):
        asset = ROOT / 'design/refactoria-design-system/project/assets/Logos/refactoria-mark-light.svg'
        raw = asset.read_bytes()
        svg = ET.fromstring(raw)
        group = svg.find('{*}g')
        self.assertEqual(svg.attrib['viewBox'], '238 130 777 1000')
        self.assertEqual(group.attrib['transform'],
                         'translate(0.000000,1254.000000) scale(0.100000,-0.100000)')
        self.assertEqual(len(group), 1)
        module = (STYLE / 'lib/mark.luau').read_text()
        digest = hashlib.sha256(raw).hexdigest()
        self.assertEqual(digest, '9bf77758fc360c6c91c8d48a740ea912efe0509cb7260233afa0e0797cf8531a')
        self.assertIn(digest, module)
        self.assertIn(str(asset.relative_to(ROOT)), module)
        self.assertIn('viewBox = { 238, 130, 777, 1000 }', module)
        self.assertIn('w = 17.094', module)
        self.assertIn('h = 22', module)
        self.assertEqual(Decimal('17.094') / 22, Decimal(777) / 1000)
        generated = re.search(r'd = \[\[(.*?)\]\]', module, re.S).group(1)
        # Independent source interpreter: compare every absolute control/end point,
        # including relative moveto after close, not a screenshot or hash alone.
        expected = []
        current = [Decimal(0), Decimal(0)]
        start = current[:]
        for block in re.finditer(r'([MmLlCcZz])([^MmLlCcZz]*)', group[0].attrib['d']):
            command, numbers = block.groups()
            values = [Decimal(n) for n in re.findall(r'-?\d+(?:\.\d+)?', numbers)]
            if command.lower() == 'z':
                self.assertEqual(values, [])
                expected.append(('Z', []))
                current = start[:]
                continue
            stride = 6 if command.lower() == 'c' else 2
            self.assertEqual(len(values) % stride, 0)
            for index in range(0, len(values), stride):
                points = values[index:index + stride]
                if command.islower():
                    points = [value + current[i % 2] for i, value in enumerate(points)]
                kind = command.upper()
                if kind == 'M' and index:
                    kind = 'L'
                if kind == 'M':
                    start = points[:]
                current = points[-2:]
                transformed = [value / 10 if i % 2 == 0 else 1254 - value / 10
                               for i, value in enumerate(points)]
                expected.append((kind, transformed))
        actual = []
        for line in generated.strip().splitlines():
            kind, *values = line.split()
            actual.append((kind, list(map(Decimal, values))))
        self.assertEqual(actual, expected)
        self.assertEqual(sum(kind == 'M' for kind, _ in actual), 2)
        self.assertEqual(sum(kind == 'Z' for kind, _ in actual), 2)
        self.assertLess(len(actual), 4096)  # tagged ShellPath command limit
        coordinates = [values for _, values in actual]
        xs = [x for values in coordinates for x in values[::2]]
        ys = [y for values in coordinates for y in values[1::2]]
        self.assertTrue(all(238 <= x <= 1015 for x in xs))
        self.assertTrue(all(130 <= y <= 1130 for y in ys))
        # Exact control hull stays inside the original padded viewBox, not a crop.
        self.assertEqual((min(xs), max(xs)), (Decimal('249.8'), Decimal('1003')))
        self.assertEqual((min(ys), max(ys)), (Decimal('141.5'), Decimal('1118.2')))

    def test_official_mark_regeneration_and_role_contract(self):
        result = subprocess.run(
            [sys.executable, '-B', str(STYLE / 'tools/generate_mark.py'), '--check'],
            capture_output=True, text=True, timeout=30)
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (0, 'Official mark is up to date\n', ''))
        source = (STYLE / 'lib/continuum.luau').read_text()
        self.assertIn('local mark = require("./mark")', source)
        self.assertIn('if role then\n        -- Official', source)
        self.assertIn('ui.path{ d = mark.d, viewBox = mark.viewBox,', source)
        self.assertIn('w = mark.w, h = mark.h, fill = "accent"', source)
        self.assertNotRegex(source, r'text = "(?:Refactor|IA|RefactorIA)"')
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        for assertion in ['assert(#marks == (if mapped then 1 else 0))',
                          'assert(node.d == mark.d and node.fill == "accent")',
                          'assert(node.w == 17.094 and node.h == 22)',
                          'assert(node.viewBox[index] == value)',
                          'assert(node.onClick == nil and node.font == nil)',
                          'assert(leading[2][1] == marks[1])']:
            self.assertIn(assertion, fixture)

    def test_manifest_api_and_installable_profile(self):
        manifest = toml('style.toml')
        self.assertEqual((manifest['format'], manifest['api'], manifest['name']),
                         (1, 1, 'refactoria'))
        self.assertEqual(manifest['minOmniWM'], '0.8.0')
        self.assertRegex(manifest['version'], r'^\d+\.\d+\.\d+$')
        profile = toml('shell.toml')
        self.assertEqual(profile['theme'], 'refactoria')
        self.assertEqual(profile['leading'], ['refactoria-spaces'])
        self.assertEqual(profile['center'], [])
        self.assertEqual(profile['trailing'], ['refactoria-status'])
        for name in profile['leading'] + profile['trailing']:
            entry = STYLE / 'widgets' / name / 'init.luau'
            self.assertTrue(entry.is_file(), entry)
            self.assertIn('function render(ctx)', entry.read_text())
        self.assertNotIn('profile', profile)  # profile-local, not host activation

    def test_flat_continuum_geometry(self):
        bar = toml('shell.toml')['workspaceBar']
        self.assertEqual(bar['position'], 'overlappingMenuBar')
        self.assertEqual(bar['height'], 36)
        for flag in ['fullWidth', 'reserveLayoutSpace', 'showAccentHighlights']:
            self.assertIs(bar[flag], True)
        for flag in ['transparentBackground', 'showItemBackgrounds', 'hideEmptyWorkspaces']:
            self.assertIs(bar[flag], False)
        self.assertEqual(bar['barFill'], 'background')
        self.assertEqual(bar['barBorder'], 'border')

    def test_all_mapped_outer_insets_use_space_3_only(self):
        inset = int(dark_tokens()('space-3').removesuffix('px'))
        self.assertEqual(inset, 16)
        source = (STYLE / 'lib/continuum.luau').read_text()
        leading, trailing = source.split('function M.trailing(ctx, ui, config)')
        # A zero-gap outer row adds exactly one spacer, not an extra lane gap
        # or symmetrical padding that also changes the notch-facing edge.
        self.assertIn(
            'if role then\n'
            '        return ui.row{ gap = 0, h = 35,\n'
            f'            ui.box{{ w = {inset}, h = 35 }}, ui.row(row),\n'
            '        }\n'
            '    end\n'
            '    return ui.row(row)', leading)
        self.assertIn(
            'return ui.row{ gap = 0, h = 35,\n'
            f'        ui.row(row), ui.box{{ w = {inset}, h = 35 }},\n'
            '    }', trailing)
        self.assertIn('if not role then return empty(ui) end', trailing)
        self.assertEqual(source.count(f'ui.box{{ w = {inset}, h = 35 }}'), 2)
        self.assertNotRegex(source, r'\b(?:radius|padLeft|padRight|padding)\s*=')
        self.assertIn('pad = if role == "lg" then 0 else 9', source)
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        self.assertIn('assert(#spacers(leading) == 1 and #spacers(trailing) == 1)', fixture)
        self.assertIn('assert(#spacers(leading) == 0 and #spacers(trailing) == 0)', fixture)
        readme = (STYLE / 'README.md').read_text()
        self.assertIn('`space-3`', readme)
        self.assertIn('16-point', readme)

    def test_lg_brand_clock_only_and_no_unnecessary_feeds(self):
        source = (STYLE / 'lib/continuum.luau').read_text()
        leading, trailing = source.split('function M.trailing(ctx, ui, config)')
        self.assertIn('if role then\n        -- Official', leading)
        # Keep app lookup wide-only; LG's early branch reads just the clock.
        self.assertIn('if role and role ~= "lg" then\n'
                      '        -- ctx.data.app is global', leading)
        clock_branch, metrics_branch = trailing.split('    else\n', 1)
        self.assertIn('if role == "lg" then', clock_branch)
        self.assertIn('metric(ui, "", ctx.data.clock)', clock_branch)
        self.assertEqual(re.findall(r'ctx\.data\.(\w+)', clock_branch), ['bar', 'clock'])
        self.assertIn('ctx.data.cpu', metrics_branch)
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        for expected in ['"1|2|3|4|5|6|7"', 'assert(#clicks == 7)',
                         'LG requested unnecessary feed', 'assert(reads.bar and reads.clock)',
                         'assert(texts(trailing) == "14:32"', 'click.target == "workspace " .. id',
                         'click.help == tostring(index) .. ": " .. names[index]']:
            self.assertIn(expected, fixture)
        widget = (STYLE / 'widgets/refactoria-status/init.luau').read_text()
        self.assertIn('return view.trailing(ctx, ui, config)', widget)
        self.assertNotRegex(widget, r'ctx\.data\.\w+')

    def test_lg_number_labels_use_native_stack_alignment_only(self):
        source = (STYLE / 'lib/continuum.luau').read_text()
        self.assertIn('local tab = if role == "lg" then ui.stack else ui.row', source)
        self.assertIn('local node = tab{', source)
        self.assertIn('align = if role == "lg" then "center" else nil', source)
        self.assertIn('w = if role == "lg" then 36 else nil', source)
        self.assertIn('pad = if role == "lg" then 0 else 9', source)
        self.assertIn('node = ui.stack{ key = workspace.id, node,\n'
                      '                ui.path{ h = 3, align = "bottom"', source)
        self.assertNotRegex(source, r'\b(?:justify|textAlign)\s*=')
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        for assertion in [
            'assert(click.kind == "stack" and click[1].align == "center")',
            'assert(#click == 1 and click[1].text == tostring(index))',
            'assert(#active == 1 and #active[1] == 2 and active[1][2] == lines(tree)[1])',
            'assert(lines(tree)[1].align == "bottom" and lines(tree)[1].w == nil)',
            'assert(tab.kind == (if entry[1] == "display:2" then "stack" else "row"))',
            'assert(tab[1].align == (if entry[1] == "display:2" then "center" else nil))',
        ]:
            self.assertIn(assertion, fixture)
        readme = (STYLE / 'README.md').read_text()
        self.assertIn('Full Width on for all four displays', readme)
        self.assertIn('centered within each 36-point click target', readme)
        for obsolete in ['Full Width off', 'fullWidth=false', 'non-full-width',
                         "LG's short-strip settings"]:
            self.assertNotIn(obsolete, readme)

    def test_palette_uses_canonical_dark_tokens_in_both_appearances(self):
        token = dark_tokens()
        roles = {'background': 'background', 'surface': 'background-2',
                 'elevatedSurface': 'background-3', 'foreground': 'text',
                 'secondaryForeground': 'text-2', 'mutedForeground': 'text-2',
                 'accent': 'brand-500', 'accentForeground': 'brand-text',
                 'border': 'border', 'focus': 'text'}
        palette = toml('themes/refactoria.toml')
        for mode in ['light', 'dark']:
            self.assertEqual(set(palette[mode]), set(roles))
            for role, name in roles.items():
                with self.subTest(mode=mode, role=role):
                    self.assertEqual(palette[mode][role].lower(), token(name))

    def test_retina_native_menu_access_only(self):
        source = (STYLE / 'lib/continuum.luau').read_text()
        leading, trailing = source.split('function M.trailing(ctx, ui, config)')
        self.assertIn('local node = ui.path{ d = mark.d, viewBox = mark.viewBox,\n'
                      '            w = mark.w, h = mark.h, fill = "accent" }', leading)
        self.assertIn('if role == "retina" then\n'
                      '            -- Only Retina wraps the unchanged mark in the native Apple menu target.\n'
                      '            node = ui.stack{ w = 28, h = 28, cursor = "pointer", hover = "surface",\n'
                      '                onClick = "menu apple", help = "Apple Menu", node }\n'
                      '        end\n'
                      '        table.insert(row, node)', leading)
        for action, label in [('menu apple', 'Apple Menu'),
                              ('shell toggle hidden-bar', 'Hidden Icons Bar')]:
            self.assertIn(f'onClick = "{action}", help = "{label}"', leading)
            self.assertNotIn(action, trailing)
        self.assertNotIn('applelogo', leading)
        self.assertIn('ui.symbol{ name = "app.dashed", size = 14, w = 14, h = 14, color = "foreground" }', leading)
        self.assertEqual(leading.count('ui.stack{ w = 28, h = 28, cursor = "pointer", hover = "surface",'), 2)
        self.assertIn('table.insert(row, ui.row{ gap = 4,', leading)
        self.assertLess(leading.index('w = mark.w'), leading.index('onClick = "menu apple"'))
        self.assertLess(leading.index('onClick = "shell toggle hidden-bar"'), leading.index('local tabs ='))
        self.assertNotRegex(source, r'"menu app"|session (?:restart|shutdown|logout)|hidden-bar activate|ctx\.data\.hiddenBar')
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        for assertion in ['assert(#menus == (if retina then 2 else 0))',
                          'assert(menus[1].onClick == "menu apple" and menus[1].help == "Apple Menu")',
                          'assert(menus[2].onClick == "shell toggle hidden-bar" and menus[2].help == "Hidden Icons Bar")',
                          'assert(content[1] == menus[1] and menus[1][1].d == mark.d)',
                          'assert(content[2][1] == menus[2] and #content[2] == 1 and content[2].gap == 4)',
                          'assert(menus[2][1].name == "app.dashed")',
                          'return node.kind == "symbol" and node.name == "applelogo"',
                          'assert(#workspaceActions(leading) == 2)',
                          'assert(button.w == 28 and button.h == 28 and button.cursor == "pointer")']:
            self.assertIn(assertion, fixture)
        readme = (STYLE / 'README.md').read_text()
        for required in ['28 × 28-point', 'isotipo opens Apple Menu', 'no separate Apple symbol',
                         'plain nonclickable path', 'Apple Menu', 'Hidden Icons Bar',
                         'menu apple', 'shell toggle hidden-bar', 'not all running apps',
                         'No hidden items', 'Full Disk Access', 'not evidence of this host',
                         'VoiceOver', 'zero extra Retina inset', 'leave permissions/settings untouched']:
            self.assertIn(required, readme)

    def test_retina_clicks_and_hidden_native_panel_availability(self):
        source = (STYLE / 'lib/continuum.luau').read_text()
        self.assertIn('local function metric(ui, label, value, action)', source)
        self.assertIn('row.onClick = action', source)
        self.assertIn('row.cursor = if action then "pointer" else nil', source)
        self.assertIn('percent(ctx, ctx.data.volume), "shell toggle volume"', source)
        self.assertIn('metric(ui, "", label, "shell toggle wifi")', source)
        self.assertIn('if role == "retina" then "shell toggle calendar" else nil', source)
        self.assertNotRegex(source, r'omniwm\.run|wifi authorize|calendar authorize|volume permission|\.ssid')
        profile = toml('shell.toml')
        self.assertEqual(profile['drawer'], {'refactoria-panels': {
            'edge': 'right', 'widgets': ['wifi', 'calendar', 'volume'], 'hover': False}})
        self.assertEqual(profile['leading'] + profile['center'] + profile['trailing'],
                         ['refactoria-spaces', 'refactoria-status'])
        fixture = (STYLE / 'checks/behavior.luau').read_text()
        for assertion in ['assert(#clicks == 3)', 'clicks[1].onClick == "shell toggle volume"',
                          'clicks[2].onClick == "shell toggle wifi"',
                          'clicks[3].onClick == "shell toggle calendar"',
                          'assert(#actions(view.trailing(ctx, ui, config)) == 0)',
                          'Wi-Fi requested private field:']:
            self.assertIn(assertion, fixture)
        readme = (STYLE / 'README.md').read_text()
        for limitation in ['shell toggle wifi', 'shell toggle calendar', 'shell toggle volume',
                           '[drawer.refactoria-panels]', 'hover = false', 'not a network chooser',
                           'top-right', 'Calendar access', 'Location', 'six required widgets']:
            self.assertIn(limitation, readme)

    def test_native_type_and_small_text_contrast(self):
        source = (STYLE / 'lib/continuum.luau').read_text()
        props = re.findall(r'ui\.text\{(.*?)\}', source, re.S)
        self.assertTrue(props)
        for text in props:
            with self.subTest(text=text):
                self.assertRegex(text, r'font = "(?:Inter|FiraCode Nerd Font Mono Beard)"')
                self.assertNotRegex(text, r'"(?:bold|semibold|blue|warning)"')
                self.assertRegex(text, r'"(?:foreground|secondaryForeground)"')
                if 'style = "mono"' in text:
                    self.assertIn('font = "FiraCode Nerd Font Mono Beard"', text)
        self.assertNotIn('text = "Refactor"', source)
        self.assertNotIn('text = "RefactorIA"', source)
        self.assertIn('ui.row{ gap = 0,', source)
        self.assertIn('weight = if workspace.focused then "medium" else "regular"', source)
        for box in re.findall(r'ui\.box\{(.*?)\}', source, re.S):
            self.assertNotIn('fill = "accent"', box)
        self.assertNotIn(chr(0xF0F00), source)

    def test_display_defaults_and_telemetry_contract_preserved(self):
        source = (STYLE / 'lib/config.luau').read_text()
        self.assertEqual(re.findall(r'(retina|lg|xiaomi|samsung) = \{ id = "", name = "" \}', source),
                         ['retina', 'lg', 'xiaomi', 'samsung'])
        self.assertIn('widths = { retina = 250, lg = 252, xiaomi = 180, samsung = 320, unknown = 252 }', source)
        view = (STYLE / 'lib/continuum.luau').read_text()
        self.assertIn('h = 35', view)
        self.assertIn('ui.path{ h = 3', view)
        self.assertIn('if not role then return empty(ui) end', view)
        self.assertIn('ctx.format.bytes(system.memory.used)', view)
        self.assertIn('interval = 2', (STYLE / 'widgets/refactoria-status/init.luau').read_text())

    def test_all_requires_are_contained_and_no_external_processes(self):
        for path in STYLE.rglob('*.luau'):
            text = path.read_text()
            for request in re.findall(r'require\("([^"]+)"\)', text):
                target = ((STYLE / 'lib' / request[7:]) if request.startswith('../lib/')
                          else path.parent / request).with_suffix('.luau').resolve()
                self.assertTrue(target.is_relative_to(STYLE.resolve()), target)
                self.assertTrue(target.is_file(), target)
            for forbidden in ['io.popen', 'os.execute', 'omniwm.http', 'omniwm.provider',
                              'sketchybar', 'bar.monitorUUID', 'bar.width']:
                self.assertNotIn(forbidden, text, path)

    def test_install_and_limitations_are_documented(self):
        readme = (STYLE / 'README.md').read_text()
        for required in [REV, '~/.config/omniwm/shell/refactoria',
                         'styles/refactoria/style.toml', 'reconnect', 'UUID',
                         'omniwmctl query displays', 'omniwmctl query shell-widgets',
                         'menu-bar auto-hide', 'Luau', 'not executed', 'tokens.css',
                         'Inter', 'FiraCode Nerd Font Mono Beard', '#RRGGBBAA',
                         'WOFF2', '22-point', 'glow', 'amber']:
            self.assertIn(required, readme)

    @unittest.skipUnless(shutil.which('luau'), 'Luau executable unavailable; no runtime proof')
    def test_native_luau_behavior(self):
        result = subprocess.run(['luau', str(STYLE / 'checks/behavior.luau')],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (0, 'RefactorIA: 17 behavior checks passed\n', ''))

    @unittest.skipUnless(TAGGED, 'use --tagged-api for pinned upstream HTTP audit')
    def test_tagged_official_mark_renderer(self):
        base = f'https://raw.githubusercontent.com/OmniNull/OmniWM/{REV}/'
        paths = ['Sources/OmniWM/Core/Shell/ShellPath.swift',
                 'Sources/OmniWM/Core/Shell/ShellLayerScene+Enter.swift',
                 'Sources/OmniWM/Core/Shell/ShellLayerScene+Paint.swift',
                 'Sources/OmniWM/Core/Shell/ShellLayerScene.swift',
                 'Sources/OmniWMScriptHost/ShellRender.cpp',
                 'Sources/OmniWM/Resources/omniwm.d.luau']
        sources = []
        for path in paths:
            raw = urllib.request.urlopen(base + path, timeout=30).read()
            sources.append(raw.decode())
            print(f'{path}: sha256={hashlib.sha256(raw).hexdigest()}')
        parser, scene, paint, layers, wire, types = sources
        for expected in ['static let maximumCommands = 4096',
                         'scaleX: size.width / viewBox.width, y: size.height / viewBox.height',
                         '.translatedBy(x: -viewBox.minX, y: -viewBox.minY)',
                         'case UInt8(ascii: "c"):', 'current = start',
                         'path.addCurve(to: point, control1: first, control2: second']:
            self.assertIn(expected, parser)
        self.assertIn('shape.fillRule = spec.evenOdd ? .evenOdd : .nonZero', scene)
        self.assertIn('path?.path(fitting: viewBox, into: size)', scene)
        self.assertIn('shape.fillColor = fill ?? Self.clear', paint)
        self.assertIn('kind == .path ? CAShapeLayer() : CALayer()', layers)
        self.assertIn('case AtomD: node.text = internValue(L, -1, instance)', wire)
        self.assertIn('viewBox must be a list of 4 numbers: x, y, width, height', wire)
        self.assertRegex(types, r'export type PathProps = Props & \{\s+d: string,\s+viewBox: \{ number \}\?,\s+evenOdd: boolean\?,')
        self.assertIn('path: (props: PathProps) -> Element', types)

    @unittest.skipUnless(TAGGED, 'use --tagged-api for pinned upstream HTTP audit')
    def test_tagged_native_popout_contract(self):
        paths = ['Sources/OmniWM/Core/Shell/' + name for name in [
            'ShellWidgetHost.swift', 'ShellWidgetHost+Interaction.swift',
            'ShellWidgetHost+Drawers.swift', 'ShellWidgetHost+Lifecycle.swift',
            'ShellWidgetHost+Delivery.swift', 'ShellConfig+Services.swift']]
        paths += [f'Sources/OmniWM/ShellDefault/widgets/{name}/init.luau'
                  for name in ['wifi', 'calendar', 'volume']]
        sources = {}
        for path in paths:
            raw = urllib.request.urlopen(
                f'https://raw.githubusercontent.com/OmniNull/OmniWM/{REV}/{path}',
                timeout=30).read()
            sources[path.rsplit('/', 1)[-1] if path.endswith('.swift') else path] = raw.decode()
            print(f'{path}: sha256={hashlib.sha256(raw).hexdigest()}')
        # Exact string-action parser, not an assumed callback or OS shell command.
        self.assertIn('words.count == 3, words[0] == "shell", words[1] == "toggle"',
                      sources['ShellWidgetHost.swift'])
        self.assertIn('self = .toggle(widget: words[2])', sources['ShellWidgetHost.swift'])
        interaction = sources['ShellWidgetHost+Interaction.swift']
        self.assertIn('guard let parsed = ShellAction(command)', interaction)
        self.assertIn('if !toggle(widget, on: origin.monitor)', interaction)
        self.assertIn('guard let state = widgets[name] else { return false }', interaction)
        self.assertIn('explicit ?? anchored?.1 ?? Self.edgeAnchor(on: monitor)', interaction)
        self.assertIn('headless = (state.name, key)', interaction)
        self.assertIn('frame: CGRect(x: visible.maxX - 1, y: visible.maxY - 1', interaction)
        self.assertIn('return togglePopout(of: name, on: monitor)', sources['ShellWidgetHost+Drawers.swift'])
        self.assertIn('+ config.drawers.flatMap(\\.widgets)', sources['ShellWidgetHost+Lifecycle.swift'])
        self.assertIn('config.widget(name) ?? ShellConfig.bundledWidget(name)',
                      sources['ShellWidgetHost+Lifecycle.swift'])
        self.assertIn('config.barLane(of: state.name)', sources['ShellWidgetHost+Delivery.swift'])
        self.assertIn('hover: table["hover"] == .boolean(true)', sources['ShellConfig+Services.swift'])
        for name, module in [('wifi', 'wifi'), ('calendar', 'calendar'), ('volume', 'audio')]:
            source = sources[f'Sources/OmniWM/ShellDefault/widgets/{name}/init.luau']
            self.assertIn('function popout(ctx)', source)
            self.assertIn(f'require("../lib/{module}")', source)

    @unittest.skipUnless(TAGGED, 'use --tagged-api for pinned upstream HTTP audit')
    def test_tagged_native_menu_access(self):
        paths = ['Sources/OmniWM/ShellDefault/widgets/apple-menu/init.luau',
                 'Sources/OmniWM/ShellDefault/lib/menu-button.luau',
                 'Sources/OmniWM/ShellDefault/widgets/hidden-bar/init.luau',
                 'Sources/OmniWM/Core/Shell/ShellWidgetHost.swift',
                 'Sources/OmniWM/Core/Shell/ShellWidgetHost+Interaction.swift',
                 'Sources/OmniWM/Core/Shell/ShellWidgetHost+Drawers.swift',
                 'Sources/OmniWM/Resources/omniwm.d.luau']
        sources = []
        for path in paths:
            raw = urllib.request.urlopen(
                f'https://raw.githubusercontent.com/OmniNull/OmniWM/{REV}/{path}',
                timeout=30).read()
            sources.append(raw.decode())
            print(f'{path}: sha256={hashlib.sha256(raw).hexdigest()}')
        apple, button, hidden, parser, interaction, drawers, types = sources
        self.assertIn('symbol = "applelogo", action = "menu apple", help = omniwm.l10n("Apple Menu")', apple)
        self.assertIn('ui.symbol{ name = props.symbol', button)
        self.assertIn('onClick = props.action, help = props.help', button)
        self.assertIn('words == ["menu", "apple"]', parser)
        self.assertIn('self = .menu(.apple)', parser)
        self.assertIn('words.count == 3, words[0] == "shell", words[1] == "toggle"', parser)
        self.assertIn('self = .toggle(widget: words[2])', parser)
        self.assertIn('if !toggle(widget, on: origin.monitor)', interaction)
        self.assertIn('return togglePopout(of: name, on: monitor)', drawers)
        self.assertIn('config.hiddenBarWidget == state.name ? "hidden bar" : nil', drawers)
        self.assertIn('function popout(ctx: Context)', hidden)
        self.assertIn('omniwm.l10n("No hidden items")', hidden)
        self.assertIn('look.glyph{ name = "app.dashed"', hidden)
        self.assertIn('onClick = "hidden-bar activate " .. item.id', hidden)
        self.assertIn('export type SymbolProps = Props & {', types)
        self.assertIn('help: string?', types)
        self.assertIn('symbol: (props: SymbolProps) -> Element', types)

    @unittest.skipUnless(TAGGED, 'use --tagged-api for pinned upstream HTTP audit')
    def test_tagged_api_inventory(self):
        base = f'https://raw.githubusercontent.com/OmniNull/OmniWM/{REV}/'
        paths = ['Sources/OmniWM/Resources/omniwm.d.luau',
                 'Sources/OmniWM/Core/Shell/ShellStyleManifest.swift',
                 'Sources/OmniWM/Core/Config/MonitorBarSettings.swift',
                 'Sources/OmniWM/UI/WorkspaceBar/WorkspaceBarOptions.swift',
                 'Sources/OmniWM/Core/Shell/ShellGitHubStyleSource.swift',
                 'Sources/OmniWM/Core/Shell/ShellTheme.swift',
                 'Sources/OmniWM/Core/Shell/ShellFontLibrary.swift',
                 'Sources/OmniWM/Core/Shell/ShellTextStore.swift',
                 'website/src/content/docs/omnishell/reference/layout-styling.mdx',
                 'website/src/content/docs/omnishell/reference/ui-elements.mdx']
        sources = {}
        for path in paths:
            raw = urllib.request.urlopen(base + path, timeout=30).read()
            sources[path] = raw.decode()
            print(f'{path}: sha256={hashlib.sha256(raw).hexdigest()}')
        types = sources[paths[0]]
        def fields(name):
            body = re.search(r'export type ' + name + r' = [^\n]*\{\n(.*?)\n}',
                             types, re.S).group(1)
            return set(re.findall(r'^    (\w+):', body, re.M))
        lua = '\n'.join(p.read_text() for p in (STYLE / 'lib').glob('*.luau'))
        self.assertTrue(set(re.findall(r'ctx\.data\.(\w+)', lua)) <= fields('Data'))
        self.assertTrue(set(re.findall(r'bar\.(\w+)', lua)) <= fields('Bar'))
        self.assertTrue(set(re.findall(r'workspace\.(\w+)', lua)) <= fields('BarWorkspace'))
        self.assertTrue(set(re.findall(r'item\.(\w+)', lua)) <= fields('BarItem'))
        self.assertNotIn('uuid', ' '.join(fields('Bar') | fields('SystemDisplay')).lower())
        props = fields('Props') | fields('TextProps') | {'d', 'viewBox'}
        self.assertTrue(set(re.findall(r'\b(\w+)\s*=', lua)) - {
            'config', 'ui', 'role', 'bar', 'row', 'tabs', 'node', 'workspace', 'item',
            'label', 'tab', 'app', 'status', 'system', 'wifi', 'volume', 'battery', 'data',
            'matches', 'selected', 'entry', 'slots', 'result', 'value', 'text',
            'M', 'mark', 'leading', 'trailing', 'resolve', 'empty', 'metric', 'percent',
            'unknown', 'retina', 'lg', 'xiaomi', 'samsung', 'displays', 'widths', 'id', 'name',
        } <= props)
        manifest_source = sources[paths[1]]
        for key in toml('style.toml'):
            self.assertIn('"' + key + '"', manifest_source)
        bar_source = sources[paths[2]]
        for key in toml('shell.toml')['workspaceBar']:
            self.assertIn(key, bar_source)
        self.assertIn('case overlappingMenuBar', sources[paths[3]])
        self.assertIn('case splitAroundNotch', sources[paths[3]])
        self.assertIn('static let folder = "styles"', sources[paths[4]])
        self.assertIn('font', fields('TextProps'))
        self.assertIn('export type Font = "system" | string', types)
        self.assertIn('"medium"', types)
        # Palette TOML accepts literal RGBA; role/alpha is for UI props, not TOML.
        self.assertIn('digits.count == 6 || digits.count == 8', sources[paths[5]])
        self.assertIn('let rgba = digits.count == 6 ? (value << 8) | 0xFF : value', sources[paths[5]])
        self.assertIn('["ttf", "otf"]', sources[paths[6]])
        self.assertIn('case 2: .monospacedDigitSystemFont', sources[paths[7]])
        self.assertIn('default: .systemFont', sources[paths[7]])
        self.assertIn('"#RRGGBBAA"', sources[paths[8]])
        self.assertTrue({'w', 'h', 'gap', 'pad', 'align'} <= fields('Props'))
        self.assertIn('"center"', re.search(r'export type Align =\n(.*?)\nexport type Element',
                                          types, re.S).group(1))
        self.assertIn('`align` positions each child', sources[paths[9]])
        self.assertIn('Placement inside an overlapping stack; defaults to center', sources[paths[8]])
        self.assertIn('Center children across the row/column’s cross axis', sources[paths[8]])
        self.assertIn('omitted dimensions use intrinsic layout', sources[paths[8]])
        self.assertIn('Equal inset on all sides', sources[paths[8]])
        self.assertIn('Children from left to right; `gap` separates them', sources[paths[9]])
        self.assertIn('unknown names use the system font', sources[paths[9]])


if __name__ == '__main__':
    unittest.main()
