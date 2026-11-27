import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

class IdentityRegressionTests(unittest.TestCase):
    def test_production_c_identity_subnet_and_dns_decoder(self):
        root=Path(__file__).parents[1]
        compiler=os.environ.get('CC') or shutil.which('cc') or shutil.which('gcc')
        self.assertIsNotNone(compiler,'C compiler required')
        with tempfile.TemporaryDirectory() as directory:
            executable=Path(directory)/'identity-tests'
            subprocess.run([compiler,'-std=c11','-Wall','-Wextra','-Werror','-I',str(root/'Sources'),str(root/'Tests/identity_tests.c'),str(root/'Sources/Network/LGIdentity.c'),'-o',str(executable)],check=True)
            subprocess.run([str(executable)],check=True)
