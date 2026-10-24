# A02 — native Word caret truth spike (independent source evidence)

Date: 2026-10-18
Status: proposed bounded experiment, NOT A02 qualified acceptance.

## Hypothesis

Without reading any user document, Windows can expose caret/focus geometry
for an unsaved disposable Word document in native screen coordinates. This
source-side signal is necessary but not sufficient for independently checking
whether Vision's 4x Doxa Centre viewport contains the caret.

## Minimum scope and permission boundary

- Use one newly created, unsaved Word document with fixed generated text,
  no user's existing Word session, templates or files touched.
- Abort if Word is already running, if physical console is locked or if
  the physical four-screen topology is absent.
- Move only the newly created Word window onto Doxa Left.
- Advance the selection among deterministic positions; sample Windows UI
  Automation TextPattern2/TextPattern caret ranges and classic Win32
  GetGUIThreadInfo caret/focus geometry.
- Record rectangles, selected source process, active monitor and evidence
  provenance. No document contents, keystrokes or clipboard captured.
- Close the unsaved Word document without saving, quit only the Word
  application created for this run, and restore prior foreground window.
- No elevated permissions, driver/software policy changes or outside agent.

## Expected evidence / falsification

PASS_SOURCE_CARET only if >=3 independent nonempty caret rectangles from
Windows UIA or Win32, attributable to the spawned Word process and physically
located inside the Left monitor, with at least two distinct caret positions.

INCONCLUSIVE if UIA providers fail, caret coordinates are stale, or Windows
does not expose the signal. BLOCKED if Word, topology or console preconditions
cannot be satisfied. FAIL only for a clear violation of the controlled
fixture's stated invariants (e.g. caret outside source or wrong process).

This does NOT claim the caret is visible on Doxa Centre. A further independent
centre-screen viewport registration at 4x will be needed, followed by Excel,
multiple caret movement actions, and actual user/physical camera acceptance.

Allowed files: lab/pocs/doxa/assessment/A02-*, plus a new, unique
artifacts/vision-poc-a-graphics-20261017/caret-truth-* output directory.

Use PowerShell's on-machine COM + Windows UIAutomation; no extra packages.
