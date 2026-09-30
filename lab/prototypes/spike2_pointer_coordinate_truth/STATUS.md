# Spike 2 Status

**Date:** 2026-09-22

## Current state

Spike 2 has a **successful physical two-display mixed-DPI baseline** and a tested reusable coordinate model.

The primary baseline question—whether a PMv2-aware Visual process can obtain stable pointer/monitor coordinates and cross a real 150%/100% DPI boundary without unexplained jumps—has positive evidence.

Physical topology variants with negative monitor origins and primary-display changes remain targeted follow-up work, but they do not need to block the next independent capability spike.

## Implemented

- C++20 standalone diagnostic executable;
- embedded Per-Monitor-V2 DPI manifest;
- `EnumDisplayMonitors` / `GetMonitorInfo` geometry;
- `EnumDisplaySettingsEx` current mode/position comparison;
- `QueryDisplayConfig` source/target identity and source-mode comparison;
- hidden PMv2 per-monitor probe windows using `GetDpiForWindow`;
- legacy `GetDpiForMonitor` and `GetScaleFactorForMonitor` comparison logging;
- `GetCursorPos` sampling;
- `MonitorFromPoint` pointer-to-monitor resolution;
- strongly named reusable coordinate types;
- screen -> monitor-local conversion;
- screen -> normalized monitor conversion;
- normalized monitor -> screen round trip;
- QPC timestamped CSV telemetry;
- deterministic center/corner/slow-sweep/fast-sweep pointer scenario;
- observation-only mode;
- physical-console runner using actual process/console session IDs rather than stale `SESSIONNAME`;
- PowerShell analyzer producing `analysis.json` and `SUMMARY.md`;
- CTest coverage for positive, negative and vertical monitor layouts.

## Session guard correction

The bridge inherited `SESSIONNAME=RDP-Tcp#0` even after RDP was disconnected.

Windows reported:

- bridge process session ID: 1;
- active console session ID: 1.

The old environment-string guard was therefore a false negative.

Spike 1 and Spike 2 physical runners now compare the current process session ID to `WTSGetActiveConsoleSessionId()`. This was verified through the bridge with an observation-only physical run.

## Strongest physical validation

Run:

`lab/benchmarks/spike2_pointer_coordinate_truth/runs/2026-09-22_17-22-32__spike2_coordinate_truth`

Environment:

- PMv2: yes;
- displays: 2;
- virtual desktop: 3840x1080 at x=0,y=0;
- DISPLAY1: 1920x1080, primary, 144 DPI;
- DISPLAY2: 1920x1080, 96 DPI.

Measured:

- 530 pointer samples;
- 10 monitor-transition samples;
- maximum SetCursorPos -> GetCursorPos delta: 0 px;
- inside-monitor violations: 0;
- normalized-coordinate violations: 0;
- expected-monitor mismatches: 0;
- geometry API disagreements: 0 for the tested topology.

This run used the shared coordinate component in the live diagnostic after refactoring.

Dated evidence:

`artifacts/2026-09-22__gpt-5.6-sol__spike2_pointer_coordinate_baseline_v0.1.md`

## Automated coordinate-model tests

CTest target:

`visual_spike2_coordinate_model_tests`

Coverage includes:

- monitor to the right of primary;
- negative X/Y monitor origin;
- monitor above primary;
- half-open rectangle edges;
- normalized round trips;
- invalid geometry/input rejection.

Latest result:

- Release build: clean;
- tests: 1/1 passed;
- failures: 0.

## Important DPI observation

On DISPLAY1:

- `GetDpiForWindow`: 144 DPI -> 150% implied;
- legacy `GetDpiForMonitor`: 144 DPI;
- legacy `GetScaleFactorForMonitor`: 140%.

The legacy scale-factor result is comparison evidence only and is not used as coordinate truth.

The earlier 1280x720 laptop geometry observed by a PowerShell/RDP-oriented collector was DPI-virtualized. The PMv2 native process sees the physical geometry as 1920x1080 and agrees with `EnumDisplaySettingsEx` and `QueryDisplayConfig`.

## Remaining targeted Spike 2 validation

When convenient:

1. external monitor physically arranged left of laptop to produce negative X;
2. external monitor above/below laptop;
3. primary-display swap;
4. optional additional mixed resolution/scaling configuration;
5. later four-display Doxa topology.

These are targeted topology validations, not reasons to continue polishing the basic pointer-coordinate mechanism indefinitely.

## Next development step

Begin the independent focus/caret evidence spike while retaining the topology variants above as explicit Spike 2 follow-up tests.

The eventual integration sequence remains:

1. Spike 1 renderer/capture foundation;
2. Spike 2 coordinate foundation;
3. focus/caret evidence;
4. viewport policy;
5. integrate proven mechanisms into the first internal Visual working build.
