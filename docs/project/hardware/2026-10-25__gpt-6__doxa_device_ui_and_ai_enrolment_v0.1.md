# Doxa English-first UI and device-scoped AI - ASUS evidence

Scope: Doxa Windows installer only. No changes to Vision magnifier, OEM driver, Dell or endpoint management.

## Implemented
- Device-first three-panel original Windows vector illustration; live status displays real read-only diagnostics only, not inferred from art.
- Offline Connection steps action, driver and permission safeguards, screen reader labels.
- Two-column normal desktop layout and stacked scrollable portrait/RDP layout.
- English UI first; Romanian is placeholder quality. Screenshot attached is the actual no-consent narrow RDP view, NOT physical connected Doxa evidence.
- Multi-device local identity: RSA key stored as Windows DPAPI CurrentUser, exported public JWK plus derived client ID, no key in ZIP.
- Worker accepts legacy Dell signed requests or explicitly server-approved per-device public JWKs in DOXA_APPROVED_DEVICES_JSON, verifies signatures/timestamps, rate limits per approved device.
- Cloudflare planner preview config [previews] only; no production deployment.

## Test evidence
- Node Worker tests 17 PASS: signed/tamper, no consent, refusal, KB gaps, unapproved device, approved device, per-device rate limit.
- Windows client mocked signed request and offline knowledge tests PASS.
- Extracted ZIP test passes 16 source hashes and 19 files; no vendor MSI, credentials or driver mutation; EN/RO journeys and test enrollment PASS.
- Rendered ASUS Windows Forms UI in an RDP portrait window; owner visual assessment still pending.

## Blocker
Cloudflare account is readable but connecting tool has no workers-scripts.write, workers-scripts.edit or workers-scripts.admin scope. Separate ASUS test Worker upload returned HTTP 403; NO WORKER DEPLOYED and NO LIVE ASUS AI verified. Cloudflare model is native Workers AI, not Dify, and no extra model API key is required. To enable ASUS, grant a Workers script write scope, deploy reviewed Worker code, add ASUS PUBLIC JWK to its allowlist and test the signed response. Retain Dell legacy signer.

Other gates remain distinct: public signing, OEM MSI redistribution, attached hardware and owner GUI walkthrough.
