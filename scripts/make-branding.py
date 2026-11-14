#!/usr/bin/env python3
"""Export owned presentation artwork from the original Icon Composer SVG layers.
Requires Pillow, librsvg and Xcode's Icon Composer. No network or publication.
"""
from pathlib import Path
import json
import subprocess
import tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
DOC = ASSETS / 'AppIcon.icon'
EXPORTS = ROOT / 'design/s024/exports'


def render(svg, path, side=None):
    args = ['rsvg-convert', str(svg), '-o', str(path)]
    if side: args += ['-w', str(side), '-h', str(side)]
    subprocess.run(args, check=True)


def main():
    EXPORTS.mkdir(parents=True, exist_ok=True)
    developer = subprocess.check_output(['xcode-select', '-p'], text=True).strip()
    ictool = str(Path(developer).parent / 'Applications/Icon Composer.app/Contents/Executables/ictool')
    for look in ['Default', 'Dark', 'TintedLight', 'TintedDark', 'ClearLight', 'ClearDark']:
        subprocess.run([ictool, str(DOC), '--export-image', '--output-file', str(EXPORTS / f'icon-{look}.png'),
                        '--platform', 'macOS', '--rendition', look, '--width', '512', '--height', '512', '--scale', '1'], check=True)
    # Flat companion for browser favicons and monochrome host category icons.
    doc = json.loads((DOC / 'icon.json').read_text())
    shapes = []
    for layer in reversed(doc['groups'][0]['layers']):
        source = (DOC / 'Assets' / layer['image-name']).read_text()
        body = source.split('>', 1)[1].rsplit('</svg>', 1)[0]
        color = {'front.svg': '#fff2d6', 'back.svg': '#47293d', 'attention.svg': '#ffcc75'}[layer['image-name']]
        shapes.append(body.replace('#fff', color))
    flat = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" rx="224" fill="#e64029"/>' + ''.join(shapes) + '</svg>\n'
    (ROOT / 'docs/assets/mark.svg').write_text(flat)
    icon = Image.open(ASSETS / 'AppIcon.icns').convert('RGBA')
    icon.save(ROOT / '.github/logo.png')
    for name, side in [('mark-512.png',512),('favicon.png',64),('apple-touch-icon.png',180)]:
        icon.resize((side,side), Image.Resampling.LANCZOS).save(ROOT / 'docs/assets' / name)
    deck = ROOT / 'streamdeck/branding'; deck.mkdir(exist_ok=True)
    for name, side in [('plugin',288),('plugin@2x',576)]:
        icon.resize((side,side), Image.Resampling.LANCZOS).save(deck / (name + '.png'))
    with tempfile.TemporaryDirectory() as temp:
        white = flat[flat.index('/>')+2:].rsplit('</svg>',1)[0]
        white = white.replace('#fff2d6','#fff').replace('#47293d','#fff').replace('#ffcc75','#fff')
        mono=Path(temp)/'category.svg';mono.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="240 110 620 730">'+white+'</svg>')
        for name,side in [('category',28),('category@2x',56)]:render(mono,deck/(name+'.png'),side)
    # Repository banner, kept in editable vector form too.
    banner = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="800" viewBox="0 0 1600 800">
<rect width="1600" height="800" fill="#fff4df"/>
<g fill="#47293d" font-family="Helvetica Neue, Helvetica, sans-serif">
<text x="100" y="130" font-size="30" font-weight="500" letter-spacing="1">LOOK HERE PLEASE</text>
<text x="92" y="342" font-size="126" font-weight="700" letter-spacing="-5">Point it out.</text>
<text x="100" y="434" font-size="33">A playful pointer for your Mac.</text>
<text x="100" y="665" font-size="26">By Austin Presley</text>
<text x="100" y="710" font-size="22" fill="#795a65">Hands + laser · Annotations · Quick controls · Stream Deck</text>
</g><svg x="1020" y="155" width="480" height="480" viewBox="0 0 1024 1024">{flat.split('>',1)[1].rsplit('</svg>',1)[0]}</svg></svg>'''
    (ROOT / '.github/banner.svg').write_text(banner + '\n')
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp)/'banner.png';render(ROOT/'.github/banner.svg',path)
        Image.open(path).convert('RGB').save(ROOT/'.github/banner.jpg', quality=94)
        Image.open(path).save(EXPORTS/'banner.png')
    Image.open(ROOT/'.github/banner.jpg').save(ROOT/'docs/assets/og-dusk.jpg', quality=94)
    print('Exported app looks, repository banner/logo, site marks and Stream Deck identity')


if __name__ == '__main__': main()
