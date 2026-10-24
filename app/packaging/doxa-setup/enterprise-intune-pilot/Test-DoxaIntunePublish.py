"""Offline preflight tests; no Azure, Microsoft identity or actual tenant changes."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

path = Path(__file__).with_name("Publish-DoxaIntunePilot.py")
spec = importlib.util.spec_from_file_location("doxa_publish", path)
pub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)


class TestDoxaIntunePilot(unittest.TestCase):
    def test_package_is_app_only_and_hash_is_expected(self):
        f, content, plain, crypt = pub.read_package()
        self.assertEqual(pub.sha256_bytes(f.read_bytes()),
                         "FFCA7CA75A5EB27083E1D3099B202929073EA97094CC8565610AE28824A44E36")
        self.assertLess(len(content), 100_000)
        self.assertGreater(plain, 0)
        self.assertEqual(crypt["fileDigestAlgorithm"], "SHA256")

    def test_device_must_be_compliant_unique_managed_and_directory_known(self):
        def good_call(method, path, token, payload=None, params=None):
            if path == "/deviceManagement/managedDevices":
                return {"value": [{"deviceName": pub.DEVICE_NAME, "managementAgent": "mdm",
                                   "complianceState": "compliant", "azureADDeviceId": "77777777-7777-7777-7777-777777777777"}]}
            if path == "/devices":
                return {"value": [{"id": "dell-object-id", "deviceId": "77777777-7777-7777-7777-777777777777"}]}
            raise AssertionError(path)
        with patch.object(pub, "call", good_call):
            self.assertEqual(pub.get_one_device("FAKE_TOKEN"), "dell-object-id")
        for bad in ["unknown", "noncompliant", "duplicate"]:
            def fake(method, path, token, payload=None, params=None):
                if bad == "duplicate":
                    return {"value": [{"deviceName": pub.DEVICE_NAME}, {"deviceName": pub.DEVICE_NAME}]}
                return {"value": [{"deviceName": pub.DEVICE_NAME, "managementAgent": "mdm",
                                   "complianceState": bad, "azureADDeviceId": "1"}]}
            with patch.object(pub, "call", fake):
                with self.assertRaises(RuntimeError):
                    pub.get_one_device("FAKE_TOKEN")

    def test_other_members_prevent_assignment(self):
        def fake_members(token, group):
            return {"dell", "another-computer"}
        with patch.object(pub, "members", fake_members), patch.object(pub, "call") as graph:
            with self.assertRaisesRegex(RuntimeError, "Pilot membership changed"):
                pub.assign_only_dell("FAKE_TOKEN", "app", "group", "dell")
            graph.assert_not_called()

    def test_unpublished_app_prevents_assignment(self):
        def fake_members(token, group):
            return {"dell"}
        with patch.object(pub, "members", fake_members), patch.object(pub, "call",
                return_value={"publishingState": "processing"}) as graph:
            with self.assertRaisesRegex(RuntimeError, "App not published"):
                pub.assign_only_dell("FAKE_TOKEN", "app", "group", "dell")
            self.assertEqual(graph.call_count, 1)

    def test_assign_is_restricted_to_only_one_group(self):
        requests = []
        def fake_call(method, path, token, payload=None, params=None):
            requests.append((method, path, payload))
            if path.endswith("/assignments"):
                return {"value": []}
            if path.endswith("/assign") and method == "POST":
                return {}
            return {"publishingState": "published"}
        with patch.object(pub, "members", return_value={"dell"}), patch.object(pub, "call", fake_call):
            pub.assign_only_dell("FAKE_TOKEN", "app", "group", "dell")
        posts = [x for x in requests if x[0] == "POST"]
        self.assertEqual(len(posts), 1)
        target = posts[0][2]["mobileAppAssignments"]
        self.assertEqual(len(target), 1)
        self.assertEqual(target[0]["target"]["@odata.type"], "#microsoft.graph.groupAssignmentTarget")
        self.assertEqual(target[0]["target"]["groupId"], "group")
        self.assertEqual(target[0]["intent"], "required")

    def test_create_payload_uses_v1_graph_fields_not_beta_only_fields(self):
        payloads = []
        def fake_call(method, path, token, payload=None, params=None):
            if method == "GET":
                return {"value": []}
            self.assertEqual((method,path),("POST","/deviceAppManagement/mobileApps"))
            payloads.append(payload)
            return {"id":"mock-app"}
        with patch.object(pub,"call",fake_call):
            self.assertEqual(pub.create_app("FAKE_TOKEN",None,None,0),"mock-app")
        body=payloads[0]
        self.assertNotIn("minimumSupportedOperatingSystem",body)
        self.assertEqual(body["minimumSupportedWindowsRelease"],"Windows11_23H2")
        self.assertEqual(body["@odata.type"],"#microsoft.graph.win32LobApp")
        self.assertEqual(body["fileName"],"IntunePackage.intunewin")
        self.assertEqual(body["installExperience"]["@odata.type"],"microsoft.graph.win32LobAppInstallExperience")
        self.assertEqual(body["installExperience"]["runAsAccount"],"system")
        self.assertEqual(body["rules"][0]["ruleType"],"detection")
        self.assertEqual(body["returnCodes"][0]["@odata.type"],"microsoft.graph.win32LobAppReturnCode")
        self.assertEqual(body["returnCodes"][0]["returnCode"],0)
        self.assertEqual(body["allowedArchitectures"],"x64")

    def test_schema_error_is_diagnosable_without_leaking_urls(self):
        class MockResponse:
            ok = False
            status_code = 400
            content = b"x"
            def json(self):
                return {"error": {"code": "BadRequest",
                    "message": "Invalid field fileName. Consult https://graph.microsoft.com/secret?sig=do-not-print"}}
        with patch.object(pub.SESSION, "request", return_value=MockResponse()):
            with self.assertRaises(RuntimeError) as caught:
                pub.call("POST", "/deviceAppManagement/mobileApps", "FAKE_TOKEN", {})
        error = str(caught.exception)
        self.assertIn("Invalid field fileName", error)
        self.assertNotIn("graph.microsoft.com", error)
        self.assertNotIn("do-not-print", error)

    def test_reuses_only_original_unassigned_not_published_app(self):
        calls = []
        def fake_call(method, path, token, payload=None, params=None):
            calls.append((method,path))
            if path == "/deviceAppManagement/mobileApps":
                return {"value": [{"id": pub.KNOWN_PILOT_APP_ID, "displayName": pub.APP_NAME}]}
            if path.endswith("/assignments"):
                return {"value":[]}
            return {
                "displayName": pub.APP_NAME,
                "publisher": "DMR Ergonomics SRL (Standivarius)",
                "@odata.type": "#microsoft.graph.win32LobApp",
                "installCommandLine": "powershell.exe -File DoxaPilot.ps1 -Action Install",
                "publishingState": "notPublished",
                "committedContentVersion": ""
            }
        with patch.object(pub, "call", fake_call):
            self.assertEqual(pub.create_app("FAKE_TOKEN",None,None,0),pub.KNOWN_PILOT_APP_ID)
        self.assertTrue(all(method == "GET" for method,path in calls))

    def test_rejects_edited_existing_app(self):
        def fake_call(method, path, token, payload=None, params=None):
            if path == "/deviceAppManagement/mobileApps":
                return {"value": [{"id": pub.KNOWN_PILOT_APP_ID}]}
            return {"displayName": "Some other app", "publisher": "Wrong"}
        with patch.object(pub, "call", fake_call):
            with self.assertRaisesRegex(RuntimeError,"Existing Intune app is changed"):
                pub.create_app("FAKE_TOKEN",None,None,0)

    def test_azure_upload_uses_block_list_not_single_put_blob(self):
        class Response:
            def __init__(self, code, length=None):
                self.status_code = code
                self.headers = {} if length is None else {"Content-Length":str(length)}
        uploaded = b"A" * 42960
        calls = []
        def mock_put(url, data, headers, timeout):
            calls.append((url, data, headers))
            return Response(201)
        def mock_head(url, headers, timeout):
            return Response(200,len(uploaded))
        with patch.object(pub.SESSION,"put",side_effect=mock_put), patch.object(pub.SESSION,"head",side_effect=mock_head):
            pub.upload_azure_blocks("https://example.invalid/content?sig=TEST-FAKE-ONLY",uploaded)
        self.assertEqual(len(calls),2)
        self.assertIn("&comp=block&", calls[0][0])
        self.assertEqual(calls[0][1],uploaded)
        self.assertIn("&comp=blocklist",calls[1][0])
        self.assertIn(b"<Latest>",calls[1][1])
        self.assertIn(b"</BlockList>",calls[1][1])

    def test_azure_upload_rejects_size_mismatch(self):
        class Response:
            def __init__(self, code, length=None):
                self.status_code=code
                self.headers={} if length is None else {"Content-Length":str(length)}
        with patch.object(pub.SESSION,"put",return_value=Response(201)), patch.object(pub.SESSION,"head",return_value=Response(200,1)):
            with self.assertRaisesRegex(RuntimeError,"Azure blob size mismatch"):
                pub.upload_azure_blocks("https://example.invalid/content?sig=FAKE",b"A"*200)

    def test_existing_group_with_unrelated_member_refused(self):
        def fake_call(method, path, token, payload=None, params=None):
            return {"value": [{"id": pub.KNOWN_PILOT_GROUP_ID, "displayName": pub.GROUP_NAME,
                               "securityEnabled": True, "mailEnabled": False}]}
        with patch.object(pub, "call", fake_call), patch.object(pub, "members", return_value={"other-device"}):
            with self.assertRaisesRegex(RuntimeError, "other members"):
                pub.ensure_private_group("FAKE_TOKEN", "dell")


if __name__ == "__main__":
    unittest.main(verbosity=2)
