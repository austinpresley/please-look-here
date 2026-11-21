#!/usr/bin/env python3
"""Create an offline gallery from actual local Settings verification captures."""
import base64
import json
from pathlib import Path
import plistlib
import shutil

root = Path(__file__).resolve().parents[1]
shots = root / 'dist/verification/settings-implementation/native'
out = root / 'design/settings-redesign/native-review'
out.mkdir(parents=True, exist_ok=True)
spec = [
    ('general', 'General', [('general', 'Page')]),
    ('pointers', 'Pointers', [('pointers', 'Library'), ('customize', 'Customize'), ('new-hand', 'New Hand')]),
    ('appearance', 'Pointer defaults', [('appearance', 'Page')]),
    ('drawing', 'Tools', [('drawing', 'Drawing'), ('magnification', 'Magnification'), ('screenshots', 'Screenshots')]),
    ('shortcuts', 'Shortcuts', [('shortcuts', 'Closed by default'), ('shortcuts-pointer', 'Pointer'), ('shortcuts-presenting', 'Presenting'), ('shortcuts-drawing', 'Drawing'), ('shortcuts-tools', 'Tool keys'), ('shortcuts-toolbar', 'Toolbar'), ('shortcuts-quickControls', 'Quick controls'), ('shortcuts-streamDeck', 'Stream Deck'), ('shortcuts-linked', 'Practice link'), ('shortcuts-expanded', 'All open')]),
    ('presets', 'Presets & Backup', [('presets', 'Page')]),
    ('about', 'About', [('about', 'Page')]),
]
images = {}
for _, _, views in spec:
    for stem, _ in views:
        images[stem] = {theme: str(shots / (stem + '-' + theme + '.png')) for theme in ['light', 'dark']}
        for filename in images[stem].values():
            assert Path(filename).exists(), filename
checks = json.loads((shots.parent / 'native-results.json').read_text())
assert all(check['passed'] for check in checks)
app = root / 'dist/Look Here Please Review.app'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
build = info.get('CFBundleVersion', '')
html = r'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Look Here Please · Native Settings review</title><style>
:root{--ink:var(--foreground,#30233d);--dim:var(--muted-foreground,#756c80);--line:var(--border,#ded8e5);--paper:var(--card,#fff);--soft:var(--secondary,#f3eff7);--radius:12px}*{box-sizing:border-box}html,body{margin:0;background:transparent;color:var(--ink);font-family:var(--font-sans,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif);font-size:14px;line-height:1.5}h1,h2,p{margin:0}button,select{font:inherit}button{cursor:pointer}button:focus-visible,summary:focus-visible{outline:2px solid #9b78c9;outline-offset:4px}.document{max-width:1440px;margin:auto}.intro{padding:8px 0 20px;border-bottom:1px solid var(--line)}.intro h1{font-size:clamp(26px,4.3vw,36px);font-weight:680;line-height:1.16;letter-spacing:-.8px}.intro p{font-size:14px;color:var(--dim);max-width:78ch;margin-top:12px}.status{font-size:12px;color:var(--dim);margin-top:12px}.status strong{color:var(--ink);font-weight:600}.pages{display:flex;gap:5px;flex-wrap:wrap;margin:20px 0 14px}.pages button,.views button{color:var(--dim);border:1px solid transparent;background:transparent;border-radius:6px;padding:6px 9px;font-size:12px}.pages button[aria-current=page],.views button[aria-pressed=true]{color:var(--ink);background:var(--soft);border-color:var(--line);font-weight:600}.controls{display:flex;align-items:center;justify-content:space-between;gap:14px;margin-bottom:14px}.controls h2{font-size:21px;letter-spacing:-.4px;font-weight:650}.theme{display:flex;gap:2px;border:1px solid var(--line);padding:3px;border-radius:7px;background:var(--soft)}.theme button{background:transparent;border:0;border-radius:4px;color:var(--dim);font-size:12px;padding:4px 9px}.theme button[aria-pressed=true]{background:var(--paper);color:var(--ink)}.views{display:flex;gap:4px;flex-wrap:wrap;margin:4px 0 14px}.views:empty{display:none}.image-wrap{padding:16px;border:1px solid var(--line);border-radius:var(--radius);background:var(--soft)}.image-wrap img{display:block;width:100%;max-width:1000px;margin:auto;height:auto;border-radius:8px}.caption{font-size:11px;color:var(--dim);margin-top:9px}.details{border-top:1px solid var(--line);margin-top:18px;padding-top:14px;font-size:12px;color:var(--dim)}.details summary{font-size:13px;font-weight:600;color:var(--ink);cursor:pointer}.details ul{padding-left:18px}.details li{margin:7px 0}.footer{margin-top:18px;border-top:1px solid var(--line);padding:14px 0;font-size:11px;color:var(--dim)}.viewer-note{font-size:12px;color:var(--dim);margin:12px 0}.footer a{color:inherit;text-underline-offset:3px}@media(prefers-color-scheme:dark){:root{--ink:var(--foreground,#eee8f5);--dim:var(--muted-foreground,#b7adc2);--line:var(--border,#483f51);--paper:var(--card,#302935);--soft:var(--secondary,#3b3246)}}
</style></head><body><main class="document"><header class="intro"><h1>Native Settings, implemented.</h1><p>The seven-page redesign is now in the app. Every Shortcuts section is collapsible and starts closed. Search, practice links and conflict recovery reveal the relevant section explicitly.</p><p class="status"><strong>400 local tests passed.</strong> __CHECKS__ live UI checks passed. Light and dark captures cover every page and each shortcut group.</p></header><nav id="pages" class="pages" aria-label="Native Settings pages"></nav><div class="controls"><h2 id="title"></h2><div class="theme" aria-label="Screenshot theme"><button data-theme="light" aria-pressed="true">Light</button><button data-theme="dark" aria-pressed="false">Dark</button></div></div><div id="views" class="views" aria-label="Captured state"></div><div class="image-wrap"><img id="shot" alt=""></div><p class="caption">Actual app-window captures from an isolated test profile on the Mac mini. This viewer shows screenshots; use the review app to operate the native controls.</p><details class="details"><summary>Implemented and checked</summary><ul><li>General groups permissions, startup, updates and app appearance.</li><li>Pointer defaults separates shared values from global output and motion.</li><li>Tools has Drawing, Magnification and Screenshots panes, with local drawing practice.</li><li>Pointers has favorites, combined filters and one searchable library scroll. Customize and New Hand are native sheets.</li><li>All seven Shortcuts groups start closed, including groups with saved assignments. Closing a group cancels any active recorder.</li><li>Direct links reveal their exact row without recording or changing keys. All 26 native shortcut destinations are present when expanded.</li><li>Presets keep their recovery and import validation. Preset-only edits preserve artwork caches.</li><li>The normal app, user preferences and grants were left intact. This is an isolated review build.</li></ul></details><footer class="footer">Review app version 1.2.0 · Build __BUILD__. Built and verified locally; hosted CI stayed disabled.</footer></main><script>
const PAGES=__PAGES__,IMAGES=__IMAGES__;let page='shortcuts',view='shortcuts',theme='light';const $=id=>document.getElementById(id);
function render(){const p=PAGES.find(p=>p[0]===page);$('pages').innerHTML=PAGES.map(p=>`<button data-page="${p[0]}" aria-current="${p[0]===page?'page':'false'}">${p[1]}</button>`).join('');$('title').textContent=p[1];$('views').innerHTML=p[2].length>1?p[2].map(([id,label])=>`<button data-view="${id}" aria-pressed="${id===view}">${label}</button>`).join(''):'';$('shot').src=IMAGES[view][theme];$('shot').alt=`Native ${p[1]} settings, ${theme} appearance`;document.querySelectorAll('[data-theme]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.theme===theme))}
document.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;if(b.dataset.page){page=b.dataset.page;view=PAGES.find(p=>p[0]===page)[2][0][0]}if(b.dataset.view)view=b.dataset.view;if(b.dataset.theme)theme=b.dataset.theme;render()});render();console.log('Native review ready: 7 pages, 40 actual captures.');
</script></body></html>'''
html = html.replace('__CHECKS__', str(len(checks))).replace('__BUILD__', build).replace('__PAGES__', json.dumps(spec)).replace('__IMAGES__', json.dumps(images))
(out / 'preview.html').write_text(html)
for pair in images.values():
    for filename in pair.values():
        uri = 'data:image/png;base64,' + base64.b64encode(Path(filename).read_bytes()).decode()
        html = html.replace(filename, uri)
html = html.replace('<body>', '<body class="standalone">', 1).replace('</style>', 'body.standalone{padding:24px clamp(16px,3vw,48px);background:#fff}@media(prefers-color-scheme:dark){body.standalone{background:#211e26}}</style>', 1)
file = out / 'settings-native-review.html'
file.write_text(html)
share = root / 'dist/settings-review-share'
share.mkdir(parents=True, exist_ok=True)
shutil.copyfile(file, share / 'index.html')
print(f'Native review gallery: {file}; {len(checks)} checks; build {build}')
