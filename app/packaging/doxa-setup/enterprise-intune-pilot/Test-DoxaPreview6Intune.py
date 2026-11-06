"""One-device release-specific Intune publisher preflight regression contract."""
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("preview6",HERE/"Publish-DoxaPreview6Intune.py")
preview6=importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview6)


class Preview6IntuneContract(unittest.TestCase):
    def test_immutable_package_provenance(self):
        file, encrypted, clear_size, crypto, digest=preview6.package()
        self.assertEqual(digest,preview6.PACKAGE_SHA)
        self.assertIn("preview6-a390b0b",str(file))
        self.assertGreater(clear_size,1000)
        self.assertGreater(len(encrypted),1000)
        self.assertEqual(crypto["fileDigestAlgorithm"],"SHA256")

    def test_old_pilot_must_be_uninstall_and_only_dell_target(self):
        calls=[]
        def api(method,path,token,payload=None,params=None):
            calls.append((method,path))
            if path.endswith("/assignments"):
                return {"value":[{"intent":"uninstall"}]}
            if path.endswith(preview6.OLD_APP_ID):
                return {"displayName":"Standivarius Doxa Setup - MARIUS-DELL app-only pilot"}
            if path=="/deviceAppManagement/mobileApps":
                return {"value":[]}
            raise AssertionError("Unexpected API: "+path)
        with patch.object(preview6.pub,"tenant_id",return_value=preview6.pub.TENANT_ID),\
             patch.object(preview6.pub,"get_one_device",return_value="dell-device-guid"),\
             patch.object(preview6.pub,"members",return_value={"dell-device-guid"}),\
             patch.object(preview6.pub,"call",side_effect=api):
            device,existing=preview6.preflight("dummy-token")
        self.assertEqual(device,"dell-device-guid")
        self.assertFalse(existing)
        self.assertTrue(all(method=="GET" for method,_ in calls))

    def test_dell_scope_rejects_extra_devices(self):
        with patch.object(preview6.pub,"tenant_id",return_value=preview6.pub.TENANT_ID),\
             patch.object(preview6.pub,"get_one_device",return_value="dell-device-guid"),\
             patch.object(preview6.pub,"members",return_value={"dell-device-guid","some-other-device"}):
            with self.assertRaisesRegex(RuntimeError,"exactly one Dell"):
                preview6.preflight("dummy-token")

    def test_app_uses_isolated_system_folder_for_install_detect_and_uninstall(self):
        import base64
        from unittest.mock import patch
        import uuid
        fake_id=str(uuid.UUID("11111111-2222-4333-8444-555555555555"))
        received=[]
        with patch.object(preview6.pub,"call",side_effect=lambda method,path,token,body=None: (
            received.append((method,path,body)) or {"id":fake_id})),\
             patch.object(preview6.pub,"record_active_pilot_app_id"):
            actual=preview6.create_preview6_app("token")
        self.assertEqual(actual,fake_id)
        method,path,body=received[0]
        self.assertEqual(method,"POST")
        self.assertEqual(path,"/deviceAppManagement/mobileApps")
        self.assertIn("DoxaSetup-preview6",body["installCommandLine"])
        self.assertIn(r"C:\Program Files\Standivarius\DoxaSetup-preview6",body["installCommandLine"])
        self.assertNotIn("$env:ProgramFiles",body["installCommandLine"])
        self.assertIn("DoxaSetup-preview6",body["uninstallCommandLine"])
        self.assertIn("-Action Install",body["installCommandLine"])
        self.assertIn("-Action Uninstall",body["uninstallCommandLine"])
        detection=base64.b64decode(body["rules"][0]["scriptContent"]).decode("utf-8-sig")
        self.assertIn("DoxaSetup-preview6",detection)
        self.assertNotIn("$TargetRoot=Join-Path $pf 'Standivarius\\\\DoxaSetup'",detection)
        self.assertEqual(body["installExperience"]["runAsAccount"],"system")

    def test_source_cannot_include_driver_or_bypass_existing_assignment(self):
        src=(HERE/"Publish-DoxaPreview6Intune.py").read_text(encoding="utf-8-sig")
        self.assertIn('pub.ensure(not existing',src)
        self.assertIn('pub.assign_only_dell(',src)
        self.assertIn('pub.ensure(len(old) == 1 and old[0].get("intent") == "uninstall"',src)
        self.assertNotIn('msiexec',src.lower())
        self.assertNotIn("(Get-FileHash ",src)


if __name__=="__main__":
    unittest.main(verbosity=2)
