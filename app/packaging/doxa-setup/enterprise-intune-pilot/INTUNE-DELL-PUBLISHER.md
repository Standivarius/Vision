# Doxa app-only Intune pilot publisher — one-device deployment control

Date: 2026-10-24. Deployment authority: DMR Ergonomics Managing Director's authorisation for local Dell Intune pilot only. **NOT** release approval, vendor driver installation, legal signing or corporate-wide deployment.

## Exact content and controls

- Use already validated `DoxaPilot.intunewin` from `Build-DoxaIntunePilot.ps1`. App includes Doxa setup support scripts and offline help only; **no Silicon Motion driver** (MSI/INF/SYS/CAT), no cloud credentials and no automatic restart.
- `Publish-DoxaIntunePilot.py` without flags performs a local-only ZIP/metadata hash check. With `--execute`, requests Microsoft Graph **delegated** device-code consent (no token persistence), then:
  1. Requires **one and only one** managed and compliant Windows device named `MARIUS-DELL` in this tenant.
  2. Resolves its unique Entra directory device ID.
  3. Creates or checks a dedicated, Doxa-named *security group*; rejects a group containing anyone else; adds Dell if missing; confirms exactly one member.
  4. Creates a new **Doxa app-only pilot** in Intune with SYSTEM install context, no reboot and original SHA-256-based detection script.
  5. Uploads the encrypted Win32 content to Microsoft's delegated Azure Storage URI; commits and waits for published state.
  6. Re-checks group membership before assigning **Required exclusively to the dedicated Dell group**. Never assigns all users/devices or changes compliance, security, tenant country or existing applications.
- The publisher deliberately refuses a duplicate named app and an unrelated preexisting group; no blind overwrite/retry after a partial Graph error. If Graph upload fails after object creation, that object is unassigned and must be assessed in the admin console before rerun.
- Tokens and SAS URLs reside in process memory only. The console prints only user code, Graph IDs and aggregate statuses; never access tokens, upload URI, contents of other device records, or secret keys.
- Pilot app is **UNSIGNED**: appropriate only for this controlled evaluation endpoint, not customer or public use.

## User gate

The company administrator is required to complete Microsoft Graph device-code sign-in once for this publisher with scopes `DeviceManagementApps.ReadWrite.All`, `DeviceManagementManagedDevices.Read.All`, `Device.Read.All`, `Group.ReadWrite.All`, `GroupMember.ReadWrite.All`. Grant only after reviewing the permissions. A denied scope prevents any deployment. No new tenant or Azure account is created.

## Evidence & rollback

- Dry run: run `python Publish-DoxaIntunePilot.py`; returns `DRY_RUN_SUCCESS_NO_MICROSOFT_AUTH_OR_WRITES`.
- Offline tests: run `python Test-DoxaIntunePublish.py`, six tests covering package digest, unique compliant Dell, unrelated group member refusal, unpublished app refusal and one-group-only assignment payload.
- Monitor actual Intune Management Extension and Graph application device status after a real, unique assignment. Do not mark an Intune deployment PASS until the enrolled device reports a real install and uninstall with timestamped logs.
- Undo in this order: remove the Doxa pilot's assignment, remove the app-only payload by the approved uninstall, check Doxa panel/driver state and Vision operations, retire or remove management from Dell through Microsoft-supported device workflow, validate original local Windows/Office account and policies. Do **not** use Wipe, dsregcmd /leave, manual registry deletion, or arbitrary OEM driver uninstall.
- Saved pre-enrollment and rollback checkpoint: `artifacts/releases/intune/dell-live-enrollment-20261024/MDM_ROLLBACK_CHECKPOINT.md`, generated artifacts excluded from Git.

Official reference: https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32
Official Graph: https://learn.microsoft.com/en-us/graph/api/intune-apps-win32lobapp-create?view=graph-rest-1.0
