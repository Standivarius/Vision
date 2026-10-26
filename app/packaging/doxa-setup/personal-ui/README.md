# Standivarius Doxa Setup — dedicated hardware installer

**Status 2026-10-16:** functional Windows-native development preview, **not** a signed public release.

## Product boundary

**Standivarius Doxa Setup** is the hardware driver installer and troubleshooting/support product for Doxa. It does not install, configure, bundle, diagnose, or require **Standivarius Vision** (the independent low-vision magnification application). Doxa hardware can later serve as a separate test platform for Vision, but that does not merge the products.

Although this work currently shares the canonical local Vision repository due to the active project setup, the Doxa setup source, knowledge base, server routes, model request/response contract and release identity must remain separable.

## First-use interface (ASUS preview update)
- The consent-first welcome now offers **English / Romanian before any local hardware diagnostics**. All welcome instructions, permissions and connection choices switch language live; language switching never grants consent.
- The chosen language carries into the main Doxa equipment + help window. A user can also change languages there. Keyboard Tab order, accessible names for core controls and Enter-to-continue are explicit.
- Local hardware checks require checked consent; cloud AI remains separately opt-in. The installed signed-driver no-op, official vendor MSI gate, unavailable physical hardware and hidden developer simulations are unchanged.
- The extracted portable preview acceptance tests cover both language journeys and refuse any driver or display mutation.
- On ASUS without Doxa hardware only disconnected/offline behaviour is verified; an attended owner visual UI review and real connected-hardware verification remain separate.

## Personal workflow

- `Start-DoxaSetup.ps1`: native Windows setup interface, language switch (English/Romanian), live signed driver and physical-panel inventory, separate RDP/console display facts, action-oriented Doxa help chat and **Install signed driver**. Safe fault demonstrations and supervised reinstall are **hidden from normal users**, accessible only with the explicit `-DeveloperTests` switch.
- `Get-DoxaSetupExperience.ps1`: read-only Windows machine and current session facts, explicitly not treating Remote Desktop's single screen as missing physical hardware.
- `Get-DoxaKnowledgeAnswer.ps1`: **offline, no-web-search** answers from curated `../knowledge/entries.json` with explicit source references. Unknown questions get a knowledge-gap response.
- `Ask-DoxaInstaller.ps1`: optional HTTPS LLM assistance; calls only the dedicated `doxa-installer-assistant` endpoint, never Vision's `ask_visual` service. Until published and configured, the interface uses offline curated help.
- `Test-DoxaPackageGate.ps1`: verifies exact known-original signed Silicon Motion MSI by SHA-256 and publisher signature, without running the installer.
- `Invoke-DoxaPersonalInstallation.ps1`: accepts only the verified original MSI, returns no-op when the known signed driver is already installed, otherwise uses Windows Installer under explicit user-approved UAC; no policy tampering or automatic reboot. This is a local qualification of one package version, not a general-purpose MSI runner.
- `Get-DoxaEnterprisePreflight.ps1`: read-only machine information for later Intune testing; does **not** read or modify actual tenant licences/policies.

### Run locally

```powershell
& .\app\packaging\doxa-setup\personal-ui\Start-DoxaSetup.ps1
```

The currently open old window must be closed/reopened to load revised code. The standard window has **no Try button or simulated error selector**; it focuses on actual detection and next actions. The `-DeveloperTests` switch is internal testing only, not included in ordinary first-run behavior. Normal installation selects a **local MSI file already downloaded lawfully from Silicon Motion**, not a Standivarius-bundled copy. It is refused if package signature/hash differs from the pinned known-original MSI. If the signed driver is already installed, the normal installation does nothing.

Advanced destructive reinstall is intentionally **not** the default customer journey and requires a separate human confirmation plus UAC; test it only when the operator can maintain a reliable Windows session. Neither the LLM nor any fault simulation can start it.

### Portable personal preview

The chat panel reports detected Doxa setup problems and allows the user to ask follow-up installation questions in EN/RO. Both online and offline assistance enforce the same Doxa-only scope policy: unrelated subjects are declined locally; genuine Doxa questions without verified evidence receive a knowledge-gap response. The current alpha shows a chat transcript but evaluates each question independently, so follow-up questions should identify the relevant screen, cable or driver.

The standalone ZIP is assembled by `app\\packaging\\doxa-setup\\Build-DoxaPersonalBundle.ps1`. Find the latest `Standivarius-Doxa-Setup-personal-preview-*.zip` under `artifacts\\releases` on Dell.

Extract it outside the repository and double-click **Open Doxa Setup.cmd**. The launcher runs the normal Windows PowerShell application without changing Windows execution policy. `README-FIRST.txt` describes its supported trial workflow. The bundle includes driver diagnostics, verified-package gating, offline curated help and the Cloudflare AI client, but **does not bundle vendor MSI, raw device IDs, local API keys or private RSA signing material**.

`Test-DoxaPersonalBundle.ps1 -BundlePath <path> -LiveAI` unpacks the ZIP into a separate temporary location, verifies all 12 bundled source hashes and exercises the installer journey without modifying drivers. On enrolled Dell it also tests a signed live Cloudflare response. The installer deliberately remains read-only if a simulated fault is selected; when signed Doxa 4.7.6.0 is already present, clicking Install driver does not open a package selector. The official Silicon Motion download link remains available if a verified installer is actually needed.

The ZIP is an **unsigned personal preview**; public distribution requires Standivarius signing, installer packaging and permissions for any future bundled Silicon Motion binaries. This is only Doxa hardware Setup, **not** the separate Standivarius Vision product. A Mac-like UI appearance pass remains deferred until functionality is validated.

### Tests

```powershell
& .\app\packaging\doxa-setup\personal-ui\Test-DoxaSetupExperience.ps1
& .\app\packaging\doxa-setup\personal-ui\Test-DoxaGatewayClient.ps1
node --test .\app\packaging\doxa-setup\assistant\worker.test.mjs
python dev-harness/check.py
```

The tests check real Doxa detection, installed driver packages versus currently connected devices, RDP versus console, safely hidden fault overlays, package identity, offline fallback, answer provenance and authenticated model boundary. **The live model and full signed Dell client path have since been validated**, but enterprise Intune enrolment and a public signed installer release are still pending.

## Curated knowledge / LLM

The separate service `../assistant/worker.mjs` retrieves evidence from the 14-entry reviewed installation knowledge pack. The runtime has no search engine or dynamic web-retrieval capability. Only summarised, reference-linked material sourced from Silicon Motion, Microsoft and explicitly labelled Dell device observations is sent to the model. If no entry matches, the assistant says the topic is not covered without calling the model. Requests never include USB serial IDs, screenshots or full system logs.

The **separate Doxa Cloudflare Worker is deployed and functional** with native Cloudflare Workers AI (`@cf/zai-org/glm-4.7-flash`) and automatic Dell request signatures. No MiMo/NVIDIA provider API key, copied client token or user-entered Cloudflare secret is needed. The signing/approval of the Doxa binary and the licence to bundle Silicon Motion's MSI are separate release gates.

Vendor driver is already Microsoft-signed; that does not sign Standivarius' installer executable. Code signing (e.g., Microsoft Artifact Signing) is needed for trusted public distribution of our own binaries. Microsoft Store MSIX qualification is a separate possible distribution option. Signing is not yet purchased or performed.

## Tenant and enterprise scope

The Azure for Students **Azure credit** is not an Intune licence. Some universities grant Intune for Education through Microsoft 365 Education licences, but usage and administrative enrolment depend on that tenant's exact entitlements. Microsoft supports a time-limited Intune trial for eligible work/school accounts. No production tenant changes, purchases or Intune policies have been made.

## Implementation status / separate gates

**Built/tested locally:** driver/panel detection, RDP separation, approved-source package validation, bounded vendor MSI install action, offline curated answers, dedicated model backend with mocked model tests, Windows UI.

**Completed:** dedicated live Doxa Worker, real native model response, signed Dell request verified by the Worker, read-only feedback to the Windows client. **Pending:** GUI full attended user-journey test, actual physical driver reinstall where appropriate, signed self-contained downloadable installer, OEM redistribution permissions and Intune-managed pilot.

The first functional product matters more than Mac-like visual polish; the owner explicitly deferred appearance research.

## Device-centred interface and multi-device AI developer gate
The main UI includes an original Windows-drawn three-screen Doxa illustration, a true-data status badge (not connected/verified/check), plain-language offline connection guide and screen-reader labels. The illustration never masquerades as hardware proof. English is prioritized; Romanian is placeholder-quality. The preview performs no driver installation without an explicit separate user action and vendor MSI gate.

The AI client supports per-Windows-user DPAPI RSA identities. An operator prepares enrollment with Get-DoxaDeviceSignature.ps1 -PrepareEnrollment, which outputs a public JWK/client ID, never a private key. The operator must approve only the public JWK on Cloudflare and deploy Worker source; until then offline assistance remains functional. Old Dell signed requests remain accepted in updated worker code. No secrets are bundled.

The Worker model is native Cloudflare Workers AI, not Dify. The curated knowledge set is a deliberately small functional sample, not a complete support knowledge base. The assistant cannot run commands or repair drivers.

### Doxa AI troubleshooting release matrix, 26 October 2026
Test-DoxaTroubleshootingMatrix.ps1 exercises 11 evidence-supported and negative Doxa prompts in EN/RO (USB black screens, RDP, policy block, flicker, SetupAPI, untrusted MSI, knowledge gap, disguised culinary questions), validates source provenance, fail-closed AI consent and endpoint pinning. It makes zero network/model calls and no Windows changes. The 17 Worker tests separately exercise signing, tampering, rate limits, source checks and model mocks. Real signed Dell cloud AI calls require separate explicit invocation. Physical display/driver faults are never induced by the matrix.

### Automated compact-screen and consent UI acceptance
Test-DoxaUILayout.ps1 now runs 10 offline Windows Forms smoke cases in EN and placeholder RO: welcome consent defaults, keyboard tab order, English/Romanian selector, privacy notice, source of device illustration, controls hidden for customers, full layout plus 440/480/522-pixel compact widths. The main customer UI reserves 30 pixels beyond the side panel for vertical-scrollbar width, puts the full-width signed-driver action on its own row, and never exposes developer fault injection. CompactTestWidth is strictly smoke-only and refuses ordinary setup invocation. This validates bounds and control contracts; human visual/assistive-technology review remains separate.
