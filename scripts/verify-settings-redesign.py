#!/usr/bin/env python3
"""Verify the real Settings window in a disposable local app instance."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

root = Path(__file__).resolve().parents[1]
binary = root / 'dist/verification/settings-implementation/SettingsTest.app/Contents/MacOS/TinyHand'
output = root / 'dist/verification/settings-implementation/native'
output.mkdir(parents=True, exist_ok=True)
temporary = tempfile.TemporaryDirectory(prefix='lhp-settings-ui-')
env = os.environ.copy()
env.update(TINYHAND_TEST_MODE='1', TINYHAND_DEFAULTS_SUITE='com.austinpresley.tinyhand.settings-ui.' + str(uuid.uuid4()),
           TH_HANDS_DIR=str(Path(temporary.name) / 'Hands'), TH_THUMBNAILS_DIR=str(Path(temporary.name) / 'Thumbnails'), APP_SNAPSHOT=str(output))
log = open(output.parent / 'native.log', 'w')
app = subprocess.Popen([str(binary)], env=env, stdout=log, stderr=log)
wake = subprocess.Popen(['caffeinate', '-d', '-i', '-u', '-w', str(app.pid)], stdout=log, stderr=log)
checks = []

def control(operation, **fields):
    result = subprocess.run([str(binary), '--ctl', json.dumps(dict(version=1, operation=operation, **fields))],
                            env=env, capture_output=True, text=True, timeout=10)
    value = json.loads(result.stdout)
    if result.returncode or not value.get('ok'):
        raise RuntimeError(value)
    return value

def verify(action='status', **fields):
    return control('test-settings', request=dict(action=action, **fields))['settings']

def check(condition, label):
    checks.append(dict(label=label, passed=bool(condition)))
    if not condition:
        raise AssertionError(label)
    print('PASS', label, flush=True)

def capture(name):
    time.sleep(.65)
    path = output / (name + '.png')
    control('snapshot-settings', path=str(path))
    check(path.exists() and path.stat().st_size > 1000, 'Native capture ' + name)

try:
    for attempt in range(30):
        try:
            state = control('status')['state']
            break
        except Exception:
            if app.poll() is not None:
                raise
            time.sleep(.5)
    else:
        raise RuntimeError('Settings test instance did not start')
    check('test-settings' in state['capabilities'], 'Disposable UI verification capability')
    control('settings', section='general')
    time.sleep(1.5)
    if os.environ.get('TINYHAND_SKIP_PRESET_SEED') != '1':
        for name in ['Workshop', 'Quiet demo']:
            verify('save-preset', name=name)
    groups = ['pointer', 'presenting', 'drawing', 'tools', 'toolbar', 'quickControls', 'streamDeck']
    for theme in ['light', 'dark']:
        control('configure', settings={'theme': theme})
        for section in ['general', 'pointers', 'appearance', 'drawing', 'shortcuts', 'presets', 'about']:
            control('settings', section=section)
            capture(section + '-' + theme)
            if section == 'shortcuts':
                settings = verify()
                check(settings['expanded'] == [], 'All shortcut sections closed on normal visit ' + theme)
                check(settings['shortcutControls'] == [], 'Closed sections mount no recorders ' + theme)
        for pane in ['magnification', 'screenshots']:
            control('settings', section=pane)
            capture(pane + '-' + theme)
        for group in groups:
            verify('expand', groups=[group])
            capture('shortcuts-' + group + '-' + theme)
        verify('expand', groups=groups)
        capture('shortcuts-expanded-' + theme)
        settings = verify()
        check(len(settings['shortcutControls']) == 26, 'All 26 native shortcut destinations mounted ' + theme)
        verify('collapse')
        time.sleep(.35)
        check(verify()['expanded'] == [], 'Explicit collapse resets every group ' + theme)
        verify('focus', command='pen')
        capture('shortcuts-linked-' + theme)
        check(verify()['expanded'] == ['tools'], 'Practice link opens only Tool keys ' + theme)
        verify('customize', pointer='lavender')
        capture('customize-' + theme)
        verify('dismiss')
        time.sleep(.4)
        verify('new-hand')
        capture('new-hand-' + theme)
        verify('dismiss')
        time.sleep(.4)
    control('settings', section='sound')
    time.sleep(.4)
    check(verify()['section'] == 'pointers' and verify()['inspectorScope'] == 'defaults', 'Legacy Sound route opens Pointer defaults')
    control('settings', section='shortcuts')
    time.sleep(.4)
    check(verify()['expanded'] == [], 'Returning to Shortcuts resets linked disclosure state')
    paths = sorted(output.glob('*-layout.json'))
    result = subprocess.run(['swift', str(root / 'scripts/check-layout.swift'), *map(str, paths)], capture_output=True, text=True)
    print(result.stdout, flush=True)
    check(result.returncode == 0, 'Native layout probes')
finally:
    app.terminate()
    app.wait(timeout=10)
    wake.terminate()
    wake.wait(timeout=5)
    log.close()
    (output.parent / 'native-results.json').write_text(json.dumps(checks, indent=2))
    temporary.cleanup()
