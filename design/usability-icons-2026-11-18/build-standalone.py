"""Inline before/ and hands/ images into one offline HTML file."""
import base64, re, sys
from pathlib import Path
here = Path(__file__).resolve().parent
src = (here / 'index.html').read_text()
def data(rel):
    b = (here / rel).read_bytes()
    return 'data:image/png;base64,' + base64.b64encode(b).decode()
src = src.replace("<html lang=\"en\">", "<html lang=\"en\" data-standalone=\"1\">", 1)
out = re.sub(r'(?<=["\'])((?:before|hands)/[\w.-]+\.png)(?=["\'])', lambda m: data(m.group(1)), src)
dest = here / 'look-here-please-easier-before-after.html'
dest.write_text(out)
print(dest, len(out) // 1024, 'KB')
