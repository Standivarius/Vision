# Doxa / Dell assisted installation and recovery pilot

Date: 2026-10-25. Host: MARIUS-DELL only, with Doxa connected. This is an **execution plan**, not authorisation to disrupt the Dell display driver or enrol endpoint management without a distinct go/no-go.

## Why the MSI is not bundled in the public preview
Silicon Motion publishes SM770 Windows EXE and MSI packages at https://www.siliconmotion.com/downloads/SM770-drivers.html . Its Windows MSI deployment manual explains organisational deployment through a network share. Public download and the right to run a legitimate installer **do not establish permission for Standivarius to redistribute the binary** inside our branded commercial installer. Request OEM redistribution terms and branding permission. Meanwhile we can run a Dell **local-use** test using an unchanged original vendor-signed MSI supplied/downloaded from its source.

Doxa's existing Test-DoxaPackageGate.ps1 pins SHA256 3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4 and signer cert thumbprint 81956F4C8904963B707B994E42FEA1EDBBFA51C6. A newer vendor MSI must not be silently accepted or downgraded to this baseline; review its signature, hash, version, installer product identity and hardware eligibility first.

## Preflight: non-negotiable
1. Dell development bridge returns project_start('visual'); record clean before/after Git branch/status, preserve all existing dirty work. Inspect RELEASE-CONTROL current state and relevant Windows display/driver inventory. Use real Dell console, not an RDP logical desktop.
2. Owner is at Dell keyboard. A **separate independent working laptop panel** has been physically confirmed, and Doxa can be disconnected without losing operator control. Keep recovery communication channel available even if USB displays fail.
3. Run recovery/Test-DoxaRecoveryPreflight.ps1 in read-only mode with and without proposed vendor MSI. Expected PASS requires local console, all three detected Doxa panels, four independent desktops, verified signed driver, exact approved MSI, and two owner physical assertions. The script NEVER removes anything.
4. Export existing matched device/driver/monitor list, Windows build and SetupAPI references. Back up the currently installed verified driver package locally (where permitted) and record restore location plus a restore route independent of the Doxa monitor. Do not export, collect or upload private credentials.
5. Explicit go/no-go from owner for **each** system-changing action. Never bypass UAC, Windows driver-signature checks, App Control, or Intune/enterprise management policy. No silent reboot. If restore MSI is missing or rejected, **do not uninstall**.

## Experiment schedule (real vs simulation distinguished)

| ID | Controlled intervention | Expected diagnostics and AI | Restore/exit condition |
|---|---|---|---|
| R0 | Baseline, no fault | Correct 3 Doxa PnP panels, 4 physical-console desktops; offline and online assistant label true status | Record OS truth and screenshot, no changes |
| R1 | With Dell attended, *only after* R0 recovery gates: controlled removal of SMI display software and its driver-store package, using the documented vendor/Windows method and exact package identity | Driver absent, Doxa hardware state correctly distinguished from Driver Store; AI explains and guides use of the verified original MSI, no privileged commands from model | Run unchanged signed MSI through Doxa Setup with independent admin approval, handle required restart only after separate owner confirmation, verify all panels |
| R2 | Disconnect **one** Windows external display via Windows Display Settings, if reversible; do not open Doxa or remove internal cables | Distinguish 3 PnP detected vs 1 display logically disabled; guide Extend / display settings, not reinstall | Re-enable same display, verify 4 desktops |
| R3 | Disconnect/reconnect Doxa power/data cable without manipulating internals | Explain no Doxa USB device vs cached installed driver. Do not suggest reinstall until reconnection checked | Reconnect, re-read PnP and displays |
| R4 | Reject a missing/incorrect/corrupted MSI **without installing** | Refuse unapproved hash/signature; no UAC, no driver removal | Confirm untouched driver and 3 panels |
| R5 | Cloud AI unavailable or opted out | Offline curated answer still works; no token leak, no silent online query | AI can be re-enabled only by fresh explicit consent |
| R6 | Online AI enabled with approved per-device identity, real Doxa defect/question | AI gives source-grounded, read-only recovery advice; never executes Windows changes; record latency/source/gaps | Verified real OS state and owner confirms recovery |

The existing developer fault overlays deliberately never call cloud AI; therefore they cannot substitute for R1-R3 real-device AI tests.

## Measurements and pass/fail
For each case save start/end time, OS/PnP truth, actual vs expected diagnosis, AI route (offline vs native Cloudflare AI), retrieved source IDs, guidance accuracy, unexpected writes, recovery time, and observed physical state after restore. Avoid storing USB serials, API secrets or account identifiers in cloud prompts. Stop immediately if laptop fallback, operator console, restore package, trust signature, or independent control is lost.

Full-system completion requires: one attended clean uninstall/reinstall, >=1 induced one-screen fault restored, a USB/power fault correctly differentiated from missing driver, all normal support modes working, an actual approved cloud AI answer when explicitly enabled, and no unapproved installs/settings changes.

## Independent product integrations
- **ManageEngine Endpoint Central EU:** Cloud console documented Windows MSI/EXE software packages, deployment and uninstall. Existing ASUS EU agent was removed after previous endpoint trial; Dell may still retain separate Intune enrolment. Confirm and approve any management changes; do not silently mix enrolment cleanup with driver removal. Cloud API access uses Zoho EU Self Client; use explicit credentials in GitHub Actions Secrets, not local source. Console-based one-device deployment can be qualified even when custom package upload is not exposed by API.
- **Microsoft Artifact Signing:** Sign the Standivarius Doxa application/installer, not Silicon Motion's already-signed driver. Paid Azure subscription, publisher verification, dedicated Entra/OIDC federated GitHub identity and public-trust certificate profile are account-side gates; Dell hardware doesn't bypass them.
- **Cloudflare native Workers AI:** Source-level approved-device signatures have passed tests but live ASUS enrolment is blocked by missing Workers Scripts Write scope. For Dell rehearsal preserve legacy Dell identity. No Dify credential is required.

## Advance preparation completed while Dell is offline
Read-only readiness script and fixture tests. No driver uninstall, MSI package copy or cloud AI deployment occurs until separate live gates are satisfied.
