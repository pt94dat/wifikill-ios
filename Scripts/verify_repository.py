#!/usr/bin/env python3
import gzip
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

base=sys.argv[1].rstrip('/')+'/'
def read(name):
    if base.startswith('https://'):
        with urllib.request.urlopen(base+name,timeout=30) as response:
            return response.read()
    return (Path(base)/name).read_bytes()

release=read('Release').decode()
packages=read('Packages')
assert gzip.decompress(read('Packages.gz')) == packages
for name in ['Packages','Packages.gz']:
    data=read(name)
    assert f'{hashlib.sha256(data).hexdigest()} {len(data)} {name}' in release
for paragraph in packages.decode().strip().split('\n\n'):
    fields=dict(line.split(': ',1) for line in paragraph.splitlines() if ': ' in line and not line.startswith(' '))
    assert fields['Architecture']=='iphoneos-arm'
    data=read(fields['Filename'])
    assert len(data)==int(fields['Size'])
    assert hashlib.sha256(data).hexdigest()==fields['SHA256']
    assert data.startswith(b'!<arch>\n')
metadata=json.loads(read('release.json'))
assert read(metadata['package'])
assert read('index.html') and read('icon.png')
print('Repository files, compression, sizes, architecture and SHA-256 verified. Physical Sileo installation pending.')
