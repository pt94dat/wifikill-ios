import socket
import struct
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
class NetBIOSTransportTests(unittest.TestCase):
    def test_actual_production_query_against_owned_loopback_responder(self):
        root=Path(__file__).resolve().parents[1]
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as server, tempfile.TemporaryDirectory() as directory:
            server.bind(('127.0.0.1',0));server.settimeout(3);port=server.getsockname()[1]
            binary=Path(directory)/'client'
            subprocess.run(['cc','-std=c11','-D_DEFAULT_SOURCE',f'-DLG_NBNS_TEST_PORT={port}','-Wall','-Wextra','-Werror','-I',str(root/'Sources'),str(root/'Tests/netbios_query_test.c'),str(root/'Sources/Network/LGNetBIOS.c'),str(root/'Sources/Network/LGIdentity.c'),'-o',str(binary)],check=True)
            failures=[]
            def reply():
                try:
                    query,peer=server.recvfrom(512)
                    assert len(query)==50
                    status=b'\x01'+b'OWNED-FIXTURE'.ljust(15,b' ')+b'\x00'+b'\x04\x00'+bytes.fromhex('021122334455')
                    packet=query[:2]+struct.pack('!HHHHH',0x8400,0,1,0,0)+query[12:46]+struct.pack('!HHIH',0x21,1,60,len(status))+status
                    server.sendto(packet,peer)
                except Exception as e:failures.append(str(e))
            worker=threading.Thread(target=reply);worker.start()
            subprocess.run([str(binary)],check=True);worker.join(timeout=4)
            self.assertFalse(worker.is_alive());self.assertEqual(failures,[])
