# Doxa Intune pilot — persistent, encrypted Microsoft Graph login

## Goal and scope
Avoid repeated user-device-code approvals while working on the DMR Ergonomics
Intune pilot. Use Microsoft's **MSAL Python + MSAL Extensions**, on MARIUS-DELL,
with encrypted Windows DPAPI CurrentUser token persistence.

- Token cache path: `%LOCALAPPDATA%\Standivarius\DoxaIntunePilot\msal_cache.bin` — **outside the Git repository**.
- No plaintext fallback. MSAL Extensions uses DPAPI for Windows encryption and
  an interprocess lock. Access is tied to the Windows profile. No password is stored.
- Microsoft identity: existing **Microsoft Graph Command Line Tools** public-client
  app, tenant bound to the existing DMR Ergonomics tenant; no new Azure subscription.
- Delegated permissions: DeviceManagementApps.ReadWrite.All,
  DeviceManagementManagedDevices.Read.All, Device.Read.All,
  Group.ReadWrite.All, GroupMember.ReadWrite.All.
- These Graph permissions are **tenant-wide in potential authority**; Dell-only
  restrictions are enforced in our publisher code through exact device, app and
  group IDs, state and membership checks. They are not a tenant-enforced permission
  restriction. Treat the cached delegated admin refresh token as sensitive.
- Refresh tokens are automatically used through MSAL where allowed. Session lifetime
  is controlled by Microsoft Entra security policy; reauth/MFA can still be required.
- Cache is absent until owner completes the first MSAL sign-in. NEVER commit cache
  files, JWTs, access/refresh tokens or SAS URLs.

## Usage
1. `python -m pip install --user -r requirements-auth.txt`
2. `python DoxaIntuneAuth.py --status` checks local cache presence only.
3. `python Publish-DoxaIntunePilot.py --execute` first tries a valid cached
   token. If missing/expired, prints Microsoft's device-code URL and short
   code for the owner's account. The first successful sign-in persists a
   DPAPI-encrypted refreshable cache on Dell for later interactive sessions.
4. `python DoxaIntuneAuth.py --clear-local-cache` removes only the local
   token cache. This is immediate local cleanup; it does **not** independently
   revoke OAuth consent, invalidate remote tokens, or unenroll Dell.
5. To revoke at organisation level, an admin can revoke the delegated grant
   to Microsoft Graph Command Line Tools and/or revoke this account's active
   sign-in sessions in Entra, which can affect other CLI usage. Do not invoke
   a tenant-wide revocation without the owner choosing it.

## Recovery and test safety
- Current Intune Doxa pilot is unpublished and unassigned after earlier failed
  content-version `commitFileFailed`, so no Intune app has reached Dell.
- The first retry was blocked when trying to create a new content version.
  The next retry correctly recovers only an exact, failed, uncommitted file
  inside the original content version.
- Graph returned `No OData route ... with http verb DELETE` when the publisher
  used a typed /microsoft.graph.win32LobApp/contentVersions/.../files/... path.
  The documented v1.0 DELETE route is the **untagged** /mobileApps/{id}/contentVersions/{version}/files/{fileId}
  route; it is now used for that DELETE, with guard rails and re-verification.
- No app-wide deletion, general Intune policy, Silicon Motion driver MSI or
  Windows reinstall is in scope.

## Offline checks
- `python Test-DoxaIntuneAuth.py`: 5 tests; silent reuse, cache misses,
  no token output, multiple-account refusal and Windows encrypted path.
- `python Test-DoxaIntunePublish.py`: 16 tests; file-recovery guard,
  exact published/unpublished state checks, one device only.
- `python Test-DoxaIntuneCrypto.py`: package integrity.
- All these are *offline*; a real future tenant action requires completed
  Microsoft authentication.

Microsoft references:
- https://github.com/AzureAD/microsoft-authentication-extensions-for-python
- https://learn.microsoft.com/en-us/entra/msal/python/advanced/msal-python-token-cache-serialization
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-delete?view=graph-rest-1.0
