import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

class NetBIOSDecoderTests(unittest.TestCase):
    def test_production_packet_parser_rejects_truncation_spoofed_transaction_and_invalid_identity(self):
        root=Path(__file__).parents[1]
        with tempfile.TemporaryDirectory() as directory:
            binary=Path(directory)/'nbns-tests'
            subprocess.run([shutil.which('cc'),'-std=c11','-Wall','-Wextra','-Werror','-DLG_NBNS_PARSER_ONLY','-I',str(root/'Sources'),str(root/'Tests/netbios_tests.c'),str(root/'Sources/Network/LGNetBIOS.c'),str(root/'Sources/Network/LGIdentity.c'),'-o',str(binary)],check=True)
            subprocess.run([str(binary)],check=True)
