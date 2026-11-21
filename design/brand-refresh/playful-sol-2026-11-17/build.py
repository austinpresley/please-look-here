#!/usr/bin/env python3
"""Four native icon ideas composed from the exact existing hand PNGs."""
from pathlib import Path
import base64
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
LOOKS=['Default','Dark','TintedLight','TintedDark','ClearLight','ClearDark']
SOURCE={name:ROOT/'assets'/f'hand_{name}.png' for name in ['glove','lavender']}
ROUND='/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
SANS='/System/Library/Fonts/HelveticaNeue.ttc'


def svg(body):
    return '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024">'+body+'</svg>\n'


def hand(name,x,y,angle,scale):
    encoded=base64.b64encode(SOURCE[name].read_bytes()).decode()
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale}) translate(-512 -430)">'
            f'<image x="0" y="0" width="1024" height="1536" xlink:href="data:image/png;base64,{encoded}"/></g>')


def color(hexv):
    return 'srgb:'+','.join(f'{int(hexv[i:i+2],16)/255:.5f}' for i in (1,3,5))+',1.00000'


CONCEPTS=[
    dict(id='S1',name='Lemon pop',note='Purple, tilted and oversized.',bg='#F7CD35',dark='#51426D',
         layers=[('hand',hand('lavender',540,480,35,1.30),False)]),
    dict(id='S2',name='Double take',note='The white and purple hands meet.',bg='#EF6251',dark='#4D2642',
         layers=[
             ('purple',hand('lavender',690,460,-35,.85),False),
             ('white',hand('glove',380,480,35,.85),False),
         ]),
    dict(id='S3',name='Sticky situation',note='A purple pointer over a peeled note.',bg='#31B3A2',dark='#174D51',
         layers=[
             ('hand',hand('lavender',548,475,29,1.24),False),
             ('paper','<g transform="rotate(-11 512 520)"><path fill="#FFF2CF" d="M260 165H755Q815 165 815 225V685L660 850H260Q210 850 210 800V215Q210 165 260 165Z"/><path fill="#F0CF78" d="M660 850V740Q660 685 715 685H815Z"/></g>',True),
         ]),
    dict(id='S4',name='Ribbon dance',note='A white hand with loud marker stripes.',bg='#493766',dark='#261C3A',
         layers=[
             ('hand',hand('glove',455,485,-25,1.38),False),
             ('ribbons','<g transform="rotate(35 512 512)"><rect x="330" y="-350" width="195" height="1750" rx="97" fill="#FFB9D7"/><rect x="575" y="-350" width="195" height="1750" rx="97" fill="#FFCA48"/></g>',False),
         ]),
]


def build(c):
    doc=HERE/c['id']/'AppIcon.icon'
    (doc/'Assets').mkdir(parents=True,exist_ok=True)
    groups=[]
    for name,body,glass in c['layers']:
        filename=name+'.svg'
        (doc/'Assets'/filename).write_text(svg(body))
        groups.append({'name':name,'layers':[{'name':name,'image-name':filename,'glass':glass}],
                       'shadow':{'kind':'neutral','opacity':.18 if name in ['hand','white','purple','paper'] else 0},
                       'translucency':{'enabled':False,'value':.5}})
    (doc/'icon.json').write_text(json.dumps({'groups':groups,
        'fill-specializations':[{'value':{'automatic-gradient':color(c['bg'])}},
                                {'appearance':'dark','value':{'automatic-gradient':color(c['dark'])}}],
        'supported-platforms':{'squares':['macOS']}},indent=2)+'\n')
    compiled=doc.parent/'compiled';compiled.mkdir(exist_ok=True)
    subprocess.run(['xcrun','actool',str(doc),'--compile',str(compiled),
        '--output-partial-info-plist',str(compiled/'partial.plist'),'--app-icon','AppIcon',
        '--include-all-app-icons','--enable-on-demand-resources','NO','--development-region','en',
        '--target-device','mac','--platform','macosx','--minimum-deployment-target','13.0'],
        check=True,stdout=subprocess.DEVNULL)
    assert (compiled/'Assets.car').stat().st_size>0
    for look in LOOKS:
        for px in ([512,32,16] if look in ['Default','Dark'] else [512]):
            subprocess.run([str(ICTOOL),str(doc),'--export-image','--output-file',str(OUT/f'{c["id"]}-{look}-{px}.png'),
                '--platform','macOS','--rendition',look,'--width',str(px),'--height',str(px),'--scale','1'],
                check=True,stdout=subprocess.DEVNULL)


def font(size,bold=False):
    return ImageFont.truetype(ROUND if bold else SANS,size)


def paste(canvas,path,x,y,side):
    im=Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS)
    canvas.paste(im,(x,y),im)


def sheets():
    board=Image.new('RGB',(1500,1600),'#F5F5F7');d=ImageDraw.Draw(board)
    d.text((56,34),'A little more personality.',font=font(45,True),fill='#211729')
    d.text((56,98),'Four icon ideas using the actual hands. Sol.',font=font(25),fill='#655D70')
    for i,c in enumerate(CONCEPTS):
        x=56+(i%2)*744;y=178+(i//2)*695
        paste(board,OUT/f'{c["id"]}-Default-512.png',x,y,450)
        paste(board,OUT/f'{c["id"]}-Dark-512.png',x+488,y+20,125)
        for j,px in enumerate([32,16]):
            paste(board,OUT/f'{c["id"]}-Default-{px}.png',x+500+j*72,y+195,px)
            d.text((x+500+j*72,y+242),str(px),font=font(17),fill='#655D70')
        d.text((x,y+477),c['id']+'  '+c['name'],font=font(32,True),fill='#211729')
        d.text((x,y+527),c['note'],font=font(23),fill='#655D70')
    board.save(OUT/'sol-ideas.png')
    for c in CONCEPTS:
        sheet=Image.new('RGB',(1500,650),'#F5F5F7');d=ImageDraw.Draw(sheet)
        for i,look in enumerate(LOOKS):
            x=(i%3)*500;y=(i//3)*325;dark='Dark' in look
            fg='white' if dark else '#211729'
            d.rectangle((x,y,x+499,y+324),fill='#272330' if dark else '#F5F5F7')
            d.text((x+20,y+16),look,font=font(21,True),fill=fg)
            paste(sheet,OUT/f'{c["id"]}-{look}-512.png',x+20,y+60,230)
            for px,yy in [(32,105),(16,220)]:
                paste(sheet,OUT/f'{c["id"]}-{look}-512.png',x+290,y+yy,px)
                d.text((x+340,y+yy),str(px)+' px',font=font(17),fill=fg)
        sheet.save(OUT/f'{c["id"]}-appearances.png')


if __name__=='__main__':
    originals=HERE/'originals';originals.mkdir(exist_ok=True)
    provenance=[]
    for name,path in SOURCE.items():
        shutil.copyfile(path,originals/path.name)
        provenance.append({'asset':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (HERE/'source-artwork.json').write_text(json.dumps(provenance,indent=2)+'\n')
    for c in CONCEPTS:build(c)
    sheets()
    (HERE/'concepts.json').write_text(json.dumps([{k:v for k,v in c.items() if k!='layers'} for c in CONCEPTS],indent=2)+'\n')
    print('Compiled and rendered S1-S4 with original PNGs embedded unchanged in SVG layers')
