#!/usr/bin/env python3
"""Read and audit all finished PNGs without regenerating or changing them."""
import hashlib
import json
from pathlib import Path
from PIL import Image
import numpy as np
from process import HERE, REPO, IDS, checks

def main():
    manifest=json.loads((HERE/'manifest.json').read_text())
    images={}
    for id in IDS:
        for pose in ['ok','shaka']:
            key=f'{id}-{pose}'; meta=manifest['images'][key]; path=HERE/f'{key}.png'
            if not path.exists():
                images[key]={'pass':False,'error':'Missing output'}; continue
            with Image.open(path) as saved:
                saved.load()
                result=checks(saved,Image.open(REPO/f'assets/hand_{id}.png').convert('RGBA'),id)
            result['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            result['hash_matches_manifest']=result['sha256']==meta['sha256']
            result['reference_hash_matches_manifest']=hashlib.sha256((REPO/meta['reference']).read_bytes()).hexdigest()==meta['reference_sha256']
            job=next(j for j in meta['attempts'] if j['attempt']==meta['selected_attempt'])
            a=np.asarray(Image.open(HERE/job['raw']).convert('RGBA'))[:,:,3]
            result['raw_input_not_cropped']=not bool((a[0]>128).any() or (a[:,0]>128).any() or (a[:,-1]>128).any())
            result['manual_pass']=meta['manual_review'].get('pass',False)
            result['pass']=all(result[k] for k in ['pass','hash_matches_manifest','reference_hash_matches_manifest','raw_input_not_cropped','manual_pass'])
            images[key]=result
    report={'outputs':len(images),'passed':sum(v['pass'] for v in images.values()),'pairs_passed':sum(all(images[f'{id}-{p}']['pass'] for p in ['ok','shaka']) for id in IDS),'failures':[k for k,v in images.items() if not v['pass']],'images':images}
    (HERE/'audit-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='images'}))
    raise SystemExit(0 if report['passed']==72 else 1)

if __name__=='__main__':main()
