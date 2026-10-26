# Doxa Intune pilot — first genuine published, Dell-only assignment
Date: 24 October 2026 (Europe/Bucharest). Clean draft PR #78.

## Confirmed live by Microsoft Graph, authenticated with DPAPI MSAL cache
- Existing DMR Ergonomics tenant; `MARIUS-DELL` uniquely `mdm` managed and compliant.
- **Published** Doxa app-only Win32 pilot GUID `62fcb7ce-ebc2-4407-9b51-0710cb809c32` confirmed after the previous initial content version was accepted. App-level `committedContentVersion = "1"`.
- Original first failed, unpublished, unassigned Doxa pilot `5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4` removed after exact identity, status, assignment and failed-file checks. No user application was removed.
- Encrypted package `DoxaPilot.intunewin`: source SHA256 `FFCA7CA75A5EB27083E1D3099B202929073EA97094CC8565610AE28824A44E36`, encrypted 42,960 bytes, Azure block list size independently verified, Microsoft server reported `commitFileSuccess` and `isCommitted=true`.
- Initial app publish PATCH missing `@odata.type` failed; fixed and publisher resumed **the same committed file**, without repackaging or re-uploading. Graph verified `publishingState=published`, version 1.
- **Exactly one** Microsoft Graph application assignment, `intent=required`, `target.groupId=3f74c6a3-d470-4d78-8c17-756381465095`, the previously checked group containing only `MARIUS-DELL`. Not assigned to all users or all devices.
- Encrypted Windows DPAPI Microsoft delegated cache exists and was successfully reused silently by separate processes without new MFA/device code. Cache remains outside Git and revocable; delegated Graph permissions have potentially broad tenant authority despite our hardcoded app/group/device guards.

## Device installation — not confirmed
- Initial Dell post-assignment read at approximately 23:34 local time: **IntuneManagementExtension absent**, no Intune agent logs yet, `%ProgramFiles%\Standivarius\DoxaSetup` not present, `DoxaPilot.ps1 -Action Detect` exit 1.
- Doxa preflight still `verified_signed_driver_and_hardware`, signed SMI driver `4.7.6.8001`, three Doxa panels. No physical/hardware changes. Canonical Vision master still `32f8960`.
- Graph's app read verified published/version 1; assignments GET verified exactly one Dell-group Required assignment. Generic `/deviceStatuses` and `/deviceInstallSummary` paths returned 400 in this tenant (unsupported); no installation claim derived.
- Next gate: trigger Windows Settings > Accounts > Access work or school > the MDM work connection > **Info > Sync**, or await automatic MDM check-in. Microsoft Intune Management Extension normally installs when a Win32 app is assigned. Observe actual IME service, logs, hashes and PowerShell detection.
- Once Installed confirmed, test uninstall under an Intune-controlled **Uninstall** assignment (if safe) and verify the app-only payload removed while the Doxa signed driver, displays, Vision and Office access remain intact. Only then remove temporary management with supported guidance (Retire/Disconnect), not Wipe or dsregcmd /leave.
- This is **not yet a completed managed deployment qualification**; app publication and assignment passed, actual installation and uninstall remain pending.

## References
- https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows
- https://learn.microsoft.com/en-us/intune/app-management/deployment/troubleshoot-win32
- https://learn.microsoft.com/en-us/intune/user-help/device-actions/sync-device-windows

All changes in isolated Doxa installer worktree; no modifications to the dirty canonical master, no vendor MSI redistribution or driver installation, no company-wide policy change.
