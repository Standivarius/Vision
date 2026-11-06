# Independent Engineering Review: Doxa Full Windows Installer Release Candidate

**Reviewer Model:** Gemini 3.8 Flash (High)
**Mode:** Read-only Source Review (Built-in file inspection only; no commands, tests, or file mutations executed)
**Repository Branch / Snapshot:** `doxa/review-package-20261028` (Review Package October 28, 2026)
**Scope of Review:** `source/full-release/DoxaSetupHost.cs`, `Build-DoxaCompleteRelease.ps1`, `Build-DoxaRetailRelease.ps1`, `Finalize-DoxaSignedRelease.ps1`, `Test-DoxaNativeRelease.ps1`, `Test-DoxaReleaseConsistency.py`, `Verify-DoxaPeSigningOnly.py`, `Publish-DoxaFullIntune.py`, `source/personal-ui/` (`Doxa-BrandTabs.ps1`, `Start-DoxaSetup.ps1`, `Start-DoxaGuidedSetup.ps1`, `Invoke-DoxaPersonalInstallation.ps1`, `Get-DoxaSetupExperience.ps1`), and `release/RELEASE-MANIFEST.json`.

---

## Executive Summary & Verdict

### Release-Readiness Verdict: **REJECTED (NOT SHIPPABLE IN CURRENT STATE)**

While the architecture makes meaningful progress toward a unified single-file installer (embedding the signed vendor MSI and payload, isolating adjacent files, and providing PE-neutral signing checks), **critical software defects prevent first-time installation on target machines and risk bricking endpoint uninstallation/reinstallation cycles**.

Specifically:
1. **P0 Blocker:** First-time installation on any system with Doxa hardware plugged in is completely blocked by a logical inversion in `DoxaSetupHost.cs` (`DriverState()`). An unconfigured USB device or standard Microsoft USB composite driver is classified as an untrusted foreign driver (`state == 2`), causing `Apply()` and `InstallDriver()` to abort with an exception.
2. **P0 Blocker:** `RemoveAppFrom()` throws an unhandled exception if any application file has been altered or added. This causes Windows Programs & Features and Intune/ManageEngine uninstalls to crash, leaving the registration key, shortcuts, and files behind. Because `InstallAppTo()` also checks `IsValidApp()`, the machine becomes permanently unable to uninstall or reinstall.
3. **P1 Blocker:** The Intune detection rule (`DetectDecision()`) returns `failure` whenever Doxa hardware is plugged in without a driver. This creates an unstable detection cycle in Intune, causing periodic detection flappings and unwanted background reinstallation attempts while users work.
4. **P1 Blocker:** Self-cleanup on Programs & Features uninstall fails because `SourceExe` matches `MaintenanceExe`, leaving `DoxaMaintenance-v2.exe` and its directory permanently behind on disk.

These are **code defects**, independent of external acceptance gates such as publisher certificate code-signing or live hardware qualification.

---

## Summary Table of Findings

| ID | Priority | Category | File & Exact Symbol | Summary |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | **P0** | **BLOCKER ΓÇö Code Defect** | `DoxaSetupHost.cs` L65ΓÇô80 (`DriverState`) | Connected Doxa without vendor driver returns `state=2` (Untrusted), blocking `Apply()` |
| **F-02** | **P0** | **BLOCKER ΓÇö Code Defect** | `DoxaSetupHost.cs` L184ΓÇô189 (`RemoveAppFrom`) | Altered or extra file in `AppRoot` throws during uninstall, bricking uninstall & reinstall cycles |
| **F-03** | **P1** | **BLOCKER ΓÇö Deployment Defect** | `DoxaSetupHost.cs` L97ΓÇô104 (`DetectDecision`) | `/detect` fails when Doxa is plugged in without driver; flips Intune state to NotInstalled |
| **F-04** | **P1** | **Code Defect ΓÇö Lifecycle** | `DoxaSetupHost.cs` L258ΓÇô260 (`Remove`) | Programs & Features uninstall cannot delete `MaintenanceExe`, leaving orphan binary permanently |
| **F-05** | **P1** | **Code Defect ΓÇö Enterprise Policy** | `DoxaSetupHost.cs` L268ΓÇô271 (`Open`) | Launching PowerShell with `-ExecutionPolicy Bypass` fails under GPO/WDAC ConstrainedLanguage |
| **F-06** | **P1** | **External Acceptance Gate** | `release/RELEASE-MANIFEST.json` L7ΓÇô9 | Binaries are unsigned; triggers SmartScreen, yellow UAC, and WDAC/AppLocker execution blocks |
| **F-07** | **P2** | **UX / Accessibility Defect** | `DoxaSetupHost.cs` L318ΓÇô346 (`UI`) | Native `DoxaSetup.exe` host is English-only (no Romanian toggle), lacks TabIndex and DPI reflow |
| **F-08** | **P2** | **Performance Defect** | `DoxaSetupHost.cs` L68 (`DriverState`) | Full `Win32_PnPSignedDriver` WMI scan without WHERE filter causes multi-second freeze |
| **F-09** | **P2** | **Packaging / Metadata Defect** | `Publish-DoxaFullIntune.py` L88 | `minimumSupportedWindowsRelease` set to `Windows11_23H2`, excluding supported Windows 10 endpoints |
| **F-10** | **P2** | **Code Hygiene** | `DoxaSetupHost.cs` L42ΓÇô43 (`MoveFileEx`) | Unused P/Invoke declaration left behind after removing queued delete-on-reboot |

---

## Detailed Findings

### P0 Findings: Blockers (Code Defects)

#### [F-01] First-time driver installation on clean hardware is blocked by `DriverState()` logic
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L65-L80)
- **Symbols:** `DoxaHost.DriverState()`, `DoxaHost.InstallDriver()`, `DoxaHost.Apply()`
- **Observed Source Lines (68ΓÇô79):**
  ```csharp
  using(var q=new ManagementObjectSearcher("SELECT DeviceID,IsSigned,DriverProviderName,Signer FROM Win32_PnPSignedDriver"))
  foreach(ManagementObject m in q.Get()){
   if(!(Convert.ToString(m["DeviceID"])??"").StartsWith(UsbPrefix,StringComparison.OrdinalIgnoreCase))continue;
   string provider=Convert.ToString(m["DriverProviderName"])??"";
   string signer=Convert.ToString(m["Signer"])??"";
   bool signed=Convert.ToBoolean(m["IsSigned"]);
   if(!signed || !provider.Equals("SiliconMotion",StringComparison.OrdinalIgnoreCase) ||
      !signer.Equals("Microsoft Windows Hardware Compatibility Publisher",StringComparison.OrdinalIgnoreCase))return 2;
   trusted=true;
  }
  return trusted?1:0;
  ```
- **Mechanism & Root Cause:**
  When Doxa hardware (`USB\VID_090C&PID_770A`) is physically connected to a Windows PC where the Silicon Motion display driver has not yet been installed:
  1. Windows PnP enumerates the device.
  2. Windows assigns either a generic Microsoft USB composite parent driver (`usbccgp.sys`) or an unconfigured null driver.
  3. In `Win32_PnPSignedDriver`, the matching entry has `DriverProviderName = "Microsoft"` (or empty/null), and `Signer = "Microsoft Windows"` (or empty).
  4. Line 74 tests `!provider.Equals("SiliconMotion", ...)` and `!signer.Equals("Microsoft Windows Hardware Compatibility Publisher", ...)`. Both conditions are **TRUE**.
  5. The method immediately executes `return 2;` (Untrusted / Conflicting Driver).
  6. In `Apply()` (line 243) and `InstallDriver()` (line 195):
     ```csharp
     Require(current!=2,"Unexpected driver identity: installation refused");
     Require(state!=2,"Different or untrusted display driver present");
     ```
  7. An `InvalidOperationException` is thrown, aborting installation.
- **Why Dell Passed Testing:**
  The test Dell machine already had `oem102.inf` installed (`DriverValid`, `state == 1`). The code was never executed on a machine with Doxa hardware connected and no driver present (`DriverMissing`, `state == 0`).
- **Impact:**
  First-time retail and enterprise installation fails completely whenever Doxa is connected prior to running setup.
- **Actionable Minimal Fix:**
  In `DriverState()`, do not treat standard Microsoft USB drivers or unassigned drivers as untrusted. Return `0` (missing) if the provider is "Microsoft" or empty/null:
  ```csharp
  if (provider.Equals("SiliconMotion", StringComparison.OrdinalIgnoreCase)) {
      if (signed && signer.Equals("Microsoft Windows Hardware Compatibility Publisher", StringComparison.OrdinalIgnoreCase)) {
          trusted = true;
      } else {
          return 2; // Silicon Motion driver present but unsigned / untrusted
      }
  } else if (provider.Equals("Microsoft", StringComparison.OrdinalIgnoreCase) || string.IsNullOrEmpty(provider)) {
      // Standard Windows USB stub or unconfigured device; driver not yet installed.
      continue;
  } else {
      return 2; // Actual foreign third-party driver bound to hardware.
  }
  ```

---

#### [F-02] Application folder modification permanently breaks uninstall and reinstall cycles
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L184-L189)
- **Symbols:** `DoxaHost.RemoveAppFrom()`, `DoxaHost.InstallAppTo()`, `DoxaHost.Remove()`
- **Observed Source Lines (184ΓÇô189):**
  ```csharp
  static string RemoveAppFrom(string root){
   if(!Directory.Exists(root))return "AppAlreadyRemoved";
   Require(IsValidApp(root),"Unknown or modified application folder: refusing to delete");
   Directory.Delete(root,true);
   return "AppRemoved";
  }
  ```
- **Mechanism & Root Cause:**
  `IsValidApp(root)` enforces exact match against 23 manifest entries and verifies that total files on disk equal 23 (line 134ΓÇô135).
  If any file inside `C:\Program Files\Standivarius\DoxaSetup` is added, modified, or touched (such as a diagnostic log, PowerShell execution artifact, local config, or administrator edit):
  1. `IsValidApp(root)` returns `false`.
  2. `RemoveAppFrom()` throws `InvalidOperationException("Unknown or modified application folder: refusing to delete")`.
  3. `Remove()` aborts before reaching line 253 (`File.Delete(Shortcut)`) and line 254 (`Registry.LocalMachine.DeleteSubKey(RegKey, false)`).
  4. The uninstaller fails in Programs & Features (Windows Settings) and returns error code 30 to Intune/ManageEngine.
  5. If an administrator attempts to rerun the installer to repair or overwrite the corrupted installation, `InstallAppTo()` (line 174) also fails:
     ```csharp
     if(Directory.Exists(root)){
      Require(IsValidApp(root),"Existing application changed: refusing overwrite");
      return "AppAlreadyInstalled";
     }
     ```
- **Impact:**
  The system becomes permanently bricked: unable to uninstall, repair, or reinstall Doxa Setup.
- **Actionable Minimal Fix:**
  In `RemoveAppFrom()`, delete known files listed in `manifest.json`. If unknown files remain, log a trace warning and delete the directory (or leave the directory without throwing), allowing `Remove()` to complete shortcut and registry key cleanup:
  ```csharp
  static string RemoveAppFrom(string root){
   if(!Directory.Exists(root)) return "AppAlreadyRemoved";
   try {
       Directory.Delete(root, true);
       return "AppRemoved";
   } catch (Exception ex) {
       Trace("Warning during directory removal: " + ex.Message);
       return "AppPartiallyRemoved";
   }
  }
  ```

---

### P1 Findings: High-Priority Defects & Lifecycle Risks

#### [F-03] Flapping Intune `/detect` evaluation caused by hardware coupling in `DetectDecision()`
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L97-L104) and [`source/full-release/Publish-DoxaFullIntune.py`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/Publish-DoxaFullIntune.py#L31-L40)
- **Symbols:** `DoxaHost.DetectDecision()`, `DoxaHost.DetectApp()`, Intune `DETECTION` script
- **Observed Source Lines (97ΓÇô104):**
  ```csharp
  static bool DetectDecision(bool appValid,bool registered,bool usb,int driver){
   // A pre-deployment app may be installed without Doxa connected. Once Doxa
   // is connected, missing or untrusted hardware driver makes /detect FAIL.
   return appValid && registered && (!usb || driver==1);
  }
  static bool DetectApp(){
   return DetectDecision(IsValidApp(AppRoot),IsRegistered(),PresentUsb(),DriverState());
  }
  ```
- **Mechanism & Root Cause:**
  In enterprise endpoint management (Microsoft Intune), application detection scripts must test **application installation state**, not peripheral connection state.
  Consider this timeline:
  1. IT deploys `DoxaDeploy.exe /install` via Intune to an offline laptop.
  2. Installation succeeds (`appValid=true, registered=true, usb=false`). Intune runs detection; `/detect` returns 0. App is marked "Installed".
  3. The employee connects Doxa hardware at their desk. The driver is deferred or reboot-pending (`usb=true, driver=0`).
  4. Intune runs its background periodic check (every 8 hours). `DetectDecision` evaluates `(!true || 0==1)`, which evaluates to **`false`**.
  5. `DoxaDeploy.exe /detect` exits with code 1.
  6. Intune marks the application as "Not Installed" / "Failed" and re-triggers `DoxaDeploy.exe /install` as SYSTEM while the employee is working.
- **Impact:**
  Endless install-fail-reinstall loops and false compliance alerts across enterprise fleets.
- **Actionable Minimal Fix:**
  In `DoxaSetupHost.cs`, strictly separate software detection from hardware verification:
  - `DetectApp()` (`/detect`) must return `appValid && registered`.
  - `/verify` remains the command for combined hardware + driver validation.
  - In `Publish-DoxaFullIntune.py`, ensure detection evaluates application presence only.

---

#### [F-04] Programs & Features uninstall leaves `DoxaMaintenance-v2.exe` permanently on disk
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L258-L260)
- **Symbol:** `DoxaHost.Remove()`
- **Observed Source Lines (258ΓÇô260):**
  ```csharp
  if(File.Exists(MaintenanceExe) &&
     !Path.GetFullPath(SourceExe).Equals(Path.GetFullPath(MaintenanceExe),StringComparison.OrdinalIgnoreCase))
    File.Delete(MaintenanceExe);
  ```
- **Mechanism & Root Cause:**
  When uninstalled via Windows Settings or Control Panel (`Programs and Features`), Windows runs `UninstallString`:
  `"C:\Program Files\Standivarius\DoxaMaintenance\DoxaMaintenance-v2.exe" /uninstall`.
  In this process, `SourceExe` is `MaintenanceExe`.
  Because Windows locks executing binaries, `File.Delete(MaintenanceExe)` is bypassed.
  The earlier build used `MoveFileEx(..., MOVEFILE_DELAY_UNTIL_REBOOT)`, which was removed to prevent queued deletions from wiping out reinstallations. However, no out-of-process self-deletion was implemented in its place.
- **Impact:**
  Customer uninstall leaves `C:\Program Files\Standivarius\DoxaMaintenance\DoxaMaintenance-v2.exe` and `Logs/` behind indefinitely.
- **Actionable Minimal Fix:**
  When `SourceExe.Equals(MaintenanceExe)`, launch a detached self-deletion command via `cmd.exe`:
  ```csharp
  Process.Start(new ProcessStartInfo("cmd.exe", "/c ping 127.0.0.1 -n 2 > nul & rmdir /s /q \"" + MaintenanceRoot + "\"") {
      CreateNoWindow = true, UseShellExecute = false
  });
  ```

---

#### [F-05] `Open()` fails silently in GPO / WDAC / AppLocker environments
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L268-L271)
- **Symbol:** `DoxaHost.Open()`
- **Observed Source Lines (268ΓÇô271):**
  ```csharp
  string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
  Process.Start(new ProcessStartInfo(exe,"-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""){
   UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=AppRoot});
  ```
- **Mechanism & Root Cause:**
  1. Under enterprise Group Policy (MachinePolicy / UserPolicy) or WDAC (Windows Defender Application Control) ConstrainedLanguageMode, `-ExecutionPolicy Bypass` is explicitly ignored by PowerShell.
  2. In ConstrainedLanguageMode, WinForms UI (`Add-Type -AssemblyName System.Windows.Forms`) in `Start-DoxaGuidedSetup.ps1` is blocked as unauthorized API reflection.
  3. Because `CreateNoWindow=true` and stderr is not captured or displayed, PowerShell terminates silently.
- **Impact:**
  Clicking "Open Doxa setup" in the GUI or from the Start Menu does nothing; no error is shown to the user.
- **Actionable Minimal Fix:**
  At minimum, capture process exit code/errors and notify the user if PowerShell fails. For enterprise reliability, sign all delivered PowerShell scripts with the publisher certificate to satisfy `AllSigned` policy, or replace the script launcher with a compiled native C# presentation window.

---

#### [F-06] Unsigned binaries fail Windows SmartScreen, UAC, and WDAC acceptance
- **File:** [`release/RELEASE-MANIFEST.json`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/release/RELEASE-MANIFEST.json#L6-L9)
- **Observed Manifest Content:**
  ```json
  "machine_install_and_signatures": {
      "DoxaDeploy.exe": "NotSigned",
      "DoxaSetup.exe": "NotSigned"
  }
  ```
- **Mechanism & External Gate Status:**
  The current binaries in `release/` are unsigned review builds.
  On retail Windows 11 machines, running `DoxaSetup.exe` prompts Windows SmartScreen ("Windows protected your PC") and displays an untrusted yellow UAC dialog.
  On managed corporate machines enforcing AppLocker or WDAC PE rules, execution is blocked immediately.
- **Impact:**
  External release blocker for general distribution.
- **Actionable Next Step:**
  Sign `DoxaSetup.exe` and `DoxaDeploy.exe` using the publisher Authenticode certificate with a valid timestamp, then execute `Finalize-DoxaSignedRelease.ps1` to re-verify PE normalization and repackage the release.

---

### P2 Findings: Medium-Priority Defects (UX, Performance, Hygiene)

#### [F-07] Native `DoxaSetup.exe` host lacks Romanian localization and accessibility metadata
- **File:** [`source/full-release/DoxaSetupHost.cs`](file:///C:/mcp/vision-dev/state/reviews/doxa-gemini-flash-20261028/source/full-release/DoxaSetupHost.cs#L318-L346)
- **Symbol:** `DoxaHost.UI()`
- **Mechanism:**
