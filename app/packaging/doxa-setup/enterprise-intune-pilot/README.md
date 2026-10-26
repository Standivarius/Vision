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

### Preview.6 one-device Dell-only Intune qualification
Publish-DoxaPreview6Intune.py is a one-version restricted use of the original Intune publisher. The encrypted local .intunewin must match SHA256 3db2530249693acffde9f6649043016044e02afaba3637794f2ec64ff29cc0da, source provenance a390b0b7757441d4c7693d263ece1225b516860c, and contain no vendor driver. It creates a distinct named application (not the October 25 Doxa pilot), checks a *single* compliant MARIUS-DELL and the exactly-one-Dell existing security group, and refuses unless original pilot remains uninstall. Default command without --execute is entirely read-only. --execute uploads and assigns only the new app to Dell under Intune SYSTEM. New app ID persists outside version control, under worktree artifacts/releases/intune. Never assign broadly, modify the old pilot, uninstall Silicon Motion or reboot. Independent local SYSTEM installation/uninstallation evidence must be captured before calling preview.6 managed-device qualified.

### Extra fail-closed installer regression cases (2026-10-26)
Test-DoxaPilot.py now also checks absent package (exit 21), interrupted/corrupt ZIP (exit 30 with no staging residue), pre-existing unrelated installation directory (install exit 32 and uninstall exit 33 without deleting the user file), and tampered installed source bytes (detection fails, uninstall exit 33 until original hash is restored). These use disposable fixture directories only, never the real system-managed Doxa application or Silicon Motion driver. This extends the Windows enterprise build acceptance gate automatically.

### Preview.7 actual Dell-only SYSTEM qualification
The review-pinned source is 08dceb23c65c84890042490fe8c098cfae9107e3; the private GitHub enterprise ZIP is 2aabe85af628f94b831f78df8f008dad2b80fd350174501f176d24590c988503 and passed 18 independent lifecycle cases on Dell. The separately prepared authentic Microsoft Win32 .intunewin SHA256 is 1339ae3baf3d954783e91cd15111edef278628464b7f7b91a55c97199dd83a2c. Publish-DoxaPreview7Intune.py requires the encrypted Microsoft admin token, tenant, exactly one Dell group member, original historical pilot assigned Uninstall, preview.6 assigned Uninstall and absent from Program Files. It uses a new, isolated preview7 system path; no SMI MSI, system driver action, Tailscale/RDP, UAC bypass or policy change. Read-only preflight is the default; --execute explicitly creates a Dell-only required Win32 pilot, to be followed by a separately verified uninstall. Do not claim that successful assignment itself proves installation.
The exact Intune preview7 app ID is c92d970f-3e6c-4cf8-bc1f-08ab9e1bedef. Historical preview6 app ec42c2b2-af21-43ff-8b68-e5c0f9c0583d remains separate and uninstalled. The permanent Switch-DoxaPreview7ToUninstall.py is scoped to that ID and the immutable Dell group. Do not use the original or preview6 scripts for this app. Required installation and independent detection passed on 26 October; uninstall assignment requested; actual removal must be separately verified via Windows/Intune.
