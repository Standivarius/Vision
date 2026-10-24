# Doxa Installer — AI, Microsoft, Silicon Motion and Enterprise Release Gates
**24 October 2026 | v0.1 | Source: live MARIUS-DELL + current official public references | Status: release NOT approved**

## Executive decision
1. Keep one deterministic Doxa hardware engine; maintain distinct personal UI and IT-managed silent workflows. The LLM offers **read-only support**, never executes driver changes or Windows policy changes.
2. Personal: local setup works without cloud AI. Cloud AI is **OFF by default**, permission before first call, detailed readable facts/recipients/risks, and an in-session offline/withdrawal control. The implemented development disclosure is NOT a final GDPR privacy policy; controller identity, applicable legal basis, retention, international transfers and reporting route require completion.
3. Enterprise: Windows Intune and other MDMs **require silent installation** with no UAC/user prompts. Install application-only offline; no cloud AI call in SYSTEM session. IT may set HKLM\SOFTWARE\Policies\Standivarius\DoxaSetup\DisableCloudAI DWORD=1 to deny AI. An IT "allow" must never bypass the employee first-use notice and optional AI preference. GDPR lawful basis and controller/processor allocation under customer agreement require separate analysis; an optional button does NOT alone prove consent is the appropriate Art. 6 basis.
4. Vendor driver MSI remains excluded from Doxa binaries until written Silicon Motion/OEM distribution rights plus controlled real-device tests. A direct user download from the official site or customer IT's own licensed source remains the interim route. The site offers a Sep-2026 V4.7 R06-8001 **normal driver** and Jun-2026 V4.7 R06 **MSI**; do not conflate them. Keep current functioning 4.7.6.8001 Dell driver, no forced downgrade. The MSI includes device remove/re-enumerate actions.
5. Public Windows signing: Microsoft Azure Artifact Signing Basic $9.99/month/5000 signatures plus any applicable Azure costs. EU organizations supported; identity verification still required. Microsoft's current quickstart does not mention a universal minimum company age, but its Windows signing overview mentions 3 years, and recent Q&A highlights inconsistent implementation. Do **not** assume a recently incorporated legal entity will pass. Select contracting/publisher legal entity and validate identity before buying. Signing is distinct from Microsoft's WHCP signature on the existing SMI driver. Public code signing also does **not** immediately eliminate SmartScreen warnings.
6. Test at least two independently managed enterprise platforms on real enrolled devices: **Intune trial** and **ManageEngine Endpoint Central Free** (up to 25 endpoints). A third, Action1, is optional. The locally passing .intunewin and temporary-directory tests are not evidence of successful managed deployment.
7. Microsoft Store only if later useful: it has additional live-generative-AI metadata/reporting requirements; publishing through Store does not magically give us permission to redistribute SM77x drivers nor replace a direct/IT MSI deployment.

## Evidence: what the current app sends
From personal-ui/Ask-DoxaInstaller.ps1 -> worker.mjs:
- Question text and language (English or Romanian).
- Windows build, signed-driver present flag, driver package in store flag, Doxa device present flag, driver version, count of Doxa panels, local/remote session, whether physical topology was verified, readiness flag, app-control-policy='not_checked', package_signature_verified=false.
- Fixed schema and inferred transport metadata (HTTPS server may receive IP, time).
- **Not intentionally sent:** usernames, full USB IDs/serials, screenshots, filesystem, arbitrary logs.
- Server: Cloudflare Worker / Workers AI; curated knowledge entries. No direct hardware-control tools. Cloudflare documents zero retention for standard stateless Workers AI inference and no model training using Customer Content, with exceptions for enabled stateful features, logging/caching or legal obligations. **Application-specific request logs, request metadata retention, actual DPA, cross-border transfers and production data flows have not yet been independently audited**; do not misstate a universal zero-data-retention promise.
- Current device-level signing is for original Dell only: customer enrollment/rotation/revocation/rate-limit model still outstanding.

## AI legal & policy boundary
| Source | Confirmed rule | Doxa action | Status |
|---|---|---|---|
| EU AI Act Art. 50(1),(5), applicable since 2 Aug 2026 | Direct users told they are interacting with AI, clearly and accessibly no later than first interaction | Label 'AI', not human; detailed first-use disclosure EN/RO | Dev disclosure implemented; final review pending |
| GDPR Arts. 6, 12–13 and 28, depending roles | Clear controller/recipient, purposes, legal basis, rights, retention, transfers where relevant, processor agreements | Final controller contact, lawful basis, privacy policy and supplier DPA before release | BLOCKED legal/publisher |
| Microsoft Store Policy 11.16 | If sold/distributed **through Store**, disclose live generative AI in listing/submission and offer inappropriate-content reporting | Add Store metadata/report route only if pursuing Store release | DEFER |
| Intune Win32 apps | Setup must be silent, cannot force user UI | Deploy installer binary with no cloud AI dependency, user first-use notice separate | Pilot-only local validation |
| Vendor driver terms | Site legal notice restricts onward transfer of downloaded software absent authorization, GPO tutorial shows corporate deployment patterns | Obtain specific commercial rights for personal and IT packaging or use separate approved driver provisioning | Supplier approval BLOCKED |

## Implemented on Dell (24 Oct, non-destructive)
- Added personal-ui/Get-DoxaCloudAIPolicy.ps1 with read-only HKLM admin-deny flag and fixture-only diagnostics.
- Added personal-ui/AI-PRIVACY-NOTICE.txt in English and Romanian, showing data categories, Cloudflare service, optionality, offline choice, risks, and publication gaps. It is explicitly marked **development**.
- Guided UI now has a local details link; cloud AI box default off; admin-deny disables choice; main UI exposes "Switch to offline help" and rechecks policy before new remote questions; API client independently refuses if policy denies.
- 16-file personal ZIP built/verified with manifest, no driver MSI/credentials; local consent/policy/client/UI and extracted package tests PASS. **Real user attended usability acceptance remains pending.**
- Intune app-only pilot local temp install/detect/idempotent/uninstall checks PASS; policy never enrolls or configures Dell automatically. Repackage after any source change.
- Never claim a signed public installer, verified GDPR legal basis, supplier distribution permission or real MDM-managed install from these outcomes.

## Release gates / next actions
**G0—source integrity:** safely import/commit mostly untracked installer sources into controlled repository without touching unrelated dirty Vision files; pin manifest/CI tests. DXI-08.
**G1—legal and privacy:** publish actual legal publisher/controller, real company contact, legal basis, processing model/Cloudflare DPA, specific retention and region/transfer, reporting route, EN/RO review. Enterprise DPA/terms, first use and admin disable. DXI-26/27.
**G2—supplier licence:** request **written** rights from Silicon Motion and Doxa OEM for inclusion in signed Doxa exe/MSI, unchanged binary, Intune/ManageEngine packages, offline corporate mirror, driver updates, customer/IT installation, support and terms. No redistribution until approved; currently NOT_APPROVED. DXI-10.
**G3—signing:** choose established legal publisher, ensure Azure bill-to match and website/domain/email; clarify 3-year qualification with Microsoft, create Azure Artifact Signing Basic only if eligible, sign + timestamp app exe/MSI; verify Authenticode and Windows trust on a clean PC. DXI-28/16.
**G4—real private Windows install:** a spare recoverable Windows 11 Pro/Enterprise physical PC with actual Doxa USB display hardware. Record clean install and upgrade, 4-source Extend, cable/power failure, driver store, RDP semantics, non-admin, rollback/reboot, HVCI/WDAC, displays after reconnect, offline AI, Cloudflare opt-in. **Do not run destructive MSI tests on working Dell.** DXI-11/12/17.
**G5—actual Intune cloud validation:** authenticated test tenant (trial and one assigned license owner-confirmed; unverified by API), dedicated group, enrolled disposable Windows device, upload pilot, silent SYSTEM install/detection/update/uninstall, device reporting and logs; then approved driver package only when G2/G4 pass. DXI-18/19/20/21/22.
**G6—second platform:** ManageEngine Endpoint Central Free agent enrolled on separate disposable Windows device (or same machine after clean reset); install/detect/repeat/uninstall and collect management console status, actual logs/screenshots. No production rollout. DXI-23.
**G7—release:** approved final C-style UI, verified customer AI identity and budget limits, signed binary, legal documentation and vendor licence, meaningful actual two-platform evidence, user manual, issue resolution, and go/no-go. DXI-13/14/15/25.

### Evidence / reference URLs (verified 24 Oct 2026)
- https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50
- https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act
- https://eur-lex.europa.eu/eli/reg/2016/679/oj
- https://learn.microsoft.com/en-us/windows/apps/publish/store-policies-and-code-of-conduct
- https://learn.microsoft.com/intune/intune-service/apps/apps-win32-add
- https://www.siliconmotion.com/cht/legal
- https://www.siliconmotion.com/downloads/SM770-drivers.html
- https://www.siliconmotion.com/support/contact
- https://www.siliconmotion.com/downloads/video/SMI_Windows_SM770_MSI_File_User_Manual.pdf
- https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart
- https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview
- https://azure.microsoft.com/en-us/products/artifact-signing
- https://developers.cloudflare.com/workers-ai/platform/data-usage/
- https://www.cloudflare.com/cloudflare-customer-dpa/
- https://www.manageengine.com/products/free-windows-tools/

**DO NOT CLAIM:** actual GDPR compliant public release; unverified Microsoft tax-history acceptance; supplier contract; completed real enterprise physical validation; current repo source committed; customer AI enrollment shipped.
