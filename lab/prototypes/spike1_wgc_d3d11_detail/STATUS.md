# Spike 1 Status

**Date:** 2026-09-22

## Current state

Spike 1 is **buildable, locally testable, and physically validated on a two-monitor Windows console setup**.

The primary architectural question—whether WGC + D3D11 is credible for the first physical cross-monitor Detail capability—has enough positive evidence to stop being the main development blocker.

Spike 1 should now remain available for targeted follow-up work rather than continued general polishing.

## Implemented

- WGC monitor capture via `IGraphicsCaptureItemInterop::CreateForMonitor`.
- D3D11 device and C++/WinRT interop.
- Free-threaded WGC frame pool with two buffers.
- GPU crop/scale shader path.
- Borderless full-screen second-monitor Detail output.
- Automatic windowed single-monitor development mode.
- `WDA_EXCLUDEFROMCAPTURE` attempt in single-monitor monitor-source mode to prevent recursive feedback.
- 2x / 4x zoom.
- WGC frame-pool recreation on content-size changes.
- Display/DPI/mode/environment logging.
- Raw WGC compositor timestamp, callback QPC, render-start QPC, Present-call QPC and Present-return QPC telemetry.
- Present result and GPU-copy fallback telemetry.
- Deterministic visual/pointer stimulus executable.
- Automated run orchestrator.
- Dedicated physical cross-monitor wrapper that refuses RDP and requires at least two active displays.
- Optional FFmpeg desktop recording.
- Automated PowerShell run analyzer.
- Raw benchmark run packaging and manifest generation.

## Strongest physical validation result

Run:

`lab/benchmarks/spike1_wgc_d3d11_detail/runs/2026-09-22_16-39-33__spike1_auto`

Environment:

- session: `Console`;
- monitors reported by Visual: 2;
- GPU: Intel UHD Graphics;
- mode: `cross_monitor_validation`;
- zoom: 2x;
- recording: disabled;
- duration: 60 s requested, ~61.12 s measured capture interval.

Scenario coverage:

- sync flash;
- slow motion;
- fast motion;
- smooth scrolling;
- rapid scrolling;
- edge pointer sweep.

Observed/tested result:

- user observed successful live behavior on both physical monitors;
- Visual exit: 0;
- Stimulus exit: 0;
- 3050 WGC frames;
- effective capture cadence: ~49.89 fps;
- Present failures: 0;
- GPU-copy fallback: 0 frames;
- Present-call p50/p95/p99/max: ~0.20 / 0.33 / 0.90 / 7.96 ms;
- inter-arrival p50/p95/max: ~17.48 / 33.04 / 44.01 ms.

The earlier ~169 ms inter-arrival outlier from the 20-second smoke did not recur in this longer run.

The deterministic stimulus intentionally controls the real pointer during some phases; interactive mouse use/typing may be impractical while the scenario is active. This is expected test behavior.

Dated interpretation artifact:

`artifacts/2026-09-22__gpt-5.6-sol__spike1_physical_dual_monitor_validation_v0.2.md`

## Important coordinate observation

The run environment collector reported the laptop display as 1280x720 while the external display was 1920x1080 with an x-origin of 1920.

This strongly indicates that some collected display geometry is affected by DPI virtualization / differing coordinate spaces rather than representing one simple contiguous physical-pixel coordinate system.

That observation is now a direct input to Spike 2: pointer and coordinate truth.

## Timing interpretation

`Direct3D11CaptureFrame.SystemRelativeTime` remains a compositor QPC timestamp.

Signed differences between that timestamp and callback/render QPC are diagnostic only. They must not be called photon latency, end-to-end latency or frame age without additional evidence.

## What remains for Spike 1

Targeted follow-up only:

1. repeated physical runs if cadence/tail behavior needs characterization;
2. recorded vs unrecorded physical runs to measure recorder perturbation;
3. video/scenario/telemetry visual correlation;
4. monitor hot-plug and sleep/wake recovery;
5. mixed-DPI stress after coordinate-space behavior is understood;
6. later four-display and Doxa hardware validation.

These should not block starting the next capability spikes.

## Next development step

Proceed to Spike 2: pointer and coordinate truth.

Charter:

`lab/prototypes/spike2_pointer_coordinate_truth/CHARTER.md`

After coordinate truth is established, proceed to independent focus/caret evidence and viewport-policy spikes before integrating those mechanisms with the Spike 1 renderer.
