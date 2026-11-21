#!/usr/bin/env python3
"""Capture the focused, running test instance rather than launching a second app."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
binary = Path(os.environ.get('TINYHAND_SNAPSHOT_BINARY', Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'))
output = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', root / 'dist/verification'))
output.mkdir(parents=True, exist_ok=True)

def control(operation, **fields):
    request = {'version': 1, 'operation': operation, **fields}
    result = subprocess.run([str(binary), '--ctl', json.dumps(request)], capture_output=True, text=True, timeout=8)
    response = json.loads(result.stdout)
    if result.returncode or not response.get('ok'):
        raise RuntimeError(response.get('error', response))
    return response

state = control('status')['state']
assert 'snapshot-settings' in state['capabilities'], 'Start the app with TINYHAND_TEST_MODE=1 and APP_SNAPSHOT=<output>; focus its Settings window first.'
for theme in ['light', 'dark']:
    control('configure', settings={'theme': theme})
    for section in os.environ.get('TINYHAND_SNAPSHOT_SECTIONS', 'pointers,drawing,shortcuts,presets,general').split(','):
        control('settings', section=section)
        time.sleep(0.35)
        path = output / f'settings-{section}-{theme}.png'
        control('snapshot-settings', path=str(path))
        layout = json.loads(path.with_name(path.stem + '-layout.json').read_text())
        assert layout['probes'], f'No layout probes in {path}'
        print(f'SNAPSHOT active window {section} {theme}: {path}', flush=True)
control('configure', settings={'theme': 'system'})
control('settings', section='general')
subprocess.run(['swift', str(root / 'scripts/check-layout.swift'), *map(str, sorted(output.glob('settings-*-layout.json')))], check=True)
