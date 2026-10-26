# Doxa Setup - Intune silent pilot (NO SILICON MOTION DRIVER)

Pilot only. Provides deterministic install / detect / uninstall for the Doxa Setup support application, not the Silicon Motion MSI. No Doxa driver, automatic restart, registration, policy, cloud credentials or display changes. Not a signed production release.

## Package
- DoxaPilot.ps1: install/uninstall/detect script with safe fail and exit codes
- DoxaSetupPayload.zip: sixteen-source-file personal preview, plus a separately hashed launcher and readme (19 total archive files)
- Test-DoxaPilot.py: ten isolated temporary-directory checks, including unexpected-file detection, safe uninstall refusal and malicious extra-EXE ZIP rejection
- README.md

For Intune Win32 app, use Microsoft's Win32 Content Prep Tool with source folder this directory and setup file DoxaPilot.ps1. Copy the tool OUTSIDE the source folder.

Install command: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Install

Uninstall command: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Uninstall

Install behavior: System. Target: an isolated disposable enrolled Windows test device. Detection rule: custom script DoxaPilot.ps1 with default Action Detect; run 64-bit; detected only on exit 0 with nonempty stdout. No dependency on a Silicon Motion driver install. Driver is a separate future package after OEM rights and safe clean install/rollback qualifications.

Do not assign this unsigned pilot to production devices or bypass WDAC/AppLocker. A signed standalone executable and enterprise policy matrix are release gates. The pilot verifies Intune plumbing, not driver deployment or product readiness.

### Deterministic integrity diagnosis for test fixtures
DoxaPilot.ps1 normally logs no internals or protected paths. For isolated installer qualification only, environment flag DOXA_PILOT_DIAGNOSTICS=1 writes short DOXA_INTEGRITY_REASON codes to stderr when manifest/path/hash/unexpected-file validation refuses a payload. It does not weaken the gate or grant permissions. Test-DoxaPilot.py enables these codes only inside its ephemeral fixture. Never enable verbose Windows file paths or customer/private identifiers in public logs.

### Silent-install SHA-256 portability ? 26 October 2026
On GitHub hosted Windows run 40309874786, machine-process PowerShell reported CommandNotFoundException at the Get-FileHash call even though Dell local full lifecycle passed. Managed DoxaPilot.ps1 now calculates SHA-256 using .NET SHA256 and FileStream with deterministic disposal, independent of PowerShell module availability. The same source and generated file hashes remain mandatory. Never ignore failed hashing, unknown files or file-system access errors; the existing fail-closed test behavior is preserved.
