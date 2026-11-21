#!/usr/bin/env python3
"""Copy approved full canvases, recompressing only PNG IDAT bytes losslessly."""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'design/gesture-art-2026-11-18'
OUTPUT = ROOT / 'dist/verification/usability-icons-phaseB2C'


def optimize(data):
    chunks = []
    offset = 8
    while offset < len(data):
        length, kind = struct.unpack('>I4s', data[offset:offset+8])
        chunks.append((kind, data[offset+8:offset+8+length]))
        offset += length + 12
    pixels = zlib.decompress(b''.join(value for kind, value in chunks if kind == b'IDAT'))
    packed = zlib.compress(pixels, 9)
    result = data[:8]
    wrote = False
    for kind, value in chunks:
        if kind == b'IDAT':
            if wrote:
                continue
            value = packed
            wrote = True
        result += struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind+value))
    assert zlib.decompress(packed) == pixels
    # Retain every color/profile/geometry chunk unchanged. The filtered pixel
    # stream is identical, stronger than a rendered appearance comparison.
    return min([data, result], key=len), hashlib.sha256(pixels).hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((SOURCE/'manifest.json').read_text())
    assert manifest['pairs_passed'] == 36
    rows = []
    for name, item in manifest['images'].items():
        assert item['pass'] and item['checks']['pass'] and item['manual_review']['pass']
        source = (SOURCE/item['file']).read_bytes()
        assert hashlib.sha256(source).hexdigest() == item['sha256']
        data, pixel_hash = optimize(source)
        hand, pose = name.rsplit('-', 1)
        target = ROOT/'assets'/f'gesture_{hand}_{pose}.png'
        target.write_bytes(data)
        rows.append(dict(file=target.name, source_bytes=len(source), bundled_bytes=len(data), filtered_pixels_sha256=pixel_hash, pixel_stream_identical=True))
    assert len(rows) == 72
    report = dict(images=rows, source_bytes=sum(r['source_bytes'] for r in rows), bundled_bytes=sum(r['bundled_bytes'] for r in rows), lossless=True)
    (OUTPUT/'gesture-resource-audit.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'images'}))


if __name__ == '__main__':
    main()
