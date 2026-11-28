#!/usr/bin/env python3
"""Explicit administrator export; never prints or transmits credentials."""
import argparse
import json
import os
from pathlib import Path
from urllib.parse import urlsplit

def export(config, endpoint, destination):
    url=urlsplit(endpoint)
    if url.scheme!='https' or not url.hostname or url.username or url.password or url.path not in ('','/') or url.query or url.fragment:
        raise ValueError('Use a trusted HTTPS origin only')
    if url.port is not None and not 1<=url.port<=65535:
        raise ValueError('Invalid HTTPS port')
    token=Path(config['token_file']).read_text().strip()
    if not 32<=len(token)<=256 or any(not 33<=ord(c)<=126 for c in token):
        raise ValueError('Invalid enrollment token')
    payload=json.dumps({'protocol':'languard-enrollment/1','endpoint':endpoint.rstrip('/'),'token':token})
    fd=os.open(destination,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as stream:stream.write(payload+'\n')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',required=True);parser.add_argument('--endpoint',required=True);parser.add_argument('--output',required=True);args=parser.parse_args()
    export(json.loads(Path(args.config).read_text()),args.endpoint,args.output)
    print('Private enrollment file created. Transfer only to the authorized management device.')
if __name__=='__main__':main()
