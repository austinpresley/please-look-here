#!/usr/bin/env python3
"""Create and verify a recoverable source copy on a second local volume."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile
import uuid


def git(root, *arguments):
    return subprocess.run(
        ['git', '-C', str(root), *arguments], check=True, capture_output=True
    ).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, default=Path.home() / 'Library' /
                        'Application Support' / 'Look Here Please' / 'Backups')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    destination = args.destination.expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)
    if root.stat().st_dev == destination.stat().st_dev:
        parser.error('Choose a backup destination on a different volume from this checkout.')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output = destination / ('source-' + stamp + '-' + uuid.uuid4().hex[:8])
    output.mkdir()
    bundle = output / 'source.bundle'
    git(root, 'bundle', 'create', str(bundle), '--branches', '--tags', 'HEAD')
    git(root, 'bundle', 'verify', str(bundle))
    patch = output / 'working-tree.patch'
    patch.write_bytes(git(root, 'diff', '--binary', 'HEAD'))
    untracked = [name for name in git(root, 'ls-files', '--others',
                                    '--exclude-standard', '-z').split(b'\0') if name]
    with tarfile.open(output / 'untracked.tar.gz', 'w:gz') as archive:
        for name in untracked:
            relative = name.decode('utf-8', errors='surrogateescape')
            archive.add(root / relative, arcname=relative, recursive=False)
    (output / 'RESTORE.txt').write_text(
        'Restore into a new empty folder. Keep the original checkout intact.\n\n'
        '1. Run: git clone source.bundle restored\n'
        '2. In restored, apply working-tree.patch with git apply if it is nonempty.\n'
        '3. Extract untracked.tar.gz into restored, preserving relative paths.\n'
        '4. Compare HEAD and the checksums with manifest.json.\n\n'
        'This source backup excludes ignored build output and user app data.\n'
        'Use the app backup export to carry preferences, hands and gestures.\n'
    )
    files = sorted(path for path in output.iterdir() if path.is_file())
    checksums = {}
    for path in files:
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
        checksums[path.name] = digest.hexdigest()
    manifest = {'createdUTC': stamp, 'source': str(root),
                'head': git(root, 'rev-parse', 'HEAD').decode().strip(),
                'branch': git(root, 'branch', '--show-current').decode().strip(),
                'untrackedFiles': len(untracked), 'sha256': checksums,
                'bundleVerified': True}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'state': 'verified', 'path': str(output), **manifest}, indent=2))


if __name__ == '__main__':
    main()
