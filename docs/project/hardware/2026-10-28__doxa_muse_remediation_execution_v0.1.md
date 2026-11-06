# Doxa Windows installer — Muse Contributor remediation and execution report

**Date:** 28 October 2026
**Repository:** Standivarius/Vision
**Branch:** `doxa/review-package-20261028` (isolated worktree `C:\wt\doxa-review-package-20261028`)
**Source commit:** `8efe76fa6b6565cc38957c2e4fcb467fc47bc65f`
**Engineering review:** independent Muse Spark 1.3 Contributor in Codex; see `2026-10-28__doxa_muse_contributor_codex_raw_review.md` and `2026-10-28__doxa_muse_contributor_codex_review_triage.md`.

## Completed corrective work

1. **One trusted Windows driver installation path.** Removed the retired browse-for-MSI handler and its associated independent PowerShell elevation path from the customer guided application. The visible `Install signed driver` tab uses the native `DoxaMaintenance-v2.exe /install`, which already embeds and verifies the original vendor-signed MSI. No user is asked to locate the driver package. The old button remains inaccessible so older read-only UI fixtures are not disrupted.
2. **Customer-facing language.** Removed visible `TEST preview.12` labels from the consent wizard, main setup window and task-tab interface. The internal immutable manifest still uses its preview version for file integrity.
3. **Readable machine status.** The native WinForms window now presents explanatory EN/RO text rather than raw `AppMissing DriverValid USBDetected` output. The machine commands `/detect` and `/verify` retain their exact automation semantics.
4. **Usable Doxa Help.** Increased the chat view height and adjusted controls in the branded layout and short-laptop fallback; the help pane remains present alongside the installation task tabs.
5. **Portable driver safety regression.** The native release test no longer assumes Dell's particular `oem102.inf` filename. It captures the signed vendor PnP driver identity and checks that the actual identity remains unchanged across read-only acceptance checks.
6. **Supply-chain traceability.** Retail builder now records and verifies the Git commit, SHA-256 of its native C# host, build script, embedded signed MSI and guided app bundle. The independent package verifier checks all declared release file hashes and lengths, validates source integrity, decrypts the Intune container and compares its executable to the ManageEngine executable.
7. **Better packaged regression guard.** The embedded application test rejects reintroduction of the external MSI picker or visible preview label, and confirms the branded customer tab still points to the protected native driver command.
8. **Updated embedded-component guidance.** The internal guided-app README describes its status as part of the native one-file Windows installer, not a separate customer-facing MSI selection flow.

## Executed test evidence

| Test or acceptance | Result |
| --- | --- |
| Guided UI layout (10 cases, English/Romanian, small viewports) | PASS |
| Read-only Doxa experience / diagnostics fixture suite | PASS |
| Direct English and Romanian customer-journey test | PASS |
| Rebuilt embedded application ZIP, extracted manifest/hash verification and actual one-window guided journeys | PASS — `muse-remediated-complete-v4-20261028` |
| Native Windows executable self-test, payload isolation and read-only safety | PASS |
| Portable signed-driver identity unchanged by tests | PASS |
| Final Intune AES package authentication, decrypt and hash validation | PASS |
| Intune and ManageEngine final native executable parity | PASS |
| Exact builder / C# source / embedded bundle hash and Git commit provenance | PASS |
| Customer and silent host publisher signing | NOT PRESENT (unsigned review binaries) |
| Physical driver-free first-time installation | NOT EXECUTED |
| Live Intune installation + removal of **this newly remediated build** | NOT EXECUTED |
| Live ManageEngine agent delivery of **this newly remediated build** | NOT EXECUTED |
| WDAC/AppLocker and ordinary consumer elevated installation acceptance | NOT EXECUTED |

**Final unsigned engineering build:**
`C:\wt\doxa-review-package-20261028\artifacts\releases\muse-remediated-retail-final-20261028`

Contains `Personal\DoxaSetup.exe`, `Intune\DoxaDeploy.intunewin`, `ManageEngine\Doxa-Managed-Windows.zip`, the release manifest and test evidence. All source and release bytes are connected through recorded SHA-256 hashes.

**Important:** Older Doxa candidates previously passed real Microsoft Intune on Dell. That evidence is not falsely attributed to this updated binary. No signed display driver, active display arrangement or unrelated application state was modified. No cleanup/reset of the extremely dirty canonical `C:\dev\Vision` main checkout occurred.

## Release decision

**Private reviewed installer candidate. Do not distribute publicly or mark GitHub PR ready to merge.** Obtain publisher signing, a recoverable first-use driver-free machine, live endpoint-agent acceptance, interactive retail/repair/uninstall tests, and restricted enterprise-policy validation. The source-level defects from the Muse review have been addressed and locally retested.

## Previous candidate Intune cleanup verified after this build

After the Muse-corrected package was frozen, the Windows Intune Management Extension completed removal of the **earlier Gemini High** Dell-only test installation. Read-only verification confirmed the previous application folder and uninstall registry entry were absent, with signed Silicon Motion driver version `4.7.6.8001` preserved. The Dell-only Intune uninstall assignment was then cleared successfully (`FULL_DOXA_TEST_ASSIGNMENT_CLEARED=true`). This is closure of the prior candidate's lifecycle, **not** a live Intune deployment test of the newly Muse-corrected binaries.
