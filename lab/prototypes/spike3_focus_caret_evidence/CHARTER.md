# Spike 3 — Focus and caret evidence

**Date:** 2026-09-22  
**Project:** Visual  
**Status:** implementation starting

## Question

Can Visual obtain reliable, screen-positioned keyboard-focus and text-caret evidence across representative Windows applications without assuming one accessibility API works everywhere?

## Product reason

Mouse-only tracking is insufficient for sustained low-vision work. When a user types, tabs through controls, edits text, or navigates a form, Visual needs evidence about the active keyboard target and, where possible, the text insertion caret.

The goal of this spike is not to implement viewport movement. It is to characterize the evidence that a later POI/viewport policy can consume.

## Primary hypothesis

A layered evidence model can provide useful focus/caret positions across a broader application set than any single API:

1. semantic UI Automation focus and text-caret evidence where supported;
2. Win32 GUI-thread focus/system-caret evidence as corroboration or fallback;
3. focused-element/window bounds as lower-precision context;
4. no automatic movement when evidence is absent or contradictory.

## Evidence providers to compare

### UI Automation

- `IUIAutomation::GetFocusedElement`;
- focused-element bounding rectangle;
- control type/name/framework metadata;
- `IUIAutomationTextPattern2::GetCaretRange` where supported;
- caret range bounding rectangles where exposed;
- later focus-change/event behavior.

### Win32 GUI-thread evidence

- `GetForegroundWindow`;
- `GetWindowThreadProcessId`;
- `GetGUIThreadInfo`;
- `hwndFocus`;
- `hwndCaret`;
- `rcCaret`, explicitly converted from caret-window client coordinates to virtual-desktop screen coordinates;
- caret visibility/blink state where available.

## Coordinate rule

All final rectangles consumed by later Visual components must be explicitly in PMv2 virtual-desktop screen coordinates.

Never compare UIA screen rectangles with raw `GUITHREADINFO.rcCaret` until the Win32 caret rectangle has been converted from the caret window's client coordinate space.

## Phase A — deterministic native baseline

Build a small native stimulus that provides:

- standard single-line edit control;
- multiline edit control;
- buttons/checkbox or other focusable controls;
- deterministic Tab/focus transitions;
- deterministic text insertion/caret movement;
- scenario log with QPC timestamps.

Run a separate probe process that records UIA and Win32 evidence while the scenario executes.

## Phase B — representative real applications

Without changing the evidence schema, exercise at least:

- Notepad / standard Windows text editing;
- a Chromium-class browser text field/content-editable surface;
- an Office application if installed, preferably Word and/or Excel;
- one modern/custom-control application if practical.

The exact set is environment-dependent and should be recorded, not silently substituted.

## Measurements

Each sample/event should record:

- QPC timestamp;
- foreground HWND/process/thread;
- Win32 focus HWND;
- Win32 caret HWND;
- raw Win32 caret client rect;
- converted Win32 caret screen rect;
- UIA focused element availability;
- UIA process/control type/framework/name where safely obtainable;
- UIA focused-element bounding rect;
- TextPattern2 availability;
- caret range availability/active flag;
- UIA caret range bounding rectangles;
- provider errors/timeouts/HRESULTs;
- evidence age/source where event-driven measurements are added.

## Success criteria

The spike succeeds when we can define a practical provider/fallback contract for later POI work, including:

- what constitutes high-confidence caret evidence;
- what constitutes focus-only evidence;
- how rectangles are normalized into Visual's coordinate model;
- which provider failures are ordinary and recoverable;
- when the correct behavior is to emit no automatic-movement target.

The spike does **not** require one API to work in every application.

## Warning/falsification conditions

Document rather than hide:

- UIA provider hangs or materially slow calls;
- missing TextPattern2 support;
- empty caret-range rectangles;
- disagreement between UIA caret and Win32 caret;
- controls that expose focus but no useful caret;
- protected/elevated surfaces;
- stale evidence after focus/window destruction;
- coordinate-space disagreement.

## Explicit exclusions

Do not include:

- viewport pan/jump policy;
- smoothing/dead zones;
- WGC rendering integration;
- OCR fallback;
- speech/screen reading;
- app-specific production hacks;
- UIAccess/elevation work;
- settings UI.

## Expected outputs

- standalone evidence probe;
- deterministic native stimulus;
- machine-readable telemetry;
- analyzer/report;
- representative-application matrix;
- recommended provider/fallback interface for subsequent Visual integration;
- dated evidence artifact.

## Graduation target

Spike 3 evidence should be sufficient for Spike 4 to consume generic POI candidates such as:

- pointer point;
- caret rectangle with confidence/source;
- focus rectangle with confidence/source;
- explicit absence/uncertainty.

The renderer should remain unaware of which Windows API produced the POI.
