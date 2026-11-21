#!/usr/bin/env python3
"""Build a portable color comparison for the selected S1 icon."""
from pathlib import Path
import base64
import io
import json
from PIL import Image

HERE=Path(__file__).resolve().parent
HTML='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>S1 Lemon pop color options</title><style>
*{box-sizing:border-box}body{margin:0;font-family:var(--font-sans,-apple-system,sans-serif);color:var(--foreground,#211729)}.intro{margin:0 0 16px;font-size:15px;line-height:1.6}.controls{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:18px}.controls p{margin:0;font-size:13px;color:var(--muted-foreground,#655D70)}.controls label{font-size:13px;white-space:nowrap}select{font:inherit;color:inherit;background:var(--card,#fff);padding:8px;border:1px solid var(--border,#DDD6E2);border-radius:8px;margin-left:6px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.swatch{font:inherit;text-align:left;color:inherit;background:var(--card,#F5F5F7);border:1px solid transparent;border-radius:14px;padding:12px;cursor:pointer}.swatch[aria-pressed=true]{border-color:var(--primary,#6850B8);box-shadow:0 0 0 1px var(--primary,#6850B8)}.swatch img{display:block;width:100%;height:auto}.swatch strong{display:block;font-size:13px;line-height:1.4;margin:8px 0 2px}.swatch span{font-size:11px;line-height:1.3;color:var(--muted-foreground,#655D70)}button:focus-visible,select:focus-visible{outline:3px solid var(--ring,#6850B8);outline-offset:3px}.compare{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:28px}.compare figure{margin:0;padding:20px;background:var(--card,#F5F5F7);border-radius:16px}.compare .large{display:block;width:100%;max-width:270px;height:auto;margin:0 auto}.compare figcaption{font-size:16px;line-height:1.4;font-weight:600;margin-top:16px}.compare .hex{font-size:12px;font-weight:400;color:var(--muted-foreground,#655D70);margin-top:4px}.tiny{display:flex;align-items:center;gap:10px;margin-top:16px;color:var(--muted-foreground,#655D70);font-size:11px}.tiny img{display:block}.footer{font-size:12px;line-height:1.6;color:var(--muted-foreground,#655D70);margin:16px 0 0}@media(max-width:500px){.grid{grid-template-columns:repeat(2,1fr)}.controls{align-items:flex-start}.controls p{max-width:155px}.controls label{display:block}.controls select{display:block;margin:5px 0 0}.compare{gap:10px}.compare figure{padding:12px}.compare figcaption{font-size:14px}.tiny{gap:5px;font-size:10px;flex-wrap:wrap}}
</style><body><p class="intro">S1's composition is selected. Here are twelve background combinations with the same purple hand. <strong>C1 is the original Lemon.</strong> Select a color to compare it with C1 below.</p><div class="controls"><p>Try Default and Dark.</p><label for="look">Appearance<select id="look" onchange="render()"><option>Default</option><option>Dark</option></select></label></div><div class="grid" id="grid" aria-label="S1 color combinations"></div><section class="compare" aria-label="Original and selected color comparison"><figure><img class="large" id="original" alt="Original S1 Lemon"><figcaption>C1 Lemon, original</figcaption><div class="hex" id="originalHex"></div><div class="tiny" id="originalTiny"></div></figure><figure><img class="large" id="selected" alt=""><figcaption id="selectedName" aria-live="polite"></figcaption><div class="hex" id="selectedHex"></div><div class="tiny" id="selectedTiny"></div></figure></section><p class="footer">The hand, angle, scale and framing are identical in every option. Backgrounds change in Default and Dark. The small images are native 32 and 16 pixel renders.</p><script>
const palettes=MANIFEST;let selected='C9';const grid=document.getElementById('grid');for(const p of palettes){const b=document.createElement('button');b.type='button';b.className='swatch';b.dataset.id=p.id;b.setAttribute('aria-pressed','false');const image=document.createElement('img');image.alt=p.name+' color option';const label=document.createElement('strong');label.textContent=p.id+' '+p.name+(p.id==='C1'?' (original)':'');const hex=document.createElement('span');b.append(image,label,hex);b.onclick=()=>{selected=p.id;render();if(window.matchMedia('(max-width:500px)').matches)document.querySelector('.compare').scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth',block:'start'});};grid.appendChild(b);}function tiny(target,p,look){target.replaceChildren();for(const px of [32,16]){const image=document.createElement('img');image.width=px;image.height=px;image.src=p.small[look][String(px)];image.alt=px+' pixel native render';const text=document.createElement('span');text.textContent=px+' px';target.append(image,text);}}function render(){const look=document.getElementById('look').value;const color=look==='Default'?'background':'dark_background';for(const b of grid.children){const p=palettes.find(p=>p.id===b.dataset.id);b.querySelector('img').src=p.images[look];b.querySelector('span').textContent=p[color];b.setAttribute('aria-pressed',String(p.id===selected));}const original=palettes[0];const current=palettes.find(p=>p.id===selected);document.getElementById('original').src=original.images[look];document.getElementById('originalHex').textContent=original[color];const image=document.getElementById('selected');image.src=current.images[look];image.alt=current.name+' in '+look;document.getElementById('selectedName').textContent=current.id+' '+current.name;document.getElementById('selectedHex').textContent=current[color];tiny(document.getElementById('originalTiny'),original,look);tiny(document.getElementById('selectedTiny'),current,look);}render();console.log('Loaded '+palettes.length+' S1 color combinations');
</script></body></html>'''


def main():
    palettes=json.loads((HERE/'palettes.json').read_text())['variants']
    web=HERE/'web';web.mkdir(exist_ok=True)
    for p in palettes:
        p['images']={};p['small']={}
        for look in ['Default','Dark']:
            dest=web/f'{p["id"]}-{look}.png'
            Image.open(HERE/'exports'/f'{p["id"]}-{look}-512.png').convert('RGBA').resize((320,320),Image.Resampling.LANCZOS).save(dest)
            p['images'][look]=str(dest)
            p['small'][look]={str(px):str(HERE/'exports'/f'{p["id"]}-{look}-{px}.png') for px in [32,16]}
    (HERE/'gallery-inline.html').write_text(HTML.replace('MANIFEST',json.dumps(palettes)))
    def data(path):
        image=Image.open(path).convert('RGBA');buffer=io.BytesIO();image.save(buffer,format='PNG')
        return 'data:image/png;base64,'+base64.b64encode(buffer.getvalue()).decode()
    for p in palettes:
        p['images']={look:data(path) for look,path in p['images'].items()}
        p['small']={look:{px:data(path) for px,path in sizes.items()} for look,sizes in p['small'].items()}
    (HERE/'gallery.html').write_text(HTML.replace('MANIFEST',json.dumps(palettes)))
    print('Wrote self-contained color comparison gallery')


if __name__=='__main__':main()
