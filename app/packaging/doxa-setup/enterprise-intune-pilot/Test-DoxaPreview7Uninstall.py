"""Guarded no-device mutation test for exact preview7 assignment switch."""
import importlib.util
from pathlib import Path
from unittest.mock import patch
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("switch6",HERE/"Switch-DoxaPreview7ToUninstall.py")
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class UninstallOneDellContract(unittest.TestCase):
    def test_wrong_or_uninstalled_payload_stops_before_any_graph_mutation(self):
        with patch.object(module,"installed",return_value=False),\
             patch.object(module,"verify") as guard,\
             patch.object(module.pub,"call") as api:
            with self.assertRaises(RuntimeError):
                module.request_uninstall("token")
            guard.assert_not_called()
            api.assert_not_called()

    def test_exact_app_and_dell_group_only(self):
        sent=[]
        def fake(method,path,token,data=None):
            sent.append((method,path,data))
            return {}
        with patch.object(module,"installed",return_value=True),\
             patch.object(module,"verify",side_effect=[("/deviceAppManagement/mobileApps/"+module.APP_ID),None]),\
             patch.object(module.pub,"call",side_effect=fake):
            module.request_uninstall("fake-token")
        self.assertEqual(len(sent),1)
        self.assertEqual(sent[0][0],"POST")
        self.assertEqual(sent[0][1],"/deviceAppManagement/mobileApps/"+module.APP_ID+"/assign")
        assign=sent[0][2]["mobileAppAssignments"]
        self.assertEqual(len(assign),1)
        self.assertEqual(assign[0]["intent"],"uninstall")
        self.assertEqual(assign[0]["target"]["groupId"],module.pub.KNOWN_PILOT_GROUP_ID)

if __name__=="__main__":
    unittest.main()
