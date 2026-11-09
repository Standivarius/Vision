# Independent re-review of the Doxa installer, 9 November candidate

**Target:** `C:\wt\doxa-terms-layout-sonnet-review-20261109`. The branch ref file reads `2e9563efdc3c56bf38164302f09a196816775309`, which matches the requested HEAD. I could not run `git status`, so a clean working tree is unverified.

**Method:** Read, Glob and Grep only. I ran no test, build, installer or network call. Everything below is a static code assertion unless I name a repo-recorded live test.

## A. Executive decision

**CONDITIONAL for signing an owner test build. HOLD for any external or commercial release.**

Do not sign this exact commit. Signing the outer EXEs freezes everything embedded in them (the PowerShell scripts, terms text and notices), so any later fix means rebuild and re-sign. Fix the four P0 items below first, then sign once. The core installer logic looks sound by source reading, but the gates that should bless it are partly red, and the terms window has an unverified layout defect.

**Unsigned and unqualified items that remain true today:**
- **Outer `DoxaSetup.exe` is unsigned.** The retail builder deliberately throws on `-RequirePublisherSignatures` (`Build-DoxaRetailRelease.ps1:66`).
- **Managed `DoxaDeploy.exe` is unsigned.** It is the same source, compiled separately (`:45-49`).
- **The embedded PowerShell UI scripts are unsigned.** The signing pipeline does not cover them.
- **OEM redistribution rights for the embedded Silicon Motion MSI are pending.**
  - Terms §3 and §8 and the worker prompt (`worker.mjs:20`) say so.
  - The `Build-DoxaCompleteRelease.ps1` README says "NOT approved".

## B. P0: fix before ANY signature

All four change bytes that end up inside the signed EXE, or the evidence that justifies signing.

**P0-1. The gate tests are stale and, by static reading, fail at HEAD (SC).** There is also dead code in the signed binary.
- `Main()` goes straight to `OpenSingleWindow()` (`DoxaSetupHost.cs:698`). `UI()` (`:588-694`) is never called. It carries a native consent window, an old "29 OCTOBER 2026" terms text, and `Open(true,cloud.Checked)`.
- `Test-DoxaConsentContract.ps1:20` requires the guided script to contain `if($PermissionsGrantedInHost){2}else{1}`. That string is absent from `Start-DoxaGuidedSetup.ps1`.
- The same test's `terms_explicit`, `local_checks_gated` and `remote_ai_optional` checks (`:16-18`) match text that exists only in the dead `UI()`.
- `tests/Test-DoxaSonnetRemediation.ps1:10` requires the literal `Open\(true\)`. The host only contains `Open(true,cloud.Checked)`.
- Neither test is in CI. `doxa-setup-contract.yml:23-47` covers only the worker tests, the gateway and policy tests, `-BrandTest` and `-SeamlessTest`.
- **Remedy:** delete `UI()` and the unused `Open(bool,bool)` and `Doxa.ProductPhoto` plumbing. Rewrite both tests against the live flow. Add `Test-DoxaPersonalBundle.ps1` and a host compile to CI.
- **Test:** the repaired tests go green and fail when the guard text is removed.

**P0-2. The Terms window layout is unverified and probably clipped (PR).** `Start-DoxaGuidedSetup.ps1:77-84,102` adds the Bottom-docked footer first and the Fill-docked RichTextBox last.
- In WinForms, controls added first sit at the front of z-order and are docked last. So the Fill control is docked first, spans the whole client area, and the footer overlays its bottom ~55 px.
- If that is right, the last lines of §8 are hidden behind the Close footer at full scroll. That would be the last lines you need to see before accepting.
- **Remedy:** add `$copy.BringToFront()` (harmless if my analysis is wrong). Also set `$copy.DetectUrls=$false` and `$window.ActiveControl=$copy`.
- **Test:** this click path (`Add_LinkClicked`, `:66-104`) is never executed by any test. Capture screenshots at 100%, 150% and 200% scale, scrolled to the end.

**P0-3. Terms §8 will be false in a signed owner build (SC).** `DOXA-SETUP-TERMS.txt:29` says "The current unsigned build is provided for controlled owner evaluation…". The file is hashed into the payload manifest, so it cannot change after signing.
- **Remedy:** reword §8 to be signature-neutral, for example "pre-release; not for general distribution".

**P0-4. The version identity is stale and provenance is not enforced (SC).**
- The host version (`DoxaSetupHost.cs:25`), the bundle manifest (`Build-DoxaPersonalBundle.ps1:58`) and `Test-DoxaPersonalBundle.ps1:15` all still say `0.4.0-preview.12`. That is the same string as the 28 Oct builds that are installed or published on the Dell and in Intune. Content has changed since, including terms, AI enrolment and flow.
- `IsValidApp` also hard-codes 22 source files and 25 total (`DoxaSetupHost.cs:182`). Any payload change must be matched by a host change. This is another reason to freeze before signing.
- Neither builder checks for a clean tree. `Build-DoxaRetailRelease.ps1:26-27` records `git rev-parse HEAD` without `git status`. The payload is taken from `$CompleteCandidateDirectory` (`:16`) with no check that the candidate's `source_commit` equals HEAD. The recorded commit can therefore describe a different payload.
- **Remedy:** bump the version in the three places above. Add a clean-tree check and a candidate-commit equality check to the retail builder.
- **Reproducibility note:** only the payload ZIP is reproducible (`-Reproducible`, commit timestamp). The EXEs come from classic `csc.exe`, which is not documented here as deterministic. State "reproducible payload, not reproducible EXE" in the manifest rather than implying more.

**Signing mechanics are otherwise stronger than on 28 Oct.** `Finalize-DoxaSignedRelease.ps1` now:
- requires an exact 40-character thumbprint, not just a subject match (`:15,21`);
- requires a timestamp countersignature (`:22`);
- re-hashes the reviewed unsigned EXEs against the manifest (`:28-33`);
- runs the PE-neutral comparison (`Verify-DoxaPeSigningOnly.py`).

`Test-DoxaSignedManifestContract.py` is only a string-presence test, so it proves nothing beyond that. `DoxaMaintenance-v2.exe` and the cleanup helper are copies of the running EXE (`DoxaSetupHost.cs:345-346,421-422`), so they inherit the signature.

## C. P1: must fix before external release

| # | Finding | Evidence | Class |
|---|---|---|---|
| P1-1 | **OEM redistribution of the Silicon Motion MSI is unapproved.** The product embeds it (`Build-DoxaRetailRelease.ps1:47`). | `knowledge/entries.json` `smi-oem-licensing`; Terms §3, §8 | GATE |
| P1-2 | **First physical driver-free install has never run.** The MSI only fires with USB present and a missing driver (`MayRunVendorMsi`, `DoxaSetupHost.cs:372-374`; `Apply`, `:389-393`). Its vendor custom actions (devcon, USB add/remove) were flagged as unqualified in the profile. Unproven: PnP binding within 60 s, the 3010 path, display behaviour during install, UAC. | `profiles/vendor-msi-reviewed.NOT_APPROVED.json` | GATE |
| P1-3 | **Online AI "authentication" is self-asserted.** The worker accepts any client-supplied public key whose ID matches its hash, with no allowlist (`worker.mjs:48-87`). Key rotation defeats the per-device 4/min limit. | `wrangler.toml:10-37` | SC (design) |
| P1-4 | **The AI consent version is a constant.** `Ask-DoxaInstaller.ps1:45` and `worker.mjs:125` hard-code `development-v0.1`, but the privacy notice is now a dated 9 Nov text. No local consent record is kept. | | SC |
| P1-5 | **The endpoint is a personal subdomain.** `marius-moldovan.workers.dev` is hard-coded in the client (`Ask-DoxaInstaller.ps1:4,12,79`). It is not suitable for a controller-identified product. | | SC |
| P1-6 | **Enterprise first-time flow has a gap.** `/install` with no USB installs the app only and defers the MSI, so `/detect` then passes (`DoxaSetupHost.cs:146-153,389`). Intune and ManageEngine therefore never re-run install. Someone must run `/repair` after connection. The runbook states this (`MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md:29`) but there is no automated remediation. | | SC (design gap) |
| P1-7 | **No live endpoint test of `DoxaDeploy.exe`.** | See section F | GATE |
| P1-8 | **Intune OS floor mismatch.** Publisher scripts require `Windows11_23H2` (`Publish-DoxaFullIntune-HighFinal.py:88`), while the host supports build ≥19041 (`DoxaSetupHost.cs:284`). `HighFinal.py:23-27` also hard-codes a Dell group and a 28 Oct release folder. There are four generations of near-identical publishers. | | SC |
| P1-9 | **The driver install freezes the UI.** `Doxa-BrandTabs.ps1:258` runs `Start-Process … -Verb RunAs -PassThru -Wait` inside the click handler on the UI thread. The host allows up to 10 min for the MSI plus a 60 s binding wait. The window will show "Not responding". | | SC |
| P1-10 | **No DPI awareness.** The only DPI setting is in the dead `UI()` (`DoxaSetupHost.cs:590`). Grep found none in the live PowerShell UI. For a low-vision product this means blurry bitmap scaling. | | SC |
| P1-11 | **The UI scripts are unsigned.** Under WDAC or Constrained Language Mode the guided UI will not run. `OpenSingleWindow` gives a clear error (`:484-486`), but the customer cannot proceed. | | PR |
| P1-12 | **Romanian terms and privacy are missing.** Both are English-only (`Start-DoxaGuidedSetup.ps1:66-104`, `AI-PRIVACY-NOTICE.txt`). The window title and the Close button are also hard-coded English (`:70,80`). The old Romanian terms live only in the dead `UI()`. | | SC |
| P1-13 | **Panel identity is name-based.** `Generic Monitor (L/T/R)` came from one unit (`profiles/smi770-observed.json`, `DoxaSetupHost.cs:290`). | | PR |

## D. P2: improvements

- **README text is stale.** The retail builder's README-FIRST (`Build-DoxaRetailRelease.ps1:80-84`) still describes the old "Install / check Doxa" flow. Also the Complete builder README references `Doxa-Complete-Managed.zip` while the build makes `Doxa-Complete-Managed.zip` and `Doxa-Managed-Windows.zip` in different stages.
- **Terms fallback does not block consent.** If the terms file is missing, only a "close Setup" message appears (`:68`); the checkbox stays tickable.
- **Privacy details use a plain multiline TextBox** in the wizard (`:163-177`) and the Help panel (`Doxa-BrandTabs.ps1:300-309`). That is the same "single block" problem the owner raised for terms.
- **Online AI UI, privacy and key store:**
  - `'Privacy details for Online AI Help'` maps to itself in the Romanian table (`Doxa-BrandTabs.ps1:491`).
  - The notice says active desktop count is sent, but the client does not send it (`Ask-DoxaInstaller.ps1:29-41`).
  - The key folder is named `DeveloperAccess` (`Get-DoxaDeviceSignature.ps1:13`) and survives uninstall. There is no erasure instruction.
- **Retained app folders accumulate.** `DoxaRetained-*` directories are never cleaned (`DoxaSetupHost.cs:236,260`).
- **Legacy Dell public key still ships in the payload.** It is listed at `Build-DoxaPersonalBundle.ps1:17` and read by the policy script (`Get-DoxaCloudAIPolicy.ps1:29-30`). The worker still has the legacy branch (`worker.mjs:53,64-70`). Retire both rather than extend them. Doing it before signing is cheap because it changes the payload count.
- **Default tool paths** in the builders point into `C:\dev\Vision` (the dirty main checkout).

## E. Terms window: the five requested checks

| Check | Result |
|---|---|
| **Styled headings** | Code styles the title, `Provider`, and `1.`–`8.` section lines in bold crimson (15/11 pt) via `[regex]::Matches` on `$copy.Text` (`:92-100`). Indices come from the same string the control holds, so highlight drift is unlikely. The `Version:` line is unstyled. PR until a screenshot confirms. |
| **Spacing** | Relies on the blank lines in the file plus form padding (`:76`). There is no paragraph spacing property, and spacing is unverified visually. |
| **Text preservation** | Good. The file is loaded verbatim with `Get-Content -Raw -Encoding UTF8` and assigned to `.Text`; only formatting is applied. |
| **Safe display** | Good. Plain-text assignment (no RTF), `ReadOnly`, no external content. Minor: `DetectUrls` stays on, so the email is a link with no handler. |
| **Keyboard / accessibility** | Close is both Accept and Cancel, so Esc and Enter close. No `AccessibleName` is set on the text box or the dialog. Initial focus is likely the Close button (first in tab order), so a screen-reader user must Tab to reach the text. |
| **Localisation** | English only. |
| **Geometry** | 800×580 client, 540×390 minimum, sizable; Close is anchored right and fits (646+106 ≤ 756). The Fill/footer overlap in P0-2 is the open risk. |
| **Click path** | The `-Smoke` and `-JourneyTest` modes never open the dialog. `Test-DoxaPersonalBundle.ps1:71-80` is a string-contains check. A live click-through is a GATE. |

## F. Status of my 28 Oct findings

| Oct finding | Status at 2e9563e (source) |
|---|---|
| F1 MSI with Doxa unplugged | **Resolved in source.** `MayRunVendorMsi` and the `Apply` gating; the selftest asserts the truth table (`:520-524`). The physical gate remains (P1-2). |
| F2 OEM redistribution | **Unresolved GATE.** |
| F3 outcome / restart not shown | **Mostly resolved.** BrandTabs reports 3010 and "verify" (`:259-265`). The 60 s `DriverBindingPending` case still exits 0 silently, with a generic message. |
| F4 duplicate consent / repetition | **Resolved.** One wizard consent; the native window is removed from the live path. |
| F5 classifier divergence | **Resolved in source.** `Get-DoxaDriverState.ps1:44-64` mirrors the host table, and the "Silicon Motion, Inc." alias is covered. The unbound / generic first-use case is now `driver_missing`. Fixture-tested only (`Test-DoxaSonnetRemediation.ps1`, which is itself stale per P0-1). |
| F6 UI-thread scan, DPI, chat cleared | **Partly resolved.** Scan now runs in a background job (`Start-DoxaSetup.ps1:353-402`) and language switch preserves chat. DPI is unresolved. New freeze at install (P1-9). |
| F7 Help panel / AI enrolment | **Changed.** Automatic first-use enrolment replaced operator approval. Online mode no longer substitutes local answers. New authentication concern (P1-3). |
| F8 privacy identifier disclosure | **Resolved** (notice line 11). Consent version constant and personal endpoint are unresolved (P1-4, P1-5). |
| F9 Fault Lab double trial | **Resolved in source.** Mutex, pending-marker guard and a `--guard-test` (`DoxaDisplayPath.cs:153-168,213-218`). The watchdog also skips if already `RESTORED` (`:200-202`). |
| F10 restore unproven | **Unresolved GATE.** No live disable or restore recorded. |
| F11 overclaiming tests | **Partly resolved, new instances.** Contract tests assert dead code (P0-1). |
| F12 panel name identity | **Unresolved** (P1-13). |
| F13 unsigned scripts under WDAC | **Unresolved** (P1-11); the error message is better. |
| F14 Intune OS floor, retained dirs, hard-coded counts | **Unresolved**, except upgrade now retains and restores on failure (`InstallAppTo`, `:220-246`). |
| F15 signing script weaknesses | **Resolved** (section B). |

**New findings since 28 Oct:** P0-2, P0-3, P0-4, P1-6, P1-9 and P1-12 above, plus the dead `UI()`.

## G. Required but unproven tests

**Recorded by the repo (live, but older):**
- `docs/.../2026-10-28__doxa_sonnet_remediation_final_validation.md` records an unsigned-build PASS at commit `1eea35d`. That is before the 9 Nov changes.
- It records physical screen tests, MSI apply, UAC, PnP binding, 3010, signing, live AI enrolment, Intune and ManageEngine agent runs, and Fault Lab disable/restore as **NOT RUN**.
- The ManageEngine live pass (25 Oct) used the legacy `DoxaPilot.ps1` on a different machine, not `DoxaDeploy.exe`.
- I found no 9 Nov validation record in `docs/project/hardware` (latest file dated 29 Oct). I did not inspect `artifacts/`.

**Missing for the signing decision and beyond:**
- Terms window click-through and screenshots (P0-2).
- Clean driver-free attended install: power, then data, then Extend.
- Signed-EXE UAC prompt and SmartScreen behaviour.
- Intune one-device pilot of `DoxaDeploy.exe`: install, detect, repair, uninstall, USB hotplug flap, 3010.
- ManageEngine live run of the native package.
- Live Online AI against the deployed worker: a fresh key, wrong clock (the 401 retry path, `Ask-DoxaInstaller.ps1:72-84`), policy-blocked, offline.
- WDAC / Constrained Language Mode test.
- 150%/200% DPI and screen-reader pass.
- Fault Lab live disable/restore, only if the lab is used.

## H. Areas requiring counsel

I am not asserting legal sufficiency on any of these:
- GDPR controller/processor roles, lawful basis and retention. The notice itself says these "require separate approval" (`AI-PRIVACY-NOTICE.txt:19,22`).
- Cloudflare processing regions, subprocessors and transfer safeguards.
- Whether the persistent pseudonymous installation identifier plus the IP it is sent with is personal data.
- Romanian-language terms and notices for Romanian consumers.
- EU AI Act disclosure wording for the assistant.
- Silicon Motion redistribution and OEM licence terms.
- Consumer-law treatment of "pre-release" terms.
- Enterprise data-processing terms for managed deployments.

## I. Bounded next steps

1. **Pre-signing batch** (one rebuild): P0-1 through P0-4, plus retiring the legacy Dell key from the payload.
2. **Test the batch:** repaired gates green locally, CI extended, terms click-through screenshots.
3. **Build the unsigned candidate**, then sign both EXEs with the pinned certificate and timestamp, and run `Finalize-DoxaSignedRelease.ps1`. This is the owner test build.
4. **Owner attended gates on the signed build:** clean driver-free install, UAC and SmartScreen, then a one-device Intune pilot.
5. **Before external release:** P1-1 through P1-13, a signed or compiled UI, a retail AI model decision (either harden authentication or ship offline-only), and counsel review.
