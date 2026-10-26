# Standivarius Doxa Setup — separate curated AI service

**Live development endpoint:** https://doxa-installer-assistant.marius-moldovan.workers.dev

This assistant belongs to **Standivarius Doxa Setup (hardware installation)**, **not** Standivarius Vision (independent low-vision software). It does not install or modify any software, driver, security policy or firmware.

## No manual API credentials

- Uses the native Cloudflare Workers AI binding **AI** with `@cf/zai-org/glm-4.7-flash`. No external Xiaomi/NVIDIA key is needed; no provider secret is stored on the Worker.
- Dell's personal installer automatically generated an RSA 2048 key pair. Its **private key** stays encrypted in the current Windows user's `%LOCALAPPDATA%\Standivarius\DeveloperAccess\DoxaSetup\client-rsa-key.dpapi` file with DPAPI, outside this repository.
- The public-only JWK is in `client-public-key.json`. Only this public key is deployed to Cloudflare. The personal installer signs the exact UTF-8 request body plus a short timestamp. Cloudflare checks the signature and timestamp with Web Crypto.
- There is **no copied token, no login prompt, and no user-administered API key** for the Dell personal prototype. This one-device alpha identity is not yet the per-device registration mechanism for a public release.
- The native `DOXA_RATE` binding caps requests to four per 60 seconds per Cloudflare location for the registered Dell identity. It is not a global daily spending cap. Cloudflare Workers AI has a daily free allocation but paid Workers usage can incur metered charges above that allocation.

## Knowledge and safety

- Strict Doxa-only scope is checked **before AI inference** using `../knowledge/scope-policy.json`. Unrelated questions are refused without calling the model; the same policy is applied in the offline and Windows client layers. Doxa-related questions without matching evidence return a knowledge gap, not a guessed answer.
- All retrieval is from `../knowledge/entries.json` (14 independently summarized Silicon Motion/Microsoft/Doxa observation topics). No browser/search tool or dynamic web retrieval.
- Only allowlisted read-only hardware and Windows diagnostic facts are sent to the model; no device serials, screen capture, log uploads or secrets.
- No matched source means no model call and an explicit knowledge-gap response.
- Request signing prevents anonymous remote AI calls. The model may explain installation steps but cannot issue privileged commands.
- Dell RDP logical monitor count is not proof of external panel failure. Similarly, an original Silicon Motion driver package can remain in the Windows Driver Store even when no Doxa hardware is currently connected; absence of the present device is not proof the driver was uninstalled.

## Implementation and validation

- `worker.mjs`: authenticated Cloudflare Worker and native AI binding.
- `curated-kb.mjs`: retrieval over curated official-source excerpts.
- `client-public-key.json`: non-secret RSA public key for the currently approved Dell prototype.
- `../personal-ui/Get-DoxaDeviceSignature.ps1`: local automatic DPAPI enrollment and per-request signatures.
- `../personal-ui/Ask-DoxaInstaller.ps1`: read-only personal UI client, signed POST to dedicated Doxa endpoint. Do not call the Vision assistant.

Validation:

```powershell
node --test .\app\packaging\doxa-setup\assistant\worker.test.mjs
& .\app\packaging\doxa-setup\personal-ui\Test-DoxaGatewayClient.ps1
& .\app\packaging\doxa-setup\personal-ui\Start-DoxaSetup.ps1 -Smoke
```

Twelve automated server-side tests passed, including signing and tamper rejection. The live Cloudflare endpoint returned a model-generated answer to a signed Doxa RDP question; the full Dell `Ask-DoxaInstaller.ps1` client returned `status=answered` with `mutating_actions_enabled=false`.

## Future releases

The first public installer still needs a signed Standivarius binary, OEM redistribution clearance if bundling the Silicon Motion MSI, customer-level enrollment/rotation/recovery (rather than one Dell key), spending caps/privacy review, and complete attended installer validation. A Mac-like visual pass is deferred until functionality is stable. Do not overwrite or couple the existing Vision Worker or source files.

### Next-stage device enrolment (tested source, not deployed)
The worker accepts server-approved per-device RSA public JWKs from DOXA_APPROVED_DEVICES_JSON (JSON map of 24-hex client IDs to JWKs) and validates each request signature and timestamp. Existing Dell requests remain supported. Client keys are DPAPI-protected per user and prepared using Get-DoxaDeviceSignature.ps1 -PrepareEnrollment. Server ratelimit keys use approved client identity. No private key, provider token or generated API key is bundled. Connected Cloudflare integration cannot deploy this Worker or update allowlist: HTTP 403, requires workers-scripts.admin, workers-scripts.edit or workers-scripts.write. Do not claim ASUS online AI works until deployed Worker approves device and real signed response is answered.
