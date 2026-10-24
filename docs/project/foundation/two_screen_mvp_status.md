# Two-screen MVP status

**Date:** 2026-09-23

## MVP definition

The first functional Visual MVP is a two-physical-screen Windows application intended for actual low-vision task use, not a diagnostic spike.

Minimum behavior:

1. capture a source screen reliably;
2. present a live magnified Detail view on the second screen;
3. follow mouse, text caret and keyboard focus using explicit POI evidence;
4. use predictable viewport behavior rather than raw mechanical centering;
5. support zoom up/down plus fast normal/return behavior;
6. provide basic pointer/caret/focus finding;
7. recover safely from ordinary focus/source/display changes;
8. package these mechanisms into one executable with a small coherent state model.

## Current state

### Integrated application executable

**Implemented and physically exercised.**

The real application target exists at:

`app/build/Release/visual_app.exe`

Integrated runtime path:

`WGC source capture -> cached latest source texture -> Windows POI evidence -> POI arbitration -> viewport controller -> locator model -> D3D11 crop/scale/locator -> second-screen Detail`

The Detail window is non-activating so keyboard focus remains in the source application.

### Capture + GPU Detail presentation

**Physically validated and integrated.**

The Spike 1 WGC + D3D11 path is part of the production app target. Integrated physical smokes continue to show zero Present failures in the exercised runs.

WGC content-size changes recreate the frame pool. Capture-item closure and display-topology invalidation have explicit safe-shutdown paths instead of leaving stale content running.

### Interaction/render cadence

**Corrected after the first human task-use session and automatically validated.**

The original integrated app sampled POI evidence and rendered only from WGC `FrameArrived`. Because cursor capture is disabled, fast pointer movement over static source pixels could be sampled/rendered late even though the GPU path itself was healthy.

The app now separates:

- WGC source-frame acquisition/caching;
- a steady ~60 Hz interaction/render loop.

The interaction loop independently samples pointer/caret/focus evidence, updates the viewport and locator, and renders the latest cached source texture.

Current telemetry also records pointer age, UIA snapshot age/status, selected POI age and selected POI rectangle.

Evidence:

- short cadence smoke: 57.84 fps, p95 17.61 ms, max 33.08 ms, zero Present failures;
- fast-pointer stress: position-error p95 0 px, pointer-age p95 16.62 ms, caret handoff 88.65 ms, zero Present failures;
- 60-second soak: 3,588 frames, 59.94 fps, p95 16.78 ms, max 24.78 ms, zero Present failures.

Full report:

`artifacts/2026-09-23__gpt-5.6-sol__interaction_cadence_fix_and_browser_compatibility_v0.1.md`

A short human regression is still required to verify that the previously perceived ~2 s fast-mouse lag / ~1 s cross-to-caret delay is gone perceptually.

### Pointer + coordinate foundation

**Physically validated and integrated.**

The PMv2 coordinate model from Spike 2 is promoted into `app/src/core/coordinate_model.h`.

Pointer evidence is emitted only while the pointer is on the source display. Pointer freshness is based on actual movement time rather than merely re-sampling a stationary cursor.

### Caret + keyboard-focus tracking

**Integrated with layered providers.**

Production providers include:

- UI Automation `TextPattern2::GetCaretRange`;
- UI Automation `TextPattern::GetSelection` insertion-range fallback;
- Win32 `GetGUIThreadInfo` caret fallback;
- UIA focused-element rectangle;
- Win32 focused-control rectangle;
- pointer evidence.

UIA runs on a separate worker thread so semantic provider calls are not made inside the GPU render path.

The UIA provider now retains the last real semantic caret through a transient miss using its **original timestamp** only. Existing freshness rules therefore expire it naturally; cached evidence is never retimestamped or fabricated.

Integrated Notepad smoke:

- 158 frames;
- zero Present failures;
- 110 frames selected UIA TextPattern2 caret;
- 48 frames selected UIA TextPattern insertion caret;
- locator active on all 158 frames.

Post-cadence deterministic focus smoke:

- 578 total frames;
- 109/109 button/checkbox focus-only frames selected UIA focus;
- zero stale pointer/caret selections in those phases;
- locator active on all 109 focus frames;
- zero invalid viewport decisions;
- zero Present failures.

### Mouse-versus-caret arbitration

**Implemented, physically exercised, and stress-tested automatically.**

A deliberately moving pointer temporarily wins over caret/focus evidence because it is direct current user intent. Pointer evidence has a short freshness window and naturally yields back to caret/focus when movement stops.

Original integrated arbitration smoke:

- pointer movement phase: 54/55 frames selected pointer;
- subsequent caret phase: 57/57 frames selected semantic caret;
- caret resumed ~130.8 ms after pointer movement stopped.

Post-cadence native arbitration:

- pointer phase: 40/42 frames selected pointer;
- first semantic caret after pointer stopped: **68.84 ms**;
- zero Present failures.

Fast-pointer stress:

- 100 pointer-selected frames;
- pointer evidence age p95: **16.62 ms**;
- semantic caret handoff: **88.65 ms**;
- zero Present failures.

### Browser compatibility

**Validated for a bounded deterministic scenario.**

On 2026-09-29 the Edge editing fixture was hardened so it explicitly reacquires the HTML textarea through UI Automation after Vision starts, verifies AutomationId=e and TextPattern, cleans up its own processes, and requires sustained caret availability/selection. Three consecutive Edge 153 runs recorded 100% UIA caret presence, 88.3-89.4% caret-selected frames and zero Present failures.

Current interpretation:

- claim support only for the validated Edge/Chromium textarea scenario;
- do not generalise that result to arbitrary contenteditable, rich-editor, embedded-Chromium or untested browser/version combinations;
- the earlier intermittent results were primarily fixture-focus and cleanup defects rather than evidence of a missing Vision UIA provider capability;
- extend the regression only when a concrete browser/editor use case needs qualification.

### Viewport policy

**Implemented, unit-tested and integrated.**

The production controller provides:

- hold while target is comfortably visible;
- minimum required pan outside the comfort area;
- jump classification for distant targets;
- source-bound clamping;
- negative-coordinate support;
- manual tracking disable;
- no movement from stale/invalid evidence;
- stable repeated decisions without drift.

Current defaults remain experimental:

- 20% horizontal comfort margin;
- 20% vertical comfort margin;
- jump threshold at 75% of viewport dimension.

These values require real low-vision usability tuning.

### Target locator

**Implemented and physically exercised.**

Current behavior:

- pointer: two-tone crosshair-style locator;
- caret/focus: two-tone outlined target region;
- black outer mark + white inner mark to avoid relying on one content-dependent color.

Locator geometry has production tests.

### Zoom, normal view and exact return

**Implemented and physically validated.**

Global alpha hotkeys:

- `Ctrl+Alt+1` -> 1x;
- `Ctrl+Alt+2` -> 2x;
- `Ctrl+Alt+4` -> 4x;
- `Ctrl+Alt+0` -> normal view / return to previous magnified state;
- `Ctrl+Alt+T` -> tracking on/off;
- `Ctrl+Alt+Q` -> exit Visual.

Exact-return physical smoke:

- 1x viewport stayed stable;
- return to 2x restored the previous magnified viewport with 0-pixel coordinate delta;
- zero Present failures;
- zero invalid viewport decisions.

### Lifecycle / topology safety

**Real HDMI disconnect/reconnect behavior physically validated.**

The app handles:

- WGC capture-item `Closed` event;
- `WM_DISPLAYCHANGE` topology invalidation;
- distinct telemetry/exit reasons.

Physical HDMI disconnect run:

`lab/benchmarks/integrated_app/runs/2026-09-22_21-20-33__physical_disconnect_smoke`

Observed:

- external HDMI unplugged while USB-C power remained connected;
- 1,024 Visual frames before shutdown;
- zero Present failures;
- Visual exited cleanly with topology-change exit code `12`;
- no stale/frozen Visual process remained.

After reconnect, native PMv2 verification showed the expected two-display 3840x1080 desktop and the post-reconnect Visual relaunch rendered successfully with zero Present failures.

### First-MVP recovery policy

**Working policy: safe shutdown on topology invalidation, then relaunch after the desired topology returns.**

Automatic in-process hot-plug rebinding remains later hardening unless task-use evidence shows relaunch is materially disruptive.

## Production tests

Current Release CTest targets:

1. `core_pipeline_tests`;
2. `locator_model_tests`;
3. `poi_arbitration_tests`;
4. `view_return_tests`.

Latest result after the interaction-cadence refactor: **4/4 passed**.

## Context / productivity experiment

The first two-screen Context+Detail productivity experiment is prepared at:

`lab/experiments/context_persistence/PROTOCOL.md`

with repeatable reference-editing and record-comparison fixtures.

The first comparison deliberately uses the current app before adding more functionality:

1. one-screen conventional magnification;
2. Visual two-screen dynamic Detail + persistent source/context;
3. ordinary two-screen extended desktop.

This tests whether Visual's Context+Detail relationship adds value beyond generic extra screen area before implementing a dedicated Freeze/Reference feature.

## What remains before calling the two-screen build an MVP

The remaining work is primarily usability and compatibility:

1. human regression of the fast mouse -> caret behavior after the cadence fix;
2. tune viewport margins/jump behavior/locator from human use;
3. preserve the bounded Edge editing-caret regression and qualify additional browser/editor scenarios only when needed;
4. run the first Context+Detail productivity comparison;
5. add a simple launch/distribution path outside the build tree;
6. document known alpha limitations;
7. optionally exercise display sleep/wake separately from HDMI disconnect.

## Progress interpretation

A rough engineering-progress estimate for the functional two-screen MVP remains approximately **80-85%**.

The core runtime, tracking architecture, interaction cadence, topology recovery and exact-return behavior are now well de-risked. The dominant remaining uncertainty is no longer basic feasibility; it is whether the interaction feels consistently good across real applications and whether Context+Detail provides meaningful productivity value for low-vision work.

The next physical validation gate is:

> **human fast-mouse/caret regression, then the first Context+Detail productivity comparison.**
