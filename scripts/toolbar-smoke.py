#!/usr/bin/env python3
"""Check native floating-panel visibility in an isolated app over the public fixture.

Launch via LaunchServices with TINYHAND_TEST_MODE, TINYHAND_DEFAULTS_SUITE and
TH_HANDS_DIR. Close Settings and put TinyHandFixture frontmost. --repro-only runs
the minimal S-016 regression without injecting pointer events.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
out = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', root / 'dist/verification/s016'))
out.mkdir(parents=True, exist_ok=True)
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
probe = out / 'ToolbarProbe'
source = root / 'Tests/Fixtures/ToolbarProbe.swift'
assert os.environ.get('TINYHAND_TEST_MODE') == '1'
suite = os.environ['TINYHAND_DEFAULTS_SUITE']
assert suite != 'com.austinpresley.pleaselookhere.integration'
if not probe.exists() or probe.stat().st_mtime < source.stat().st_mtime:
    subprocess.run(['swiftc', str(source), '-o', str(probe), '-framework', 'AppKit', '-framework', 'ApplicationServices'], check=True)

def control(op, **fields):
    r = subprocess.run([str(binary), '--ctl', json.dumps({'version': 1, 'operation': op, **fields})], capture_output=True, text=True, timeout=5)
    v = json.loads(r.stdout)
    assert not r.returncode and v['ok'], v
    return v

def ctl(op, **fields):
    return control(op, **fields)['state']

assert control('test-shortcuts', request={})['shortcuts']['defaultsSuite'] == suite, 'Refusing real preferences'
assert not any(w['title'].endswith('Settings') for w in ctl('status')['windows']), 'Close Settings first'
pid = subprocess.check_output(['pgrep', '-x', 'TinyHand'], text=True).strip()
assert pid.isdigit(), 'Expected exactly one running app'
checks = []
panel_id = None

def probe_call(*args):
    return json.loads(subprocess.check_output([str(probe), *map(str, args)], text=True, timeout=5))

def sample(name, expected, settle=.35):
    global panel_id
    time.sleep(settle)
    s = ctl('status')
    if panel_id is None:
        panel_id = next(w['id'] for w in s['windows'] if w['title'] == '' and w['height'] == s['toolbarFrame'][3])
    panel = next((w for w in probe_call('windows', pid) if w['kCGWindowNumber'] == panel_id), None)
    alpha = panel['kCGWindowAlpha'] if panel else 0
    native_visible = alpha > .01
    checks.append({'name': name, 'expected': expected, 'nativeAlpha': alpha, 'state': s, 'panel': panel})
    assert s['toolbarVisible'] is expected and native_visible is expected, f'{name}: setting={s["settings"]["showToolbar"]}, reported={s["toolbarVisible"]}, native opacity={alpha}, expected={expected}'
    print('PASS', name, 'native opacity', alpha, flush=True)
    return s

def move(x, y):
    result = probe_call('move', x, y)
    assert result['ok'], result

try:
    ctl('off')
    ctl('interact', enabled=True)
    ctl('configure', settings={'showToolbar': True, 'handSound': False})
    ctl('on')
    sample('enabled at pointer startup', True)
    ctl('off')
    ctl('configure', settings={'showToolbar': False})
    ctl('on')
    sample('OFF survives pointer reactivation, original regression', False)
    if '--repro-only' not in sys.argv:
        # The helper checks the real frontmost fixture and every target coordinate.
        move(300, 350)
        for motion in ['original', 'responsive']:
            ctl('configure', settings={'motion': motion})
            for interact in [False, True]:
                ctl('interact', enabled=interact)
                s = sample(f'OFF, {motion}, Interact {interact}', False, .1)
                x, y, width, height = s['toolbarFrame']
                screen_height = max(w['height'] for w in s['windows'])
                move(x + width / 2, screen_height - y - height / 2)
                sample(f'OFF ignores hover, {motion}, Interact {interact}', False, .1)
                move(300, 350)
        ctl('configure', settings={'showToolbar': True})
        sample('enabling reveals immediately', True)
        sample('ON auto-hides away after three seconds', False, 3.1)
        s = ctl('status')
        x, y, width, height = s['toolbarFrame']
        screen_height = max(w['height'] for w in s['windows'])
        move(x + width / 2, screen_height - y - height / 2)
        sample('ON reveals on hover after deadline', True)
        sample('ON stays visible while hovered', True)
        move(300, 350)
        sample('ON hides after leaving hover', False)
        ctl('off')
        sample('pointer off hides toolbar', False)
        ctl('configure', settings={'showToolbar': False})
        ctl('configure', settings={'showToolbar': True})
        sample('enabling with pointer off does not activate it', False)
        ctl('on')
        sample('ON permits reactivation', True)
        ctl('configure', settings={'showToolbar': False})
        sample('OFF hides an already visible panel immediately', False, .1)
finally:
    path = out / ('toolbar-repro.json' if '--repro-only' in sys.argv else 'toolbar-smoke.json')
    path.write_text(json.dumps({'checks': checks}, indent=2))
    print('Saved', path, flush=True)
