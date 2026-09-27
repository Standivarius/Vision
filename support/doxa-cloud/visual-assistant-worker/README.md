# Doxa Visual Assistant Worker

Thin server-side gateway for Visual's optional `Ask Visual` fallback.

Current development backend:

- Dify app: `Visual Assistant`
- Dify app ID: `c94b6e55-3f7f-4b8f-a2d2-99fe960959a1`
- configured Dify model: `Muse Spark 1.3 Contributor`

Secrets required in Cloudflare:

- `NVIDIA_API_KEY` - NVIDIA API key used by the primary hosted NIM request.

- `DIFY_API_KEY` - key belonging to the dedicated Visual Assistant Dify app.
- `VISUAL_ROUTE_TOKEN` - high-entropy development-only route token for `/v1/ask/<token>`.
- `DOXA_CLIENT_TOKEN` - shared alpha client credential for the packaged `/v1/ask` bearer-authenticated route.

`NVIDIA_API_KEY`, `DIFY_API_KEY` and `VISUAL_ROUTE_TOKEN` stay server-side. Alpha Visual builds contain the existing Doxa client credential so fresh installs can use `/v1/ask` without per-machine setup. This is intentionally temporary: a shared embedded client credential is not the final Doxa device-authentication design.

## Generated Worker and knowledge grounding

`worker.js` is generated from `worker.template.js` plus the knowledge set in `../visual-assistant-knowledge/`. Do not hand-edit the generated Worker for lasting changes.

The knowledge layer has two deliberately bounded sources:

1. curated, paraphrased and source-attributed official ZoomText, SuperNova and Windows Magnifier material; and
2. a generated read-only mirror of an explicit allowlist of current Visual runtime/help/settings/tracking source and documentation.

The model never receives filesystem or repository access. The Worker performs deterministic retrieval and normally sends at most seven matching chunks and roughly 12 KB of reference evidence with a question. Current Visual source/docs outrank incumbent material for claims about Visual; official incumbent material describes only the named incumbent product; project migration research is lower-authority interpretation.

Generate/update the mirror and Worker:

```powershell
.\support\doxa-cloud\visual-assistant-knowledge\build-knowledge.ps1
```

Verify that the checked-in mirror still matches its canonical source files:

```powershell
.\support\doxa-cloud\visual-assistant-knowledge\build-knowledge.ps1 -Check
```

A source change to an allowlisted file intentionally makes `-Check` fail until the snapshot is regenerated and reviewed.

## Contract

Packaged alpha route:

`POST /v1/ask` with `Authorization: Bearer <DOXA_CLIENT_TOKEN>`.

Development override route:

`POST /v1/ask/<VISUAL_ROUTE_TOKEN>`

Request:

```json
{
  "schema_version": "1",
  "intent": "ask_visual",
  "question": "...",
  "context": { "zoom": 2.0 }
}
```

The Worker allowlists and normalizes context fields before retrieval or forwarding. It does not forward arbitrary client fields.

Response:

```json
{
  "schema_version": "1",
  "title": "Ask Visual",
  "answer": "...",
  "knowledge": {
    "source_tree_sha256": "...",
    "chunk_ids": ["..."]
  }
}
```

The `knowledge` trace contains non-secret IDs for validation/audit; Visual currently ignores these fields. `GET /health` is public and reports service/configuration identity, the retrieval version, knowledge chunk count and source-tree digest, never secrets.