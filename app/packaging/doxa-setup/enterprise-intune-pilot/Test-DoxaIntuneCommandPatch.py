"""Offline regression tests for the live Intune Doxa SYSTEM script-policy fix."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

p=Path(__file__).with_name("Patch-DoxaIntuneCommands.py")
spec=importlib.util.spec_from_file_location("doxa_command_patch",p)
repair=importlib.util.module_from_spec(spec)
spec.loader.exec_module(repair)

class CommandPatchTests(unittest.TestCase):
    def setUp(self):
        self.app_id="62fcb7ce-ebc2-4407-9b51-0710cb809c32"
        self.target="/deviceAppManagement/mobileApps/"+self.app_id
        self.original={
            "id":self.app_id,
            "displayName":repair.pub.APP_NAME,
            "publisher":"DMR Ergonomics SRL (Standivarius)",
            "@odata.type":"#microsoft.graph.win32LobApp",
            "publishingState":"published",
            "committedContentVersion":"1",
            "installCommandLine":repair.INSTALL_OLD,
            "uninstallCommandLine":repair.UNINSTALL_OLD
        }
        self.assignments={"value":[{"intent":"required","target":{"groupId":repair.pub.KNOWN_PILOT_GROUP_ID}}]}
        self.calls=[]
        self.updated=False

    def fake_call(self,method,path,token,payload=None,params=None):
        self.calls.append((method,path,payload))
        if method=="GET" and path==self.target:
            if self.updated:
                return dict(self.original,installCommandLine=repair.INSTALL_NEW,
                            uninstallCommandLine=repair.UNINSTALL_NEW)
            return self.original
        if method=="GET" and path==self.target+"/assignments":
            return self.assignments
        if method=="PATCH" and path==self.target:
            self.assertEqual(payload,{"@odata.type":"#microsoft.graph.win32LobApp",
                                      "installCommandLine":repair.INSTALL_NEW,
                                      "uninstallCommandLine":repair.UNINSTALL_NEW})
            self.updated=True
            return {}
        raise AssertionError((method,path))

    def patches(self):
        return [(m,p,v) for m,p,v in self.calls if m=="PATCH"]

    def setup_mocks(self):
        return (patch.object(repair.pub,"active_pilot_app_id",return_value=self.app_id),
                patch.object(repair.pub,"get_one_device",return_value="dell-entra-id"),
                patch.object(repair.pub,"ensure_private_group",return_value=repair.pub.KNOWN_PILOT_GROUP_ID),
                patch.object(repair.pub,"members",return_value={"dell-entra-id"}),
                patch.object(repair.pub,"call",side_effect=self.fake_call))

    def test_change_only_two_script_commands_under_exact_device_and_group(self):
        from contextlib import ExitStack
        with ExitStack() as stack:
            for mock in self.setup_mocks():stack.enter_context(mock)
            repair.update_commands("FAKE_TOKEN")
        self.assertTrue(self.updated)
        self.assertEqual(len(self.patches()),1)
        self.assertIn("-ExecutionPolicy Bypass -File",repair.INSTALL_NEW)
        self.assertIn("-ExecutionPolicy Bypass -File",repair.UNINSTALL_NEW)

    def test_rejects_changed_or_extra_group_assignment(self):
        from contextlib import ExitStack
        self.assignments={"value":[{"intent":"required","target":{"groupId":"other-group"}}]}
        with ExitStack() as stack:
            for mock in self.setup_mocks():stack.enter_context(mock)
            with self.assertRaisesRegex(RuntimeError,"Dell-only Required assignment"):
                repair.update_commands("FAKE_TOKEN")
        self.assertFalse(self.patches())

    def test_rejects_altered_install_command(self):
        from contextlib import ExitStack
        self.original["installCommandLine"]="powershell.exe -File other-script.ps1"
        with ExitStack() as stack:
            for mock in self.setup_mocks():stack.enter_context(mock)
            with self.assertRaisesRegex(RuntimeError,"Unexpected installer command"):
                repair.update_commands("FAKE_TOKEN")
        self.assertFalse(self.patches())

    def test_rejects_wrong_content_version(self):
        from contextlib import ExitStack
        self.original["committedContentVersion"]="99"
        with ExitStack() as stack:
            for mock in self.setup_mocks():stack.enter_context(mock)
            with self.assertRaisesRegex(RuntimeError,"App identity or published package"):
                repair.update_commands("FAKE_TOKEN")
        self.assertFalse(self.patches())

    def test_already_fixed_is_idempotent(self):
        from contextlib import ExitStack
        self.original["installCommandLine"]=repair.INSTALL_NEW
        self.original["uninstallCommandLine"]=repair.UNINSTALL_NEW
        with ExitStack() as stack:
            for mock in self.setup_mocks():stack.enter_context(mock)
            repair.update_commands("FAKE_TOKEN")
        self.assertFalse(self.patches())

if __name__=="__main__":
    unittest.main(verbosity=2)
