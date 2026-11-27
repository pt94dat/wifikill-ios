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
    result = {'metadata':fields,'sha256':hashlib.sha256(package.read_bytes()).hexdigest(), 'size':package.stat().st_size,'checks':'ARM64 Mach-O, iOS12 minimum, signature structure, bundle, icons, permissions, install/remove scripts', 'physical_installation':'pending'}
    return result


if __name__ == '__main__':
    print(json.dumps(validate(sys.argv[1]),indent=2))
