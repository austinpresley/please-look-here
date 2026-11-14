#!/usr/bin/env python3
"""Local package contract. No app build, host install, profile write or downloader."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ID = 'com.austinpresley.lookhereplease'
FILENAME = PLUGIN_ID + '.streamDeckPlugin'
TEAM = 'G2R8798RLT'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    paths = [ROOT / 'Package.swift', ROOT / 'scripts/build-streamdeck.sh', ROOT / 'scripts/streamdeck-package.py', ROOT / 'LICENSE']
    paths += [p for base in ('Sources/LookHerePleaseDeck', 'streamdeck') for p in (ROOT / base).rglob('*') if p.is_file()]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def verify_archive(archive, manifest, payload=None):
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, 'Corrupt plugin archive'
        names = z.namelist()
        prefix = PLUGIN_ID + '.sdPlugin/'
        assert all(n.startswith(prefix) and '..' not in Path(n).parts for n in names), 'Unexpected archive paths'
        actual = json.loads(z.read(prefix + 'manifest.json'))
        assert actual == manifest, 'Plugin manifest does not match this source/build'
        executable = prefix + actual['CodePath']
        assert z.getinfo(executable).external_attr >> 16 & stat.S_IXUSR, 'Plugin executable bit is missing'
        if payload:
            expected = {str(p.relative_to(payload)): digest(p) for p in payload.rglob('*') if p.is_file()}
            received = {n[len(prefix):]: hashlib.sha256(z.read(n)).hexdigest() for n in names if not n.endswith('/') and not n.startswith(prefix + '__MACOSX/')}
            assert expected == received, 'Plugin archive payload differs from signed build'
    with tempfile.TemporaryDirectory(prefix='lookhere-plugin-check-') as tmp:
        subprocess.run(['ditto', '-x', '-k', str(archive), tmp], check=True)
        bundle = Path(tmp) / (PLUGIN_ID + '.sdPlugin')
        binary = bundle / manifest['CodePath']
        subprocess.run(['codesign', '--verify', '--strict', str(binary)], check=True)
        info = subprocess.check_output(['codesign', '-dvv', str(binary)], stderr=subprocess.STDOUT, text=True)
        assert 'TeamIdentifier=' + TEAM in info and 'runtime' in info and 'Timestamp=' in info, 'Plugin must use timestamped hardened Developer ID signing'
        assert set(subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()) == {'arm64', 'x86_64'}, 'Plugin must be universal'
        subprocess.run(['npx', '--yes', '@elgato/cli@1.10.0', 'validate', str(bundle), '--force-update-check'], check=True)
    return digest(archive)


def record(output):
    manifest = json.loads((ROOT / 'streamdeck/manifest.json').read_text())
    assert manifest['UUID'] == PLUGIN_ID
    receipt = json.loads((output / 'notarization.json').read_text())
    assert receipt['status'] == 'Accepted', 'Plugin notarization must be Accepted'
    sha = verify_archive(output / FILENAME, manifest, output / (PLUGIN_ID + '.sdPlugin'))
    result = {'schema': 1, 'pluginID': PLUGIN_ID, 'pluginVersion': manifest['Version'],
              'minimumHostVersion': manifest['Software']['MinimumVersion'], 'sha256': sha,
              'notarizationID': receipt['id'], 'sourceHashes': inputs()}
    (output / 'package.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Verified signed/notarized plugin:', result['pluginVersion'], sha)


def embed(app, output):
    record = json.loads((output / 'package.json').read_text())
    assert record['sourceHashes'] == inputs(), 'Plugin inputs changed. Rebuild the plugin before packaging the app.'
    manifest = json.loads((ROOT / 'streamdeck/manifest.json').read_text())
    assert record['pluginID'] == manifest['UUID'] == PLUGIN_ID and record['pluginVersion'] == manifest['Version']
    assert record['minimumHostVersion'] == manifest['Software']['MinimumVersion']
    assert digest(output / FILENAME) == record['sha256'], 'Plugin installer changed after validation'
    notarization = json.loads((output / 'notarization.json').read_text())
    assert notarization['status'] == 'Accepted' and notarization['id'] == record['notarizationID']
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    resources = app / 'Contents/Resources'
    shutil.copy2(output / FILENAME, resources / FILENAME)
    record.update(appVersion=info['CFBundleShortVersionString'], appBuild=info['CFBundleVersion'])
    (resources / 'StreamDeckInstaller.json').write_text(json.dumps(record, indent=2) + '\n')


def verify_app(app):
    resources = app / 'Contents/Resources'
    record = json.loads((resources / 'StreamDeckInstaller.json').read_text())
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert record['schema'] == 1 and record['pluginID'] == PLUGIN_ID
    assert record['appVersion'] == info['CFBundleShortVersionString'] and record['appBuild'] == info['CFBundleVersion'], 'Installer/app version mismatch'
    assert record['sourceHashes'] == inputs(), 'Delivered plugin is stale against build inputs'
    manifest = json.loads((ROOT / 'streamdeck/manifest.json').read_text())
    assert record['pluginVersion'] == manifest['Version'] and record['minimumHostVersion'] == manifest['Software']['MinimumVersion']
    assert verify_archive(resources / FILENAME, manifest) == record['sha256'], 'Bundled installer SHA-256 mismatch'
    print('App installer contract verified:', record['appVersion'], record['appBuild'], record['pluginVersion'], record['sha256'])


if __name__ == '__main__':
    try:
        command = sys.argv[1]
        if command == 'record': record(Path(sys.argv[2]))
        elif command == 'embed': embed(Path(sys.argv[2]), Path(sys.argv[3]))
        elif command == 'verify-app': verify_app(Path(sys.argv[2]))
        else: raise ValueError('Use record OUTPUT | embed APP OUTPUT | verify-app APP')
    except Exception as error:
        raise SystemExit('Stream Deck packaging failed: ' + str(error))
