#!/usr/bin/env python3
"""Check shortcut assignments only on an explicitly isolated running test app.

Run once, relaunch with the same isolated defaults suite, then use --after-relaunch.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
binary = Path.home() / 'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
output = Path(os.environ.get('TINYHAND_VERIFICATION_DIR', root / 'dist/verification/s015'))
output.mkdir(parents=True, exist_ok=True)
suite = os.environ['TINYHAND_DEFAULTS_SUITE']
assert suite.startswith('com.austinpresley.tinyhand.s015.'), 'Use a disposable S-015 defaults suite'
checks = []


def call(operation, **fields):
    result = subprocess.run([str(binary), '--ctl', json.dumps(dict(version=1, operation=operation, **fields))],
                            capture_output=True, text=True, timeout=10)
    response = json.loads(result.stdout)
    assert result.returncode == 0 and response['ok'], response
    return response


def shortcuts(**request):
    result = call('test-shortcuts', request=request)['shortcuts']
    assert result.get('defaultsSuite') == suite, 'The running app must use this isolated suite'
    return result


def passed(name):
    print('PASS', name, flush=True)
    checks.append(name)


def assignment(code=40, modifiers=6144, display='⌃⌥K'):
    return dict(keyCode=code, modifiers=modifiers, display=display)


assert 'test-shortcuts' in call('status')['state']['capabilities'], 'Launch the isolated app with TINYHAND_TEST_MODE=1'
initial = shortcuts()
if '--after-relaunch' in sys.argv:
    expected = json.loads((output / 'expected-relaunch.json').read_text())
    assert initial['assignments'] == expected, initial
    assert initial['assignments']['pen'] is None
    assert initial['registeredCount'] == 1, initial  # Only assigned toggle is global with pointer off.
    passed('saved custom assignments and cleared Pen survive LaunchServices relaunch')
    reset = shortcuts(command='reset')
    assert all(value is None for value in reset['assignments'].values()) and reset['registeredCount'] == 0, reset
    passed('Reset All clears every command and unregisters the final binding')
    report = output / 'shortcut-relaunch.json'
else:
    assert all(value is None for value in initial['assignments'].values()), initial
    assert initial['registeredCount'] == 0, initial
    call('on')
    assert shortcuts()['registeredCount'] == 0
    call('off')
    passed('fresh domain registers no hotkeys, with pointer off or on, including Escape')
    for command in initial['assignments']:
        assigned = shortcuts(command=command, shortcut=assignment())
        assert assigned['accepted'] and assigned['assignments'][command] == assignment(), assigned
        cleared = shortcuts(command=command, shortcut=None)
        assert cleared['accepted'] and cleared['assignments'][command] is None, cleared
        assert cleared['registeredCount'] == 0, cleared
    passed(f'all {len(initial["assignments"])} configurable commands assign and clear without fallbacks')
    for command, value in [('toggle', assignment()), ('mode', assignment(2, 6144, '⌃⌥D'))]:
        assert shortcuts(command=command, shortcut=value)['accepted']
    previous = shortcuts()['assignments']
    duplicate = shortcuts(command='mode', shortcut=assignment())
    assert not duplicate['accepted'] and 'already assigned' in duplicate['error']
    assert duplicate['assignments'] == previous
    passed('duplicate feedback preserves all previous assignments')
    reserved = shortcuts(command='mode', shortcut=assignment(6, 256, '⌘Z'))
    assert not reserved['accepted'] and 'reserved' in reserved['error']
    assert reserved['assignments'] == previous
    passed('reserved editing shortcut feedback preserves all previous assignments')
    with tempfile.TemporaryDirectory(prefix='s015-blocker-') as temp:
        blocker_binary = str(Path(temp) / 'ShortcutBlocker')
        subprocess.run(['swiftc', str(root / 'Tests/Fixtures/ShortcutBlocker.swift'), '-o', blocker_binary], check=True)
        blocker = subprocess.Popen([blocker_binary, '38', '6912'], stdout=subprocess.PIPE, text=True)
        try:
            assert blocker.stdout.readline().strip() == 'ready'
            unavailable = shortcuts(command='toggle', shortcut=assignment(38, 6912, '⌃⌥⇧⌘J'))
            assert not unavailable['accepted'] and 'unavailable' in unavailable['error'], unavailable
            assert unavailable['assignments'] == previous
            assert unavailable['registeredCount'] == 1
            passed('a real competing Carbon registration is rejected and prior registration restored')
        finally:
            blocker.terminate()
            blocker.wait(timeout=5)
    assert shortcuts(command='mode', shortcut=None)['accepted']
    assert shortcuts(command='capture', shortcut=assignment(1, 6144, '⌃⌥S'))['accepted']
    assert shortcuts(command='pen', shortcut=assignment(35, 0, 'P'))['accepted']
    assert shortcuts(command='pen', shortcut=None)['accepted']
    result = shortcuts()
    # S-023 reports the real grouped native menu, including nested choices.
    def menu_items(items):
        return [entry for item in items for entry in [item, *menu_items(item.get('children', []))]]
    result['menu'] = menu_items(result['menu'])
    assert next(item for item in result['menu'] if item['title'] == 'Take Screenshot')['key'] == 's'
    assert next(item for item in result['menu'] if item['title'] == 'Pen')['key'] == ''
    for title in ['Undo Annotation', 'Redo Annotation', 'Settings…', 'Turn Pointer Off']:
        assert next(item for item in result['menu'] if item['title'] == title)['key'] == ''
    passed('menu equivalents reflect assigned and unassigned commands without fixed annotation or Settings keys')
    (output / 'expected-relaunch.json').write_text(json.dumps(result['assignments'], indent=2))
    report = output / 'shortcut-smoke.json'
report.write_text(json.dumps(dict(checks=checks, final=shortcuts()), indent=2))
