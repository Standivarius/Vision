# Doxa Setup — ManageEngine Endpoint Central second enterprise test

**Purpose:** Qualify the **app-only**, unsigned Doxa Setup pilot under a second real endpoint manager (DXI-23). This is a parallel test to Intune DXI-20, NOT a replacement. Status on 25 October 2026: **package locally verified; no ManageEngine agent-managed deployment performed**.

## Exact frozen pilot artifact

- Local file (generated, excluded from Git):
  `C:\wt\doxa-installer-clean-pr-20261024\artifacts\releases\managed\Doxa-Managed-AppOnly-Pilot-20261024-201607.zip`
- SHA-256 **4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425**.
- Contents: exactly `DoxaPilot.ps1` (SHA256 `A0C32CF6E961E9CD2BF39A389E4338C28288DC8C9B82D2014AA94FFE495D4F64`) and `DoxaSetupPayload.zip` (SHA256 `E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50`).
- Payload: 16 source files, two generated files and manifest; all hashes verified. **No vendor MSI, INF, SYS, CAT, unsigned driver installer, secrets, cloud calls or AI dependency at install time**.
- Verification on Dell: `python app\packaging\doxa-setup\enterprise-intune-pilot\Verify-DoxaManageEnginePackage.py` extracts the actual frozen distribution package, confirms outer and inner hashes, and runs 10 Install / Detect / repeat / foreign-file-refusal / Uninstall lifecycle cases **against the extracted script** in a disposable directory. Not real agent evidence.

## Test platform — prerequisite (do not skip)
- Use **one disposable Windows 11 Pro/Enterprise VM or spare physical test PC** with admin authorization and ability to recover to the initial snapshot. Avoid production devices and the working MARIUS-DELL while its Intune pilot is unresolved.
- On 25 October, Remote Desktop Commander exposes only MARIUS-DELL (online) and ASUS-DESKTOP-HOME (offline). No separate VM is remotely accessible. Hyper-V VM listing on Dell is forbidden from non-elevated remote shell, and Dell has only ~1.5 GiB RAM free; **do not create a VM or install Endpoint Central on Dell**.
- Set up ManageEngine Endpoint Central **Free (up to 25 endpoints)**; cloud-based control avoids hosting a second management server on Dell. Owner/administrator must establish the console/tenant and provision the disposable endpoint. Agent enrollment must be explicitly approved for only that endpoint.
- Record console URL, tenant (without access tokens), unique **test endpoint hostname and management agent identity**, Windows version, baseline installation/detection (absent), and restore checkpoint. No cross-tenant or broader deployment.
- Use no customer credentials/API tokens in repository or evidence bundles.

## Preferred method — official Computer Configuration, Custom Script + dependency ZIP

The official custom-script route supports Windows `ps1`, `System user`, once-only computer targeting, dependency ZIPs and per-endpoint exit-code/remarks reporting. It avoids packaging a new EXE wrapper just for the pilot.

1. Extract the frozen outer `Doxa-Managed-AppOnly-Pilot-*.zip` on the IT console machine, **not onto the test target**; verify both inner SHA-256 values. Keep the two files separately for upload.
2. Endpoint Central console: **Configurations → Add Configurations → Windows Configuration → Custom Script → Computer Configuration**.
3. Add `DoxaPilot.ps1` to the **Script Repository**; attach `DoxaSetupPayload.zip` under **Dependency Files**. Do not attach the outer ZIP as a dependency or change filenames. The app script defaults its payload path to `$PSScriptRoot\DoxaSetupPayload.zip`; the dependency must arrive in the same working directory.
4. Name: `Doxa app-only installer — ManageEngine one-device pilot`; `Script Arguments` = `-Action Install`. Choose `Run As: System user`, `Frequency: Once`, expected success code **0 only**. Enable logging and retain remarks. Computer target **only the unique disposable endpoint**; do not target All Computers/users. Suppress any reboot (pilot requires none), request no interactive/UAC prompt and do not enable automatic recurring retries before observing first result.
5. This script is **unsigned** and is for an isolated IT-approved test only. Confirm applicable machine PowerShell execution policy, AppLocker and WDAC. On a test machine where policy forbids unsigned scripts, record the block as a policy PASS, **do not bypass GPO/WDAC/AppLocker or weaken machine security**. ManageEngine's separate software-package guide illustrates `-ExecutionPolicy RemoteSigned`, but that is not permission to override an organisation's restriction.
6. In a normal permissive disposable test machine, run once, capture status, Windows SYSTEM context, exit code/remarks, absence of UAC/reboot/AI/network call. Independently run `DoxaPilot.ps1 -Action Detect` in the managed machine context: expect stdout `DETECTED:DoxaSetupPilot` and code 0. Check `%ProgramFiles%\Standivarius\DoxaSetup` for all expected files. On first fail, collect agent `dcconfigaccess.log` and product logs, preserving failure evidence.
7. Repeat the **same** install once as a separate computer-level configuration (same script, ZIP dependency) and verify `ALREADY_INSTALLED:DoxaSetupPilot`, code 0. Do not change the package or create a new application installation folder.

## Managed removal and negative case

8. For management-controlled removal, create a one-time **computer-level** Custom Script configuration using `DoxaPilot.ps1`, `Script Arguments = -Action Uninstall`, Run As System, target only the *same* endpoint. The script does not require the ZIP for uninstall; verify exit 0 and stdout `REMOVED:DoxaSetupPilot`, installation directory absent and Detect exit 1.
9. In the separate resettable test VM only: reinstall from the package, create an extra harmless foreign file in that Doxa **test installation directory**, request the IT-controlled removal again; verify exit **33**, preserved foreign file and intact package (not a PASS uninstall). Snapshot/restore after collecting evidence; never stage this negative test on Dell or a working customer's endpoint.
10. Verify no change to vendor driver/PnP display profile, no reboot, Windows machine policy unchanged, no cloud-AI execution. Capture actual Endpoint Central console device/status records (redact account identifiers), script execution exit results, `dcconfigaccess.log`, Windows events and a pre/post Doxa hardware report if a Doxa device is attached. After all gates, remove test agent/management using Endpoint Central supported procedure, then revert the disposable VM.

## Acceptance ledger (all actual Endpoint Central agent rows initially OPEN)

| Gate | Evidence | Status as of 25 Oct |
|---|---|---|
| Package zip integrity & 10 extracted local lifecycle cases | frozen SHA256, unit checks, stdout | **LOCAL PASS** |
| Disposable real Windows managed agent enrolled | unique test endpoint, console record, baseline | **BLOCKED: endpoint not available** |
| Remote SYSTEM install & no UAC/reboot | console delivery outcome, agent log, exit 0 | NOT RUN |
| Agent-side detection | code 0 + nonempty DETECTED stdout | NOT RUN |
| Idempotent second managed install | `ALREADY_INSTALLED`, exit 0 | NOT RUN |
| Managed uninstall to absent | `REMOVED`, exit 0, Detect exit 1 | NOT RUN |
| Foreign-file refusal | exit 33; file preserved in disposable VM | NOT RUN |
| Restricted-user / app-control/offline | policy preserving refusal, no AI network needed | NOT RUN |
| Hardware/driver unchanged | pre/post vendor driver and monitors | NOT RUN |
| Cleanup of separate test agent/endpoint | console record and restored VM baseline | NOT RUN |

## Avoid misleading claims

- Local tests, Graph app publication and Intune client downloads do not qualify a ManageEngine deployment.
- The service may itself need the business's proxy/firewall permissions; distinguish **online management delivery** from Doxa's **offline installation runtime**.
- The preview is not signed for public production, and OEM driver redistribution permission remains pending. Real physical driver upgrade/reconnect/rollback belongs to a **different** recoverable-host gate.
- Do **not** install Endpoint Central agent on MARIUS-DELL in parallel with Intune without separate reviewed plan and protected snapshot.

### Official references checked 25 Oct 2026
- [Endpoint Central custom scripts for Computer Configuration (9 Oct 2026)](https://www.manageengine.com/eu/products/desktop-central/help/configuration-management/executing_custom_scripts-computer.html)
- [Endpoint Central Windows software deployment](https://www.manageengine.com/products/desktop-central/help/software-deployment/software-deployment-windows.html)
- [Endpoint Central Free edition comparison](https://www.manageengine.com/products/desktop-central/edition-comparison-matrix.html)
