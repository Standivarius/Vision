# Doxa Intune pilot — successful application creation, failed content commit, protected recovery
Date: 24 October 2026. All work in clean draft PR #78 and isolated Doxa worktree.

## Genuine live outcome (after owner Microsoft approval)
- MARIUS-DELL verified uniquely in Intune with MDM state and compliant status; dedicated security group already exists and includes only Dell.
- Intune POST /v1.0/deviceAppManagement/mobileApps **SUCCESS**: Doxa app ID `5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4`.
- Encrypted 42,960-byte package uploaded using single Azure `Put Blob` and Graph /commit returned successfully, but Intune asynchronous file state **commitFileFailed**.
- No committed/published application, **no assignment**, no Win32 installation/driver change. Do not claim deployment succeeded.
- Existing Dell-only group ID `3f74c6a3-d470-4d78-8c17-756381465095`.
- Previous source `abe7c9a` and package SHA256 `FFCA7CA75A5EB27083E1D3099B202929073EA97094CC8565610AE28824A44E36` remain unchanged.

## Evidence and recovery
- Research: Microsoft's official mggraph-intune-samples and Intune PowerShell SDK use **Put Block** and then **Put Block List**, not a single `Put Blob`, before Graph file commit. Related Microsoft Q&A users observed `commitFileFailed` with AZCopy/direct upload and recovered by switching to block upload. This is a strong diagnosis, but our specific cause awaits successful live verification.
- Existing `.intunewin` cryptographic check against its own encrypted bytes: 32-byte MAC, 16-byte IV, 32-byte AES key, 32-byte HMAC key, 32-byte digest; MAC in payload equals metadata; IV in payload equals metadata; recomputed HMAC-SHA256 of IV+ciphertext equals MAC. **PASS**. These checks do not replace server-side validation.
- Replaced publisher's one-shot Azure blob PUT with **Put Block**, **Put Block List**, and HEAD exact content-length check; then Graph encryption metadata commit. 4 MiB chunk size; tiny payload is one chunk.
- Publisher now **reuses the exact pre-existing unpublished app** by its confirmed GUID, after checking app type, name, publisher, command, absence of committed content and assignments; rejects any unknown or modified app. Existing group is verified against its exact original GUID. It creates a new content version and does not repeat the old failed one.
- Local test suite expanded to **12/12 PASS**, including actual one-device assignment guard, app resume/reject changed object, Azure block-list structure, expected blob-size validation and request metadata checks. Independent offline payload HMAC/IV checks also PASS.
- No Graph mutation occurred during repair/tests; original main Vision tree and physical Doxa driver preserved.
- **LIVE RETEST PENDING**, requires a new short-lived delegated administrator sign-in because Graph tokens were not retained.

## Next
Run publisher with `--execute` after owner login. If it creates and publishes the existing app, verify one-group-only assignment then Intune Management Extension installation and actual app-only install/detect/uninstall and normal Doxa/Office/Vision behavior. If new Graph error occurs, stop, preserve app/group, and diagnose without creating duplicates or expanding scope.

Microsoft official samples:
https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/Win32_Application_Update.ps1
https://github.com/microsoft/Intune-PowerShell-SDK/blob/master/Samples/Apps/UploadLobApp.psm1
Microsoft Q&A case:
https://learn.microsoft.com/en-gb/answers/questions/5570102/graph-api-win32-app-upload-fails-with-commitfilefa
