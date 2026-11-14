#!/usr/bin/env python3
"""Exercise fail-closed embedding with disposable packages, without signing/network/host."""
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import sys

sys.dont_write_bytecode = True
import unittest

spec = importlib.util.spec_from_file_location('contract', Path(__file__).with_name('streamdeck-package.py'))
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)


class EmbeddingTests(unittest.TestCase):
    def test_missing_stale_changed_and_matching_installers(self):
        with tempfile.TemporaryDirectory(prefix='s022-contract-') as tmp:
            root = Path(tmp)
            app = root / 'Test.app'
            resources = app / 'Contents/Resources'
            resources.mkdir(parents=True)
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.0.2', 'CFBundleVersion': '123'}))
            output = root / 'plugin'
            output.mkdir()
            with self.assertRaises(FileNotFoundError):
                contract.embed(app, output)
            archive = output / contract.FILENAME
            archive.write_bytes(b'test payload')
            manifest = json.loads((contract.ROOT / 'streamdeck/manifest.json').read_text())
            record = {'schema': 1, 'pluginID': contract.PLUGIN_ID, 'pluginVersion': manifest['Version'], 'minimumHostVersion': manifest['Software']['MinimumVersion'], 'sha256': contract.digest(archive), 'notarizationID': 'fixture-accepted', 'sourceHashes': {}}
            receipt = output / 'package.json'
            receipt.write_text(json.dumps(record))
            with self.assertRaisesRegex(AssertionError, 'inputs changed'):
                contract.embed(app, output)
            record['sourceHashes'] = contract.inputs()
            receipt.write_text(json.dumps(record))
            (output / 'notarization.json').write_text(json.dumps({'status': 'Invalid', 'id': 'fixture-accepted'}))
            with self.assertRaises(AssertionError):
                contract.embed(app, output)
            (output / 'notarization.json').write_text(json.dumps({'status': 'Accepted', 'id': 'fixture-accepted'}))
            archive.write_bytes(b'changed after validation')
            with self.assertRaisesRegex(AssertionError, 'changed after validation'):
                contract.embed(app, output)
            archive.write_bytes(b'test payload')
            contract.embed(app, output)
            embedded = json.loads((resources / 'StreamDeckInstaller.json').read_text())
            self.assertEqual(embedded['appVersion'], '1.0.2')
            self.assertEqual(embedded['appBuild'], '123')
            self.assertEqual(embedded['sha256'], contract.digest(resources / contract.FILENAME))
            self.assertEqual(embedded['pluginVersion'], manifest['Version'])


if __name__ == '__main__':
    unittest.main()
