#!/usr/bin/env python3
import email.utils
import gzip
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path
from validate_package import validate

root=Path(__file__).resolve().parents[1]
out=root/'build/repository'
if out.exists():
    shutil.rmtree(out)
shutil.copytree(root/'Website',out)
(out/'debs').mkdir()
packages=sorted((root/'packages').glob('*.deb'))
assert packages, 'No compiled packages; refusing to publish'
entries=[]
for package in packages:
    result=validate(package)
    target=out/'debs'/package.name
    shutil.copy2(package,target)
    control=subprocess.check_output(['dpkg-deb','-f',str(package)],text=True).strip()
    data=target.read_bytes()
    entry=control+'\nFilename: debs/'+package.name+'\nSize: '+str(len(data))+'\n'
    for field,fn in [('MD5sum',hashlib.md5),('SHA256',hashlib.sha256),('SHA512',hashlib.sha512)]:
        entry+=field+': '+fn(data).hexdigest()+'\n'
    entry+='Depiction: https://pt94dat.github.io/wifikill-ios/\n'
    entries.append(entry)
    version=result['metadata']['Version']
    (out/'release.json').write_text(json.dumps({'name':'LanGuard','version':version,'package':'debs/'+package.name,'sha256':result['sha256'],'source_commit':os.environ.get('GITHUB_SHA',subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()),'physical_device_tests':'pending','access_control':'Compatible opt-in Linux/nftables gateway agent only; router rules verified, end-to-end Internet tests pending'},indent=2))
    (out/'package-validation.json').write_text(json.dumps(result,indent=2))
(out/'Packages').write_text('\n'.join(entries)+'\n')
with (out/'Packages.gz').open('wb') as f:
    with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0) as g:
        g.write((out/'Packages').read_bytes())
release='Origin: pt94dat\nLabel: LanGuard\nSuite: stable\nCodename: languard\nArchitectures: iphoneos-arm\nComponents: main\nDescription: LanGuard native iOS beta repository\nDate: '+email.utils.formatdate(usegmt=True)+'\n'
for label,fn in [('MD5Sum',hashlib.md5),('SHA256',hashlib.sha256),('SHA512',hashlib.sha512)]:
    release+=label+':\n'
    for name in ['Packages','Packages.gz']:
        data=(out/name).read_bytes()
        release+=f' {fn(data).hexdigest()} {len(data)} {name}\n'
(out/'Release').write_text(release)
(out/'.nojekyll').touch()
shutil.copyfile(root/'Resources/Icon60@2x.png',out/'CydiaIcon.png')
shutil.copyfile(root/'Resources/Icon1024.png',out/'icon.png')
print(out)
