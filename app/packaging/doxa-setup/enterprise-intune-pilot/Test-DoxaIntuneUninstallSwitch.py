"""Offline guards: no uninstall until Dell app really installed; no other devices."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

p=Path(__file__).with_name("Switch-DoxaIntunePilotToUninstall.py")
spec=importlib.util.spec_from_file_location("doxa_uninstall_switch",p)
subject=importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)

class UninstallGuardTests(unittest.TestCase):
    def test_cannot_request_uninstall_before_install(self):
        with patch.object(subject.pub,"call") as call:
            with self.assertRaisesRegex(RuntimeError,"DOXA_NOT_INSTALLED"):
                subject.request_uninstall("FAKE_TOKEN",installed=False)
            call.assert_not_called()

    def test_single_app_single_group_payload(self):
        calls=[]
        def mock(method,path,token,payload=None,params=None):
            calls.append((method,path,payload))
            if method=="POST" and path.endswith("/assign"):
                return {}
            if method=="GET" and path.endswith("/assignments"):
                return {"value":[{"intent":"uninstall","target":{"groupId":subject.pub.KNOWN_PILOT_GROUP_ID}}]}
            raise AssertionError((method,path))
        with patch.object(subject,"preflight",return_value=("/deviceAppManagement/mobileApps/"+subject.EXPECTED_APP_ID,subject.pub.KNOWN_PILOT_GROUP_ID)),patch.object(subject.pub,"call",side_effect=mock):
            subject.request_uninstall("FAKE_TOKEN",installed=True)
        writes=[row for row in calls if row[0]=="POST"]
        self.assertEqual(len(writes),1)
        self.assertTrue(writes[0][1].endswith("/assign"))
        apps=writes[0][2]["mobileAppAssignments"]
        self.assertEqual(len(apps),1)
        self.assertEqual(apps[0]["intent"],"uninstall")
        self.assertEqual(apps[0]["target"]["groupId"],subject.pub.KNOWN_PILOT_GROUP_ID)

    def test_group_mismatch_prohibits_uninstall(self):
        with patch.object(subject.pub,"get_one_device",return_value="dell-only-object"),patch.object(subject.pub,"call",return_value={
                    "id":subject.pub.KNOWN_PILOT_GROUP_ID,"displayName":subject.pub.GROUP_NAME,
                    "securityEnabled":True,"mailEnabled":False}),patch.object(subject.pub,"members",return_value={"dell-only-object","unrelated-device"}):
            with self.assertRaisesRegex(RuntimeError,"Group is not exactly Dell"):
                subject.assert_single_dell_group("FAKE_TOKEN")

    def test_modified_app_prohibits_uninstall(self):
        def fake_call(method,path,token,payload=None,params=None):
            if path.endswith("/assignments"): return {"value":[{"intent":"required","target":{"groupId":subject.pub.KNOWN_PILOT_GROUP_ID}}]}
            return {"id":subject.EXPECTED_APP_ID,"displayName":"Different app",
                    "publisher":"DMR Ergonomics SRL (Standivarius)"}
        with patch.object(subject.pub,"active_pilot_app_id",return_value=subject.EXPECTED_APP_ID),patch.object(subject.pub,"tenant_id",return_value=subject.TENANT_ID),patch.object(subject,"assert_single_dell_group",return_value=subject.pub.KNOWN_PILOT_GROUP_ID),patch.object(subject.pub,"call",side_effect=fake_call):
            with self.assertRaisesRegex(RuntimeError,"App identity"):
                subject.preflight("FAKE_TOKEN")

    def test_wrong_assignment_prohibits_uninstall(self):
        app={"id":subject.EXPECTED_APP_ID,"displayName":subject.pub.APP_NAME,
             "publisher":"DMR Ergonomics SRL (Standivarius)",
             "@odata.type":"#microsoft.graph.win32LobApp",
             "publishingState":"published","committedContentVersion":"1",
             "installCommandLine":subject.EXPECTED_INSTALL,
             "uninstallCommandLine":subject.EXPECTED_UNINSTALL}
        def fake_call(method,path,token,payload=None,params=None):
            if path.endswith("/assignments"):return {"value":[{"intent":"required","target":{"groupId":"wrong-group"}}]}
            return app
        with patch.object(subject.pub,"active_pilot_app_id",return_value=subject.EXPECTED_APP_ID),patch.object(subject.pub,"tenant_id",return_value=subject.TENANT_ID),patch.object(subject,"assert_single_dell_group",return_value=subject.pub.KNOWN_PILOT_GROUP_ID),patch.object(subject.pub,"call",side_effect=fake_call):
            with self.assertRaisesRegex(RuntimeError,"Expected exactly one"):
                subject.preflight("FAKE_TOKEN")

if __name__=="__main__":
    unittest.main(verbosity=2)
