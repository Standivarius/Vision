# A04 — Word/Excel 4× text-entry and PageDown orientation experiment

**Date:** 2026-10-18
**Parent product direction:** Vision magnification + caret/focus tracking, MAG-001 and GitHub Vision Project #6.
**Status:** Two bounded strict PASS runs; details in artifacts/2026-10-18__vision_A04_office_edit_4x_qualification_v0.1.md. Not customer validation.

## Hypothesis

On a physical 3- or 4-screen Windows console with ordinary Context (Right)
and magnified Detail (Centre) at 4×, inserting text and PageDown navigation
through keyboard messages in Word and Excel will not leave the active caret
or selected cell outside the magnified viewport.

## Allowed environment and changes

MARIUS-DELL, C:\dev\Vision only. Two newly created unsaved Office test
documents and no existing Office/Vision sessions. Abort if locked/nonconsole,
unsupported topology or competing process. Keep original app focus and
pointer, preserve unrelated files/dirty edits and never touch display
settings, drivers or personal Office documents.

Only new A04 harness/scorer/tests and evidence documents are in scope;
a core application change requires a reproduced Vision defect.

## Stimulus and measurement

Six alternating phases:
Word typed text in selected generated paragraph; Excel edited B2;
Word typed text in another paragraph; Excel edited J24;
Word typed text in a distant paragraph; Excel edited C41.

Every step must confirm (a) intended Office process owns foreground,
(b) Windows SendInput-generated keyboard text is found in the *actual*
unsaved Office document/cell via COM, (c) PageDown generated actual
Word selection or Excel ScrollRow movement, (d) source caret/cell
geometry belongs to the expected active application and Right monitor.

An independent GDI recorder stores 2fps PNG images with SHA-256 manifests
from Context and Detail, plus Windows source truth and Vision diagnostics.
The scorer requires correct visible source and Detail markers, frame
freshness, normal shutdown and unmodified source identity acceptance.

A separately scored strict negative-only veto checks that the OS target
geometry remains inside Vision's recorded viewport for every frame in
the stable phase. The telemetry viewport *cannot* establish a PASS alone.

## Falsification

Wrong/missing text insertion, missing PageDown movement, wrong foreground,
stale/missing UIA or Win32 caret geometry, wrong source monitor, missed
visual target, >2-second observed software frame lag, viewport exclusion,
truncated final phase, unclean process exit, any document saved,
unrestored original focus/pointer -> FAIL or INCONCLUSIVE.

## Limits

Scripted Win32 keyboard events are not genuine human typing.
UIA is intermittently unavailable; a bounded retry may establish fresh
evidence but must not manufacture a passing rectangle.
The software GDI capture is not physical-camera/photo latency.
Do not promote MAG-001 to validated without actual low-vision user,
prolonged workload or hardware evidence.

## Verification

- Source-only: A04-ProbeOfficeEditingStimulus.ps1
- Full run: A04-RunAndQualifyOfficeEditStrict.ps1
- Independent score: A03-AnalyzeOfficeSwitch.py
- Strict viewport veto: A03-QualifyOfficeSwitchCaret.py
- Input/content score: A04-QualifyOfficeEditing.py
- Python regressions: python -m unittest discover -s lab/pocs/doxa/assessment -p "test_*.py" -q
- Dev-harness: python dev-harness/check.py

All outputs go under artifacts/vision-poc-a-graphics-20261017.
