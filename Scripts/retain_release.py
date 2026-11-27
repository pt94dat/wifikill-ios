#!/usr/bin/env python3
"""Retain checksum-validated published packages. Never execute package contents."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import urljoin
from validate_package import validate
ROOT=Path(__file__).resolve().parents[1]
BASE='https://pt94dat.github.io/wifikill-ios/'
DEST=ROOT/'build/retained'
def fetch(path,optional=False):
    result=subprocess.run(['curl','--silent','--show-error','--location','--max-time','30','--proto','=https','--max-redirs','2','--write-out','\n%{http_code}',urljoin(BASE,path)],capture_output=True,check=True)
    body,code=result.stdout.rsplit(b'\n',1)
    if optional and code==b'404':
        return None
    if code!=b'200':
        raise RuntimeError('Unable to retain published release: HTTP '+code.decode())
    if len(body)>5*1024*1024:
        raise ValueError('Retention object too large')
    return body
def main():
    DEST.mkdir(parents=True,exist_ok=True)
    raw=fetch('releases.json',optional=True)
    if raw is None:
        first=fetch('release.json',optional=True)
        if first is None:
            print('No previous published release')
            return
        releases=[json.loads(first)]
    else:
        releases=json.loads(raw)
    assert isinstance(releases,list) and len(releases)<=20
    retained=[]
    for release in releases[-5:]:
        path=release['package']
        assert re.fullmatch(r'debs/com\.pt94dat\.wifikillios_[0-9A-Za-z.+~_-]+_iphoneos-arm\.deb',path)
        expected=release['sha256']
        assert re.fullmatch('[0-9a-f]{64}',expected)
        data=fetch(path)
        assert hashlib.sha256(data).hexdigest()==expected,'Published package checksum mismatch'
        target=DEST/Path(path).name
        target.write_bytes(data)
        result=validate(target)
        assert result['metadata']['Version']==release['version']
        retained.append(release)
    (DEST/'releases.json').write_text(json.dumps(retained,indent=2))
    print('Retained',len(retained),'validated previous releases')
if __name__=='__main__':
    main()
