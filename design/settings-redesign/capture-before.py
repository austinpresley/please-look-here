#!/usr/bin/env python3
"""Capture only the isolated reference app's own window on Austin's Mac."""
import json
import os
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BINARY = ROOT / 'dist/verification/settings-redesign/Reference.app/Contents/MacOS/TinyHand'
env = os.environ.copy()
env.update(TINYHAND_DEFAULTS_SUITE='com.austinpresley.settings-review-20261117',
           TH_HANDS_DIR=str(ROOT / 'dist/verification/settings-redesign/Hands'),
           TH_THUMBNAILS_DIR='/tmp/lhp-settings-review-thumbnails',
           APP_SNAPSHOT=str(HERE / 'before'), TINYHAND_TEST_MODE='1')
log = open(ROOT / 'dist/verification/settings-redesign/reference.log', 'w')
app = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)

def control(operation, **fields):
    result = subprocess.run([str(BINARY), '--ctl', json.dumps(dict(version=1, operation=operation, **fields))],
                            env=env, capture_output=True, text=True, timeout=10)
    response = json.loads(result.stdout)
    if result.returncode or not response.get('ok'):
        raise RuntimeError(response)
    return response

try:
    for attempt in range(20):
        try:
            control('status')
            break
        except Exception:
            if app.poll() is not None:
                raise
            time.sleep(.75)
    else:
        raise RuntimeError('Reference app did not become ready')
    control('settings', section='pointers')
    time.sleep(2)
    source = '''import CoreGraphics
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
for w in windows {
    if (w[kCGWindowOwnerPID as String] as? Int) == PID && (w[kCGWindowLayer as String] as? Int) == 0 {
        print(w[kCGWindowNumber as String] as! Int)
    }
}
'''.replace('PID &&', f'{app.pid} &&')
    window = subprocess.run(['swift', '-e', source], check=True, capture_output=True, text=True).stdout.strip().splitlines()[0]
    for theme in ['light', 'dark']:
        control('configure', settings={'theme': theme})
        for page in ['general', 'shortcuts', 'drawing', 'pointers', 'appearance', 'sound', 'presets', 'about']:
            control('settings', section=page)
            time.sleep(1.2)
            path = HERE / f'before/{page}-{theme}.png'
            subprocess.run(['/usr/sbin/screencapture', '-x', '-o', '-l', window, str(path)], check=True)
            print(f'Captured {page} {theme}', flush=True)
finally:
    app.terminate()
    app.wait(timeout=10)
    log.close()
