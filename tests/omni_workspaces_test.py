"""Isolated tests for the OmniWM workspace listener and its launchd helper.

Every external program (omniwmctl, sketchybar, launchctl) is a fake script in a
temp directory; nothing touches the live bar, OmniWM IPC, or launchd.
"""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
LISTENER = ROOT / 'sketchybar/plugins/omni_workspaces.py'
HELPER = ROOT / 'sketchybar/plugins/omni_workspaces.sh'
RC = ROOT / 'sketchybar/sketchybarrc'

LG_IDS = ['1c9a5b0e-0000-4000-8000-00000000000%d' % i for i in range(1, 8)]
MAC_WS = '2d9a5b0e-0000-4000-8000-000000000001'

FAKE_CTL = textwrap.dedent('''\
    #!/usr/bin/env python3
    import json, os, sys, time
    d = os.environ['FAKE_DIR']
    with open(os.path.join(d, 'ctl.log'), 'a') as f:
        f.write(json.dumps(sys.argv[1:]) + '\\n')
    n = len(open(os.path.join(d, 'ctl.log')).read().splitlines())
    plan = json.load(open(os.path.join(d, 'plan.json')))
    step = plan[min(n, len(plan)) - 1]
    open(os.path.join(d, 'ctl.pid'), 'w').write(str(os.getpid()))
    if 'displays' in step:
        open(os.path.join(d, 'displays.json'), 'w').write(json.dumps(step['displays']))
    for line in step.get('lines', []):
        print(line, flush=True)
    if step.get('sleep'):
        time.sleep(step['sleep'])
    sys.exit(step.get('rc', 1))
''')

FAKE_BAR = textwrap.dedent('''\
    #!/usr/bin/env python3
    import json, os, sys
    d = os.environ['FAKE_DIR']
    if sys.argv[1:3] == ['--query', 'displays']:
        print(open(os.path.join(d, 'displays.json')).read())
        sys.exit(0)
    with open(os.path.join(d, 'bar.log'), 'a') as f:
        f.write(json.dumps(sys.argv[1:]) + '\\n')
    sys.exit(int(os.environ.get('FAKE_BAR_RC', '0')))
''')

DISPLAYS = [
    {'arrangement-id': 1, 'DirectDisplayID': 1, 'UUID': 'mac'},
    {'arrangement-id': 3, 'DirectDisplayID': 7, 'UUID': 'lg'},
]


def workspace(uid, raw, name, focused=False):
    return {'id': uid, 'rawName': raw, 'displayName': name,
            'number': int(raw) if raw.isdigit() else None,
            'isFocused': focused, 'windows': []}


def event(monitors, channel='workspace-bar'):
    return json.dumps({'version': 22, 'kind': 'event', 'channel': channel,
                       'ok': True, 'status': 'success',
                       'result': {'kind': 'ignored',
                                  'payload': {'interactionMonitorId': 'display:7',
                                              'monitors': monitors}}})


ACK = json.dumps({'version': 22, 'kind': 'response', 'ok': True, 'status': 'success'})


def lg_monitor(focused_index=2, names=None):
    names = names or ['term', 'web', 'grok bot', 'mail', 'notes', 'music', 'a very long workspace name']
    return {'id': 'display:7', 'name': 'LG', 'isVisible': True, 'enabled': False,
            'workspaces': [workspace(LG_IDS[i], str(i + 1), names[i], i == focused_index)
                           for i in range(7)]}


def mac_monitor():
    return {'id': 'display:1', 'name': 'Built-in', 'isVisible': True, 'enabled': False,
            'workspaces': [workspace(MAC_WS, "it's; $(x)", '', True)]}


class Harness:
    def __init__(self, plan):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        for name, body in [('omniwmctl', FAKE_CTL), ('sketchybar', FAKE_BAR)]:
            path = self.dir / name
            path.write_text(body)
            path.chmod(0o755)
        (self.dir / 'plan.json').write_text(json.dumps(plan))
        (self.dir / 'displays.json').write_text(json.dumps(DISPLAYS))
        self.env = {'PATH': '/usr/bin:/bin', 'FAKE_DIR': str(self.dir),
                    'OMNIWMCTL': str(self.dir / 'omniwmctl'),
                    'SKETCHYBAR': str(self.dir / 'sketchybar'),
                    'OMNI_WS_LOCK': str(self.dir / 'listener.lock'),
                    'OMNI_WS_BACKOFF': '0.01',
                    'CONFIG_DIR': str(ROOT / 'sketchybar')}

    def run(self, timeout=20):
        return subprocess.run([sys.executable, str(LISTENER)], env=self.env,
                              text=True, capture_output=True, timeout=timeout)

    def start(self):
        return subprocess.Popen([sys.executable, str(LISTENER)], env=self.env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def log(self, name):
        path = self.dir / name
        return [json.loads(l) for l in path.read_text().splitlines()] if path.exists() else []

    def wait_for(self, name, timeout=10):
        deadline = time.time() + timeout
        while not (self.dir / name).exists() and time.time() < deadline:
            time.sleep(0.02)

    def close(self):
        self.tmp.cleanup()


def sets(call):
    """Map item -> {prop: value} from one sketchybar batch argv."""
    out, current = {}, None
    for arg in call:
        if arg.startswith('--'):
            current = None
            continue
        if current is None and '=' not in arg:
            current = arg
            out.setdefault(current, {})
        elif current and '=' in arg:
            key, value = arg.split('=', 1)
            out[current][key] = value
    return out


class ListenerTests(unittest.TestCase):
    def harness(self, plan):
        h = Harness(plan)
        self.addCleanup(h.close)
        return h

    def test_renders_each_monitor_with_focus_highlight_and_safe_click(self):
        h = self.harness([{'lines': [ACK, event([lg_monitor(), mac_monitor()])], 'rc': 1}])
        result = h.run()
        self.assertEqual(result.returncode, 1)
        self.assertIn('denied', result.stderr)
        self.assertEqual(h.log('ctl.log'), [['subscribe', 'workspace-bar,display-changed',
                                             '--reconnect', '--format', 'ndjson']])
        first = h.log('bar.log')[0]
        items = sets(first)
        lg = ['omni.ws.' + uid for uid in LG_IDS]
        for name in lg:
            self.assertEqual(items[name]['display'], '3')
        self.assertEqual(items['omni.ws.' + MAC_WS]['display'], '1')
        self.assertEqual(items[lg[2]]['label'], 'grok bot')
        self.assertEqual(items[lg[2]]['icon'], '3')
        self.assertEqual(items[lg[6]]['label'], 'a very lon…')
        self.assertEqual(items[lg[2]]['background.border_width'], '1')
        self.assertEqual(items[lg[0]]['background.border_width'], '0')
        self.assertEqual(items[lg[2]]['background.color'], '0xff2c2144')
        self.assertEqual(items['omni.ws.' + MAC_WS]['label.drawing'], 'off')
        click = items['omni.ws.' + MAC_WS]['click_script']
        self.assertEqual(click, "%s workspace focus-name 'it'\"'\"'s; $(x)'" % h.env['OMNIWMCTL'])
        self.assertEqual(first.count('--add'), 8)
        self.assertIn(['--move', lg[0], 'before', 'front_app'],
                      [first[i:i + 4] for i in range(len(first) - 3)])
        # Disconnection never leaves stale active indicators behind.
        self.assertEqual(sorted(sets(h.log('bar.log')[-1])), sorted(lg + ['omni.ws.' + MAC_WS]))
        self.assertIn('--remove', h.log('bar.log')[-1])

    def test_updates_only_changes_and_ignores_duplicates_and_malformed_events(self):
        moved = lg_monitor(focused_index=4)
        h = self.harness([{'lines': [ACK, event([lg_monitor()]), event([lg_monitor()]),
                                     '{not json', json.dumps({'kind': 'event', 'result': 5}),
                                     event([moved])], 'rc': 1}])
        h.run()
        calls = h.log('bar.log')
        self.assertEqual(len(calls), 3, calls)  # initial, focus change, disconnect cleanup
        change = calls[1]
        self.assertNotIn('--add', change)
        self.assertEqual(sorted(sets(change)), sorted(['omni.ws.' + LG_IDS[2], 'omni.ws.' + LG_IDS[4]]))

    def test_monitor_mapping_changes_and_stale_items_are_removed(self):
        smaller = lg_monitor()
        smaller['workspaces'] = smaller['workspaces'][:5]
        # On reconnect the LG is re-enumerated as arrangement 2 and the Mac display is gone.
        swap = [{'arrangement-id': 2, 'DirectDisplayID': 7, 'UUID': 'lg'}]
        h = self.harness([{'lines': [ACK, event([lg_monitor(), mac_monitor()])], 'rc': 2},
                          {'displays': swap, 'lines': [ACK, event([smaller, mac_monitor()])], 'rc': 1}])
        h.run()
        calls = h.log('bar.log')
        self.assertEqual(set(sets(calls[1])), set('omni.ws.' + u for u in LG_IDS + [MAC_WS]))
        self.assertIn('--remove', calls[1])
        reconnect = sets(calls[2])
        self.assertEqual(calls[2].count('--add'), 5)
        self.assertEqual(reconnect['omni.ws.' + LG_IDS[0]]['display'], '2')
        self.assertNotIn('omni.ws.' + MAC_WS, reconnect)

    def test_malformed_nested_payload_is_rejected_whole_and_keeps_bar(self):
        bad_ws = lg_monitor()
        bad_ws['workspaces'] = [None] + bad_ws['workspaces']
        bad_id = lg_monitor()
        bad_id['workspaces'][0]['id'] = 5
        bad_raw = lg_monitor()
        bad_raw['workspaces'][0]['rawName'] = ['x']
        scalar = lg_monitor()
        scalar['workspaces'] = 5
        h = self.harness([{'lines': [ACK, event([lg_monitor(), mac_monitor()]),
                                     event(['oops', lg_monitor()]), event([None]),
                                     event([scalar]), event([bad_ws]), event([bad_id]),
                                     event([bad_raw])], 'rc': 1}])
        result = h.run()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('Traceback', result.stderr)
        calls = h.log('bar.log')
        self.assertEqual(len(calls), 2, calls)  # initial render, disconnect cleanup only
        self.assertNotIn('--remove', calls[0])

    def test_failed_bar_update_is_retried_not_deduplicated(self):
        h = self.harness([{'lines': [ACK, event([lg_monitor()]), event([lg_monitor()])], 'rc': 1}])
        h.env['FAKE_BAR_RC'] = '1'
        result = h.run()
        self.assertNotIn('Traceback', result.stderr)
        self.assertIn('sketchybar update failed', result.stderr)
        calls = h.log('bar.log')
        self.assertEqual(len(calls), 3, calls)  # both renders attempted, then cleanup
        # The retry starts by clearing only our own items, then rebuilds everything.
        self.assertEqual(calls[1][:2], ['--remove', '/^omni\\.ws\\./'])
        self.assertEqual(calls[1].count('--add'), 7)

    def test_missing_sketchybar_binary_does_not_crash(self):
        h = self.harness([{'lines': [ACK, event([lg_monitor()])], 'rc': 1}])
        h.env['SKETCHYBAR'] = str(h.dir / 'missing')
        result = h.run()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('Traceback', result.stderr)

    def test_transport_failure_retries_but_denied_does_not(self):
        h = self.harness([{'rc': 2}, {'rc': 2}, {'rc': 1}])
        result = h.run()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(h.log('ctl.log')), 3)
        denied = self.harness([{'rc': 1}])
        self.assertEqual(denied.run().returncode, 1)
        self.assertEqual(len(denied.log('ctl.log')), 1)

    def test_sigterm_stops_owned_child_and_duplicate_start_is_a_noop(self):
        h = self.harness([{'lines': [ACK], 'sleep': 30, 'rc': 0}])
        proc = h.start()
        self.addCleanup(lambda: proc.poll() is None and (proc.kill(), proc.communicate()))
        h.wait_for('ctl.pid')
        child = int((h.dir / 'ctl.pid').read_text())
        duplicate = h.run()
        self.assertEqual(duplicate.returncode, 0)
        self.assertIn('already running', duplicate.stderr)
        self.assertEqual(len(h.log('ctl.log')), 1)
        proc.send_signal(signal.SIGTERM)
        proc.communicate(timeout=10)
        self.assertEqual(proc.returncode, 0)
        time.sleep(0.2)
        with self.assertRaises(ProcessLookupError):
            os.kill(child, 0)


class HelperTests(unittest.TestCase):
    def run_helper(self, loaded):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        d = Path(tmp.name)
        fake = d / 'launchctl'
        fake.write_text('#!/bin/bash\necho "$*" >> "%s/launchctl.log"\n'
                        '[ "$1" = print ] && exit %d\nexit 0\n' % (d, 0 if loaded else 113))
        fake.chmod(0o755)
        plist = d / 'agent.plist'
        plist.write_text('<plist/>')
        env = {'PATH': '%s:/usr/bin:/bin' % d, 'OMNI_WS_PLIST': str(plist)}
        result = subprocess.run(['bash', str(HELPER)], env=env, text=True,
                                capture_output=True, timeout=10)
        return result, (d / 'launchctl.log').read_text().splitlines(), plist

    def test_reload_kickstarts_only_own_label(self):
        result, calls, _ = self.run_helper(loaded=True)
        uid = os.getuid()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ['print gui/%d/com.cortex.omniwm-workspaces' % uid,
                                 'kickstart -k gui/%d/com.cortex.omniwm-workspaces' % uid])

    def test_missing_agent_is_bootstrapped_from_installed_plist(self):
        result, calls, plist = self.run_helper(loaded=False)
        uid = os.getuid()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[1], 'bootstrap gui/%d %s' % (uid, plist))
        self.assertFalse(any('kill' in c and 'kickstart' not in c for c in calls))


class BarConfigTests(unittest.TestCase):
    def test_native_spaces_replaced_and_bar_only_on_retina(self):
        rc = RC.read_text()
        self.assertNotIn('--add space', rc)
        self.assertIn('MAC_DISPLAY=1', rc)
        bar = rc.split('sketchybar --bar', 1)[1].split('sketchybar --default', 1)[0]
        self.assertIn('display="$MAC_DISPLAY"', bar)
        self.assertNotIn('display=all', bar)
        self.assertNotIn('display=main', rc)
        self.assertIn('omni_workspaces.sh', rc)
        self.assertIn('sketchybar --add item front_app left', rc)


if __name__ == '__main__':
    unittest.main()
