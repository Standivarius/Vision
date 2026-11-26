# DOXA Windows enterprise deployment - signed 0.4.0.13 candidate

**Status: qualified package integrity, not authorised for mass deployment.** Source: 9 November signed candidate (GitHub draft). This is Doxa Setup, not the Vision magnifier.

## Channels and support

- Windows 10/11 64-bit candidate, subject to validation on targeted OS images and policies. Product's pinned Silicon Motion SM770 MSI is **not evidence of a generic driver licence**.
- Personal: `DoxaSetup.exe` (interactive, signed); enterprise: `DoxaDeploy.exe` (native silent managed executable, signed), byte-identical between Intune and ManageEngine deliveries.
- The preexisting signed driver on a healthy Dell must not be reinstalled for a UI or package smoke test.

## Intune Win32 app settings (pilot only)

| Setting | Value |
|---|---|
| Installer content | `DoxaDeploy.intunewin` produced from the **signed** `DoxaDeploy.exe` |
| Install command | `DoxaDeploy.exe /install` |
| Uninstall command | `DoxaDeploy.exe /uninstall` |
| Install behaviour | System |
| Device restart behaviour | Determine based on return codes; never force reboot |
| Detection | Custom PowerShell calling `DoxaDeploy.exe /detect` and treating exit code 0 as installed; **do not** detect physical USB presence |
| Return codes | 0 success; 3010 soft reboot requested; other non-zero failure |
| Repair | `DoxaDeploy.exe /repair` via an approved admin remediation or agent operation |
| Diagnostic only | `DoxaDeploy.exe /verify` and `/verify-panels` |
| Logs | `C:\Program Files\Standivarius\DoxaMaintenance\Logs\` |

The detection script must use the durable installed maintenance executable path as defined by the installer and check its exit code; adapt the pilot wrapper to the Intune application's detection context. The hardware probes are not evidence of Windows Extend mode. The installer may defer driver installation while Doxa is disconnected: this is intentional and must not cause redeployment loops.

## Acceptance before deployment to customers

1. Independently verify downloaded publisher Authenticode signatures and trusted timestamps, and SHA-256 hashes against the exact signed manifest.
2. On a clean sacrificial Windows endpoint, test `/install`, `/detect`, `/repair`, `/uninstall`, reboot behaviour and non-corruption of unrelated preinstalled drivers, first disconnected and then with real Doxa attached.
3. On one approved Intune-targeted SYSTEM device, test first install, post-install detection, repair and removal; preserve logs and record Intune/IME return codes.
4. Check all four physical screens (laptop + three Doxa) in Windows Extend, not just PnP enumeration. Repeat on supported representative hardware and company policy images.
5. Confirm written OEM permission to redistribute the pinned MSI and sign off customer Terms, privacy, online AI and support processing before public release.

Full managed-agent pilot contract: `app/packaging/doxa-setup/full-release/MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md`.

**Never deploy this candidate to a broad Intune assignment or treat a working Dell's existing driver as a disposable test target.**
