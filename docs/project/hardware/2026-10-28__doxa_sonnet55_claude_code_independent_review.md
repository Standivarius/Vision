# Claude Sonnet 5.5 independent Doxa installer readiness review

- Reviewed source branch: doxa/review-package-20261028
- Source HEAD: e85ef2bb47b41ce3373f569d1bae5aedd0c687de
- Reviewer: Claude Code subscription, resolved model claude-sonnet-5-5 (CLI --model sonnet), read-only Read/Glob/Grep
- Review type: Static code analysis only; no driver or display changes, no live release qualification

---

# Independent Review: Standivarius Doxa Windows Installer (Sonnet, Claude Code subscription)

**Scope and method.** This is a read-only static review of `C:\wt\doxa-review-package-20261028`, `app/packaging/doxa-setup`, at HEAD `e85ef2b`. I used only Read, Glob and Grep. I did not run anything, open any prior reviewer report, or touch any Vision magnifier source. Line numbers refer to the files as committed.

**Evidence labels.**
- **SC** is a source-confirmed defect.
- **PR** is a probable risk that needs live confirmation.
- **GATE** is a release gate that is currently unproven.
- **LOW** is cosmetic or low-risk.

---

## A. Executive decision

| Channel | Decision | Exact reason |
|---|---|---|
| **Retail (single EXE)** | **HOLD** | Four things block it. (1) Clicking *Install / check Doxa* runs the vendor MSI immediately, even with Doxa unplugged. The repo's own gates say that is unqualified (F1). (2) The outcome is not shown to the customer, including restart-required (F3). (3) Redistribution rights for the vendor MSI are unproven, and the product embeds it (F2). (4) The privacy and consent layer is self-labelled "development", and the Online AI cannot work for any customer (F7, F8). The EXE is also unsigned and has had no clean driver-free Windows test. |
| **Intune** | **CONTROLLED PILOT** | Detection is software-only and USB-hotplug-stable (`DoxaSetupHost.cs:146-153`). Install, uninstall and exit codes (0 / 3010 / 30) are sensible. Install runs as SYSTEM with no UAC and no automatic restart, and the `.intunewin` is byte-parity verified. Pilot only a one-device group, using a signed EXE on a machine where Doxa is already connected and the driver is healthy. That path is a driver no-op. Driver-less and disconnected provisioning is a separate gate. No live agent run has happened. |
| **ManageEngine** | **HOLD** | The native-EXE procedure exists only as `README-FIRST.txt` text emitted by the builders. The only repo runbook and verifier (`enterprise-intune-pilot/MANAGEENGINE-REAL-PILOT-RUNBOOK.md`) target the legacy `DoxaPilot.ps1`; none of the `.md` files there mention `DoxaDeploy`. There is no authored ManageEngine detection or uninstall definition for `DoxaDeploy.exe`, and no agent run. |

---

## B. Components and the end-to-end journey as coded

### Component inventory

| Layer | Files | Role |
|---|---|---|
| Native host | `full-release/DoxaSetupHost.cs` | One source file, compiled twice. `DoxaSetup.exe` is `winexe` and `DoxaDeploy.exe` is a console `exe`. The vendor MSI and a payload ZIP are embedded as resources. |
| Builders | `Build-DoxaPersonalBundle.ps1`, then `Build-DoxaCompleteRelease.ps1`, then `Build-DoxaRetailRelease.ps1`, then `Finalize-DoxaSignedRelease.ps1` | The payload ZIP has 21 files plus 3 generated files, 24 in total. |
| Guided UI (PowerShell/WinForms) | `Start-DoxaGuidedSetup.ps1`, then `Start-DoxaSetup.ps1`, then `Doxa-BrandTabs.ps1` | Consent wizard, then main window, then three tabs plus the Help panel. |
| Diagnostics | `Get-DoxaDriverState.ps1`, `Get-DoxaSetupExperience.ps1`, `Get-DoxaCompatibility.ps1`, `profiles/smi770-observed.json` | Read-only. |
| Online AI | `Ask-DoxaInstaller.ps1`, `Get-DoxaDeviceSignature.ps1`, `Get-DoxaCloudAIPolicy.ps1`, `assistant/worker.mjs`, `scope.mjs`, `curated-kb.mjs`, `knowledge/*` | Cloudflare Worker with Workers AI. |
| Safe-test tools | `fault-lab/*` (not shipped), `recovery/*` (not shipped), `Doxa-RecoveryLab.ps1` (shipped, simulation only) | |
| Dead or legacy | `Invoke-DoxaPersonalInstallation.ps1` and `Test-DoxaPackageGate.ps1` (shipped inside the payload, never called by the host or UI), `enterprise-intune-pilot/*` preview.6/7 scripts, and four generations of `Publish-DoxaFullIntune*.py` | |

### Actual customer journey (personal EXE)

1. **Double-click `DoxaSetup.exe`.** The native WinForms window shows a local-checks consent checkbox. *Install* and *Refresh* are disabled until it is ticked (`DoxaSetupHost.cs:549-550`). Ticking it triggers an immediate hardware scan (`:602`).
2. **Click *Install / check Doxa*.** The host re-launches itself with `runas` (UAC) as `/install` (`:559-566`). `Apply()` (`:354-369`) then does these steps in order:
   - It verifies the SHA-256 of the embedded MSI.
   - If the driver state is not "untrusted", it runs `msiexec /i ΓÇª /qn /norestart` **whether or not Doxa is plugged in** (`:288-323`).
   - It installs the app to `Program Files\Standivarius\DoxaSetup`.
   - It copies itself to `DoxaMaintenance-v2.exe` and writes the uninstall registration and a Start-menu shortcut.
3. **The host ignores the details of the result.** It treats exit code 0 or 3010 as success and calls `Open()` (`:565-575`). `Open()` starts `powershell.exe -ExecutionPolicy Bypass -File Start-DoxaGuidedSetup.ps1` with no window.
4. **Guided wizard, page 1: consent again.** This is a second local-check consent, plus an optional cloud-AI checkbox (`Start-DoxaGuidedSetup.ps1:168-178`).
5. **Wizard, page 2.** The user picks "connected" or "continue without Doxa". The choice only feeds the text of the compatibility summary.
6. **Main window, same HWND** (`:189-213`). `RefreshState` runs a synchronous hardware scan (`Start-DoxaSetup.ps1:285-352`). It posts "advice" and a "Pre-check" summary into the Help chat. The Detect tab shows the power (upper) and data (lower) USB-C illustration and three per-panel ticks driven by PnP names (`Doxa-BrandTabs.ps1:357-369`).
7. **Tabs.**
   - *Set up screens* is static text plus an `ms-settings:display` button.
   - *Install signed driver* shows a button only if the signed driver is not detected. That button re-runs `DoxaMaintenance-v2.exe /install` with `RunAs` (`:203-220`).
8. **Online AI** (radio button, per-session confirm). Each question runs `Ask-DoxaInstaller.ps1` as a background job.

### Surprising sequence and dead ends

- **Driver install happens at step 2, before the guided UI says "Signed driver: only if needed".** By the time the user reaches the Install tab, the host has already tried it. The tab is only useful if the MSI failed or Doxa was connected later.
- **Local consent is requested twice** (host window, then wizard page 1).
- **Power-first, data-second is never enforced.** It appears only as UI text (`BrandTabs:74-77`).
- **Switching language clears the chat and re-runs the whole scan.** `ApplyMainLanguage` calls `$chat.Clear()` and `RefreshState` (`Start-DoxaSetup.ps1:545-546`).
- **Unplugged Doxa after a successful install produces no clear next step in the host window.** The host UI keeps saying "Connect power firstΓÇª" while the guided UI opens.

---

## C. Findings

| # | Pri | Class | Location / call path | Evidence ΓåÆ impact | Minimum remedy | Targeted test |
|---|---|---|---|---|---|---|
| **F1** | **P0** | SC (contradiction) + GATE (physical effect unknown) | `DoxaSetupHost.cs:354-369`, `:288-323`, `:554-569` | `Apply()` runs the vendor MSI as soon as state Γëá untrusted, with no check that Doxa is present. The repo's own artifacts say the opposite. `Get-DoxaCompatibility.ps1:44,55` says the pre-connection MSI path "has not yet been qualified; do not apply it automatically" (`automatic_driver_installation_permitted=$false`). `Invoke-DoxaPersonalInstallation.ps1:21-26` refuses `preconnection_install_unqualified`. `vendor-msi-reviewed.NOT_APPROVED.json:19,21` has `allow_prestage_without_device:false` and notes MSI custom actions that call devcon and add/remove `USB VID_090C&PID_770A`. A retail customer who clicks Install with Doxa unplugged runs unqualified display-driver custom actions. | For the personal EXE, require `PresentUsb()` before `InstallDriver`, and otherwise return "connect Doxa first" without running the MSI. Keep disconnected provisioning only behind an explicit enterprise flag (for example `/install /prestage`) until it is physically qualified. | Clean VM or spare PC, Doxa unplugged: confirm no `msiexec` starts and the UI instructs "connect power, then USB data". Separate gate: a disconnected SYSTEM prestage run. |
| **F2** | **P0 gate** | GATE | `Build-DoxaRetailRelease.ps1:45` (embeds MSI via `/resource`); `knowledge/entries.json` `smi-oem-licensing`; `NOT_APPROVED.json:24` | The product's own KB says the vendor manual "does not grant a redistribution licence" and advises pointing to the vendor download for early testing. The approval file lists "Supplier/OEM distribution and redistribution rights" as outstanding. The retail EXE nonetheless embeds the MSI. Not a code defect, but a hard commercial block. | Obtain written Silicon Motion OEM or redistribution permission and record it. Until then, ship only non-public builds. | None (document gate). |
| **F3** | **P1** | SC | `DoxaSetupHost.cs:565`, `:570-576`; elevated child stdout lost (`UseShellExecute=true`) | Exit code 0 or 3010 is success. The UI never shows `RestartRequired`, `DriverBindingPending` (60 s PnP wait expires, still exit 0, `:315-322`), or `DriverMSIPreparedForFirstConnection`. Customers are never told to restart or that the driver has not bound. The "no unexpected restart" goal is met, but the *expected* restart is silent. | Have the elevated child write a result file (or use distinct exit codes) and show one localized sentence per outcome. | Fixture with a stub MSI returning 3010: UI must say "restart when convenient". |
| **F4** | **P1** | SC | Repetition: `DoxaSetupHost.cs:531-549` plus `Start-DoxaGuidedSetup.ps1:168-178`, with `Open()` at `:420-434` | The host-level and wizard-level consents are separate. Detection also runs repeatedly: host `checkState`, then main `RefreshState`, then again on every language switch. The Install tab is redundant after the host install. This conflicts with a "logical, non-repeating" flow. | Pass a `-DiagnosticsApproved` token from host to wizard and skip page 1. Run the driver action only from the guided Connect stage, after the physical-connection step. | Journey test: one consent, one scan. |
| **F5** | **P1** | PR (needs driver-free test) | `Get-DoxaSetupExperience.ps1:73-82` and `Get-DoxaDriverState.ps1:41-64` versus `DoxaSetupHost.cs:70-81` | The host treats empty or "Microsoft" providers as installable (0). The PowerShell path requires provider **exactly** `SiliconMotion`, so a generic or unbound device becomes `driver_identity_or_signature_mismatch`, then `driver_untrusted`, then "request IT approval". If the unbound device has no row, it becomes `doxa_not_detected` ("do not reinstall a driverΓÇª"). The exact first-time customer state (Doxa plugged in, no driver) may therefore be messaged as "not detected / ask IT". There are also three provider matchers: host (normalized `StartsWith`), PowerShell (`-eq`), and `Test-DoxaNativeRelease.ps1:21` (regex). A Windows Update driver reporting "Silicon Motion, Inc." would fail the PowerShell classifier but pass the host. | One shared classification table (host and PowerShell), with fixture states for unbound, generic Microsoft, Silicon Motion and foreign drivers. | Fixtures for each state against both classifiers. Live: a driver-free PC with Doxa connected. |
| **F6** | **P1** | SC | `Start-DoxaSetup.ps1:285-352` (synchronous `& $diagnose` after a single `DoEvents`); `:545-546`; no DPI declaration in any `.cs`/`.ps1`/manifest (grep: none) | The scan (`Win32_PnPSignedDriver`, `pnputil /enum-drivers`, a PnP census) runs on the UI thread, so the window shows "Not responding". Every language switch repeats it and wipes the chat. The EXE and PowerShell windows declare no DPI awareness, so they are bitmap-scaled on high-DPI displays. That hurts low-vision users, the product's audience. | Run the scan in a runspace or background job and marshal the result. Add `SetProcessDpiAwareness` or an app manifest. Do not clear chat on language change. | UI-thread blocking test (timer-tick latency while the scan runs). A 200% DPI screenshot. |
| **F7** | **P1** | SC | Enrollment is only in `Get-DoxaDeviceSignature.ps1 -PrepareEnrollment`, called only by tests and docs; shipped UI never calls it. `:51-53` throws "not enrolled". `worker.mjs:50-61` allows Γëñ64 operator-pasted keys. `Start-DoxaSetup.ps1:333,342` post status text into the chat. `Get-DoxaKnowledgeAnswer.ps1` is a keyword matcher over 14 entries. | Beyond the Dell, no customer can use Online AI. The toggle exists and failure falls back silently to the keyword FAQ. The Help panel is a keyword FAQ with detection messages interleaved, not the "genuine chatbot" the brief requires (it is a genuine chat UI only with an enrolled AI). Two further wrinkles: `worker.mjs:66-68` has a legacy "Dell" key path, and `Ask-DoxaInstaller.ps1:28` re-runs a full diagnostic scan on every question. | Decide the retail model. Either make the retail Help panel honest ("offline help") and hide Online AI until there is a server-side enrollment flow, or build self-enrollment with token-based approval. Separate status messages from the conversation. | Unenrolled profile: the UI must not show Online AI as available. |
| **F8** | **P1** | SC + GATE | `AI-PRIVACY-NOTICE.txt:10,21`; `Ask-DoxaInstaller.ps1:45,52-58`; `worker.mjs:107` | Every request carries a stable `x-doxa-client-id` (hash of the public key, `Get-DoxaDeviceSignature.ps1:24-29`) plus a signature. The notice enumerates the diagnostic fields but never mentions this persistent pseudonymous identifier. The server-side consent check is a constant string (`development-v0.1`, `worker.mjs:107`) supplied by the client, so it proves nothing. The endpoint is a personal `*.marius-moldovan.workers.dev` subdomain (`Ask-DoxaInstaller.ps1:4,12`). The notice itself says GDPR basis, controller, retention and processors are not yet published. | Disclose the identifier in the notice. Move to a branded domain. Version the notice with real retention and controller text. Log consent per notice version locally. | Notice text is complete versus the payload fields (test comparing `$body` keys to the notice). |
| **F9** | **P1** (lab) | SC | `DoxaDisplayPath.cs:119`, `:184`, `:160-179`; `Invoke-DoxaFaultLab.ps1:135-148` (GUI Run button is never disabled) | No run lock. A second trial snapshots the *already-reduced* topology. With laptop plus 3 Doxa (4 paths), the second trial is allowed because 3 paths remain. Watchdog 1 restores all 4 at T1. Watchdog 2 later restores its 3-path snapshot, which excludes display A. Display A is then left disabled with no timer running. The primary and laptop displays remain safe. | Refuse a trial if any run folder has `.armed` without `.done`. Use a named mutex. Disable the Run button while armed. | Two overlapping trials (attended only): the final state must equal the original. |
| **F10** | **P1** (lab) | GATE + PR | `DoxaDisplayPath.cs:149-159`, `:198-207`, `:164-176`; `Invoke-DoxaFaultLab.ps1:146-147` | Restore is unproven (confirmed by `2026-10-28__readonly_validation.json`: `automatic_rollback_physically_verified:false`). Specific uncertainties: (a) `SetDisplayConfig` is called with `SDC_APPLY\|SDC_USE_SUPPLIED_DISPLAY_CONFIG` and neither `SDC_ALLOW_CHANGES` nor `SDC_SAVE_TO_DATABASE`, which may reject a restore if the OS must adjust modes (hypothesis); (b) adapter LUIDs for a USB display can change on re-enumeration; (c) the watchdog is a plain child process, with no job-breakaway or detach, so a job-kill wrapper can terminate it; (d) the `.done` result is never read back or shown, and the GUI only says "restore armed". Primary safety itself is well implemented (see D). | Surface `.done` (a small polling message). Try `SDC_ALLOW_CHANGES` on the fallback path in the attended run. Document that an unplugged Doxa cannot be restored. | One attended acceptance session: trial ΓåÆ watchdog kill ΓåÆ manual `--restore`; confirm the exact topology returns. |
| **F11** | **P1** | SC (overclaiming tests) | `Test-DoxaPersonalBundle.ps1:130`; `Invoke-DoxaFaultLab.ps1:167-187`; `Test-DoxaFaultLab.ps1:11-14`; `DoxaDisplayPath.cs:236-238` | `driver_install_prevented_safely`, `bilingual_ui_verified` and `multidevice_identity_tested` are hard-coded `$true` in the result object. The Fault Lab SelfTest counts `UNSUPPORTED_SAFE_BLOCK` as non-failing, so it can report PASS with zero validated externals. The "independent rollback path" check is a regex over the C# text. The snapshot roundtrip compares only array lengths and primary name, not path/mode contents. The host `/selftest` runs only temp-folder fixtures (`:435-485`) and its PASS string says so. | Compute the flags. Fail when `external_dry_run` has no PASS. Compare snapshot contents (hash). | Mutation test: break the watchdog and see the test fail. |
| **F12** | **P2** | PR | `smi770-observed.json:11-15`; `DoxaSetupHost.cs:278`; `Doxa-BrandTabs.ps1:360`; `Get-DoxaDriverState.ps1:33-35` | Panel identity is three hard-coded names (`Generic Monitor (L)/(T)/(R)`) observed on one Dell unit. They are generic, not Doxa-unique. The host queries `Win32_PnPEntity`; the PowerShell uses `Get-PnpDevice -PresentOnly`, which could disagree on ghost devices. The UI ticks Screen 2/3/4 per name but explicitly does not map them to desktops. That is honest, but "mark each separately" depends on this name list holding for every unit and revision. | Bind to the Doxa adapter's monitor instance path (parent device) where possible. Align the two queries. | Second physical unit. A PnP ghost monitor fixture. |
| **F13** | **P2** | PR | `DoxaSetupHost.cs:420-434`; no script signing anywhere in the pipeline (grep: none in the build scripts) | The guided UI is unsigned PowerShell using `Add-Type`, `New-Object` and reflection. On WDAC or AppLocker with Constrained Language Mode, it fails to start. The host waits only 3 s for early exit, so a later failure is silent. The native install, detect and uninstall paths work, but the customer UI does not. | Sign the scripts in the finalize step (or ship the UI as compiled code), and report a failure surface. | WDAC-enforced test VM. |
| **F14** | **P2** | SC / LOW | Intune: `Publish-DoxaFullIntune-HighFinal.py:88` vs `DoxaSetupHost.cs:272`. Upgrade: `:222-226`, `:235-260`. Uninstall: `:240-243`. Shortcut: `:350`. `IsValidApp`: `:182`. | (a) Intune requires `Windows11_23H2` while the host supports build ΓëÑ19041, so Windows 10 and early Win 11 devices are excluded. (b) A version change means `IsValidApp` is false, so the old tree is moved to `DoxaRetained-*` and not cleaned on uninstall. (c) `Directory.Delete(recursive)` on a locked tree can leave a half-deleted app (recoverable on retry). (d) A managed install copies the console `DoxaDeploy.exe` as the maintenance host, so the Start-menu shortcut may flash a console window. (e) The `source!=21 \|\| count!=24` literals make any payload change a silent detection failure. (f) The publisher scripts are four generations of near-identical files with hard-coded Dell group and paths. | Align the OS floor. Clean retained dirs on uninstall. Derive counts from the manifest. Archive old publishers. | Upgrade then uninstall leaves no leftovers (VM). |
| **F15** | **P2** | SC / LOW | `Build-DoxaRetailRelease.ps1:61-65`; `Finalize-DoxaSignedRelease.ps1:16-19,22-26`; `Build-DoxaCompleteRelease.ps1:55` | `-RequirePublisherSignatures` checks the freshly compiled unsigned binaries, so it can never pass. `Finalize` matches the signer subject as a substring, does not check the timestamp countersignature, and does not re-hash the baseline EXEs against the manifest it reads. (It does verify PE-neutral equality with `Verify-DoxaPeSigningOnly.py`, which is good.) Also, `Build-DoxaCompleteRelease.ps1:55` contains mojibake in the intermediate README. | Remove the dead switch, pin the certificate thumbprint, require a timestamp, and re-verify baseline hashes. | Finalize with an untimestamped signature must fail. |

---

## D. Online AI architecture and safe test utilities

### Online AI

**What is sound.**
- **Authorization.** Per-device RSA-2048, DPAPI-protected (`Get-DoxaDeviceSignature.ps1:30-44`). The server trusts only keys held in its own allowlist (`worker.mjs:50-61`), never request-supplied keys (tested at `worker.test.mjs:181`).
- **Anti-replay.** The signature covers timestamp plus raw body, with a ┬▒120 s window (`worker.mjs:73,82`) and a per-device rate limit (4/min). A body-bound signature with no nonce means a replay inside 120 s is possible, but it is bounded by the rate limit and TLS, so I classify it LOW.
- **Scope.** There is a two-stage local-and-server scope gate (`scope.mjs`; `Get-DoxaKnowledgeAnswer.ps1:13-18`) before any model call. Out-of-scope and knowledge-gap answers are deterministic, with no model call.
- **Tool execution.** There is none. The worker returns text only (`actions_enabled:false`, `execution_performed:false`), and the client only renders the answer in a RichTextBox. Nothing parses the output into a command.
- **Policy.** The registry key can only deny AI (`Get-DoxaCloudAIPolicy.ps1`), fail-closed on read error, and it is rechecked every tick. Consent is off by default and revocable per session.

**Residual risks.**
- **Hallucination.** The answer is free text from `glm-4.7-flash` with a prompt-only guard. There is no post-generation check. The returned "sources" are the retrieved KB entries, not what the model actually used. Mitigation (prompt "untrusted data", temperature 0, retrieval-gated) is reasonable, but the guarantee is statistical.
- **Prompt injection.** The question is passed inside a JSON blob to the model. Impact is limited to wrong text, because there are no tools.
- **Privacy.** See F8. The payload is minimal and PII-light, but it includes the persistent device ID and IP/timing at Cloudflare, and the typed question is free text.
- **Network failure.** It degrades gracefully to local guidance, and a 35-40 s timeout is applied. A per-question full re-scan adds latency (F7).

### Fault Lab and watchdog

**Primary-monitor safety (well designed).**
- Native code refuses: the primary (`:125`), an embedded or internal panel (`:126`, `IsEmbedded` covers INTERNAL, LVDS, DP-embedded and UDI-embedded), a cloned or non-unique source (`:129`), no active internal panel (`:132`), and fewer than 3 paths (`:119`).
- It validates the reduced topology with `SDC_VALIDATE` before applying, and requires a typed acknowledgement string.
- It is refused in session 0 and in Remote Desktop sessions (`:182`).
- The `.armed` marker is written before `SetDisplayConfig` (`:208`), and the watchdog only starts counting after `.armed` appears.
- SelfTest asserts the primary fails preflight (`Invoke-DoxaFaultLab.ps1:176-179`).

**Gaps.** F9, F10 and F11 above. Also, the "Doxa" label (`Invoke-DoxaFaultLab.ps1:96`, `:105`) is not enforced. `Get-ActiveNames` (`:60-63`) lists any non-primary screen, including a non-Doxa HDMI monitor.

**Read-only validation versus real restore proof.**
- *Proven by source and by the 2026-10-28 JSON:* enumeration, three external CCD validations, primary rejection, snapshot serialization (length-level), GUI creation, and unchanged display count.
- *Not proven:* an actual disable, the watchdog firing, `SetDisplayConfig` restore, the database fallback, behavior if the Doxa is unplugged mid-trial, and a double run. The JSON states this honestly (`live_disable_performed:false`, `automatic_rollback_physically_verified:false`).

**What can and cannot be repaired automatically.** The watchdog can restore a path set that Windows still recognises, on the same adapter LUIDs, in the same session. It cannot restore an unplugged device, a changed LUID, or a driver crash. The fallback is the user (Windows+P, Display Settings, or the printed `--restore` command), with the laptop display staying usable.

**AI and the lab.** The lab never lets the AI run commands. The Recovery Lab (`Doxa-RecoveryLab.ps1`) is simulation-only, gated by an env-var hash, and may send a "simulated" question to the AI. It does not change Windows. The fault-lab folder is not in the retail payload (`Build-DoxaPersonalBundle.ps1:12-34`, and `Test-DoxaPersonalBundle.ps1:36` requires exactly 24 files).

---

## E. What works, what the fixtures prove, and what remains unproven

**Genuinely working or well designed (source-level).**
- Embedded-resource design with a SHA-256 pin on the MSI, extraction into an ACL-protected stage before verification, and no sidecar-file override (tested at `Test-DoxaNativeRelease.ps1:61-65`).
- Driver preservation. A foreign or untrusted driver on the Doxa ID blocks replacement (`:288-291`). A healthy driver returns `DriverAlreadyHealthy`. No MSI downgrade or removal. Uninstall retains the driver.
- Detection is software-only and independent of USB hotplug (`:146-153`), with clean separation from `/verify` and `/verify-panels`. `/verify-panels` explicitly says `ExtendModeNotVerified`, so it does not overclaim four-screen Extend.
- Safe app handling. Modified app trees are moved aside rather than deleted. Reparse points are refused. ZIP path traversal is blocked. Unknown commands exit 30.
- Release packaging parity. The Intune, ManageEngine and personal outputs are the same EXE, verified by the Intune MAC and digest, and by a ZIP and inventory comparison (`Test-DoxaReleaseConsistency.py`). Source and builder hashes are recorded, and signing is checked to change only PE-neutral bytes.
- Consent-first UI. No scan occurs before consent (tested). AI is off by default and separately consented. The UI is bilingual and has accessible names. Per-panel ticks follow PnP data and cannot be hard-coded green (BrandTest).

**Proven only by fixtures or virtual tests.**
- The host `/selftest`: classification truth tables, install, modify, retain and reinstall on a temp folder. There is no MSI, registry, UAC or hardware.
- Bundle, UI-journey and layout tests run against the developer's own live read-only state or fixtures, not a clean machine.
- The Fault Lab's read-only preflight on one Dell with four paths.

**Unproven on a real driver-free Windows computer.**
- MSI behavior with and without Doxa connected, and its custom actions.
- Whether PnP binds the driver afterward, how long that takes, and which diagnostic message appears (F5).
- Whether the display briefly blanks or the laptop panel is affected during driver install.
- UAC and Verb `runas` behavior, WDAC/CLM behavior of the guided UI, and DPI rendering.
- Real Intune or ManageEngine agent runs, including SYSTEM, return codes, and detection after reboot.
- Signed-EXE behavior (SmartScreen and certificate chain).
- The Fault Lab's actual disable-and-restore cycle.

---

## F. Minimal ordered remediation and verification

1. **Gate the MSI on a connected Doxa for the personal EXE** (F1). Keep a separate explicit enterprise `/prestage` mode, unqualified, off by default. *Verify:* a clean VM with Doxa unplugged shows no `msiexec` and the correct message.
2. **Surface the install result** (F3). Show restart-required, driver-binding-pending and ready-but-unplugged outcomes. Remove the duplicate consent (F4). *Verify:* a stub-MSI fixture for exit codes 0 and 3010.
3. **Unify driver classification** (F5), with fixtures for unbound, generic Microsoft, Silicon Motion (several spellings) and foreign drivers across host, PowerShell and the release test. *Verify:* the same truth table passes in all three.
4. **Move the scan off the UI thread, declare DPI awareness, and stop clearing chat on language change** (F6). *Verify:* UI responsiveness at 200% DPI with a screen reader.
5. **Make the Help panel honest for retail** (F7, F8). Offline FAQ by default. Hide Online AI unless enrolled. Keep status text out of the conversation. Disclose the device ID and move to a branded endpoint. *Verify:* an unenrolled profile shows no Online AI.
6. **Fix the Fault Lab double-trial hazard** (F9). Add a run mutex and a visible `.done` result. Strengthen the self-tests (F11). *Verify:* a mutation test fails, and a second trial is refused.
7. **Run the attended Fault Lab acceptance** (F10): trial, watchdog kill, manual restore, double-run refusal. Record the result separately from the read-only validation.
8. **Sign scripts or ship compiled UI** (F13), and tighten finalize (F15). *Verify:* a WDAC test VM and an untimestamped signature that fails finalize.
9. **Resolve the commercial gate** (F2): written OEM redistribution permission.
10. **Then, in order, run the distinct gates:**
    - clean driver-free attended retail install (power, then data, then Extend);
    - signed-EXE install;
    - Intune one-device pilot, including install, detect, repair, uninstall and a USB hotplug flap check;
    - an authored ManageEngine package and detection, then a live agent run.

Do not extend feature scope before steps 1-5. They are what a first commercial customer would hit.