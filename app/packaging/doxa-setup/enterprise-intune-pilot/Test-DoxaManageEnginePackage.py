"""ManageEngine archive guard tests using the pinned, verified pilot."""
from pathlib import Path
import importlib.util
import tempfile
import unittest
import zipfile
from unittest.mock import patch

root=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("me_validator",root/"Verify-DoxaManageEnginePackage.py")
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class PackageGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tmp_path=Path(self.tmp.name)
        with zipfile.ZipFile(m.DEFAULT_ARCHIVE) as z:
            self.script=z.read("DoxaPilot.ps1")
            self.payload=z.read("DoxaSetupPayload.zip")
        self.original=m.EXPECTED_SHA256

    def make(self, members):
        out=self.tmp_path/"altered.zip"
        with zipfile.ZipFile(out,"w",compression=zipfile.ZIP_DEFLATED) as z:
            for name,data in members:
                z.writestr(name,data)
        return out

    def test_verified_archive_and_payload_contents(self):
        report=m.verify_archive(m.DEFAULT_ARCHIVE,run_lifecycle=False)
        self.assertEqual(report["status"],"PACKAGE_VERIFIED")
        self.assertEqual(report["sha256"],self.original)
        self.assertEqual(report["distribution_files"],
                         ["DoxaPilot.ps1","DoxaSetupPayload.zip"])
        self.assertEqual(report["actual_agent_deployment"],"NOT_PERFORMED")

    def test_altered_archive_rejected(self):
        modified=self.make([("DoxaPilot.ps1",self.script+b"# changed"),
                            ("DoxaSetupPayload.zip",self.payload)])
        with self.assertRaisesRegex(ValueError,"checksum differs"):
            m.verify_archive(modified,run_lifecycle=False)

    def test_malicious_extra_file_rejected_if_outer_hash_is_forged(self):
        altered=self.make([("DoxaPilot.ps1",self.script),
                           ("DoxaSetupPayload.zip",self.payload),
                           ("../../other.ps1",b"Bad")])
        with patch.object(m,"EXPECTED_SHA256",m.sha256(altered)):
            with self.assertRaisesRegex(ValueError,"Unexpected archive entries"):
                m.verify_archive(altered,run_lifecycle=False)

    def test_same_archive_names_but_altered_inner_payload_rejected(self):
        altered=self.make([("DoxaPilot.ps1",self.script),
                           ("DoxaSetupPayload.zip",self.payload+b"JUNK")])
        with patch.object(m,"EXPECTED_SHA256",m.sha256(altered)):
            with self.assertRaisesRegex(ValueError,"Inner Doxa payload checksum"):
                m.verify_archive(altered,run_lifecycle=False)

if __name__=="__main__":
    unittest.main(verbosity=2)
