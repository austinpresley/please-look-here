#!/usr/bin/env python3
"""Build a local branding proposal. Production files are never written.

Requires Pillow, librsvg, Xcode and Icon Composer. The glove develops the
project's original vector study in ../vector/build.py. All geometry is here.
"""
from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / 'exports'
OUT.mkdir(exist_ok=True)
COLORS = dict(coral='#F04B32', cream='#FFF5E6', ink='#211729', butter='#F6C84A', paper='#F5F5F7')
DEV = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip())
ICTOOL = DEV.parent / 'Applications/Icon Composer.app/Contents/Executables/ictool'
ROUNDED = '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
REGULAR = '/System/Library/Fonts/HelveticaNeue.ttc'


def cap(x, y, w, h, r=None):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r if r is not None else min(w,h)/2}"/>'


PARTS = {
    'hand': '<path d="M326 196 A86 86 0 0 1 498 196 L498 366 C498 396 532 400 566 402 C652 410 720 484 720 580 L720 600 A180 180 0 0 1 540 780 L460 780 A180 180 0 0 1 280 600 L280 580 C280 528 300 486 326 458 Z"/>',
    'fingers': cap(452,430,262,114) + cap(460,550,278,108) + cap(468,664,230,98),
    'cuff': cap(296,742,408,134),
    'stick': cap(447,830,106,420),
}
# Keep the complete toy in the tile, with a substantial hand and a short handle.
TF = 'translate(548 480) rotate(38) scale(.84) translate(-500 -600)'


def svg(body, viewbox='0 0 1024 1024'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}">{body}</svg>\n'


def color(hexv):
    h = hexv.lstrip('#')
    return 'srgb:' + ','.join(f'{int(h[i:i+2],16)/255:.5f}' for i in (0,2,4)) + ',1.00000'


def paint(part, tint, transform=TF):
    return f'<g transform="{transform}" fill="{tint}">{PARTS[part]}</g>'


def document(name, background):
    doc = HERE / name / 'AppIcon.icon'
    (doc / 'Assets').mkdir(parents=True, exist_ok=True)
    groups = []
    for name, parts, light, dark, shadow in [
        ('Fingers', ['fingers'], '#FFFBF2', '#FFFBF2', .23),
        ('Glove', ['hand','cuff'], COLORS['cream'], COLORS['cream'], .28),
        ('Handle', ['stick'], COLORS['ink'], COLORS['coral'], .20),
    ]:
        filename = name.lower() + '.svg'
        (doc / 'Assets' / filename).write_text(svg(f'<g transform="{TF}" fill="#fff">' + ''.join(PARTS[p] for p in parts) + '</g>'))
        layer = {'name': name, 'image-name': filename, 'glass': True,
            'fill-specializations': [
                {'value': {'solid': color(light)}},
                {'appearance': 'dark', 'value': {'solid': color(dark)}},
                {'appearance': 'tinted', 'value': {'solid': color('#FFFFFF')}}]}
        groups.append({'name': name, 'layers': [layer], 'shadow': {'kind':'neutral','opacity':shadow},
                       'translucency': {'enabled':False,'value':.5}})
    (doc / 'icon.json').write_text(json.dumps({'groups':groups,
        'fill-specializations': [
            {'value': {'automatic-gradient': color(background)}},
            {'appearance':'dark','value':{'automatic-gradient':color(COLORS['ink'])}}],
        'supported-platforms':{'squares':['macOS']}}, indent=2) + '\n')
    return doc


def export(doc, prefix):
    compiled = doc.parent / 'compiled'
    compiled.mkdir(exist_ok=True)
    subprocess.run(['xcrun','actool',str(doc),'--compile',str(compiled),
        '--output-partial-info-plist',str(compiled/'partial.plist'),'--app-icon','AppIcon',
        '--include-all-app-icons','--enable-on-demand-resources','NO','--development-region','en',
        '--target-device','mac','--platform','macosx','--minimum-deployment-target','13.0'],
        check=True, stdout=subprocess.DEVNULL)
    assert (compiled / 'Assets.car').stat().st_size > 0
    for appearance in ['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']:
        for px in ([512,32,16] if prefix == 'coral' else [512]):
            subprocess.run([str(ICTOOL),str(doc),'--export-image','--output-file',str(OUT/f'{prefix}-{appearance}-{px}.png'),
                '--platform','macOS','--rendition',appearance,'--width',str(px),'--height',str(px),'--scale','1'],
                check=True, stdout=subprocess.DEVNULL)


def menu():
    # Optical reduction: remove the sculpted finger detail, split cuff with a gap.
    tf = 'translate(500 485) rotate(38) scale(.81) translate(-500 -600)'
    shape = (f'<g transform="{tf}"><g mask="url(#cut)">{PARTS["stick"]}{PARTS["hand"]}{PARTS["fingers"]}</g>{PARTS["cuff"]}</g>')
    cut = '<defs><mask id="cut"><rect x="0" y="0" width="1600" height="1600" fill="white"/><rect x="268" y="716" width="464" height="188" rx="94" fill="black"/></mask></defs>'
    for state in ['off','on']:
        dot = '<circle cx="782" cy="124" r="54"/>' if state == 'on' else '<path fill-rule="evenodd" d="M836 124 A54 54 0 1 1 728 124 A54 54 0 1 1 836 124 Z M807 124 A25 25 0 1 0 757 124 A25 25 0 1 0 807 124 Z"/>'
        path = HERE / f'menubar-{state}.svg'
        path.write_text(svg(cut+f'<g fill="black">{shape}{dot}</g>', '60 0 860 1024'))
        for scale in [1,2,3]:
            subprocess.run(['rsvg-convert',str(path),'-w',str(18*scale),'-h',str(18*scale),'-o',str(OUT/f'menubar-{state}-{scale}x.png')],check=True)
    # Standalone illustration for web and banners, deliberately no app-icon mask.
    (HERE / 'pointer.svg').write_text(svg(''.join(paint(p,c) for p,c in [
        ('stick',COLORS['ink']),('cuff','#E7CEAA'),('hand',COLORS['cream']),('fingers','#FFFBF2')])) )


def wordmarks():
    """Outline type so the delivered wordmark never depends on a local font."""
    face = TTFont(ROUNDED)
    glyphs = face.getGlyphSet()
    cmap = face.getBestCmap()
    size = 100
    scale = size / face['head'].unitsPerEm
    for name,lines in [('wordmark',['Look Here Please']),('wordmark-stacked',['Look Here','Please'])]:
        paths=[]; widest=0
        for row,line in enumerate(lines):
            x=0
            for char in line:
                glyph=cmap[ord(char)]
                pen=SVGPathPen(glyphs)
                glyphs[glyph].draw(pen)
                paths.append(f'<path transform="translate({x:.4f} {size+row*114}) scale({scale:.8f} {-scale:.8f})" d="{pen.getCommands()}"/>')
                x += face['hmtx'][glyph][0]*scale-1.4
            widest=max(x,widest)
        body=''.join(paths)
        for suffix,tint in [('',COLORS['ink']),('-cream',COLORS['cream'])]:
            (HERE / f'{name}{suffix}.svg').write_text(svg(f'<g fill="{tint}">{body}</g>',f'0 15 {widest+4:.3f} {len(lines)*114}'))


def web_preview():
    """An editable visual treatment, not a published site or functioning app."""
    import base64, io
    def data(path):
        path=Path(path)
        mime='image/svg+xml' if path.suffix=='.svg' else 'image/png'
        if mime == 'image/png':
            buffer=io.BytesIO()
            Image.open(path).convert('RGBA').resize((160,160),Image.Resampling.LANCZOS).save(buffer,format='PNG')
            payload=buffer.getvalue()
        else:
            payload=path.read_bytes()
        return 'data:'+mime+';base64,'+base64.b64encode(payload).decode()
    html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Look Here Please identity preview</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;background:#F5F5F7;color:#211729}.site{border-radius:24px;overflow:hidden;background:#fff}.site header{padding:24px 32px;display:flex;justify-content:space-between;align-items:center;gap:24px}.logo{width:210px;max-width:65%}.site header span{font-size:13px;color:#62596E}.hero{background:#F04B32;color:#FFF5E6;padding:48px;display:grid;grid-template-columns:1.1fr 1fr;align-items:center;gap:8px}.hero .wordmark{width:100%;max-width:380px}.hero h1{font-family:'Arial Rounded MT Bold',sans-serif;font-size:30px;margin:28px 0 12px}.hero p{color:#211729;font-size:17px;line-height:1.6;max-width:330px;margin:0}.hero .pointer{width:100%;filter:drop-shadow(8px 15px 4px #952c2720)}.sub{padding:28px 32px;display:flex;gap:30px;justify-content:space-between;align-items:center}.sub strong{font-size:18px}.sub p{font-size:14px;line-height:1.6;margin:7px 0 0;max-width:420px}.tag{flex-shrink:0;border:1px solid #D4CED8;border-radius:30px;font-size:13px;padding:9px 14px}.application{padding:32px;margin-top:24px;border-radius:24px;background:#E5E2E9}.about{background:#FAFAFB;border:1px solid #CCC6D3;border-radius:12px;padding:30px;max-width:580px;margin:0 auto;box-shadow:0 12px 30px #21172915}.window-bar{display:flex;gap:6px;margin-bottom:32px}.window-bar i{width:10px;height:10px;border-radius:50%;background:#D6D0DA}.about-main{display:flex;gap:20px;align-items:center}.about-main img{width:94px;height:94px}.about h2{font-size:21px;margin:0 0 6px}.about p{font-size:13px;color:#685F73;line-height:1.6;margin:4px 0}.about footer{border-top:1px solid #DED9E3;margin-top:24px;padding-top:20px}.caption{margin:20px 0 0;font-size:12px;color:#62596E;line-height:1.6;text-align:center}@media(max-width:560px){.hero{padding:28px;grid-template-columns:1fr}.hero .pointer{width:75%;margin:-8px 0 0 auto}.hero .wordmark{width:85%}.site header{padding:20px}.sub{display:block;padding:24px}.tag{display:inline-block;margin-top:18px}.application{padding:20px}.about{padding:20px}.about-main{gap:12px}.about-main img{width:72px;height:72px}.about h2{font-size:17px}}
</style><body><section class="site" aria-label="Website concept"><header><img class="logo" src="WORDMARK" alt="Look Here Please"><span>By Austin Presley</span></header><main class="hero"><div><img class="wordmark" src="STACKED" alt="Look Here Please"><h1>Point it out.</h1><p>Put a pointer where it matters.<br>Draw on screen as you explain.</p></div><img class="pointer" src="POINTER" alt="Cream pointing glove on a dark handle"></main><div class="sub"><div><strong>A little help with the explaining.</strong><p>Choose a hand or laser. Add arrows, highlights and notes. Keep the controls close to your cursor.</p></div><span class="tag">For Mac</span></div></section><section class="application" aria-label="About window treatment"><div class="about"><div class="window-bar" aria-hidden="true"><i></i><i></i><i></i></div><div class="about-main"><img src="APPICON" alt="Proposed application icon"><div><h2>Look Here Please</h2><p>Pointers and screen annotations for Mac.</p><p>By Austin Presley</p></div></div><footer><p>Based on TinyHand by Kamran Ahmed. MIT license.</p></footer></div><p class="caption">Website and About layout studies. The app keeps native system typography.<br>Existing version, update controls, links and credits remain required in implementation.</p></section></body></html>'''
    for token,path in [('WORDMARK',HERE/'wordmark.svg'),('STACKED',HERE/'wordmark-stacked-cream.svg'),('POINTER',HERE/'pointer.svg'),('APPICON',OUT/'coral-Default-512.png')]:
        html=html.replace(token,data(path))
    (HERE / 'identity-preview.html').write_text(html)


def font(size, bold=False):
    return ImageFont.truetype(ROUNDED if bold else REGULAR, size)


def place(canvas, path, xy, size):
    im = Image.open(path).convert('RGBA').resize((size,size), Image.Resampling.LANCZOS)
    canvas.paste(im,xy,im)


def sheets():
    sheet = Image.new('RGB',(1600,700),COLORS['paper'])
    d = ImageDraw.Draw(sheet)
    for i,look in enumerate(['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']):
        x=i%3*534; y=i//3*350
        dark='Dark' in look
        bg = '#272330' if dark else COLORS['paper']
        fg = '#FFFFFF' if dark else COLORS['ink']
        d.rectangle((x,y,x+533,y+349),fill=bg)
        d.text((x+24,y+18),look,font=font(22,True),fill=fg)
        place(sheet,OUT/f'coral-{look}-512.png',(x+22,y+64),250)
        for px,yy in [(32,105),(16,210)]:
            d.text((x+312,y+yy-30),f'{px} px',font=font(18),fill=fg)
            place(sheet,OUT/f'coral-{look}-{px}.png',(x+312,y+yy),px)
            im=Image.open(OUT/f'coral-{look}-{px}.png').convert('RGBA').resize((px*3,px*3),Image.Resampling.NEAREST)
            sheet.paste(im,(x+388,y+yy),im)
    sheet.save(OUT/'native-appearances.png')

    board = Image.new('RGB',(1600,1320),COLORS['paper'])
    d=ImageDraw.Draw(board)
    d.text((70,48),'Look Here Please',font=font(39,True),fill=COLORS['ink'])
    d.text((70,107),'A bigger personality for a little Mac utility.',font=font(25),fill='#655D70')
    d.rounded_rectangle((64,173,1536,800),radius=38,fill=COLORS['coral'])
    d.text((116,242),'Look Here',font=font(105,True),fill=COLORS['cream'])
    d.text((116,358),'Please',font=font(105,True),fill=COLORS['cream'])
    d.text((119,526),'Point it out.',font=font(36,True),fill=COLORS['cream'])
    d.text((119,592),'Pointers and screen annotations for Mac.',font=font(25),fill=COLORS['ink'])
    d.text((119,720),'By Austin Presley',font=font(22),fill=COLORS['ink'])
    place(board,OUT/'coral-Default-512.png',(892,226),516)
    d.text((70,853),'Current',font=font(23,True),fill=COLORS['ink'])
    place(board,ROOT/'design/s024/exports/icon-Default.png',(62,894),160)
    d.text((259,853),'Proposed',font=font(23,True),fill=COLORS['ink'])
    place(board,OUT/'coral-Default-512.png',(250,894),160)
    d.text((469,853),'Alternate color',font=font(23,True),fill=COLORS['ink'])
    place(board,OUT/'butter-Default-512.png',(470,894),160)
    d.text((703,853),'A mark made for the menu bar',font=font(23,True),fill=COLORS['ink'])
    for i,(bg,fg) in enumerate([('#FFFFFF','#18131F'),('#211729','#FFFFFF')]):
        x=704+i*398
        d.rounded_rectangle((x,904,x+365,968),radius=14,fill=bg)
        for j,state in enumerate(['off','on']):
            im=Image.open(OUT/f'menubar-{state}-2x.png').convert('RGBA')
            tint=Image.new('RGBA',im.size,fg);tint.putalpha(im.getchannel('A'))
            board.paste(tint,(x+22+j*160,917),tint)
            d.text((x+70+j*160,925),state.capitalize(),font=font(20),fill=fg)
    d.text((705,997),'Original silhouette, simplified at 18 pt.',font=font(22),fill='#655D70')
    for i,(name,hexv) in enumerate(COLORS.items()):
        x=70+i*298
        d.rounded_rectangle((x,1111,x+270,1181),radius=14,fill=hexv,outline='#DAD7DF',width=1)
        d.text((x,1196),name.capitalize()+'  '+hexv,font=font(20),fill=COLORS['ink'])
    d.text((70,1264),'Branding study. Original vector art. Native Icon Composer rendering. Not installed.',font=font(20),fill='#655D70')
    board.save(OUT/'brand-direction.png')


def companion_assets():
    im=Image.open(OUT/'coral-Default-512.png').convert('RGBA')
    for name,px in [('favicon',64),('apple-touch-icon',180),('streamdeck-plugin',288),('streamdeck-plugin@2x',576)]:
        im.resize((px,px),Image.Resampling.LANCZOS).save(OUT/f'{name}.png')
    for name,px in [('streamdeck-category',28),('streamdeck-category@2x',56)]:
        subprocess.run(['rsvg-convert',str(HERE/'menubar-on.svg'),'-w',str(px),'-h',str(px),'-o',str(OUT/f'{name}.png')],check=True)
    banner=Image.new('RGB',(1600,800),COLORS['coral'])
    d=ImageDraw.Draw(banner)
    d.text((95,158),'Look Here',font=font(114,True),fill=COLORS['cream'])
    d.text((95,286),'Please',font=font(114,True),fill=COLORS['cream'])
    d.text((98,478),'Point it out.',font=font(40,True),fill=COLORS['cream'])
    d.text((98,548),'Pointers and screen annotations for Mac.',font=font(27),fill=COLORS['ink'])
    d.text((98,697),'By Austin Presley',font=font(24),fill=COLORS['ink'])
    place(banner,OUT/'coral-Default-512.png',(950,136),530)
    banner.save(OUT/'repository-banner.png')


if __name__ == '__main__':
    export(document('coral', COLORS['coral']), 'coral')
    export(document('butter', COLORS['butter']), 'butter')
    menu()
    wordmarks()
    web_preview()
    sheets()
    companion_assets()
    print('Built native icons, optical menu symbols and brand boards in', HERE)
