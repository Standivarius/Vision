# Doxa Windows installers — independent GPT-6-Sol subscription review and test verification

**Date:** 28 October 2026
**Review type:** independent, read-only static assessment and separate local non-destructive regression runs.
**Project:** Standivarius/Vision, isolated `doxa/review-package-20261028` worktree.
**Reviewed application-source commit:** `8efe76fa6b6565cc38957c2e4fcb467fc47bc65f` (the more recent commits contain review documentation).
**Exact model and route:** `gpt-6-sol` through Codex CLI v0.155.0 via **ChatGPT subscription**, **not API-key billing**. Reasoning effort `high`. Codex did not expose `gpt-6.1-sol` and rejected that literal ID; the user-approved review used the available GPT-6-Sol.
**Model work duration:** 131 seconds, ~83,975 tokens as reported by Codex; snapshot of 19 current source/evidence files, 223,352 input characters. The model's own review was static/read-only; it did not execute the tests.

## Independence and audit evidence

A fresh ephemeral Codex session received a neutral installer brief, current source code with file/line references and previous local release evidence, **without Gemini or Muse review reports or their findings**. The raw model report is preserved verbatim at `docs/project/hardware/2026-10-28__doxa_sol_subscription_independent_review_raw.md`. Exact source snapshots, SHA-256 input packet inventory, native model logs and separate test records are stored outside the repository at `C:\mcp\vision-dev\state\reviews\doxa-sol-independent-20261028`.

The source is one customer WinForms EXE `Personal\DoxaSetup.exe` and one common native silent executable embedded separately into `Intune\DoxaDeploy.intunewin` and `ManageEngine\Doxa-Managed-Windows.zip`, built from the same vendor-signed MSI and guided application.

## Grounded triage — Sol findings

| Finding | Our assessment | Corrective action / verification |
| --- | --- | --- |
| Windows repair `ModifyPath` includes literal backslashes before quotes | **Confirmed functional defect** | `DoxaSetupHost.cs:308` contains literal backslash-quote sequences in the registered Windows command; `UninstallString` nearby uses valid plain escaped quotes. Align `ModifyPath` with `UninstallString` and add an explicit registry-value Windows repair fixture. |
| Signed-package finalizer writes a manifest incompatible with release-consistency checker | **Confirmed release-process defect** | `Finalize-DoxaSignedRelease.ps1:66–69` writes files under `relative` and omits `source_commit`, native source/builder hashes. `Test-DoxaReleaseConsistency.py:20–33` expects `path` and those metadata fields. Preserve source provenance and identical schema when signing. Validate the *signed* package, not only the unsigned build. |
| Native customer window automatically probes WMI/device state before the guided application's consent | **Confirmed code-path and consent-design mismatch** | `DoxaSetupHost.cs:515–527` calls `State()` on `form.Shown` before the separate guided welcome. The guided welcome says local checks require prior consent. Move native local check behind explicit consent or reconcile the UI policy; test launch with declined permission. |
| Corporate disconnected install executes vendor MSI while device absent | **Confirmed code path; risk not a newly introduced accidental bug** | `Apply():325–330` calls `InstallDriver` with `plugged=false`, and `InstallDriver():267–281` still invokes the original signed MSI. This was deliberately added after the previous review to allow SYSTEM provisioning ahead of connection; vendor MSI disconnected behavior remains **physically unqualified**, so do not label staging success hardware verified. Qualify on recoverable driver-free hardware before replacing behavior or declaring release. Note stale contradicting comment at `Apply():322–324`. |
| `/verify` does not check all three independent external monitors | **Real scope limitation; avoid claiming screen verification** | `DoxaSetupHost.cs:448` returns 0 for valid app + USB controller + signed driver only. README correctly calls it *machine driver verification*. Keep software-only `/detect`; provide a separate all-three-panel evidence route, plus attended 4-display Extend-mode check. |
| Windows build preflight can vary and is bypassed for already healthy driver | **Confirmed inconsistent flow, OS reporting risk unqualified** | `InstallDriver():263–266` returns early if driver healthy before OS build/architecture validation; `Environment.OSVersion` may differ from `Win32_OperatingSystem.BuildNumber` in guided app. Establish one tested compatibility gate. |
| MSI has no bounded timeout; connected binding wait is only 15 seconds | **Confirmed code path with unmeasured risk** | `InstallDriver():273–289` uses unbounded `WaitForExit()`. Add documented bounded MSI behavior, safe diagnostic logging, delayed PnP recheck/retry policy and 3010 state tests. |
| Customer install waits synchronously on UI thread | **Confirmed responsiveness/accessibility defect** | `UI` install click: `p.WaitForExit()` `DoxaSetupHost.cs:500–512`. Migrate long work off the UI thread with explicit result status while retaining Windows UAC and safety. |
| Romanian UI and accessibility descriptions not completely localized | **Confirmed usability gap** | `Doxa-BrandTabs.ps1` exposes an English `Install / check driver` button and accessible description; not every string is in `$brandTranslations`. Add exact EN/RO regression assertions and screen-reader acceptance. |
| Commercial signing, driver-free physical install, exact-binary Intune/ManageEngine, WDAC/AppLocker | **Known external acceptance gates** | Current review binaries unsigned. Previous versions' live Intune results cannot establish new binary's managed lifecycle. Do not manipulate Dell's working signed driver for first-install qualification. |

## Independent read-only tests

Locally reran without installing a driver, restarting the computer, changing Windows monitor topology, writing endpoint assignments or touching the dirty main checkout. The test source is the **current** remediated worktree and review binary, not a previous Muse/Gemini artifact.

- T01: `Test-DoxaUILayout.ps1` — PASS (10 layout cases, EN/RO).
- T02: `Test-DoxaSetupExperience.ps1` — PASS (read-only UI/diagnostics/fault fixtures).
- T03: `Test-DoxaNativeRelease.ps1` against the remediated retail release — PASS (native embedded tests, invalid commands, sidecar isolation, driver unchanged).
- T04: `Test-DoxaReleaseConsistency.py` — PASS (cryptographic Intune container verification, identical ManageEngine executable, source-manifest provenance).
- T05: `Test-DoxaPersonalBundle.ps1` — extracted the **inner** `DoxaSetupPayload.zip` from the built complete Windows package for the independent validation. **PASS**. The evidence is recorded in `T05-Extracted-Customer-Bundle.json` and `LOCAL-SAFE-TEST-SUMMARY.json` in the external review directory. The first attempt pointed the test at the *outer* complete package rather than the inner bundle and failed with missing `manifest.json`; this was a test-input error, not an installer-code defect.

## Decision and boundaries

**Do not publish or merge the installer release yet.** Sol raised several material concerns beyond signing. The confirmed repair-string and signed-manifest issues can be fixed immediately without touching hardware. Native consent flow and responsiveness also merit immediate remediation. The disconnected MSI qualification, driver-free physical first-install, three-panel hardware verification and live Intune/ManageEngine checks require separate evidence.

No code changes or hardware installation are authorized or performed by this **review-and-test** turn. Keep the existing PR draft and preserve all untracked/dirty main checkout files.
