#!/usr/bin/env python3
"""Re-run local post-processing and compare all 72 finished PNG byte hashes."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE=Path(__file__).resolve().parent
def hashes():
    manifest=json.loads((HERE/'manifest.json').read_text())
    return {key:hashlib.sha256((HERE/entry['file']).read_bytes()).hexdigest() for key,entry in manifest['images'].items()}

before=hashes()
subprocess.run([sys.executable,str(HERE/'process.py')],cwd=HERE,check=True)
after=hashes()
changed=[key for key in before if before[key]!=after[key]]
report={'images_compared':len(before),'byte_identical':len(before)-len(changed),'changed':changed,'pass':len(before)==72 and not changed,'sha256':after}
(HERE/'determinism-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='sha256'}))
raise SystemExit(0 if report['pass'] else 1)
