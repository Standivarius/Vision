# Doxa: four independent Windows displays — read-only validation and driver qualification checkpoint
**Date:** 16 October 2026, MARIUS-DELL, Vision \`master\` (HEAD \`286422d\` at observation)
**Status:** **G1 Windows desktop extension PASS** on one observed Doxa unit; **enterprise MSI qualification G2 remains open**. No installation, reboot, driver replacement, user-session display changes or firmware modification.

## Live evidence and tested fact

The owner stated all four screens are working. A read-only Windows Forms \`System.Windows.Forms.Screen.AllScreens\` enumeration in the same host session returned **four distinct active desktop sources**:

| Source | Primary | Desktop bounds returned by PowerShell (DPI-virtualised, not native-pixel proof) |
|---|---|---|
| \`\\.\DISPLAY1\` | Yes | x=0, y=0, 1280×720 |
| \`\\.\DISPLAY10\` | No | x=-1278, y=-725, 1280×720 |
| \`\\.\DISPLAY11\` | No | x=2, y=-720, 1280×720 |
| \`\\.\DISPLAY12\` | No | x=1282, y=-709, 1280×720 |

Unlike the earlier 16 October observation where source 3 and 4 were duplicated, **DISPLAY12 is now separately active**. All four sources are distinct. Windows Forms process DPI virtualization means the bounds here are *not* a physical pixel-resolution or EDID/refresh verification; do not claim each display is native 1280×720.

Separately, Windows PnP recorded:
- \`SMI770 USB Display\`, SiliconMotion driver **4.7.6.0**, INF \`oem101.inf\`, **signed** by Microsoft Windows Hardware Compatibility Publisher.
- Hardware family \`USB\VID_090C&PID_770A\` (prefix only; do not publish or copy device serials).
- Laptop integrated display and three distinct connected Doxa monitor devices **(L)**, **(T)**, **(R)**.
- Windows 11 Pro build 26300.
- Installed driver should **not be reinstalled** solely to qualify desktop extension.

The live read-only script \`app/packaging/doxa-setup/Get-DoxaDriverState.ps1\` was corrected to measure desktop source counts from **live Windows enumeration**, rather than hard-coding \`independent_windows_desktops_verified=false\`; fixture-based snapshots must still always report false. Current live output:
- \`status=signed_driver_present_monitors_detected\`
- \`active_windows_desktop_count=4\`
- \`independent_windows_desktops_verified=true\`
- \`package_approved_for_distribution=false\`
- \`profile_qualification=observed_not_oem_approved\`

The read-only test \`tests/Test-DoxaDriverReadOnly.ps1\` now verifies live source count and preserved negative fixtures. **All six read-only checks passed**: signed-complete, unsigned-rejected, missing-driver, missing-Doxa-panel, live source count and live MSI dry-run. These check read-only behaviour, not signed package installation or interactive graphics health.

## Vendor package research: what is actually published

Silicon Motion's official [SM77x Windows download page](https://www.siliconmotion.com/downloads/SM770-drivers.html) lists:
- Windows 10/11 standard driver **V4.7 R06-8001**, published **24 September 2026**.
- Windows 10/11 **driver MSI V4.7 R06**, published **22 June 2026**.
- The two release identifiers **do not prove byte-for-byte driver equivalence** with installed \`4.7.6.0\`; confirm actual INF/SYS inside the MSI, package hash and catalog/version before authorising deployment.
- Vendor [MSI Group Policy walkthrough](https://www.siliconmotion.com/downloads/video/SMI_Windows_SM770_MSI_File_User_Manual.pdf) confirms an IT-oriented packaging route; it is not a completed enterprise security qualification or Doxa redistribution licence.

## Qualified today vs not qualified

**Qualified for this particular Dell:** one SMI770 device, Microsoft-signed \`4.7.6.0\`, physically enumerated L/T/R panels plus laptop, four independently active Windows desktop sources. No Windows security policy bypass was used.

**Still requiring proof for product / enterprise:** exact vendor MSI file, SHA-256 and Authenticode publisher; compatibility with this hardware ID/revision and supported Windows versions/HVCI; silent install/repair/remove/upgrade/rollback; packaging/redistribution licence/OEM approval; Intune/ConfigMgr/GPO and WDAC/App Control behaviour; attended WGC cross-adapter graphics and pointer/caret follow on four displays; genuine lower-spec laptop; unplug/reconnect/reboot behaviour when approved; signed Doxa end-user package/release.

The manifest \`app/packaging/doxa-setup/profiles/vendor-msi-approval.TEMPLATE.json\` remains **NOT_APPROVED**. The deployment wrapper defaults to read-only audit and gates \`-Apply\` behind approved vendor package hash, signer and explicit IT authorisation. Do not silently elevate or download/install replacement graphics drivers on this working machine.

## Next safe development step

1. Obtain **exact official MSI bits** via supplier/owner distribution path, document file hash, Authenticode chain, actual embedded driver INF/version and OEM redistribution rights.
2. In isolated controlled Windows test environment, exercise \`Deploy-DoxaDriverPackage.ps1\` audit and signed silent MSI install (with authorised IT), log, no automatic reboot, status codes; verify four independent desktops and Doxa interactive graphics after install. Negative-policy cases required.
3. Only after clean deployment and approval update pin manifest to \`approved\`, not before. Keep Vision runtime independent of driver.
4. Execute separate four-screen WGC/D3D11 application qualification with selected disposable tasks and user-attended tests; do not assume active Windows desktops prove Vision capture/presentation.

**This checkpoint is suitable for incoming-chat handover.**
