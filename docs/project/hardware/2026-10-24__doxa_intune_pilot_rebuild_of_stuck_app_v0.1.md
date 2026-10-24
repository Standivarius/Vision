# Doxa Intune pilot — recover unrecoverable failed content by recreating only the isolated app

Date: 2026-10-24. Clean Vision draft PR #78; `MARIUS-DELL` only.

## Live evidence
- Windows DPAPI-encrypted MSAL delegated refresh token now established under `%LOCALAPPDATA%\Standivarius\DoxaIntunePilot`. Verified *new process* reuses cached token with **no device code**. Never persist auth tokens in Git.
- DMR Intune managed device `MARIUS-DELL` uniquely present and compliant.
- Existing Doxa app `5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4` confirmed **notPublished**, committed content version `null`, assignments **zero**; exactly one failed first content version with one uncommitted `commitFileFailed` file `39991579-da12-4e1a-9553-3c189c90a3ee`, sizes `42910/42960` bytes.
- Two Graph v1.0 methods documented for deleting a mobileAppContentFile were attempted and rejected by backend: casted win32LobApp: HTTP 400 *No OData route with DELETE*; uncasted mobileApps/{id}/contentVersions/{v}/files/{id}: HTTP 400 *Resource not found for segment contentVersions*. The feature is not supported by this tenant's win32 backend despite generic Graph documentation.
- No app had ever been published, assigned or installed. No Silicon Motion driver changes.

## Strict fallback
- A new explicit CLI gate `--recreate-stuck-pilot` is available **only with** `--execute`.
- Before deleting the one existing failed app, validate its **exact original UUID**, display name, publisher, install command, app type, `notPublished`, absence of committed content, zero assignments, exactly one initial content version (id 1) and one *uncommitted* `commitFileFailed` file matching original filename and sizes. Stop if any mismatch.
- DELETE only `/deviceAppManagement/mobileApps/{original UUID}`, which Microsoft explicitly supports for Win32 apps; re-query to confirm its disappearance before recreating. Never delete a managed device, group, working app or an assigned app.
- Create replacement same-name pilot using corrected Graph v1.0 metadata, secure Azure Put Block + Put Block List upload, content commit and application publishing. Save new GUID in Git-ignored `artifacts/releases/intune/doxa-active-pilot-app.json`, enabling safe retries without deleting a new app. No tokens or SAS URLs in this state file.
- Reverify group has **only Dell** before Required assignment. Only then begin actual Intune agent/install/detect observation; installer is app-only, without MSI driver, no reboot.
- 19/19 publisher unit tests and 5/5 encrypted auth tests passed in local dry-run; no Microsoft tenant change during test. New rebuild route LIVE_UNVERIFIED until execution.

## References
- https://learn.microsoft.com/en-us/graph/api/intune-apps-win32lobapp-delete?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-delete?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/intune/app-management/deployment/troubleshoot-win32

The original dirty Vision master is preserved; Dell enrollment, Windows profile, drivers, physical monitors, and Office account are not reset.
