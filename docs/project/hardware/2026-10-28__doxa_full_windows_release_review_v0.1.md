# Doxa Setup Ã¢â‚¬â€ full Windows installer release-candidate review

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
- No physical vendor-driver reinstall, reboot or Windows display change occurred on the working Dell. **An actual Dell-only Intune install and uninstall of the new native executable subsequently PASSED**, as documented below; no new ManageEngine agent run on the exact binary has yet been observed.

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

## Implementation corrections after the first review build

- Completed native setup installation and managed detection in a shared Windows engine. The Windows UI checks hardware only after a customer action; no scan is forced before the first-use disclosure.
- Native setup and management now register an entry in Windows installed apps and maintain a protected Start-menu/uninstall executable. Normal customer uninstall requests Windows administrator approval; automated IT installation/uninstall is silent. Driver removal is **not** part of an app uninstall.
- The native engine returns a clear *deferred driver* status for a computer without connected Doxa hardware. For connected Doxa, detection refuses a missing or untrusted driver. Windows will not claim successful hardware readiness because the app folder exists alone.
- Added installed-app integrity checks, repeat-install handling, refusal to remove changed files, protected Windows Installer staging/logging, normal signed-driver no-op handling and explicit non-reboot exit codes.
- The branded bilingual driver screen now has a direct **Install / check driver** action using the protected native Windows installer. The previous preview-only disabled-driver instruction has been removed.
- Fixed a build integration fault that omitted embedded resources from an intermediate EXE. The builder now embeds both release payloads and requires the executable to pass extraction and integrity testing. Intune's encrypted content was independently decrypted and compared byte-for-byte with the ManageEngine deployment EXE.
- Added verification that Windows signing may change only the PE checksum and certificate table, not the executable code or embedded resources. Packaging is rebuilt from the signed originals.
- The local Windows test covers the embedded payload, an app-only install in a disposable folder, repeat installation, a modified file that blocks removal, invalid commands, detection of driver gaps and filesystem state preservation.

## Real Intune Dell qualification Ã¢â‚¬â€ observed result

On 28 October 2026, the obsolete Dell-only Doxa test **Uninstall** assignments were first checked against absent original app directories and then cleared, leaving other Intune apps and groups untouched.

A new isolated **Dell-only** Win32 application was published using the full native Doxa deployment EXE and the actual Microsoft Win32 Content Prep Tool. The Intune Management Extension on Dell downloaded the encrypted content, executed the SYSTEM install and independently ran detection. **Real install PASS; post-install detection PASS.** Doxa app files, protected maintenance host and Windows Apps & Features registration were confirmed. The native `/detect` and `/verify` returned success while the existing signed display driver remained unchanged.

The Dell-only cloud assignment was then switched to **Uninstall**, strictly in the same Dell-only group. The actual Intune Management Extension then executed the SYSTEM uninstall with success and re-detected the application as NotInstalled. The Program Files application directory and Windows Apps & Features registration were absent; the original signed display driver stayed unchanged. The temporary test assignment was cleared after verification so future installations cannot be affected by it.

ManageEngine: prior real ASUS Endpoint Central app-only lifecycle success remains historical. The current native package passes local encrypted-content equivalence/fixture tests, but its new exact-binary deployment through a running ManageEngine agent has **not** yet been observed. The ASUS Windows development bridge is connected but the endpoint-management agent is currently uninstalled.

## Exact status for reviewers

| Step | Result |
| --- | --- |
| Windows personal and SYSTEM deployment executables | Built, standalone integrity PASS |
| Branded EN/RO interface, narrow layout, privacy and tab navigation | PASS |
| Initial/duplicate/tampered app fixture tests | PASS |
| Intune encrypted package vs ManageEngine executable | Exact binary equivalence PASS |
| Real managed Intune install and detection | PASS |
| Real managed Intune uninstall | PASS â€” SYSTEM uninstall, app and registration absent, driver preserved; old test assignment cleared |
| Real managed ManageEngine deployment of current executable | Not performed |
| Driver-first installation on driver-free hardware | Not performed |
| Public publisher-signing and post-sign rebuild | No local publisher signing identity available; script prepared and PE-code-preservation verification implemented |

These are evidence boundaries, not software features to imitate or bypass. No destructive change to the working Dell driver, reboot or Windows display topology occurred during this qualification.
