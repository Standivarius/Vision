# Doxa enterprise ManageEngine pilot — ASUS Endpoint Central agent installed, package staged

**25 October 2026, ~07:12 Europe/Bucharest.** Vision Doxa software-only pilot (GitHub #75, draft PR #78). This checkpoint reports live evidence from **ASUS-DESKTOP-HOME** via the AiGov Local Dev host bridge, with no changes to the AiGov repository and no Vision main-branch modification.

## Authorised scope and privacy

One ASUS Windows 11 Pro agent, separately from MARIUS-DELL's existing Intune pilot. Do not enrol other computers, modify existing Doxa/Silicon Motion drivers, initiate device reboots or broadly enable patching, remote control or unrelated security configurations. Owner approved admin UAC for a Zoho-signed endpoint agent.

The vendor-generated enrollment/download URL contained a sensitive key and is **not** reproduced or committed. Tenant bootstrap JSON, agent certificates, MSI installers and logs remain local to ASUS user staging, and MUST NOT be committed or posted.

## Actual Endpoint Central agent installation — PASS

- User downloaded vendor ZIP `DefaultRemoteOffice.zip` into ASUS's OneDrive-backed Downloads location. It contained `DCAgentServerInfo.json`, `UEMSAgent.msi`, `UEMSAgent.mst`, vendor helper EXEs, installer batch, empty computer list, and root certificate.
- Embedded **UEMSAgent.msi** SHA-256 **CE0ACE07D9BF63467EDF088411BEC7DC3730F56A6A90D6E41354B08D6993FB91**, Windows Authenticode **Valid**, signer **ZOHO Corporation Private Limited**; both helper EXEs also valid Zoho signatures.
- Earlier webpage-linked standalone PE was **unsigned** and never executed. Signed MSI used instead.
- First ASUS pilot launcher and revised Windows-Temp logging launcher both returned MSI **1622** (optional verbose log failed to open), no agent installed. No Windows policy/global execution-policy changes made.
- Created ASUS-only **v2** launcher to verify exact vendor MSI hash and signature, refuse duplicate service, explicitly suppress reboots, preflight a dedicated writable ProgramData logging folder, and on 1622 allow only one bounded fallback without optional logging.
- Owner right-clicked **Install-ManageEngine-ASUS-Pilot-v2.cmd** on ASUS desktop, approved UAC. Independently read local record:
  `STATUS=AGENT_PRESENT`, `MSI_EXIT=0`, `INITIAL_MSI_EXIT=0`, `LOGGING_MODE=preflight-writable-verbose`, `HOST=ASUS-DESKTOP-HO`, UTC `2026-10-25T05:01:48.2419399Z`. Installer log saved under `C:\ProgramData\Doxa-ASUS-ManageEngine-Logs\ASUS-MSI-20261025-070129.log`, ~828 KB.
- Independently checked Windows services: **ManageEngine UEMS - Agent Running/Automatic**, **ManageEngine UEMS - Agent Health Checker Running/Automatic**, **ManageEngine Unified Endpoint Security - Agent Running/Automatic**. Remote Control service present but Stopped/Manual. Agent process `dcagentservice` running. Agent directory `C:\Program Files (x86)\ManageEngine\UEMS_Agent` exists.
- Agent client log files updated live around 07:05; selected upload/computer logs include HTTP 200 responses. This indicates communication, **not yet independent server-console proof of device enrolment and correct tenant assignment**.
- No reboot pending per Windows Update and CBS checks. Existing AiGov workloads and repo not modified.

## Exact Doxa artifact delivered to ASUS — PASS

Original Dell artifact `C:\wt\doxa-installer-clean-pr-20261024\artifacts\releases\managed\Doxa-Managed-AppOnly-Pilot-20261024-201607.zip` transferred **byte-for-byte** through the two authorized local host bridges; SHA-256 of ASUS destination:

- Outer ZIP: **4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425**, **42,670 bytes**.
- Inner `DoxaPilot.ps1`: **A0C32CF6E961E9CD2BF39A389E4338C28288DC8C9B82D2014AA94FFE495D4F64**, **4,880 bytes**.
- Inner `DoxaSetupPayload.zip`: **E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50**, **42,841 bytes**.

ASUS path: `C:\Users\User\AppData\Local\DoxaPilot-Staging\Doxa-Managed-Ready`. The exact two inner deployment files are extracted beside the outer archive, ready for upload to Endpoint Central; they were **not executed** as Install.

ASUS baseline `DoxaPilot.ps1 -Action Detect` returned **exit 1** (absent) and `C:\Program Files\Standivarius\DoxaSetup` absent. No Doxa vendor driver installed or altered. Software-only host; physical Doxa display lifecycle remains separately blocked.

## Next gates — NOT YET PASS

1. Verify **ASUS-DESKTOP-HOME** appears as exactly intended endpoint in Endpoint Central Cloud console. Protect tenant: scope one endpoint, do not turn on automatic patching/reboot policies, avoid unrelated configurations. If separate browser sign-in is required, use owner's authenticated session or request explicit TinyFish browser-profile sign-in; do not copy auth cookies/keys.
2. Follow `app/packaging/doxa-setup/enterprise-intune-pilot/MANAGEENGINE-REAL-PILOT-RUNBOOK.md`. Create Computer-level Custom Script configuration using **DoxaPilot.ps1**, Script Arguments **-Action Install**, ZIP dependency **DoxaSetupPayload.zip**, **System user**, **Once**, success exit 0, destination ASUS only; console logging. Protect script execution policy; no GPO/WDAC bypass.
3. Validate managed install exit 0, Detect exit 0, app-only files, no reboot; repeat via distinct once-only managed config (idempotency), then managed `-Action Uninstall`, verify Detect exit 1. Negative foreign-file refusal only under separate recoverable staging scope; avoid destructive tests on live AiGov workstation.
4. Only after managed install and removal, clean up the management agent using Endpoint Central-supported uninstallation and verify AiGov/dev environment, reboot state and connectivity.

## Current status

**ManageEngine agent actual installed and healthy: PASS**. Frozen deployment distributable verified on both computers: PASS. **Endpoint Central console device listing: NOT CONFIRMED**. **Real agent-delivered Doxa installation/detection/uninstallation: NOT RUN**. No claims about broad production readiness.

Official reference: https://www.manageengine.com/eu/products/desktop-central/help/configuration-management/executing_custom_scripts-computer.html
