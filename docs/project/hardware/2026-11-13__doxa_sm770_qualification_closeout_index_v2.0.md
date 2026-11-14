# Doxa SM770 qualification â€” canonical closeout index

**Decision:** 13 November 2026 | **Programme:** Doxa assistive-technology and performance evaluation | **Status:** **Functional PASS; performance investigation complete with ZoomText CPU advisory.**

## Current reports (replace the historical verdicts)

1. **Functional qualification v2.0:** [2026-11-13__doxa_sm770_functional_qualification_v2.0.md](2026-11-13__doxa_sm770_functional_qualification_v2.0.md)
2. **Performance qualification v2.0:** [2026-11-13__doxa_sm770_performance_qualification_v2.0.md](2026-11-13__doxa_sm770_performance_qualification_v2.0.md)

These are the **two current decision documents**. Original 10 November and 12â€“13 November reports are still present as historical sources; do not quote their early unfinished verdicts as current status.

## Evidence and repeatability

- **Doxa qualification catalogue:** lab/doxa-at-qualification/cases.json â€” 24 entries: 19 PASS, two NOT APPLICABLE, three MEASURED.
- **Audit/exporter:** lab/doxa-at-qualification/pipeline.py â€” path-safe hashing, evidence-checking, HTML and JUnit XML, immutable closeout output folders.
- **Physically guarded live adapter:** lab/doxa-at-qualification/Invoke-DoxaATTest.ps1 â€” plan-only by default, requires explicit dual approval for any live run, never overwrites historical evidence.
- **Pure validation tests:** lab/doxa-at-qualification/test_pipeline.py â€” pytest; hardware-free on CI.
- **Methods and commands:** lab/doxa-at-qualification/README.md.
- **Lessons learned:** lab/doxa-at-qualification/LESSONS_LEARNED.md.
- **Open-source choice:** lab/doxa-at-qualification/OPEN_SOURCE_DECISION.md; existing Vision Test Farm reused.
- **Scaffolding audit and migration:** lab/doxa-at-qualification/INVENTORY_AND_MIGRATION.md.
- **Generated Dell ledger:** artifacts/2026-11-13__doxa_sm770_qualification_ledger_v2/ â€” qualification.json, qualification.html, qualification.junit.xml, SUMMARY.md and software-test JUnit XML.

## Decision boundary

The owner has accepted the agreed functional scope as PASS. The final verdict tables therefore reflect **project acceptance**, not earlier speculative failures. Observed and owner-accepted items are separately recorded in the catalogue without changing raw evidence. NVDA functions that the product does not offer remain NOT APPLICABLE.

The Dell's sustained ZoomText CPU saturation risk is an **operational product caveat**, not a reason to reopen the now-passed functional programme. Additional trials require a new concrete user, hardware or vendor-change question; no repeat of the entire suite is indicated.

**Repository discipline:** preserve all unrelated dirty work. No new Doxa driver, firmware, ZoomText installation, vendor contact or Windows machine reconfiguration is required by this closeout.

