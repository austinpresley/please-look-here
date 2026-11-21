#!/usr/bin/env python3
"""Native color variations of Austin's selected S1 Lemon pop composition."""
from pathlib import Path
import copy
import hashlib
import json
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'playful-sol-2026-11-17/S1/AppIcon.icon'
OUT=HERE/'exports'
LOOKS=['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']
ROUND='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
SANS='/System/Library/Fonts/HelveticaNeue.ttc'
PALETTES=[
    ('C1','Lemon','#F7CD35','#51426D'),
    ('C2','Butter','#FFE5A0','#514331'),
    ('C3','Apricot','#FFAF72','#603D37'),
    ('C4','Tangerine','#FA762D','#632E29'),
    ('C5','Watermelon','#FB696F','#592C4B'),
    ('C6','Bubblegum','#FFADD1','#552B56'),
    ('C7','Lime','#D7ED69','#3A492A'),
    ('C8','Mint','#78D9BD','#254941'),
    ('C9','Lagoon','#1E9EAA','#174F59'),
    ('C10','Sky','#73C7ED','#273D60'),
    ('C11','Cream','#F5F0E7','#51426D'),
    ('C12','Midnight','#24203D','#181627'),
]


def color(hexv):
    return 'srgb:'+','.join(f'{int(hexv[i:i+2],16)/255:.5f}' for i in (1,3,5))+',1.00000'


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    developer=Path(subprocess.check_output(['xcode-select','-p'],text=True).strip())
    ictool=developer.parent/'Applications/Icon Composer.app/Contents/Executables/ictool'
    original=json.loads((BASE/'icon.json').read_text())
    provenance={'selected_composition':'S1 Lemon pop','source_document':str(BASE),
                'unchanged_layers':{},'variants':[]}
    for path in (BASE/'Assets').iterdir():
        if path.is_file():provenance['unchanged_layers'][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
    for key,name,light,dark in PALETTES:
        doc=HERE/key/'AppIcon.icon'
        (doc/'Assets').mkdir(parents=True,exist_ok=True)
        for path in (BASE/'Assets').iterdir():
            if path.is_file():shutil.copyfile(path,doc/'Assets'/path.name)
        spec=copy.deepcopy(original)
        spec['fill-specializations']=[{'value':{'automatic-gradient':color(light)}},
            {'appearance':'dark','value':{'automatic-gradient':color(dark)}}]
        assert spec['groups']==original['groups']
        (doc/'icon.json').write_text(json.dumps(spec,indent=2)+'\n')
        compiled=doc.parent/'compiled';compiled.mkdir(exist_ok=True)
        subprocess.run(['xcrun','actool',str(doc),'--compile',str(compiled),
            '--output-partial-info-plist',str(compiled/'partial.plist'),'--app-icon','AppIcon',
            '--include-all-app-icons','--enable-on-demand-resources','NO','--development-region','en',
            '--target-device','mac','--platform','macosx','--minimum-deployment-target','13.0'],
            check=True,stdout=subprocess.DEVNULL)
        assert (compiled/'Assets.car').stat().st_size>0
        for look in LOOKS:
            for px in ([512,32,16] if look in ['Default','Dark'] else [512]):
                subprocess.run([str(ictool),str(doc),'--export-image','--output-file',str(OUT/f'{key}-{look}-{px}.png'),
                    '--platform','macOS','--rendition',look,'--width',str(px),'--height',str(px),'--scale','1'],
                    check=True,stdout=subprocess.DEVNULL)
        provenance['variants'].append({'id':key,'name':name,'background':light,'dark_background':dark})
    (HERE/'palettes.json').write_text(json.dumps(provenance,indent=2)+'\n')


def font(size,bold=False):
    return ImageFont.truetype(ROUND if bold else SANS,size)


def paste(im,path,x,y,side):
    image=Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS)
    im.paste(image,(x,y),image)


def sheets():
    for look in ['Default','Dark']:
        im=Image.new('RGB',(1800,1700),'#F5F5F7' if look=='Default' else '#211D2A')
        d=ImageDraw.Draw(im);fg='#211729' if look=='Default' else '#FFFFFF';muted='#655D70' if look=='Default' else '#C1B8CD'
        d.text((50,34),'S1 Lemon pop. More colors.',font=font(46,True),fill=fg)
        d.text((50,102),'Same original purple hand, same angle, same framing. '+look+' appearance.',font=font(26),fill=muted)
        for i,(key,name,light,dark) in enumerate(PALETTES):
            x=50+(i%4)*438;y=185+(i//4)*491
            paste(im,OUT/f'{key}-{look}-512.png',x,y,330)
            d.text((x,y+352),key+'  '+name+(' (original)' if key=='C1' else ''),font=font(25,True),fill=fg)
            d.text((x,y+391),light if look=='Default' else dark,font=font(20),fill=muted)
            for j,px in enumerate([32,16]):
                paste(im,OUT/f'{key}-{look}-{px}.png',x+162+j*80,y+389+(32-px)//2,px)
                d.text((x+201+j*80,y+397),str(px),font=font(16),fill=muted)
        im.save(HERE/f'lemon-colors-{look.lower()}.png')
    for key,name,light,dark in PALETTES:
        im=Image.new('RGB',(1500,650),'#F5F5F7');d=ImageDraw.Draw(im)
        for i,look in enumerate(LOOKS):
            x=(i%3)*500;y=(i//3)*325;is_dark='Dark' in look
            fg='white' if is_dark else '#211729'
            d.rectangle((x,y,x+499,y+324),fill='#272330' if is_dark else '#F5F5F7')
            d.text((x+20,y+16),look,font=font(21,True),fill=fg)
            paste(im,OUT/f'{key}-{look}-512.png',x+20,y+60,230)
            if look in ['Default','Dark']:
                for px,yy in [(32,105),(16,215)]:
                    paste(im,OUT/f'{key}-{look}-{px}.png',x+290,y+yy,px)
                    d.text((x+342,y+yy),str(px)+' px',font=font(17),fill=fg)
        im.save(OUT/f'{key}-appearances.png')


if __name__=='__main__':
    build()
    sheets()
    print('Compiled twelve S1 color variants. Original hand layer and composition are unchanged.')
