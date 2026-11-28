import tempfile
import time
from pathlib import Path
import unittest
from test_gateway import KernelFixture, m
class DHCPInventoryTests(unittest.TestCase):
    def setUp(self):
        self.gateway=m.Gateway({"lan_interfaces":["lan0"],"wan_interfaces":["wan0"],"protected_macs":["02:00:00:00:00:03"]},KernelFixture())
    def test_real_file_inventory_filters_and_retains_private_mac(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'leases'
            path.write_text(f'{int(time.time())+300} 02:11:22:33:44:55 192.0.2.20 owned-printer *\n1 00:11:22:33:44:55 192.0.2.21 expired *\n0 02:00:00:00:00:00 192.0.2.22 placeholder *\n0 00:11:22:33:44:56 192.0.3.20 wrong-network *\n')
            self.gateway.config.update(dnsmasq_lease_files=[str(path)],inventory_networks=['192.0.2.0/24'])
            rows=self.gateway.devices();lease=next(r for r in rows if r['dst']=='192.0.2.20')
            self.assertEqual(lease['lladdr'],'02:11:22:33:44:55');self.assertEqual(lease['hostname'],'owned-printer');self.assertEqual(lease['source'],'dnsmasq');self.assertEqual(len(rows),3)
            with self.assertRaises(ValueError):
                self.gateway.validate_target(lease['lladdr'],lease['dst'],'192.0.2.2')
    def test_conflicting_leases_do_not_create_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'leases';path.write_text('0 00:11:22:33:44:55 192.0.2.20 first *\n0 00:11:22:33:44:56 192.0.2.20 second *\n')
            self.gateway.config.update(dnsmasq_lease_files=[str(path)],inventory_networks=['192.0.2.0/24'])
            self.assertFalse(any(r['dst']=='192.0.2.20' for r in self.gateway.devices()))
    def test_missing_scope_rejected(self):
        self.gateway.config['dnsmasq_lease_files']=['/nonexistent']
        with self.assertRaises(ValueError):self.gateway.devices()
