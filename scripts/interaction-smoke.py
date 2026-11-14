#!/usr/bin/env python3
"""Verify interaction and hand visibility on the installed app over the public fixture."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
output = root / 'dist/verification'
env = dict(os.environ, TINYHAND_TEST_MODE='1')
checks = []


def ctl(operation, **fields):
    reply = subprocess.run([str(binary), '--ctl', json.dumps(dict(version=1, operation=operation, **fields))],
                           capture_output=True, text=True, timeout=8)
    value = json.loads(reply.stdout)
    assert reply.returncode == 0 and value['ok'], value
    return value['state']


def held_check(expected):
    press = subprocess.Popen([str(binary), '--input-probe', 'hold', '500', '650', '1'], env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        time.sleep(.2)
        assert press.poll() is None, 'Hold ended before visibility check'
        state = ctl('status')
        assert state['pointerVisible'] is expected, state
        stdout, stderr = press.communicate(timeout=3)
        assert press.returncode == 0, stdout + stderr
        time.sleep(.12)
        assert ctl('status')['pointerVisible'], 'Pointer did not restore after release'
        return state
    finally:
        # Let the bounded probe send its matching mouse-up, even after a failed assertion.
        if press.poll() is None:
            press.communicate(timeout=5)


before = ctl('status')
assert before['accessibility'] and before['screenRecording'], before
assert 'snapshot-settings' in before['capabilities'], 'Use an isolated test instance'
ctl('interact', enabled=True)
ctl('on')
for keep in [True, False]:
    ctl('configure', settings={'interactKeepsHand': keep})
    held = held_check(keep)
    assert held['interact'] and not held['input']['active']
    assert held['annotations'] == before['annotations']
    checks.append('native press with hand visibility ' + str(keep) + ', restored on release')
ctl('interact', enabled=False)
held = held_check(True)
assert not held['interact'] and held['input']['active']
checks.append('drawing keeps the hand visible with interaction visibility disabled')
ctl('interact', enabled=True)
ctl('configure', settings={'interactKeepsHand': True})
state = ctl('status')
assert state['style'] == before['style']
checks.append('Interact changes preserve the selected pointer')
(output / 'interaction-smoke.json').write_text(json.dumps({'passed': checks, 'state': state}, indent=2))
for check in checks:
    print('PASS', check, flush=True)
