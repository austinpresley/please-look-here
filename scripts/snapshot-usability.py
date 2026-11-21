#!/usr/bin/env python3
"""Phase A own-window snapshots. No native events or real preference domains."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import time
import uuid
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'dist/Look Here Please Review.app'
BINARY = APP / 'Contents/MacOS/TinyHand'
OUTPUT = Path(os.environ.get('TINYHAND_USABILITY_VERIFICATION_DIR', ROOT / 'dist/verification/usability-icons-phaseA'))


def main():
    assert plistlib.loads((APP / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'] == 'com.austinpresley.pleaselookhere.review'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    with tempfile.TemporaryDirectory(prefix='lhp-phaseA-') as temporary:
        for group in ['s023', 'radial-v9']:
            suite = f'com.austinpresley.tinyhand.{group}.{uuid.uuid4()}'
            env = dict(os.environ, TINYHAND_TEST_MODE='1', TINYHAND_TEST_DENY_ACCESSIBILITY='1', TINYHAND_DEFAULTS_SUITE=suite,
                       TH_HANDS_DIR=temporary+'/Hands', TH_THUMBNAILS_DIR=temporary+'/Thumbnails', APP_SNAPSHOT=str(OUTPUT))
            probe = subprocess.run([str(BINARY), '--ctl', '{"version":1,"operation":"status"}'], capture_output=True, text=True, timeout=8)
            assert probe.returncode != 0, 'An existing Review instance owns the endpoint. Do not adopt its preferences.'
            log = (OUTPUT / f'{group}-process.log').open('w')
            process = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)
            def ctl(operation='test-menu-bar', **fields):
                payload = dict(version=1, operation=operation)
                if operation.startswith('test-'):
                    payload['request'] = fields
                else:
                    payload.update(fields)
                r = subprocess.run([str(BINARY), '--ctl', json.dumps(payload)], env=env, capture_output=True, text=True, timeout=8)
                data = json.loads(r.stdout)
                if r.returncode or not data.get('ok'):
                    raise RuntimeError(data)
                return data.get('controls', data.get('radial', data))
            try:
                for _ in range(60):
                    if process.poll() is not None:
                        raise RuntimeError('Review app exited')
                    try:
                        ctl('status'); break
                    except (RuntimeError, json.JSONDecodeError):
                        time.sleep(.1)
                else:
                    raise RuntimeError('No disposable endpoint')
                time.sleep(.5)
                if group == 'radial-v9':
                    for attempt in range(3):
                        ctl('test-radial', event='open', mode='persistent', point=[700,500], bounds=[200,200,1000,700])
                        time.sleep(.25)
                        state = ctl('test-radial', event='state')
                        if state.get('visible') and state.get('keyWindow'):
                            break
                        ctl('test-radial', event='close'); time.sleep(.25)
                    else:
                        raise RuntimeError('Wheel did not acquire initial key focus')
                    ctl('test-radial', event='close'); time.sleep(.25)
                for theme in ['light', 'dark']:
                    ctl('configure', settings=dict(theme=theme, radialTrigger='option'))
                    if group == 's023':
                        for name, selection, pointer, permission in [('cursor','cursor',True,True), ('pen','pen',True,True), ('hidden','pen',False,True), ('permission','pen',True,False)]:
                            ctl(open=True, selection=selection, pointer=pointer, permission=permission, appearance=theme)
                            time.sleep(.25)
                            path = OUTPUT / f'popover-{name}-{theme}.png'
                            state = ctl(snapshot=str(path))
                            assert path.exists() and state['visible'] and state['key'], state
                            manifest.append(dict(file=path.name, state=state))
                            ctl(open=False); time.sleep(.15)
                        for selection in ['cursor', 'pen']:
                            ctl(surface='toolbar', open=True, selection=selection, permission=True, appearance=theme)
                            time.sleep(.25)
                            path = OUTPUT / f'toolbar-{selection}-{theme}.png'
                            state = ctl(surface='toolbar', appearance=theme, snapshot=str(path))
                            assert path.exists() and state['visible'] and not state['key'], state
                            manifest.append(dict(file=path.name, state=state))
                        ctl(surface='toolbar', picker=True, appearance=theme)
                        time.sleep(.3)
                        path = OUTPUT / f'toolbar-picker-{theme}.png'
                        state = ctl(surface='toolbar', appearance=theme, pickerSnapshot=str(path))
                        assert path.exists(), state
                        manifest.append(dict(file=path.name, state=state))
                        ctl(surface='toolbar', open=False)
                        for surface in ['welcome', 'practice']:
                            ctl(surface=surface, open=True, appearance=theme, lesson=1)
                            time.sleep(.3)
                            path = OUTPUT / f'{surface}-{theme}.png'
                            state = ctl(surface=surface, appearance=theme, snapshot=str(path))
                            assert path.exists() and state['key'], state
                            manifest.append(dict(file=path.name, state=state))
                        for name, fields in [
                            ('practice-progress', dict(surface='practice', open=True, lesson=1, completePrevious=True)),
                            ('practice-completed', dict(surface='practice', completeCurrent=True)),
                            ('practice-wheel', dict(surface='practice', open=True, lesson=3)),
                            ('welcome-permission', dict(surface='welcome', open=True, forDrawing=True, permission=False)),
                            ('welcome-ready', dict(surface='welcome', open=True, forDrawing=True, permission=True))]:
                            ctl(appearance=theme, **fields)
                            time.sleep(.3)
                            path = OUTPUT / f'{name}-{theme}.png'
                            state = ctl(surface=fields['surface'], appearance=theme, snapshot=str(path))
                            assert path.exists() and state['key'], state
                            manifest.append(dict(file=path.name, state=state))
                    else:
                        for selection in ['cursor', 'draw']:
                            ctl('test-radial', event='open', mode='persistent', point=[700,500], bounds=[200,200,1000,700],
                                appearance=theme, interact=selection=='cursor', opaque=True, reduceMotion=True)
                            time.sleep(.3)
                            path = OUTPUT / f'wheel-{selection}-{theme}.png'
                            state = ctl('test-radial', event='state', snapshot=str(path))
                            assert path.exists() and state['keyWindow'], state
                            manifest.append(dict(file=path.name, state=state))
                            ctl('test-radial', event='close'); time.sleep(.25)
                # The toolbar's native frame data must match across both contexts.
                toolbar = [m['state'] for m in manifest if m['file'].startswith('toolbar-') and 'picker' not in m['file']]
                if toolbar:
                    assert all(t['size'] == toolbar[0]['size'] and t['buttons'] == toolbar[0]['buttons'] for t in toolbar)
            finally:
                process.terminate()
                try:
                    process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
                log.close()
                # Delete only the disposable domain made above.
                subprocess.run(['defaults','delete',suite], capture_output=True)
    for item in manifest:
        with Image.open(OUTPUT / item['file']) as image:
            assert image.getbbox() is not None, f"Empty compositor image: {item['file']}"
    (OUTPUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    print(f'PASS {len(manifest)} native snapshots', flush=True)


if __name__ == '__main__':
    main()
