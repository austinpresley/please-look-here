#!/usr/bin/env python3
"""B2/C native app windows from an owned disposable test endpoint. No input posts."""
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
OUTPUT = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', ROOT / 'dist/verification/usability-icons-phaseB2C'))


def main():
    assert plistlib.loads((APP/'Contents/Info.plist').read_bytes())['CFBundleIdentifier'] == 'com.austinpresley.pleaselookhere.review'
    resources = sorted((APP/'Contents/Resources').glob('gesture_*_*.png'))
    assert len(resources) == 72, f'{len(resources)} bundled per-hand canvases, expected 72'
    manifest = []
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lhp-B2C-') as temporary:
        suite = f'com.austinpresley.tinyhand.settings-ui.{uuid.uuid4()}'
        env = dict(os.environ, TINYHAND_TEST_MODE='1', TINYHAND_TEST_DENY_ACCESSIBILITY='1', TINYHAND_DEFAULTS_SUITE=suite,
                   TH_HANDS_DIR=temporary+'/Hands', TH_THUMBNAILS_DIR=temporary+'/Thumbnails', APP_SNAPSHOT=str(OUTPUT),
                   TINYHAND_SNAPSHOT_BINARY=str(BINARY), TINYHAND_VERIFICATION_DIR=str(OUTPUT), TINYHAND_SNAPSHOT_SECTIONS='drawing,shortcuts,presets')
        probe = subprocess.run([str(BINARY), '--ctl', '{"version":1,"operation":"status"}'], capture_output=True, text=True, timeout=8)
        assert probe.returncode != 0, 'Existing Review endpoint. Refusing to adopt its preferences.'
        log = (OUTPUT/'settings-process.log').open('w')
        process = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)
        def ctl(operation='test-settings', **fields):
            payload = dict(version=1, operation=operation)
            if operation.startswith('test-'):
                payload['request'] = fields
            else:
                payload.update(fields)
            result = subprocess.run([str(BINARY), '--ctl', json.dumps(payload)], env=env, capture_output=True, text=True, timeout=8)
            data = json.loads(result.stdout)
            if result.returncode or not data.get('ok'):
                raise RuntimeError(data)
            return data.get('settings', data)
        def capture(name, theme, replay=False):
            time.sleep(.45)
            if replay:
                ctl(action='replay-drawing')
                time.sleep(.12)
            state = ctl()
            path = OUTPUT/f'{name}-{theme}.png'
            ctl('snapshot-settings', path=str(path))
            assert path.exists()
            manifest.append(dict(file=path.name, state=state))
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
            subprocess.run(['python3', str(ROOT/'scripts/snapshot-settings.py')], env=env, check=True)
            for theme in ['light', 'dark']:
                ctl('configure', settings={'theme': theme})
                ctl('settings', section='drawing')
                ctl('configure', settings={'inkFadeStyle':'wholeLine', 'fade':3, 'trailDelay':1, 'trailSpeed':240})
                ctl(action='drawing-options', advanced=False)
                capture('tools-ink-fade', theme, replay=True)
                ctl('configure', settings={'inkFadeStyle':'trail'})
                capture('tools-ink-trail', theme, replay=True)
                ctl(action='drawing-options', advanced=True)
                ctl(action='scroll', bottom=True)
                capture('tools-ink-advanced', theme, replay=True)
                ctl(action='scroll', bottom=False)
                ctl('settings', section='magnification')
                capture('tools-magnifier', theme)
                ctl('settings', section='screenshots')
                capture('tools-capture', theme)
                ctl('test-shortcuts', command='reset')
                ctl('configure', settings={'theme':theme})
                ctl('settings', section='shortcuts')
                capture('shortcuts-default', theme)
                seeded = ctl('test-shortcuts', command='toggle', shortcut=dict(keyCode=35, modifiers=2304, display='⌥⌘P'))
                assert seeded['shortcuts']['accepted']
                state = ctl(action='suggest-add')
                assert state['suggestedResult'] == '2 added · 1 already set · 1 skipped', state
                capture('shortcuts-added', theme)
                ctl(action='expand', groups=['drawing'])
                capture('shortcuts-expanded', theme)
                ctl(action='focus', command='mode')
                time.sleep(.5)
                ctl(action='record', command='mode')
                capture('shortcuts-recording', theme)
                ctl(action='cancel-recording', command='mode')
                ctl('settings', section='shortcuts')
                ctl(action='expand', groups=['pointer'])
                capture('shortcuts-pointer', theme)
                ctl(action='suggest-undo')
                # Save a matching card in each appearance, with a contrasting
                # older setup and unmodified, actual recovery transactions.
                ctl('configure', settings={'theme':theme, 'ink':'red'})
                ctl(action='save-preset', name=f'Quiet demo {theme}')
                ctl('configure', settings={'ink':'match'})
                ctl(action='save-preset', name=f'Workshop {theme}')
                ctl('settings', section='presets')
                ctl(action='preset-view')
                assert ctl()['presetNowCount'] >= 1
                capture('presets-cards', theme)
                ctl(action='preset-view', included=True)
                capture('presets-included', theme)
                ctl(action='preset-view', recovery=True)
                ctl(action='scroll', bottom=True)
                capture('presets-recovery', theme)
                ctl(action='restore-review')
                capture('presets-restore-review', theme)
                ctl(action='dismiss-review')
                time.sleep(.3)
                ctl(action='import-review')
                capture('presets-import-review', theme)
                ctl(action='import-review', details=True)
                capture('presets-import-details', theme)
                ctl(action='dismiss-review')
                ctl(action='scroll', bottom=False)
                for pointer in ['lavender','pixel','robot']:
                    ctl(action='inspector', pointer=pointer, scope='this', filter='all')
                    capture(f'pointers-{pointer}-gestures', theme)
                    for slot in ['first','second']:
                        ctl(action='gesture-preview', slot=slot)
                        capture(f'gesture-preview-{pointer}-{slot}', theme)
        finally:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
            log.close()
            subprocess.run(['defaults', 'delete', suite], capture_output=True)
    (OUTPUT/'settings-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    subprocess.run(['swift', str(ROOT/'scripts/check-layout.swift'), *map(str, sorted(OUTPUT.glob('*-layout.json')))], check=True)
    print(f'PASS {len(manifest)} B2/C native snapshots plus 6 standard Settings snapshots; 72 bundled resources', flush=True)


if __name__ == '__main__':
    main()
