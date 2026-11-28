import importlib.util
import json
import stat
import tempfile
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('export_enrollment',Path(__file__).parents[1]/'Gateway/export_enrollment.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class EnrollmentExportTests(unittest.TestCase):
    def test_private_export_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            token=Path(directory)/'token';token.write_text('a'*48);dest=Path(directory)/'enrollment.json';m.export({'token_file':str(token)},'https://gateway.example:8443',dest)
            self.assertEqual(stat.S_IMODE(dest.stat().st_mode),0o600);self.assertEqual(json.loads(dest.read_text())['token'],'a'*48)
            with self.assertRaises(FileExistsError):m.export({'token_file':str(token)},'https://gateway.example:8443',dest)
    def test_non_origin_rejected(self):
        for endpoint in ['http://gateway.example','https://user:secret@gateway.example','https://gateway.example/path','https://gateway.example/?token=x']:
            with self.assertRaises(ValueError):m.export({},endpoint,'not-written')
