#!/usr/bin/env python3
"""Real isolated Linux network-namespace integration test; no physical Internet claim.
Requires root on a disposable Linux CI VM. All links/routes/nft changes live in
named test namespaces; production interfaces and the host firewall are untouched.
"""
import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
NAMES=['lgw-audit','lgt-audit','lga-audit','lww-audit']
GW,TARGET,ADMIN,WAN=NAMES
PROCESSES=[]
RESULTS=[]


def run(args,*,check=True,**kwargs):
    result=subprocess.run(args,check=False,capture_output=True,text=True,timeout=15,**kwargs)
    if check and result.returncode:
        raise RuntimeError('Lab command failed: '+args[0]+' '+result.stderr[-2000:])
    return result


def ns(name,args,**kwargs):
    return run(['ip','netns','exec',name,*args],**kwargs)


def check(name,condition):
    if not condition:
        raise AssertionError(name)
    RESULTS.append({'test':name,'passed':True})
    print('PASS',name,flush=True)


def link(peer,name,mac,ip4,ip6):
    run(['ip','link','add',name,'type','veth','peer','name',name+'p'])
    run(['ip','link','set',name,'netns',GW])
    run(['ip','link','set',name+'p','netns',peer])
    ns(peer,['ip','link','set',name+'p','name','eth0'])
    ns(peer,['ip','link','set','eth0','address',mac])
    ns(peer,['ip','addr','add',ip4,'dev','eth0'])
    ns(peer,['ip','-6','addr','add',ip6,'dev','eth0','nodad'])
    ns(peer,['ip','link','set','eth0','up'])
    ns(GW,['ip','link','set',name,'up'])
    if peer!=WAN:
        ns(GW,['ip','link','set',name,'master','br-lan'])
        ns(peer,['ip','route','add','default','via','192.0.2.1'])
        ns(peer,['ip','-6','route','add','default','via','2001:db8:1::1'])
    else:
        ns(GW,['ip','addr','add','198.51.100.1/24','dev',name])
        ns(GW,['ip','-6','addr','add','2001:db8:2::1/64','dev',name,'nodad'])
        ns(peer,['ip','route','add','default','via','198.51.100.1'])
        ns(peer,['ip','-6','route','add','default','via','2001:db8:2::1'])


def reachable(peer,ipv6=False):
    host='[2001:db8:2::2]' if ipv6 else '198.51.100.2'
    r=ns(peer,['curl','--noproxy','*','--silent','--max-time','1',f'http://{host}:18080/'],check=False)
    return r.returncode==0 and 'languard-lab-ok' in r.stdout


def main():
    assert os.geteuid()==0,'Use root only on a disposable CI VM'
    temporary=tempfile.TemporaryDirectory(prefix='languard-lab-')
    directory=Path(temporary.name)
    try:
        for name in NAMES:
            run(['ip','netns','add',name])
            ns(name,['ip','link','set','lo','up'])
        ns(GW,['sysctl','-qw','net.ipv4.ip_forward=1'])
        ns(GW,['sysctl','-qw','net.ipv6.conf.all.forwarding=1'])
        ns(GW,['ip','link','add','br-lan','type','bridge'])
        ns(GW,['ip','link','set','br-lan','address','02:00:00:00:00:01'])
        ns(GW,['ip','addr','add','192.0.2.1/24','dev','br-lan'])
        ns(GW,['ip','-6','addr','add','2001:db8:1::1/64','dev','br-lan','nodad'])
        ns(GW,['ip','link','set','br-lan','up'])
        link(TARGET,'lt0','02:00:00:00:00:04','192.0.2.10/24','2001:db8:1::10/64')
        link(ADMIN,'la0','02:00:00:00:00:03','192.0.2.20/24','2001:db8:1::20/64')
        link(WAN,'wan0','02:00:00:00:00:05','198.51.100.2/24','2001:db8:2::2/64')
        ns(GW,['nft','-f','-'],input='table inet unrelated_test {\n chain forward {\n type filter hook forward priority 0; policy accept;\n counter\n }\n}\n')
        (directory/'index.html').write_text('languard-lab-ok')
        server=subprocess.Popen(['ip','netns','exec',WAN,sys.executable,'-m','http.server','18080','--bind','::','--directory',str(directory)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        PROCESSES.append(server)
        # Short settling interval is for namespace link setup only, not fabricated app progress.
        time.sleep(1)
        check('baseline_target_ipv4',reachable(TARGET))
        check('baseline_target_ipv6',reachable(TARGET,True))
        check('baseline_admin_ipv4',reachable(ADMIN))
        check('baseline_admin_ipv6',reachable(ADMIN,True))
        run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-keyout',str(directory/'key.pem'),'-out',str(directory/'cert.pem'),'-subj','/CN=LanGuard isolated lab','-addext','subjectAltName=IP:192.0.2.1'])
        token=secrets.token_urlsafe(48)
        (directory/'token').write_text(token)
        os.chmod(directory/'token',0o600)
        config={'listen_address':'192.0.2.1','port':18443,'lan_interfaces':['br-lan'],'wan_interfaces':['wan0'],'protected_macs':['02:00:00:00:00:03'],'token_file':str(directory/'token'),'certificate':str(directory/'cert.pem'),'private_key':str(directory/'key.pem')}
        (directory/'config.json').write_text(json.dumps(config))
        log=(directory/'agent.log').open('w')
        agent=subprocess.Popen(['ip','netns','exec',GW,sys.executable,str(ROOT/'Gateway/languard_gateway.py'),'--config',str(directory/'config.json')],stdout=log,stderr=log)
        PROCESSES.append(agent)
        def api(method,path,body=None,authorized=True):
            args=['curl','--noproxy','*','--silent','--show-error','--max-time','3','--cacert',str(directory/'cert.pem'),'-X',method,'--write-out','\n%{http_code}']
            if authorized:
                args+=['-H','Authorization: Bearer '+token]
            if body is not None:
                args+=['-H','Content-Type: application/json','--data',json.dumps(body)]
            result=ns(ADMIN,args+['https://192.0.2.1:18443'+path],check=False)
            if result.returncode:
                return 0,{}
            payload,status=result.stdout.rsplit('\n',1)
            return int(status),json.loads(payload)
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            status,cap=api('GET','/v1/capabilities')
            if status==200:
                break
            if agent.poll() is not None:
                raise RuntimeError('Gateway startup failed: '+(directory/'agent.log').read_text()[-3000:])
            time.sleep(.2)
        check('authenticated_tls_capabilities',status==200 and cap['management_authorized'])
        status,_=api('PUT','/v1/restrictions/02:00:00:00:00:04',{'ip':'192.0.2.10','seconds':30},False)
        check('unauthenticated_put_rejected',status==401 and reachable(TARGET))
        status,_=api('PUT','/v1/restrictions/02:00:00:00:00:03',{'ip':'192.0.2.20','seconds':30})
        check('management_host_protected',status==403 and reachable(ADMIN))
        status,_=api('PUT','/v1/restrictions/02:00:00:00:00:01',{'ip':'192.0.2.1','seconds':30})
        check('gateway_protected',status==403)
        status,result=api('PUT','/v1/restrictions/02:00:00:00:00:04',{'ip':'192.0.2.10','seconds':30})
        check('kill_router_readback',status==200 and result['restricted'] and result['router_verified'] and not result['end_to_end_verified'])
        check('target_routed_ipv4_restricted',not reachable(TARGET))
        check('target_routed_ipv6_restricted',not reachable(TARGET,True))
        check('target_lan_link_unchanged','UP' in json.loads(ns(TARGET,['ip','-j','link','show','eth0']).stdout)[0]['flags'])
        check('unrelated_admin_still_reachable',reachable(ADMIN) and reachable(ADMIN,True))
        status,result=api('DELETE','/v1/restrictions/02:00:00:00:00:04')
        check('unkill_router_readback',status==200 and result['router_verified'] and not result['restricted'])
        check('target_ipv4_restored',reachable(TARGET))
        check('target_ipv6_restored',reachable(TARGET,True))
        api('PUT','/v1/restrictions/02:00:00:00:00:04',{'ip':'192.0.2.10','seconds':30})
        check('lease_restriction_active',not reachable(TARGET))
        # SIGKILL intentionally skips graceful cleanup: the real kernel timeout must restore access.
        agent.kill();agent.wait(timeout=5)
        deadline=time.monotonic()+35
        while time.monotonic()<deadline and not reachable(TARGET):
            time.sleep(.5)
        check('kernel_expiry_restores_after_agent_crash',reachable(TARGET) and reachable(TARGET,True))
        check('unrelated_firewall_table_preserved','unrelated_test' in ns(GW,['nft','-j','list','table','inet','unrelated_test']).stdout)
        report={'kind':'real isolated Linux network namespace integration','physical_iphone_tested':False,'public_internet_tested':False,'results':RESULTS}
        (ROOT/'build').mkdir(exist_ok=True)
        (ROOT/'build/gateway-lab-results.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report,indent=2))
    finally:
        for process in reversed(PROCESSES):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill();process.wait()
        for name in reversed(NAMES):
            run(['ip','netns','del',name],check=False)
        temporary.cleanup()

if __name__=='__main__':
    main()
