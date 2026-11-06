# Doxa Intune pilot — install retry pending; managed uninstall gate ready

**Date:** 25 October 2026, MARIUS-DELL local clock 00:15 and subsequent read checks.
**Repo:** C:\\wt\\doxa-installer-clean-pr-20261024, clean draft PR #78; canonical Vision master preserved.

## Confirmed status

- Existing DMR Ergonomics Intune Win32 app **62fcb7ce-ebc2-4407-9b51-0710cb809c32** remains `published` on committed content version 1 and has one Required assignment to exact Dell-only group **3f74c6a3-d470-4d78-8c17-756381465095**.
- Dell Intune Management Extension is running; original failed installation attempt occurred 24 Oct at 23:41 local and is confirmed in Windows PowerShell Event 4100: SYSTEM execution policy blocked `DoxaPilot.ps1`.
- Microsoft Graph install/uninstall command lines were corrected with process-scoped `-ExecutionPolicy Bypass` and validated by live readback; system-wide policy and driver unchanged.
- **No later installation attempt confirmed** in `C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Logs\\AppWorkload.log` as of approximately 00:15, and Program Files Doxa Setup remains absent with Detect exit 1. The IME main service log is updating; existing global reevaluation (GRS) record from failed attempt is present.
- Official Microsoft Win32 app documentation explains retry and detection re-evaluation can run on a **24-hour** cadence, while IME assignment check-ins normally happen every 8 hours and can also be triggered via service restart. Restart/sync was already tried; it did **not** override the failure at this checkpoint. Do **not** circumvent via registry deletion, endless service restarts, full device reboot or changing LocalMachine PowerShell execution policy.
- Doxa driver 4.7.6.8001 and three attached panels remain healthy in most recent full read-only preflight.
- A single guarded Graph PATCH to the pilot app's **Notes** was previously accepted on 25 Oct 00:07. This updates `lastModifiedDateTime`, but it is **not confirmed** to increment Intune's GRS `MetadataVersion` or trigger reinstallation, so make no such claim.

## Ready-to-use controlled uninstall test (never executed prematurely)

- `app/packaging/doxa-setup/enterprise-intune-pilot/Switch-DoxaIntunePilotToUninstall.py` was added. No flags = local-only dry run. `--execute` is guarded by successful on-device `DoxaPilot.ps1 -Action Detect` and Microsoft Graph identity/assignment verification. It will **refuse** to switch while Doxa is not installed.
- Before a real Graph change it asserts exact Doxa application UUID/name, publisher, win32 type, published state, committed version 1, exact fixed install/uninstall commands, unique compliant enrolled Dell, unchanged dedicated Dell-only security group with exactly one matching device member, and exactly one Required assignment to that group. It then uses Graph `/assign` to replace Required with Uninstall for the same **one** group, verifies readback, never includes Silicon Motion driver operations or MDM unenrollment, and does not claim uninstall complete merely because assigned.
- Separate offline tests `Test-DoxaIntuneUninstallSwitch.py`: **5/5 PASS** including pre-install refusal, one-group-only payload, wrong-group/changed-app/changed-assignment refusal. `Switch-DoxaIntunePilotToUninstall.py` dry run PASS, `DOXA_APP_DETECTED=False`, zero tenant mutations.
- **Do not run --execute until real Dell first-install PASS**: IME reports Install exit 0, Doxa package integrity Detect exit 0 and original hardware/driver baseline holds. After applying Uninstall, verify actual IME uninstall logs, install directory absent, Detect exit 1, Doxa signed driver and screens still intact.
- Only then initiate supported MDM **Retire/Disconnect** of the temporary Dell management connection, keeping pre-existing Entra/Office account intact. Do not use Wipe or `dsregcmd /leave`. Recheck OS, Office, Vision and driver baseline.

Official Microsoft references:
- https://learn.microsoft.com/en-us/intune/app-management/deployment/win32
- https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows

**Exit state:** Server app publish/assign PASS, IME download/first attempt PASS, first install FAIL (previous policy), current corrected retry PENDING, managed uninstall ready but NOT RUN, Dell unenrollment NOT RUN.
