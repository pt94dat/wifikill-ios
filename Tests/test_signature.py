import hashlib
import importlib.util
import struct
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('validate',Path(__file__).parents[1]/'Scripts/validate_package.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ExecutableIntegrityTests(unittest.TestCase):
    def fixture(self):
        code=b'Native-code-test-fixture-only'*200
        pages=[code[n:n+4096] for n in range(0,len(code),4096)]
        hashes=b''.join(hashlib.sha256(page).digest() for page in pages)
        header=struct.pack('>9I4B',0xfade0c02,40+len(hashes),0x20000,0,40,0,0,len(pages),len(code),32,2,0,12)
        directory=header+hashes
        signature=struct.pack('>III',0xfade0cc0,20+len(directory),1)+struct.pack('>II',0,20)+directory
        return code+signature,len(code),len(signature)
    def test_real_verifier_accepts_matching_page_hashes(self):
        data,start,size=self.fixture()
        self.assertGreater(module.verify_code_pages(data,start,size),0)
    def test_mutated_executable_is_rejected(self):
        data,start,size=self.fixture()
        corrupted=bytes([data[0]^1])+data[1:]
        with self.assertRaises(AssertionError):
            module.verify_code_pages(corrupted,start,size)
    def test_corrupt_signature_bounds_are_rejected(self):
        data,start,size=self.fixture()
        corrupted=data[:start+4]+struct.pack('>I',size+1000)+data[start+8:]
        with self.assertRaises(AssertionError):
            module.verify_code_pages(corrupted,start,size)
