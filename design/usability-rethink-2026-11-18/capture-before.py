"""Capture only the signed local Review app in a disposable preference suite."""
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'before'
BINARY = ROOT / 'dist/Look Here Please Review.app/Contents/MacOS/TinyHand'
env = dict(os.environ, TINYHAND_TEST_MODE='1',
           TINYHAND_DEFAULTS_SUITE='com.austinpresley.tinyhand.s023.ux.' + str(uuid.uuid4()),
           TH_HANDS_DIR=str(OUT / 'Hands'), TH_THUMBNAILS_DIR=str(OUT / 'Thumbnails'), APP_SNAPSHOT=str(OUT))

def control(op, **fields):
    result = subprocess.run([str(BINARY), '--ctl', json.dumps(dict(version=1, operation=op, **fields))],
                            env=env, capture_output=True, text=True, timeout=5)
    value = json.loads(result.stdout)
    if not value.get('ok'):
        raise RuntimeError(value)
    return value

OUT.mkdir(exist_ok=True)
with (OUT / 'capture.log').open('w') as log:
    process = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)
    try:
        for _ in range(30):
            try:
                control('status')
                break
            except Exception:
                time.sleep(.2)
        control('configure', settings={'showToolbar': False, 'handSound': False})
        control('style', style='lavender')
        control('on')
        control('interact', enabled=False)
        control('tool', tool='arrow')
        for theme in ['light', 'dark']:
            control('configure', settings={'theme': theme})
            control('test-menu-bar', request={'open': True})
            time.sleep(.6)
            result = control('test-menu-bar', request={'snapshot': str(OUT / f'controls-{theme}.png')})
            (OUT / f'capture-state-{theme}.json').write_text(json.dumps(result, indent=2))
            assert (OUT / f'controls-{theme}.png').exists()
            control('test-menu-bar', request={'open': False})
        control('off')
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
print('Native control captures saved in light and dark.')
