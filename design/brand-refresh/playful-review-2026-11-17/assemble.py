#!/usr/bin/env python3
"""Combine Sol and Opus's eight original-hand icon ideas for review."""
from pathlib import Path
import base64
import io
import json
import textwrap
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
BASE=HERE.parent
SOL=BASE/'playful-sol-2026-11-17'
OPUS=BASE/'playful-opus-2026-11-17'
LOOKS=['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']
ROUND='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
SANS='/System/Library/Fonts/HelveticaNeue.ttc'


def font(size,bold=False):
    return ImageFont.truetype(ROUND if bold else SANS,size)


def paste(canvas,path,x,y,side):
    im=Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS)
    canvas.paste(im,(x,y),im)


def concepts():
    items=[]
    for c in json.loads((SOL/'concepts.json').read_text()):
        items.append({'id':c['id'],'name':c['name'],'by':'Sol','note':c['note'],
            'description':{
                'S1':'My pick for the app icon. The diagonal gives the hand energy, and yellow makes the original lavender stand out.',
                'S2':'The white and purple fingertips meet. A friendly character direction, with both source hands visible.',
                'S3':'A peeled sticky note connects the pointing hand to screen annotations. It can also suggest a notes app.',
                'S4':'A bolder white-hand direction with pink and yellow marker stripes. The background competes with the hand at tiny sizes.',
            }[c['id']],
            'images':{look:str(SOL/'exports'/f'{c["id"]}-{look}-512.png') for look in LOOKS},
            'small':{look:{str(px):str(SOL/'exports'/f'{c["id"]}-{look}-{px}.png') for px in [16,32]} for look in ['Default','Dark']}})
    notes=['The glove makes a magical entrance.','A sideways purple hand pokes a burst.','A white hand points to buried treasure.','The hand becomes a stage puppet.']
    descriptions=[
        "Opus's pick. A magician's hat hides the long stick, and the original white glove rises out of it. The sparkles fade away at small sizes.",
        'A sideways purple hand and a pop-art burst make the pointing action explicit. The hand is an exact quarter-turn of the original.',
        'An upside-down original white hand points to an X on a little island. A playful treasure-map joke, with weaker separation at 16 pixels.',
        'The actual lavender hand appears between stage curtains. A playful theatrical direction; the scene gets busy at 16 pixels.',
    ]
    for i,c in enumerate(json.loads((OPUS/'provenance.json').read_text())):
        stem=c['concept']
        items.append({'id':'O'+str(i+1),'name':c['title'],'by':'Opus 5.5','note':notes[i],
            'description':descriptions[i],
            'images':{look:str(OPUS/'exports'/f'{stem}-{look}-{512 if look in ["Default","Dark"] else 256}.png') for look in LOOKS},
            'small':{look:{str(px):str(OPUS/'exports'/f'{stem}-{look}-{px}.png') for px in [16,32]} for look in ['Default','Dark']}})
    return items


def board(items):
    im=Image.new('RGB',(1920,1420),'#F5F5F7');d=ImageDraw.Draw(im)
    d.text((48,34),"Eight ways to say 'look here'.",font=font(46,True),fill='#211729')
    d.text((48,103),'The actual hand assets. Four ideas from Sol and four from Opus 5.5 high.',font=font(26),fill='#655D70')
    for i,c in enumerate(items):
        x=48+(i%4)*468;y=180+(i//4)*603
        paste(im,c['images']['Default'],x,y,360)
        d.text((x,y+385),c['id']+'  '+c['name'],font=font(28,True),fill='#211729')
        d.text((x,y+428),c['by'],font=font(21),fill='#655D70')
        for j,line in enumerate(textwrap.wrap(c['note'],33)):
            d.text((x,y+465+j*27),line,font=font(21),fill='#655D70')
        for j,px in enumerate([32,16]):
            paste(im,c['small']['Default'][str(px)],x+j*102,y+541+(32-px)//2,px)
            d.text((x+j*102+44,y+547),str(px),font=font(17),fill='#655D70')
    d.text((48,1374),'My shortlist: S1 Lemon pop, O1 Ta-da!, O2 Boop. All eight are native icon concepts.',font=font(24),fill='#211729')
    im.save(HERE/'eight-icon-ideas.png')


HTML='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eight Look Here Please icon ideas</title><style>
*{box-sizing:border-box}body{margin:0;font-family:var(--font-sans,-apple-system,sans-serif);color:var(--foreground,#211729)}.intro{margin:0 0 18px;font-size:15px;line-height:1.6}.controls{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:20px}.controls p{margin:0;color:var(--muted-foreground,#655D70);font-size:13px}.controls label{display:flex;align-items:center;gap:8px;font-size:13px}select{font:inherit;padding:8px;border:1px solid var(--border,#DAD4DF);border-radius:8px;color:inherit;background:var(--card,#fff)}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.idea{font:inherit;text-align:left;padding:12px;border:1px solid transparent;border-radius:16px;background:var(--card,#F5F5F7);color:inherit;cursor:pointer}.idea[aria-pressed=true]{border-color:var(--primary,#6850B8);box-shadow:0 0 0 1px var(--primary,#6850B8)}.idea img{display:block;width:100%;height:auto}.idea strong{display:block;font-size:13px;line-height:1.4;margin-top:10px}.idea span{display:block;font-size:11px;line-height:1.4;margin-top:4px;color:var(--muted-foreground,#655D70)}button:focus-visible,select:focus-visible{outline:3px solid var(--ring,#6850B8);outline-offset:3px}.detail{display:grid;grid-template-columns:260px 1fr;gap:28px;align-items:center;margin-top:28px;padding:24px;background:var(--card,#F5F5F7);border-radius:18px}.large{width:100%;height:auto;display:block}.detail h2{font-size:22px;line-height:1.3;margin:0 0 10px}.detail p{font-size:14px;line-height:1.65;margin:0;color:var(--muted-foreground,#655D70)}.small{display:flex;gap:26px;align-items:center;margin-top:22px}.size{display:flex;align-items:center;gap:9px;font-size:12px;color:var(--muted-foreground,#655D70)}.size img{display:block}.footer{margin:16px 0 0;font-size:12px;line-height:1.6;color:var(--muted-foreground,#655D70)}@media(max-width:550px){.grid{grid-template-columns:repeat(2,1fr)}.controls{align-items:flex-start}.controls p{max-width:150px}.controls label{display:block}.controls select{display:block;margin-top:7px}.detail{grid-template-columns:1fr;padding:20px;gap:20px}.large{width:240px;max-width:100%;margin:auto}.idea strong{font-size:13px}}
</style><body><p class="intro">My pick is <strong>S1 Lemon pop</strong>. Opus's pick is <strong>O1 Ta-da!</strong> Select an idea to see it larger, or switch the native appearance.</p><div class="controls"><p>Actual white and purple hand artwork.</p><label for="look">Appearance <select id="look" onchange="render()"><option>Default</option><option>Dark</option><option>TintedLight</option><option>TintedDark</option><option>ClearLight</option><option>ClearDark</option></select></label></div><div class="grid" id="grid" aria-label="Icon ideas"></div><section class="detail" aria-live="polite"><img class="large" id="large" alt=""><div><h2 id="name"></h2><p id="description"></p><div class="small" id="small"></div></div></section><p class="footer">All eight compile as native Icon Composer icons. Tiny previews in Default and Dark use direct 32 and 16 pixel renders. TintedDark has lower contrast. Concepts only; the running app is unchanged.</p><script>
const ideas=MANIFEST;let selected='S1';const grid=document.getElementById('grid');for(const item of ideas){const b=document.createElement('button');b.type='button';b.className='idea';b.dataset.id=item.id;b.setAttribute('aria-pressed','false');const img=document.createElement('img');img.alt=item.name;const label=document.createElement('strong');label.textContent=item.id+' '+item.name;const by=document.createElement('span');by.textContent=item.by;b.append(img,label,by);b.onclick=()=>{selected=item.id;render();if(window.matchMedia('(max-width:550px)').matches)document.querySelector('.detail').scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth',block:'start'});};grid.appendChild(b);}function render(){const look=document.getElementById('look').value;for(const b of grid.children){const item=ideas.find(x=>x.id===b.dataset.id);b.querySelector('img').src=item.images[look];b.setAttribute('aria-pressed',String(item.id===selected));}const item=ideas.find(x=>x.id===selected);const image=document.getElementById('large');image.src=item.images[look];image.alt=item.name+' in '+look;document.getElementById('name').textContent=item.id+' '+item.name;document.getElementById('description').textContent=item.description;const small=document.getElementById('small');small.replaceChildren();if(item.small[look])for(const px of [32,16]){const wrap=document.createElement('div');wrap.className='size';const image=document.createElement('img');image.src=item.small[look][String(px)];image.width=px;image.height=px;image.alt=px+' pixel native export';const text=document.createElement('span');text.textContent=px+' px';wrap.append(image,text);small.appendChild(wrap);}}render();console.log('Loaded '+ideas.length+' native icon concepts');
</script></body></html>'''


def gallery(items):
    web=HERE/'web';web.mkdir(exist_ok=True)
    compact=[]
    for item in items:
        c=dict(item);c['images']={}
        for look,path in item['images'].items():
            dest=web/f'{item["id"]}-{look}.png'
            Image.open(path).convert('RGBA').resize((320,320),Image.Resampling.LANCZOS).save(dest)
            c['images'][look]=str(dest)
        compact.append(c)
    inline=HTML.replace('MANIFEST',json.dumps(compact))
    (HERE/'gallery-inline.html').write_text(inline)
    portable=[]
    def data(path):
        im=Image.open(path).convert('RGBA');buf=io.BytesIO();im.save(buf,format='PNG')
        return 'data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()
    for item in compact:
        c=dict(item);c['images']={look:data(path) for look,path in item['images'].items()}
        c['small']={look:{px:data(path) for px,path in sizes.items()} for look,sizes in item['small'].items()}
        portable.append(c)
    (HERE/'gallery.html').write_text(HTML.replace('MANIFEST',json.dumps(portable)))
    (HERE/'concepts.json').write_text(json.dumps(items,indent=2)+'\n')


if __name__=='__main__':
    HERE.mkdir(exist_ok=True)
    items=concepts()
    for item in items:
        for path in item['images'].values():assert Path(path).is_file(),path
    board(items)
    gallery(items)
    print('Wrote eight-icon comparison and self-contained interactive gallery')
