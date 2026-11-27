import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
spec = importlib.util.spec_from_file_location('gateway', Path(__file__).parents[1]/'Gateway/languard_gateway.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class KernelFixture:
    """Explicit unit-test double; never used by app or release gateway."""
    def __init__(self):
        self.elements = set()
        self.commands = []
        self.offload = False
        self.fail = False

    def __call__(self, args, **kw):
        self.commands.append((args, kw.get('input')))
        if self.fail:
            return subprocess.CompletedProcess(args, 1, '', 'test failure')
        data = {}
        if args == ['ip', '-j', 'link', 'show']:
            data = [{'ifname':'lan0','address':'02:00:00:00:00:01'}, {'ifname':'wan0','address':'02:00:00:00:00:02'}]
        elif args == ['ip', '-j', 'neigh', 'show']:
            data = [{'dst':'192.0.2.2','lladdr':'02:00:00:00:00:03','dev':'lan0','state':['REACHABLE']}, {'dst':'192.0.2.3','lladdr':'02:00:00:00:00:04','dev':'lan0','state':['STALE']}]
        elif args[-2:] == ['list', 'ruleset']:
            data = {'nftables':[{'flowtable':{}}] if self.offload else []}
        elif args[:4] == ['nft','-j','list','set']:
            data = {'nftables':[{'set':{'elem':[{'elem':{'val':x,'expires':290000}} for x in sorted(self.elements)]}}]}
        elif args == ['nft','-f','-']:
            text = kw['input']
            for line in text.splitlines():
                if line.startswith('add element'):
                    self.elements.add(line.split('{ ')[1].split()[0])
                if line.startswith('delete element'):
                    self.elements.discard(line.split('{ ')[1].split()[0])
                if line.startswith('flush set'):
                    self.elements.clear()
        return subprocess.CompletedProcess(args, 0, json.dumps(data), '')


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.kernel = KernelFixture()
        self.gateway = m.Gateway({'lan_interfaces':['lan0'],'wan_interfaces':['wan0'],'protected_macs':['02:00:00:00:00:03']}, self.kernel)

    def test_restrict_readback_and_restore(self):
        r = self.gateway.restrict('02:00:00:00:00:04','192.0.2.3',300,'192.0.2.2')
        self.assertTrue(r['router_verified'])
        self.assertFalse(r['end_to_end_verified'])
        self.assertTrue(self.gateway.restore('02:00:00:00:00:04')['router_verified'])

    def test_host_protected(self):
        with self.assertRaises(PermissionError):
            self.gateway.restrict('02:00:00:00:00:03','192.0.2.2',300,'192.0.2.2')

    def test_mapping_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            self.gateway.restrict('02:00:00:00:00:04','192.0.2.8',300,'192.0.2.2')

    def test_remote_management_rejected(self):
        with self.assertRaises(PermissionError):
            self.gateway.restrict('02:00:00:00:00:04','192.0.2.3',300,'198.51.100.9')

    def test_lease_bounds(self):
        for duration in [0,-1,901,True,'300']:
            with self.assertRaises(ValueError):
                self.gateway.restrict('02:00:00:00:00:04','192.0.2.3',duration,'192.0.2.2')

    def test_shutdown_refuses_late_restriction(self):
        self.gateway.stopping = True
        with self.assertRaises(RuntimeError):
            self.gateway.restrict("02:11:22:33:44:55", "192.0.2.20", 300, "192.0.2.10")

    def test_command_injection(self):
        for value in ['00:11:22:33:44:55; reboot','ff:ff:ff:ff:ff:ff','00:00:00:00:00:00']:
            with self.assertRaises(ValueError):
                self.gateway.restore(value)

    def test_offload_fail_closed(self):
        self.kernel.offload = True
        with self.assertRaises(ValueError):
            self.gateway.restrict('02:00:00:00:00:04','192.0.2.3',300,'192.0.2.2')
        self.assertFalse(self.kernel.elements)

    def test_kernel_error_not_success(self):
        self.kernel.fail = True
        with self.assertRaises(RuntimeError):
            self.gateway.restore()

    def test_restore_all(self):
        self.kernel.elements = {'02:00:00:00:00:04'}
        self.assertTrue(self.gateway.restore()['router_verified'])
        self.assertFalse(self.kernel.elements)

    def test_duplicate_lease_refresh(self):
        for _ in range(2):
            self.gateway.restrict('02:00:00:00:00:04','192.0.2.3',300,'192.0.2.2')
        self.assertEqual(len(self.kernel.elements),1)

    def test_interface_injection_rejected(self):
        with self.assertRaises(ValueError):
            m.Gateway({'lan_interfaces':['x;reboot'],'wan_interfaces':['wan0'],'protected_macs':['02:00:00:00:00:03']})

    def test_install_timed_set_and_early_forward_hook(self):
        self.gateway.install()
        script = self.kernel.commands[-1][1]
        self.assertIn('flags timeout', script)
        self.assertIn('priority -100', script)
        self.assertIn('ether saddr @blocked', script)


class HTTPBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import threading
        from http.server import ThreadingHTTPServer
        cls.kernel=KernelFixture()
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),m.Handler)
        cls.server.token='test-only-enrolled-token-not-for-deployment'
        cls.server.gateway=m.Gateway({'lan_interfaces':['lan0'],'wan_interfaces':['wan0'],'protected_macs':['02:00:00:00:00:03']},cls.kernel)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self,method,path,body=None,token=None):
        import http.client
        client=http.client.HTTPConnection('127.0.0.1',self.server.server_port,timeout=3)
        headers={'Authorization':'Bearer '+token} if token is not None else {}
        client.request(method,path,body=body,headers=headers)
        response=client.getresponse()
        result=(response.status,json.loads(response.read()))
        client.close()
        return result

    def test_unauthenticated_control_rejected(self):
        self.kernel.elements={'02:00:00:00:00:04'}
        code,_=self.request('DELETE','/v1/restrictions')
        self.assertEqual(code,401)
        self.assertTrue(self.kernel.elements)

    def test_wrong_token_rejected(self):
        code,_=self.request('GET','/v1/capabilities',token='wrong')
        self.assertEqual(code,401)

    def test_authenticated_capability_response(self):
        code,data=self.request('GET','/v1/capabilities',token=self.server.token)
        self.assertEqual(code,200)
        self.assertEqual(data['protocol'],'languard-gateway/1')
        self.assertFalse(data['end_to_end_verification'])

    def test_invalid_json_and_oversize_rejected(self):
        for body in ['{broken','x'*2049,'[]']:
            code,_=self.request('PUT','/v1/restrictions/02:00:00:00:00:04',body,self.server.token)
            self.assertEqual(code,400)

    def test_unknown_control_path_rejected(self):
        code,_=self.request('PUT','/not-a-control-api','{}',self.server.token)
        self.assertEqual(code,404)

class PlaceholderRegressionTests(unittest.TestCase):
    def test_placeholder_mapping_cannot_be_control_target(self):
        with self.assertRaises(ValueError):
            m.mac_value('02:00:00:00:00:00')

    def test_valid_private_mac_is_not_blanket_rejected(self):
        self.assertEqual(m.mac_value('02:00:00:00:00:01'),'02:00:00:00:00:01')

if __name__ == '__main__':
    unittest.main()
