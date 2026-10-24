# Doxa Setup - Intune silent pilot (NO SILICON MOTION DRIVER)

Pilot only. Provides deterministic install / detect / uninstall for the Doxa Setup support application, not the Silicon Motion MSI. No Doxa driver, automatic restart, registration, policy, cloud credentials or display changes. Not a signed production release.

## Package
- DoxaPilot.ps1: install/uninstall/detect script with safe fail and exit codes
- DoxaSetupPayload.zip: sixteen-source-file personal preview, SHA-256 manifest checked
- Test-DoxaPilot.py: tests only an isolated temporary directory
- README.md

For Intune Win32 app, use Microsoft's Win32 Content Prep Tool with source folder this directory and setup file DoxaPilot.ps1. Copy the tool OUTSIDE the source folder.

Install command: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Install

Uninstall command: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Uninstall

Install behavior: System. Target: an isolated disposable enrolled Windows test device. Detection rule: custom script DoxaPilot.ps1 with default Action Detect; run 64-bit; detected only on exit 0 with nonempty stdout. No dependency on a Silicon Motion driver install. Driver is a separate future package after OEM rights and safe clean install/rollback qualifications.

Do not assign this unsigned pilot to production devices or bypass WDAC/AppLocker. A signed standalone executable and enterprise policy matrix are release gates. The pilot verifies Intune plumbing, not driver deployment or product readiness.
