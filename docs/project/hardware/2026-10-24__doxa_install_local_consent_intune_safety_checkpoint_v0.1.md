# Doxa installer — consent and Intune package safety checkpoint v0.1

**Date:** 2026-10-24
**Scope:** isolated Doxa worktree `C:\wt\doxa-installer-ai-enterprise-20261024`; GitHub #75; ClickUp DXI-26/27 and DXI-07/08.
**Status:** LOCAL TEST PASS, commercial and managed deployment NOT approved.

## Change
- The Doxa cloud AI request client now fails closed with `consent_required` without an explicit caller-supplied `-AIConsentGranted` flag. Guided setup forwards this flag only on the already opt-in-selected path. Enterprise machine policy deny continues to take precedence. The flag is an in-process development safeguard, **not** a durable notice-version consent ledger or production customer identity system.
- Personal ZIP manifest still declares 16 approved source files; the generated launcher and readme now have independent SHA-256 entries. Complete archive count is 19, including the manifest.
- Intune app-only script checks the exact 19-file inventory and declared SHA-256 values. Unknown files make detection fail; uninstall refuses to delete an altered/unrecognised target, and an expanded ZIP containing an extra executable fails installation.
- No MSI, SYS, CAT, vendor driver or credentials are embedded. No policy, PnP, desktop topology or driver was changed.

## Evidence actually observed (Dell, 24 October)
- `Test-DoxaGatewayClient.ps1`: PASS, including direct-client refusal without consent and signed-client mock.
- `Test-DoxaCloudAIPolicy.ps1`: PASS (including organisational deny fixture and default-off welcome).
- `Test-DoxaSetupExperience.ps1`: PASS, observed signed driver `4.7.6.8001`, live readiness `ready`; simulated faults kept labelled.
- `Test-DoxaPersonalBundle.ps1`: PASS, 16 source SHA checks, 19 total archive files, extracted guided journey, offline help and zero driver mutations.
- `Test-DoxaPilot.py`: PASS, 10 cases in isolated temporary roots: absent/install/detect/idempotence/foreign-file non-detection/refused remove/re-detect/uninstall/absent/tampered-EXE ZIP refusal.
- Microsoft Win32 Content Prep Tool v1.8.7 downloaded from its official release, Authenticode **Valid**, signer **Microsoft Corporation**, SHA-256 `C1BA45B5CB939E84AF064BB7FF4B38FB3DFE33C8DC1078FD9B157672EAE671F6`.
- Fresh source-built app-only Intune artifact: `artifacts/releases/intune/doxa-intune-app-only-20261024-194141-5efabe6/DoxaPilot.intunewin`, SHA-256 `71899E4F3253B51F017D9E83DB608D70B050100075098319CB49E40AC619E515`.
- Its source ZIP SHA-256: `D7C4D33EBDA16F500C39287E3E560DEDD2EB338A81EB4B2363021B297E0789F5`.

## Limits / open gates
- This is a source-script preview, not a production signed installer. An explicit switch is not cryptographic proof the user saw a final privacy notice; consent recording, final GDPR/controller/retention, client enrolment and organisation deployment policy still need completion.
- No actual Intune or ManageEngine managed endpoint was enrolled or deployed here. Live field evidence, machine-level silent deployment, user-session UI, enterprise rollback and reports are pending.
- Silicon Motion redistribution authorisation is pending with the vendor and Chinese manufacturer. Vendor MSI approval manifest remains NOT_APPROVED. Production physical-driver upgrade/uninstall/rollback validation has not run.
- Microsoft publisher identity/code signing is pending legal/tenant clarification.
- The isolated installer branch was based on Dell local master; remote PR #77 still includes unrelated earlier Vision history. Do not merge blindly.
- The dev-harness directory is untracked in the dirty master, not present in the isolated committed worktree; its local check was not run in this branch.

No claims above promote this pilot to a qualified customer release.
