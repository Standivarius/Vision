# Doxa Intune pilot — device check-in and SYSTEM PowerShell execution-policy failure

Date: 24 October 2026. Test endpoint: MARIUS-DELL. Scope: single-device Doxa app-only Intune pilot; no Silicon Motion MSI/driver replacement.

## Observed real-device sequence (Europe/Bucharest)

- Owner used Settings > Accounts > Access work or school > DMR Ergonomics MDM > Info > Sync.
- Windows installed and started **IntuneManagementExtension** (Automatic/Running), logs under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- IME downloaded, decrypted and staged Doxa Win32 app `62fcb7ce-ebc2-4407-9b51-0710cb809c32` from its published/committed content 1. PowerShell detection under SYSTEM correctly reported not-installed.
- At **23:41:31** IME launched `powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Install` in the machine SYSTEM session.
- At **23:41:34**, Windows PowerShell Operational log **Event ID 4100** under **WORKGROUP\SYSTEM**: `DoxaPilot.ps1 cannot be loaded because running scripts is disabled on this system`. Error: `UnauthorizedAccess`. This establishes the actual first-install root cause.
- IME reported installer `lpExitCode 1`, HRESULT `-2147024895`, enforcement **Error**, and subsequent hash-based detection **NotDetected**. This is not a package download failure, driver failure or manifest hash failure.
- Native test under the current logged-in user is NOT equivalent to SYSTEM, because execution policy scopes differ by account.
- Doxa check remained `verified_signed_driver_and_hardware`: driver 4.7.6.8001, three panels. Vision master unchanged (HEAD 32f8960). No install folder created.

## Narrow live correction

- Added and tested `Patch-DoxaIntuneCommands.py` with exact GUID/name/publisher/committed version 1/published status, and single Required assignment to Dell-only group. The script refuses unknown metadata/commands or wider targeting.
- Microsoft Graph PATCH **SUCCESS**, and subsequent GET verified commands:
  - `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\DoxaPilot.ps1 -Action Install`
  - `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\DoxaPilot.ps1 -Action Uninstall`
- `-ExecutionPolicy Bypass` affects only the launched PowerShell process. No LocalMachine, Group Policy, registry, driver, app content, Windows account or Intune group changed.
- Corrected future first-creation publisher default to use the same safe invocation.
- Offline guard tests: **5 command-patch + 22 original publisher tests PASS**; server read-after-write confirmed same published package and Dell-only Required assignment.
- Live successful **reinstallation is NOT confirmed**. At ~23:51 Dell agent is running, pilot Detect still exit 1. Its Win32App logs include a GRS/re-evaluation entry for the earlier failure; do not force retry by deleting registry or agent caches.
- Next supported gate: initiate an IME check-in using Company Portal Settings > Sync, Windows Settings > Work or school > Info > Sync, or an authorised administrator restart of IntuneManagementExtension; verify its AppWorkload logs for updated command. The remote shell is medium-integrity and cannot restart the Windows service, so did not attempt UAC bypass. Do not represent the 23:41 failure as a later result after the Graph correction.

## Reversibility and exit gates
Continue only with Doxa app-only install/detection, Intune-managed uninstall, and then temporary MDM unenrollment through supported Retire/Disconnect (not Wipe), while preserving the existing Entra ID/Office connection and hardware driver. Save baseline at `artifacts/releases/intune/dell-live-enrollment-20261024/MDM_ROLLBACK_CHECKPOINT.md`.

Sources:
- https://learn.microsoft.com/en-us/intune/device-management/tools/management-extension-windows
- https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
