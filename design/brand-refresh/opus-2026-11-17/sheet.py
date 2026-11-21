#!/usr/bin/env python3
"""Compose review sheets as SVG next to the PNGs in exports/ (librsvg only loads
images from the SVG's own directory). Small sizes come from sips downscales."""
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
E = HERE / "exports"
ROOT = HERE.parents[2]
LOOKS = ["Default", "Dark", "TintedLight", "TintedDark", "ClearLight", "ClearDark"]
DARK = {"Dark", "TintedDark", "ClearDark"}
FONT = "font-family=\"-apple-system,'Helvetica Neue',sans-serif\""


def shrink(src, size, dst):
    subprocess.run(["sips", "-Z", str(size), str(src), "--out", str(dst)], check=True, capture_output=True)


def img(name, x, y, w, h=None):
    return f'<image href="{name}" x="{x}" y="{y}" width="{w}" height="{h or w}"/>'


def text(s, x, y, fill, size=14, weight=500):
    return f'<text x="{x}" y="{y}" {FONT} font-size="{size}" font-weight="{weight}" fill="{fill}">{s}</text>'


def icon_review():
    parts = []
    for i, look in enumerate(LOOKS):
        x, y = (i % 3) * 400, (i // 3) * 310
        bg = "#28232a" if look in DARK else "#eee9e1"
        fg = "#fff" if look in DARK else "#352333"
        parts.append(f'<rect x="{x}" y="{y}" width="400" height="310" fill="{bg}"/>')
        parts.append(text(look, x + 20, y + 28, fg))
        parts.append(img(f"icon-{look}.png", x + 20, y + 46, 224))
        for side, yy in [(64, 60), (32, 150), (16, 220)]:
            small = f"_icon-{look}-{side}.png"
            shrink(E / f"icon-{look}.png", side, E / small)
            parts.append(text(str(side), x + 270, y + yy + 12, fg, 12))
            parts.append(img(small, x + 300, y + yy, side))
    # Menu bar template symbols, tinted as macOS would for light and dark bars.
    y = 640
    for i, state in enumerate(["off", "on"]):
        for j, dark in enumerate([False, True]):
            x = 20 + i * 300 + j * 140
            parts.append(f'<rect x="{x}" y="{y}" width="124" height="44" rx="6" fill="{"#28232a" if dark else "#fff"}"/>')
            fill = "#fff" if dark else "#000"
            parts.append(f'<g transform="translate({x + 10} {y + 13})"><g style="filter:url(#{"inv" if dark else "id"})">'
                         + img(f"menubar-{state}-36.png", 0, 0, 18) + "</g></g>")
            parts.append(text(state, x + 40, y + 27, fill, 13))
    defs = ('<defs><filter id="inv"><feColorMatrix type="matrix" values="-1 0 0 0 1  0 -1 0 0 1  0 0 -1 0 1  0 0 0 1 0"/></filter>'
            '<filter id="id"><feColorMatrix type="identity"/></filter></defs>')
    body = "".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="700">{defs}'
            f'<rect width="1200" height="700" fill="#eee9e1"/>{body}'
            + text("Real Icon Composer exports · menu bar template at 18 pt", 700, 668, "#352333", 13)
            + "</svg>")


def before_after():
    old = ROOT / "design/s024/exports/icon-Default.png"
    shutil.copy(old, E / "_current-icon-Default.png")
    shutil.copy(ROOT / "assets/menubar_on@2x.png", E / "_current-menubar-on-36.png")
    parts = ['<rect width="1200" height="520" fill="#f3efe8"/>',
             text("Current (s024)", 40, 44, "#352333", 18, 700),
             text("Proposed", 640, 44, "#352333", 18, 700)]
    for col, (name, menu) in enumerate([("_current-icon-Default.png", "_current-menubar-on-36.png"),
                                        ("icon-Default.png", "menubar-on-36.png")]):
        x0 = 40 + col * 600
        parts.append(img(name, x0, 70, 300))
        xs = x0 + 320
        for side, yy in [(128, 70), (64, 214), (32, 296), (16, 346)]:
            small = f"_ba-{col}-{side}.png"
            shrink(E / name, side, E / small)
            parts.append(img(small, xs, yy, side))
        parts.append(f'<rect x="{x0}" y="400" width="300" height="34" fill="#fff"/>')
        parts.append(img(menu, x0 + 10, 408, 18))
        parts.append(f'<rect x="{x0 + 310}" y="400" width="200" height="34" fill="#28232a"/>')
        parts.append(f'<g style="filter:url(#inv)">{img(menu, x0 + 320, 408, 18)}</g>')
    defs = ('<defs><filter id="inv"><feColorMatrix type="matrix" values="-1 0 0 0 1  0 -1 0 0 1  0 0 -1 0 1  0 0 0 1 0"/></filter></defs>')
    notes = [
        "Fingertip, target and stick share one 45 degree axis: the gesture lands on the dot.",
        "No raised thumb, so the silhouette cannot read as two fingers or a V.",
        "The stick ties the icon to the app's own glove-on-a-stick pointers.",
    ]
    for i, n in enumerate(notes):
        parts.append(text(n, 40, 470 + i * 20, "#5a4052", 14))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="540">{defs}' + "".join(parts) + "</svg>")


def main():
    (E / "icon-review.svg").write_text(icon_review())
    (E / "before-after.svg").write_text(before_after())
    for name in ["icon-review", "before-after"]:
        subprocess.run(["rsvg-convert", str(E / f"{name}.svg"), "-o", str(E / f"{name}.png")], check=True)
        (E / f"{name}.svg").unlink()
    for tmp in E.glob("_*.png"):
        tmp.unlink()


if __name__ == "__main__":
    main()
