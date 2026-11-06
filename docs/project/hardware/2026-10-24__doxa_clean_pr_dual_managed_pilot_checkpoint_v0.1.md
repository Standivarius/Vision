# Doxa clean PR and dual managed app-only pilot — checkpoint v0.1

**Date:** 24 October 2026
**Branch:** `doxa/installer-clean-pr-20261024` (GitHub draft PR #78; base `origin/master`).
**Scope:** DXI-08 clean integration, DXI-26/27 development AI acknowledgement, DXI-20/23 local package preparation.
**Disposition:** LOCAL VERIFIED only; managed deployment, customer legal compliance and physical MSI release NOT qualified.

## Verified changes
1. Clean draft PR #78 uses two Doxa-only integration commits on GitHub remote master, with 51 changed paths. Previous broad PR #77 remains open and untouched; no merge into local dirty master.
2. Personal remote AI client sends an explicit development disclosure version (`development-v0.1`) and `user_enabled_optional_ai=true` only when its caller supplies the deliberate opt-in switch. The server-side Worker rejects signed requests with absent/false/outdated acknowledgement before performing a rate-limited model call. This is **not** independent proof of a GDPR-valid, notice-versioned consent record: a client assertion can be forged by a caller with legitimate device signing rights. Production enrolment and legal notice remain pending.
3. Added `Build-DoxaManagedPilot.ps1`: an independent local vendor-neutral archive for ManageEngine deployments with exactly `DoxaPilot.ps1` and the same app-only source-built `DoxaSetupPayload.zip`. Personal extracted acceptance and all 10 temporary-folder install/detect/repeat/tamper/uninstall checks run automatically.
4. `enterprise-intune-pilot/MANAGED-DEPLOYMENT-ACCEPTANCE.md` records parallel testing instructions and the evidence needed from real Intune and ManageEngine enrolled devices. The machine/SYSTEM installation remains silent and offline; employee user-session disclosure is separate.

## Local tests (24 October)
- `Test-DoxaGatewayClient.ps1`: PASS including request fields; locally mocked network.
- `node --test assistant/worker.test.mjs`: **14 tests PASS**, including three negative acknowledgement cases and no model calls on refusal. No live Cloudflare production redeploy occurred.
- `Build-DoxaManagedPilot.ps1`: **LOCAL_PASS**, 10 lifecycle cases, 16 source-file hashes, 19 personal-bundle files, two managed distribution files. Artifact: `artifacts/releases/managed/Doxa-Managed-AppOnly-Pilot-20261024-201607.zip`, SHA-256 `4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425`. Inner personal ZIP SHA-256 `E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50`.
- `Build-DoxaIntunePilot.ps1`: PASS, Microsoft-signed Content Prep Tool v1.8.7 Authenticode valid; generated fresh `artifacts/releases/intune/doxa-intune-app-only-20261024-201637-df574ee/DoxaPilot.intunewin`, SHA-256 `FFCA7CA75A5EB27083E1D3099B202929073EA97094CC8565610AE28824A44E36`. Inner source ZIP SHA-256 `7791F670957E40895B01E08781D6F27F78AB7E65E5AB22DBA13A76D2140B80D4`.
- The two source-bundle hashes differ because the bundle embeds creation time; both were built from the same source revision and separately verified. Byte-identical bundles are not claimed.
- No vendor MSI or signed customer executable is bundled. Generated archive and downloaded packaging tool bytes are excluded from Git.

## Remaining gates
- Intune: tenant/Graph RBAC and disposable enrolled Windows endpoint; remote upload, SYSTEM install/detect/update/uninstall and management logs **NOT RUN**.
- ManageEngine: enrolled test endpoint and actual package execution, status and event logs **NOT RUN**.
- Physical SMI770 driver install/upgrade/rollback, security-policy, reboot/reconnect qualification **NOT RUN**.
- Silicon Motion/OEM written distribution permission pending; vendor MSI approval manifest remains `NOT_APPROVED`.
- Microsoft publisher qualification and signing pending, including the existing Microsoft account's country mismatch.
- Final DMR Ergonomics controller/processor allocation, EU AI Act/GDPR notice, retention, Cloudflare agreement, legal basis and versioned user-choice record not approved.
- Not production ready; not a commercial installer.

Official deployment references:
https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
https://www.manageengine.com/products/desktop-central/help/software-deployment/powershell-script-as-a-package.html
https://www.manageengine.com/eu/products/desktop-central/help/configuration-management/executing_custom_scripts-computer.html
