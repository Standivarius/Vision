# Doxa Intune Win32 pilot — retry after the first failed SYSTEM attempt

**Date:** 25 October 2026, Romania local, after 00:08 (Windows timestamp +03:00 at checkpoint)
**Workspace:** C:\\wt\\doxa-installer-clean-pr-20261024; canonical dirty Vision master untouched.
**Pilot app:** 62fcb7ce-ebc2-4407-9b51-0710cb809c32. **Pilot group:** 3f74c6a3-d470-4d78-8c17-756381465095. Scope Dell only.

## Live findings

1. User restarted IntuneManagementExtension from Task Manager. Service running normally, new IME process PID 33628; local IntuneManagementExtension.log recorded restart, registration and Windows policy contact between 00:03 and 00:08, including Win32RequiredApp workload timer.
2. Doxa installation is **still not present** at 00:08. Directory Program Files\\Standivarius\\DoxaSetup absent; DoxaPilot -Action Detect exit 1. AppWorkload.log contains no new Doxa installer execution after original **23:41:31** attempt. The only evidenced installer failure is 23:41 PowerShell Operational Event 4100 (SYSTEM scripts disabled) and IME exit 1. Do not report a second failed attempt or successful install.
3. Corrected Intune app Program install/uninstall commands were confirmed through Microsoft Graph with process-only `-ExecutionPolicy Bypass`; app still published, content version 1, exactly one Required assignment to Dell-only group. No machine-wide PowerShell policy changes.
4. AppWorkload.log had recorded GRS value for the original failed policy at 23:41, and later recognised this entry. Intune retry cooldown is a plausible explanation for absence of immediate reattempt after restart, not definitively proved. Official Microsoft docs state IME app polls and retries are distinct from ordinary MDM check-ins. A published community study from Aug 2026 suggests changing an app's Description or Notes increments MetadataVersion and causes reevaluation at a later check-in, but its author explicitly notes **Graph PATCH untested** in that study.
5. A single guarded Graph PATCH was executed on **only this exact Doxa app** at 00:07:24 local to append `IME retry evaluation requested 2026-10-25 after SYSTEM command policy fix` to its **Notes**. Graph response and readback confirmed success; `lastModifiedDateTime` changed from `2026-10-24T20:50:24.8132996Z` to `2026-10-24T21:07:24.2367034Z`. Scope revalidated: unique managed/compliant Dell, group containing Dell only, one Required assignment, same install/uninstall commands, publisher, content version 1 and published status. No package, driver, Windows PowerShell policy or other tenant app changed.
6. A new IME policy/app check-in **after this Graph notes update is not yet confirmed**, and installation remains **NOT DETECTED** as of 00:08:44. The metadata refresh is a limited non-destructive attempt, not a proven reset of Intune GRS in this tenant.
7. Canonical Vision HEAD 32f8960 and Doxa signed SMI driver 4.7.6.8001 with three panels remained healthy in the most recent full hardware preflight, before the metadata-only patch. No further driver changes were made.

## Next checkpoints, without repeated prompts or registry modification

- At the next actual IME required-app policy check-in, inspect `C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Logs\\AppWorkload.log` for this exact app GUID and the **new** `-ExecutionPolicy Bypass` install command. Inspect `IntuneManagementExtension.log` for startup and policy-fetch failures.
- If run occurs: verify DoxaPilot Install exit 0, hash-based Detect exit 0, Program Files installation files, Microsoft Intune app state, and Doxa preflight driver/panels before setting install PASS.
- If GRS is still active, do **not** delete IME registry entries, spoof success, modify machine execution policy, alter drivers or repeatedly restart Windows/Intune service. Either use a supported portal app Save/check-in with explicitly authorised Windows administrator GUI action, or let the normal evaluation schedule pass.
- After real Install PASS: verify Intune-managed Uninstall with exact private Dell group, uninstall/detect and pre/post original Vision/Doxa/Office work environment, then temporary management removal by Microsoft-supported process (Retire/Disconnect), not Wipe.
- Keep the Microsoft Graph delegated DPAPI cache under the Windows current user only; it is revocable and potentially tenant-wide in authority despite publisher's internal narrow guards.

References:
- https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
- https://alttabtowork.com/2026/08/06/decoding-the-intune-win32-app-grs-hash/

**Bottom line:** Live enterprise deployment succeeded through app publish/assignment/IME install/download; controlled Win32 first install failed due to SYSTEM execution policy, corrected app command was deployed, and actual retry/install/uninstall remain pending. Avoid conflating MDM sync or IME service restart with successful installation.
