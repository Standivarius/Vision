# Doxa enterprise driver packaging: observed real-device baseline and deployment gate
**Date:** 16 October 2026. **Project:** Vision, MARIUS-DELL. **State:** real device recognised, installation package not yet qualified or shipped.
**Next main work:** complete signed-vendor-MSI qualification, independent display extension, then consented managed-Windows deployment test.
**Source of evidence:** read-only Windows PnP/CIM / live connected hardware; screenshot from owner; official Silicon Motion and Microsoft references.

## Verified host observations (DO NOT claim production qualification)

| Evidence | Observed result |
|---|---|
| Host | Windows 11 Pro, build 26300, integrated Intel UHD GPU |
| External USB display processor | **SMI770 USB Display** |
| Hardware identifier (non-serial prefix) | \`USB\\VID_090C&PID_770A\` |
| Installed INF | \`oem101.inf\` (\`SMIIddX770.inf\` vendor INF content) |
| Driver provider/version | SiliconMotion, **4.7.6.0**, INF DriverVer 28 May 2026 |
| Driver signature | **Signed**, Microsoft Windows Hardware Compatibility Publisher |
| Connected panels | Distinct Generic Monitor **(L)**, **(T)**, **(R)** plus integrated laptop panel |
| Attached Windows desktop graphics sources | DISPLAY1 (Intel), DISPLAY10 and DISPLAY11 (SMI770). DISPLAY11 reports **two monitors**; DISPLAY12 (SMI770) is currently **not attached** |
| Windows UI | Screenshot shows tile **3|4**, consistent with duplicated displays |
| Inference | Controller/driver appears present and functional; **all four independently extended desktops are not yet verified**. Windows source mode and device/path behaviour must be qualified separately |
| What was NOT tested | Driver clean install, enterprise WDAC/AppLocker/HVCI policies, secure deploy, signed MSI permissions, upgrade/rollback, exact Doxa OEM release, actual 4-independent-screen capture and UX |

**Important:** A driver appearing automatically on this laptop may result from Windows driver-store staging, prior installation or Windows Update. This does *not* prove no driver provisioning is needed on managed/locked-down endpoints. Also do not infer from this host alone that every Doxa hardware revision is SMI770.

## Build strategy: wrap signed vendor driver; don't author a kernel graphics driver

1. Use the official signed **Silicon Motion SM77x Windows driver package** for verified Doxa chipset/revision. Silicon Motion distributes both a Windows driver and a **Windows MSI for IT deployment**, with Group Policy instructions. Use the OEM driver without patching INF/SYS, bypassing signature checking or changing Windows security policy. Repackaging/redistribution requires confirming OEM licence and enterprise approvals.
2. Separate **driver** and **Vision/Doxa application** artifacts. Existing Vision Velopack per-machine MSI is a software package; it is **not automatically the signed Silicon Motion USB driver package**. In Intune/ConfigMgr, model vendor driver dependency/preflight before app. In a normal end-user state, do not request administrator credentials.
3. Build Doxa-owned **hardware/driver assessment and diagnostics** around known compatible PnP IDs, published INF, signature, Windows build, three Doxa monitors and user-session WGC/D3D graphics health.
4. IT deploys under an approved **SYSTEM/administrator context**, using silent, logged MSI installation and a documented detection/upgrade/retry code. Do not reboot automatically. Reboot/maintenance windows are owned by organisation policy. Support offline installation using approved signed packages.
5. For **WDAC/App Control, AppLocker, EDR, application allowlists, least privilege, Intune, Entra join and HVCI/Memory Integrity**, return explanatory IT-facing failure/approval records rather than disabling protections. Confirm both Doxa app/binaries and Silicon Motion driver signatures are accepted. Do not create unofficial driver certificates.
6. Enterprise package must carry fixed source URL, hashes, signer fingerprint, vetted installer and uninstall/rollback behaviour, supported Windows/HVCI matrix and licence/redistribution rights. Do not claim a different/newer public MSI is a safe replacement without certification.

## First code now in repo

- \`app/packaging/doxa-setup/profiles/smi770-observed.json\`: observed hardware/driver identity with \`observed_not_oem_approved\` qualification; *not* production packaging approval.
- \`app/packaging/doxa-setup/Get-DoxaDriverState.ps1\`: **read-only** live driver/panel assessment. Does not expose device serial numbers in its normal JSON output. Reads independent fixture JSON for deterministic tests; does not claim four independent desktops from four PnP monitors.
- \`app/packaging/doxa-setup/Deploy-DoxaDriverPackage.ps1\`: **audit by default**. An explicit \`-Apply\` requires a local vendor MSI, a separately qualified approved manifest with matching actual SHA256/signing certificate/profile, IT-admin/SYSTEM execution and existing writable IT log directory. The only privileged operation is fixed-format \`msiexec.exe /i ... /qn /norestart /L*v\`. No download, no policy bypass, no firmware update, no vendor INF mutation, no reboot, no arbitrary command execution. Already-approved, already-present driver is **not** reinstalled. This is not yet an approved production package.
- \`app/packaging/doxa-setup/profiles/vendor-msi-approval.TEMPLATE.json\` is intentionally **NOT_APPROVED** and has placeholder hash/certificate; it cannot be used to install.
- \`app/packaging/doxa-setup/tests/Test-DoxaDriverReadOnly.ps1\`: four deterministic negative/normal fixtures plus a live audit path. Does not install MSI or modify machine.
- Existing \`run-surrogate.ps1\`, \`simulate.ps1\`, \`smoke.ps1\`, \`visual_diagnostics.exe\`, \`visual_app.exe --health-check\` and Velopack \`-EnterpriseMsi\` remain the base; none was changed or invoked to alter the system today.

**Read-only examples** (use standard approved PowerShell execution for development; no ExecutionPolicy bypass):
\`\`\`powershell
& .\app\packaging\doxa-setup\Get-DoxaDriverState.ps1
& .\app\packaging\doxa-setup\Deploy-DoxaDriverPackage.ps1
& .\app\packaging\doxa-setup\tests\Test-DoxaDriverReadOnly.ps1
\`\`\`

**Controlled deployment example, NOT TO RUN UNTIL QUALIFIED:** prepare an approved manifest with *actual* signature/hash from vetted vendor MSI, execute package on IT-managed test system and specify \`-Apply -PackagePath ... -ApprovalManifest ... -EvidenceDirectory ...\`. It is not safe to test on the currently working Dell without owner approval and a verified recovery path. No file from the vendor is redistributed in this repository.

## Mandatory next acceptance checks

**G1: physical display configuration and driver identity.** In Windows Display Settings select the 3|4 combined tile and review the **Multiple displays** mode. Test extending instead of duplicating under attended operator control, confirm all four numbered desktops become individually arranged, and record which panel corresponds to each. Windows duplication may be a configuration setting, not a driver limitation. If the option is missing or fails, inspect active display paths, driver limitation and USB link/firmware with evidence—not blind driver reinstalls. Validate Vision WGC capture on all active source screens only after stable extended topology.

**G2: distribution candidate.** Obtain official signed MSI version and exact supplier permissions. Confirm hash, Authenticode signature, supported hardware ID, Windows build, zero-interaction silent install, return codes 0/3010, read-only detection, blocked-policy failure, App Control and HVCI status, offline package path, upgrade and reversal. Then approve pinned manifest. **Never** auto-update a working driver based solely on version numbers.

**G3: enterprise deployment.** Test one dedicated ordinary Windows endpoint and one IT-managed policy scenario (Intune/ConfigMgr/GPO where available), standard-user session/no admin credentials, signed install package, appropriate restart policy, privacy-safe logs, per-machine package/signature and interactive-session graphics health. Do not pretend Dell's successful auto-install covers enterprise deployment.

**G4: UX.** Test a normal employee plug-in flow with clear statuses and no IT visit, and blocked-case support code for remote IT resolution, ideally supported by the UK contact's experience. Full support for multiple languages is a separate content/localisation track, not a kernel driver change.

### Public references

- Silicon Motion SM77x official driver and MSI (2026): https://www.siliconmotion.com/downloads/SM770-drivers.html
- Silicon Motion Windows MSI Group Policy distribution tutorial: https://www.siliconmotion.com/downloads/video/SMI_Windows_SM770_MSI_File_User_Manual.pdf
- Microsoft Windows PnPUtil driver operations: https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-examples
- Microsoft Intune managed Win32 apps, silent install/dependencies/SYSTEM and detection: https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
- Microsoft Windows Driver Store: https://learn.microsoft.com/en-us/windows-hardware/drivers/install/driver-store
- Microsoft deployment/signing/app control: https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/

## Status

**G1 partial:** signed installed driver + three panels verified; independent four-desktop extension not verified. **G2–G4 pending.** Driver package not distributed or installed; no unattended IT deployment tested. The correct next owner-attended action is the 3|4 display-extension check, followed by verified vendor MSI qualification. Changes are confined to non-mutating installer development scripts, fixtures and this development note.
