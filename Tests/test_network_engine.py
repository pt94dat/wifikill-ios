import os
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class NetworkEngineTests(unittest.TestCase):
    def run_c(self, fixture, sources, extra=()):
        with tempfile.TemporaryDirectory() as d:
            binary=Path(d)/'test'
            subprocess.run(['cc','-std=c11','-D_POSIX_C_SOURCE=200809L','-Wall','-Wextra','-Werror','-fsanitize=address,undefined','-I',str(ROOT/'Sources'),'-I',str(ROOT/'Tests'),*extra,str(ROOT/'Tests'/fixture),*[str(ROOT/s) for s in sources],'-o',str(binary)],check=True)
            subprocess.run([str(binary)],check=True,env={**os.environ,"ASAN_OPTIONS":"detect_leaks=0"})
    def test_production_darwin_parser(self):
        self.run_c('neighbor_parser_tests.c',['Sources/Network/LGNeighborParser.c','Sources/Network/LGIdentity.c'])
    def test_production_resolver_outcomes_and_cleanup(self):
        self.run_c('resolver_tests.c',['Sources/Network/LGResolver.c','Sources/Network/LGIdentity.c'],['-DLG_RESOLVER_TEST'])

    def test_late_resolution_budget_matrix_and_cancellation(self):
        self.run_c('resolver_timing_tests.c',['Sources/Network/LGResolver.c','Sources/Network/LGIdentity.c'],['-DLG_RESOLVER_TEST','-pthread'])
