# Doxa Setup — ManageEngine Endpoint Central real managed lifecycle on ASUS — RESULTS

**Date:** 25 October 2026, local time Europe/Bucharest. **Scope:** Vision / Doxa app-only software pilot, ASUS-DESKTOP-HOME only; separate from Dell Intune. Draft Vision PR #78, GitHub issue #75. **Status:** The core real-agent lifecycle **PASS** (install / repeat / uninstall). Physical vendor driver and unrelated enterprise gates remain separate.

## Scope, package and environment

- Device: **ASUS-DESKTOP-HOME** (Windows hostname `ASUS-DESKTOP-HO`; ManageEngine resource ID `43565000000329359`); Windows 11 Pro, workgroup `WORKGROUP`; no ASUS physical Doxa hardware/driver changes.
- ManageEngine Endpoint Central **EU Cloud**, agent `11.5.2632.14.W` installed from official downloaded signed Zoho MSI. Signed MSI SHA256 `CE0ACE07D9BF63467EDF088411BEC7DC3730F56A6A90D6E41354B08D6993FB91`.
- Local ASUS bridge used to inspect actual Endpoint Central Windows services and logs; **locally hosted Playwright 1.60 over Chrome CDP port 9223** controlled one isolated authenticated browser profile. TinyFish was **not** used for successful script upload, targeting or managed deployments. The AiGov repository was **not** modified.
- Exact frozen `Doxa-Managed-AppOnly-Pilot-20261024-201607.zip` transferred from Dell and verified on ASUS: SHA256 **4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425**, 42,670 bytes. Extracted script `DoxaPilot.ps1` SHA256 **A0C32CF6E961E9CD2BF39A389E4338C28288DC8C9B82D2014AA94FFE495D4F64**; dependency `DoxaSetupPayload.zip` SHA256 **E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50**.
- Via actual ManageEngine Cloud UI, uploaded the original `DoxaPilot.ps1` into **Configurations > Script Repository**, then for each Computer-level Custom Script used that repository script and uploaded the exact `DoxaSetupPayload.zip` as a dependency.
- For all three jobs: `System User`, `Once`, **single computer target** selected using `Remote Office = Default Remote Office` **refined by Computer = WORKGROUP/ASUS-DESKTOP-HOME**, logging enabled, **Retry disabled**, notifications disabled. Pre-deployment UI state checked programmatically before clicking `Deploy Immediately`. No broad group target, no other computers, no vendor driver installer, no reboot requests or OS policy bypass.

## Three genuine managed deployments

| Gate | ManageEngine configuration ID | Window, local | Agent log / independent result |
| --- | --- | --- | --- |
| Initial Install, `-Action Install` | **43565000000332018** | 09:06:52–09:07:03 | **SUCCESS**. `DoxaPilot.ps1 -Action Detect` returned `DETECTED:DoxaSetupPilot`, exit **0**. Expected `C:\Program Files\Standivarius\DoxaSetup` present; hashes checked by Detect. |
| Repeat Install, `-Action Install` | **43565000000332038** | 09:12:17–09:12:27 | **SUCCESS**. Existing installation remained valid; Detect exit **0**. Script source has explicit `IsInstalled` early return. Agent reported SUCCESS without an overwrite. |
| Managed Uninstall, `-Action Uninstall` | **43565000000332053** | 09:14:22–09:14:30 | **SUCCESS**. Detect exit **1** and Doxa Program Files folder **absent**. No driver/unrelated paths removed. |

**Source of truth:** ASUS local `C:\Program Files (x86)\ManageEngine\UEMS_Agent\logs\dcconfigaccess.log` recorded all three jobs as `POLICY_INVOKED=Ondemand`, `CONFIG_TYPE=Computer`, **USER_NAME=SYSTEM**, `CONFIG_NAME=Script Configuration`, and **CONFIG_STATUS=SUCCESS**. `dcconfigondemand.log` separately recorded each collection finishing with `collection status:6` and server-upload activity. The console showed exactly the ASUS-only target in each configuration's Target Scope. These logs are user-local and may be deleted with agent decommission; this document retains the evidence summary and exact IDs.

## Test matrix / claims

- PASS: exact signed agent installed on ASUS, registered and communicating with Endpoint Central EU; agent-delivered cloud script + dependency; *SYSTEM* execution; intended one-computer scope; initial install; independent detection; repeat/idempotent install (no overwrite, successful execution); manager-driven uninstall to absent; Windows no pending Windows Update restart after removal.
- NOT RUN / NOT CLAIMED: foreign-file refusal **through the management console** on a disposable VM; AppLocker/WDAC blocked-policy response; restricted corporate credentials and offline manager-delivery; actual physical Doxa Silicon Motion driver MSI install/reconnect/rollback; public production signing. The frozen package already passed local 10/10 lifecycle and 4 package integrity/tamper tests.
- Dell's separate Intune pilot **was not modified**. The ASUS AiGov application/repository and operating services were not touched by this app-only Doxa exercise.
- ManageEngine agent cleanup was requested only **after** the three managed application jobs finished successfully; record final removal/console cleanup separately when verified. Do not claim account/tenant or billing cancellation.

## Reproducibility

- UI path: `Configurations > Script Repository > Add Script`, then `Add Configurations > Windows > Custom Script > Computer Configuration`.
- Choose `Repository: DoxaPilot.ps1`; `Script Arguments: -Action Install` or `-Action Uninstall`; upload `DoxaSetupPayload.zip` dependency; `Once`, `Run As System User`, `Exit Codes 0`, `Enable Logging`, disable `Retry this configuration on failed targets`; `Remote Office: Default Remote Office`, refine on **Computer ASUS-DESKTOP-HOME**, confirm *one selected computer only*.
- The exact created IDs are recorded above; future pilot runs should use new one-time configurations and a recoverable endpoint.

## Verified post-test decommission

- **ASUS managed agent removal successful:** Windows Application MsiInstaller event **1034** plus event **11724** for `ManageEngine UEMS - Agent` at **09:20:51 on 2026-10-25**, removal error status 0. ASUS independent service enumeration later showed **zero ManageEngine services**.
- **Doxa absent:** `DoxaPilot.ps1 -Action Detect` returned **1**, Doxa Program Files folder absent, and no pending Windows Update or CBS reboot.
- **Endpoint Central Cloud**: vendor-supported ASUS-only agent uninstall had been requested after all three real managed jobs passed; UI showed **Uninstalled Successfully**. Its single ASUS device record was then removed with the one-record scope check. Following refresh, **No computers managed, 0–0 of Total Records**.
- **Cloud one-time jobs**: test configuration IDs `43565000000332018`, `43565000000332038`, `43565000000332053` moved to **Trash** only after recording success evidence. They are no longer active jobs. The `DoxaPilot.ps1` Script Repository entry **remains**: vendor UI refused deletion because of these historical associated tasks, even after moving them to Trash. It cannot execute without an active job/target. The managed Endpoint Central tenant/subscription **was not deleted or cancelled**.
- **ASUS transient cleanup**: dedicated isolated CDP Chrome profile / listener port `9223` closed and the Doxa-only temporary `%LOCALAPPDATA%\DoxaPilot-Staging` folder deleted. The two exact desktop pilot installers `Install-ManageEngine-ASUS-Pilot.cmd` and `Install-ManageEngine-ASUS-Pilot-v2.cmd` removed. Ordinary Chrome and all AiGov application/repo work remain untouched.
- **User-owned download preserved**: `C:\Users\User\OneDrive - DMR Ergonomics\DefaultRemoteOffice.zip` not changed. It is a Zoho-generated agent bootstrap download with tenant configuration and should be protected; optional deletion from OneDrive is a separate user-data action, not part of this test.
- **TinyFish**: the previously-created Standivarius Endpoint Central EU saved browser profile within TinyFish **was not removed by local Playwright**. TinyFish may retain cookies; its profile cleanup is separate from local ASUS cleanup. No TinyFish wallet top-up or billing modification was performed.
- **Dell**: unrelated Intune app-only pilot and original Doxa hardware/driver unchanged. **No merge** was performed.

**Final ManageEngine pilot conclusion:** core genuine app-only remote Install, repeat/ idempotency, managed Uninstall **PASS**, agent uninstall and managed-device cleanup **PASS**. Physical vendor-driver lifecycle and wider regulated endpoint-policy tests remain distinct unpassed gates.
