#!/usr/bin/env python3
"""Run only with the disposable full-screen fixture visible and frontmost."""
import json
import os
from pathlib import Path
import struct
import subprocess
import time

root = Path(__file__).resolve().parents[1]
binary = root / 'dist/TinyHand Integration.app/Contents/MacOS/TinyHand'
env = dict(os.environ, TINYHAND_TEST_MODE='1', TINYHAND_DEFAULTS_SUITE='com.austinpresley.tinyhand.integration.testing')
results = []

def ctl(operation, **fields):
    response = subprocess.run([str(binary), '--ctl', json.dumps({'version': 1, 'operation': operation, **fields})], capture_output=True, text=True, timeout=6)
    value = json.loads(response.stdout)
    assert response.returncode == 0 and value['ok'], value
    return value['state']

def probe(*arguments):
    response = subprocess.run([str(binary), '--input-probe', *map(str, arguments)], env=env, capture_output=True, text=True, timeout=6)
    assert response.returncode == 0, response.stdout + response.stderr

def passed(name):
    print('PASS', name, flush=True)
    results.append(name)

ctl('configure', settings={'fade': 0, 'handSound': False, 'captureCopies': False, 'captureSaves': True,
                          'captureFolder': str(root / 'dist/verification/captures'), 'showToolbar': True})
ctl('mode', mode='point')
ctl('on')
probe('click', 116, 150)
ctl('mode', mode='draw')
ctl('clear')
for tool, coordinates, count in [
    ('pen', (200, 320, 470, 360), 1),
    ('rectangle', (650, 320, 900, 500), 2),
    ('arrow', (650, 600, 900, 500), 3),
]:
    probe('key', tool)
    probe('drag', *coordinates)
    state = ctl('status')
    assert state['tool'] == tool and state['annotations'] == count
    passed(f'native {tool} input and annotation')
probe('key', 'number')
probe('click', 1150, 350)
assert ctl('status')['annotations'] == 4
probe('drag', 1150, 350, 1250, 420)
assert ctl('status')['annotations'] == 4
probe('click', 1250, 420)
assert ctl('status')['annotations'] == 3
probe('key', 'undo')
assert ctl('status')['annotations'] == 4
passed('marker placement, movement, deletion and Undo')
probe('key', 'redo')
assert ctl('status')['annotations'] == 3
probe('key', 'undo')
assert ctl('status')['annotations'] == 4
passed('native Undo and Redo shortcuts')
probe('key', 'pen')
probe('control-click', 1400, 350)
assert ctl('status')['annotations'] == 5
probe('key', 'undo')
assert ctl('status')['annotations'] == 4
passed('Control-click places a number without changing the Pen tool')
for method, clock in [('responsive', 'displayLink'), ('original', 'timer')]:
    ctl('configure', settings={'motion': method})
    probe('click', 1450, 750)
    state = ctl('status')
    assert state['motionClock'] == clock and state['annotations'] == 4
    passed(f'{method} motion uses {clock}')
for expected in [False, True]:
    probe('key', 'toolbar')
    state = ctl('status')
    assert state['settings']['showToolbar'] is expected
    assert state['toolbarVisible'] is expected
passed('native toolbar visibility shortcut')
probe('key', 'mode')
assert ctl('status')['mode'] == 'point'
probe('key', 'mode')
assert ctl('status')['mode'] == 'draw'
passed('native Point / Draw shortcut')
state = ctl('status')
x, y, width, height = state['toolbarFrame']
screen_height = max(w['height'] for w in state['windows'])
start = (x + 18, screen_height - (y + height - 24))
delta = -120 if x > 960 else 120
probe('drag', *start, start[0] + delta, start[1] - 64)
time.sleep(.2)
state = ctl('status')
assert state['settings']['toolbarPosition'] == state['toolbarFrame'][:2], state
assert state['toolbarFrame'][0] != x
assert state['input']['events'] < 2000, state['input']
passed('toolbar drag persists final position without event-tap feedback')
previous_capture = state['lastCapture']
probe('key', 'capture')
for _ in range(40):
    state = ctl('status')
    if not state['capturing'] and (state['lastCapture'] != previous_capture or state['lastCaptureError']):
        break
    time.sleep(.1)
assert not state['capturing'] and not state['lastCaptureError'] and state['lastCapture'] != previous_capture, state
png = Path(state['lastCapture']).read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
assert list(struct.unpack('>II', png[16:24])) == state['captureSize']
passed('native screenshot shortcut saves a valid PNG at acknowledged dimensions')
probe('key', 'pen')
process = subprocess.Popen([str(binary), '--input-probe', 'drag', '200', '800', '600', '800'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
time.sleep(.18)
ctl('mode', mode='point')
stdout, stderr = process.communicate(timeout=5)
assert process.returncode == 0, stdout + stderr
time.sleep(.1)
state = ctl('status')
assert state['mode'] == 'point' and not state['input']['active'] and not state['input']['enabled'], state['input']
assert state['settings']['toolbarPosition'] == state['toolbarFrame'][:2], state
passed('mode change mid-drag drains the captured release')
path = root / 'dist/verification/live-smoke.json'
path.write_text(json.dumps({'passed': results, 'capture': state['lastCapture'], 'finalState': state}, indent=2))
print('Saved', path, flush=True)
