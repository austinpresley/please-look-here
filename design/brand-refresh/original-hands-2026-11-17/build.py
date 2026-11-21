#!/usr/bin/env python3
"""Use the actual in-app PNG artwork, unchanged, in native icon documents."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=HERE/'exports'
OUT.mkdir(exist_ok=True)
DEV=Path(subprocess.check_output(['xcode-select','-p'],text=True).strip())
ICTOOL=DEV.parent/'Applications/Icon Composer.app/Contents/Executables/ictool'


def color(hexv):
    return 'srgb:'+','.join(f'{int(hexv[i:i+2],16)/255:.5f}' for i in (1,3,5))+',1.00000'


def build(name,asset,background):
    doc=HERE/name/'AppIcon.icon'
    (doc/'Assets').mkdir(parents=True,exist_ok=True)
    source=ROOT/'assets'/asset
    target=doc/'Assets'/asset
    shutil.copyfile(source,target)
    assert source.read_bytes()==target.read_bytes()
    spec={
        'groups':[{
            'name':'Actual pointer artwork',
            'layers':[{'name':'Original hand PNG','image-name':asset,'glass':False}],
            'position':{'scale':1.4,'translation-in-points':[0,480 if asset=='hand_glove.png' else 520]},
            'shadow':{'kind':'neutral','opacity':.15},
            'translucency':{'enabled':False,'value':.5}
        }],
        'fill-specializations':[
            {'value':{'automatic-gradient':color(background)}},
            {'appearance':'dark','value':{'automatic-gradient':color('#30233D')}}
        ],
        'supported-platforms':{'squares':['macOS']}
    }
    (doc/'icon.json').write_text(json.dumps(spec,indent=2)+'\n')
    compiled=doc.parent/'compiled'
    compiled.mkdir(exist_ok=True)
    subprocess.run(['xcrun','actool',str(doc),'--compile',str(compiled),
        '--output-partial-info-plist',str(compiled/'partial.plist'),'--app-icon','AppIcon',
        '--include-all-app-icons','--enable-on-demand-resources','NO','--development-region','en',
        '--target-device','mac','--platform','macosx','--minimum-deployment-target','13.0'],
        check=True,stdout=subprocess.DEVNULL)
    assert (compiled/'Assets.car').stat().st_size>0
    for look in ['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']:
        for px in [512,32,16]:
            subprocess.run([str(ICTOOL),str(doc),'--export-image','--output-file',str(OUT/f'{name}-{look}-{px}.png'),
                '--platform','macOS','--rendition',look,'--width',str(px),'--height',str(px),'--scale','1'],
                check=True,stdout=subprocess.DEVNULL)
    return {'variant':name,'source':str(source.relative_to(ROOT)),
            'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}


def font(size,bold=False):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf' if bold else '/System/Library/Fonts/HelveticaNeue.ttc',size)


def paste(canvas,path,xy,side):
    art=Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS)
    canvas.paste(art,xy,art)


def sheets():
    board=Image.new('RGB',(1500,920),'#F5F5F7');d=ImageDraw.Draw(board)
    d.text((60,40),'Look Here Please',font=font(40,True),fill='#211729')
    d.text((60,100),'The actual hands from the app',font=font(26),fill='#655D70')
    for i,(name,label) in enumerate([('white-coral','Original white'),('purple-coral','Purple on coral'),('purple-cream','Purple on cream')]):
        x=60+i*485
        d.text((x,173),label,font=font(27,True),fill='#211729')
        paste(board,OUT/f'{name}-Default-512.png',(x,230),365)
        paste(board,OUT/f'{name}-Dark-512.png',(x,632),112)
        for j,px in enumerate([32,16]):
            paste(board,OUT/f'{name}-Default-{px}.png',(x+154+j*90,660+(32-px)//2),px)
            d.text((x+154+j*90,709),str(px)+' px',font=font(17),fill='#655D70')
    d.text((60,819),'Original source PNGs preserved byte-for-byte. Native icon framing only.',font=font(24),fill='#211729')
    d.text((60,861),'No redesigned hand. No regenerated artwork. Design previews, not installed.',font=font(20),fill='#655D70')
    board.save(OUT/'actual-hands-comparison.png')
    for name in ['white-coral','purple-coral','purple-cream']:
        sheet=Image.new('RGB',(1500,650),'#F5F5F7');d=ImageDraw.Draw(sheet)
        for i,look in enumerate(['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']):
            x=i%3*500;y=i//3*325;dark='Dark' in look
            fg='#FFFFFF' if dark else '#211729'
            d.rectangle((x,y,x+499,y+324),fill='#272330' if dark else '#F5F5F7')
            d.text((x+20,y+16),look,font=font(21,True),fill=fg)
            paste(sheet,OUT/f'{name}-{look}-512.png',(x+20,y+63),220)
            for px,yy in [(32,98),(16,205)]:
                d.text((x+281,y+yy-25),str(px)+' px',font=font(17),fill=fg)
                paste(sheet,OUT/f'{name}-{look}-{px}.png',(x+281,y+yy),px)
                art=Image.open(OUT/f'{name}-{look}-{px}.png').convert('RGBA').resize((px*3,px*3),Image.Resampling.NEAREST)
                sheet.paste(art,(x+354,y+yy),art)
        sheet.save(OUT/f'{name}-appearances.png')


if __name__=='__main__':
    provenance=[build('white-coral','hand_glove.png','#F04B32'),
                build('purple-coral','hand_lavender.png','#F04B32'),
                build('purple-cream','hand_lavender.png','#F5F0E7')]
    (HERE/'source-artwork.json').write_text(json.dumps(provenance,indent=2)+'\n')
    sheets()
    print('Compiled three native icon options using byte-identical original PNGs')
