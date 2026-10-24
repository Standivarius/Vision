# Doxa SMI770 official signed MSI — non-installing package qualification checkpoint
**16 October 2026 | MARIUS-DELL | No installation or reboot performed**
**Verdict:** **VENDOR_BINARY_VERIFIED, ENTERPRISE_PACKAGE_NOT_APPROVED.** Existing four working Windows desktops and driver version \`4.7.6.0\` preserved.

## Proven supplier provenance and file identity

Official supplier download page: https://www.siliconmotion.com/downloads/SM770-drivers.html

Official ZIP URL: https://www.siliconmotion.com/downloads/SMI-USB-Display-SW-MSI-for-Windows-4.7-R06.zip

Downloaded with PowerShell \`Invoke-WebRequest\` to ignored \`artifacts/vendor/smi770-msi-20261016/\` solely for qualification, **not repository distribution**. ZIP contains one MSI.

| Field | Verified observation |
|---|---|
| ZIP byte count | 6,598,200 |
| ZIP SHA-256 | \`DD41326F9641D6E43DC2F2A42AC515902F497F7A376E77F9FB5D22DB6DD8C383\` |
| MSI name | \`SMIUSBDisplaySW770.msi\` |
| MSI byte count | 6,816,256 |
| MSI SHA-256 | \`3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4\` |
| Authenticode validation | \`Valid\` (checked by Windows) |
| Certificate subject | Silicon Motion, Inc. |
| Certificate issuer | DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1 |
| Certificate thumbprint | \`81956F4C8904963B707B994E42FEA1EDBBFA51C6\` |
| MSI ProductName | Silicon Motion USB Display Driver 770 |
| MSI ProductVersion | \`4.7.6\` |
| MSI ProductCode | \`{50676769-B66A-4B79-8D38-D763F3A2C5BD}\` |
| Package declared Windows user scope | \`ALLUSERS=2\` (Windows Installer property, not evidence of successful managed IT deployment) |

The installed Dell driver is \`SiliconMotion 4.7.6.0\`, \`oem101.inf\`, Microsoft WHCP signed, SMI770 USB ID \`USB\VID_090C&PID_770A\`. The MSI's declared version **4.7.6** is consistent but **not byte-level proof** that the internal INF/CAT/SYS match the installed DriverStore package.

## MSI structure and rollout risks observed without execution

Read-only Windows Installer COM \`OpenDatabase(..., 0)\` inspected MSI \`Property\`, \`File\`, \`CustomAction\`, \`LaunchCondition\`, \`Upgrade\` and \`Media\` tables. Relevant contents include:
- \`SMIIddX770.inf\`, \`SMIIddX770.dll\`, \`smiiddx770.cat\` in x86 and x64 roles.
- \`DriverInstall.exe\`, \`DriverUninstall.exe\`, \`DriverUninstall2.exe\`, \`devcon.exe\`, \`ScanforhardwareChanges.exe\`.
- Driver action references to observed \`USB\VID_090C&PID_770A\` and family \`PID_0770\` / \`PID_0772\`.
- **Explicit \`/remove\` custom actions** for SMI USB device IDs. Thus a repair/reinstall/upgrade may remove and re-enumerate the Doxa display device, possibly interrupting all attached external desktops. **Do not execute vendor MSI against currently working Dell merely to check it.**
- MSI \`ProductVersion\` and \`ProductCode\` extracted without a single installer action. Actual custom-action sequence, rollback and exit statuses still require isolated tests.

The existing repo's \`app/packaging/doxa-setup/Deploy-DoxaDriverPackage.ps1\` rejects unapproved packages, uses fixed \`msiexec /i ... /qn /norestart /L*v\` only after qualified approval and explicitly avoids auto-reinstalling an already approved identical driver.

Created reviewed candidate metadata \`app/packaging/doxa-setup/profiles/vendor-msi-reviewed.NOT_APPROVED.json\` containing the real hashes, signing thumbprint, source, version and remaining review gates. **Do not set \`approval_status=approved\` yet.** Legacy \`vendor-msi-approval.TEMPLATE.json\` remains a safe placeholder.

## Remaining true qualification gates

1. **OEM / supplier rights:** confirm Doxa is permitted to redistribute the signed Silicon Motion MSI with its product and/or license it through enterprise IT. A download link alone does not grant onward redistribution.
2. **Embedded driver content:** inspect and verify \`SMIIddX770.inf\` DriverVer, CAT/SYS signers/versions and support for observed Doxa hardware revision; no unsigned modifications or Windows policy changes.
3. **Installer staging:** on a **separate, approved** Windows test laptop/VM with suitable real hardware, run signed MSI under IT-approved SYSTEM/admin context with logging, no end-user admin request, no automatic reboot, and test detection, policy blocks, install, upgrade, uninstall and rollback.
4. **Security and system compatibility:** validate Windows 10/11, HVCI/Memory Integrity, WDAC/App Control/AppLocker, EDR interference, Intune/ConfigMgr/GPO packaging, offline install where approved, and enterprise deployment documentation.
5. **User-session health:** independently validate WGC/D3D11 Vision presentation across the four live sources, and reconnection/stability/performance on lower-spec laptops.

Until these are done: **current Dell driver working/WHCP signed and vendor MSI signed is a good candidate, not production Doxa installer qualification.**

## Next chat
The owner's immediate instruction is **formal new-chat handover**, so the next chat should verify this source and complete comprehension gate before doing more engineering. Refer also to [four Windows source qualification](2026-10-16__doxa_four_independent_windows_desktops_qualification_v0.1.md), \`CHAT_HANDOVER_INSTRUCTIONS.md\` and \`dev-harness/workitems/ins-001.json\`.
