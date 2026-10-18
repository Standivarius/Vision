# Vision A04 — Word/Excel 4x keyboard editing and Page Down qualification

Date: 2026-10-18
Track: Vision magnification, caret/focus tracking, MAG-001 / GitHub Project #6
Environment: MARIUS-DELL, unlocked physical Windows console, three active displays: laptop, Doxa Centre Detail, Doxa Right Context.
Evidence: Windows GDI software-visible screenshots and independently observed Office/Windows source state. NOT physical-camera, photon-latency, or human user acceptance.

## Outcome: TWO CONSECUTIVE STRICT PASSES

First accepted run:
artifacts/vision-poc-a-graphics-20261017/office-edit-4x-20261018-171840-58e2a7/

Second unchanged accepted run:
artifacts/vision-poc-a-graphics-20261017/office-edit-4x-20261018-172202-fc1fc6/

Both runs' office-edit-qualified-v1.json reported:
PASS_OFFICE_EDIT_4X_TYPED_AND_SCROLLED_VISIBLE_WITH_CARET.

In EACH:
- 6/6 expected keyboard text tokens verified in Word document or Excel cells via Office COM.
- 6/6 Page Down movements independently verified by Word selection movement or Excel ScrollRow.
- 6/6 correct foreground owners both before typing and at the final source observation.
- 6/6 correct Win32 Word caret or UIA Excel cell rectangles on Doxa Right.
- 6/6 matching yellow/green markers on independent source and magnified Centre frames.
- 100% target containment within Vision's 4x viewport in every stable phase.
- 200 timestamped Right PNGs and 200 Centre PNGs; role/SHA-256 manifest provenance.
- Normal Vision shutdown; unsaved test documents closed; original pointer and foreground restored; no test process left behind.
- Maximum diagnostic UIA snapshot age: approximately 977 ms and 1355 ms, respectively. These figures are NOT user-visible latency.

Keyboard text uses Windows SendInput Unicode, with F2 and Enter for Excel editing. Page Down uses Windows Forms SendKeys, confirmed by actual application navigation. These are scripted inputs, not physical human keystrokes.

## Disqualified investigative runs retained

office-edit-4x-20261018-170008-037982:
6 edits and 6 Page Down operations, but Excel UIA selected-cell rectangle was missing for one step. INCONCLUSIVE.

office-edit-4x-20261018-170431-026f68:
Source truth and independent colours available, but Vision preview did not exit inside its normal-shutdown limit and was force-closed. FAIL_PREVIEW_SHUTDOWN; intermittent clean-exit weakness not declared resolved.

office-edit-4x-20261018-171301-5fbd2c:
All six edits/navigation actions, but the last Excel UIA observation repeatedly pointed to a PowerShell process. Source verdict INCONCLUSIVE_SOURCE_TRUTH. Foreground interference may have been caused by independent remote PowerShell status probes made during GUI capture; this is plausible but not proven.

A04 source has a bounded six-attempt UIA observation retry. It never fabricates a cell rectangle. The strict scorer additionally requires the actual foreground PID at measurement time, beyond ownership at the start of the phase. The two passing runs were executed without intervening shell/desktop probes, using only job polling.

## Reproduce

With physical console unlocked, supported three/four-screen topology and NO pre-existing Word, Excel or Vision process:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/A04-RunAndQualifyOfficeEditStrict.ps1

The guarded script creates unsaved test-owned Office instances, records independent Right and Centre frames, and applies three gates: independent visual acceptance, strict caret/cell viewport containment veto, and input/navigation/source/cleanup qualification. It creates a unique evidence directory and does not overwrite historical results.

Core files under lab/pocs/doxa/assessment:
A04-office-editing-charter.md;
A04-ProbeOfficeEditingStimulus.ps1;
A04-RunOfficeEdit4xVisualCapture.ps1;
A04-RunAndQualifyOfficeEditStrict.ps1;
A04-QualifyOfficeEditing.py;
test_A04_office_editing.py.

Test results: 104/104 assessment Python tests, 23/23 native CTests, 8/8 dev-harness tests, development-contract validator PASS.

## Interpretation and next step

This strengthens A03: Vision followed real Windows keyboard-simulated editing and Page Down rather than only programmatic selection changes. It is still a bounded controlled three-screen assessment, NOT proof of all-day reliability, real user typing comfort, arbitrary documents, pointer-versus-caret conflict recovery, fourth-display operation, physical panel fidelity or low-vision user acceptance.

Next: longer mixed Office editing/scrolling workload measuring foreground theft, caret displacement, staleness, software frame freshness, clean shutdown and resource overhead. Keep all desktop probes out of the active test interval.

A04 files and this report remain local uncommitted work. No commit, push, issue mutation, or alteration of unrelated dirty files was performed in this tranche.
