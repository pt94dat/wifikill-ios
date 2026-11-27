#!/usr/bin/env python3
import email.utils
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import tarfile
from pathlib import Path
from validate_package import validate

root=Path(__file__).resolve().parents[1]
out=root/'build/repository'
if out.exists():
    shutil.rmtree(out)
shutil.copytree(root/'Website',out)
(out/'debs').mkdir()
packages=sorted((root/'build/retained').glob('*.deb'))+sorted((root/'packages').glob('*.deb'))
packages=list({p.name:p for p in packages}.values())
assert packages, 'No compiled packages; refusing to publish'
entries=[]
retained_file=root/'build/retained/releases.json'
retained=json.loads(retained_file.read_text()) if retained_file.exists() else []
current_versions={subprocess.check_output(['dpkg-deb','-f',str(p),'Version'],text=True).strip() for p in (root/'packages').glob('*.deb')}
releases=[]
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
    previous=next((r for r in retained if r['version']==version),None)
    metadata=previous or {'name':'LanGuard','version':version,'package':'debs/'+package.name,'sha256':result['sha256'],'source_commit':os.environ.get('GITHUB_SHA',subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()),'gateway_bundle':'gateway/languard-gateway-0.3.0-beta.1.tar.gz','physical_device_tests':'pending','access_control':'Compatible configured HTTPS gateway agent required. Router rule readback and target Internet verification are separate.'}
    assert metadata['sha256']==result['sha256'],'Refusing to replace an immutable published version'
    releases.append(metadata)
    (out/('validation-'+version+'.json')).write_text(json.dumps(result,indent=2))
    if version in current_versions:
        (out/'release.json').write_text(json.dumps(metadata,indent=2))
        (out/'package-validation.json').write_text(json.dumps(result,indent=2))
assert (out/'release.json').exists()
(out/'releases.json').write_text(json.dumps(releases,indent=2))
# Distribute the actual optional Linux gateway component separately from the iOS package.
(out/'gateway').mkdir(exist_ok=True)
gateway_archive=out/'gateway/languard-gateway-0.3.0-beta.1.tar.gz'
with tarfile.open(gateway_archive,'w:gz') as archive:
    for source in ['Gateway/languard_gateway.py','Gateway/install_gateway.py','Gateway/config.example.json','Gateway/README.md','Gateway/service/languard-gateway.service','Gateway/service/languard-gateway-avahi.service','LICENSE']:
        archive.add(root/source,arcname=source)
(out/'gateway/SHA256SUMS').write_text(hashlib.sha256(gateway_archive.read_bytes()).hexdigest()+'  '+gateway_archive.name+'\n')
if (root/'build/gateway-lab-results.json').exists():
    shutil.copy2(root/'build/gateway-lab-results.json',out/'gateway-lab-results.json')
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
