# Doxa Setup — second managed platform (ManageEngine Endpoint Central) readiness

Date: 25 October 2026. Project: Vision. Isolated Doxa clean PR #78.

## Task / owner approval
Proceed with second independent enterprise managed-app deployment pilot while Intune's first failed-install retry awaits its normal evaluation window. No vendor driver MSI, physical display changes, production device enrollment or organisation-wide targeting. The goal is an actual **ManageEngine agent-managed SYSTEM** install/detect/repeat/uninstall with management-console evidence, not another local-only lifecycle pass.

## Existing distribution artifact — independent revalidation PASS
- `artifacts/releases/managed/Doxa-Managed-AppOnly-Pilot-20261024-201607.zip`
- SHA-256 `4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425`.
- Script `DoxaPilot.ps1` SHA-256 `A0C32CF6E961E9CD2BF39A389E4338C28288DC8C9B82D2014AA94FFE495D4F64`.
- Inner `DoxaSetupPayload.zip` SHA-256 `E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50`.
- Independent `Verify-DoxaManageEnginePackage.py` checks full pinned ZIP, two exact entries (not just names from repo), inner payload hash, and invokes `Test-DoxaPilot.py --script <extracted script> --payload <extracted ZIP>`, so all **ten real local lifecycle cases execute from the actual managed distribution files** in a disposable temp directory.
- First run: `PACKAGE_VERIFIED`, `local_lifecycle=PASS`, `local_lifecycle_steps=10`, `driver_msi_in_package=false`, `actual_agent_deployment=NOT_PERFORMED`. A repeated real verification run also PASS.
- `Test-DoxaManageEnginePackage.py`: **4/4 PASS** including altered archive rejection, path-traversal extra entry refusal (with outer digest controlled), altered inner payload refusal and positive checksum validation.
- Source-level `Test-DoxaPilot.py` supports optional `--script` path to exercise extracted code; existing default behavior for both builders preserved. No Doxa installation under Program Files.

## Host/test endpoint inventory — blocked, not simulated
- Desktop Commander online endpoints: **only MARIUS-DELL**, already temporary enrolled in DMR Intune, with working 3 Doxa panels and Vision developer activity. ASUS-DESKTOP-HOME is registered but **offline** and not certified disposable.
- Dell Windows 11 Pro, 16 GB installed RAM, ~**1.5 GB free RAM**, 248 GB free disk. Hyper-V Virtual Machine Management service running but listing VMs or virtual switches returns **permission denied** under non-elevated remote bridge. No Windows ISO/VHD visible in initial candidate locations. Building a VM on this low-memory protected active host could disrupt the concurrent Intune/Doxa display testing and should not be attempted.
- No ManageEngine agent service observed on Dell; installing one there would breach isolated-endpoint test design. No separate enrolment or ManageEngine cloud console authenticated/connected in this session. No management account provisioned, agent installed or deployment job submitted.
- Product feature verified via official ManageEngine docs: Endpoint Central Free supports up to 25 endpoints; computer-level Custom Script configurations support `System user`, once-only execution, ZIP dependency files and per-target reporting. Verified effective October 2026, see runbook.
- Preferred route: **Endpoint Central Computer Configuration → Custom Script**, upload frozen script plus adjacent payload ZIP as dependency, System user, Frequency Once, 0 = success, target a **single** expressly authorised disposable Windows endpoint; capture console and agent logs. Do not use an unapproved process-scoped bypass of organisation-defined script controls.

## What remains
1. Supply/connect a **separate disposable Windows endpoint** and grant needed Windows VM/console administrator permissions. Set up Endpoint Central Free Cloud tenant if not available. These require user/provider account actions outside current non-admin tooling; no unsupported anonymous enrollment is attempted.
2. Agent enrollment and console record; snapshot baseline; safe one-device machine-level Install.
3. Independent Detect 0 + nonempty output, repeat Install idempotence, managed Uninstall to absent, foreign-file refusal on restored disposable VM, policy/permission/offline observations; server/device log and no changes to display driver.
4. Clean up standalone test management and restore disposable endpoint.

The current Intune test on Dell remains **unchanged**. Its actual retry remains pending. Do not claim second platform PASS until an actual ManageEngine agent executes and reports the package.

## Files
- `app/packaging/doxa-setup/enterprise-intune-pilot/MANAGEENGINE-REAL-PILOT-RUNBOOK.md`
- `app/packaging/doxa-setup/enterprise-intune-pilot/Verify-DoxaManageEnginePackage.py`
- `app/packaging/doxa-setup/enterprise-intune-pilot/Test-DoxaManageEnginePackage.py`
- `app/packaging/doxa-setup/enterprise-intune-pilot/Test-DoxaPilot.py` (optional extracted-script parameter)

## Official references
- https://www.manageengine.com/eu/products/desktop-central/help/configuration-management/executing_custom_scripts-computer.html
- https://www.manageengine.com/products/desktop-central/help/software-deployment/powershell-script-as-a-package.html
- https://www.manageengine.com/products/desktop-central/edition-comparison-matrix.html
