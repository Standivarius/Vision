# Doxa Intune pilot — committed package, publication PATCH recovery
Date: 24 October 2026. Dell pilot only, isolated clean PR #78.

## Real Microsoft results
- User authorised DPAPI-encrypted persistent MSAL. A fresh PowerShell/Python process reused the cached refreshable Microsoft token silently.
- Original stale, unpublished, unassigned Doxa Win32 app `5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4` was deleted only after verifying its exact identity, no committed content, no assignments, one `commitFileFailed` file with expected sizes.
- Replacement Doxa application created in DMR Intune: `62fcb7ce-ebc2-4407-9b51-0710cb809c32`, ID safely recorded outside Git in `artifacts/releases/intune/doxa-active-pilot-app.json`.
- Azure encrypted **Put Block + Put Block List** succeeded, HEAD verified **42,960 bytes**.
- Live Graph read confirms initial content version **1**, file `commitFileSuccess`, `isCommitted=true`, clear/encrypted sizes `42910/42960`. This is a genuine server-side content acceptance, not just an offline test.
- Graph PATCH `/deviceAppManagement/mobileApps/{id}` with `committedContentVersion=1` but **without `@odata.type`** returned HTTP 400 `ModelValidationFailure`. App remains `notPublished`, `committedContentVersion=null`, assignments **0**. No Dell app installed or driver changed.

## Correction
- Microsoft's Win32 PowerShell sample explicitly sends `{"@odata.type":"#microsoft.graph.win32LobApp","committedContentVersion":"1"}` to PATCH. Publisher now uses that typed body and verifies publication, matching committed version.
- Before any additional upload, it reads exactly one content version/one content file and reuses the existing fully committed, correctly named/sized file, rather than sending a duplicate or attempting an unsupported DELETE.
- Publishing requires exact recorded active app ID, name/type/publisher, no assignments and an uncommitted app-level version. Assignment requires app `published` and dedicated group containing **exactly MARIUS-DELL**.
- **22/22 offline publisher tests PASS**, including typed PATCH, previously committed file reuse, size mismatch refusal; 5/5 encrypted-auth tests PASS. The publisher dry-run PASS. Live typed PATCH remains UNVERIFIED until execution.
- No unrelated applications, organisation-wide policies, driver MSI or Vision master files affected.

Reference: https://github.com/microsoft/mggraph-intune-samples/blob/main/LOB_Application/Win32_Application_Update.ps1
