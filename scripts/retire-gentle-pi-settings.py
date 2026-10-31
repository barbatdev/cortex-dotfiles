#!/usr/bin/env python3
"""Usage: python3 retire-gentle-pi-settings.py [--apply]. Defaults to dry-run.

Remove only the audited legacy Pi package declarations and launcher overrides.
Keep all other settings, installed package files, credentials and user data.
The backup contains only removed settings, not the complete settings file.
"""
import argparse
import json
import os
from pathlib import Path
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Apply the scoped changes')
    args = parser.parse_args()
    home = Path.home()
    path = home / '.pi/agent/settings.json'
    if any(p.is_symlink() for p in (home / '.pi', home / '.pi/agent', path)):
        raise SystemExit('Refusing symlinked settings path')
    if not path.exists():
        print('No Pi settings file; nothing changed.')
        return
    original = path.read_bytes()
    data = json.loads(original)
    if not isinstance(data, dict):
        raise SystemExit('Expected a JSON object; nothing changed.')
    sources = {
        'git:github.com/Gentleman-Programming/engram@main',
        'npm:pi-claude-bridge', 'npm:gentle-engram@0.4.0',
        'npm:pi-web-access', 'npm:pi-btw',
    }
    removed = {}
    packages = data.get('packages', [])
    if not isinstance(packages, list):
        raise SystemExit('Unexpected packages format; nothing changed.')
    old = [p for p in packages if (p.get('source') if isinstance(p, dict) else p) in sources]
    if old:
        removed['packages'] = old
        data['packages'] = [p for p in packages if p not in old]
    if data.get('npmCommand') == ['pnpm']:
        removed['npmCommand'] = data.pop('npmCommand')
    extensions = data.get('extensions')
    if isinstance(extensions, list) and '-builtin:codemode' in extensions:
        removed['extensions'] = ['-builtin:codemode']
        data['extensions'] = [e for e in extensions if e != '-builtin:codemode']
    print('Legacy package declarations to remove:', len(old))
    print('Remove pnpm command override:', 'npmCommand' in removed)
    print('Restore builtin codemode availability:', 'extensions' in removed)
    print('All other settings and installed package files are preserved.')
    if not args.apply or not removed:
        print('No changes applied.')
        return
    backup = Path(tempfile.mkdtemp(prefix='gentle-settings-retirement.', dir=home))
    backup.chmod(0o700)
    record = backup / 'removed-settings.json'
    fd = os.open(record, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump(removed, f, indent=2)
        f.write('\n')
    fd, staged = tempfile.mkstemp(prefix='.settings-retirement-', dir=path.parent)
    try:
        os.fchmod(fd, path.stat().st_mode & 0o777)
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
        if path.read_bytes() != original:
            raise SystemExit('Settings changed concurrently; refusing replacement.')
        os.replace(staged, path)
        assert json.loads(path.read_text()) == data
    finally:
        if os.path.exists(staged):
            os.unlink(staged)
    print('Applied and verified. Removed-settings backup:', record)


if __name__ == '__main__':
    main()
