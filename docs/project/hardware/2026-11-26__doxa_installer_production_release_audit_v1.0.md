# DOXA installer qualification and release register - 26 November 2026

## Decision

**NO COMMERCIAL RELEASE.** The Windows binaries are genuinely signed/timestamped, and offline packages pass byte-level checks. Their release remains a GitHub owner-test draft pending OEM redistribution, genuine clean-system deployment, owner UI/privacy approval and supported hardware qualification. The macOS universal review build succeeds on a real GitHub Actions macOS runner, but no Apple Developer ID signing, notarisation or physical Mac qualification has been performed. No customer-facing `standivarius.com` download redirect has been created: the DNS is not delegated to the available Cloudflare account, and no verified website-hosting publication route was established.

## Candidates and support claims

| Channel | Candidate/version | OS | Evidence / current status |
|---|---|---|---|
| Windows Personal | `DoxaSetup.exe` 0.4.0.13 | Windows 10/11 x64 candidate, exact builds not fully qualified | Authenticode **Valid**; DMR ERGONOMICS S.R.L.; timestamp **Present**; owner-test draft |
| Windows Enterprise | `DoxaDeploy.exe` 0.4.0.13 | Windows 10/11 x64 candidate | Authenticode **Valid**, timestamp **Present**; native non-mutating selftest **PASS**; physical SYSTEM/repair/uninstall **NOT RUN** |
| Microsoft Intune | `DoxaDeploy.intunewin` 0.4.0.13 | Windows x64 / SYSTEM pilot | Authenticated package decryption, digest, equality with managed EXE **PASS**; actual Intune deployment **NOT RUN** |
| ManageEngine | signed managed EXE/ZIP 0.4.0.13 | Windows x64 / SYSTEM pilot | ZIP EXE byte-identical to Intune EXE **PASS**; real managed-agent rollout **NOT RUN** |
| macOS | Standivarius Doxa Setup 0.1.0 | macOS 13+; universal x86_64 + arm64 review build | GitHub macOS-15 workflow **PASS** on 26 Nov; **UNSIGNED FOR DISTRIBUTION / NOT NOTARISED**; no actual Doxa/Mac acceptance |

## Independent 26 November verification

- Downloaded the four 9 November Windows draft assets and original release metadata. Independently verified two executable hashes and signatures using Windows `Get-AuthenticodeSignature`: valid DMR company signature, Microsoft Public RSA Time Stamping Authority; certificate SHA-1 thumbprint `F130F66D722638FCDFB2465CBA2B8F2B7034DEB8`.
- Personal SHA-256 `802E42A44542F9B95E900491CC2DE08A28A38F6FA47627ACBA9C23A2F74E8B6D`; managed SHA-256 `7549EC23A3DCC4EA90C0446F4897DE632FF6C78832E7095075568317568EA507`. Both exactly match the original Azure signing attestation.
- The `.intunewin` decrypted successfully (authenticated HMAC, CBC padding, SHA-256 digest) and contained only `DoxaDeploy.exe`, **byte-identical** to the signed ManageEngine executable. Managed ZIP contains the exact same bytes; four downloaded asset hashes match the release manifest.
- `Test-DoxaNativeRelease.ps1` on isolated reconstructions: `PASS`, including selftest, sidecar isolation, `/detect`, `/verify`, unknown-command rejection, and read-only driver/system-state preservation. It explicitly did **not** install or repair the actual MSI or execute a live agent rollout.
- Reran GitHub macOS workflow `45807280280` on `master`: `success` unsigned universal build. A prior 9 November master push workflow was recorded unsuccessful/cancelled; current manually dispatched source build is green.
- The existing November 13 Doxa SM770 hardware qualification demonstrates physical extended-screen and resource characteristics; it is **not a first-time installer qualification**.

## Release train and documentation

- Canonical single Windows train: `docs/project/programme/2026-11-06__doxa_single_release_train_v1.0.md`; do not replace with another installer.
- Signed release finalisation: `app/packaging/doxa-setup/full-release/Finalize-DoxaSignedRelease.ps1` and `Test-DoxaReleaseConsistency.py`.
- Native enterprise install/detect/repair/uninstall instructions: `docs/project/hardware/doxa_windows_enterprise_deployment.md`; managed agent pilot: `app/packaging/doxa-setup/full-release/MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md`.
- macOS setup and signing/notarisation instructions: `app/packaging/doxa-setup/macos/README.md`. Production build now requires `DOXA_MACOS_RELEASE=1` plus installed Developer ID Application/Installer identities and notarytool credentials. Missing credentials fail closed; unsigned preview remains default. Mac build is a companion to official vendor InstantView; it does **not** bundle or redistribute vendor macOS software.

## Distribution: verified vs blocked

- **Windows owner-test (draft, not public):** https://github.com/Standivarius/Vision/releases/tag/untagged-750231b9eba1ab025884
- **macOS 0.1.0 development preview (draft, not public):** https://github.com/Standivarius/Vision/releases/tag/untagged-9f55147d032947225cf8
- **Customer downloads on standivarius.com: NONE VERIFIED / NONE ENABLED.** Do not invent links or redirect a permanent customer path to draft/unqualified assets. Once production gates pass, publish immutable versioned GitHub release assets and configure permanent redirects in the actual authoritative website/DNS environment, then verify browser/HTTP download, MIME, redirect destination, publisher signature, checksums and rollback.

## One consolidated owner action list - required before commercial signoff

1. **OEM/licensing:** Obtain written manufacturer/Silicon Motion redistribution authorisation for the exact `SMIUSBDisplaySW770.msi` version/hash `3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4`, including commercial bundling in Windows EXEs/Intune. A signed vendor MSI does not itself grant redistribution rights.
2. **Windows pilot endpoints:** Authorise one genuinely clean Windows 10/11 x64 machine with the Doxa device for install/repair/uninstall and a separate approved Intune SYSTEM deployment pilot; preserve original Dell's working driver. Test unplugged/replugged operation, return codes, and independent extended laptop + 3 Doxa displays.
3. **Mac:** Provide an Apple Developer Program team with **Developer ID Application** and **Developer ID Installer** signing identities and notarytool credentials to a controlled Mac signing host (do not send private keys in chat). Supply one Intel Mac and one Apple Silicon Mac, each with Doxa available for physical acceptance of InstantView and permission guidance.
4. **Owner/legal:** Approve final personal UI (including 150/200% DPI), customer Terms, privacy/GDPR, Cloudflare AI controller/processor arrangement and support-retention terms.
5. **Customer download hosting:** Grant authorised control of `standivarius.com` website redirect routing and approve stable customer paths after production qualification; current authoritative DNS records point to `ns.second-ns.com`, `ns3.second-ns.de`, `ns1.your-server.de`. Domain ownership or Cloudflare login alone does not prove redirect control.

Until these gates are closed, retain the signed Windows 0.4.0.13 **owner-test draft** and unsigned macOS 0.1.0 **development preview**, not a customer production version.
