#!/usr/bin/env python3
"""Assemble the two independently developed branding proposals for review."""
from pathlib import Path
import base64
import io
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
BASE=HERE.parent
SOL=BASE/'sol-2026-11-17'
OPUS=BASE/'opus-2026-11-17'
ROOT=BASE.parents[1]
HERE.mkdir(exist_ok=True)
ROUND='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
SANS='/System/Library/Fonts/HelveticaNeue.ttc'


def font(size,bold=False):
    return ImageFont.truetype(ROUND if bold else SANS,size)


def paste(canvas,path,xy,side):
    art=Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS)
    canvas.paste(art,xy,art)


def data(path,maxwidth=1000):
    path=Path(path)
    art=Image.open(path).convert('RGBA')
    if art.width>maxwidth:
        art=art.resize((maxwidth,round(art.height*maxwidth/art.width)),Image.Resampling.LANCZOS)
    buf=io.BytesIO();art.save(buf,format='PNG')
    return 'data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()


def make():
    board=Image.new('RGB',(1500,750),'#F5F5F7');d=ImageDraw.Draw(board)
    d.text((56,35),'Look Here Please',font=font(38,True),fill='#211729')
    d.text((56,94),'Two directions for the app icon and identity',font=font(24),fill='#655D70')
    items=[
        ('Current',ROOT/'design/s024/exports/icon-Default.png','Small glove and separate dot'),
        ('My direction',SOL/'exports/coral-Default-512.png','Soft toy glove. Complete short handle.'),
        ('Opus 5.5 high',OPUS/'exports/icon-Default.png','Graphic glove. Aligned target.'),
    ]
    for i,(name,path,caption) in enumerate(items):
        x=56+i*486
        d.text((x,166),name,font=font(27,True),fill='#211729')
        paste(board,path,(x,214),350)
        for j,px in enumerate([32,16]):
            paste(board,path,(x+j*86,606+(32-px)//2),px)
            d.text((x+j*86+40,614),str(px),font=font(17),fill='#655D70')
        d.text((x,670),caption,font=font(21),fill='#655D70')
    board.save(HERE/'branding-comparison.png')

    html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Look Here Please branding directions</title><style>
*{box-sizing:border-box}body{margin:0;font-family:var(--font-sans,-apple-system,BlinkMacSystemFont,sans-serif);color:var(--foreground,#211729)}.choices{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 18px}button{font:inherit;font-size:14px;border:1px solid var(--border,#DAD6DF);border-radius:10px;padding:10px 14px;background:transparent;color:inherit;cursor:pointer}button[aria-selected="true"]{background:var(--primary,#211729);color:var(--primary-foreground,#fff);border-color:transparent}button:focus-visible{outline:3px solid var(--ring,#F04B32);outline-offset:3px}.panel[hidden]{display:none}.panel h2{font-size:20px;line-height:1.3;margin:0 0 8px}.panel p{font-size:14px;line-height:1.6;color:var(--muted-foreground,#655D70);margin:0 0 18px;max-width:680px}.panel img{display:block;width:100%;height:auto;border-radius:16px}.candidates{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-bottom:20px}.candidates figure{margin:0;background:var(--card,#F5F5F7);border-radius:16px;padding:18px}.candidates img{width:100%;aspect-ratio:1}.candidates figcaption{margin-top:14px;font-size:14px;line-height:1.4;font-weight:600}.note{font-size:12px;line-height:1.5;color:var(--muted-foreground,#655D70);margin:14px 0 0}@media(max-width:450px){.candidates{gap:8px}.candidates figure{padding:10px}.candidates figcaption{font-size:12px}button{padding:9px 11px;font-size:13px}}
</style><body><div class="choices" role="tablist" aria-label="Branding views"><button id="tab-compare" role="tab" aria-controls="compare" aria-selected="true" onclick="show('compare')">Compare icons</button><button id="tab-soft" role="tab" aria-controls="soft" aria-selected="false" onclick="show('soft')">My direction</button><button id="tab-opus" role="tab" aria-controls="opus" aria-selected="false" onclick="show('opus')">Opus 5.5</button><button id="tab-looks" role="tab" aria-controls="looks" aria-selected="false" onclick="show('looks')">Native appearances</button></div>
<section id="compare" class="panel" role="tabpanel" aria-labelledby="tab-compare"><h2>Make the pointing wand the identity.</h2><p>Keep the full name and the coral. Give the glove enough room to be recognized. My pick is the soft toy direction, which feels closest to the app's own pointers.</p><div class="candidates"><figure><img src="CURRENT" alt="Current small cream glove with attention dot"><figcaption>Current</figcaption></figure><figure><img src="SOFT" alt="Proposed larger soft cream glove on a complete short handle"><figcaption>My direction</figcaption></figure><figure><img src="OPUS" alt="Opus's geometric cream glove aiming at an amber target"><figcaption>Opus 5.5 high</figcaption></figure></div><p>Both studies include original vector art, menu bar symbols and broader branding treatments. The tabs show the identity and native icon checks.</p></section>
<section id="soft" class="panel" role="tabpanel" aria-labelledby="tab-soft" hidden><h2>The soft toy direction</h2><p>A complete pointing wand, rounded lettering and one consistent identity across the icon, repository, website and About window.</p><img src="SOFTBOARD" alt="Brand board with rounded wordmark, cream pointing wand, coral and yellow icon variants, menu bar symbols and color palette"></section>
<section id="opus" class="panel" role="tabpanel" aria-labelledby="tab-opus" hidden><h2>Opus's graphic direction</h2><p>A geometric glove and a target on the same diagonal. The oversized hand addresses the current icon's scale; the target makes the pointing action explicit.</p><img src="OPUSBEFORE" alt="Opus's current and proposed native icons at large and small sizes"><img style="margin-top:18px" src="OPUSLOCK" alt="Opus's horizontal pointing glove beside a stacked Look Here Please wordmark"></section>
<section id="looks" class="panel" role="tabpanel" aria-labelledby="tab-looks" hidden><h2>Native icon appearances</h2><p>Compiled locally with Xcode. Default, Dark, TintedLight, TintedDark, ClearLight and ClearDark, with real 32 and 16 pixel renders for the soft toy proposal.</p><img src="LOOKS" alt="Six native appearance treatments of the soft toy icon, with actual and enlarged small-size renders"><p class="note">Finger detail merges at 16 pixels. TintedDark has lower contrast under the system's tint treatment.</p></section><p class="note">Design proposals. The running app and production branding have not been changed.</p>
<script>function show(id){document.querySelectorAll('.panel').forEach(p=>p.hidden=p.id!==id);document.querySelectorAll('[role=tab]').forEach(t=>t.setAttribute('aria-selected',String(t.id==='tab-'+id)));}document.querySelector('[role=tablist]').addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;const tabs=[...document.querySelectorAll('[role=tab]')];let i=tabs.indexOf(document.activeElement);if(i<0)return;e.preventDefault();i=e.key==='Home'?0:e.key==='End'?tabs.length-1:(i+(e.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;tabs[i].focus();tabs[i].click();});</script></body></html>'''
    replacements={
        'CURRENT':ROOT/'design/s024/exports/icon-Default.png',
        'SOFT':SOL/'exports/coral-Default-512.png',
        'OPUS':OPUS/'exports/icon-Default.png',
        'SOFTBOARD':SOL/'exports/brand-direction.png',
        'OPUSBEFORE':OPUS/'exports/before-after.png',
        'OPUSLOCK':OPUS/'exports/lockup-stacked.png',
        'LOOKS':SOL/'exports/native-appearances.png',
    }
    inline=html
    for token,path in replacements.items():
        inline=inline.replace('src="'+token+'"','src="'+str(path)+'"')
    (HERE/'comparison-inline.html').write_text(inline)
    for token,path in sorted(replacements.items(),key=lambda pair:-len(pair[0])):
        html=html.replace('src="'+token+'"','src="'+data(path)+'"')
    (HERE/'comparison.html').write_text(html)
    print('Wrote comparison PNG and self-contained HTML')


if __name__=='__main__':
    make()
