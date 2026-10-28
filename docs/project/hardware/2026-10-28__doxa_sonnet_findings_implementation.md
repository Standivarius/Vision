# Doxa Windows installer — Sonnet findings implementation

Date: 2026-10-28. Source: independent Sonnet subscription review in `2026-10-28__doxa_sonnet55_claude_code_independent_review.md`. Changes implemented directly by ChatGPT in isolated `C:\wt\doxa-review-package-20261028`; main checkout unchanged. The report is the source for the original claims; the entries below record actual changes and remaining gates, **not an assertion that Doxa is commercially releasable**.

## Changed customer journey

1. Open DoxaSetup.exe and explicitly permit local read-only checks. The native host does not auto-enumerate monitors upon checking the box. The primary action **Set up Doxa** elevates and calls `/prepare` to install/validate the application only; this mode cannot invoke the vendor MSI.
2. In the same guided UI, the earlier local consent is shown as already approved. Optional remote AI still requires a separate decision and an enrolled local identity. Unenrolled/IT-blocked devices stay on usable offline help.
3. Connect power **first**, then USB data. Use **Detect Doxa** for one coherent hardware scan, now performed in a background PowerShell job in the real UI. The status panel gets the diagnostic results, while user-generated troubleshooting stays in Doxa Help.
4. Individual L/T/R PnP identities drive green ticks; they do not prove that four Windows desktops are in Extend mode. Open Windows Display Settings only in **Set up screens**.
5. Only when Doxa USB is present and the signed driver is missing can the user initiate `/install` with Windows administrator approval. Healthy signed drivers remain no-ops. MSI 3010 is explicitly reported as a restart request; there is never an automatic reboot. Driver-binding and three-screen readiness remain distinct read-only checks.
6. The enterprise `/install` and `/repair` paths retain software-only detection and hardware-only verification. Without present Doxa USB, the native host installs the application but **defers** the vendor MSI. No unqualified disconnected custom actions run. A later attended /repair or /install with connected Doxa can attempt the signed MSI.

## Findings tracked

| Finding | Implementation | Remaining limit |
|---|---|---|
| **F1** Unqualified pre-connection MSI | **Implemented** `/prepare` software-only consumer launch; driver gating via `MayRunVendorMsi()`; disconnected enterprise install deferred. Native `/selftest` now has a 5-case no-MSI decision table. | No live driver-free installation; physical vendor custom-action behavior still unqualified. |
| **F2** MSI redistribution | **Commercial HOLD** explicitly documented in builder and runbooks. | Obtain written Silicon Motion OEM redistribution permission; no code can grant it. |
| **F3** Install result | **Improved** explicit 3010/restart messaging; installer completion prompts re-detection, not blanket hardware-ready success. | Live MSI result propagation and PnP pending on clean Windows remain an acceptance test. |
| **F4** Duplicate consent and scans | **Improved** native host grants same-session local read-only consent to wizard; the guided stage retains optional AI choice. No automatic native scan after consent; language change no longer scans. | Native manual Refresh still available; hardware detection upon main view is deliberate. |
| **F5** Driver provider mismatch | **Implemented** normalized Silicon Motion provider matching in PowerShell (aligned to native C#), generic Microsoft/unbound classified missing, foreign/unsigned denied, prioritizing untrusted in multi-device state. New fixture regressions. | Test actual first-time unbound Windows hardware on a clean machine. |
| **F6** UI responsiveness, DPI and chat history | **Improved** production scans now use `Start-Job` and a WinForms timer, not blocking UI WMI on the event thread; language changes preserve chat. Native UI already uses WinForms DPI autoscaling. | Full per-monitor DPI and screen-reader / WDAC qualification still required. |
| **F7** Online AI un-enrolled customers | **Implemented** policy now reports local identity separately from machine policy; wizard/main online control unavailable when no local RSA identity exists. Never claims server approval. Offline help stays available. | Provisioning and server approval remain operator-managed; no public enrollment workflow. |
| **F8** Privacy and dev endpoint | **Improved** disclosed persistent pseudonymous `x-doxa-client-id`, signature/timestamp, correlation and developer-owned endpoint in English and Romanian notices. | Approved final GDPR notice, branded endpoint and legal disclosures before public online AI. |
| **F9** Overlapping Fault Lab trials | **Implemented** interprocess trial mutex and persistent .armed/.done check; refuses a second pending/failing run. GUI locks the trial button pending watchdog restore. Non-Doxa external targets refused. | Attended physical overlap test not performed; currently no external Doxa screens visible on Dell. |
| **F10** Fault Lab restore outcome | **Improved** GUI shows watchdog .done result and blocks again on failed restore; watchdog skips a second restore after manual successful restore; snapshots are compared structurally after roundtrip. | Physical live auto-restore and unplug/re-enumeration behavior remain unproven. |
| **F11** Hard-coded fixture PASS | **Implemented** bundle results say not physically tested or fixture-only; Fault Lab read-only check reports no external screen as unavailable instead of claiming 3 passed. | Fixture PASS is not physical driver or monitor acceptance. |
| **F12** Monitor identities and ghost monitors | **Improved** C# checks only present PnP monitor instances (CM_Locate_DevNode); fault trials restricted to observed Doxa L/T/R identities. | Additional physical hardware revision/second Doxa unit to validate IDs and mapping. |
| **F13** WDAC/signed scripts | **Release HOLD in WDAC environments**; no unsigned-script workaround or bypass implemented. | Sign scripts with proper trust chain or compile PowerShell UI in next release; test WDAC/GPO. |
| **F14** Enterprise and upgrade | **Improved** dedicated native ManageEngine command/detection/uninstall pilot runbook; disconnected install and software detection explicitly distinguished. Intune and ManageEngine separate gates. | Live agent and upgrade/uninstall; do not silently delete retained or modified user files. OS targeting may deliberately be narrower than native minimum. |
| **F15** Signing trust | **Implemented source gates** requiring explicit publisher thumbprint, timestamped valid Authenticode, rechecking unsigned baseline hashes and PE-neutral code equality before repackaging. The unsigned review builder now explains that production signing belongs to finalization. | Actual publisher-signed release not produced; certificate and timestamp must be provided. |

## Evidence and safety

Safe tests (source compile, PS syntax, provider fixtures, policy, bilingual UI, fault simulations and source-only snapshot tests) run without modifying drivers, Windows displays or managed agents. The installed signed Silicon Motion driver is not uninstalled, downgraded or replaced. **Actual full retail, Intune and ManageEngine release statuses remain HOLD/CONTROLLED PILOT/HOLD until their distinct live and legal gates pass.**

For enterprise native commands, see `app/packaging/doxa-setup/full-release/MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md`.

The proprietary signed vendor MSI remains hashed and checked; a valid MSI signature does **not** itself grant redistribution permission. Online AI is not permitted to mutate Windows or execute a shell. Fault Lab is developer-only and is excluded from the customer payload.
