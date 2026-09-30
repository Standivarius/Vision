# Spike 3 Status

**Date:** 2026-09-22

## Current state

Spike 3 has a buildable evidence probe, deterministic native stimulus, real-app runners, and target-aware analysis.

The current evidence strongly supports a layered provider model:

- Win32 caret/focus evidence works well for classic edit controls;
- UI Automation focused-element evidence is useful across both native and modern controls;
- modern Notepad exposes rich UIA text caret semantics in addition to Win32 evidence;
- one universal API is not a safe assumption.

## Implemented

- PMv2 native probe;
- `GetForegroundWindow` / `GetWindowThreadProcessId` context;
- `GetGUIThreadInfo` focus/caret evidence;
- conversion of `GUITHREADINFO.rcCaret` from caret-window client coordinates to screen coordinates;
- UIA focused-element identity, bounds and metadata;
- explicit TextPattern2 interface presence;
- `TextPattern2::GetCaretRange` range presence/degeneracy/bounds;
- ordinary TextPattern interface presence;
- `TextPattern::GetSelection` insertion/selection range evidence;
- expanded character-context rectangles;
- deterministic native stimulus;
- target-PID-aware native analyzer;
- real-app analyzer;
- Notepad temporary-fixture runner;
- isolated Chrome local-fixture runner with test-profile cleanup and strict foreground validation.

## Deterministic native baseline

Strongest corrected run:

`lab/benchmarks/spike3_focus_caret_evidence/runs/2026-09-22_18-08-18__native_baseline`

Key interpretation:

- Win32 system-caret evidence is present throughout standard edit phases and absent for button/checkbox focus phases, as expected;
- UIA focused-element evidence is present;
- the classic Win32 edit controls used by the deterministic stimulus do not expose useful TextPattern/TextPattern2 caret semantics in this environment;
- therefore Win32 caret fallback is required even when UIA focus is available.

This is a useful layered-provider result, not a failure.

## Real Windows Notepad result

Run:

`lab/benchmarks/spike3_focus_caret_evidence/runs/2026-09-22_18-11-20__notepad`

Observed in the exercised editing state:

- target foreground samples: 192 / 192 (100%);
- Win32 focus: 100%;
- Win32 caret: 100%;
- UIA focus: 100%;
- TextPattern2 interface: 100%;
- TextPattern2 caret range: 100%;
- TextPattern2 character-context rectangle: 100%;
- TextPattern interface: 100%;
- TextPattern selection/insertion range: 100%;
- degenerate insertion range: 100%;
- TextPattern character-context rectangle: 100%.

This is strong evidence that a modern Windows text surface can provide rich semantic caret information while retaining Win32 evidence in parallel.

## Chrome status

Chrome testing is **not yet valid evidence**.

Two isolated local-fixture attempts were rejected because Windows Terminal remained the foreground process. The runner correctly refused to accept samples unless a Chrome process actually owned foreground focus.

This is a foreground-control/harness limitation caused by normal Windows foreground-lock behavior, not evidence that Chrome lacks UIA/Win32 caret support.

Do not spend additional development time fighting foreground-lock behavior in the background harness right now. Browser coverage can be resumed later with one deliberate physical foreground action if needed.

## Current provider hypothesis

Working candidate hierarchy for later POI production code:

1. UIA TextPattern2 caret range when present and usable;
2. UIA TextPattern degenerate selection/insertion range when present and usable;
3. Win32 `GetGUIThreadInfo` caret rectangle for classic GUI controls;
4. UIA focused-element rectangle as focus-only context;
5. Win32 focused-window/control context;
6. emit no automatic-movement caret target when evidence is absent or contradictory.

This hierarchy remains provisional until event freshness/timing and more representative application families are measured.

## Next work

1. add event-driven focus/caret freshness measurements rather than relying only on polling;
2. define a reusable evidence/POI candidate structure with source + confidence + timestamp;
3. characterize disagreement/staleness between providers;
4. test another representative application family when practical;
5. finalize the provider/fallback contract;
6. begin the standalone viewport-policy spike.

## User action

No action required now.

A later browser validation may benefit from the user physically clicking the isolated fixture window once, but this should not block continued MVP development.
