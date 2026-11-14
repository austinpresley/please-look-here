#!/usr/bin/env python3
"""Bounded native checks over the public fixture and an isolated app instance."""
import json
import os
from pathlib import Path
import selectors
import subprocess
import time

root = Path(__file__).resolve().parents[1]
out = root / 'dist/verification/fork-upgrades-20261114'
settings = json.loads((out / 'environment.json').read_text())
assert settings['TINYHAND_DEFAULTS_SUITE'].startswith('com.austinpresley.tinyhand.fork-upgrades.')
env = os.environ | settings
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
fixture = root / 'dist/verification/TinyHandFixture.app'
fixture_state = Path(json.loads((out / 'fixture-environment.json').read_text())['TINYHAND_FIXTURE_STATE'])
checks = []

def request(operation, ok=True, **fields):
    process = subprocess.run([str(binary), '--ctl', json.dumps({'version': 1, 'operation': operation, **fields})],
                             capture_output=True, text=True, timeout=8, env=env)
    result = json.loads(process.stdout)
    assert result['ok'] is ok, result
    return result

def ctl(operation, **fields):
    return request(operation, **fields)['state']

def settle(predicate, seconds=6):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        state = ctl('status')
        if predicate(state):
            return state
        time.sleep(0.08)
    raise AssertionError({'stateDeadline': state})

def passed(name, detail=None):
    checks.append({'check': name, 'detail': detail})
    (out / 'native-checks.json').write_text(json.dumps({'passed': checks}, indent=2))
    print('PASS', name, flush=True)

def probe(*arguments):
    return subprocess.run([str(binary), '--input-probe', *map(str, arguments)], env=env,
                          capture_output=True, text=True, timeout=8, check=True)

def fixture_events():
    return json.loads(fixture_state.read_text()).get('events', {})

def snapshot(name):
    path = out / (name + '.png')
    path.unlink(missing_ok=True)
    time.sleep(0.1)  # Allow the committed layer changes to reach Window Server.
    ctl('test-presentation', request={'event': 'snapshot', 'path': str(path)})
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        if path.exists():
            assert path.read_bytes().startswith(b'\x89PNG')
            return str(path)
        error = Path(str(path) + '.error.txt')
        if error.exists():
            raise AssertionError(error.read_text())
        time.sleep(0.05)
    raise AssertionError('Own-window snapshot deadline: ' + str(path))

def key_stages(command, expected):
    process = subprocess.Popen([str(binary), '--input-probe', command, 'gesture1', '0.6'], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    pending = b''
    observed = []
    deadline = time.monotonic() + 6
    try:
        while time.monotonic() < deadline:
            if not selector.select(timeout=0.2):
                if process.poll() is not None:
                    break
                continue
            data = os.read(process.stdout.fileno(), 4096)
            if not data:
                break
            pending += data
            while b'\n' in pending:
                line, pending = pending.split(b'\n', 1)
                if line.startswith(b'STAGE '):
                    stage = line[6:].decode()
                    if stage in expected:
                        state = settle(lambda s: s['gesture'] == expected[stage], seconds=0.3)
                        observed.append({'stage': stage, 'gesture': state['gesture']})
        assert process.wait(timeout=2) == 0, process.stderr.read().decode()
        assert {x['stage'] for x in observed} == set(expected), observed
        return observed
    finally:
        selector.close()
        if process.poll() is None:
            process.kill(); process.wait(timeout=2)
        probe('release-keys')

initial = ctl('status')
assert 'test-presentation' in initial['capabilities'] and initial['appVersion'] == '1.1.0'
actual_suite = request('test-shortcuts', request={})['shortcuts']['defaultsSuite']
assert actual_suite == settings['TINYHAND_DEFAULTS_SUITE'], actual_suite
assert initial['accessibility'] and initial['screenRecording'], initial
frame = json.loads(fixture_state.read_text())['frame']
x, y = min(500, frame[2] * 0.45), min(450, frame[3] * 0.45)
try:
    request('test-shortcuts', request={'command': 'reset'})
    ctl('off')
    ctl('configure', settings={'showToolbar': False, 'handSound': False, 'laserSound': False,
                               'inkFadeStyle': 'permanent', 'tapSwing': 0})
    ctl('style', style='glove')
    ctl('on')
    probe('move', x, y)
    time.sleep(3.5)
    assert ctl('status')['motionClock'] == 'sleeping'
    probe('move', x + 32, y + 16)
    assert ctl('status')['motionClock'] != 'sleeping'
    passed('idle motion sleeps and real movement wakes it')

    for event in ['space', 'display']:
        state = ctl('test-presentation', request={'event': event})
        assert state['active'] and not state['toolbarVisible']
    passed('Space/display recovery preserves the hidden toolbar')
    for event in ['sleep', 'screenSleep', 'session', 'lock', 'screensaver']:
        ctl('on')
        state = ctl('test-presentation', request={'event': event})
        assert not state['active'] and not state['toolbarVisible'] and state['gesture'] == ''
        assert not ctl('test-presentation', request={'event': 'space'})['active']
    passed('system shutdown paths restore inactive state without automatic wake activation')

    ctl('on'); ctl('interact', enabled=True)
    before = fixture_events()
    probe('click', x, y)
    after = fixture_events()
    assert after.get('1', 0) == before.get('1', 0) + 1
    assert after.get('2', 0) == before.get('2', 0) + 1
    passed('normal Interact clicks reach the fixture')

    ctl('interact', enabled=False)
    ctl('configure', settings={'inkFadeStyle': 'trail', 'trailDelay': 1.2, 'trailSpeed': 240, 'lineWidth': 8, 'ink': 'red'})
    ctl('tool', tool='pen'); ctl('clear')
    before = fixture_events()
    probe('drag', x - 120, y + 80, x + 160, y + 110)
    after = fixture_events()
    assert all(after.get(k, 0) == before.get(k, 0) for k in ['1', '2', '6'])
    assert ctl('status')['annotations'] == 1
    before_path = snapshot('trail-before')
    time.sleep(2.5)
    after_path = snapshot('trail-after')
    assert ctl('status')['annotations'] == 1
    assert ctl('undo')['annotations'] == 0
    assert ctl('redo')['annotations'] == 1
    ctl('clear'); ctl('interact', enabled=True)
    passed('native trail drawing captures input and preserves Undo/Redo', [before_path, after_path])

    for slot, name in [('first', 'ok'), ('second', 'shaka')]:
        ctl('gesture', slot=slot)
        settle(lambda s: s['gesture'] == slot)
        snapshot('gesture-' + name)
        ctl('gesture', slot='none')
        assert ctl('status')['gesture'] == ''
    passed('both native gesture previews restore the selected hand')

    for command, code, display in [('gesture1', 18, '⌃⌥1'), ('gesture2', 19, '⌃⌥2')]:
        result = request('test-shortcuts', request={'command': command, 'shortcut': {'keyCode': code, 'modifiers': 6144, 'display': display}})
        assert result['shortcuts']['accepted'], result
    overlap = key_stages('gesture-overlap', {'down': 'first', 'second': 'second', 'second-after-first-release': 'second', 'released': ''})
    modifier = key_stages('key-release-modifiers', {'down': 'first', 'modifiers-up': '', 'released': ''})
    passed('real gesture hotkeys handle overlap and modifier/key release', overlap + modifier)

    broken = Path(settings['TH_HANDS_DIR']) / 'Gestures/glove-first.png'
    broken.parent.mkdir(parents=True, exist_ok=True)
    assert not broken.exists(), 'Use a clean isolated gesture folder'
    broken.write_bytes(b'broken imported artwork')
    try:
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            observed = request('test-shortcuts', request={})['shortcuts']
            if observed['registeredCount'] == 1:
                break
            time.sleep(0.1)
        else:
            raise AssertionError(observed)
        assert observed['assignments']['gesture1']['keyCode'] == 18
        probe('key', 'gesture1')
        assert ctl('status')['gesture'] == ''
    finally:
        broken.unlink(missing_ok=True)
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        observed = request('test-shortcuts', request={})['shortcuts']
        if observed['registeredCount'] == 2:
            break
        time.sleep(0.1)
    else:
        raise AssertionError(observed)
    passed('corrupt pose artwork releases its exclusive shortcut and restoration re-registers it')

    ctl('configure', settings={'magnifierZoom': 3, 'magnifierDiameter': 240})
    probe('move', x, y)
    ctl('magnifier', enabled=True)
    running = settle(lambda s: s['magnifier']['state'] == 'running' and s['magnifier']['frames'] > 0, seconds=8)
    snapshot('magnifier-3x')
    frames = running['magnifier']['frames']
    probe('click', x + 10, y + 10)
    settle(lambda s: s['magnifier']['frames'] > frames)
    passed('live magnification receives changing public-fixture frames', ctl('status')['magnifier'])
    for _ in range(5):
        ctl('magnifier', enabled=False); ctl('magnifier', enabled=True)
    ctl('magnifier', enabled=False)
    state = settle(lambda s: s['magnifier']['state'] == 'off')
    frames = state['magnifier']['frames']; time.sleep(0.3)
    assert not ctl('status')['magnifier']['visible'] and ctl('status')['magnifier']['frames'] == frames
    passed('rapid magnifier on/off cannot revive an old frame')

    ctl('configure', settings={'tapSwing': 1})
    ctl('style', style='glove'); ctl('interact', enabled=True)
    before = fixture_events()
    probe('drag', x, y + 120, x + 80, y + 150)
    after = fixture_events()
    assert after.get('1', 0) == before.get('1', 0) + 1 and after.get('2', 0) == before.get('2', 0) + 1
    assert not ctl('status')['contactSoundPending']
    passed('tap swing leaves real native dragging immediate')
finally:
    try:
        probe('release-keys')
        ctl('gesture', slot='none'); ctl('magnifier', enabled=False); ctl('off')
    finally:
        (out / 'native-checks.json').write_text(json.dumps({'passed': checks, 'final': ctl('status')}, indent=2))
