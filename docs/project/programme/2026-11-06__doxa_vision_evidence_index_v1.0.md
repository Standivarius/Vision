# Doxa four-display qualification and Vision resource evidence — curated index

**Captured:** 6 November 2026. **Sources:** nine exact, unchanged documents copied from the existing local Dell Vision repository. Their original SHA-256 hashes and byte lengths are in `2026-11-06__doxa_vision_curated_evidence_manifest_v1.0.json`. Run `scripts/release/Test-CuratedEvidenceIntegrity.ps1` to verify the checked-in copies. Earlier dated material is retained locally, not overwritten.

## What is and is not qualified

**4 November:** Doxa on Dell had four active screens (laptop and three SMI770 USB displays) and a signed Silicon Motion driver. The 17-field comparison documents Microsoft Magnifier, NVDA 2026.2 and ZoomText 2026; SuperNova 25.05 was *research/documentation only*, not a fourth live qualified application. Bounded test results are not interchangeable with formal user acceptance. Read `2026-11-04__doxa_17_field_comparative_synthesis_v1.2.md` and `2026-11-04__doxa_17_field_execution_ledger_v1.1.csv` together. Distinguish `PASS_PHYSICAL`, `PASS_BOUNDED`, `DOCUMENTED_ONLY`, `NOT_DEMONSTRATED`, `NOT_RUN` and `INCONCLUSIVE`.

- **Microsoft Magnifier**: strongest optical/physical evidence for independent laptop magnification and specific four-screen tasks; not a blanket product compatibility certificate. Details: `2026-11-04__doxa_qualification_report_microsoft_magnifier_v1.0.md`.
- **NVDA 2026.2**: screen reader and bounded four-screen interactions demonstrated; do not describe it as providing a native zoom/magnifier mode. Panning was inconclusive and simultaneous cross-app tests remained unrun. Details: `2026-11-04__doxa_qualification_report_nvda_v1.0.md`.
- **ZoomText 2026**: bounded physical and trial-backed tests, no demonstration of source-to-centre shared Detail or independent laptop-only zoom; some viewing modes documented only. The 4-screen CPU observations are Dell-specific, not a universal superiority claim. Details: `2026-11-04__doxa_qualification_report_zoomtext_v1.1.md`.

**Independent quality review:** `2026-11-04__gemini_doxa_17_field_independent_acceptance_review_v0.1.md` raised evidence-validity concerns. The subsequent `2026-11-04__gemini_execution_report_and_response_to_independent_review_v1.0.md` records the repaired ledger and narrower claims. Preserve both; no final independent certification is implied.

**5 November changed the physical state:** `2026-11-05__vision_resource_attribution_w0_decision_v0.1.md` recorded a disconnected/unpowered Doxa and only one observable Windows console display. That later state does not invalidate the documented November 4 bounded tests, but it means a four-screen *new* run could not be reproduced on 5 November without reconnecting hardware.

**Vision resource attribution:** `2026-11-05__vision_gemini_resource_attribution_execution_summary_v1.0.md` validates the measurement harness and narrows prior claims. It suggests static-frame presentation churn as a bottleneck candidate, but the proposed event/state-driven optimisation was **not** implemented, validated as a general fix, or added to the published Vision alpha. Later source performance claims must use new matched evidence.

## What remains local, not on GitHub

Raw camera photographs, benchmark traces, app installation-state captures, guarded ZoomText trial data, W0/W1/W2 resource-attribution CSVs and many historical reports remain in the Dell `artifacts/` and `docs/project/programme/` folders. **This GitHub evidence index is curated reporting, not a remote backup of all raw data.** Before deleting old local worktrees or generated artefacts, verify all cited paths, retention and source hashes. The owner has not authorised wiping those data.

## Software/release boundary

These qualification reports are **tests of Doxa hardware with other applications**, not features bundled into Doxa Setup. **Vision** is a separate Windows low-vision application released through its existing Velopack alpha channel. The Doxa installer includes the Silicon Motion MSI and independent Doxa-only AI support; Vision must not bundle, replace or implicitly certify those components. See root `RELEASE_TRACKS.md` and `2026-11-06__vision_doxa_release_register_v1.0.md` for current release gates.