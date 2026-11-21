#!/usr/bin/env python3
"""Four playful Look Here Please icon concepts built around the ORIGINAL hand PNGs.

Run:  python3 -I tools/build.py   (from anywhere; stdlib only + Xcode actool + Icon Composer ictool
      + swiftc + rsvg-convert, all already on Austin's Mac)

Hand handling:
  - ta-da      : assets/hand_glove.png copied byte-for-byte.
  - boop       : assets/hand_lavender.png, exact 90-degree pixel remap (no resampling; verified).
  - x-marks    : assets/hand_glove.png, exact 180-degree pixel remap (no resampling; verified).
  - puppet     : assets/hand_lavender.png, rotated -12 degrees with CoreGraphics high-quality
                 resampling (the one resampled derivative; labelled as such).
Icon Composer has no rotation property, so a rotated hand must be a rotated copy of the raster.
Props (hat, burst, map, stage) are original SVG drawn here. No text, no SF Symbols.
"""
from pathlib import Path
import hashlib, json, math, random, shutil, subprocess, sys, tempfile

HERE = Path(__file__).resolve().parent.parent
ROOT = HERE.parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE / 'tools'))
import pngraw  # noqa: E402

OUT = HERE / 'exports'
DEV = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip())
ICTOOL = DEV.parent / 'Applications/Icon Composer.app/Contents/Executables/ictool'
TMP = Path(tempfile.mkdtemp(prefix='lhp-playful-'))
KIT = TMP / 'rasterkit'
LOOKS = ['Default', 'Dark', 'TintedLight', 'TintedDark', 'ClearLight', 'ClearDark']


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def color(h, a=1.0):
    return 'srgb:' + ','.join(f'{int(h[i:i+2], 16)/255:.5f}' for i in (1, 3, 5)) + f',{a:.5f}'


def svg(body, defs=''):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
            f'<defs>{defs}</defs>{body}</svg>\n')


def place(img_w, img_h, scale, src_pt, dst_pt):
    """Icon Composer maps image px (ix,iy) to canvas pt: 512 + s*(ix - W/2) + tx (same for y)."""
    return [round(dst_pt[0] - 512 - scale * (src_pt[0] - img_w / 2), 2),
            round(dst_pt[1] - 512 - scale * (src_pt[1] - img_h / 2), 2)]


def rotate_point(p, deg, w, h, nw, nh):
    """Clockwise visual rotation about the image centre, y-down coordinates (matches rasterkit tilt)."""
    t = math.radians(deg); x, y = p[0] - w / 2, p[1] - h / 2
    return (x * math.cos(t) - y * math.sin(t) + nw / 2, x * math.sin(t) + y * math.cos(t) + nh / 2)


# Landmarks measured from the alpha channel of the untouched originals (tools/pngraw.alpha_bbox + row scan).
MARKS = {
    'hand_glove.png':    {'tip': (470, 144), 'cuff': (525, 700), 'handle_x': 525},
    'hand_lavender.png': {'tip': (473, 118), 'cuff': (526, 705), 'handle_x': 526},
}


# ---------------------------------------------------------------- props (original SVG)

def sparkle(cx, cy, r, fill):
    k = r * 0.16
    return (f'<path fill="{fill}" d="M{cx},{cy-r} C{cx+k},{cy-k} {cx+k},{cy-k} {cx+r},{cy} '
            f'C{cx+k},{cy+k} {cx+k},{cy+k} {cx},{cy+r} C{cx-k},{cy+k} {cx-k},{cy+k} {cx-r},{cy} '
            f'C{cx-k},{cy-k} {cx-k},{cy-k} {cx},{cy-r} Z"/>')


def burst(cx, cy, r_out, r_in, n, seed, fill, rot=0):
    rnd = random.Random(seed); pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = (r_out * rnd.uniform(0.86, 1.0)) if i % 2 == 0 else (r_in * rnd.uniform(0.92, 1.05))
        pts.append(f'{cx + r*math.cos(a):.1f},{cy + r*math.sin(a):.1f}')
    return f'<polygon fill="{fill}" stroke-linejoin="round" points="{" ".join(pts)}"/>'


def concept_tada():
    # Upside-down magician's top hat; the original white glove rises out of it. Opening centred (512, 742).
    oy, orx, ory = 742, 196, 48
    back = svg(
        f'<ellipse cx="512" cy="{oy}" rx="300" ry="78" fill="#15121C"/>'          # brim (back half shows)
        f'<ellipse cx="512" cy="{oy-4}" rx="300" ry="74" fill="#2A2533"/>'
        f'<ellipse cx="512" cy="{oy}" rx="{orx}" ry="{ory}" fill="#050407"/>')      # opening interior
    front = svg(
        # crown hanging below the brim, slight flare, with satin highlight and red band
        f'<path fill="#16131D" d="M{512-orx},{oy} L{512-orx-22},1060 L{512+orx+22},1060 L{512+orx},{oy} '
        f'A{orx},{ory} 0 0 1 {512-orx},{oy} Z"/>'
        f'<path fill="#E2384D" d="M{512-orx-3},{oy+42} L{512-orx-7},{oy+112} L{512+orx+7},{oy+112} L{512+orx+3},{oy+42} '
        f'A{orx},{ory} 0 0 1 {512-orx-3},{oy+42} Z"/>'
        f'<path fill="#FFFFFF" fill-opacity="0.13" d="M{512-orx+38},{oy+120} L{512-orx+30},1060 L{512-orx+92},1060 L{512-orx+96},{oy+125} Z"/>'
        # front lip of the brim (lower half of the brim ellipse, opening cut out)
        f'<path fill-rule="evenodd" fill="#1E1A27" d="M212,{oy} A300,78 0 0 0 812,{oy} L{512+orx},{oy} '
        f'A{orx},{ory} 0 0 1 {512-orx},{oy} Z"/>'
        f'<path fill="none" stroke="#5C5470" stroke-width="5" d="M222,{oy+12} A292,72 0 0 0 802,{oy+12}"/>'
        # sparkles around the fingertip
        + sparkle(250, 250, 74, '#FFD84D') + sparkle(752, 205, 52, '#FFD84D') + sparkle(800, 440, 32, '#FFFFFF'))
    return {
        'title': 'Ta-da!', 'idea': 'The white glove is a magician’s glove: it rises out of an upside-down top hat.',
        'hand': 'hand_glove.png', 'transform': 'none (byte-identical original)',
        'fill': '#4330B8', 'fill_dark': '#1D1650',
        'props': {'hat-front.svg': front, 'hat-back.svg': back},
        'groups': [('Hat front and sparkles', ['hat-front.svg'], False),
                   ('HAND', None, None),
                   ('Hat brim and opening', ['hat-back.svg'], False)],
        # cuff bottom sits just above the hat opening, handle disappears into it
        'scale': 1.08, 'anchor': ('cuff', (512, 718)),
    }


def concept_boop():
    cx, cy = 702, 498
    back = svg(burst(cx, cy, 300, 205, 11, 7, '#FFD23F', rot=-8) + burst(cx + 6, cy, 178, 128, 9, 3, '#FF4F8B', rot=14))
    return {
        'title': 'Boop', 'idea': 'A manicule (☞, the old “look here” mark): the purple hand enters from the edge and boops a pop-art burst.',
        'hand': 'hand_lavender.png', 'transform': 'exact 90° clockwise pixel remap (lossless)',
        'quarter_turns': 1,
        'fill': '#0FA89C', 'fill_dark': '#0A2E31',
        'props': {'burst.svg': back},
        'groups': [('HAND', None, None), ('Impact burst', ['burst.svg'], False)],
        'scale': 1.1, 'anchor': ('tip', (cx - 46, cy + 4)),
    }


def concept_xmarks():
    island = ('<path fill="#F3D08A" d="M210,770 C200,690 300,640 420,652 C520,610 690,626 790,676 '
              'C870,716 860,820 770,852 C650,900 420,898 300,866 C236,850 214,812 210,770 Z"/>'
              '<path fill="#E2B866" d="M240,800 C300,860 520,880 760,840 C700,880 450,892 310,866 C270,856 248,830 240,800 Z"/>')
    trail = ''.join(f'<circle cx="{x}" cy="{y}" r="9" fill="#9A6A33"/>' for x, y in
                    [(282, 790), (318, 760), (360, 742), (404, 738), (446, 748)])
    x = ('<g stroke="#E5383B" stroke-width="58" stroke-linecap="round">'
         '<line x1="438" y1="690" x2="586" y2="838"/><line x1="586" y1="690" x2="438" y2="838"/></g>')
    body = island + trail + x
    return {
        'title': 'X marks the spot', 'idea': 'Treasure-map joke: the white glove drops in from the top and points straight down at the red X.',
        'hand': 'hand_glove.png', 'transform': 'exact 180° pixel remap (lossless)',
        'quarter_turns': 2,
        'fill': '#2196E8', 'fill_dark': '#0D2A4A',
        'props': {'map.svg': svg(body)},
        'groups': [('HAND', None, None), ('Island and X', ['map.svg'], False)],
        'scale': 1.06, 'anchor': ('tip', (524, 650)),
    }


def concept_puppet():
    defs = ('<radialGradient id="spot" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFE9B0" stop-opacity="0.5"/>'
            '<stop offset="0.6" stop-color="#FFD27A" stop-opacity="0.18"/><stop offset="1" stop-color="#FFD27A" stop-opacity="0"/></radialGradient>')
    spot = svg('<ellipse cx="500" cy="470" rx="300" ry="380" fill="url(#spot)"/>', defs)

    def curtain(mirror):
        # inner edge sweeps in to a gold tie-back, then flares out to the floor
        d = ('M0,0 L215,0 C200,240 158,470 118,610 C150,700 190,840 196,1024 L0,1024 Z')
        folds = ''.join(f'<path fill="none" stroke="#9E1628" stroke-width="18" stroke-linecap="round" d="M{x},40 C{x-10},260 {x*0.62:.0f},470 {x*0.5:.0f},600 M{x*0.55:.0f},650 C{x*0.75:.0f},780 {x*0.9:.0f},900 {x*0.95:.0f},1024"/>'
                        for x in (70, 150))
        tie = '<rect x="30" y="590" width="128" height="40" rx="20" fill="#F2B33D"/>'
        g = f'<path fill="#D7263D" d="{d}"/>{folds}{tie}'
        return f'<g transform="translate(1024,0) scale(-1,1)">{g}</g>' if mirror else g
    scallops = ''.join(f'<circle cx="{x}" cy="112" r="44" fill="#C21F33"/>' for x in range(-12, 1080, 88))
    valance = f'<rect x="0" y="0" width="1024" height="114" fill="#C21F33"/>{scallops}<rect x="0" y="0" width="1024" height="30" fill="#F2B33D"/>'
    apron = ('<rect x="0" y="808" width="1024" height="216" fill="#6B2E1F"/>'
             '<rect x="0" y="800" width="1024" height="26" fill="#F2B33D"/>'
             '<rect x="0" y="826" width="1024" height="14" fill="#000000" fill-opacity="0.25"/>')
    front = svg(curtain(False) + curtain(True) + valance + apron)
    return {
        'title': 'Puppet show', 'idea': 'The hand already lives on a stick, so make it a puppet: it pops up on stage, leaning in to point.',
        'hand': 'hand_lavender.png', 'transform': 'rotated -12° with CoreGraphics high-quality resampling (only resampled hand)',
        'tilt': -12,
        'fill': '#1E1033', 'fill_dark': '#12091F',
        'props': {'stage.svg': front, 'spotlight.svg': spot},
        'groups': [('Stage, curtains and apron', ['stage.svg'], False),
                   ('HAND', None, None),
                   ('Spotlight', ['spotlight.svg'], False)],
        'scale': 1.08, 'anchor': ('cuff', (538, 774)),
    }


CONCEPTS = [('1-ta-da', concept_tada), ('2-boop', concept_boop), ('3-x-marks', concept_xmarks), ('4-puppet', concept_puppet)]


# ---------------------------------------------------------------- hand rasters

def prepare_hand(c, dest):
    src = ROOT / 'assets' / c['hand']
    m = MARKS[c['hand']]
    if 'quarter_turns' in c:
        w, h, px = pngraw.read(src)
        nw, nh, rpx = pngraw.rotate(w, h, px, c['quarter_turns'])
        pngraw.write(dest, nw, nh, rpx)
        # verify: decode what we wrote, rotate it back, compare every byte with the original pixels
        bw, bh, back = pngraw.read(dest)
        ow, oh, opx = pngraw.rotate(bw, bh, back, 4 - c['quarter_turns'])
        assert (ow, oh, opx) == (w, h, px), 'rotation was not lossless'
        q = c['quarter_turns']
        tf = (lambda p: (h - 1 - p[1], p[0])) if q == 1 else (lambda p: (w - 1 - p[0], h - 1 - p[1]))
        info = {'verified': 'decoded output rotated back is byte-identical to the original pixel data'}
    elif 'tilt' in c:
        subprocess.run([str(KIT), 'tilt', str(src), str(dest), str(c['tilt'])], check=True)
        w, h, _ = pngraw.read(src)
        nw, nh, _ = pngraw.read(dest)
        tf = lambda p: rotate_point(p, c['tilt'], w, h, nw, nh)
        info = {'verified': 'resampled derivative; not pixel-identical by design'}
    else:
        shutil.copyfile(src, dest)
        assert src.read_bytes() == dest.read_bytes()
        nw, nh = 1024, 1536; tf = lambda p: p
        info = {'verified': 'byte-identical copy'}
    key, dst = c['anchor']
    trans = place(nw, nh, c['scale'], tf(m[key]), dst)
    return trans, {'source': str(src.relative_to(ROOT)), 'source_sha256': sha(src), 'layer_png': dest.name,
                   'layer_sha256': sha(dest), 'transform': c['transform'], **info,
                   'icon_composer_position': {'scale': c['scale'], 'translation-in-points': trans}}


# ---------------------------------------------------------------- build

def build(slug, c):
    doc = HERE / 'concepts' / slug / 'AppIcon.icon'
    if doc.exists(): shutil.rmtree(doc)
    (doc / 'Assets').mkdir(parents=True)
    hand_name = c['hand'] if 'quarter_turns' not in c and 'tilt' not in c else c['hand'].replace('.png', f'-{slug.split("-",1)[1]}.png')
    trans, prov = prepare_hand(c, doc / 'Assets' / hand_name)
    for n, body in c['props'].items(): (doc / 'Assets' / n).write_text(body)
    groups = []
    for name, layers, glass in c['groups']:
        if layers is None:
            groups.append({'name': 'Original hand', 'layers': [{'name': 'Original hand PNG', 'image-name': hand_name, 'glass': False}],
                           'position': {'scale': c['scale'], 'translation-in-points': trans},
                           'shadow': {'kind': 'neutral', 'opacity': 0.28},
                           'translucency': {'enabled': False, 'value': 0.5}})
        else:
            groups.append({'name': name, 'layers': [{'name': l.removesuffix('.svg'), 'image-name': l, 'glass': glass} for l in layers],
                           'shadow': {'kind': 'neutral', 'opacity': 0.18},
                           'translucency': {'enabled': False, 'value': 0.5}})
    spec = {'groups': groups,
            'fill-specializations': [{'value': {'automatic-gradient': color(c['fill'])}},
                                     {'appearance': 'dark', 'value': {'automatic-gradient': color(c['fill_dark'])}}],
            'supported-platforms': {'squares': ['macOS']}}
    (doc / 'icon.json').write_text(json.dumps(spec, indent=2) + '\n')
    compiled = doc.parent / 'compiled'
    if compiled.exists(): shutil.rmtree(compiled)
    compiled.mkdir()
    subprocess.run(['xcrun', 'actool', str(doc), '--compile', str(compiled), '--output-partial-info-plist', str(compiled / 'partial.plist'),
                    '--app-icon', 'AppIcon', '--include-all-app-icons', '--enable-on-demand-resources', 'NO', '--development-region', 'en',
                    '--target-device', 'mac', '--platform', 'macosx', '--minimum-deployment-target', '13.0'],
                   check=True, stdout=subprocess.DEVNULL)
    assert (compiled / 'Assets.car').stat().st_size > 0
    for look in LOOKS:
        for px in ([1024, 512, 128, 64, 32, 16] if look in ('Default', 'Dark') else [256]):
            subprocess.run([str(ICTOOL), str(doc), '--export-image', '--output-file', str(OUT / f'{slug}-{look}-{px}.png'),
                            '--platform', 'macOS', '--rendition', look, '--width', str(px), '--height', str(px), '--scale', '1'],
                           check=True, stdout=subprocess.DEVNULL)
    for px in (16, 32):
        for look in ('Default', 'Dark'):
            subprocess.run([str(KIT), 'nearest', str(OUT / f'{slug}-{look}-{px}.png'), str(OUT / f'zoom-{slug}-{look}-{px}.png'), str(128 // px)], check=True)
    return {'concept': slug, 'title': c['title'], 'idea': c['idea'], 'document': str(doc.relative_to(HERE)), **prov}


# ---------------------------------------------------------------- review boards (SVG laid out, rasterised by rsvg-convert)

FONT = "font-family=\"Avenir Next\""


def text(x, y, s, size, fill='#211729', weight='normal', anchor='start'):
    s = s.replace('&', '&amp;').replace('<', '&lt;')
    return f'<text x="{x}" y="{y}" {FONT} font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>'


def img(href, x, y, w, h=None, pixel=False):
    style = ' style="image-rendering:pixelated"' if pixel else ''
    return f'<image href="{href}" x="{x}" y="{y}" width="{w}" height="{h or w}"{style}/>'


def render(name, w, h, body):
    p = OUT / f'{name}.svg'
    p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">{body}</svg>')
    subprocess.run(['rsvg-convert', str(p), '-o', str(HERE / f'{name}.png')], check=True)
    p.unlink()


def boards(meta):
    # contact sheet: four columns
    W, col = 1880, 460
    b = f'<rect width="{W}" height="1150" fill="#F5F5F7"/>'
    b += text(40, 70, 'Look Here Please · four playful icon ideas', 44, weight='bold')
    b += text(40, 112, 'Every hand is the original in-app PNG: unchanged, or rotated as noted. Props are new SVG. Native Icon Composer docs, ictool exports.', 21, '#655D70')
    for i, (slug, c) in enumerate(meta):
        x = 40 + i * col
        b += text(x, 182, f'{i+1}. {c["title"]}', 32, weight='bold')
        words, line, lines = c['idea'].split(), '', []
        for wd in words:
            if len(line) + len(wd) > 38: lines.append(line); line = wd
            else: line = (line + ' ' + wd).strip()
        lines.append(line)
        for j, ln in enumerate(lines): b += text(x, 218 + j * 25, ln, 19, '#4A4256')
        b += img(f'{slug}-Default-512.png', x - 10, 310, 420)
        b += f'<rect x="{x-10}" y="750" width="420" height="190" rx="18" fill="#26212E"/>'
        b += img(f'{slug}-Dark-128.png', x + 6, 781, 128)
        for k, (px, xx) in enumerate([(64, 160), (32, 252), (16, 312)]):
            b += img(f'{slug}-Default-{px}.png', x + xx, 813 + (64 - px) // 2, px)
            b += text(x + xx, 910, f'{px}', 16, '#C9C2D6')
        b += text(x + 6, 975, 'hand: ' + c['hand_file'], 17, '#655D70')
        b += text(x + 6, 1000, c['transform_short'], 17, '#655D70')
    b += text(40, 1085, 'Design proposals only. Nothing installed; production assets untouched. Dark tile = native Dark rendition at 128 / 64 / 32 / 16 px.', 19, '#655D70')
    render('contact-sheet', W, 1150, b)

    # small-size review: 1x and nearest-neighbour 4x/8x, light and dark menu-ish backdrops
    H = 140 + len(meta) * 200
    b = f'<rect width="1500" height="{H}" fill="#F5F5F7"/>' + text(40, 60, 'Small-size review: actual 16 and 32 px ictool exports, then the same pixels enlarged (nearest neighbour)', 26, weight='bold')
    b += text(40, 100, 'Default on light, Dark on dark. Read the enlarged tiles as “what the 16/32 px raster really contains”, not as a larger icon.', 18, '#655D70')
    for i, (slug, c) in enumerate(meta):
        y = 140 + i * 200
        b += text(40, y + 80, f'{i+1}. {c["title"]}', 24, weight='bold')
        for look, x0, bg, fg in (('Default', 330, '#FFFFFF', '#655D70'), ('Dark', 920, '#1E1B24', '#C9C2D6')):
            b += f'<rect x="{x0-20}" y="{y}" width="570" height="176" rx="14" fill="{bg}"/>'
            b += img(f'exports/{slug}-{look}-16.png', x0, y + 40, 16) + img(f'exports/{slug}-{look}-32.png', x0 + 36, y + 32, 32)
            b += img(f'exports/zoom-{slug}-{look}-16.png', x0 + 100, y + 24, 128) + img(f'exports/zoom-{slug}-{look}-32.png', x0 + 246, y + 24, 128)
            b += img(f'exports/{slug}-{look}-128.png', x0 + 392, y + 24, 128)
            for lbl, xx in (('16', 0), ('32', 36), ('16 ×8', 100), ('32 ×4', 246), ('128', 392)):
                b += text(x0 + xx, y + 172, lbl, 15, fg)
    p = HERE / 'small-size-review.svg'
    p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1500" height="{H}">{b}</svg>')
    subprocess.run(['rsvg-convert', str(p), '-o', str(HERE / 'small-size-review.png')], check=True)
    p.unlink()

    # native appearances: all six looks per concept
    b = '<rect width="1640" height="' + str(120 + len(meta) * 300) + '" fill="#F5F5F7"/>' + text(40, 64, 'Native appearances (ictool renditions, 256 px)', 28, weight='bold')
    for i, (slug, c) in enumerate(meta):
        y = 100 + i * 300
        b += text(40, y + 150, f'{i+1}. {c["title"]}', 22, weight='bold')
        for j, look in enumerate(LOOKS):
            x = 260 + j * 228
            dark = 'Dark' in look
            b += f'<rect x="{x}" y="{y}" width="218" height="280" rx="12" fill="{"#26212E" if dark else "#FFFFFF"}"/>'
            b += img(f'{slug}-{look}-{256 if look not in ("Default","Dark") else 512}.png', x + 9, y + 12, 200)
            b += text(x + 109, y + 262, look, 17, '#C9C2D6' if dark else '#655D70', anchor='middle')
    render('appearances', 1640, 120 + len(meta) * 300, b)


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    for f in OUT.glob('*.png'): f.unlink()
    subprocess.run(['xcrun', 'swiftc', '-O', str(HERE / 'tools/rasterkit.swift'), '-o', str(KIT)], check=True)
    meta, prov = [], []
    for slug, fn in CONCEPTS:
        c = fn(); p = build(slug, c); prov.append(p)
        c['hand_file'] = p['layer_png'] + (' (original bytes)' if p['layer_png'] == c['hand'] else '')
        c['transform_short'] = {'1-ta-da': 'unchanged original bytes', '2-boop': 'exact 90° pixel remap, no resampling',
                                '3-x-marks': 'exact 180° pixel remap, no resampling', '4-puppet': '−12° tilt, resampled (CoreGraphics)'}[slug]
        meta.append((slug, c))
        print('built', slug, p['icon_composer_position'])
    (HERE / 'provenance.json').write_text(json.dumps(prov, indent=2, ensure_ascii=False) + '\n')
    boards(meta)
    shutil.rmtree(TMP)
    print('done')
