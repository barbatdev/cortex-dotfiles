#!/usr/bin/env python3
"""Mirror OmniWM workspaces into SketchyBar, one group per monitor.

Runs as a single long-lived listener (launchd agent, see omniwm-workspaces.plist).
It owns one `omniwmctl subscribe` child and turns each workspace-bar snapshot into
one batched `sketchybar` call that only touches items whose state changed.

Event fields are untrusted: they are only ever passed as argv elements, and the
click script quotes rawName with shlex.quote. Nothing is evaluated by a shell here.
"""
import fcntl
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time

OMNIWMCTL = os.environ.get('OMNIWMCTL', '/opt/homebrew/bin/omniwmctl')
SKETCHYBAR = os.environ.get('SKETCHYBAR', '/opt/homebrew/bin/sketchybar')
CONFIG_DIR = os.environ.get('CONFIG_DIR', os.path.expanduser('~/.config/sketchybar'))
LOCK_PATH = os.environ.get('OMNI_WS_LOCK', os.path.expanduser('~/.cache/cortex/omni-workspaces.lock'))
BACKOFF = float(os.environ.get('OMNI_WS_BACKOFF', '1'))
BACKOFF_MAX = 30
SUBSCRIBE = ['subscribe', 'workspace-bar,display-changed', '--reconnect', '--format', 'ndjson']
EXIT_DENIED = 1
PREFIX = 'omni.ws.'
ANCHOR = 'front_app'
OWN_ITEMS = r'/^omni\.ws\./'
LABEL_CHARS = 10
UUID_RE = re.compile(r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')
COLOR_NAMES = ('COLOR_TEXT', 'COLOR_MUTED', 'COLOR_RAISED', 'COLOR_PILL_SOFT',
               'COLOR_ACCENT_TEXT', 'COLOR_TRANSPARENT')


#region Palette
def load_colors():
    """Read only the known palette constants from colors.sh; never source it."""
    colors = {}
    try:
        with open(os.path.join(CONFIG_DIR, 'colors.sh')) as handle:
            for line in handle:
                match = re.match(r'^(COLOR_[A-Z_]+)=(0x[0-9a-fA-F]{8})\b', line)
                if match and match.group(1) in COLOR_NAMES:
                    colors[match.group(1)] = match.group(2)
    except OSError:
        pass
    return colors
#endregion


#region Rendering
def arrangement_by_display_id():
    """Map CGDirectDisplayID -> SketchyBar arrangement-id, queried fresh every time."""
    try:
        out = subprocess.run([SKETCHYBAR, '--query', 'displays'], capture_output=True,
                             text=True, timeout=5).stdout
        return {int(d['DirectDisplayID']): int(d['arrangement-id']) for d in json.loads(out)}
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired):
        return None


def truncate(text):
    return text if len(text) <= LABEL_CHARS else text[:LABEL_CHARS] + '…'


def item_props(workspace, display, colors):
    raw = workspace['rawName']
    number = workspace.get('number')
    label = workspace.get('displayName') if isinstance(workspace.get('displayName'), str) else ''
    focused = workspace.get('isFocused') is True
    props = {
        'display': str(display),
        'icon': str(number) if isinstance(number, int) and not isinstance(number, bool) else truncate(raw),
        'label': truncate(label),
        'label.drawing': 'on' if label else 'off',
        'icon.color': colors.get('COLOR_TEXT' if focused else 'COLOR_MUTED', ''),
        'background.color': colors.get('COLOR_RAISED' if focused else 'COLOR_PILL_SOFT', ''),
        'background.border_color': colors.get('COLOR_ACCENT_TEXT' if focused else 'COLOR_TRANSPARENT', ''),
        'background.border_width': '1' if focused else '0',
        'click_script': '%s workspace focus-name %s' % (shlex.quote(OMNIWMCTL), shlex.quote(raw)),
    }
    return {key: value for key, value in props.items() if value != ''}


def valid_payload(payload):
    """Minimal shape check; any malformed entry rejects the whole event."""
    monitors = payload.get('monitors') if isinstance(payload, dict) else None
    if not isinstance(monitors, list):
        return False
    for monitor in monitors:
        if not isinstance(monitor, dict) or not isinstance(monitor.get('workspaces', []), list):
            return False
        for workspace in monitor.get('workspaces', []):
            if not (isinstance(workspace, dict) and isinstance(workspace.get('id'), str)
                    and UUID_RE.match(workspace['id'])
                    and isinstance(workspace.get('rawName'), str) and workspace['rawName']):
                return False
    return True


def desired_items(payload, mapping, colors):
    """Return ordered {item: props} for a valid payload; skips unknown displays."""
    items = {}
    for monitor in payload['monitors']:
        # The native Omni bar may be disabled (`enabled: false`); that is unrelated here.
        match = re.match(r'^display:(\d+)$', str(monitor.get('id', '')))
        display = mapping.get(int(match.group(1))) if match else None
        if display is None:
            continue
        for workspace in monitor.get('workspaces', []):
            items[PREFIX + workspace['id'].lower()] = item_props(workspace, display, colors)
    return items


def batch(previous, desired):
    """Build one sketchybar argv that moves `previous` to `desired`."""
    args = []
    for name in previous:
        if name not in desired:
            args += ['--remove', name]
    added = [name for name in desired if name not in previous]
    for name in added:
        args += ['--add', 'item', name, 'left']
    for name, props in desired.items():
        if previous.get(name) != props:
            args += ['--set', name] + ['%s=%s' % kv for kv in props.items()]
    if added:
        # Keep workspace order and stay between the brand tiles and front_app.
        for name in desired:
            args += ['--move', name, 'before', ANCHOR]
    return args
#endregion


class Listener:
    def __init__(self):
        self.colors = load_colors()
        self.state = {}
        self.dirty = False
        self.payload = None
        self.child = None

    def apply(self, desired):
        if self.dirty:
            # A failed batch may have applied partially: rebuild only our own items.
            args = ['--remove', OWN_ITEMS] + batch({}, desired)
        else:
            args = batch(self.state, desired)
        if not args:
            return
        try:
            code = subprocess.run([SKETCHYBAR] + args, capture_output=True, timeout=10).returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            code = type(error).__name__
        if code != 0:
            # Report only the status; argv carries workspace names.
            print('omni_workspaces: sketchybar update failed (%s)' % code, file=sys.stderr)
            self.dirty = True
            return
        self.state = desired
        self.dirty = False

    def render(self):
        mapping = arrangement_by_display_id()
        if mapping is not None and self.payload is not None:
            self.apply(desired_items(self.payload, mapping, self.colors))

    def handle(self, line):
        try:
            message = json.loads(line)
            if message.get('kind') != 'event' or message.get('ok') is not True:
                return
            payload = message['result']['payload']
            if message.get('channel') == 'workspace-bar':
                if not valid_payload(payload):
                    return
                self.payload = payload
            elif message.get('channel') != 'display-changed':
                return
        except (ValueError, KeyError, TypeError, AttributeError):
            return  # malformed events never change the bar
        self.render()

    def clear(self):
        """Disconnected: drop every workspace item so nothing looks falsely active."""
        self.payload = None
        self.apply({})

    def stop(self, *_):
        if self.child and self.child.poll() is None:
            self.child.terminate()
            try:
                self.child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.child.kill()
        self.clear()
        sys.exit(0)

    def run(self):
        delay = BACKOFF
        while True:
            try:
                self.child = subprocess.Popen([OMNIWMCTL] + SUBSCRIBE, stdout=subprocess.PIPE,
                                              text=True)
            except OSError as error:
                print('omni_workspaces: cannot start omniwmctl: %s' % error, file=sys.stderr)
                return 1
            for line in self.child.stdout:
                delay = BACKOFF
                self.handle(line)
            code = self.child.wait()
            self.clear()
            if code == EXIT_DENIED:
                print('omni_workspaces: IPC denied by OmniWM (exit 1); not retrying',
                      file=sys.stderr)
                return 1
            # Covers the initial connect, which --reconnect does not retry (exit 2).
            time.sleep(delay)
            delay = min(delay * 2, BACKOFF_MAX)


def main():
    os.makedirs(os.path.dirname(LOCK_PATH), exist_ok=True)
    lock = open(LOCK_PATH, 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print('omni_workspaces: already running', file=sys.stderr)
        return 0
    listener = Listener()
    signal.signal(signal.SIGTERM, listener.stop)
    signal.signal(signal.SIGINT, listener.stop)
    return listener.run()


if __name__ == '__main__':
    sys.exit(main())
