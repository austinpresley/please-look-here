import sys
from pathlib import Path
from PIL import Image, ImageDraw
OUT = Path(__file__).resolve().parent / 'out'
name = sys.argv[1]
looks = ['Default', 'Dark', 'TintedLight', 'TintedDark', 'ClearLight', 'ClearDark']
W = 300
sheet = Image.new('RGB', (W * 6, W + 90), '#e9e4dc')
d = ImageDraw.Draw(sheet)
for i, look in enumerate(looks):
    dark = 'Dark' in look
    d.rectangle((i * W, 0, i * W + W - 1, W + 89), fill='#2a252b' if dark else '#e9e4dc')
    im = Image.open(OUT / f'{name}-{look}.png').convert('RGBA')
    big = im.resize((W - 40, W - 40), Image.LANCZOS)
    sheet.paste(big, (i * W + 20, 14), big)
    x = i * W + 24
    for s in (64, 32, 16):
        sm = im.resize((s, s), Image.LANCZOS)
        sheet.paste(sm, (x, W + 80 - s - 6), sm)
        x += s + 18
    d.text((i * W + 190, W + 50), look, fill='white' if dark else '#333')
sheet.save(OUT / f'{name}-sheet.png')
print(OUT / f'{name}-sheet.png')
