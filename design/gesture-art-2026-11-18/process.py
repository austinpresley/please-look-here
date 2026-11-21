#!/usr/bin/env python3
"""Deterministic local-only normalization, validation and contact-sheet rendering.

Usage: .venv/bin/python process.py
Only writes beside this script. Generation itself uses the built-in image tool.
"""
from pathlib import Path
import json
import html
import hashlib
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
IDS = 'astro black blue cactus choco chrome cloud cookie coral fuzzy glass glove grass holo jelly knit lava lavender leaf lemon lowpoly marble mech mint monster neon pastel pink pixel plush robot skeleton space terrazzo water wood'.split()
SIZE = (1024, 1536)
# Restoration line in top-left PNG coordinates, sometimes in the lower palm.
# The original cuff and rod below it are restored, never redrawn or re-scaled.
# This is not HandAsset.wrist and must not be used as a runtime crop anchor.
RESTORE_Y = dict(zip(IDS, [600,638,638,630,634,612,670,610,677,615,649,611,635,604,638,618,611,594,620,605,614,607,620,610,676,612,613,638,712,669,744,588,615,648,615,611]))
# These two generated vinyl necks had an extra cuff lip. Restore from slightly
# higher on the wrist so the original single cuff replaces that generated lip.
RESTORE_Y.update(black=565,blue=615,cloud=560,coral=500,monster=620,terrazzo=610)

def bbox(mask):
    y,x = np.where(mask)
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None

def clean(im, pixel=False):
    """Remove RGB under zero alpha and diffuse alpha residue, retain edge AA.

    The model sometimes returns alpha=1 far outside the object. Only alpha
    within two pixels of meaningful coverage survives. No color-keying occurs.
    Translucent materials retain their interior alpha.
    """
    a = np.array(im.convert('RGBA')).copy()
    core = Image.fromarray(np.where(a[:,:,3]>96,255,0).astype('uint8'))
    near = np.asarray(core.filter(ImageFilter.MaxFilter(5)))>0
    a[:,:,3] = np.where(near & (a[:,:,3]>8),a[:,:,3],0)
    a[:,:,3] = np.where(a[:,:,3]>=245,255,a[:,:,3])
    a[a[:,:,3]==0,:3]=0
    # Source plush/robot rods touch the bottom edge. Clear one edge pixel;
    # preserve rod scale, with a documented one-pixel endpoint difference.
    a[0,:,:]=0; a[-1,:,:]=0; a[:,0,:]=0; a[:,-1,:]=0
    return Image.fromarray(a)

def anchor(im, cut):
    a=np.asarray(im)[:,:,3]>128
    rod=bbox(a[850:1350])
    if rod: rod=[rod[0],rod[1]+850,rod[2],rod[3]+850]
    spans=[]
    for y in range(max(440,cut-80),min(800,cut+85)):
        xs=np.where(a[y])[0]
        if len(xs)>100: spans.append((y,int(xs[-1]-xs[0]+1),float((xs[-1]+xs[0])/2)))
    return rod, spans

def normalize(raw, base, id):
    cut=RESTORE_Y[id]
    registration=600 if id=='coral' else cut
    input_rgba=np.asarray(raw.convert('RGBA'))
    clipped={'top':int((input_rgba[0,:,3]>128).sum()),'left':int((input_rgba[:,0,3]>128).sum()),'right':int((input_rgba[:,-1,3]>128).sum())}
    raw=clean(raw)
    base=clean(base)
    if raw.size!=SIZE:
        raw=raw.resize(SIZE,Image.Resampling.NEAREST if id=='pixel' else Image.Resampling.LANCZOS)
    # Search the raw neck profile near the expected cuff. Compare scaled
    # profiles, anchoring x with the rod and y with the neck, not hand bounds.
    br,bs=anchor(base,registration); rr,rs=anchor(raw,registration)
    if not br or not rr or not bs or not rs:
        raise ValueError('Missing cuff or rod anchor')
    bx=(br[0]+br[2]-1)/2; rx=(rr[0]+rr[2]-1)/2
    ba=np.asarray(base)[:,:,3]>128; ra=np.asarray(raw)[:,:,3]>128
    bw=float(np.median([ba[y].sum() for y in range(registration-4,registration+5)]))
    # Restrict scale so a generation with a very different hand is flagged
    # for review instead of silently being stretched into a different style.
    candidates=[]
    for y,w,c in rs:
        if abs(y-registration)>85: continue
        s=bw/w
        if not .80<=s<=1.25: continue
        loss=abs(y-registration)*.045+abs(s-1)*10
        for dy in (-18,-9,0,9,18):
            by=registration+dy; ry=round(y+dy/s)
            if 0<=by<1536 and 0<=ry<1536:
                loss+=abs(float(ba[by].sum())-float(ra[ry].sum())*s)/max(1,bw)
        candidates.append((loss,s,y))
    _,scale,raw_y=min(candidates) if candidates else (0,1,registration)
    b=np.array(base)
    base_top=bbox(b[:,:,3]>128)[1]
    raw_box=bbox(np.asarray(raw)[:,:,3]>128)
    tx=bx-rx*scale; ty=registration-raw_y*scale
    registered_top=raw_box[1]*scale+ty
    # ArmView crops with the BASE HandAsset.handTop. A generator can raise the
    # three OK fingertips above that line. Fit the upper hand vertically into
    # the original top-to-cuff interval, with the wrist fixed, to avoid clipping.
    top_fit=1.0
    if registered_top<base_top:
        top_fit=(registration-base_top)/(registration-registered_top)
    # Combine these transforms before sampling. An intermediate canvas could
    # crop a tall fingertip before the vertical fit had a chance to preserve it.
    horizontal_fit=min(1.,(bx-16)/max(1,bx-(raw_box[0]*scale+tx)),(SIZE[0]-16-bx)/max(1,raw_box[2]*scale+tx-bx))
    sx=scale*horizontal_fit; tx=bx-rx*sx
    sy=scale*top_fit; final_ty=ty*top_fit+registration*(1-top_fit)
    filt=Image.Resampling.NEAREST if id=='pixel' else Image.Resampling.BICUBIC
    reg=raw.transform(SIZE,Image.Transform.AFFINE,(1/sx,0,-tx/sx,0,1/sy,-final_ty/sy),resample=filt)
    a=np.array(reg)
    # Match lower-palm row contours before the cuff blend. Crossfading two
    # unregistered silhouettes would leave tiny fins or a doubled outline.
    # A smooth horizontal warp over 100 rows joins the generated upper hand
    # to the exact original wrist contour without moving any digits.
    contour_rows=100
    xx=np.arange(SIZE[0],dtype=float)
    for y in range(max(base_top,cut-contour_rows),cut):
        rxs=np.where(a[y,:,3]>128)[0]; bxs=np.where(b[y,:,3]>128)[0]
        if len(rxs)<2 or len(bxs)<2: continue
        t=(y-(cut-contour_rows))/contour_rows; t=t*t*(3-2*t)
        left=float(rxs[0])*(1-t)+float(bxs[0])*t
        right=float(rxs[-1])*(1-t)+float(bxs[-1])*t
        sx=(right-left)/float(rxs[-1]-rxs[0])
        source_x=(xx-left)/sx+float(rxs[0])
        if id=='pixel':
            ix=np.rint(source_x).astype(int); valid=(ix>=0)&(ix<SIZE[0]); row=np.zeros_like(a[y]); row[valid]=a[y,ix[valid]]
        else:
            prem=a[y].astype(float); prem[:,:3]*=prem[:,3:4]/255
            row=np.stack([np.interp(source_x,xx,prem[:,c],left=0,right=0) for c in range(4)],axis=1)
            row[:,:3]/=np.maximum(row[:,3:4]/255,1e-9)
            row=np.clip(np.round(row),0,255).astype('uint8')
        a[y]=row
    color_gain=np.ones(3)
    if id=='wood':
        # The generated wood was slightly warmer than the original. Match the
        # median unshadowed lower-palm RGB while preserving its grain/detail.
        lo=max(0,int(bx)-45); hi=min(SIZE[0],int(bx)+45)
        source_patch=a[cut-120:cut-45,lo:hi]
        base_patch=b[cut-120:cut-45,lo:hi]
        src_values=source_patch[source_patch[:,:,3]>240,:3]
        base_values=base_patch[base_patch[:,:,3]>240,:3]
        if len(src_values) and len(base_values):
            color_gain=np.clip(np.median(base_values,axis=0)/np.maximum(np.median(src_values,axis=0),1),.8,1.25)
            for y in range(cut):
                weight=min(1.,(cut-y)/30)
                gain=1+(color_gain-1)*weight
                a[y,:,:3]=np.clip(np.round(a[y,:,:3].astype(float)*gain),0,255).astype('uint8')
    # Restore exact original cuff and rod. Blend only inside the palm over
    # 12 rows above the cuff, with straight-alpha weighted colors.
    blend=12
    for y in range(cut-blend,cut):
        t=(y-(cut-blend)+1)/(blend+1)
        ar=a[y,:,3:4]/255.; ab=b[y,:,3:4]/255.
        out_a=ar*(1-t)+ab*t
        rgb=(a[y,:,:3]*ar*(1-t)+b[y,:,:3]*ab*t)/np.maximum(out_a,1e-9)
        a[y,:,:3]=np.clip(np.round(rgb),0,255).astype('uint8')
        a[y,:,3]=np.clip(np.round(out_a[:,0]*255),0,255).astype('uint8')
    a[cut:]=b[cut:]
    a[a[:,:,3]==0,:3]=0
    return clean(Image.fromarray(a)), {'scale':scale,'translate':[tx,final_ty], 'raw_registration_y':raw_y,'base_restoration_y':cut,'base_registration_y':registration,'base_rod_x':bx, 'raw_rod_x':rx,'upper_hand_vertical_fit':top_fit,'horizontal_margin_fit':horizontal_fit,'base_hand_top_px':base_top,'original_cuff_and_rod_restored':True,'blend_rows':blend,'lower_palm_contour_blend_rows':contour_rows,'reference_color_gain_rgb':color_gain.tolist(),'raw_input_opaque_edge_pixels':clipped}

def checks(im,base,id):
    a=np.asarray(im); b=np.asarray(clean(base)); cut=RESTORE_Y[id]
    edge=np.concatenate([a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])
    ob=bbox(a[cut:,:,3]>128); bb=bbox(np.asarray(base)[cut:,:,3]>128)
    diff=max(abs(x-y) for x,y in zip(ob,bb)) if ob and bb else 9999
    mask=a[:,:,3]>128
    # OK hole and anatomy are reviewed visually, not falsely inferred from
    # alpha connectivity. Skeleton and glass can contain several real holes.
    core=Image.fromarray(np.where(a[:,:,3]>96,255,0).astype('uint8'))
    near=np.asarray(core.filter(ImageFilter.MaxFilter(5)))>0
    result={'canvas':list(im.size),'canvas_pass':im.size==SIZE,'alpha_present':im.mode=='RGBA','transparent_pixels':int((a[:,:,3]==0).sum()),'nonzero_edge_pixels':int((edge>0).sum()),'edge_pass':not bool((edge>0).any()),'cuff_stick_bbox_coordinate_note':f'y values relative to cuff top {cut}','cuff_stick_bbox':ob,'base_cuff_stick_bbox':bb,'cuff_stick_bbox_delta_px':diff,'cuff_stick_bbox_pass':diff<=3,'cuff_stick_pixel_exact':bool(np.array_equal(a[cut:],b[cut:])),'pixel_exact_reference':'cleaned base RGBA, transparent RGB zeroed','all_transparent_rgb_zero':bool((a[a[:,:,3]==0,:3]==0).all()),'alpha_residue_pixels_beyond_2px_core':int(((a[:,:,3]>0)&~near).sum()),'opaque_bbox':bbox(mask),'source_bottom_edge_trim_px':int(id in ('plush','robot'))}
    result['base_hand_top_px']=bbox(b[:,:,3]>128)[1]
    result['within_base_hand_top_crop']=result['opaque_bbox'][1]>=result['base_hand_top_px']-2
    solid=(a[cut:,:,3]>128)|(b[cut:,:,3]>128)
    result['cuff_stick_solid_pixels_exact']=bool(np.array_equal(a[cut:][solid],b[cut:][solid]))
    result['cuff_stick_pixel_difference_count']=int((a[cut:]!=b[cut:]).any(axis=2).sum())
    result['alpha_clean_pass']=result['alpha_residue_pixels_beyond_2px_core']==0
    result['pass']=all(result[k] for k in ['canvas_pass','alpha_present','edge_pass','cuff_stick_bbox_pass','cuff_stick_solid_pixels_exact','all_transparent_rgb_zero','within_base_hand_top_crop','alpha_clean_pass'])
    return result

def load_font(size):
    for path in ['/System/Library/Fonts/Supplemental/Arial.ttf','/System/Library/Fonts/Helvetica.ttc']:
        try: return ImageFont.truetype(path,size)
        except OSError: pass
    return ImageFont.load_default()

def tile(im,size,bg):
    cell=Image.new('RGBA',size,bg if bg!='checker' else '#dddddd')
    if bg=='checker':
        d=ImageDraw.Draw(cell)
        for y in range(0,size[1],12):
            for x in range(0,size[0],12):
                if (x//12+y//12)%2: d.rectangle([x,y,x+11,y+11],fill='#bcbcbc')
    if im:
        im=im.copy(); im.thumbnail(size,Image.Resampling.LANCZOS)
        cell.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
    return cell

def sheets(manifest):
    # Each row shows base|OK|Shaka repeated on light, dark and checkerboard.
    # Full canvas, including the stick. Detail sheets crop only for review.
    cw,ch=118,177; rh=212; width=9*cw+140
    for theme,bg,fg in [('light','#f5f5f7','#161619'),('dark','#1b1c20','#eeeeee')]:
        sheet=Image.new('RGB',(width,80+len(IDS)*rh),bg); d=ImageDraw.Draw(sheet)
        d.text((14,10),'Look Here Please / gesture artwork / base | OK | Shaka',font=load_font(22),fill=fg)
        for k,back in enumerate(['light','dark','checker']): d.text((140+k*3*cw,47),back,font=load_font(17),fill=fg)
        for i,id in enumerate(IDS):
            y=80+i*rh; d.text((14,y+12),id,font=load_font(18),fill=fg)
            pair=[manifest['images'].get(id+'-'+p,{}) for p in ('ok','shaka')]
            status='PASS' if all(e.get('pass') for e in pair) else 'REVIEW'
            d.text((14,y+42),status,font=load_font(12),fill=('#21915b' if status=='PASS' else '#bd7731'))
            paths=[REPO/'assets'/f'hand_{id}.png',HERE/f'{id}-ok.png',HERE/f'{id}-shaka.png']
            imgs=[Image.open(p).convert('RGBA') if p.exists() else None for p in paths]
            for group,back in enumerate(['#ffffff','#202126','checker']):
                for j,im in enumerate(imgs):
                    t=tile(im,(cw,ch),back); sheet.paste(t.convert('RGB'),(140+(group*3+j)*cw,y))
                    d.text((146+(group*3+j)*cw,y+ch+7),['base','OK','Shaka'][j],font=load_font(12),fill=fg)
        sheet.save(HERE/f'contact-sheet-{theme}.png')
    # Larger hand details, 6 materials per sheet, on three backgrounds. These
    # make finger count, material and cuff seam review practical.
    for start in range(0,len(IDS),6):
        w,h=140+9*150,6*220
        s=Image.new('RGB',(w,h),'#ededf0'); d=ImageDraw.Draw(s)
        for i,id in enumerate(IDS[start:start+6]):
            d.text((10,i*220+8),id,font=load_font(17),fill='#161619')
            paths=[REPO/'assets'/f'hand_{id}.png',HERE/f'{id}-ok.png',HERE/f'{id}-shaka.png']
            for g,bg in enumerate(['#ffffff','#202126','checker']):
                for j,p in enumerate(paths):
                    im=Image.open(p).convert('RGBA').crop((100,20,930,830)) if p.exists() else None
                    t=tile(im,(150,210),bg); s.paste(t.convert('RGB'),(140+(g*3+j)*150,i*220))
        s.save(HERE/'reviews'/f'detail-{start//6+1}.png')
    rows=[]
    for id in IDS:
        panels=[]
        for bg in ['light','dark','checker']:
            cells=[]
            for suffix,label in [('base','base'),('ok','OK'),('shaka','Shaka')]:
                src=str(REPO/'assets'/f'hand_{id}.png') if suffix=='base' else f'{id}-{suffix}.png'
                status='' if suffix=='base' else ('pass' if manifest['images'].get(f'{id}-{suffix}',{}).get('pass') else 'review')
                cells.append(f'<figure><div class="sprite {bg}"><img loading="lazy" src="{html.escape(src)}" alt="{id} {label}"></div><figcaption>{label} {status}</figcaption></figure>')
            panels.append('<div class="triple">'+''.join(cells)+'</div>')
        rows.append(f'<section id="{id}"><h2>{id}</h2><div class="backgrounds">'+''.join(panels)+'</div></section>')
    doc='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Gesture artwork review</title><style>
    *{box-sizing:border-box}body{font:14px -apple-system,BlinkMacSystemFont,sans-serif;margin:20px;color:#18181b;background:#eeeef1}h1{font-size:24px}p{max-width:85ch}h2{font-size:17px;margin:18px 0 8px}section{border-top:1px solid #c9c9d0}.backgrounds{display:flex;gap:16px;flex-wrap:wrap}.triple{display:flex;gap:3px}figure{margin:0}.sprite{width:118px;height:177px;overflow:hidden}.sprite img{width:100%;height:100%;object-fit:contain}.light{background:white}.dark{background:#202126}.checker{background:repeating-conic-gradient(#ddd 0% 25%,#bcbcbc 0% 50%) 0/20px 20px}figcaption{font-size:11px;text-align:center;margin:5px 0 12px}nav{display:flex;gap:10px;flex-wrap:wrap}a{color:#235da9}@media(max-width:500px){body{margin:12px}.sprite{width:100px;height:150px}}
    </style></head><body><h1>Gesture artwork review</h1><p>Each material shows base, OK, Shaka on light, dark and checkerboard. The full canvas preserves each original cuff and rod. Review status combines deterministic checks and manual anatomy/material review. Click an image to inspect its PNG at full resolution.</p>'''
    doc+='<nav>'+''.join(f'<a href="#{id}">{id}</a>' for id in IDS)+'</nav>'+''.join(rows)+'</body></html>'
    doc=doc.replace('<img loading="lazy" src="','<img loading="lazy" onclick="window.open(this.src)" src="')
    (HERE/'contact-sheet.html').write_text(doc)
    # A compact, self-contained-in-T3 close-up browser. The HTML preview/render
    # tools inline these absolute local thumbnail paths automatically.
    groups=[]
    for i,id in enumerate(IDS):
        cards=[]
        for pose,label in [('base','Base'),('ok','OK'),('shaka','Shaka')]:
            src=REPO/'assets'/f'hand_{id}.png' if pose=='base' else HERE/f'{id}-{pose}.png'
            thumb=HERE/'reviews'/f'thumb-{id}-{pose}.png'
            if src.exists():
                im=Image.open(src).convert('RGBA').crop((100,20,930,830)); im.thumbnail((300,300),Image.Resampling.LANCZOS); im.save(thumb)
                cards.append(f'<figure><div class="art"><img src="{html.escape(str(thumb))}" alt="{id} {label}"></div><figcaption>{label}</figcaption></figure>')
        passed=all(manifest['images'].get(f'{id}-{p}',{}).get('pass') for p in ['ok','shaka'])
        groups.append(f'<div class="group" data-hand="{id}"'+(' hidden' if i else '')+'><div class="cards">'+''.join(cards)+f'</div><p class="status">{id} / '+('passed' if passed else 'awaiting review')+'</p></div>')
    inline='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>
    *{box-sizing:border-box}body{margin:0;font:14px var(--font-sans,-apple-system,BlinkMacSystemFont,sans-serif);color:var(--foreground,#202024)}.controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:0 0 12px}select,button{font:inherit;border:1px solid var(--border,#bbb);background:var(--card,#f0f0f3);color:inherit;border-radius:6px;padding:7px 9px}button{cursor:pointer}button[aria-pressed=true]{outline:2px solid var(--ring,#668abb)}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}figure{margin:0}.art{aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;overflow:hidden;background:repeating-conic-gradient(#ddd 0% 25%,#bcbcbc 0% 50%) 0/20px 20px}.art img{width:100%;height:100%;object-fit:contain}body[data-bg=light] .art{background:#fff}body[data-bg=dark] .art{background:#202126}figcaption{text-align:center;margin-top:6px;font-size:12px}.status{color:var(--muted-foreground,#666);font-size:12px;margin:10px 0 4px}.note{color:var(--muted-foreground,#666);font-size:12px;line-height:1.5;margin:8px 0 12px}[hidden]{display:none!important}
    </style></head><body data-bg="checker"><div class="controls"><button id="previous" aria-label="Previous material">&#8592;</button><select id="material" aria-label="Hand material">'''
    inline+=''.join(f'<option value="{id}">{id}</option>' for id in IDS)
    inline+='''</select><button id="next" aria-label="Next material">&#8594;</button><button data-bg="light" aria-pressed="false">Light</button><button data-bg="dark" aria-pressed="false">Dark</button><button data-bg="checker" aria-pressed="true">Checker</button></div>'''+''.join(groups)
    inline+=f'<p class="note">{manifest.get("pairs_passed",0)} / 36 pairs accepted. Close-ups show material, finger pose and cuff alignment. The saved contact sheets show all complete canvases and rods.</p>'
    inline+='''<script>const select=document.querySelector('#material');function show(){document.querySelectorAll('.group').forEach(g=>g.hidden=g.dataset.hand!==select.value)}select.addEventListener('change',show);document.querySelector('#previous').onclick=()=>{select.selectedIndex=(select.selectedIndex+35)%36;show()};document.querySelector('#next').onclick=()=>{select.selectedIndex=(select.selectedIndex+1)%36;show()};document.querySelectorAll('button[data-bg]').forEach(b=>b.onclick=()=>{document.body.dataset.bg=b.dataset.bg;document.querySelectorAll('button[data-bg]').forEach(a=>a.setAttribute('aria-pressed',String(a===b)))});console.log('Materials:',select.options.length,'sprites:',document.images.length);</script></body></html>'''
    (HERE/'review-inline.html').write_text(inline)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--only',nargs='*'); args=parser.parse_args()
    jobs=json.loads((HERE/'generation-log.json').read_text()) if (HERE/'generation-log.json').exists() else []
    review=json.loads((HERE/'manual-review.json').read_text()) if (HERE/'manual-review.json').exists() else {}
    manifest={'version':1,'canvas':list(SIZE),'coordinate_system':'top-left PNG pixels','tool':'built-in image_gen.imagegen, edit/reference mode, transparent_background=true','review_scope':'Codex design sub-agent visual review and local PNG checks; Claude lead review pending','images':{}}
    for id in IDS:
        for pose in ['ok','shaka']:
            key=f'{id}-{pose}'; attempts=[j for j in jobs if j['id']==id and j['pose']==pose]
            base=Image.open(REPO/'assets'/f'hand_{id}.png').convert('RGBA')
            existing=HERE/f'{key}.png'
            if attempts:
                selected=review.get(key,{}).get('selected_attempt',max(j['attempt'] for j in attempts))
                job=next(j for j in attempts if j['attempt']==selected)
                if args.only is None or key in args.only:
                    im,transform=normalize(Image.open(HERE/job['raw']),base,id); im.save(existing)
                else: im=Image.open(existing); transform={}
                # Validate the serialized deliverable, not just memory pixels.
                im=Image.open(existing); im.load()
                check=checks(im,base,id); manual=review.get(key,{'pass':False,'notes':'Awaiting visual review'})
                check['raw_input_not_cropped']=not any(transform.get('raw_input_opaque_edge_pixels',{}).values())
                check['pass']=check['pass'] and check['raw_input_not_cropped']
                manifest['images'][key]={'file':existing.name,'prompt':job['prompt'],'reference':job['reference'],'reference_sha256':hashlib.sha256((REPO/job['reference']).read_bytes()).hexdigest(),'pose_reference':job['pose_reference'],'attempt_count':len(attempts),'selected_attempt':selected,'attempts':attempts,'normalization':transform,'checks':check,'manual_review':manual,'sha256':hashlib.sha256(existing.read_bytes()).hexdigest(),'pass':check['pass'] and manual.get('pass',False)}
            else:
                manifest['images'][key]={'file':existing.name,'reference':f'assets/hand_{id}.png','attempt_count':0,'checks':{'pass':False},'pass':False,'manual_review':{'pass':False,'notes':'Not yet generated'}}
    manifest['pairs_passed']=sum(all(manifest['images'][f'{id}-{p}']['pass'] for p in ['ok','shaka']) for id in IDS)
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    sheets(manifest)
    print(json.dumps({'images_generated':sum(e['attempt_count']>0 for e in manifest['images'].values()),'programmatic_passes':sum(e['checks']['pass'] for e in manifest['images'].values()),'pairs_passed':manifest['pairs_passed']}))

if __name__=='__main__':main()
