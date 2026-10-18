# Vision A03 — mixed Word/Excel 4x working-session checkpoint

Date: 2026-10-18
Status: one qualified bounded PASS, repeat not qualified; continuing stability work.
Scope: MARIUS-DELL physical unlocked console, 3 active displays (laptop primary, Centre Detail, Right source). This is generic three-monitor Vision, not a Doxa-specific renderer or four-screen claim.

## Why this test exists

A02 confirmed Word caret and Excel selected-cell visibility in separate sessions.
A03 tests the additional risk of switching foreground between Word and Excel on
the same source display, while a single 4x Vision Detail view follows.

## Qualified bounded mixed run

- Independent evidence directory:
  artifacts/vision-poc-a-graphics-20261017/mixed-office-4x-visual-20261018-154927-afc62e/
- Independent verdict:
  mixed-office-independent-verdict.json inside that directory.
- Result: PASS_MIXED_OFFICE_4X_SOURCE_AND_VISIBLE_OUTPUT.
- Six actual foreground phases, in this order:
  WORD, EXCEL, WORD, EXCEL, WORD, EXCEL.
- Word used an unsaved test document and inserted generated text through Word
  COM at different caret positions. Excel used an unsaved generated workbook,
  selected and edited known cells through Excel COM; no real keyboard typing
  was asserted.
- Windows process/foreground truth and Word Win32 caret or Excel UIA selected
  cell geometry/identity matched the intended app and Right source monitor
  for all six phases.
- Independent GDI recordings captured 156 source frames and 156 Centre frames.
  The correct yellow Word or green Excel marker appeared in both recordings
  during all six phases.
- Largest independently sampled source-to-Centre frame difference: 466.9 ms.
  Sampling was only 2 fps, so this is NOT an optical/photon latency claim.
- One continuous Vision preview, normal shutdown, and restoration of the
  original user foreground. Test documents/workbook were closed without saving.

## Important contrary evidence — not hidden

- Early exploratory mixed run:
  artifacts/vision-poc-a-graphics-20261017/mixed-office-stimulus-20261018-154334-2bbbc9/
  was INCONCLUSIVE because an Office COM top-level HWND was not ready.
  Explicit bounded handle-readiness retries were added.
- Later exploratory run:
  artifacts/vision-poc-a-graphics-20261017/mixed-office-stimulus-20261018-154627-e85af6/
  was INCONCLUSIVE because Windows Terminal, not Word or Excel, held
  foreground focus. Window activation was then made explicit and verified.
- Repeat:
  artifacts/vision-poc-a-graphics-20261017/mixed-office-stimulus-20261018-155333-0bb06d/
  was INCONCLUSIVE: Word first phase lost foreground to Windows Terminal;
  five subsequent phases had the correct foreground and source evidence.
  This run cannot support reliability/soak PASS.
- A separate simultaneously executing Vision A03 test harness
  (A03-RunOfficeSwitch4xVisualCapture.ps1) was found through the shared
  project job list. Its overlapping Office processes blocked one of our
  runs at startup. Its source file and dirty work were NOT modified.
- The other independent A03 Office-switch stimulus runs were also
  inconclusive. No cross-session results were merged or promoted.
- A two-application unscored warm-up was added for a subsequent controlled
  retry, but concurrent running Office processes blocked that attempt
  before start. Do not claim warm-up proven.

## Safety / replay

Our fixture aborts if Word, Excel or Vision preview is preexisting. It does
not modify Windows display layout, drivers, user's documents or other projects.
All evidence directories use immutable unique names. Foreground restore and
test-only process ownership are explicit. Existing A02 and four-screen POC A
scorers remain unchanged.

Use one designated Vision GUI/Office assessment job at a time.
A project-wide named desktop assessment lock is recommended before longer
soak/recovery qualification, because a preflight process check alone is
insufficient against simultaneous session starts.

The independent image scorer rejects missing or wrong markers, wrong
application sequence, bad foreground/cell/caret provenance, altered frame
roles or SHA-256, insufficient samples, excess delay, forced exit,
incomplete source restoration, unknown topology and unexpected missing phases.

To repeat on a controlled unlocked 3- or 4-monitor console, with no other
GUI assessment already running:

1. powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/A03-RunMixedWordExcel4x.ps1
2. python lab/pocs/doxa/assessment/A03-AnalyzeMixedOffice.py <new resulting mixed-office-4x-visual directory>

At this checkpoint the full assessment Python suite passed 82 tests,
including 12 A03 mixed-assessment negative tests and other concurrent
session tests. The last native Visual CTest run passed 23/23.

Still open: one clean unattended repeat without other GUI jobs; real physical
keyboard typing; sustained natural use; sleep/wake, docking, screen changing;
external optical camera; and low-vision participant validation. Do not use
this experimental evidence to claim all-day Word/Excel reliability.
