# Spike 2 — Pointer and coordinate truth

This prototype isolates Windows multi-monitor pointer and coordinate behavior before caret/focus tracking or viewport integration.

## Build

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

Release executable:

`build\Release\visual_spike2_coordinate_truth.exe`

## Physical deterministic run

Run from the physical Windows console, not an RDP session:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-physical.ps1
```

**Warning:** the deterministic scenario intentionally controls the real Windows pointer for roughly 10 seconds. Do not try to use the mouse while it is active.

Observation-only mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-physical.ps1 -NoPointerMove -ObserveSeconds 15
```

## Output

Each run is written below:

`lab\benchmarks\spike2_pointer_coordinate_truth\runs\<timestamp>__spike2_coordinate_truth\`

Important files:

- `displays.json` — PMv2 awareness, virtual-desktop geometry, monitor rectangles, current display modes, QueryDisplayConfig identity/path evidence and DPI measurements;
- `pointer_telemetry.csv` — timestamped pointer samples, resolved monitor, monitor-local/normalized coordinates, expected points and deltas;
- `analysis.json` — machine-readable run analysis;
- `SUMMARY.md` — concise human-readable interpretation;
- `completed.txt` — successful executable completion marker.

## Coordinate/DPI policy in this spike

The executable embeds a Per-Monitor-V2 manifest.

Current canonical evidence:

- virtual-desktop/monitor geometry: PMv2 `GetMonitorInfo`, `EnumDisplaySettingsEx` and `QueryDisplayConfig` are compared explicitly;
- pointer position: `GetCursorPos` in the PMv2-aware process;
- pointer-to-monitor resolution: `MonitorFromPoint`;
- per-monitor DPI: `GetDpiForWindow` on a hidden PMv2 top-level probe window created on each monitor.

`GetDpiForMonitor` and `GetScaleFactorForMonitor` are logged as comparison evidence only. Microsoft documents `GetDpiForMonitor` as inappropriate as the primary DPI API for a per-monitor-aware caller; the spike therefore does not build its coordinate model around it.

Microsoft references:

- https://learn.microsoft.com/en-us/windows/win32/hidpi/setting-the-default-dpi-awareness-for-a-process
- https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getdpiformonitor
- https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getscalefactorformonitor

## Current evidence

A non-pointer-moving smoke run on MARIUS-DELL verified:

- PMv2 active;
- two displays enumerated;
- contiguous PMv2 virtual desktop of 3840x1080;
- laptop display geometry 1920x1080 at 144 DPI;
- external display geometry 1920x1080 at 96 DPI;
- `GetMonitorInfo`, `EnumDisplaySettingsEx` and `QueryDisplayConfig` source geometry agree in that topology;
- analyzer completes successfully.

The earlier 1280x720 laptop geometry observed from a PowerShell/RDP-oriented environment collector is therefore strong evidence of DPI virtualization in that collector, not the physical PMv2 coordinate space Visual should use.

A full physical deterministic pointer run is still required before Spike 2 can claim pointer-transition correctness.
