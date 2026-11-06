# Doxa installer — Sonnet remediation final validation

**Date:** 2026-10-28. **Host:** MARIUS-DELL. **Branch:** `doxa/review-package-20261028`. **Validated implementation commit:** `1eea35d70fdcf7d426a9204b66ef2ab17f0389a1`, after safety fixes `b16f5c1` and embedded-panel paint/session fix `1eea35d`.

## Result — PASS for UNSIGNED ENGINEERING BUILD ONLY

The released unsigned review binaries and installed software behavior are distinct. Source and package tests passed without invoking the vendor MSI, touching display topology, or deploying endpoints. No publisher-signed commercial release was produced or authorized.

### Final package paths (on Dell)

**Standalone retail-style executable, unsigned review copy:**

`C:\wt\doxa-review-package-20261028\artifacts\releases\sonnet-remediated-retail-final-20261028\Personal\DoxaSetup.exe`

SHA-256: `D2A149892C8C4994E56204A9BCE7505ADBC34A0D36BFFC2D8977A387FE194ADE`

**ManageEngine native executable, unsigned review copy:**

`C:\wt\doxa-review-package-20261028\artifacts\releases\sonnet-remediated-retail-final-20261028\ManageEngine\DoxaDeploy.exe`

SHA-256: `A9F703E34A9A9FF8D0A1ABFA07FAB4A720DF3C1F7001C0E749DEBF9393F9D7BC`

**Managed archive:** `ManageEngine\Doxa-Managed-Windows.zip` within the same release.

**Intune Win32 archive:** `Intune\DoxaDeploy.intunewin` within the same release.

**Complete customer/enterprise test bundle:**

`C:\wt\doxa-review-package-20261028\artifacts\releases\sonnet-remediated-complete-v3-20261028`

The complete build returned `REVIEW_BUILD_PASS` with source commit `1eea35d`; the retail build returned `UNSIGNED_REVIEW_BUILD_PASS` from the identical source and embedded payload.

### Tests completed

| Gate | Result / limitation |
|---|---|
| PS source syntax (12 modified scripts) and Windows .NET native host C# compilation | PASS |
| Fault Lab C# compilation, primary protection, overlapping-trial marker guard, and snapshot serialization | PASS (read-only; no actual disable) |
| Six driver classification fixtures and mixed untrusted-device rejection | PASS |
| Organizational online AI denial, locally un-enrolled gating, persistent identifier notice | PASS (no live AI requests) |
| Customer seamless transition, English and Romanian | PASS; one WinForms handle, read-only Detect Doxa, no online calls or driver changes |
| Ten-case responsive-width, keyboard and layout fixture suite | PASS |
| Native embedded install selftests, software detection, app retention/reinstall fixture, unknown-command refusal | PASS |
| Complete packaged personal-application extraction and manifest hashes | PASS |
| Standalone native-release test | PASS |
| Intune MAC/digest and byte-for-byte embedded managed EXE equality | PASS |
| Source-only signed release manifest contract | PASS (NOT a signed build) |
| Windows driver status before/after native tests | Unchanged; signed Silicon Motion 4.7.6.8001 remains |
| Physical connected left/top/right screen tests | NOT RUN; at final test time Windows reported one active desktop |
| Vendor MSI apply, admin UAC, PnP binding and 3010 runtime | NOT RUN |
| Publisher Authenticode certificate and timestamp signing | NOT RUN / REQUIRED |
| Retail online AI provider, device enrollment to live server | NOT RUN / preview service is not retail-ready |
| Intune and ManageEngine live-agent testing | NOT RUN |
| Real Fault Lab monitor-disable and independent auto-restore | NOT RUN |

Read-only `DoxaDeploy.exe /detect` and `/verify` correctly returned code 1: `AppMissing DriverValid USBDetected`, because the updated application is not installed on Dell. No driver was installed or uninstalled.

### Important integration defect discovered and fixed during packaging

Initial complete bundle validation revealed a **false overlap failure** in branded UI narrow/stacked mode. The test now checks actual vertical overlap before enforcing side-by-side boundaries. Subsequent bundle validation uncovered a **real WinForms painting error** in same-form embedded mode: `$script:lang` and `$script:doxaScreenChecks` were unavailable inside a later paint callback. The language helper now tolerates absent script scope, and the screen paint handler receives its live per-panel tick array on its control's `Tag`, so it no longer reads a destroyed PowerShell module variable. Both English and Romanian seamless tests, and all ten layout cases, passed afterward. The complete and retail builds were regenerated from that fixed commit.

Earlier failed build directories were left intact as engineering evidence, not reused or overwritten. The final validated outputs are the `complete-v3` and `retail-final` directories above.

### Release gate decisions remain

- **Retail:** HOLD. Publisher-sign both EXEs, sign/qualify included script execution under WDAC/AppLocker, obtain supplier/OEM permission to redistribute the embedded Silicon Motion MSI, complete approved privacy disclosures and retail online AI provisioning (or omit online AI), and perform a clean driver-free attended Windows laptop installation.
- **Intune:** CONTROLLED PILOT ONLY after signed package; verify SYSTEM installation, software-only detection, USB disconnect/reconnect resilience, return codes, repair/uninstall on a qualified endpoint.
- **ManageEngine:** HOLD pending signed native package and real agent pilot with documented commands and acceptance.
- **Fault Lab:** do not run unattended. Concurrency and snapshot safety logic have source/fixture tests but no live watchdog qualification. Keep an independently usable laptop panel.

The main checkout `C:\dev\Vision` remained untouched. Source patches and scripts are committed only to the isolated Doxa worktree. See `2026-10-28__doxa_sonnet_findings_implementation.md` for the F1–F15 finding-by-finding implementation and residual gates.
