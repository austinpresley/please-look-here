#!/usr/bin/env python3
"""Build pass two / pass three comparison without modifying earlier artifacts."""
import base64
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / 'round-2'

def js(value):
    return json.dumps(value, ensure_ascii=False).replace('</', '<\\/')

source = (PREVIOUS / 'preview.html').read_text()
values = {}
for name in ['REVIEW_ART', 'REVIEW_FULL_ART', 'REVIEW_ICON', 'REVIEW_CATALOG', 'REVIEW_GESTURES', 'REVIEW_NOTICES']:
    values[name] = json.loads(re.search(r'window\.' + name + r'=(.*);', source).group(1))

before = (PREVIOUS / 'version-two-frame.html').read_text().replace("version:'v2'", "version:'v1'")
before = before.replace('</script>', '''window.addEventListener('message',e=>{
 if(e.source===parent&&e.data?.type==='review-state'&&S.page==='drawing'&&e.data.toolPane){
   requestAnimationFrame(()=>focusSection(e.data.toolPane==='drawing'?'drawing-ink':e.data.toolPane));
 }
});</script>''')
(HERE / 'before-frame.html').write_text(before)
base_js = (HERE / 'refined.js').read_text()
initialization = "replaySample();render();new ResizeObserver(reportSize).observe($('app'));parent.postMessage({type:'frame-ready',version:'v2'},'*');"
assert initialization in base_js
combined_js = base_js.replace(initialization, '') + '\n' + (HERE / 'ui-pass.js').read_text() + '\n' + initialization
(HERE / 'combined.js').write_text(combined_js)
css = '\n'.join((HERE / p).read_text() for p in ['native-base.css', 'refined.css', 'ui-pass.css'])
after = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>' + css + '</style></head><body><div class="app refined third" id="app"><div class="chrome" aria-hidden="true"><i></i><i></i><i></i><span>Look Here Please Settings</span></div><div class="app-body"><nav id="app-nav" class="app-nav" aria-label="Settings pages"></nav><main id="app-main" class="app-main"></main></div><div id="modal-layer" class="modal-layer" hidden></div><div class="toast" id="toast" role="status" hidden></div></div><script>' + combined_js + '</script></body></html>'
(HERE / 'after-frame.html').write_text(after)
spec = json.loads((HERE / 'design-spec.json').read_text())
html = (HERE / 'comparison.html').read_text()
replacements = {'__SPEC__': js(spec), '__BEFORE__': js(before), '__AFTER__': js(after)}
replacements.update({'__' + key + '__': js(value) for key, value in values.items()})
for token, value in replacements.items():
    html = html.replace(token, value)
(HERE / 'preview.html').write_text(html)
for filename in list(values['REVIEW_ART'].values()) + list(values['REVIEW_FULL_ART'].values()) + list(values['REVIEW_GESTURES'].values()) + [values['REVIEW_ICON']]:
    uri = 'data:image/png;base64,' + base64.b64encode(Path(filename).read_bytes()).decode()
    html = html.replace(filename, uri)
html = html.replace("mode='after'", "mode='compare'", 1)
html = html.replace('<body>', '<body class="standalone">', 1).replace('</style>', '''body.standalone{padding:24px clamp(16px,3vw,48px);background:#fff}
@media(prefers-color-scheme:dark){body.standalone{background:#211e26}}</style>''', 1)
destination = HERE / 'settings-ui-pass-three.html'
destination.write_text(html)
brief = json.loads((HERE / 'review-brief.json').read_text())
assert hashlib.sha256(Path(brief['baselineArtifact']).read_bytes()).hexdigest() == brief['baselineSha256']
assert '/Volumes/' not in html
assert not re.search(r'__(?:SPEC|BEFORE|AFTER|REVIEW_)', html)
print(f'Built {destination.name}: {destination.stat().st_size:,} bytes. Pass two unchanged.')
