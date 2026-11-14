#!/usr/bin/env python3
"""Exercise temporary full-screen Spaces using the controlled local fixture."""
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

root = Path(__file__).resolve().parents[1]
out = root / 'dist/verification/fork-upgrades-20261114'
env = os.environ | json.loads((out / 'environment.json').read_text())
cache = Path.home() / 'Library/Caches/look-here-please-fork-upgrades-20261114'
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
probe, windows = cache / 'own-window-probe', cache / 'toolbar-probe'
pid = json.loads((out / 'certified-build.json').read_text())['pid']
assert len(json.loads((out / 'native-checks.json').read_text())['passed']) == 11
subprocess.run(['osascript', '-e', 'tell application id "com.austinpresley.tinyhand.fixture" to quit'], capture_output=True)
fixture_env = {'TINYHAND_FIXTURE_STATE': '/tmp/s013-fork-upgrades-space-' + uuid.uuid4().hex + '.json',
               'TINYHAND_FIXTURE_FULLSCREEN': '1'}
(out / 'fixture-space-environment.json').write_text(json.dumps(fixture_env, indent=2))
arguments = ['open', '-n']
for key, value in fixture_env.items():
    arguments += ['--env', key + '=' + value]
subprocess.run(arguments + [str(root / 'dist/verification/TinyHandFixture.app')], check=True)
state_path = Path(fixture_env['TINYHAND_FIXTURE_STATE'])
for _ in range(80):
    if state_path.exists():
        break
    time.sleep(0.1)
else:
    raise AssertionError('Full-screen fixture did not become ready')

def ctl(operation, **fields):
    request = {'version': 1, 'operation': operation, **fields}
    process = subprocess.run([str(binary), '--ctl', json.dumps(request)], env=env, capture_output=True, text=True, timeout=8)
    reply = json.loads(process.stdout)
    assert reply['ok'], reply
    return reply['state']

def fullscreen(enabled):
    subprocess.run([str(probe), 'fixture-front'], env=env, capture_output=True, check=True)
    process = subprocess.run([str(probe), 'fixture-fullscreen', 'on' if enabled else 'off'], env=env,
                             capture_output=True, text=True, timeout=5)
    assert process.returncode == 0, process.stdout + process.stderr
    for _ in range(100):
        state = json.loads(state_path.read_text())
        if state.get('fullScreen') is enabled:
            time.sleep(0.3)
            return state
        time.sleep(0.1)
    raise AssertionError(state)

checks = []
try:
    ctl('off'); ctl('configure', settings={'showToolbar': False, 'handSound': False})
    fullscreen(True); fullscreen(False)
    state = ctl('on')
    assert state['active'] and state['onActiveSpace'] and not state['toolbarVisible']
    checks.append('activation after a real full-screen Space closes')
    fullscreen(True); state = ctl('status')
    assert state['onActiveSpace'] and not state['toolbarVisible']
    checks.append('active overlay follows a real full-screen Space')
    fullscreen(False); state = ctl('status')
    assert state['onActiveSpace'] and not state['toolbarVisible']
    checks.append('return to desktop preserves hidden toolbar')
    state = ctl('configure', settings={'showToolbar': True})
    frame = state['toolbarFrame']; height = max(window['height'] for window in state['windows'])
    subprocess.run([str(binary), '--input-probe', 'move', str(frame[0] + frame[2] / 2), str(height - frame[1] - frame[3] / 2)],
                   env=env, capture_output=True, check=True)
    fullscreen(True); state = ctl('status')
    assert state['onActiveSpace'] and state['toolbarVisible'], state
    on_screen = json.loads(subprocess.check_output([str(windows), 'windows', str(pid)], env=env, text=True))
    assert any(abs(window['kCGWindowBounds']['Width'] - frame[2]) < 2
               and abs(window['kCGWindowBounds']['Height'] - frame[3]) < 2 for window in on_screen), on_screen
    checks.append('toolbar is actually on screen inside a real full-screen Space')
    fullscreen(False)
    (out / 'fullscreen-checks.json').write_text(json.dumps({'passed': checks, 'final': ctl('status'), 'onScreenWindows': on_screen}, indent=2))
    print('PASS', len(checks), 'actual full-screen Space transitions', flush=True)
finally:
    try:
        fullscreen(False)
    except Exception:
        pass
    ctl('off')
    subprocess.run(['osascript', '-e', 'tell application id "com.austinpresley.tinyhand.fixture" to quit'], capture_output=True)
