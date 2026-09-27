# Doxa Visual Assistant Worker

Thin server-side gateway for Visual's optional `Ask Visual` fallback.

Current development backend:

- Dify app: `Visual Assistant`
- Dify app ID: `c94b6e55-3f7f-4b8f-a2d2-99fe960959a1`
- configured Dify model: `Muse Spark 1.3 Contributor`

Secrets required in Cloudflare:

- `DIFY_API_KEY` - key belonging to the dedicated Visual Assistant Dify app.
- `VISUAL_ROUTE_TOKEN` - high-entropy development route token. Visual's configured endpoint is `/v1/ask/<token>`.

Neither secret belongs in Git or in the Visual executable.

The route-token scheme is a development control, not the final Doxa device-authentication design.

## Contract

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

The Worker allowlists and normalizes context fields before sending them to Dify. It does not forward arbitrary client fields.

Response:

```json
{
  "schema_version": "1",
  "title": "Ask Visual",
  "answer": "..."
}
```

`GET /health` is public and reports only service/configuration identity, never secrets.