# Independent Windows engineering assessment

**Decision:** This candidate is suitable for continued controlled testing, but **neither retail nor Intune/ManageEngine production release is ready**. I found no source evidence of automatic display changes or driver removal. The main release blockers are an unqualified disconnected MSI path, customer checks before consent, incomplete managed hardware verification, and the absence of current-candidate physical and agent tests. No P0 finding is established from the supplied source.

This is a static assessment of the supplied packet. I did not run the code or inspect the vendor MSI’s internal actions.

## Priority-ranked findings

| Priority | Classification | Finding |
|---|---|---|
| P1 | Source-verified bug | Unattended install invokes the vendor MSI while Doxa is disconnected, although the application identifies that path as unqualified. |
| P1 | Source-verified bug | The native customer window reads device and driver state before the guided consent step. |
| P1 | Source-verified bug | `/verify` can succeed without identifying any of the three external panels. |
| P1 | Strong risk needing a test | The Windows build check may reject supported systems, while an existing driver bypasses that check altogether. |
| P2 | Source-verified bug | The signed finalization manifest drops fields required by the supplied consistency checker. |
| P2 | Strong risk needing a test | MSI execution has no time limit; connected-device verification allows only 15 seconds after MSI completion. |
| P2 | Source-verified bug | Installation blocks the customer window, and visible Romanian text and accessibility descriptions remain partly English. |
| P2 | Source-verified bug | The registered repair command contains backslashes before its quotation marks. |

### 1. P1 — Disconnected corporate install applies an unqualified MSI

`DoxaSetupHost.cs` `Apply` obtains USB presence, then calls `InstallDriver(driverPackage, plugged)` for both connected and disconnected machines (approximately lines 318–329). `InstallDriver` launches `msiexec /i ... /qn /norestart` whenever it does not classify a driver as healthy or untrusted (262–280). With no device connected, it returns `DriverMSIPreparedForFirstConnection` after MSI exit 0 (281). The comment in `Apply` says the driver is deferred on a disconnected endpoint (322–324); the executable code does the opposite.

The guided application explicitly reports `prestage_msi_qualified=false` and `automatic_driver_installation_permitted=false` in `Get-DoxaCompatibility.ps1` (42–56). Its separate personal installation path refuses an unqualified preconnection install in `Invoke-DoxaPersonalInstallation.ps1` (21–27). The shared native host therefore takes the very path those components warn against. This matters most for the stated corporate goal of reliable SYSTEM installation before physical connection. A successful MSI exit alone cannot establish what the vendor MSI staged, whether it requires hardware, or what it will do at first connection.

**Minimal resolution:** Until the MSI’s disconnected behavior is physically qualified, install the application and maintenance registration while disconnected, report driver preparation as pending, and make `/verify` remain incomplete. If pre-provisioning is essential, qualify the exact MSI offline on a clean driver-free machine, then test first connection, reboot-required outcomes, repeat install and uninstall. Update the comments and user guidance to match the chosen behavior.

### 2. P1 — Customer diagnostics precede consent

The no-argument native executable enters `UI()` (`DoxaSetupHost.cs` 532–536). On showing that window, `checkState()` runs `State()` (515–527). `State()` reads installed application files, enumerates a USB PnP identity and queries signed drivers through WMI (55–103). This occurs before the user reaches `Start-DoxaGuidedSetup.ps1`, whose local read-only consent checkbox is on its first page (42–48, 168–178). The native **Install / check Doxa** button can also call `Apply()` and start MSI work before opening that guided application (500–512).

The welcome script’s claim that no hardware enumeration occurs before consent (line 2) is true only for entry through that script. It is not true of the shipped native customer entry path. A user may reasonably understand the first native window’s automatic “Checking Doxa…” as part of setup.

**Minimal fix:** Put the consent step ahead of the native `State()` call, or make the first native window a purely static welcome with a clear permission action before it starts checks. Keep the separate UAC request for installation. Test a fresh launch of `Personal/DoxaSetup.exe`, including refusal and closure, while instrumenting calls to `State()`, WMI and MSI; testing the embedded PowerShell wizard alone cannot close this gap.

### 3. P1 — Managed `/verify` does not verify the screens

`DoxaSetupHost.cs` `Run("/verify")` returns 0 when the application is valid, a matching USB device is present and `DriverState()==1` (445–449). Neither `PresentUsb()` nor `DriverState()` enumerates monitor panels (55–96). Thus a machine with the controller and a trusted driver but zero, one or two external panels can pass `/verify`. The retail README calls this “Machine driver verification” (`release/README-FIRST.txt` 9–15), which is accurate in a narrow sense; it does not meet the product goal of deterministic hardware verification for all three panels.

The guided UI has a separate three-panel PnP presentation (`Doxa-BrandTabs.ps1` 304–315), and it carefully states that a green tick does not prove Extend mode (111–116, 143–144). Preserve that distinction.

**Minimal fix:** Keep `/detect` as software-only so USB hotplug cannot cause endpoint-manager detection to flap. Either add a separate machine command that verifies all three expected PnP monitor identities, or extend `/verify` and state its exact contract. Report controller, driver and panel results separately. Qualify four independent extended displays in an attended console session; a SYSTEM command should not claim to prove physical arrangement.

### 4. P1 — Windows support gate is inconsistent and needs a real OS test

`InstallDriver` returns immediately for any driver classified healthy, before checking Windows build and 64-bit OS (262–267). On that path, `Apply()` can still install and register the application (318–331). With no healthy driver, the build check uses `Environment.OSVersion.Version.Build`; the build scripts compile with `csc.exe` and show no explicit Windows compatibility manifest (`Build-DoxaRetailRelease.ps1` 28, 37, 43–46). Whether that API reports the intended Windows build for these exact binaries must be checked on supported systems. The guided compatibility check uses `Win32_OperatingSystem.BuildNumber` instead (`Get-DoxaCompatibility.ps1` 18–29), so the two channels can disagree.

This is a **risk**, not proof that a particular Windows 10 or 11 release is rejected. It is also source-verified that the gate is skipped when a healthy driver exists.

**Minimal fix:** Evaluate one documented OS and architecture requirement at the start of `Apply()`, using a version source validated on every supported Windows baseline. Test driver-free and driver-present paths on those baselines, including an unsupported one. Decide whether unsupported Windows should allow an app-only installation and give it an explicit result if so.

### 5. P2 — Final signed-release evidence cannot pass its own consistency contract

`Finalize-DoxaSignedRelease.ps1` writes a final manifest containing product, status, signing proof and files recorded under `relative` (56–69). `Test-DoxaReleaseConsistency.py` requires `source_commit`, `native_host_source_sha256` and `retail_builder_source_sha256` (20–26), then expects each inventory entry under `path` (29–33). It consequently cannot validate the final signed manifest as written. The finalizer checks that the earlier manifest says `validated_standalone` and compares signed EXEs with baseline EXEs using a PE verifier (22–43); the verifier’s implementation was not supplied, so its byte comparison cannot be independently assessed here.

This is a release-evidence defect, not evidence that the embedded MSI changed. The earlier retail builder records source commit and payload hashes, and the unsigned manifest identifies commit `8efe76fa6b6565cc38957c2e4fcb467fc47bc65f`.

**Minimal fix:** Carry the baseline source identity and embedded payload hashes into the signed manifest, use one inventory schema across builders and checker, and verify the baseline files against their manifest before finalization. Run the consistency checker on the *signed* final package, then preserve its result. The current unsigned Intune/ManageEngine parity result does not automatically transfer to newly signed bytes.

### 6. P2 — MSI and PnP timing can leave an endpoint stalled or partially installed

`InstallDriver` calls `process.WaitForExit()` without a timeout (`DoxaSetupHost.cs` 271–279). A stalled vendor installer can therefore leave a customer window or SYSTEM endpoint-manager job waiting indefinitely. On a connected device, MSI exit 0 is followed by only 15 one-second `DriverState()` polls (281–289). If binding takes longer, `InstallDriver` throws before `InstallAppTo` and `InstallMaintenance` run (`Apply`, 328–330), despite MSI already having returned success. A subsequent attempt may rerun the MSI because the driver still appears missing.

The code correctly avoids claiming a completed binding when it has not observed one. The timing limits nonetheless need qualification against the actual vendor MSI and PnP behavior.

**Minimal fix:** Put a bounded, documented timeout around MSI, retain its log and return a distinct pending/timeout result. Treat a successful MSI with delayed PnP binding as a state that can be rechecked without needless MSI repetition. Test clean connected install, disconnected install, slow binding, MSI failure, 3010, and interrupted repair under the real SYSTEM agent.

### 7. P2 — The customer flow needs responsive and complete bilingual acceptance

The native install click waits synchronously for the elevated process, then calls `State()` and `Open()` on the UI thread (`DoxaSetupHost.cs` 500–512). During a long MSI operation the native window cannot update normally or respond to assistive technology. The guided `RefreshState` also performs diagnostic work from a UI event path (`Start-DoxaSetup.ps1` 285–350). Existing layout tests exercise control placement and drawing, but do not demonstrate usable focus, screen reader announcements, large text or a long-running install.

Romanian coverage is meaningful but incomplete. `Doxa-BrandTabs.ps1` translates controls only when their English text is in `$brandTranslations` (338–380); the visible `Install / check driver` button (199–202) has no entry. Its accessibility name and description are English, as is the Windows settings button description (184–185). The screen illustration paints `Laptop 1` literally (177–179). The status row in `Start-DoxaSetup.ps1` also constructs English “Signed Silicon Motion driver, version …” text (298–300). These are concrete gaps for a bilingual accessible retail installer.

**Minimal fix:** Run installation and diagnostics with responsive progress and cancellation behavior appropriate to MSI; translate remaining visible and accessible strings through the same language mechanism. Perform attended English/Romanian keyboard, high DPI and screen reader sessions on a typical laptop, including installer failure and 3010.

### 8. P2 — Registered repair command is malformed

`InstallMaintenance` registers `ModifyPath` as `"\\\""+MaintenanceExe+"\\\" /repair"` (`DoxaSetupHost.cs` 291–309). In C#, that yields a backslash followed by a quote around the path, unlike the correctly formed `UninstallString` and `QuietUninstallString` immediately above it. Windows repair entry behavior for that value is therefore unreliable. The command-line `/repair` path itself calls `Apply()` (445–455), but the registered repair entry may never invoke it correctly.

**Minimal fix:** Write the path using the same quoting construction as `UninstallString`, followed by ` /repair`. Inspect the installed registry value and invoke repair through the Windows application entry on a disposable test machine.

## What the evidence establishes

Several design choices are sound. The native host embeds the MSI and application rather than trusting adjacent files; it checks the extracted MSI against a fixed SHA-256 (`DoxaSetupHost.cs` 200–217), and the builders check the supplied vendor MSI’s hash and Authenticode identity (`Build-DoxaRetailRelease.ps1` 31–36). The host uses the 64-bit registry view (130–151), preserves a driver it classifies as healthy, rejects an untrusted matching binding (262–265), uses `/norestart`, and never calls a display-topology setter. Modified application files are moved aside for recovery rather than overwritten (`RemoveAppFrom`, 234–259). Software detection deliberately ignores USB connection, a sensible endpoint-manager contract (145–151).

The supplied checks support narrower conclusions than some PASS labels suggest. The embedded `SelfTest()` uses disposable folders and fabricated driver-classification inputs; its own comment says it does not perform driver installation, registry registration, Start-menu work or display changes (`DoxaSetupHost.cs` 399–443). `Test-DoxaNativeRelease.ps1` explicitly does not start MSI or deploy an agent (4–5, 84–85). Its sidecar test is useful for confirming that neighboring fake payload files do not override resources (61–65). `Test-DoxaReleaseConsistency.py` verifies and decrypts the unsigned Intune package and compares its sole EXE with ManageEngine’s (40–67); it does not test endpoint-manager execution.

The extracted bilingual journey tests show that consent controls, navigation and selected PnP tick rendering work in their test modes. Some reported fields are assigned constants, including zero initial hardware scans and network requests in `Start-DoxaGuidedSetup.ps1` (261–267), rather than measurements of the native entry path. The brand test clicks tabs and synthesizes panel data; it does not click the new driver action (`Start-DoxaSetup.ps1` 567–625). These tests are valuable regression checks, but do not close findings 1–3 or prove retail accessibility.

## Release decisions and practical sequence

**Retail: hold.** First fix native consent order and responsive installation, then qualify the exact signed one-file EXE on a driver-free physical Windows laptop with Doxa attached. Observe vendor MSI behavior, UAC, three panel identities, four independently extended displays, restart requests, Romanian/English use and accessibility. Reconfirm preservation of an already working signed driver. Commercial signing and timestamp verification remain a required distribution gate because the manifest lists both EXEs as `NotSigned`; they do not substitute for those physical tests.

**Intune: hold for production; controlled pilot only after finding 1 is resolved or the exact disconnected MSI path is qualified.** Keep `/detect` software-only, define a separate hardware-verification result, correct the signed-package evidence schema, and exercise install, detection, repair, uninstall and 3010 under the actual Intune SYSTEM agent both before and after connection.

**ManageEngine: hold independently.** Package parity shows that its unsigned EXE matches Intune’s payload, but no live ManageEngine agent qualification is supplied. Run the same state matrix with the actual agent, installation account, detection rules and return-code handling. Add restrictive WDAC/AppLocker and full retail acceptance as later environment gates. The older Dell managed observations and retained 4.7.6.8001 driver are useful safety context, not proof for this candidate.

The shortest path forward is: **(1)** settle and test disconnected MSI behavior; **(2)** fix native consent and `/verify`; **(3)** align OS gating, MSI timing and repair registration; **(4)** complete retail usability checks; **(5)** sign, finalize and revalidate exact package bytes; **(6)** qualify physical first install and both endpoint agents on those final bytes.