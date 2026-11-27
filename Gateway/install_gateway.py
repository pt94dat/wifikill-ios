#!/usr/bin/env python3
"""Install the explicit Linux gateway component; never runs on the phone.
Requires an administrator-owned config and existing trusted TLS material.
Only this application's service/advertisement files are written.
"""
import argparse
import json
import os
import re
import secrets
import shutil
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--config',default='/etc/languard/config.json')
    parser.add_argument('--check',action='store_true',help='Validate without installing or starting services')
    args=parser.parse_args()
    config_path=Path(args.config).resolve()
    if not re.fullmatch(r'/etc/languard/[A-Za-z0-9_.-]+\.json',str(config_path)):
        raise ValueError('Keep the administrator config under /etc/languard/')
    config=json.loads(config_path.read_text())
    for command in ['nft','ip','systemctl','python3']:
        if not shutil.which(command):
            raise RuntimeError('Missing prerequisite: '+command)
    for key in ['certificate','private_key']:
        if not Path(config[key]).is_file():
            raise ValueError('Supply trusted TLS material before installing: '+key)
    if not config.get('lan_interfaces') or not config.get('wan_interfaces') or not config.get('protected_macs'):
        raise ValueError('Explicit LAN/WAN paths and protected administrator MACs are required')
    port=config.get('port',8443)
    if isinstance(port,bool) or not isinstance(port,int) or not 1024<=port<=65535:
        raise ValueError('Choose a valid non-privileged HTTPS port')
    if args.check:
        print('Configuration prerequisites present; nft topology and live access still require service checks')
        return
    if os.geteuid()!=0:
        raise PermissionError('A gateway administrator must run the installer')
    token_path=Path(config['token_file']).resolve()
    if token_path.parent!=Path('/etc/languard'):
        raise ValueError('Keep the service token under /etc/languard/')
    if not token_path.exists():
        fd=os.open(token_path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as stream:
            stream.write(secrets.token_urlsafe(48)+'\n')
    os.chmod(token_path,0o600)
    os.chmod(config_path,0o600)
    root=Path(__file__).resolve().parent
    destination=Path('/opt/languard-gateway')
    destination.mkdir(mode=0o755,parents=True,exist_ok=True)
    shutil.copyfile(root/'languard_gateway.py',destination/'languard_gateway.py')
    os.chmod(destination/'languard_gateway.py',0o644)
    unit=f'''[Unit]
Description=LanGuard authorized gateway access leases
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/languard-gateway/languard_gateway.py --config {config_path}
Restart=on-failure
RestartSec=2
User=root
UMask=0077
NoNewPrivileges=yes
CapabilityBoundingSet=CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_ADMIN
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
[Install]
WantedBy=multi-user.target
'''
    Path('/etc/systemd/system/languard-gateway.service').write_text(unit)
    # Avahi watches this directory. No token or private data is advertised.
    avahi=Path('/etc/avahi/services')
    if avahi.is_dir():
        xml=f'''<?xml version="1.0" standalone="no"?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group><name replace-wildcards="yes">LanGuard on %h</name><service><type>_languard._tcp</type><port>{port}</port><txt-record>{escape('protocol=languard-gateway/1')}</txt-record></service></service-group>
'''
        (avahi/'languard-gateway.service').write_text(xml)
    subprocess.run(['systemctl','daemon-reload'],check=True)
    subprocess.run(['systemctl','enable','--now','languard-gateway.service'],check=True)
    print('Installed LanGuard gateway service. Token remains in its root-only file; enroll it securely in the app.')
    print('If Avahi is enabled, a local suggestion is advertised. Its TLS name must match the trusted certificate.')
    print('Test real client traffic before relying on enforcement. Stock firmware without these prerequisites is unsupported.')

if __name__=='__main__':
    main()
