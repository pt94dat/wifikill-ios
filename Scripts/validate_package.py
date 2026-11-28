#!/usr/bin/env python3
"""Reject non-native, unsigned or incorrectly targeted packages before publishing."""
import hashlib
import json
import plistlib
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def verify_code_pages(data, start, length):
    signature=data[start:start+length]
    assert len(signature)>=12
    magic,total,count=struct.unpack_from('>III',signature)
    assert magic==0xfade0cc0 and total<=len(signature) and count<=128
    verified=0
    for i in range(count):
        assert 12+(i+1)*8<=total
        slot,offset=struct.unpack_from('>II',signature,12+i*8)
        assert offset+8<=total
        if struct.unpack_from('>I',signature,offset)[0]!=0xfade0c02:
            continue
        assert offset+40<=total
        header=struct.unpack_from('>9I4B',signature,offset)
        _,size,version,flags,hash_offset,identifier,special,slots,limit,hash_size,hash_type,platform,page_bits=header
        assert size>=40 and offset+size<=total and page_bits<=20
        assert 0<limit<=start and 0<hash_size<=64
        functions={1:hashlib.sha1,2:hashlib.sha256,3:hashlib.sha256,4:hashlib.sha384}
        assert hash_type in functions
        page_size=(1<<page_bits) if page_bits else limit
        assert slots==(limit+page_size-1)//page_size
        assert hash_offset+slots*hash_size<=size
        for page in range(slots):
            expected=signature[offset+hash_offset+page*hash_size:offset+hash_offset+(page+1)*hash_size]
            actual=functions[hash_type](data[page*page_size:min((page+1)*page_size,limit)]).digest()[:hash_size]
            assert actual==expected,'Executable CodeDirectory page hash mismatch'
        verified+=slots
    assert verified>0,'No verifiable executable code pages'
    return verified


def validate(package):
    package = Path(package).resolve()
    fields = {key: command('dpkg-deb', '-f', str(package), key) for key in ['Package','Version','Architecture','Depends','Maintainer']}
    assert fields['Package'] == 'com.pt94dat.wifikillios', fields
    assert fields['Architecture'] == 'iphoneos-arm', fields
    assert fields['Maintainer'] and 'firmware' in fields['Depends']
    with tempfile.TemporaryDirectory() as tmp:
        command('dpkg-deb', '-x', str(package), tmp)
        app = Path(tmp)/'Applications/LanGuard.app'
        info = plistlib.loads((app/'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == fields['Package']
        assert info['MinimumOSVersion'] == '12.0'
        if fields['Version'] in ['0.4.0-beta.1','0.5.0-beta.1','0.5.1-beta.1']:
            assert len(info.get('LGSourceCommit',''))==40, 'Source build identifier missing'
        binary = app/info['CFBundleExecutable']
        assert binary.stat().st_mode & 0o111
        data = binary.read_bytes()
        magic,cpu,subtype,filetype,ncmds,cmdsize,flags,reserved = struct.unpack_from('<8I', data)
        assert magic == 0xfeedfacf and cpu == 0x100000c and filetype == 2, 'ARM64 Mach-O executable required'
        assert len(data) > 4096 and cmdsize + 32 <= len(data)
        offset = 32
        signed = False
        minimum = None
        for _ in range(ncmds):
            cmd,size = struct.unpack_from('<II',data,offset)
            assert size >= 8 and offset+size <= 32+cmdsize
            if cmd == 0x1d:
                start,length = struct.unpack_from('<II',data,offset+8)
                assert length > 0 and start+length <= len(data)
                assert data[start:start+4] == bytes.fromhex('fade0cc0'), 'Embedded signature superblob required'
                verify_code_pages(data,start,length)
                signed = True
            if cmd == 0x25:
                minimum = struct.unpack_from('<I',data,offset+8)[0]
            if cmd == 0x32:
                platform,minimum = struct.unpack_from('<II',data,offset+8)
                assert platform == 2, 'iOS platform required'
            offset += size
        assert signed, 'Code signature load command required'
        assert minimum == (12<<16), f'Unexpected deployment target: {minimum}'
        for name in ['Icon60@2x.png','Icon60@3x.png']:
            assert (app/name).read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
        assert not list(Path(tmp).rglob('*.apk'))
        command('dpkg-deb','-e',str(package),str(Path(tmp)/'control'))
        for script in ['postinst','postrm']:
            contents=(Path(tmp)/'control'/script).read_text()
            assert 'uicache' in contents and 'curl ' not in contents
    result = {'metadata':fields,'sha256':hashlib.sha256(package.read_bytes()).hexdigest(), 'size':package.stat().st_size,'checks':'ARM64 Mach-O, iOS12 minimum, signature structure and executable page hashes, bundle, icons, permissions, install/remove scripts', 'physical_installation':'pending'}
    return result


if __name__ == '__main__':
    print(json.dumps(validate(sys.argv[1]),indent=2))
