#!/usr/bin/env python3
"""Hand-drawn vector icon study for Look Here Please.

Draws the pointer (glove on a stick) from primitives in an upright local frame,
then places it on the 1024 canvas. Writes Icon Composer documents plus flat
previews. Requires rsvg-convert and Xcode's Icon Composer (ictool).
"""
from pathlib import Path
import json, subprocess, sys

HERE = Path(__file__).resolve().parent
OUT = HERE / 'out'

CORAL = '#E8472B'; PLUM = '#3A1F31'; CREAM = '#FFF3DC'; CREAM_HI = '#FFFAEE'
CREAM_LO = '#F0D8B4'; INK = '#24121D'; AMBER = '#FFC65C'


def cap(x, y, w, h, r=None):
    r = min(w, h) / 2 if r is None else r
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}"/>'


# Upright pointer, finger up. Local units; origin arbitrary.
PARTS = {
    # index finger and fist read as one glove shape
    # index finger and fist as one outline, with a soft web where they meet
    'glove': [
        '<path d="M326 196 A86 86 0 0 1 498 196 L498 366 C498 396 532 400 566 402 '
        'C652 410 720 484 720 580 L720 600 A180 180 0 0 1 540 780 L460 780 A180 180 0 0 1 280 600 '
        'L280 580 C280 528 300 486 326 458 Z"/>',
    ],
    # three folded fingers, facing the viewer
    'fingers': [
        cap(452, 430, 262, 114),
        cap(460, 550, 278, 108),
        cap(468, 664, 230, 98),
    ],
    'cuff': [cap(296, 742, 408, 134)],
    'stick': [cap(447, 830, 106, 700)],
}


def placed(shapes, tf):
    out = []
    for s in shapes:
        for tag in ('<rect ', '<path '):
            s = s.replace(tag, f'{tag}transform="{tf}" ')
        out.append(s)
    return ''.join(out)


def svg(body, fill=None):
    g = f'<g fill="{fill}">{body}</g>' if fill else body
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{g}</svg>\n'


def transform(angle, scale, tx, ty, pivot=(500, 600)):
    return f'translate({tx} {ty}) rotate({angle}) scale({scale}) translate({-pivot[0]} {-pivot[1]})'


def flat(name, tf, bg=CORAL, extra_back='', tile=True, lo=CREAM_LO):
    """Flat preview: what the mark looks like with no system glass."""
    drop = 'translate(9 13) ' + tf
    body = (f'<rect width="1024" height="1024" rx="{230 if tile else 0}" fill="{bg}"/>' + extra_back
            + f'<g fill="{INK}">{placed(PARTS["stick"], tf)}</g>'
            + f'<g fill="{lo}">{placed(PARTS["cuff"], tf)}</g>'
            + f'<g fill="{CREAM}">{placed(PARTS["glove"], tf)}</g>'
            + ''.join(f'<g fill="{lo}">{placed([f], drop)}</g><g fill="{CREAM_HI}">{placed([f], tf)}</g>'
                      for f in reversed(PARTS["fingers"])))
    p = OUT / f'{name}-flat.svg'
    p.write_text(svg(body))
    subprocess.run(['rsvg-convert', str(p), '-w', '512', '-h', '512', '-o', str(OUT / f'{name}-flat.png')], check=True)


def srgb(hexv, a=1.0):
    h = hexv.lstrip('#')
    if len(h) == 8:
        a = int(h[6:8], 16) / 255
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f'srgb:{r:.5f},{g:.5f},{b:.5f},{a:.5f}'


def ictool():
    dev = subprocess.check_output(['xcode-select', '-p'], text=True).strip()
    return str(Path(dev).parent / 'Applications/Icon Composer.app/Contents/Executables/ictool')


def icon_doc(name, tf, groups, bg, bg_dark=None):
    """groups: list (top first) of (group name, [(layer name, part key, light hex, dark hex)], shadow opacity)."""
    doc = OUT / name / 'AppIcon.icon'
    (doc / 'Assets').mkdir(parents=True, exist_ok=True)
    out_groups = []
    for gname, layers, shadow in groups:
        ls = []
        for lname, shapes, light, dark, *rest in layers:
            glass = rest[0] if rest else True
            tinted = rest[1] if len(rest) > 1 else '#ffffff'
            fn = f'{lname}.svg'
            (doc / 'Assets' / fn).write_text(svg(placed(shapes, tf) if tf else ''.join(shapes), '#fff'))
            ls.append({'image-name': fn, 'name': lname, 'glass': glass,
                       'fill-specializations': [{'value': {'solid': srgb(light)}},
                                                {'appearance': 'dark', 'value': {'solid': srgb(dark or light)}},
                                                {'appearance': 'tinted', 'value': {'solid': srgb(tinted)}}]})
        out_groups.append({'name': gname, 'layers': ls, 'shadow': {'kind': 'neutral', 'opacity': shadow},
                           'translucency': {'enabled': False, 'value': 0.5}})
    fills = [{'value': {'automatic-gradient': srgb(bg)}}]
    if bg_dark:
        fills.append({'appearance': 'dark', 'value': {'automatic-gradient': srgb(bg_dark)}})
    (doc / 'icon.json').write_text(json.dumps({'groups': out_groups, 'supported-platforms': {'squares': ['macOS']},
                                               'fill-specializations': fills}, indent=2))
    return doc


def render(doc, name, looks=('Default',), side=512):
    for look in looks:
        subprocess.run([ictool(), str(doc), '--export-image', '--output-file', str(OUT / f'{name}-{look}.png'),
                        '--platform', 'macOS', '--rendition', look, '--width', str(side), '--height', str(side),
                        '--scale', '1'], check=True, stdout=subprocess.DEVNULL)


DISC = ['<circle cx="716" cy="262" r="196"/>']


def pointer_groups(disc=None):
    """disc: None, or (light hex+alpha, dark hex+alpha) for a pool of light behind the fingertip."""
    extra = [('Light', [('light', DISC, disc[0], disc[1], False, '#FFFFFF38')], 0.0)] if disc else []
    return [
        ('Folded fingers', [('fingers', PARTS['fingers'], CREAM_HI, None)], 0.45),
        ('Glove', [('glove', PARTS['glove'], CREAM, None)], 0.5),
        ('Cuff', [('cuff', PARTS['cuff'], CREAM_LO, None)], 0.45),
        ('Stick', [('stick', PARTS['stick'], INK, CORAL)], 0.5),
    ] + extra


def menubar(state):
    """Template glyph: same pointer, one colour, with a clear gap around the cuff.
    Off shows a ring past the fingertip, On fills it."""
    tf = transform(45, 0.95, 480, 600)
    stick = [cap(447, 830, 106, 200)]
    cuff = placed(PARTS['cuff'], tf)
    gap = cuff.replace('<rect ', '<rect stroke="#000" stroke-width="84" ')
    dot = ('<circle cx="836" cy="126" r="60"/>' if state == 'on' else
           '<path fill-rule="evenodd" d="M896 126 A60 60 0 1 1 776 126 A60 60 0 1 1 896 126 Z '
           'M866 126 A30 30 0 1 0 806 126 A30 30 0 1 0 866 126 Z"/>')
    body = (f'<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">'
            f'<rect width="1024" height="1024" fill="#fff"/><g fill="#000">{gap}</g></mask></defs>'
            f'<g fill="#000"><g mask="url(#m)">{placed(PARTS["glove"] + PARTS["fingers"] + stick, tf)}</g>{cuff}{dot}</g>')
    p = OUT / f'menubar-{state}.svg'
    p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="83 58 880 880">{body}</svg>\n')
    for px in (18, 36, 54, 144):
        subprocess.run(['rsvg-convert', str(p), '-w', str(px), '-h', str(px), '-o', str(OUT / f'menubar-{state}-{px}.png')], check=True)


def pointer_art():
    """Upright flat pointer with a long stick, no tile: for banners and the site."""
    drop = 'translate(10 12)'
    def at(shapes, tf=None):
        return placed(shapes, tf) if tf else ''.join(shapes)
    body = (f'<g fill="{INK}">{cap(447, 830, 106, 1500)}</g>'
            f'<g fill="{CREAM_LO}">{at(PARTS["cuff"])}</g>'
            f'<g fill="#E4C79C">{at(PARTS["glove"], drop)}</g>'
            f'<g fill="{CREAM}">{at(PARTS["glove"])}</g>'
            + ''.join(f'<g fill="{CREAM_LO}">{at([f], drop)}</g><g fill="{CREAM_HI}">{f}</g>'
                      for f in reversed(PARTS["fingers"])))
    (OUT / 'pointer.svg').write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="240 90 540 2260">{body}</svg>\n')


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    looks = sys.argv[1:] or ['Default']
    tf = transform(40, 0.9, 560, 560)
    flat('v1', tf)
    variants = {
        'v1': None,                                   # hand only
        'v2': ('#FFC65C00', '#F4B94AFF'),             # light appears in dark mode only
        'v3': ('#FF8A4FFF', '#F4B94AFF'),             # pool of light in both
    }
    for name, disc in variants.items():
        doc = icon_doc(name, tf, pointer_groups(disc), CORAL, PLUM)
        render(doc, name, looks)
    menubar('off'); menubar('on'); pointer_art()
    print('ok')
