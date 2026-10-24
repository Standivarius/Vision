"""Optional persistent Microsoft delegated sign-in for the Dell-only Doxa pilot.

Windows DPAPI protects the MSAL cache for the signed-in Windows user.
Never print access tokens, refresh tokens, client credentials or file contents.
No plaintext fallback; no registry, certificate or environment secrets.
Local cache: %LOCALAPPDATA%\\Standivarius\\DoxaIntunePilot\\msal_cache.bin
"""
from pathlib import Path
import argparse
import os
import sys

import msal
from msal_extensions import PersistedTokenCache, build_encrypted_persistence

CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Existing Microsoft Graph CLI public client
SCOPES = [
    "DeviceManagementApps.ReadWrite.All",
    "DeviceManagementManagedDevices.Read.All",
    "Device.Read.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
]
TENANT_ID = "4a59108a-ad19-40ba-8221-87e7cbe17e63"
CACHE_DIR = Path(os.environ.get("LOCALAPPDATA", "")) / "Standivarius" / "DoxaIntunePilot"
CACHE_FILE = CACHE_DIR / "msal_cache.bin"


def secure_cache():
    if sys.platform != "win32" or not os.environ.get("LOCALAPPDATA"):
        raise RuntimeError("Encrypted pilot auth is supported only on the Dell Windows account")
    if CACHE_DIR.is_symlink() or CACHE_FILE.is_symlink():
        raise RuntimeError("Refusing a redirected Intune token cache")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    persistence = build_encrypted_persistence(str(CACHE_FILE))
    if not persistence.is_encrypted:
        raise RuntimeError("DPAPI token encryption is unavailable; no plaintext fallback")
    return PersistedTokenCache(persistence)


def get_token(*, allow_interactive=True):
    """Return an in-memory access token; reuse MSAL refresh tokens silently."""
    cache = secure_cache()
    client = msal.PublicClientApplication(
        CLIENT_ID,
        authority="https://login.microsoftonline.com/" + TENANT_ID,
        token_cache=cache,
    )
    accounts = client.get_accounts()
    if len(accounts) > 1:
        raise RuntimeError("Multiple cached Microsoft accounts; clear the pilot cache and retry")
    if accounts:
        result = client.acquire_token_silent(SCOPES, account=accounts[0])
        if result and result.get("access_token"):
            print("MICROSOFT_AUTH=ENCRYPTED_CACHE_REUSED", flush=True)
            return result["access_token"]
    if not allow_interactive:
        raise RuntimeError("No valid cached Microsoft token; interactive consent required")
    flow = client.initiate_device_flow(scopes=SCOPES)
    if not flow or "user_code" not in flow:
        raise RuntimeError("Microsoft rejected the initial device-code request")
    print("AUTHORIZE_URL=" + flow.get("verification_uri", "https://login.microsoft.com/device"),
          flush=True)
    print("AUTHORIZE_CODE=" + flow["user_code"], flush=True)
    print("PERMISSIONS=" + ", ".join(SCOPES), flush=True)
    print("AUTH_PERSISTENCE=WINDOWS_DPAPI_CURRENT_USER_ONLY", flush=True)
    result = client.acquire_token_by_device_flow(flow)
    if "access_token" not in result:
        raise RuntimeError("Microsoft sign-in failed: " +
                           result.get("error", "unknown"))
    print("MICROSOFT_AUTH=NEW_ENCRYPTED_SESSION", flush=True)
    return result["access_token"]


def clear_local_cache():
    """Remove only this project's local cache. Does not revoke tenant consent."""
    if CACHE_FILE.exists():
        if CACHE_FILE.is_symlink():
            raise RuntimeError("Refusing to follow a redirected cache file")
        CACHE_FILE.unlink()
    lock_file = CACHE_FILE.with_suffix(CACHE_FILE.suffix + ".lockfile")
    if lock_file.exists() and not lock_file.is_symlink():
        try:
            lock_file.unlink()
        except PermissionError:
            pass
    print("DOXA_INTUNE_LOCAL_AUTH_CACHE_CLEARED=true", flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--status", action="store_true")
    p.add_argument("--clear-local-cache", action="store_true")
    args = p.parse_args()
    if args.clear_local_cache:
        clear_local_cache()
    elif args.status:
        exists = CACHE_FILE.exists()
        print("CACHE_EXISTS=" + str(exists), flush=True)
        print("CACHE_PATH=" + str(CACHE_FILE), flush=True)
        if exists:
            cache = secure_cache()
            print("CACHE_IS_ENCRYPTED=true", flush=True)
            print("CACHE_IS_OUTSIDE_REPOSITORY=true", flush=True)
    else:
        print("Use --status or --clear-local-cache. "
              "Actual Graph token use occurs only in the publisher.", flush=True)


if __name__ == "__main__":
    main()
