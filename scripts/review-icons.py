#!/usr/bin/env python3
"""Build a local contact sheet of real Icon Composer exports and template symbols."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]; E=ROOT/'design/s024/exports'
looks=['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']
sheet=Image.new('RGB',(1200,700),'#eee9e1');d=ImageDraw.Draw(sheet)
for i,look in enumerate(looks):
 x=(i%3)*400;y=(i//3)*310
 if look in ['Dark','TintedDark','ClearDark']:d.rectangle((x,y,x+399,y+309),fill='#28232a')
 color='white' if look in ['Dark','TintedDark','ClearDark'] else '#352333'
 d.text((x+20,y+12),look,fill=color)
 icon=Image.open(E/f'icon-{look}.png').convert('RGBA');sheet.paste(icon.resize((224,224),Image.Resampling.LANCZOS),(x+20,y+46),icon.resize((224,224),Image.Resampling.LANCZOS))
 for side,yy in [(64,60),(32,150),(16,220)]:
  small=icon.resize((side,side),Image.Resampling.LANCZOS);sheet.paste(small,(x+300,yy+y),small);d.text((x+270,yy+y),str(side),fill=color)
for i,state in enumerate(['off','on']):
 for j,dark in enumerate([False,True]):
  x=20+i*280+j*130;y=640;d.rectangle((x,y,x+110,y+44),fill='#28232a' if dark else '#fff')
  art=Image.open(ROOT/f'assets/menubar_{state}.png').convert('RGBA');t=Image.new('RGBA',art.size,'white' if dark else 'black');t.putalpha(art.getchannel('A'));sheet.paste(t,(x+8,y+12),t);d.text((x+36,y+12),state,fill='white' if dark else '#111')
sheet.save(E/'icon-review.png');print(E/'icon-review.png')
