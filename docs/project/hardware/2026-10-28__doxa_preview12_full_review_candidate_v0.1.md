# Doxa Setup Preview.12 — installer and enterprise reviewer dossier v0.1
**Date:** 28 October 2026. **Status:** PRIVATE ENGINEERING REVIEW CANDIDATE, NOT A SIGNED CUSTOMER RELEASE.
**Source:** branch doxa/review-package-20261028 based on Preview.12 commit 116454458edc285ccd1279f5b9fa11c95d42e63b. Parent PR #105, stacked on #104 / #103 / #78.

## Distribution inventory
1. Personal interactive ZIP: personal/Standivarius-Doxa-Setup-personal-preview-*.zip. Windows launcher, EN/RO, 20 hashed source files, 23 total entries, no OEM installer.
2. Intune Win32: intune/doxa-intune-app-only-*/DoxaPilot.intunewin with Microsoft-signed Win32 Content Prep Tool v1.8.7; app-only SYSTEM deployment and version-aware Detect.
3. ManageEngine: manageengine/Doxa-Managed-AppOnly-Pilot-*.zip; exactly DoxaPilot.ps1 and DoxaSetupPayload.zip, for agent System User with adjacent dependency.
Build/test JSON and a checksummed master manifest accompany the files; all derive from the same Preview.12 source. Intune encryption gives a distinct package SHA256.

## Scope and actual user journey
- One bilingual consent-gated WinForms journey; three LEFT tabs and persistent right-hand Doxa Help, stacking beneath on narrow windows.
- Detect Doxa: centre-panel upper female USB-C is POWER; lower is DATA/SIGNAL; single Check connection; three independent PnP identities 2/3/4. Green ticks DO NOT establish extended desktop/topology or genuine power diagnosis.
- Set up screens: 2–3–4 physically above laptop 1 (laptop beneath screen 3); Windows Identify/Extend and one Display Settings control. No silent Windows geometry changes.
- Install signed driver: CONDITIONAL READ-ONLY TROUBLESHOOTING. Preview.12 does not perform a real elevated driver installation.
- Local offline assistance is deterministic. Cloud AI is optional and user-controlled; the managed SYSTEM installation makes no remote AI request.

## Managed deployment contract
- Install: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Install
- Detect: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Detect -ExpectedVersion 0.4.0-preview.12
- Uninstall: powershell.exe -NoProfile -NonInteractive -File .\DoxaPilot.ps1 -Action Uninstall
- Intune: install as System, use 64-bit custom detection requiring exit 0 AND nonempty stdout; restrict any new assignment to authorised single test device. Do NOT reuse historical app assignment IDs.
- ManageEngine: Computer Configuration / Custom Script, repository DoxaPilot.ps1 plus DoxaSetupPayload.zip dependency, Run As System User, exactly one approved computer, once only, no automatic retries.
- Valid different version: ordinary Install refuses; explicit managed Upgrade may be used only after its versioned restore tests. Altered or foreign files must block unsafe removal.

## Evidence boundaries
- Local evidence of THIS candidate: artifacts/releases/review-20261028/personal-test.json, manageengine-local-tests.json, intune-build.json, ui-layout-test.txt. An absent/failed file is not a pass.
- Historical real Intune Dell pilot: docs/project/hardware/2026-10-25__doxa_intune_install_success_uninstall_assigned_v0.1.md. An EARLIER app-only version reached SYSTEM Install/Detect PASS. Uninstall was assigned, not yet completed in that report.
- Historical real ManageEngine ASUS pilot: docs/project/hardware/2026-10-25__doxa_manageengine_asus_real_agent_lifecycle_results_v0.1.md. An EARLIER app-only version had actual agent SYSTEM Install/Repeat/Uninstall PASS; the agent was decommissioned afterwards. ASUS currently offline through Desktop Commander.
- Historical managed results do NOT certify current Preview.12 distribution. Do not claim live Intune or ManageEngine PASS without exact package/device/agent logs/installation and uninstall confirmation.
- Owner visual acceptance (100/125/150% DPI, keyboard/screen reader), first-time driver-free host and full 4-desktop interactive health remain outstanding.

## Independent reviewer work order
Review all three distributed artefacts and their exact code, not only screenshots. Report P0/P1/P2, file/line, reproduction, observed evidence, impact, minimal correction:
1. Confirm archive integrity, hashes/source correspondence, no credentials, unsigned vendor payload, unsafe executable or SYSTEM cloud calls.
2. Review EN/RO consent, local-data notice, online AI policy, retention/privacy claims, offline behaviour and in-flight cancellation.
3. Audit driver-state conditions; make sure read-only driver tab does not promise a real install; verify supplier-signature boundaries and privileged recovery risks.
4. Challenge PnP ticks versus actual Windows extended-desktop state and physical port/cable claims.
5. Inspect visual hierarchy, DPI/keyboard/screen-reader accessibility, persistent Help and four-screen drawing.
6. Unpack Intune package; check security, version-pinned detection, install/repeat/uninstall/upgrade, return codes, SYSTEM execution and narrow assignment.
7. Unpack ManageEngine ZIP; test dependency staging, System User execution, idempotence, tamper refusal, reinstall and safe removal.
8. Distinguish local fixture tests from genuine Intune agent and ManageEngine agent results for THIS package.
9. Provide three separate verdicts: reviewable engineering package, genuine full driver installer, signed customer release.

## Non-negotiable release blockers
- Written Silicon Motion/OEM redistribution rights before bundling OEM driver; verified approved official driver and recoverable driver-free first-time install.
- Public publisher code signing, trusted installer, and rollback/recovery independently verified on a recoverable test PC.
- Actual four independent extended desktops, pointer/click/typing, reconnect, per-user graphics acceptance; safe revert from layout changes.
- Fresh package managed deployment on test-only Intune and ManageEngine targets with agent-side installation, detection and uninstall evidence.
- Final legal privacy/Cloudflare processing terms and owner visual acceptance.

Never merge draft PRs, publish customer-ready package, alter working Dell driver/topology or label app-only managed success as OEM driver installation.
