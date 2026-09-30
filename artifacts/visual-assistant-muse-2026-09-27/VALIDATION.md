# Visual Assistant / Muse live validation - 2026-09-27

## Deployment

- Client: Visual `0.1.0-alpha.6` on MARIUS-DELL.
- Gateway: Cloudflare Worker `doxa-visual-assistant`.
- Public host: `https://doxa-visual-assistant.marius-moldovan.workers.dev/`.
- Dify app: `Visual Assistant`.
- Dify app ID: `c94b6e55-3f7f-4b8f-a2d2-99fe960959a1`.
- Configured Dify model: `Muse Spark 1.3 Contributor`.
- Provider credentials remain server-side.

Cloudflare has two Production Secrets by name:

- `DIFY_API_KEY`
- `VISUAL_ROUTE_TOKEN`

Secret values are intentionally not recorded here.

Visual's current user environment has `VISUAL_ASSISTANT_ENDPOINT` configured to the protected Worker route. The endpoint value is intentionally not recorded because the current development route contains the route token.

## Worker validation

`GET /health` returned HTTP 200 and reported:

- service `doxa-visual-assistant`;
- provider `dify`;
- app `Visual Assistant`;
- configured model `Muse Spark 1.3 Contributor`.

A POST to an invalid route token returned HTTP 404.

A POST to the protected route returned a normal `Ask Visual` answer through Dify/Muse.

The Worker normalizes and allowlists the Visual state object before sending it upstream. Privacy test: an injected unknown field containing a fake raw monitor-device identifier was stripped. The assistant answered that no raw monitor identifier had been provided, and the fake marker did not appear in the response.

## Visual client validation

The first live Visual online test exposed a real timeout issue: the client allowed only 7 seconds for the WinHTTP response, while the hosted Muse/Dify request took roughly 15 seconds. Visual therefore failed soft to local help even though the Worker was healthy.

Correction:

- WinHTTP resolve/connect/send timeout: 5 seconds;
- receive timeout: 45 seconds;
- request remains on the Help window's background worker thread, so the Visual UI remains responsive.

Canonical Release rebuild after the correction: **9/9 CTest tests passed**.

Final live Visual UI test:

- Help / Ask Visual opened normally;
- a question deliberately outside the local help catalog put the Ask button into `Working...` state;
- the online call completed successfully;
- status displayed `Online contextual help`;
- the returned answer correctly used live structured state such as Tracking, Follow Text Cursor, Text Cursor Highlight and View Locator;
- after adding the Dify plain-text rule, the final answer contained no Markdown `**` markers.

## Current security posture

- no Dify key is embedded in Visual;
- no Dify key is tracked in Git;
- the Worker source contains only non-secret app/model identity;
- screenshots, document contents, typed text and raw monitor IDs are outside the client contract;
- unknown context fields are dropped server-side;
- the route token is a development abuse-control measure, not the final production Doxa client-authentication design;
- local Visual help remains available if the online service is unavailable.

## Backend direction

Muse Spark 1.3 Contributor via Dify is the validated development backend while the NVIDIA credential is unavailable. The Visual client contract remains provider-neutral so a future NVIDIA/Nemotron backend can replace Dify/Muse server-side without putting provider credentials or provider-specific logic into Visual.