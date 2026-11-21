#!/usr/bin/env python3
"""Generate the Opus 2026-11-17 brand proposal SVGs from one shared geometry.

Pure string output (no Pillow). Run `build.sh` to also render PNGs with
rsvg-convert and Icon Composer's ictool. Writes only inside this directory.
"""
from pathlib import Path
import json

OUT = Path(__file__).resolve().parent

# Palette. Coral, cream and plum stay; amber is lifted so the target survives on coral.
CORAL = "#E8452B"
CORAL_DEEP = "#C9321F"
CREAM = "#FFF4DF"
PLUM = "#3D2134"
PLUM_DARK = "#24151F"
AMBER = "#FFC94D"

# Local geometry, drawn pointing straight up, then turned 45 degrees clockwise.
# The fingertip, target and stick share one axis, so the gesture lands on the dot.
ANGLE = 45
PIVOT = (512, 512)
SHIFT = (-22, 22)  # nudge the whole composition after rotation
SCALE = 0.95

AXIS_X = 506          # finger centre line
FINGER_W = 128
TIP_Y = 236
GAP = 14              # negative-space seam between glove parts

PALM = dict(left=352, right=AXIS_X + FINGER_W / 2, top=480, bottom=800)
ROLL_RIGHT = 728
ROLL_H = 92
CUFF = dict(left=316, right=632, top=PALM["bottom"] + GAP, h=88, r=34)
STICK_W = 88
DOT_R = 70
RING_GAP = 38
DOT_CY = TIP_Y - 34 - DOT_R


def g(inner, extra=""):
    sx, sy = SHIFT
    return (f'<g transform="translate({sx} {sy}) translate(512 512) scale({SCALE}) translate(-512 -512) '
            f'rotate({ANGLE} {PIVOT[0]} {PIVOT[1]})"{extra}>'
            f"{inner}</g>")


def finger_palm_path():
    r = FINGER_W / 2
    fl, fr = AXIS_X - r, AXIS_X + r
    p = PALM
    return (
        f"M{fl} {TIP_Y + r} A{r} {r} 0 0 1 {fr} {TIP_Y + r} "
        f"L{fr} {p['bottom'] - 18} Q{fr} {p['bottom']} {fr - 18} {p['bottom']} "
        f"L{p['left'] + 44} {p['bottom']} Q{p['left']} {p['bottom']} {p['left']} {p['bottom'] - 44} "
        f"L{p['left']} {p['top'] + 96} "
        f"Q{p['left']} {p['top']} {p['left'] + 96} {p['top']} "
        f"L{fl} {p['top']} Z"
    )


def rolls():
    x0 = PALM["right"] + GAP
    out = []
    y = PALM["top"] + 20
    for i in range(3):
        w = ROLL_RIGHT - x0 - i * 16
        out.append(f'<rect x="{x0}" y="{y}" width="{w}" height="{ROLL_H}" rx="{ROLL_H / 2}"/>'
                   f'<rect x="{x0}" y="{y}" width="{ROLL_H / 2}" height="{ROLL_H}" rx="10"/>')
        y += ROLL_H + GAP
    return "".join(out)


def cuff():
    c = CUFF
    return f'<rect x="{c["left"]}" y="{c["top"]}" width="{c["right"] - c["left"]}" height="{c["h"]}" rx="{c["r"]}"/>'


def stick(length=900):
    cx = (CUFF["left"] + CUFF["right"]) / 2
    y = CUFF["top"] + CUFF["h"] - 10
    return f'<rect x="{cx - STICK_W / 2}" y="{y}" width="{STICK_W}" height="{length}" rx="{STICK_W / 2}"/>'


def glove():
    return f'<path d="{finger_palm_path()}"/>{rolls()}{cuff()}'


def dot():
    return f'<circle cx="{AXIS_X}" cy="{DOT_CY}" r="{DOT_R}"/>'


def ping(width=20):
    # One ripple ring around the target: the "here" tap. Fingertip just kisses it.
    return (f'<circle cx="{AXIS_X}" cy="{DOT_CY}" r="{DOT_R + RING_GAP}" fill="none" '
            f'stroke="#fff" stroke-width="{width}"/>')


def svg(body, vb="0 0 1024 1024", extra=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"{extra}>{body}</svg>\n'


def write(rel, text):
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


# ---------- Icon Composer document ----------

def layer(name, image, light, dark, tinted_opacity=None):
    spec = [
        {"value": {"solid": light}},
        {"appearance": "dark", "value": {"solid": dark}},
        {"appearance": "tinted", "value": {"solid": "srgb:1.00000,1.00000,1.00000,1.00000"}},
    ]
    d = {"image-name": image, "name": name, "glass": True, "fill-specializations": spec}
    if tinted_opacity is not None:
        d["opacity-specializations"] = [{"appearance": "tinted", "value": tinted_opacity}]
    return d


def srgb(hex_):
    h = hex_.lstrip("#")
    r, g_, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g_:.5f},{b:.5f},1.00000"


def icon_doc():
    d = OUT / "icon/AppIcon.icon"
    write("icon/AppIcon.icon/Assets/stick.svg", svg(g(stick(), ' fill="#fff"')))
    write("icon/AppIcon.icon/Assets/glove.svg", svg(g(glove(), ' fill="#fff"')))
    write("icon/AppIcon.icon/Assets/target.svg", svg(g(dot(), ' fill="#fff"')))
    write("icon/AppIcon.icon/Assets/ping.svg", svg(g(ping())))
    doc = {
        "groups": [
            {
                "layers": [
                    layer("Ping", "ping.svg", srgb(AMBER), srgb(AMBER), 0.6),
                    layer("Target", "target.svg", srgb(AMBER), srgb(AMBER)),
                    layer("Glove", "glove.svg", srgb(CREAM), srgb(CREAM)),
                    layer("Stick", "stick.svg", srgb(PLUM), srgb(CORAL), 0.55),
                ],
                "shadow": {"kind": "neutral", "opacity": 0.4},
                "translucency": {"enabled": True, "value": 0.3},
            }
        ],
        "supported-platforms": {"squares": ["macOS"]},
        "fill-specializations": [
            {"value": {"automatic-gradient": srgb(CORAL)}},
            {"appearance": "dark", "value": {"automatic-gradient": srgb("#3A2032")}},
        ],
    }
    write("icon/AppIcon.icon/icon.json", json.dumps(doc, indent=2) + "\n")


# ---------- Flat marks ----------

def flat_tile(rx=228, dark=False):
    bg = PLUM_DARK if dark else CORAL
    stick_c = CORAL if dark else PLUM
    defs = (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{"#4A2A40" if dark else "#F2583A"}"/>'
            f'<stop offset="1" stop-color="{bg if dark else CORAL_DEEP}"/></linearGradient>'
            f'<clipPath id="tile"><rect width="1024" height="1024" rx="{rx}"/></clipPath></defs>')
    body = (defs + f'<g clip-path="url(#tile)"><rect width="1024" height="1024" fill="url(#bg)"/>'
            + g(stick(), f' fill="{stick_c}"')
            + g(ping(), f' opacity="0.7" style="color:{AMBER}"').replace('stroke="#fff"', f'stroke="{AMBER}"')
            + g(dot(), f' fill="{AMBER}"')
            + g(glove(), f' fill="{CREAM}"') + "</g>")
    return svg(body)


def glyph(color="#000", with_stick=True, with_ping=True):
    body = ""
    if with_stick:
        body += g(stick(), f' fill="{color}"')
    if with_ping:
        body += g(ping(), "").replace('stroke="#fff"', f'stroke="{color}"')
    body += g(dot(), f' fill="{color}"') + g(glove(), f' fill="{color}"')
    return body


# ---------- Menu bar template ----------
# A heavier redraw of the same glove for 18 pt: wider seams, two finger rolls, cuff,
# no stick. On = filled target. Off = hollow target. Pure black on transparent.

def menubar(state):
    import math
    gap = 52
    fl, fr, tip = 424, 588, 96
    pl, pt, pb = 300, 450, 790
    r = (fr - fl) / 2
    hand = (f"M{fl} {tip + r} A{r} {r} 0 0 1 {fr} {tip + r} L{fr} {pb} L{pl + 80} {pb} "
            f"Q{pl} {pb} {pl} {pb - 80} L{pl} {pt + 110} Q{pl} {pt} {pl + 110} {pt} L{fl} {pt} Z")
    # Curled fingers: three touching capsules. Their round ends scallop the edge,
    # so the knuckles read without interior seams at 18 pt.
    rh = (pb - pt) / 3
    xr = 748
    rolls = "".join(
        f'<rect x="{fr - 80}" y="{pt + i * rh}" width="{xr - (fr - 80) - i * 22}" height="{rh}" rx="{rh / 2}"/>'
        for i in range(3))
    cuff_ = f'<rect x="{pl - 30}" y="{pb + gap}" width="{fr - pl + 60}" height="118" rx="40"/>'
    cx, dr = (fl + fr) / 2, 94
    cy = tip - 60 - dr
    if state == "on":
        target = f'<circle cx="{cx}" cy="{cy}" r="{dr}"/>'
    else:
        target = f'<circle cx="{cx}" cy="{cy}" r="{dr - 30}" fill="none" stroke="#000" stroke-width="60"/>'
    pts = [(fl, tip), (fr, tip), (pl, pt), (pl, pb),
           (pl - 30, pb + gap + 118), (fr + 30, pb + gap + 118), (xr, pt), (xr, pt + rh)]
    a = math.radians(45)
    rot = [(512 + (x - 512) * math.cos(a) - (y - 512) * math.sin(a),
            512 + (x - 512) * math.sin(a) + (y - 512) * math.cos(a)) for x, y in pts]
    ccx = 512 + (cx - 512) * math.cos(a) - (cy - 512) * math.sin(a)
    ccy = 512 + (cx - 512) * math.sin(a) + (cy - 512) * math.cos(a)
    rot += [(ccx + dr, ccy), (ccx - dr, ccy), (ccx, ccy - dr), (ccx, ccy + dr)]
    minx, maxx = min(q[0] for q in rot), max(q[0] for q in rot)
    miny, maxy = min(q[1] for q in rot), max(q[1] for q in rot)
    side = max(maxx - minx, maxy - miny) * 1.04
    vx, vy = (minx + maxx) / 2 - side / 2, (miny + maxy) / 2 - side / 2
    return svg(f'<g fill="#000" transform="rotate(45 512 512)"><path d="{hand}"/>{rolls}{cuff_}{target}</g>',
               vb=f"{vx:.1f} {vy:.1f} {side:.1f} {side:.1f}")


# ---------- Lockups and banner ----------

# Comps only. Production uses live system text: ui-rounded on the web, .rounded in SwiftUI.
FONT = "font-family=\"'.SF NS Rounded','SF Pro Rounded',ui-rounded,'Helvetica Neue',sans-serif\""


def glove_pointing_right(k, tip_x, tip_y, glove_fill, stick_fill, stick_len=700):
    """Unrotated local glove turned to point right, scaled by k, fingertip at (tip_x, tip_y)."""
    # Local tip (AXIS_X, TIP_Y) maps to (512 + 512 - TIP_Y, AXIS_X) after rotate(90 512 512).
    rx, ry = 1024 - TIP_Y, AXIS_X
    tx, ty = tip_x - rx * k, tip_y - ry * k
    inner = (f'<g fill="{stick_fill}">{stick(stick_len)}</g><g fill="{glove_fill}">{glove()}</g>')
    return f'<g transform="translate({tx:.1f} {ty:.1f}) scale({k}) rotate(90 512 512)">{inner}</g>'


def lockup_stacked(dark=False):
    ink = CREAM if dark else PLUM
    bg = PLUM_DARK if dark else CREAM
    # The glove points straight at the word "Here": the name does what it says.
    hand = glove_pointing_right(0.56, 536, 352, CREAM if dark else PLUM, CORAL)
    return svg(
        f'<rect width="1280" height="720" fill="{bg}"/>{hand}'
        f'<g {FONT} font-weight="800" font-size="168" letter-spacing="-5">'
        f'<text x="560" y="236" fill="{ink}">Look</text>'
        f'<text x="560" y="410" fill="{CORAL}">Here</text>'
        f'<text x="560" y="584" fill="{ink}">Please</text></g>',
        vb="0 0 1280 720")


def nested_tile(x, y, size, dark=False):
    inner = flat_tile(dark=dark).split(">", 1)[1].rsplit("</svg>", 1)[0]
    return f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="0 0 1024 1024">{inner}</svg>'


def lockup_horizontal(dark=False):
    ink = CREAM if dark else PLUM
    return svg(
        nested_tile(0, 0, 120, dark)
        + f'<text x="148" y="82" {FONT} font-weight="800" font-size="62" letter-spacing="-2" fill="{ink}">'
        f'Look <tspan fill="{CORAL}">Here</tspan> Please</text>',
        vb="0 0 760 120")


def banner():
    hand = g(stick(), f' fill="{PLUM}"') + g(dot(), f' fill="{AMBER}"') + g(glove(), f' fill="{CREAM}"')
    pings = g(ping(), "").replace('stroke="#fff"', f'stroke="{AMBER}"')
    return svg(
        f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F2583A"/>'
        f'<stop offset="1" stop-color="{CORAL_DEEP}"/></linearGradient>'
        f'<clipPath id="panel"><rect x="940" width="660" height="800"/></clipPath></defs>'
        f'<rect width="1600" height="800" fill="{CREAM}"/>'
        f'<rect x="940" width="660" height="800" fill="url(#bg)"/>'
        f'<g clip-path="url(#panel)"><g transform="translate(905 150) scale(0.74)">{pings}{hand}</g></g>'
        f'<g {FONT}>'
        f'<text x="100" y="150" font-size="34" font-weight="700" letter-spacing="1" fill="{PLUM}">Look <tspan fill="{CORAL}">Here</tspan> Please</text>'
        f'<text x="94" y="380" font-size="148" font-weight="800" letter-spacing="-6" fill="{PLUM}">Point it out<tspan fill="{CORAL}">.</tspan></text>'
        f'<text x="100" y="470" font-size="38" font-weight="500" fill="{PLUM}">A playful pointer for presenting on a Mac.</text>'
        f'<text x="100" y="680" font-size="28" font-weight="600" fill="{PLUM}">By Austin Presley</text>'
        f'<text x="100" y="724" font-size="24" font-weight="500" fill="#7A5A6C">Hands and laser · Annotations · Quick controls · Stream Deck</text>'
        f'</g>',
        vb="0 0 1600 800")


def main():
    icon_doc()
    write("mark/mark.svg", flat_tile())
    write("mark/mark-dark.svg", flat_tile(dark=True))
    write("mark/glyph.svg", svg(glyph("#3D2134")))
    write("mark/glyph-mono.svg", svg(glyph("#000", with_ping=False)))
    write("menubar/menubar-on.svg", menubar("on"))
    write("menubar/menubar-off.svg", menubar("off"))
    write("lockup/lockup-stacked.svg", lockup_stacked())
    write("lockup/lockup-stacked-dark.svg", lockup_stacked(dark=True))
    write("lockup/lockup-horizontal.svg", lockup_horizontal())
    write("lockup/lockup-horizontal-dark.svg", lockup_horizontal(dark=True))
    write("banner/banner.svg", banner())


if __name__ == "__main__":
    main()
