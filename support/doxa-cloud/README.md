# Doxa lab cloud planner

`lab-proxy.ps1` is a temporary test backend for the Doxa installer pilot. It is not the production cloud service.

The second PC authenticates to this proxy with an expendable lab token. The proxy holds the model-provider credential and calls either Dify Cloud or Meta/Muse. Provider credentials never belong in the pilot ZIP.

## Visual Assistant development gateway

Visual's optional `Ask Visual` fallback now has a separate cloud path from the installer planner:

`Visual -> doxa-visual-assistant Cloudflare Worker -> NVIDIA NIM / Nemotron 3 Super 120B A12B`

The tracked Worker source is in `visual-assistant-worker/`. The deployed development Worker is `doxa-visual-assistant` at the account's `marius-moldovan.workers.dev` subdomain.

The primary hosted model is NVIDIA NIM `nvidia/nemotron-3-super-120b-a12b`. The dedicated Dify `Visual Assistant` app (Muse Spark 1.3 Contributor) remains configured as a temporary fallback.

Cloudflare stores three Secrets for the Worker:

- `NVIDIA_API_KEY` - the primary Ask Visual NVIDIA key;
- `DIFY_API_KEY` - the dedicated Visual Assistant Dify fallback key;
- `VISUAL_ROUTE_TOKEN` - a high-entropy development-only route token.
- `DOXA_CLIENT_TOKEN` - the shared alpha client credential accepted by the packaged `/v1/ask` route.

`NVIDIA_API_KEY`, `DIFY_API_KEY` and `VISUAL_ROUTE_TOKEN` remain server-side and never belong in Visual, Git, `wrangler.toml`, logs or support bundles. Alpha release builds embed the existing `DOXA_CLIENT_TOKEN` client credential so a fresh install can call the Doxa-owned `/v1/ask` route without Dell-specific configuration. This shared client credential is an alpha mechanism and is not the final per-device authentication design. `VISUAL_ASSISTANT_ENDPOINT` remains a developer/test override only.

The Worker allowlists the structured Visual context fields before sending anything to the hosted model. It deliberately drops unknown client fields such as raw monitor device identifiers. Screenshots, document contents and typed text are not part of the contract.

Before an online question is sent to the hosted model, the Worker also retrieves a small evidence set from `visual-assistant-knowledge/`: curated official incumbent terminology/behavior plus an explicit read-only mirror of current Visual source/docs. The model never receives repository access. Current Visual source/docs are authoritative for Visual implementation claims; official incumbent evidence applies only to the named product; project migration research is lower-authority interpretation. Regenerate with `visual-assistant-knowledge\build-knowledge.ps1` and use `-Check` to detect a stale mirror.

The route-token scheme is a **development control**, not the production Doxa authentication design. A production service still needs device/client authentication that does not rely on one shared client secret.

NVIDIA Nemotron is the current primary Ask Visual backend. Dify/Muse remains a temporary server-side fallback. The Visual client remains provider-neutral and contains no model-provider credential.
## Current lab app

The installer pilot now uses the published Dify Chatflow `Doxa Installer Planner` (app ID `4568517a-3cec-4f05-a4f4-add9f177206a`) with the `Muse Spark 1.3 Contributor` model through the verified OpenAI-compatible provider.

The app API key is stored server-side on MARIUS-DELL for the lab and must never be copied into the pilot ZIP.
## Dify mode

Create an app API key inside the Dify app. To avoid putting the key in chat or command history, store it locally on MARIUS-DELL with:

```powershell
.\support\doxa-cloud\configure-dify-key.ps1
```

The helper prompts locally, does not print the key, and stores it only in the current Windows user's environment for this lab. Use `-Clear` after the pilot if desired. Then run:

```powershell
$env:DOXA_LAB_TOKEN = '<temporary-random-token>'
.\support\doxa-cloud\lab-proxy.ps1 -Port 8791 -Provider Dify
```

The proxy uses Dify Cloud's app API base `https://api.dify.ai/v1` and `POST /chat-messages` in blocking mode. It sends the structured installer state inside a constrained planner prompt and accepts only actions present in `app/packaging/doxa-setup/approved-actions.json`.

### Planner audit evidence

The permanent Worker returns the Dify `task_id` (when present), `message_id`/`id`, and `conversation_id` with every `ai_plan`. These are execution identifiers returned by Dify and are safe to retain in setup evidence.

The Worker also returns the configured, non-secret planner identity from tracked Worker configuration: app ID/name and model ID/name (`muse-spark-1.3-contributor` / `Muse Spark 1.3 Contributor`). These fields are explicitly labelled as configured identity (`model_identity_source=worker_config`); they are not presented as model-name fields returned by the Dify Service API. The Dify message/conversation IDs are the transaction trace keys to correlate with Dify/observability logs when audit-grade proof of the executed model is required.

The Windows setup orchestrator stores the full Worker response in `cloud-response.json` and logs `cloud_ai_trace` with the configured model ID plus Dify message/task/conversation IDs. No provider credential is written to client logs.

For temporary cross-machine testing, expose only the proxy port with an HTTPS tunnel such as Cloudflare Quick Tunnel. Do not expose the repository bridge as the installer endpoint.

## Meta fallback

`-Provider Meta` exists only to validate the planner transport when a Dify app API key is unavailable. It uses `META_API_KEY` on the proxy host. The production direction remains client -> Doxa-owned HTTPS service -> Dify/Muse.

## Security boundary

The client sends a small structured state object, not arbitrary command output. The model chooses from an allowlist of diagnostic/escalation actions. The client validates the action again before executing it. Version 1 gives the model no arbitrary command execution, registry editing, security-policy bypass, driver replacement, or unrestricted download capability.
