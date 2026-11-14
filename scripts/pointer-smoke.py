#!/usr/bin/env python3
"""Verify S-018 against an already-running disposable test instance.

Launch via LaunchServices with TINYHAND_TEST_MODE, TINYHAND_DEFAULTS_SUITE,
TH_HANDS_DIR. This resets only that suite and temporarily removes a fixture PNG.
"""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
out = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', root / 'dist/verification/s018'))
out.mkdir(parents=True, exist_ok=True)
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
suite = os.environ['TINYHAND_DEFAULTS_SUITE']
hands = Path(os.environ['TH_HANDS_DIR'])
assert os.environ.get('TINYHAND_TEST_MODE') == '1'
assert suite.startswith('com.austinpresley.tinyhand.s018.')
assert hands.name.startswith('s018-hands-') and hands.is_dir()
rows = []

def control(op, ok=True, **fields):
    p = subprocess.run([str(binary), '--ctl', json.dumps({'version': 1, 'operation': op, **fields})], capture_output=True, text=True, timeout=8)
    value = json.loads(p.stdout)
    assert value['ok'] is ok and p.returncode == (0 if ok else 1), value
    return value

def ctl(op, **fields):
    return control(op, **fields)['state']

def passed(name, state=None):
    rows.append({'name': name, 'state': state or ctl('status')})
    print('PASS', name, flush=True)

def settle(predicate):
    for _ in range(30):
        s = ctl('status')
        if predicate(s):
            return s
        time.sleep(.1)
    raise AssertionError(s)

assert control('test-shortcuts', request={})['shortcuts']['defaultsSuite'] == suite, 'Refusing real preferences'
try:
    ctl('off')
    control('test-shortcuts', request={'command': 'reset'})
    library = control('styles')['styles']
    assert all(e['enabled'] for e in library)
    assert any(not e['available'] for e in library), 'Seed an unavailable custom fixture'
    ids = [e['id'] for e in library if e['selectable']]
    assert ctl('status')['enabledPointers'] == ids
    passed('reset enables complete library; unavailable is distinct')
    initial_pins = ctl('status')['pinned']
    ctl('style', style='robot')
    ctl('on')
    s = ctl('enable-pointer', style='robot', enabled=False)
    assert s['style'] == 'lavender' and s['active'] and s['interact']
    assert s['pinned'] == initial_pins and 'robot' not in s['quickPointers']
    assert 'chrome' in s['enabledPointers'] and 'chrome' not in s['pinned']
    passed('selected disable falls back without changing activation, Interact or pins', s)
    ctl('off')
    for op, fields in [('style', {'style': 'robot', 'activate': True}), ('configure', {'settings': {'style': 'robot', 'lineWidth': 19}})]:
        before = ctl('status')
        r = control(op, ok=False, **fields)
        assert r['error']['code'] == 'disabled-style'
        for key in ['style', 'active', 'settings', 'pinned', 'disabledPointers']:
            assert r['state'][key] == before[key], (key, r)
    script = 'tell application id "com.austinpresley.pleaselookhere.integration" to set selected pointer to "robot"'
    r = control('run-applescript', source=script)
    assert r['script']['errorNumber'] == 1006, r
    passed('JSON batches and AppleScript reject disabled selections without mutation')
    ctl('enable-pointer', style='laser', enabled=False)
    r = control('laser', ok=False)
    assert r['error']['code'] == 'disabled-style' and not r['state']['active']
    passed('legacy laser rejects before activation')
    ctl('enable-pointer', style='robot', enabled=True)
    assert ctl('status')['pinned'] == initial_pins
    passed('re-enabling restores saved toolbar favorite')
    custom = 'custom-s018'
    path = hands / (custom + '.png')
    original = path.read_bytes()
    ctl('style', style=custom)
    path.unlink()
    s = settle(lambda s: s['style'] == 'lavender' and custom not in s['enabledPointers'])
    entry = next(e for e in control('styles')['styles'] if e['id'] == custom)
    assert entry['enabled'] and not entry['available'] and not entry['selectable']
    r = control('style', ok=False, style=custom, activate=True)
    assert r['error']['code'] == 'missing-asset' and not r['state']['active']
    path.write_bytes(original)
    s = settle(lambda s: custom in s['enabledPointers'])
    assert s['style'] == 'lavender'
    ctl('enable-pointer', style=custom, enabled=False)
    path.unlink()
    time.sleep(1.2)
    path.write_bytes(original)
    time.sleep(1.2)
    entry = next(e for e in control('styles')['styles'] if e['id'] == custom)
    assert not entry['enabled'] and entry['available']
    passed('custom image removal/reappearance keeps enable state and does not steal selection')
    ctl('enable-pointer', style=custom, enabled=True)
    for style in ctl('status')['enabledPointers']:
        if style != custom:
            ctl('enable-pointer', style=style, enabled=False)
    before = ctl('status')
    r = control('enable-pointer', ok=False, style=custom, enabled=False)
    assert r['error']['code'] == 'last-enabled-pointer' and r['state']['disabledPointers'] == before['disabledPointers']
    assert r['state']['style'] == custom
    passed('last available enabled pointer rejects with useful feedback')
    path.unlink()
    s = settle(lambda s: s['style'] == 'lavender' and s['enabledPointers'] == ['lavender'])
    path.write_bytes(original)
    settle(lambda s: custom in s['enabledPointers'])
    assert ctl('status')['style'] == 'lavender'
    passed('sole custom loss safely enables first built-in and preserves restored custom')
    control('test-shortcuts', request={'command': 'reset'})
    s = ctl('status')
    assert s['disabledPointers'] == [] and all(v is None for v in s['shortcuts'].values())
    passed('reset preserves custom files and leaves every hotkey unassigned', s)
finally:
    if 'original' in locals() and not path.exists():
        path.write_bytes(original)
    (out / 'pointer-smoke.json').write_text(json.dumps({'checks': rows}, indent=2))
