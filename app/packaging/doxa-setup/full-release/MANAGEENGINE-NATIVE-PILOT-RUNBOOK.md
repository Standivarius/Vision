# Standivarius Doxa — current native ManageEngine deployment

Status: **controlled engineering pilot, not qualified for unattended mass deployment**. This is the native DoxaDeploy.exe channel. Do not use the old DoxaPilot.ps1 enterprise-preview runbook for this package.

## Artifact and provenance

Obtain the publisher-signed `ManageEngine/DoxaDeploy.exe` from the same finalized release used for retail and Intune, and verify the signer certificate thumbprint, timestamp and release SHA-256 against `RELEASE-MANIFEST.json`. The review-build executable is UNSIGNED and is not for commercial distribution.

Unpack `ManageEngine/Doxa-Managed-Windows.zip` to a managed package source directory (the archive contains DoxaDeploy.exe). The installer already embeds a pinned, original Silicon Motion MSI. **OEM redistribution permission is still a commercial release gate.**

## Managed package definition

| Field | Required value |
|---|---|
| Package type | Windows executable, 64-bit |
| Context | SYSTEM / machine |
| Install command | `DoxaDeploy.exe /install` |
| Software detection command | `DoxaDeploy.exe /detect` |
| Repair command | `DoxaDeploy.exe /repair` |
| Uninstall command | `DoxaDeploy.exe /uninstall` |
| Hardware verification (separate, not software detection) | `DoxaDeploy.exe /verify` |
| Three Doxa PnP identities (separate check) | `DoxaDeploy.exe /verify-panels` |
| Success | Exit code 0 |
| Soft reboot required | Exit code 3010; coordinate with IT, **do not force automatic restart** |
| Failure | All other nonzero codes, including 30 |
| Installation logs | `C:\Program Files\Standivarius\DoxaMaintenance\Logs\` |
| Targeting | One approved pilot endpoint, with a physically usable built-in screen |

**Critical installation condition.** Disconnected Doxa no longer triggers the vendor MSI automatically. The /install command installs the application and defers driver setup until Doxa USB is physically connected and /repair or /install is explicitly run later. Therefore /detect may pass while /verify fails; this is correct, and must not cause an endless redeployment loop. Do not use hardware state as the software detection rule.

For an attended installation pilot, check power then USB-C data first, and run the native install only after the laptop panel is independently usable. The /verify-panels command validates reported PnP identities but **does not prove** Windows Extend layout or physical screen mapping.

## Acceptance pilot

Use a throwaway/test endpoint or approved Dell installation window, not a live mass group. Confirm published signed bytes and IT policy before any installation. Capture:

1. pre-install /detect and /verify results without modifying anything;
2. managed execution as SYSTEM, including return code and exact process log;
3. /detect after install with USB present and absent: only software installation should matter;
4. /verify and /verify-panels after physical USB connection, and **manually** verify laptop plus three independently extended screens in Windows;
5. return-code handling (0/3010/other), including no forced reboot;
6. explicit /repair and /uninstall, followed by detection check and expected preservation of a healthy original vendor driver;
7. signature/publisher trust, allowlisting and script language-mode/GPO restrictions.

No ManageEngine agent install, uninstall or signed publisher rollout was executed by source remediation. The previous live deployment gaps remain open.
