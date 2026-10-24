# Vision A03 — Mixed Word/Excel 4× caret tracking correction and strict qualification

Date: 2026-10-18
Repo: C:\dev\Vision, master
Evidence: unlocked physical Dell console, three active Windows displays: laptop, Doxa Centre Detail, Doxa Right source. Independently recorded software-visible Windows GDI frames, not an external camera.

## The verified defect

A03 alternates Word / Excel / Word / Excel / Word / Excel, each with a
test-owned selected caret or cell and a yellow/green visual marker. The
first new run, office-switch-4x-visual-20261018-161321-e8f182, ended
INCONCLUSIVE on the third phase. At 49.5 seconds, the separately recorded
Right source showed Word's yellow target, but the Centre screenshot showed
different text without that target.

Independent Win32 Word caret geometry placed the target at x=5173 on the
Right source, while Vision's viewport had been moved to x=4497..4977.
The diagnostic trace showed Vision initially following the correct caret,
then dropping it after roughly 0.3 seconds and following a broad UIA
focus rectangle to the document edge.

A separate negative-only caret-containment audit of two historical runs,
office-switch-4x-visual-20261018-155942-6f5683 and
office-switch-4x-visual-20261018-161048-4789f0, exposed a false-positive
weakness: colour-only reports had said PASS even though the Word caret
was outside Detail during at least one stable phase. Those historical
reports were not overwritten or silently relabelled.

## Repair

Files: app/src/core/poi_evidence.h,
app/src/tracking/win32_evidence_provider.h,
app/tests/poi_arbitration_tests.cpp.

Windows GetGUIThreadInfo re-observes a real caret attached to the current
foreground thread every render frame. The policy previously kept the
timestamp from the first observation when the caret stayed still. After
250 ms, that genuinely active caret expired, allowing less precise focus
evidence to pull the Detail viewport away.

The correction permits a still-active Win32 caret to refresh evidence
while its owning foreground thread and target remain the same. It
preserves the deliberate pointer-movement intent barrier: if the pointer
moves after the caret was last activated, an unchanged insertion point
cannot reclaim Detail. New caret geometry or a different process is
recognised as fresh activity.

No broader graphics/magnification/display-setting changes were needed.
Unrelated pre-existing repository edits were not modified.

## Repeated physical-console results after repair

1. **Strict PASS**: office-switch-4x-visual-20261018-162258-41881e
   - 126 independent Right frames and 126 Centre frames
   - six of six application switches visibly correct
   - 100% source caret/cell within Detail viewport in all six stable phases
   - max observed source/Detail sample lag ~401 ms at 2 fps
   - normal preview shutdown; test-created Office instances closed

2. **Strict PASS**: office-switch-4x-long-20261018-162943-5c2298
   - 190 independent Right frames and 190 Centre frames
   - six of six visibly correct, including return-to-Word transitions
   - 100% caret/cell containment throughout all six stable phases
   - max observed source/Detail sample lag ~364 ms at 2 fps
   - normal preview shutdown; test-created Office instances closed
   - strict verdict: office-switch-caret-qualified-v2.json

A separate middle rerun, office-switch-4x-visual-20261018-162650-90e9a9,
showed 100% caret containment but was INCONCLUSIVE in the original
colour-only scorer because the fixed-length capture ended too close to
the final Excel phase, leaving only two target frames. That run was
retained as inconclusive, not promoted to PASS. The strict one-command
runner now records for 95 seconds to avoid this evidence-coverage gap
without reducing minimum stable-phase requirements.

## Stricter evidence qualifications

A03-AnalyzeOfficeSwitch.py remains the independent source/Detail PNG
colour/identity scorer. Added:
- A03-AuditViewportCaretContainment.py: compares controlled Word Win32 /
  Excel UIA source target rectangles with Vision viewport telemetry.
- A03-QualifyOfficeSwitchCaret.py: requires the independent visual PASS
  **and** rejects any documented viewport that excludes the actual target.
  Telemetry can only veto, never by itself establish a PASS.
- A03-RunOfficeSwitch4xVisualCaptureLong.ps1 and
  A03-RunAndQualifyOfficeSwitchStrict.ps1: guarded, repeatable one-command
  GUI capture with an extended evidence window, two-stage scoring,
  original-frame retention and normal cleanup.
- test_A03_caret_containment.py: false-positive and missing-data gates.

Validation: 90/90 Python assessment tests and 23/23 native CTests PASS.
The new Win32 caret/timestamp/pointer regression tests are included in
the native suite.

Run (physical, unlocked Dell console, no existing Word/Excel/Vision):
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab\pocs\doxa\assessment\A03-RunAndQualifyOfficeSwitchStrict.ps1

## Limitations and next milestone

This proves the controlled six-switch software-visible experiment on the
currently active three-screen physical topology. It does not measure
photons on the SMI770 panel, natural human typing/selection, a full workday
of Office workflows, or the fourth currently inactive Windows display.
Prior four-screen POC A qualification remains separate.

Next: bounded natural typing, scrolling and cross-app focus scenarios,
including pointer interruption and explicit recovery, while retaining
independent source pixels, precise OS target evidence, normal shutdown
and a clean physical-console test lock. Screen narration work is not part
of this track.
