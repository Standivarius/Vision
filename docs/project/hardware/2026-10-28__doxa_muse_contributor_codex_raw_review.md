**Independent Review — Standivarius Doxa Windows Host 0.4.0-preview.12**

**Readiness Verdict: NOT READY for retail or broad Intune/ManageEngine rollout.** Safe as a Dell-only lab candidate. Do not sign-off production until P0 closed and physical + managed-agent qualification rerun on the exact signed bits.

**What Actually Holds**

- No auto-reboot, no silent topology writes: `DoxaSetupHost.cs:Apply(),InstallDriver()` returns `RestartRequired`/3010, never restarts; UI only opens `ms-settings:display`.
- Healthy-driver preservation is real logic, not docs: `ClassifyDriver():69-80`, `DriverState():81-96`, `InstallDriver():241-269` refuse state 2, keep state 1. Native fixtures prove classification.
- Single-EXE embedding with sidecar isolation: `ReadEmbedded():179-187`, `ValidDriver():54`, `VerifyAndUnpack*():189-197`, proven by `Test-DoxaNativeRelease.ps1:48-52`.
- Zip-slip, uninstall-hijack, reinstall-race guards: `AllowedPath():132-138`, `RecognizedRegisteredMaintenance():104-108`, `IsRegistered():112-123`, `CleanupMaintenanceAfterParent():313-333` are careful.
- Enterprise hygiene good on paper: SYSTEM/runAsAccount system, `deviceRestartBehavior:suppress`, 0/3010 only, custom PS detection `DoxaDeploy.exe /detect`, Dell-only group checks in `Publish-DoxaFullIntune-HighFinal.py:61-76`, `Switch-*:21-30`, `Clear-*:22-32`.
- Consent-first UI, offline-by-default AI, IT deny-only key in `Get-DoxaCloudAIPolicy.ps1:14-23`, `Start-DoxaGuidedSetup.ps1:169-186`.

**P0 — Ship Blockers**

- **Unsigned host.** `release/RELEASE-MANIFEST.json:6-9` `NotSigned` for both EXEs. `Build-DoxaRetailRelease.ps1:52-57` allows unsigned unless flag passed; `Finalize-DoxaSignedRelease.ps1:14-34` not yet executed. SmartScreen/WDAC/corporate policy will block. Fix: sign, timestamp, run `Finalize-*`, reissue zips/`intunewin`/manifest; requalify — do not ship current hashes.
- **No qualified first-use driver install.** `DoxaSetupHost.cs:246-260` stages MSI disconnected then returns `DriverMSIPreparedForFirstConnection` without verification. `Invoke-DoxaPersonalInstallation.ps1:21-26` explicitly calls this `preconnection_install_unqualified` exit 26. Vendor MSI runtime unknown, no evidence supplied. `Test-DoxaNativeRelease.ps1:71`, `windows-standalone.json:7`, `managed-parity-after-high.json:8` all `NOT_RUN/NOT_EXECUTED`. Fix: one recoverable driver-free Dell test with connected Doxa + SetupAPI/DeviceManager proof; decide to block disconnected `/install` driver step until qualified.
- **Uninstall lifecycle unproven.** Brief states Dell uninstall assigned but agent completion NOT confirmed, app + `HKLM\...\Uninstall\StandivariusDoxaSetup` still present. `DoxaSetupHost.cs:Remove():347-362` preserves driver by design but deletes reg before guaranteeing `DoxaMaintenance-v2.exe` deletion; SYSTEM orphan has no reboot-delete fallback unlike interactive path `ScheduleInteractiveMaintenanceCleanup():334-346`. Test: force Intune uninstall to completion, verify `/detect`→1, reg gone, driver retained, no orphan.
- **Retail file-picker defeats single-EXE promise.** `Start-DoxaSetup.ps1:578-601` `OpenFileDialog` asks nontechnical buyer to locate `SMI770 MSI`, then calls unreviewed `Test-DoxaPackageGate.ps1`/`Get-DoxaSetupExperience.ps1` (not in packet). `Doxa-BrandTabs.ps1:203-220` correctly uses embedded `DoxaMaintenance-v2.exe /install`. Fix: remove picker from retail; embedded-only path.
- **Missing sources prevent verification.** Gate, experience, compatibility, knowledge-answer, connection-guide, privacy/local notices referenced but not supplied. Cannot validate `signed_driver_present`, `hardware_ready`, `physical_display_topology_verified`, AI scope. Supply or remove claims.

**P1 — High Severity**

- **Host source drift.** `Build-DoxaRetailRelease.ps1:21,37-40` recompiles current `DoxaSetupHost.cs`, only pins MSI hash `28` and payload zip; no `.cs` hash. Candidate-tested code ≠ shipped code. Fix: hash-pin `.cs` + manifest it.
- **Complete-candidate overexposure.** `Build-DoxaCompleteRelease.ps1:84-90` packs 5 files incl. raw `SMIUSBDisplaySW770.msi` + both EXEs into both Personal/Managed zips. Customer can double-click MSI bypassing checks. Retail build fixes this (`DoxaSetup.exe` only / `DoxaDeploy.exe` only) — do not distribute complete zips.
- **TEST branding ships.** `Start-DoxaSetup.ps1:33`, `Start-DoxaGuidedSetup.ps1:11`, `Doxa-BrandTabs.ps1:15` title `TEST preview.12`. Fix before signing.
- **Cryptic status for consumers.** `State():97-103` + `UI():449-507` shows `AppMissing DriverValid USBDetected`. Needs human EN/RO sentence + next action.
- **Dual driver UX flags.** Host `InstallDriver():250-251` uses `/qn`; personal script `Invoke-*:48` uses `/passive`. Standardize silent/passive story and log location (`Maintenance\Logs` vs `ProgramData\Standivarius\...`).
- **Read-only commands write.** `Trace():49-52` `CreateDirectory(Logs)` on `/detect|/verify|/selftest`. SYSTEM detect litters `Program Files`. Make logging best-effort under temp for read-only modes.
- **Brittle INF check.** `Test-DoxaNativeRelease.ps1:19,57` hardcodes `oem102.inf`. Snapshot-only; use driver-store enumeration.
- **Stale Intune paths/docs.** `Publish-DoxaFullIntune-HighFinal.py:24` points to `gemini-high-fix-build-20261028` not current retail dir; `README-FIRST.txt:17-20` says 4-file ManageEngine side-by-side while retail zip is single-EXE. Align docs.

**P2 — Hardening**

- Retained-dir leak: `RemoveAppFrom():226-237` moves modified app to `DoxaRetained-*` forever; no cleanup/documented recovery. Add cap + README note that uninstall retains signed driver.
- `/uninstall` elevation check `DoxaSetupHost.cs:439` omits `SessionId!=0` used for `/install:426`; `Main():516-518` shows MessageBox for install/repair/open but not uninstall. Align.
- `Verify-DoxaPeSigningOnly.py:27-30` correctly excludes cert-table/checksum but does not check countersignature strength; rely on `Get-AuthenticodeSignature Valid` + timestamp — enforce in final checklist.
- External link `Start-DoxaSetup.ps1:200` Silicon Motion URL unverified; pin or remove.
- Secret scan `Build-DoxaCompleteRelease.ps1:86` regex naive; keep as smoke only.

**Evidence Challenge**

PASS claims are fixture-only. `native-regression-after-high.json`, `managed-parity-after-high.json`, `windows-standalone.json` explicitly mark MSI apply, system install, managed-agent as `NOT_EXECUTED/NOT_RUN`. Read-only `/detect` showing `AppMissing DriverValid USBDetected` exit 1 proves isolation, not install success. Claimed SYSTEM Intune install/detection on one Dell has no log in packet; uninstall still pending — cannot accept as lifecycle proof. Prior-version passes do not transfer.

**Missing Gates Before Go-Live**

1. Commercial Authenticode + timestamp on both EXEs + rebuilt packages.
2. Clean-host connected install with driver-missing → verified `DriverInstalledVerified`, reboot-3010 path, 4-screen user-session check.
3. Disconnected SYSTEM `/install` decision (allow app-only or block driver).
4. Intune SYSTEM install/detect/verify/uninstall round-trip + ManageEngine agent delivery.
5. Restrictive-policy retail GUI (SmartScreen, UAC, WDAC/GPO-blocked Bypass) EN+RO.
6. Repair (`/repair`), idempotent reinstall, corrupt-app retain-and-recover on live box.

**Prioritized Fix/Test Sequence**

1. Remove file-picker, TEST labels; pin host `.cs` hash; fix Trace side-effect; clarify retained-driver UX.
2. Run `Finalize-DoxaSignedRelease.ps1` with publisher; verify `Verify-DoxaPeSigningOnly.py` + `/selftest`.
3. Lab Dell: driver-free connected install → verify → reboot test → uninstall to completion.
4. Single-device Intune + ManageEngine agent cycles on signed bits; capture logs.
5. Full GUI acceptance EN/RO under locked-down policy; publish signed manifest + hashes.
