#!/usr/bin/env python3
"""B1 Settings captures using only the disposable test bridge, never native input."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'dist/Look Here Please Review.app'
BINARY = APP / 'Contents/MacOS/TinyHand'
OUTPUT = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', ROOT / 'dist/verification/usability-icons-phaseB1'))


def main():
    assert plistlib.loads((APP / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'] == 'com.austinpresley.pleaselookhere.review'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    with tempfile.TemporaryDirectory(prefix='lhp-B1-') as temporary:
        # A valid catalog member with missing artwork exercises recovery UI.
        hands = Path(temporary)/'Hands'
        hands.mkdir()
        (hands/'hands.json').write_text(json.dumps([dict(id='custom-missingart', name='Missing artwork', ink=0x8040BF)]))
        suite = f'com.austinpresley.tinyhand.settings-ui.{uuid.uuid4()}'
        env = dict(os.environ, TINYHAND_TEST_MODE='1', TINYHAND_TEST_DENY_ACCESSIBILITY='1', TINYHAND_DEFAULTS_SUITE=suite,
                   TH_HANDS_DIR=temporary+'/Hands', TH_THUMBNAILS_DIR=temporary+'/Thumbnails', APP_SNAPSHOT=str(OUTPUT),
                   TINYHAND_SNAPSHOT_BINARY=str(BINARY), TINYHAND_VERIFICATION_DIR=str(OUTPUT), TINYHAND_SNAPSHOT_SECTIONS='general,pointers')
        probe = subprocess.run([str(BINARY), '--ctl', '{"version":1,"operation":"status"}'], capture_output=True, text=True, timeout=8)
        assert probe.returncode != 0, 'An existing Review instance owns the endpoint. Do not adopt its preferences.'
        log = (OUTPUT / 'settings-process.log').open('w')
        process = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)
        def ctl(operation='test-settings', **fields):
            payload = dict(version=1, operation=operation)
            if operation.startswith('test-'):
                payload['request'] = fields
            else:
                payload.update(fields)
            result = subprocess.run([str(BINARY), '--ctl', json.dumps(payload)], env=env, capture_output=True, text=True, timeout=8)
            response = json.loads(result.stdout)
            if result.returncode or not response.get('ok'):
                raise RuntimeError(response)
            return response.get('settings', response)
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
            ctl('configure', settings={'pointerOverrides': {'lavender': {'size': .18, 'shadow': True, 'shadowStyle': 'contact', 'soundEnabled': True, 'sound': 'pop'}}})
            ctl(action='inspector', pointer='lavender', scope='this', filter='all')
            subprocess.run(['python3', str(ROOT/'scripts/snapshot-settings.py')], env=env, check=True)
            for theme in ['light', 'dark']:
                ctl('configure', settings={'theme': theme})
                ctl('settings', section='general')
                ctl(action='about', expanded=True)
                time.sleep(.35)
                path = OUTPUT / f'general-about-{theme}.png'
                ctl('snapshot-settings', path=str(path))
                manifest.append(dict(file=path.name, state=ctl()))
                ctl(action='about', expanded=False)
                for name, pointer, scope, category in [
                    ('this-overrides', 'lavender', 'this', 'all'),
                    ('defaults', 'lavender', 'defaults', 'all'),
                    ('laser', 'laser', 'this', 'all'),
                    ('spotlight', 'spotlight', 'this', 'all'),
                    ('presentation', 'presentation', 'this', 'all'),
                    ('hidden', 'robot', 'this', 'hidden'),
                    ('missing-artwork', 'custom-missingart', 'this', 'hidden'),
                    ('favorites8', 'lavender', 'this', 'favorites')]:
                    ctl('enable-pointer', style='robot', enabled=False)
                    if name == 'favorites8':
                        for style in ['spotlight', 'presentation']:
                            ctl('pin', style=style, pinned=True)
                    state = ctl(action='inspector', pointer=pointer, scope=scope, filter=category)
                    time.sleep(.4)
                    path = OUTPUT / f'pointers-{name}-{theme}.png'
                    ctl('snapshot-settings', path=str(path))
                    assert path.exists()
                    assert state['inspectorScope'] == scope and state['inspectorPointer'] == pointer
                    manifest.append(dict(file=path.name, state=state))
                    if name == 'favorites8':
                        for style in ['spotlight', 'presentation']:
                            ctl('pin', style=style, pinned=False)
        finally:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
            log.close()
            subprocess.run(['defaults', 'delete', suite], capture_output=True)
    (OUTPUT/'pointers-manifest.json').write_text(json.dumps(manifest, indent=2))
    subprocess.run(['swift', str(ROOT/'scripts/check-layout.swift'), *map(str, sorted(OUTPUT.glob('pointers-*-layout.json')))], check=True)
    print(f'PASS {len(manifest)} inspector snapshots plus 4 standard Settings snapshots', flush=True)


if __name__ == '__main__':
    main()
