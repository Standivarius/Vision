# Spike 1 Automated Test Harness

## Purpose

This harness makes Spike 1 repeatable without requiring a human to manually move the pointer or remember timestamps.

It is developer/test infrastructure, not part of the Visual product architecture.

## What it automates

`run-automated.ps1`:

1. creates a timestamped run directory;
2. records machine/session/display metadata;
3. optionally starts an FFmpeg desktop recording;
4. starts the Visual Spike 1 executable;
5. starts `visual_spike1_stimulus.exe`;
6. runs a deterministic visual/pointer scenario;
7. stops Visual cleanly;
8. finalizes the recording;
9. writes a manifest;
10. runs `analyze-run.ps1` and writes a summary.

## Run artifacts

Raw runs are written under:

`lab/benchmarks/spike1_wgc_d3d11_detail/runs/<run-id>/`

A run contains:

- `environment.json` — OS/CPU/GPU/session/display context;
- `orchestrator_events.jsonl` — process start/stop timing using QPC;
- `scenario_events.jsonl` — deterministic scenario events using QPC;
- `visual_telemetry.csv` — WGC/render/presentation telemetry;
- `manifest.json` — run parameters, exit codes, recording metadata and artifact names;
- `analysis.json` — computed timing/cadence statistics;
- `SUMMARY.md` — human-readable analysis summary;
- `video.mp4` — optional diagnostic desktop recording;
- `ffmpeg.log` — optional recorder diagnostics.

Raw run directories are intentionally Git-ignored. Selected conclusions should be promoted into dated `artifacts/` reports when they become decision evidence.

## Single-monitor development mode

When only one display is available, Visual automatically enters `single_monitor_development` mode.

The Detail output is a fixed-size top-right window rather than a full-screen second-display window.

For monitor-source single-monitor runs, Visual attempts:

`SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)`

This prevents the Detail window from feeding recursively back into its own WGC monitor capture. Success/failure is written to telemetry as:

- `detail_excluded_from_capture`
- `detail_exclusion_error`

This mode validates most of the WGC/D3D11/render/telemetry machinery but does **not** prove the cross-monitor product hypothesis.

## Deterministic stimulus

`visual_spike1_stimulus.exe` runs a repeating sequence of 10-second phases:

1. synchronization flashes;
2. slow motion;
3. fast motion;
4. smooth scrolling bands;
5. rapid scrolling bands;
6. pointer edge sweep.

The scenario can move the real Windows pointer unless `-NoPointer` is passed to the runner.

Major transitions are written to `scenario_events.jsonl` with QPC timestamps. Synchronization flashes are intended to provide a visible landmark that can later be correlated against video frames.

## Typical commands

### Fast development smoke run

```powershell
.\run-automated.ps1 -DurationSeconds 20 -ForceSingleMonitor
```

### Diagnostic run with recording

```powershell
.\run-automated.ps1 -DurationSeconds 60 -ForceSingleMonitor -Record
```

### Later two-monitor validation

With two real displays attached, omit `-ForceSingleMonitor`:

```powershell
.\run-automated.ps1 -DurationSeconds 180 -Record
```

The runner will use the normal cross-monitor mode when two displays are visible to the process.

## Recording

FFmpeg is discovered either from `PATH` or from the user's WinGet package directory.

Current diagnostic recording settings request:

- desktop capture through FFmpeg `gdigrab`;
- 60 fps input;
- H.264 (`libx264`);
- ultrafast preset;
- CRF 18.

The manifest stores the actual encoded frame rate reported by `ffprobe`. Requested frame rate must not be mistaken for achieved frame rate.

Recording is **diagnostic**, not a source of final performance numbers. It adds GDI capture, encoding, CPU/GPU load and additional scheduling pressure. Important performance conclusions should be checked in a matching run with `-Record` omitted.

### Single-monitor recording limitation

In the current single-monitor monitor-source mode, the Detail window is deliberately marked `WDA_EXCLUDEFROMCAPTURE` to prevent recursive WGC feedback. Windows documents that `WDA_EXCLUDEFROMCAPTURE` makes the window absent from supported capture paths.

Therefore a single-monitor desktop recording is useful for validating the recorder, the deterministic stimulus, scenario timing and overall run packaging, but it should **not** be assumed to contain the Detail window itself.

Once two monitors are attached, the Detail output is on a separate display and this exclusion is unnecessary. A full virtual-desktop recording can then show source activity and Detail output together, which is the intended video-versus-telemetry validation setup.

## Timing interpretation

Microsoft documents `Direct3D11CaptureFrame.SystemRelativeTime` as the QPC time at which the compositor rendered the frame. The first RDP single-monitor runs showed this value approximately 10–23 ms ahead of the callback QPC timestamp.

For that reason the harness preserves the signed QPC delta but does not label it as frame age, capture latency or photon latency.

The telemetry separately measures:

- WGC frame timestamp;
- frame callback arrival QPC;
- render-start QPC;
- `Present()` call QPC;
- `Present()` return QPC;
- `Present()` call duration;
- inter-arrival cadence;
- Present result;
- GPU-copy fallback use.

External/video correlation is needed before interpreting any software timestamp combination as user-visible end-to-end latency.

## Current verified smoke result

On 2026-09-19 in the active RDP development session:

- single monitor reported;
- `WDA_EXCLUDEFROMCAPTURE` succeeded;
- WGC/D3D11 run completed normally;
- Visual exit code 0;
- stimulus exit code 0;
- zero Present failures;
- zero GPU-copy fallback frames;
- effective WGC cadence was about 32 fps, consistent with the remote-display environment rather than a physical-monitor performance result;
- a recorded run produced a valid H.264 MP4;
- the RDP recording achieved about 13.5 fps despite a 60 fps request.

These are harness-validation observations only. They are not evidence for or against the physical dual-monitor WGC hypothesis.
