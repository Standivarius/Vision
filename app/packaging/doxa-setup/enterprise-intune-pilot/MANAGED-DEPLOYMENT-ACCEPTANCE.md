# Doxa Setup — app-only pilot on two managed Windows platforms

**25 October 2026 live-state addendum:** The 24 October engineering baseline below predates owner's approval of temporary MARIUS-DELL Intune enrollment. Dell is now enrolled, a Dell-only Intune app is published/assigned and its first SYSTEM run failed due PowerShell policy; corrected commands are live, installation retry remains pending. The original prohibition on enrolling Dell below was superseded by explicit owner authorisation **only for Intune**, not ManageEngine. The separate ManageEngine agent-managed test has not run: see [current pilot runbook](MANAGEENGINE-REAL-PILOT-RUNBOOK.md). Keep other 24 October historical instructions as original context, not current deployment state.

**Engineering baseline: 24 October 2026.** Unapproved, unsigned **app-only** test payload. No Silicon Motion MSI, INF, CAT or SYS is bundled; no driver, firmware or display configuration is changed. Do not deploy to production devices.

## Shared installer contract

The same two deployable files are used in both environments: `DoxaPilot.ps1` and `DoxaSetupPayload.zip` (16 approved source files, generated launcher/readme and manifest, with SHA-256 verification). The script's `-Action` controls `Install`, `Detect`, or `Uninstall`. The optional `-TargetRoot` may point to an isolated disposable folder for tests; normal managed deployment defaults to the machine-wide Program Files directory.

- Install: `powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Install`
- Detect: `powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Detect`
- Remove: `powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Uninstall`
- Detection: exit `0` **and** a nonempty `DETECTED:DoxaSetupPilot` stdout mean installed. Exit `1` means not detected. Extra, missing or altered files invalidate the app payload.
- Installation is idempotent. Uninstall only deletes the exact recognised payload: if foreign or modified files are found, return `33` and preserve the directory for IT investigation. Do not bypass organisational PowerShell, WDAC or AppLocker policy to run this unsigned pilot.
- Normal application install is offline and completely silent, with no AI prompt in the machine/SYSTEM session. Any employee AI notice/choice is a *separate* interactive user-session journey. IT may independently deny AI using `HKLM\SOFTWARE\Policies\Standivarius\DoxaSetup\DisableCloudAI` DWORD `1`.

## Intune — first independent managed qualification (DXI-20)

**Authentication preflight (no new Microsoft account):** On MARIUS-DELL, run `Check-DoxaIntuneAccess.ps1` without switches first. It derives the existing DMR Ergonomics workplace tenant identifier from Windows and verifies Microsoft sign-in metadata without asking for credentials or modifying the tenant. Once the owner is present to sign in, run `Check-DoxaIntuneAccess.ps1 -Authenticate`. Enter the printed short code only at Microsoft's official device-login URL and review the two delegated **read-only** Intune Graph permissions: `DeviceManagementManagedDevices.Read.All` and `DeviceManagementApps.Read.All`. Admin consent may be required. The script reads the first apps page and first 100 managed devices, outputs **only the current Dell's enrollment summary**, never prints other device identities, does not save tokens and performs no Graph writes. Failure to find Dell on the first page is inconclusive when additional pages exist; confirm through the Intune console before assigning the app. The earlier apps-read permission succeeded but the general `/deviceManagement` endpoint returned HTTP 403; the updated device-read check requires a new delegated authorisation.

**Endpoint isolation:** Dell is workplace registered to DMR Ergonomics, but not enrolled in Intune. It is the active Vision development machine; do not Entra-join or Intune-enrol it for the pilot. Use a separate persistent, disposable Windows evaluation VM or dedicated spare Windows machine. The current remote developer session has medium integrity, and Hyper-V Manager access returned access denied; creating/inspecting a VM needs Windows elevation. No VM created, system feature enabled or reboot performed.

1. Generate `DoxaPilot.intunewin` with `Build-DoxaIntunePilot.ps1 -ContentPrepTool <path-to-authenticode-valid-Microsoft-IntuneWinAppUtil.exe>`. The builder performs local extraction and 10 app-only lifecycle tests; the content-prep tool must be signed by Microsoft.
2. In a disposable test tenant/device group, add a **Win32 application** with that `.intunewin`. Set machine install context **System** and the above silent Install/Uninstall commands. Do not assign to the working Dell or any production group.
3. Use an uploaded *custom detection script* based on `DoxaPilot.ps1 -Action Detect`; 64-bit PowerShell where available, and **do not run using the logged-on user's credentials**. Intune requires exit 0 plus nonempty stdout, with no stderr.
4. Test: absent -> install -> detect -> repeat install -> detect -> uninstall -> absent. Collect app/device status, Company Portal status if applicable, Intune Management Extension logs, package/version, local exit codes and timestamps. Verify no prompt/UAC, network/AI call, reboot, driver or display state changes.
5. For an intentionally altered directory verify deterministic failure and support escalation; do not automatically delete unknown employee/IT files. Later test IT-managed update/rollback with a *versioned, signed* package.

## ManageEngine Endpoint Central — second independent managed qualification (DXI-23)

1. Generate `Doxa-Managed-AppOnly-Pilot-*.zip` with `Build-DoxaManagedPilot.ps1`. Verify ZIP hash, unzip to a controlled deployment repository and preserve both files together. This generic archive is **not** an Intune `.intunewin`.
2. Use Endpoint Central's **Windows PowerShell software package** or **Computer Configuration custom script with ZIP dependencies** to stage both files on a disposable enrolled Windows endpoint. Ensure the script's working directory includes `DoxaSetupPayload.zip`. Use a machine/System run-as context; no user interaction.
3. Configure the same Install/Detect/Uninstall commands with explicit `-File` path. Use computer-targeted deployment, IT-approved scheduling and retries, and existing Endpoint Central console reporting. Avoid execution-policy bypass or automatic privilege changes.
4. Record a separate real end-to-end run and management-console evidence: machine agent identity, deployment package/hash, installation and detection exit codes, idempotent repeat, uninstall, unexpected-content refusal, timeout/failure logs and absence of physical driver changes.
5. If this platform's packaging UI cannot retain the adjacent ZIP dependency or report the correct detection result, record the limitation and select its approved custom-script-with-dependencies route; do not claim a PASS without actual agent evidence.

## Shared release gates (still OPEN)

- **DXI-10/11/12:** written OEM redistribution permission, inspected vendor MSI and real recoverable physical Doxa driver install/upgrade/rollback tests on a separate Windows machine.
- **DXI-16/28:** organisation identity verification and commercial Windows code signing; this source-script preview is deliberately unsigned.
- **DXI-26/27:** final data protection, correct legal notice, policy, user consent and live Cloudflare customer authentication; local tests and acknowledgement booleans cannot prove legal consent.
- **DXI-17/22/23/25:** attended four-display physical user-session evidence, **real** Intune and ManageEngine installations with logs, and release go/no-go. Temporary-folder tests, source integrity and vendor documentation are not managed-deployment proof.

Sources verified 24 October 2026:
- Microsoft Intune Win32: https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
- ManageEngine script package: https://www.manageengine.com/products/desktop-central/help/software-deployment/powershell-script-as-a-package.html
- ManageEngine Windows packages: https://www.manageengine.com/products/desktop-central/help/software-deployment/create-software-packages-windows.html
- ManageEngine custom script with dependency ZIP: https://www.manageengine.com/eu/products/desktop-central/help/configuration-management/executing_custom_scripts-computer.html
