#!/usr/bin/env python3
"""Drive only the isolated Review app through the test control protocol."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get('TINYHAND_REVIEW_APP', ROOT / 'dist/Look Here Please Review.app'))
BINARY = APP / 'Contents/MacOS/TinyHand'
OUTPUT = ROOT / 'dist/verification/radial-v9'


def main():
    info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.austinpresley.pleaselookhere.review', 'Use only the isolated Review build'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Refuse to adopt another instance or its preferences. The dedicated bundle
    # ID separates both the Unix socket and all grants from the normal app.
    probe = subprocess.run([str(BINARY), '--ctl', '{"version":1,"operation":"status"}'], capture_output=True, text=True, timeout=8)
    assert probe.returncode != 0, 'Close the existing Review instance before running this disposable matrix'
    with tempfile.TemporaryDirectory(prefix='radial-v9-') as temporary:
        env = dict(os.environ, TINYHAND_TEST_MODE='1', TINYHAND_TEST_DENY_ACCESSIBILITY='1',
                   TINYHAND_DEFAULTS_SUITE='com.austinpresley.tinyhand.radial-v9.' + str(uuid.uuid4()),
                   TH_HANDS_DIR=temporary + '/Hands', TH_THUMBNAILS_DIR=temporary + '/Thumbnails', APP_SNAPSHOT=str(OUTPUT))
        log = (OUTPUT / 'review-process.log').open('w')
        process = subprocess.Popen([str(BINARY)], env=env, stdout=log, stderr=log)
        def control(operation='test-radial', **request):
            payload = {'version': 1, 'operation': operation}
            if operation.startswith('test-'):
                payload['request'] = request
            else:
                payload.update(request)
            result = subprocess.run([str(BINARY), '--ctl', json.dumps(payload)], capture_output=True, text=True, timeout=8)
            response = json.loads(result.stdout)
            if result.returncode or not response.get('ok'):
                raise RuntimeError(response)
            if request.get('event') == 'close':
                # Native restoration posts activation notifications after the
                # command returns. Drain them before opening the next fixture.
                time.sleep(.25)
            return response['radial'] if operation == 'test-radial' else response.get('quickControls', response)
        try:
            for _ in range(80):
                if process.poll() is not None:
                    raise RuntimeError('Review app exited: ' + (OUTPUT / 'review-process.log').read_text())
                ready = subprocess.run([str(BINARY), '--ctl', '{"version":1,"operation":"status"}'], capture_output=True, text=True, timeout=8)
                if ready.returncode == 0:
                    break
                time.sleep(.1)
            else:
                raise RuntimeError('Review endpoint did not start')
            # A directly launched accessory app can finish its first activation
            # after the control endpoint is ready. Settle this launch transition
            # before the matrix; every measured state still runs exactly once.
            for attempt in range(3):
                control(event='open', mode='persistent', point=[700, 500], bounds=[200, 200, 1000, 700])
                time.sleep(.25)
                ready = control(event='state')
                if ready.get('visible') and ready.get('keyWindow'):
                    break
                control(event='close')
            else:
                raise RuntimeError('Review fixture did not acquire initial key focus')
            print(f'READY initial key focus after {attempt + 1} launch attempts', flush=True)
            control(event='close')
            # Coordinates are AppKit screen points. Synthetic owning rectangles
            # exercise edge/list rules without changing a real display layout.
            states = [
                ('root', {'level': 'root'}),
                ('pointer', {'level': 'pointer', 'highlighted': 'coral'}),
                ('color', {'level': 'color', 'highlighted': 'match'}),
                ('draw', {'level': 'draw', 'highlighted': 'highlighter'}),
                ('more', {'level': 'more', 'highlighted': 'toolbar'}),
                ('disabled', {'level': 'more', 'highlighted': 'redo', 'canRedo': False}),
                ('keyboard', {'level': 'root', 'highlighted': 'clear', 'keyboard': True}),
                ('edge-unarmed', {'mode': 'held', 'point': [230, 225]}),
                ('list', {'bounds': [200, 200, 320, 360], 'point': [360, 380], 'level': 'root', 'highlighted': 'clear', 'keyboard': True}),
                ('list-short-child', {'bounds': [200, 200, 320, 180], 'point': [360, 280], 'level': 'color', 'highlighted': 'back', 'keyboard': True}),
                ('list-short-bottom', {'bounds': [200, 200, 320, 180], 'point': [360, 280], 'level': 'color', 'highlighted': 'black', 'keyboard': True}),
                ('pointer-back', {'level': 'pointer', 'highlighted': 'back'}),
                ('color-back', {'level': 'color', 'highlighted': 'back'}),
                ('draw-back', {'level': 'draw', 'highlighted': 'back'}),
                ('more-back', {'level': 'more', 'highlighted': 'back'}),
                ('list-pointer', {'bounds': [200, 200, 320, 360], 'point': [360, 380], 'level': 'pointer'}),
                ('list-color', {'bounds': [200, 200, 320, 360], 'point': [360, 380], 'level': 'color'}),
                ('held-marker', {'mode': 'held', 'level': 'root'}),
            ]
            manifest = []
            if os.environ.get('TINYHAND_SNAPSHOT_SCOPE') == 'quick':
                states = []
            for theme in ['light', 'dark']:
                for variant in ['material', 'opaque', 'contrast', 'reduce-motion']:
                    for name, state in states:
                        request = dict(event='open', mode='persistent', point=[700, 500], bounds=[200, 200, 1000, 700], canUndo=True, hasInk=True, canRedo=False)
                        request.update(state)
                        request.update(appearance=theme, opaque=variant == 'opaque', increaseContrast=variant == 'contrast', reduceMotion=variant == 'reduce-motion')
                        current = control(**request)
                        time.sleep(.2)
                        path = OUTPUT / f'{name}-{theme}-{variant}.png'
                        current = control(event='state', appearance=theme, opaque=variant == 'opaque', increaseContrast=variant == 'contrast', reduceMotion=variant == 'reduce-motion', snapshot=str(path))
                        layout = json.loads(path.with_name(path.stem + '-layout.json').read_text())
                        assert layout['items'], f'No measured frames for {path}'
                        assert current['group'] == state.get('level', 'root').replace('root', '')
                        assert current['list'] == name.startswith('list')
                        if name == 'edge-unarmed':
                            assert not current['armed'] and not current['ownsFocus']
                        if current['mode'] == 'persistent':
                            assert current['keyWindow'], f'Persistent panel did not become key: {path}'
                        if name == 'keyboard':
                            assert current['keyboard'] and current['ownsFocus']
                        if name == 'disabled':
                            assert current['highlighted'] == 'redo' and not current['candidate']
                        manifest.append({'file': path.name, 'state': current})
                        print(f'SNAPSHOT {path}', flush=True)
                        control(event='close')
            quick_states = [
                ('browser-wide', {'size': [560, 600]}),
                ('browser-narrow', {'size': [320, 360]}),
                ('browser-short', {'size': [560, 280]}),
                ('browser-narrow-short', {'size': [320, 180]}),
                ('browser-search', {'query': 'Presentation'}),
                ('browser-empty', {'query': 'no such pointer'}),
                ('browser-quick-controls', {'scope': 1}),
                ('browser-edit-start', {'editing': True}),
                ('browser-edit-short-start', {'size': [320, 180], 'editing': True}),
                ('browser-edit-wide', {'size': [800, 600], 'editing': True, 'candidate': 'coral'}),
                ('browser-edit-long', {'editing': True, 'candidate': 'presentation'}),
                ('browser-edit-narrow-tall', {'size': [320, 600], 'editing': True, 'candidate': 'presentation'}),
                ('browser-edit-narrow', {'size': [320, 360], 'editing': True, 'candidate': 'presentation'}),
                ('browser-edit-short-wide', {'size': [560, 280], 'editing': True, 'candidate': 'presentation'}),
                ('browser-edit-short', {'size': [320, 180], 'editing': True, 'candidate': 'presentation'}),
            ]
            def quick(**request):
                return control(operation='test-quick-controls', **request)
            for theme in ['light', 'dark']:
                for name, state in quick_states:
                    request = dict(surface='browser', event='open', size=[560, 600], appearance=theme)
                    request.update(state)
                    current = quick(**request)
                    time.sleep(.2)
                    path = OUTPUT / f'{name}-{theme}.png'
                    current = quick(surface='browser', appearance=theme, snapshot=str(path))
                    browser = current['browser']
                    assert browser['keyWindow'] and browser['visible']
                    assert browser['searchText'] == request.get('query', '') and browser['scopeSegment'] == request.get('scope', 0)
                    width, height = browser['contentSize']
                    assert width == request['size'][0] and height == request['size'][1]
                    assert 1 <= browser['columns'] <= 7
                    assert all(cell['frame'][0] >= 16 and cell['frame'][0] + cell['frame'][2] <= width - 16 for cell in browser['cells'])
                    for cell in browser['cells']:
                        assert cell['nameWidth'] == cell['frame'][2] == 64
                        if cell['id'] == 'cookie':
                            assert cell['nameLines'] == ['Gingerbread']
                        elif cell['id'] == 'presentation':
                            assert cell['nameLines'] == ['Presenta-', 'tion pointer']
                    assert browser['scopeFrame'][2] < 220
                    assert (browser['scopeFrame'][1] == browser['searchFrame'][1]) == (width >= 440)
                    assert browser['footerFrame'][0] + browser['footerFrame'][2] < browser['editFrame'][0]
                    assert browser['editFrame'][2] < 200 and browser['editFrame'][3] == 28
                    assert browser['gridBottomInset'] >= 12
                    manifest.append({'file': path.name, 'state': current})
                    if name == 'browser-empty':
                        assert browser['count'] == 0 and browser['inspected'] == ''
                    if request.get('editing'):
                        assert browser['editing'] and browser['candidate'] == request.get('candidate', '')
                        assert browser['editorDocked'] == (height >= 480)
                        if height >= 480:
                            assert browser['editorHeaderVisible']
                            assert browser['editorScrollOffset'] == 0, 'A reopened editor must start at North'
                            viewport = browser['scrollViewport']
                            assert browser['editorFrame'][3] <= (viewport[3] + browser['editorFrame'][3]) * .45 + 1
                            assert viewport[1] + viewport[3] <= browser['editorFrame'][1]
                            assert browser['editorFrame'][1] + browser['editorFrame'][3] <= height - 44
                        elif not request.get('candidate'):
                            assert browser['editorHeaderVisible'], 'Entering the short editor must reveal its header'
                        for slot in browser['slots']:
                            direction, art, label, button = (slot[key] for key in ['directionFrame', 'artFrame', 'nameFrame', 'frame'])
                            assert direction[2] == 28 and art[2:] == [26, 26]
                            assert direction[0] + direction[2] <= art[0] and art[0] + art[2] <= label[0]
                            assert label[0] + label[2] < button[0] and button[0] + button[2] <= width - 16
                        if not request.get('candidate'):
                            quick(surface='browser', event='finish')
                            quick(surface='browser', event='close')
                            print(f'SNAPSHOT {path}', flush=True)
                            continue
                        assert browser['candidateVisible'], f'Candidate must stay visible: {path}'
                        current = quick(surface='browser', event='assign', slot=5, appearance=theme)
                        time.sleep(.2)
                        assert current['browser']['focus'] == 'slot(5)' and current['browser']['focusedSlot'] == 5
                        assert current['browser']['currentPointer'] == browser['currentPointer'] and current['browser']['visible']
                        assert current['browser']['favorites'][5] == request['candidate']
                        assert current['browser']['slots'][5]['visible']
                        if height >= 480:
                            assert current['browser']['candidateVisible'], 'Docked assignment must preserve grid visibility'
                        assigned_path = OUTPUT / f'{name}-assigned-{theme}.png'
                        current = quick(surface='browser', appearance=theme, snapshot=str(assigned_path))
                        assert current['browser']['slots'][5]['visible'] and current['browser']['focusedSlot'] == 5
                        if height >= 480:
                            assert current['browser']['candidateVisible']
                        manifest.append({'file': assigned_path.name, 'state': current})
                        finished = quick(surface='browser', event='finish')
                        assert not finished['browser']['editing'] and not finished['browser']['candidate'] and finished['browser']['editFocused']
                    print(f'SNAPSHOT {path}', flush=True)
                    quick(surface='browser', event='close')
                # Error appearance must leave browser search's key focus intact.
                quick(surface='browser', event='open', appearance=theme)
                time.sleep(.2)
                assert quick(surface='browser')['browser']['keyWindow'], 'Error fixture requires a settled key browser'
                error = quick(surface='error', event='open', appearance=theme)
                assert error['error']['visible'] and not error['error']['keyWindow'] and error['browser']['keyWindow'], error
                assert error['error']['action'] == 'Choose Folder…'
                assert error['error']['recoveryHeight'] == 28 and error['error']['dismissSize'] == [28, 28]
                assert error['error']['dismissLabel'] == 'Dismiss' and error['error']['cornerRadius'] == 12
                time.sleep(.2)
                path = OUTPUT / f'command-error-{theme}.png'
                error = quick(surface='error', appearance=theme, snapshot=str(path))
                manifest.append({'file': path.name, 'state': error})
                for focus_event, control_name in [('focus', 'recovery'), ('focus-dismiss', 'dismiss')]:
                    focused = quick(surface='error', event=focus_event)
                    assert focused['error']['keyWindow'] and focused['error'][control_name + 'Focused']
                    time.sleep(.2)
                    path = OUTPUT / f'command-error-keyboard-{control_name}-{theme}.png'
                    focused = quick(surface='error', appearance=theme, snapshot=str(path))
                    manifest.append({'file': path.name, 'state': focused})
                quick(surface='error', event='dismiss'); quick(surface='browser', event='close')
                # Exercise an actual wheel command and ControlBridge rejection.
                # This review process denies AX without changing any grants.
                control(event='open', mode='persistent', point=[700, 500], bounds=[200, 200, 1000, 700], level='draw', highlighted='pen', keyboard=True)
                control(event='key', key='enter')
                error = quick(surface='error', appearance=theme)
                assert error['error']['visible'] and not error['error']['keyWindow']
                assert error['error']['action'] == 'Open Accessibility Settings'
                assert 'Accessibility' in error['error']['reason']
                time.sleep(.2)
                path = OUTPUT / f'command-error-rejected-{theme}.png'
                error = quick(surface='error', appearance=theme, snapshot=str(path))
                manifest.append({'file': path.name, 'state': error})
                quick(surface='error', event='dismiss')
                for name, bounds in [('wheel', [200, 200, 1000, 700]), ('list', [200, 200, 320, 180])]:
                    control(event='open', mode='persistent', point=[700, 500], bounds=bounds)
                    time.sleep(.2)
                    recovery = quick(surface='recovery', event='open', appearance=theme)
                    assert not recovery['recovery']['keyWindow']
                    recovery = quick(surface='recovery', event='focus')
                    assert recovery['recovery']['keyWindow'] and recovery['recovery']['undoFocused']
                    time.sleep(.2)
                    path = OUTPUT / f'clear-recovery-keyboard-{name}-{theme}.png'
                    recovery = quick(surface='recovery', appearance=theme, snapshot=str(path))
                    manifest.append({'file': path.name, 'state': recovery})
                    recovery = quick(surface='recovery', event='focus-dismiss')
                    assert recovery['recovery']['keyWindow'] and recovery['recovery']['dismissFocused']
                    time.sleep(.2)
                    path = OUTPUT / f'clear-recovery-keyboard-dismiss-{name}-{theme}.png'
                    recovery = quick(surface='recovery', appearance=theme, snapshot=str(path))
                    manifest.append({'file': path.name, 'state': recovery})
                    recovery = quick(surface='recovery', event='undo-key' if name == 'wheel' else 'dismiss')
                    assert not recovery['recovery']['visible']
                    prior = control(event='state')
                    # Recovery owns the wheel's original restoration token.
                    # Leaving recovery ends the relinquished wheel session.
                    assert not prior['visible'], 'Recovery must not reactivate the relinquished controls window'
                    control(event='close')
                recovery = quick(surface='recovery', event='open', appearance=theme)
                control(operation='off')
                recovery = quick(surface='recovery')
                assert recovery['recovery']['valid'] and recovery['recovery']['visible'] and not recovery['recovery']['keyWindow']
                assert recovery['recovery']['undoHeight'] == 28 and recovery['recovery']['dismissSize'] == [28, 28]
                assert recovery['recovery']['dismissLabel'] == 'Dismiss'
                assert not recovery['recovery']['undoFocused'] and not recovery['recovery']['dismissFocused']
                time.sleep(.2)
                path = OUTPUT / f'clear-recovery-{theme}.png'
                recovery = quick(surface='recovery', appearance=theme, snapshot=str(path))
                manifest.append({'file': path.name, 'state': recovery})
                # Open real app-owned controls, then close them using production
                # exclusion methods. Capture only the diagnostic witness window.
                control(event='open', mode='persistent', point=[700, 500], bounds=[200, 200, 1000, 700])
                quick(surface='browser', event='open', appearance=theme)
                hidden = quick(surface='exclusion', event='open', appearance=theme)
                assert not hidden['browser']['visible'] and not hidden['recovery']['visible']
                assert hidden['recovery']['valid'] and hidden['recovery']['captureHidden']
                assert not hidden['capture']['wheelVisible'] and not hidden['capture']['resultVisible']
                time.sleep(.2)
                path = OUTPUT / f'screenshot-exclusion-{theme}.png'
                hidden = quick(surface='exclusion', appearance=theme, snapshot=str(path))
                manifest.append({'file': path.name, 'state': hidden})
                restored = quick(surface='exclusion', event='restore')
                assert restored['recovery']['visible'] and not restored['browser']['visible']
                assert not restored['capture']['wheelVisible']
                assert not control(event='state')['visible']
                # The diagnostic witness itself owns key focus here. External
                # responder restoration remains a manual acceptance check.
                assert not restored['recovery']['keyWindow']
                quick(surface='browser', event='close'); control(event='close')
                quick(surface='recovery', event='edit')
                stale = quick(surface='recovery', event='undo')
                assert not stale['recovery']['valid'] and stale['recovery']['accessibilityHidden']
            (OUTPUT / 'manifest.json').write_text(json.dumps(manifest, indent=2))
            print(f'PASS {len(manifest)} snapshots with state/layout JSON')
        finally:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
            log.close()


if __name__ == '__main__':
    main()
