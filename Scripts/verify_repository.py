#!/usr/bin/env python3
import gzip
import hashlib
import json
import sys
import os
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
current_data=read(metadata['package'])
assert hashlib.sha256(current_data).hexdigest()==metadata['sha256']
expected_version=os.environ.get('EXPECTED_VERSION')
expected_commit=os.environ.get('EXPECTED_COMMIT')
if expected_version:
    assert metadata['version']==expected_version,metadata
if expected_commit:
    assert metadata['source_commit']==expected_commit,metadata
if metadata.get('gateway_bundle'):
    gateway_data=read(metadata['gateway_bundle'])
    sums=read('gateway/SHA256SUMS').decode()
    assert hashlib.sha256(gateway_data).hexdigest() in sums
print('VERIFIED_RELEASE_METADATA',json.dumps(metadata,sort_keys=True))
assert read('index.html') and read('icon.png')
print('Repository files, compression, sizes, architecture and SHA-256 verified. Physical Sileo installation pending.')
