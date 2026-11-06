# Doxa Intune pilot: first authenticated attempt and v1.0 Graph request fix
**Date:** 24 October 2026
**Surface:** isolated `doxa/installer-clean-pr-20261024` worktree, GitHub draft PR #78. Existing main Vision master dirty state remains protected.

## Actual authenticated results, in order
1. The DMR Ergonomics administrator approved Microsoft Graph delegated scopes for Doxa one-device Intune pilot publishing.
2. The publisher queried MARIUS-DELL in the existing tenant, confirmed it was uniquely managed and compliant, and resolved its Entra directory ID. It created the dedicated, Doxa-specific test security group `3f74c6a3-d470-4d78-8c17-756381465095` and ensured that Dell is its only member before proceeding.
3. POST `/v1.0/deviceAppManagement/mobileApps` returned HTTP **400 BadRequest**. **No Doxa app was created/published/assigned and no Intune software installation started.** Other unrelated applications/policies were not modified.
4. Original Graph error logger reported only HTTP code and omitted the useful validation detail. The earlier token was intentionally kept in memory and was not saved; the process exited after the failure.

## Cause identified and corrected
- The create request included `minimumSupportedOperatingSystem`, a **Graph beta-specific** complex property; for **v1.0**, Microsoft documents `minimumSupportedWindowsRelease` instead. Pilot changed to `Windows11_23H2` (Dell uses Windows 11).
- Added explicit `@odata.type` to nested `win32LobAppInstallExperience`.
- Added explicit `@odata.type=microsoft.graph.fileEncryptionInfo` in the future file commit request (not exercised live yet).
- Error reporting now surfaces a bounded, filtered Microsoft schema error message when it contains no token, URL or email, so the next rejected request is diagnosable.
- Added `test_create_payload_uses_v1_graph_fields_not_beta_only_fields` and the six pre-existing zero-network publisher safety tests: **7/7 PASS**; no tenant Graph writes occurred in these regression checks.
- Source and app-only `.intunewin` payload unchanged: SHA256 `FFCA7CA75A5EB27083E1D3099B202929073EA97094CC8565610AE28824A44E36`.

## Next live step / permissions
- With explicit owner sign-in, rerun the one-device publisher. It first checks current unique/compliant MARIUS-DELL and reuses the existing dedicated group; it refuses unrelated members and duplicate Doxa applications. The group ID above is recorded to reconcile any unexpected duplicate or partial Graph failure.
- If the create succeeds, verify content upload, publishing, one-group assignment, Dell Intune Management Extension and actual device install/detect/uninstall logs; never infer success from app creation alone.
- No Silicon Motion MSI/driver install, reboot, tenant-wide assignment, Microsoft country correction or corporate security policy change is in scope.
- Unenrollment caution and exact rollback evidence remain under `artifacts/releases/intune/dell-live-enrollment-20261024/MDM_ROLLBACK_CHECKPOINT.md`.

## Evidence level
**Graph create request fix: LOCAL_TEST_PASS, LIVE_UNVERIFIED.** The previous HTTP 400 is real; the exact remote validation message was not captured and the beta/v1 schema mismatch is a strong cause hypothesis, not independently proved to be the sole cause.

Microsoft source: https://learn.microsoft.com/en-us/graph/api/intune-apps-win32lobapp-create?view=graph-rest-1.0
Microsoft source: https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-commit?view=graph-rest-1.0
