# Doxa Setup — full Windows installer release-candidate review

**Status:** full Windows installer **engineering candidate**, with executable software completed for the planned personal and IT routes. Not a claim of completed public signing, clean-PC physical acceptance or live current-version endpoint-manager delivery. Source branch: `doxa/review-package-20261028`; code review PR #106.

## What has changed in the Windows software

The previous Preview.12 customer application only provided a read-only driver tab. This work adds a native Windows installer host, a native silent deployment host, and an end-to-end installation engine that calls the official signed Windows Installer package when needed.

- `DoxaSetup.exe`: a single-file Windows desktop installer. Includes the Doxa application and original signed driver package as embedded resources, verifies integrity, invokes Windows UAC when required, checks for an existing healthy signed driver before installation, and opens the existing bilingual Doxa interface. Creates a Start-menu shortcut.
- `DoxaDeploy.exe`: the same engine in a console executable for IT. Supports `/install`, `/detect`, `/verify`, `/uninstall`, `/selftest`. Distinct application presence and signed-driver status; Windows reboot return codes pass to IT.
- **Windows signing does not rewrite installer logic.** It changes the executable's digital signature and file hash. Both EXEs must be signed and timestamped, and the packages rebuilt from those signed binaries. `Finalize-DoxaSignedRelease.ps1` supplies this final packaging stage.
- The installed customer interface is still the existing EN/RO guided app, not a second independently rewritten product. It opens directly through a Windows process rather than the original visible batch-file entry point. PowerShell execution remains subject to enterprise device policy.

## Exact customer journey

1. Connect laptop, Doxa power, then the USB-C DATA connection as the physical guide shows.
2. Run the single `DoxaSetup.exe`, choose **Install / check Doxa**, approve normal Windows UAC. If the correct signed driver is already present, it is left unchanged.
3. For a missing driver with recognised connected hardware, the installer validates its embedded package, runs Windows Installer silently with an IT/Windows-readable log, and verifies driver identity afterwards. It never downgrades or removes a healthy driver automatically.
4. If the driver installation requires a reboot, return a restart-required result; do not restart automatically.
5. Launch the existing EN/RO setup interface; detect the three external panels and use Windows Identify/Extend to arrange independent screens. A PnP tick alone never proves fully working extended desktops.
6. Run the actual pointer, click, typing and reconnect acceptance on a logged-on Windows desktop. Do not treat an Intune SYSTEM test as user-session graphics evidence.

## Managed delivery

**Microsoft Intune:** upload `Intune/DoxaDeploy.intunewin`; machine/System install `DoxaDeploy.exe /install`, custom detection `DoxaDeploy.exe /detect`, uninstall `DoxaDeploy.exe /uninstall`. Use `/verify` for separate signed-driver checks. Configure reboot handling and explicit narrow assignment. The driver installer is embedded; no external dependency files or model/cloud service needed.

**ManageEngine Endpoint Central:** deploy `ManageEngine/Doxa-Managed-Windows.zip`, containing the same standalone `DoxaDeploy.exe`. Run as System on explicitly targeted computers; the same install/detect/verify/uninstall commands. Record remote agent execution logs separately.

The managed `/uninstall` removes the Doxa app only and deliberately retains the working Windows display driver. Modified/foreign application directories are not deleted.

## Trust and safety boundaries

- Official driver MSI is byte-for-byte preserved inside the Windows executable. It is pinned to a previously signature-checked SHA-256 digest.
- The standalone executable always favours its own embedded resources over arbitrary adjacent files. Elevated extraction is inside an administrator-owned Program Files staging area, not a user-writable privileged-script location.
- No AI model gets permission to install drivers, run arbitrary Windows commands or change security policy. Online Doxa Help remains separately consent-gated.
- No automatic display-topology writes, policy changes or reboots.
- For a missing driver, unknown driver identity or disconnected Doxa, the installer has an explicit refusal/connection path; it does not guess hardware capabilities.
- Publisher signing still needs to be applied to the final executables. Device policy restrictions and customer trust decisions must be checked against the signed files.

## Actual verification on Dell

- Both native executables compile using the Windows .NET Framework compiler.
- A standalone `DoxaDeploy.exe /selftest` passes without adjacent files: it extracts and verifies both embedded installation resources without installing anything.
- Read-only detection identifies that Dell already has a driver but no installed retail app, rather than claiming customer installation complete.
- Modified sidecar files cannot override embedded resources: positive and negative isolation checks pass.
- Existing Preview.12 bilingual extracted-package tests passed; isolated managed app-only lifecycle tests passed before this native release layer.
- The authentic Microsoft Win32 Content Prep Tool produced the new Intune package. ManageEngine ZIP derives from the same embedded deployment binary.
- No new actual driver installation, machine-level retail install/uninstall, reboot or Windows display change occurred on working Dell. No new Intune or ManageEngine agent assignment has been run against these exact native binaries.

## Reviewer work order

Review the new C# host, full-source builders, signed-finalisation script and **the actual distributed binary package**. Return P0/P1/P2 findings with reproduction and code path. In particular:

1. Check signed-driver detection and non-downgrade logic, hardware PnP detection before first install, Windows Installer exit/rollback, reboot reporting and safe failures.
2. Challenge embedded resource integrity, protected staging directory ACL, validation of modified app directory, signing-stage provenance and adjacent-file override defences.
3. Verify managed install/detect/verify/uninstall on an enrolled Windows test endpoint under Intune and independently under ManageEngine; preserve exact agent output.
4. Verify actual first-time driver-free install and physical four-screen results on recoverable hardware, including preconnection/connection, disconnect/reconnect and user-session interaction.
5. Test the native personal window, normal UAC and installed bilingual app at ordinary and high-DPI laptop sizes, keyboard/screen-reader accessibility, persistent Help and local/cloud consent.
6. Ensure execution policy, WDAC/AppLocker, endpoint management and offline Windows policies are respected; record blocked installations honestly.
7. Distinguish passing source/unit tests, on-device user observation and production-release readiness. Signing alone cannot fix an untested driver or display workflow.

**Files:** `app/packaging/doxa-setup/full-release/DoxaSetupHost.cs`, `Build-DoxaCompleteRelease.ps1`, `Build-DoxaRetailRelease.ps1` and `Finalize-DoxaSignedRelease.ps1`.

**Latest local distribution:** `C:\wt\doxa-review-package-20261028\artifacts\releases\retail-go-live-candidate`. The consolidated ZIP and checksum manifest are in the review output folder.
