#!/usr/bin/env python3
"""Export C11 assets locally. Requires Pillow, fonttools, librsvg and Xcode."""
from pathlib import Path
import base64
import json
import shutil
import subprocess
import tempfile
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets'
DOC=ASSETS/'AppIcon.icon'
EXPORTS=ROOT/'design/s024/exports'
WEB=ROOT/'docs/assets'
GITHUB=ROOT/'.github'
BRAND=json.loads((ASSETS/'brand.json').read_text())
PALETTE=BRAND['palette']
FONT='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
LOOKS=['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']


def svg(body,viewbox='0 0 1024 1024',width=None,height=None):
    size=f' width="{width}" height="{height}"' if width and height else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"{size} viewBox="{viewbox}">{body}</svg>\n'


def body(source):
    return source.split('>',1)[1].rsplit('</svg>',1)[0]


def data(path):
    path=Path(path)
    mime='image/svg+xml' if path.suffix=='.svg' else 'image/png'
    return 'data:'+mime+';base64,'+base64.b64encode(path.read_bytes()).decode()


def render(source,dest,width=None,height=None):
    args=['rsvg-convert',str(source),'-o',str(dest)]
    if width:args+=['-w',str(width)]
    if height:args+=['-h',str(height)]
    subprocess.run(args,check=True)


def wordmark(lines,tint):
    # Outline installed type. Delivered SVGs have no font dependencies.
    face=TTFont(FONT);glyphs=face.getGlyphSet();cmap=face.getBestCmap()
    scale=100/face['head'].unitsPerEm
    paths=[];widest=0
    for row,line in enumerate(lines):
        x=0
        for character in line:
            glyph=cmap[ord(character)];pen=SVGPathPen(glyphs);glyphs[glyph].draw(pen)
            paths.append(f'<path transform="translate({x:.4f} {100+row*114}) scale({scale:.8f} {-scale:.8f})" d="{pen.getCommands()}"/>')
            x+=face['hmtx'][glyph][0]*scale-1.4
        widest=max(widest,x)
    return svg(f'<g fill="{tint}">'+''.join(paths)+'</g>',f'0 15 {widest+4:.3f} {len(lines)*114}')


def native_exports():
    developer=Path(subprocess.check_output(['xcode-select','-p'],text=True).strip())
    ictool=developer.parent/'Applications/Icon Composer.app/Contents/Executables/ictool'
    for look in LOOKS:
        subprocess.run([str(ictool),str(DOC),'--export-image','--output-file',str(EXPORTS/f'icon-{look}.png'),
            '--platform','macOS','--rendition',look,'--width','512','--height','512','--scale','1'],check=True,stdout=subprocess.DEVNULL)
    # Use the real native mask and selected look in repository and browser marks.
    icon=Image.open(EXPORTS/'icon-Default.png').convert('RGBA')
    icon.save(GITHUB/'logo.png')
    for name,side in [('mark-512.png',512),('favicon.png',64),('apple-touch-icon.png',180)]:
        icon.resize((side,side),Image.Resampling.LANCZOS).save(WEB/name)
    (WEB/'mark.svg').write_text(svg(f'<image width="512" height="512" xlink:href="{data(WEB/"mark-512.png")}"/>','0 0 512 512'))
    for name,lines in [('wordmark',['Look Here Please']),('wordmark-stacked',['Look Here','Please'])]:
        (WEB/f'{name}.svg').write_text(wordmark(lines,PALETTE['plum']))
        (WEB/f'{name}-cream.svg').write_text(wordmark(lines,PALETTE['cream']))
    # Preserve the source SVG, including the original embedded PNG, byte for byte.
    shutil.copyfile(DOC/'Assets/hand.svg',WEB/'pointer.svg')
    render(WEB/'pointer.svg',WEB/'pointer.png',768,768)
    return icon


def banner():
    stacked=(WEB/'wordmark-stacked.svg').read_text();art=(WEB/'pointer.svg').read_text()
    viewbox=stacked.split('viewBox="',1)[1].split('"',1)[0]
    image=svg(f'''<rect width="1600" height="800" fill="{PALETTE['cream']}"/>
<svg x="96" y="133" width="690" height="300" viewBox="{viewbox}">{body(stacked)}</svg>
<g font-family="Arial Rounded MT Bold, sans-serif" fill="{PALETTE['purple']}"><text x="100" y="520" font-size="46">{BRAND['tagline']}</text></g>
<g font-family="Helvetica Neue, Helvetica, sans-serif" fill="{PALETTE['plum']}">
<text x="100" y="582" font-size="29">{BRAND['descriptor']}</text>
<text x="100" y="716" font-size="24">{BRAND['byline']}</text></g>
<svg x="820" y="20" width="780" height="780" viewBox="0 0 1024 1024">{body(art)}</svg>''','0 0 1600 800',1600,800)
    (GITHUB/'banner.svg').write_text(image)
    render(GITHUB/'banner.svg',GITHUB/'banner.png')
    banner=Image.open(GITHUB/'banner.png').convert('RGB')
    banner.save(GITHUB/'banner.jpg',quality=94);banner.save(EXPORTS/'banner.png')
    social=Image.new('RGB',(1200,630),PALETTE['cream'])
    social.paste(banner.resize((1200,600),Image.Resampling.LANCZOS),(0,15))
    social.save(WEB/'og-image.png');social.save(WEB/'og-dusk.jpg',quality=94)


def lineup():
    hands=[('lavender','Lavender'),('glove','Cursor glove'),('coral','Coral vinyl'),
           ('robot','Robot'),('plush','Plush'),('neon','Neon')]
    parts=[f'<rect width="1600" height="410" fill="{PALETTE["cream"]}"/>']
    for index,(name,label) in enumerate(hands):
        x=40+index*260
        parts.append(f'<image x="{x}" y="24" width="220" height="280" preserveAspectRatio="xMidYMax meet" xlink:href="{data(WEB/"hands"/(name+".png"))}"/>')
        parts.append(f'<text x="{x+110}" y="356" text-anchor="middle" font-family="Helvetica Neue, Helvetica, sans-serif" font-size="23" fill="{PALETTE["plum"]}">{label}</text>')
    source=WEB/'pointer-lineup.svg';source.write_text(svg(''.join(parts),'0 0 1600 410',1600,410))
    render(source,WEB/'pointer-lineup.png')


def deck(icon):
    # The public presentation checkout may not contain the local plugin leaf.
    dest=ROOT/'streamdeck/branding'
    if not dest.is_dir():return
    for name,side in [('plugin',288),('plugin@2x',576)]:
        icon.resize((side,side),Image.Resampling.LANCZOS).save(dest/(name+'.png'))
    with tempfile.TemporaryDirectory() as tmp:
        shape=Path(tmp)/'hand.png';render(WEB/'pointer.svg',shape,512,512)
        alpha=Image.open(shape).convert('RGBA').getchannel('A')
        mono=Image.new('RGBA',(512,512),'white');mono.putalpha(alpha)
        for name,side in [('category',28),('category@2x',56)]:
            mono.resize((side,side),Image.Resampling.LANCZOS).save(dest/(name+'.png'))


def main():
    for folder in [EXPORTS,WEB,GITHUB]:folder.mkdir(parents=True,exist_ok=True)
    icon=native_exports();banner();lineup();deck(icon)
    print('Exported C11 native looks, repository banner, wordmarks and web/plugin assets.')


if __name__=='__main__':main()
