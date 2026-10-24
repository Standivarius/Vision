# Spike 2 — Pointer and coordinate truth

**Date:** 2026-09-22  
**Project:** Visual  
**Status:** implementation built and PMv2 observation smoke verified; first deterministic physical-console pointer run pending

## Question

Can Visual establish a reliable, explicitly modeled coordinate foundation for pointer-driven behavior across arbitrary Windows multi-monitor layouts, including mixed DPI/scaling and negative virtual-desktop coordinates?

## Why this spike is next

Spike 1 has now demonstrated credible WGC + D3D11 cross-monitor Detail behavior on two physical displays.

The 60-second physical run exposed a concrete coordinate issue worth isolating before adding caret/focus tracking: the environment collector reported the laptop display as 1280x720 while the external display was 1920x1080 with a non-contiguous x-origin. This is consistent with DPI-aware versus DPI-virtualized coordinate spaces being mixed by different APIs/tools.

Caret/focus tracking will be harder to reason about if pointer/display coordinate truth is not established first.

## Primary hypothesis

With the process running Per-Monitor-V2 DPI aware, Visual can obtain and convert pointer, monitor, window and display coordinates into explicitly named spaces such that monitor transitions and view targeting remain correct across mixed-DPI multi-monitor layouts.

## Scope

Build a small standalone diagnostic executable/tool that:

- runs Per-Monitor-V2 DPI aware;
- enumerates all active displays;
- records multiple relevant display/monitor coordinate representations;
- samples the real pointer position;
- identifies which monitor contains the pointer;
- reports DPI/scaling for the relevant monitor;
- logs pointer transitions between monitors;
- tests conversion between screen, monitor-local and normalized source/view coordinates;
- visualizes or logs expected versus resolved monitor-local position;
- supports negative-coordinate monitor layouts;
- produces deterministic machine-readable telemetry;
- can run independently of Spike 1 rendering.

## Explicit coordinate spaces

The spike must name spaces rather than using ambiguous `x` / `y` values.

At minimum distinguish:

1. virtual-desktop screen coordinates as reported to a PMv2-aware process;
2. monitor rectangle coordinates;
3. monitor-local coordinates;
4. normalized monitor/source coordinates;
5. logical/DPI-virtualized coordinates where an API or external collector exposes them;
6. later, source-texture coordinates for comparison with Spike 1.

Do not assume that values from different APIs share the same space merely because they are all integers called pixels.

## Minimum APIs/evidence to compare

Use Windows-native APIs appropriate to the question, including where useful:

- `GetCursorPos`;
- `MonitorFromPoint`;
- `GetMonitorInfo`;
- `EnumDisplayMonitors`;
- display configuration APIs such as `QueryDisplayConfig` / `DisplayConfigGetDeviceInfo`;
- DPI APIs appropriate to PMv2 windows, plus older DPI APIs only as comparison evidence;
- `GetSystemMetrics` virtual-screen metrics;
- relevant display-mode APIs.

The spike should record API provenance for each coordinate/metric.

## Deterministic test scenario

Provide a simple scenario that moves the real pointer through known paths:

- center of each monitor;
- every shared boundary;
- outer edges/corners;
- repeated cross-monitor transitions;
- a slow sweep and a fast sweep.

The scenario must warn that it intentionally controls the real pointer while active.

Allow a `--no-pointer-move` / observation-only mode.

## Test topologies

Start with the current physical two-monitor setup.

Then deliberately test:

1. external monitor right of laptop;
2. external monitor left of laptop, creating negative x coordinates;
3. external monitor above/below laptop if practical;
4. different Windows scaling factors on the two displays;
5. different resolutions;
6. primary-display swap.

Later extend the same mechanism to the four-screen Doxa topology.

## Measurements

For each pointer sample/transition record:

- QPC timestamp;
- raw screen point;
- resolved monitor identity;
- monitor rectangle in the same declared coordinate space;
- monitor-local point;
- normalized x/y;
- DPI/scaling evidence;
- transition event when monitor identity changes;
- expected target monitor/point for deterministic scenarios where known;
- error/delta when expected coordinates are known.

## Success criteria

The spike succeeds when:

- pointer-to-monitor resolution is correct across tested layouts;
- monitor-local/normalized conversions are internally consistent;
- negative coordinates are handled correctly;
- mixed-DPI behavior is explicitly understood rather than hidden by virtualization;
- moving between monitors does not produce unexplained jumps or ambiguous spaces;
- the output is sufficient to define a stable coordinate interface for later POI and viewport components.

## Falsification / warning conditions

The current model is insufficient if:

- two APIs thought to share a coordinate space disagree materially without a documented conversion;
- monitor transitions cannot be resolved reliably under mixed DPI;
- the same physical point maps inconsistently depending on calling thread/window DPI context;
- display identity cannot be related reliably enough to current topology;
- normalized/source mapping cannot be defined without renderer-specific assumptions.

Any of these should be documented rather than hidden behind compensating constants.

## Exclusions

Do not include:

- UI Automation;
- caret tracking;
- keyboard-focus tracking;
- viewport smoothing/dead zones;
- WGC capture/render integration;
- settings UI;
- Doxa-specific driver logic;
- persistent monitor-role restoration.

Those belong to later spikes/integration.

## Expected outputs

- standalone diagnostic source/build target;
- deterministic pointer scenario;
- raw telemetry;
- short analysis script/report;
- dated evidence artifact after physical runs;
- recommended coordinate interface for later Visual components.

## Relationship to subsequent spikes

After coordinate truth is characterized:

- Spike 3 should investigate caret/focus evidence independently across representative applications;
- Spike 4 should build viewport policy using synthetic and then real POIs;
- only then should pointer/caret/focus policy be integrated with the Spike 1 renderer.
