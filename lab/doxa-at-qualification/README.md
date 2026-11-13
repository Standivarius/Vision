# DOXA SM770 assistive-technology qualification pipeline

**Status:** v1.0, 13 November 2026. The November physical test programme is closed. This directory provides a durable catalogue, evidence validation, conservative hardware-test adapter and repeatable reports; it does not reopen qualified tests.

## Architecture

The **existing Vision Test Farm**, at lab/automation-harness, remains the general scenario execution, capability-probing, process-isolation and evidence-bundle framework. The existing Doxa physical-acceptance scripts and external-camera evidence remain the source for this hardware qualification. This package adds the missing AT-specific acceptance and traceability layer:

1. **Cases** (cases.json): stable 24-case inventory with agreed verdict, basis and precise source files. Historic programme: 19 PASS, two NVDA features NOT APPLICABLE, three performance measurements recorded.
2. **Historical audit** (pipeline.py): validates schema, duplicate IDs, status/basis contract, path containment, file presence, SHA256 and evidence byte size. Missing proof causes a nonzero exit and cannot be turned into a green result.
3. **Closeout export** (pipeline.py closeout): one immutable new output folder with qualification.json, qualification.junit.xml, qualification.html and SUMMARY.md; the raw images, ETLs and original result JSONs are linked but never rewritten.
4. **Future physical run** (Invoke-DoxaATTest.ps1): explicitly gated, one-case-at-a-time adapter for the already verified wide-window and Word/Edge/Excel scenarios. It uses the canonical physical-display preflight and copies a source harness script to a **new run folder**, redirecting the hard-coded historical output path. Original run folders are never overwritten.
5. **Quality checks** (test_pipeline.py): pure Python tests for schema, security, missing evidence, JUnit/HTML exports, hashes and overwrite refusal, run by pytest. The hardware cannot safely be tested on ordinary GitHub runners.

The acceptance ledger records **what is accepted**, not what the assistant speculates. Original evidence records remain unchanged, and the acceptance basis distinguishes observed results from the owner's Freeze or other scope decision.

## Existing Vision Test Farm integration

The standard farm now discovers the read-only scenario **doxa_at_evidence_audit** in lab/automation-harness/scenarios. It validates the existing physical evidence with the ordinary farm capability resolver, process runner, assertion oracle, run bundle and aggregate reporter. **This runs only the evidence audit; it does not start an assistive application or run physical tests.**

    python lab/automation-harness/tf_cli.py dry-run --scenario doxa_at_evidence_audit
    python lab/automation-harness/tf_cli.py run --scenario doxa_at_evidence_audit

The first local registered farm run on Dell passed on 13 November 2026 with 1 PASS, 0 FAIL. The schema file must use **UTF-8 without BOM**, because the legacy farm reader is strict about the BOM. Do not modify tf_schema.py or tf_runner.py merely for this scenario.
## Daily commands

Run from C:\dev\Vision. These do not launch ZoomText, NVDA or Windows Magnifier:

    python lab/doxa-at-qualification/pipeline.py catalogue
    python lab/doxa-at-qualification/pipeline.py audit
    python -m pytest lab/doxa-at-qualification/test_pipeline.py -q

Generate a new read-only closeout record, choosing a **new** output folder each time:

    python lab/doxa-at-qualification/pipeline.py closeout --output artifacts/doxa-at-closeout-runs/20261113-example

Inspect the current physical-console topology without running an AT scenario:

    python lab/doxa-at-qualification/pipeline.py preflight
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/doxa-at-qualification/Invoke-DoxaATTest.ps1 -Case WideNone -Preflight

Preview a future test without doing anything:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/doxa-at-qualification/Invoke-DoxaATTest.ps1 -Case AppsZoomText

A future owner-approved physical run requires **both** -Execute and -PhysicalApproval. It also requires an unlocked physical Windows console and exactly four qualified display paths. **Do not run it merely to check this closeout**:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/doxa-at-qualification/Invoke-DoxaATTest.ps1 -Case WideNone -Execute -PhysicalApproval

Approved adapter cases: WideNone, WideMagnifier, WideNVDA, WideZoomText, AppsMagnifier, AppsNVDA and AppsZoomText. Only **one** may run at a time. It checks no competing AT processes, no pre-existing Office session in app mode, FFmpeg availability and the existing read-only display preflight.

## Boundaries and evidence rules

- Historical report sources are **dated records**; v2 functional/performance reports in docs/project/hardware are canonical current decisions.
- The physical tests have **already passed** in the agreed programme. The new adapter is for a genuinely new hardware/configuration qualification, not an automatic rerun.
- No driver, PnP, USB-C, display mode, firmware, Wi-Fi or registry mutation is part of this pipeline. No Windows reboot or automatic ZoomText trial reset. The adapter only launches the known tested applications **when explicitly approved**, stores evidence, and checks its own exit/status.
- Verify physical source display and optical captures separately from UI Automation or screenshot/COM readback. A process running or a menu command returning successfully is not an optical oracle.
- Use physical-DPI-aware coordinates. Some PowerShell operations report DPI-virtualised coordinates, which must not be interpreted as reduced native resolution.
- Re-validate every fixture after a Windows restart and do not assume stable DISPLAY numbers.
- Never run the historical stage scripts directly when they write fixed filenames into historic evidence directories. Use the gated adapter's unique run directory.
- Performance snapshots must record whole-machine vs per-process CPU units and sample lengths; do not equate GPU event counts with displayed frame rate.
- Do not use GitHub CI as proof of physically tested Doxa functionality. CI only tests the pure ledger/scaffolding code. The raw local evidence is deliberately not uploaded to GitHub by this system.
- The future live adapter is a **new operational wrapper**, tested in plan/preflight/refusal modes, **not** newly certified with full physical execution. Future live qualification needs normal first-run review.

## Current outputs and reports

- Functional qualification v2: docs/project/hardware/2026-11-13__doxa_sm770_functional_qualification_v2.0.md.
- Performance investigation v2: docs/project/hardware/2026-11-13__doxa_sm770_performance_qualification_v2.0.md.
- Local machine-verified ledger: artifacts/2026-11-13__doxa_sm770_qualification_ledger_v2/.
- Original 10 Nov/12 Nov reports and all 11–13 November JPEG, JSON, ETW and log files remain in place.
- The existing Vision Test Farm is documented in lab/automation-harness/README.md. Its original scenarios remain untouched; this qualification package is a small domain adapter, not a second test farm.


## Test scaffolding inventory

The full scoped folder inventory, retained historical suites, execution-risk classification and migration/stop rules are documented in lab/doxa-at-qualification/INVENTORY_AND_MIGRATION.md. Existing experimental scripts are not automatically executable through the new pipeline.

