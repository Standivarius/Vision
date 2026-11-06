"""Offline tests for DPAPI token cache and no-secret output."""
import io
from contextlib import redirect_stdout
import unittest
from unittest.mock import patch
import DoxaIntuneAuth as auth


class AuthTests(unittest.TestCase):
    def test_cache_encrypted_and_not_under_repo(self):
        cache = auth.secure_cache()
        self.assertIsNotNone(cache)
        self.assertEqual(auth.CACHE_FILE.name, "msal_cache.bin")
        self.assertTrue(str(auth.CACHE_FILE).lower().startswith(str(auth.CACHE_DIR).lower()))
        self.assertTrue(auth.CACHE_FILE.is_absolute())
        self.assertTrue(str(auth.CACHE_FILE).lower().find("wt\\doxa-installer") < 0)

    def test_cached_token_is_silent_and_does_not_prompt(self):
        class FakeClient:
            def __init__(self, *args, **kwargs): pass
            def get_accounts(self): return [{"username":"mock-admin"}]
            def acquire_token_silent(self, scopes, account):
                self_scopes = scopes
                assert "DeviceManagementApps.ReadWrite.All" in self_scopes
                return {"access_token":"EXAMPLE_SECRET_NOT_REAL"}
            def initiate_device_flow(self, scopes): raise AssertionError("Must not request auth")
        with patch.object(auth.msal,"PublicClientApplication", FakeClient):
            buf=io.StringIO()
            with redirect_stdout(buf):
                token=auth.get_token()
            self.assertEqual(token,"EXAMPLE_SECRET_NOT_REAL")
            self.assertIn("ENCRYPTED_CACHE_REUSED",buf.getvalue())
            self.assertNotIn(token,buf.getvalue())

    def test_cache_miss_can_fail_without_prompt(self):
        class FakeClient:
            def __init__(self,*args,**kwargs):pass
            def get_accounts(self):return []
        with patch.object(auth.msal,"PublicClientApplication",FakeClient):
            with self.assertRaisesRegex(RuntimeError,"interactive consent required"):
                auth.get_token(allow_interactive=False)

    def test_new_login_token_not_printed(self):
        class FakeClient:
            def __init__(self,*args,**kwargs):pass
            def get_accounts(self):return []
            def initiate_device_flow(self,scopes):
                return {"user_code":"MOCK-CODE","verification_uri":"https://login.microsoft.com/device"}
            def acquire_token_by_device_flow(self,flow):
                return {"access_token":"EXAMPLE_SECRET_NOT_REAL"}
        with patch.object(auth.msal,"PublicClientApplication",FakeClient):
            buf=io.StringIO()
            with redirect_stdout(buf):
                token=auth.get_token()
            self.assertEqual(token,"EXAMPLE_SECRET_NOT_REAL")
            self.assertIn("WINDOWS_DPAPI_CURRENT_USER_ONLY",buf.getvalue())
            self.assertNotIn(token,buf.getvalue())

    def test_multiple_cached_accounts_are_rejected(self):
        class FakeClient:
            def __init__(self,*args,**kwargs):pass
            def get_accounts(self):return [{"username":"one"},{"username":"two"}]
        with patch.object(auth.msal,"PublicClientApplication",FakeClient):
            with self.assertRaisesRegex(RuntimeError,"Multiple cached Microsoft accounts"):
                auth.get_token(allow_interactive=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
