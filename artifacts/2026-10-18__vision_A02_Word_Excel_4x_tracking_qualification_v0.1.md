# Vision A02 — Word/Excel 4× caret and cell tracking qualification

Date: 2026-10-18
Scope: physical MARIUS-DELL console, **independent software-visible GDI recordings**. Not a physical camera, photonic measurement, or genuine low-vision participant acceptance.

## Verified

**Word, four active displays, earlier run:** the unsaved generated document displayed six alternating yellow/green caret-target highlights. Independent source and magnified Centre captures both showed all six selected targets. The observed source-vs-output frame difference was at most about 443 ms at 2 fps, not precise end-to-end latency. Run: artifacts/vision-poc-a-graphics-20261017/word-4x-visual-alternating-20261018-123727-ab4104/

One earlier long Word run had more than 31 seconds of stale UI Automation evidence and forced preview shutdown. Following a bounded IUIAutomation2 worker transaction timeout (connection 1000ms, transaction 2500ms), two long Word runs kept UIA evidence age below 0.6 seconds and shut down normally. That is not proof of all-day reliability.

**Excel, three active displays, current:** actual Windows desktop presently comprises laptop, external Centre and external Right. Four monitor devices are still present but only three Windows desktop surfaces are active. We did not change display settings. The Excel trial is valid specifically for this three-screen arrangement, NOT four-screen acceptance.

A disposable unsaved Excel workbook selected six known cell addresses. Excel COM and Windows UI Automation independently agreed on all six selected cells and their process/screen ownership. Bright yellow and green cell-region markers were observed separately on the Right source and Centre Detail.

- Qualified run: artifacts/vision-poc-a-graphics-20261017/excel-4x-visual-20261018-150857-0082eb/
- Qualified report: excel-colour-identity-qualified-v2.json within that directory.
- Verdict: PASS_EXCEL_SOURCE_IDENTITY_AND_VISIBLE_MARKERS_WITHIN_2S.
- Evidence: 148 Right frames, 148 Centre frames; all six selected cells and all six visible phases passed.
- Largest observed source-to-Detail sample difference: 468.4ms, at 2fps. NOT photon latency.
- Normal Vision preview shutdown; original foreground and pointer restored; workbook never saved.
- Display count 3 independently recorded; physical console session checked.
- Corroborating run: artifacts/vision-poc-a-graphics-20261017/excel-4x-visual-20261018-150449-d08488/, also six-phase visual PASS but predated the explicit display-count gate.
- The first Excel recording ended before the last selection and was correctly INCONCLUSIVE. It remains retained in artifacts/vision-poc-a-graphics-20261017/excel-4x-visual-20261018-145953-d50fc7/. Recording time was extended; evidence thresholds were not relaxed.

## Assessor controls

- Correct Excel COM target address must equal the Win32 UIA focus address, with nonempty screen rectangle and correct process ownership.
- Independent PNG content must contain the expected phase marker in both source and Centre within the observation window.
- Recorded monitor roles, PNG SHA-256 hashes and frame paths are validated; corruption, role mismatch and path escape are rejected.
- Wrong cell identity, missing output, delayed output, unknown topology, forced preview shutdown or failure to restore source focus cannot earn overall PASS.
- Reused old four-screen assessor code was not changed. A02 adds its own three/four-monitor role resolver and recorder.
- Python assessor regression: 61/61 passed.
- Compiled native C++ CTest regression: 23/23 passed.

## Reproduction, from C:\dev\Vision

First ensure an unlocked physical console, no existing Word/Excel or visual_app process, and no person currently using the displays.

1. Python unit tests: python -m unittest discover -s lab/pocs/doxa/assessment -p "test_*.py" -q
2. Console/display preflight: python lab/pocs/doxa/assessment/A02_display_preflight.py
3. Excel capture: powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/A02-RunExcel4xVisualCapture.ps1
4. Independent verdict: python lab/pocs/doxa/assessment/A02-AnalyzeExcelVisual.py <actual resulting Excel visual run directory>

Word four-screen test is in lab/pocs/doxa/assessment/A02-RunWord4xVisualCaptureAlternating.ps1; it requires a true four-display topology.

## Not yet qualified

Real continuous typing and natural workflows; sustained provider availability; sleep/wake, docking and hot-plug; external-camera panel fidelity; participant usability; and restoring the fourth currently inactive Windows display. The SYSTEM-level RDP-to-console recovery task is still not installed. None of this changes the earlier passed four-screen POC A baseline. No narration or speech feature was developed here.
