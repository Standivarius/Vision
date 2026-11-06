# Standivarius Doxa Setup — separate curated AI service

**Live development endpoint:** https://doxa-installer-assistant.marius-moldovan.workers.dev

This assistant belongs to **Standivarius Doxa Setup (hardware installation)**, **not** Standivarius Vision (independent low-vision software). It does not install or modify any software, driver, security policy or firmware.

## No manual API credentials

- Uses the native Cloudflare Workers AI binding **AI** with `@cf/zai-org/glm-4.7-flash`. No external Xiaomi/NVIDIA key is needed; no provider secret is stored on the Worker.
- Every Doxa Setup installation automatically generates its own RSA 2048 key pair on first Online AI use. The **private key** stays encrypted in that Windows user's `%LOCALAPPDATA%\Standivarius\DeveloperAccess\DoxaSetup\client-rsa-key.dpapi` file with DPAPI, outside this repository.
- The installed client sends its *own* public JWK with its derived pseudonymous device ID and a signature over the exact UTF-8 request body and short timestamp. Cloudflare checks the signature and that the ID matches the public key. The historical Dell public JWK remains bundled for legacy-client compatibility, not as a shared secret.
- There is **no copied token, no login prompt, no manual approval and no user-administered API key**. Public keys are self-registered at first signed use; this proves possession of the private key, **not** genuine installer provenance or purchase.
- Native rate limits: four AI calls per installation and 20 per network per 60 seconds per Cloudflare location. A SQLite Durable Object enforces an atomic global daily limit of **300 paid model attempts** (configurable). This is a request allowance, not a financial guarantee; Cloudflare usage may still be billed and needs monitoring.

## Knowledge and safety

- Strict Doxa-only scope is checked **before AI inference** using `../knowledge/scope-policy.json`. Unrelated questions are refused without calling the model; the same policy is applied in the offline and Windows client layers. Doxa-related questions without matching evidence return a knowledge gap, not a guessed answer.
- All retrieval is from `../knowledge/entries.json` (14 independently summarized Silicon Motion/Microsoft/Doxa observation topics). No browser/search tool or dynamic web retrieval.
- Only allowlisted read-only hardware and Windows diagnostic facts are sent to the model; no device serials, screen capture, log uploads or secrets.
- No matched source means no model call and an explicit knowledge-gap response.
- Request signing prevents unauthenticated body tampering and replay beyond the short timestamp window, but anyone can generate a self-signed installation identity. Network and daily limits protect the public endpoint. The model may explain installation steps but cannot issue privileged commands.
- Dell RDP logical monitor count is not proof of external panel failure. Similarly, an original Silicon Motion driver package can remain in the Windows Driver Store even when no Doxa hardware is currently connected; absence of the present device is not proof the driver was uninstalled.

## Implementation and validation

- `worker.mjs`: authenticated Cloudflare Worker and native AI binding.
- `curated-kb.mjs`: retrieval over curated official-source excerpts.
- `client-public-key.json`: legacy Dell public key, retained for old signed clients only.
- `../personal-ui/Get-DoxaDeviceSignature.ps1`: local automatic DPAPI enrollment and per-request signatures.
- `../personal-ui/Ask-DoxaInstaller.ps1`: read-only personal UI client, signed POST to dedicated Doxa endpoint. Do not call the Vision assistant.

Validation:

```powershell
node --test .\app\packaging\doxa-setup\assistant\worker.test.mjs
& .\app\packaging\doxa-setup\personal-ui\Test-DoxaGatewayClient.ps1
& .\app\packaging\doxa-setup\personal-ui\Start-DoxaSetup.ps1 -Smoke
```

**5 November 2026 local universal-access implementation:** 21 Worker unit tests pass, including freshly generated identities without allowlist, malformed signatures, consent, IP/device rate limits and SQLite global budget. PowerShell signed-client and policy tests also pass. The *current deployed* Worker still uses Dell-only authentication, and universal live operation remains blocked until the Worker and new installer are deployed and tested together.

## Future releases

The first commercial release still needs a signed Standivarius binary, OEM redistribution clearance if bundling the Silicon Motion MSI, identity recovery/rotation policy, final privacy/processor documentation and complete attended installer validation. Do not overwrite or couple the independent Vision Worker.

### Deployment and acceptance gate (5 November 2026)
Universal access requires deploying the updated `worker.mjs` and `wrangler.toml` **before** distributing the matching new installer. The cloud service must have the AI binding, both rate limit bindings and the SQLite-backed `DOXA_BUDGET` Durable Object migration. Its global allowance defaults to 300 model attempts per UTC day. The old server must not be described as universal.

In the Doxa assistant directory, after authenticating with a Cloudflare account granted **Workers Scripts Write** (or Workers Editor/Admin), deploy using Wrangler. Do not use the independent Vision Worker. Then run a signed live AI request from an isolated fresh Windows profile, and repeat from Dell. Confirm `GET /health` reports `authentication=automatic-device-signature` and `manual_device_approval=false`. No device public-key allowlist may be required for a fresh profile. Preserve the original Dell identity throughout.

**Current blocker:** the connected Cloudflare app returned HTTP 403 on an attempted isolated, non-production deployment write. It needs `workers-scripts.write`, `workers-scripts.edit` or `workers-scripts.admin` authorisation. The current live Worker is still Dell-only. No amount of installer rebuilding fixes that until backend deployment succeeds. Do not publish the new installer as universally functional yet.
