#!/usr/bin/env python3
"""Package the reviewed and refined designs in one offline HTML document."""
import base64
import hashlib
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FIRST = HERE.parent

def js(value):
    return json.dumps(value, ensure_ascii=False).replace('</', '<\\/')

def main():
    spec = json.loads((HERE / 'design-spec.json').read_text())
    original = (FIRST / 'preview.html').read_text()
    art = json.loads(re.search(r'const ART=(.*);', original).group(1))
    full = json.loads(re.search(r'const ART_FULL=(.*);', original).group(1))
    catalog = [{'id': id, 'name': name} for id, name in re.findall(r'\("([a-z]+)", "([^"]+)", Ink\.', (ROOT / 'Sources/TinyHand/PointerStyle.swift').read_text())]
    assets = HERE / 'artwork'
    assets.mkdir(exist_ok=True)
    for p in catalog:
        if p['id'] not in art:
            path = assets / (p['id'] + '.png')
            if not path.exists():
                subprocess.run(['sips', '-c', '700', '700', '--cropOffset', '60', '160', str(ROOT / f"assets/hand_{p['id']}.png"), '--out', str(path)], check=True, capture_output=True)
                subprocess.run(['sips', '-Z', '140', str(path)], check=True, capture_output=True)
            art[p['id']] = str(path)
    catalog += [{'id': id, 'name': name} for id, name in [('laser', 'Laser dot'), ('spotlight', 'Spotlight'), ('presentation', 'Presentation pointer')]]
    gestures = {}
    for pose in ['ok', 'shaka']:
        path = assets / ('gesture-' + pose + '.png')
        if not path.exists():
            subprocess.run(['sips', '-c', '900', '800', '--cropOffset', '0', '112', str(ROOT / f'assets/gesture_{pose}.png'), '--out', str(path)], check=True, capture_output=True)
            subprocess.run(['sips', '-Z', '160', str(path)], check=True, capture_output=True)
        gestures[pose] = str(path)
    icon = str(ROOT / 'docs/assets/apple-touch-icon.png')
    first_frame = (HERE / 'version-one-frame.html').read_text()
    base_css = (HERE / 'native-base.css').read_text()
    refined_css = (HERE / 'refined.css').read_text()
    refined_js = (HERE / 'refined.js').read_text()
    second_frame = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>' + base_css + '\n' + refined_css + '</style></head><body><div class="app refined" id="app"><div class="chrome" aria-hidden="true"><i></i><i></i><i></i><span>Look Here Please Settings</span></div><div class="app-body"><nav id="app-nav" class="app-nav" aria-label="Settings pages"></nav><main id="app-main" class="app-main"></main></div><div id="modal-layer" class="modal-layer" hidden></div><div class="toast" id="toast" role="status" hidden></div></div><script>' + refined_js + '</script></body></html>'
    (HERE / 'version-two-frame.html').write_text(second_frame)
    replacements = {
        '__ICON__': icon, '__ICON_JSON__': js(icon),
        '__TITLE__': spec['title'], '__INTRO__': spec['intro'],
        '__DEMO_SCOPE__': spec['demoScope'],
        '__REVIEW_METHOD__': spec['reviewMethod'],
        '__IMPLEMENTATION_SCOPE__': spec['implementationScope'],
        '__ART__': js(art), '__FULL_ART__': js(full), '__SPEC__': js(spec),
        '__CATALOG__': js(catalog), '__GESTURES__': js(gestures),
        '__NOTICES__': js((ROOT / 'assets/ThirdPartyNotices.txt').read_text()),
        '__FRAME_ONE__': js(first_frame), '__FRAME_TWO__': js(second_frame),
    }
    html = (HERE / 'comparison.html').read_text()
    for token, value in replacements.items():
        html = html.replace(token, value)
    (HERE / 'preview.html').write_text(html)
    for filename in list(art.values()) + list(full.values()) + list(gestures.values()) + [icon]:
        data = 'data:image/png;base64,' + base64.b64encode(Path(filename).read_bytes()).decode()
        html = html.replace(filename, data)
    html = html.replace('<body>', '<body class="standalone">', 1)
    html = html.replace('</style>', '''body.standalone{padding:24px clamp(16px,3vw,48px);background:#fff}
@media(prefers-color-scheme:dark){body.standalone{background:#211e26}}
</style>''', 1)
    destination = HERE / 'settings-refinement-before-and-after.html'
    destination.write_text(html)
    brief = json.loads((HERE / 'review-brief.json').read_text())
    assert hashlib.sha256((FIRST / 'settings-before-and-after.html').read_bytes()).hexdigest() == brief['sha256'], 'Version one was changed'
    assert '/Volumes/' not in html, 'Offline artifact still has a local dependency'
    assert not re.search(r'__(?:ART|SPEC|FRAME|ICON|TITLE|INTRO)', html), 'Unresolved build token'
    print(f'Built {destination.name}: {destination.stat().st_size:,} bytes; version one unchanged.')

if __name__ == '__main__':
    main()
