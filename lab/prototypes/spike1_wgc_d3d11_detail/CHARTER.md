# Spike 1 Charter — WGC → D3D11 Cross-Monitor Detail

**Project:** Visual  
**Machine:** MARIUS-DELL  
**Date:** 2026-09-19  
**Status:** Approved to implement after charter review  
**Location:** `lab/prototypes/spike1_wgc_d3d11_detail/`

## 1. Decision this spike must enable

Determine whether Windows Graphics Capture (WGC) plus D3D11 is technically credible for Visual's first cross-monitor **Detail** experience on an ordinary Windows dual-monitor system.

This spike is not a product prototype. It exists to answer whether the core loop is responsive, stable, measurable, and recoverable enough to justify further architecture work.

The result must support one of these decisions:

- **Continue with WGC + D3D11 as the leading capture/render hypothesis.**
- **Keep WGC but change presentation/lifecycle strategy.**
- **Benchmark Desktop Duplication before further WGC work.**
- **Stop and revise the core capture/render direction.**

## 2. Primary hypothesis

> WGC can provide fresh enough GPU-backed frames for a continuously magnified cross-monitor Detail view, rendered through D3D11, without persistent stale-frame behavior or unacceptable instability during ordinary interactive Windows use.

This hypothesis is deliberately narrower than “WGC is the production architecture.”

## 3. Secondary hypotheses

1. A single WGC capture session can feed a cropped/scaled D3D11 Detail output without requiring third-party graphics libraries.
2. Pointer-centred source-region selection is sufficient for this spike and can be kept independent from future caret/focus tracking.
3. The capture/render loop can detect and recover from ordinary source-size/topology lifecycle changes without requiring application restart.
4. The pipeline can expose enough timing data to distinguish:
   - capture-frame age;
   - application processing delay;
   - presentation cadence;
   - dropped/stale frames;
   - recovery gaps.
5. The first implementation can remain small enough that failure points are attributable rather than hidden behind production abstractions.

## 4. Explicit non-goals

Spike 1 must **not** include:

- caret tracking;
- keyboard-focus tracking;
- UI Automation;
- UIAccess;
- Doxa-specific hardware logic;
- workspace restoration;
- monitor roles;
- settings UI;
- installer/package work;
- application profiles;
- speech;
- OCR;
- same-monitor Inspect;
- Desktop Duplication implementation;
- Direct3D 12;
- HDR correctness beyond detecting/logging the environment state;
- production-level graphics abstraction layers;
- arbitrary multi-view fan-out;
- third-party graphics frameworks.

If a non-goal becomes necessary to make the spike run, that is evidence that the proposed minimal architecture is more complex than expected and must be documented before adding it.

## 5. Minimal user-visible behavior

On an interactive Windows desktop with at least two active displays:

1. Start the spike executable.
2. Enumerate active displays and graphics adapters and write them to the run log.
3. Select a source display and a destination display.
   - For the first version, deterministic defaults are acceptable: source = display containing the pointer at launch or primary display; destination = another active display.
   - Command-line overrides are preferred over a settings UI if selection is needed.
4. Create a WGC capture item for the source display.
5. Receive WGC frames as D3D11 surfaces.
6. Read the current global mouse position.
7. Select a source crop centred on the mouse position.
8. Render that crop enlarged on the destination display in a borderless output window.
9. Support at least fixed 2× and 4× zoom through a command-line/startup option or minimal key toggle.
10. Continuously log timing/cadence/recovery telemetry.
11. Shut down cleanly without leaving capture sessions or windows behind.

No polished controls are required.

## 6. Implementation constraints

### Language and build

- Native C++20.
- CMake.
- Visual Studio 2022 Build Tools / MSVC x64.
- Windows SDK 10.0.26100.0 or the verified installed SDK selected by CMake.

### Windows APIs

Use only the minimum required Windows facilities:

- Windows Graphics Capture;
- C++/WinRT;
- D3D11;
- DXGI;
- Win32 windowing/input/display APIs;
- QPC / high-resolution timing facilities.

### Graphics

- D3D11 device.
- WGC frame pool backed by D3D11.
- Borderless destination HWND.
- DXGI swap chain, preferably flip-model if the minimal implementation supports it cleanly.
- GPU crop/scale path preferred.
- Avoid CPU readback in the normal rendering path.

### DPI

- Process must use **Per-Monitor V2 DPI awareness** from the start.
- Pointer and monitor geometry used in this spike must be logged with explicit coordinate-space assumptions.
- Spike 1 does not attempt the full typed-coordinate architecture required later, but must not silently mix logical and physical coordinate values.

## 7. Source/destination safety rules

- Source and destination must be different active displays for the primary test mode.
- The destination Visual window must not accidentally become the source display.
- Same-monitor recursion/exclusion is out of scope.
- If fewer than two active displays are detected, the executable must fail clearly with a diagnostic rather than silently alter the experiment.

## 8. Runtime environment logging

Every run must record enough environment state to make measurements interpretable.

At minimum:

- timestamp;
- Visual spike build/version identifier;
- Windows build/version;
- CPU model;
- GPU adapter name(s), LUID where practical, and driver version if obtainable without unrelated complexity;
- active display count;
- display device names/identifiers where available;
- virtual-desktop bounds;
- per-display desktop rectangle;
- primary-display flag;
- resolution;
- refresh rate;
- rotation/orientation;
- DPI/scaling information;
- source display;
- destination display;
- source and destination adapter ownership where discoverable;
- HDR state if easily queryable, otherwise `unknown`;
- WGC pixel format;
- WGC frame-pool buffer count;
- destination swap-chain format and buffer count;
- zoom factor;
- source crop dimensions;
- whether WGC cursor capture is enabled.

This runtime enumeration becomes the authoritative interactive display baseline; the background repository bridge's display enumeration is not authoritative.

## 9. Telemetry to collect

The spike must produce machine-readable per-frame or sampled telemetry sufficient to compute the following.

### WGC frame data

- frame sequence number;
- WGC `SystemRelativeTime` / equivalent frame timestamp;
- application frame-arrival QPC timestamp;
- captured content size;
- whether content size changed;
- whether the frame was consumed or intentionally skipped.

### Render/presentation data

- QPC immediately before crop/render submission;
- QPC immediately after command submission where meaningful;
- presentation-call timestamp;
- presentation result/status;
- destination frame sequence number.

### Derived metrics

At minimum calculate or make calculable:

- **frame age at application receipt**;
- **frame age at presentation submission**;
- inter-arrival interval distribution;
- presentation interval distribution;
- effective capture cadence;
- effective presentation cadence;
- repeated/stale-frame indicators where detectable;
- dropped/skipped frame count;
- longest gap between fresh captured frames;
- longest destination presentation gap;
- recovery duration after lifecycle events.

Do not label any single timestamp subtraction as “end-to-end photon latency.” This spike has no external optical measurement device. Software timing is a proxy and must be described as such.

## 10. Test scenarios

Run each scenario long enough to expose cadence problems, not just for a few seconds.

### Baseline

- Static desktop.
- Pointer movement across source monitor.
- 2× zoom.
- 4× zoom.

### Interactive stress

- Rapid pointer movement.
- Smooth and rapid web-page scrolling.
- Dragging a window around the source display.
- Typing into a normal text editor/browser field.
- Playing ordinary video while moving the pointer/crop.

### Display lifecycle

Where practical without disrupting the development environment:

- resize/change resolution of the captured source;
- change source-monitor scaling if practical;
- disconnect/reconnect the non-primary external display;
- sleep/resume as a later manual run within this spike;
- restart the spike after a topology change and compare enumerated state.

The implementation should attempt automatic WGC frame-pool/session recovery for changes that are observable within the running process. Failures must be logged explicitly.

## 11. Initial run durations

- Development sanity runs: 1–5 minutes.
- Measurement runs: at least 10 minutes per major interactive scenario where practical.
- Stability/soak run before concluding the spike: **30 minutes minimum** of mixed interaction.

A later multi-hour soak belongs to pre-production reliability work unless the 30-minute run reveals progressive failure.

## 12. Measurement interpretation

The research phase suggested a provisional p95 Point-of-Interest→Detail target around 50 ms, but DR-05 correctly challenged treating that number as an established user threshold.

Therefore Spike 1 will not use “p95 < 50 ms” as an automatic pass/fail gate.

Instead it will report:

- p50 / p90 / p95 / p99 software-observed frame age at presentation submission;
- cadence distribution;
- visible qualitative observations during pointer motion/scrolling;
- frequency and duration of stale-frame episodes;
- lifecycle recovery behavior.

A later user-facing latency criterion should be based on behavioral testing and, if required, external high-speed-camera measurement.

## 13. Falsification criteria

The WGC-first hypothesis is considered **falsified or materially weakened** if any of the following persist after straightforward, non-architectural tuning:

1. **Persistent stale Detail:** the destination visibly trails ordinary pointer movement or scrolling in a way that makes continuous use uncomfortable, and telemetry confirms recurrent stale-frame age rather than only rendering/UI bugs.
2. **Cadence collapse:** WGC delivers substantially below the source monitor's usable interaction cadence for sustained periods on this machine, without an obvious correctable configuration issue.
3. **Frame backlog:** the application accumulates old frames or cannot maintain a latest-frame policy without pathological jitter.
4. **Recovery failure:** ordinary source-size/topology changes repeatedly require full process restart rather than deterministic session/frame-pool recreation.
5. **Unexpected CPU path:** acceptable behavior requires regular GPU→CPU→GPU copies or another expensive workaround contrary to the intended architecture.
6. **Destination instability:** the D3D11 presentation path exhibits persistent tearing/stutter/blanking that is not attributable to a trivial implementation defect.
7. **Excessive implementation coupling:** basic cross-monitor Detail cannot be implemented without prematurely introducing caret/focus tracking, privilege elevation, Doxa-specific logic, or another supposedly unrelated subsystem.

A failure on MARIUS-DELL does **not** automatically prove WGC is unsuitable universally. It triggers diagnosis and, where appropriate, a controlled Desktop Duplication comparator spike.

## 14. Success criteria

Spike 1 is successful as an experiment if it produces a decisive, reproducible answer—even if the technical hypothesis fails.

The WGC + D3D11 direction remains credible if:

- the cross-monitor Detail loop runs continuously;
- interaction appears responsive enough to justify further testing;
- telemetry shows bounded frame age without persistent backlog;
- capture/presentation cadence is stable enough for normal desktop interaction;
- ordinary frame-size/topology changes can be recovered programmatically or have clearly bounded failure modes;
- 30-minute mixed-interaction soak completes without progressive corruption, resource exhaustion, or unrecoverable capture failure;
- implementation remains small and understandable;
- no third-party graphics dependency is required.

## 15. Architecture questions intentionally deferred

Spike 1 must not answer these unless results force the issue:

- WGC versus Desktop Duplication on Doxa USB displays;
- cross-adapter resource sharing on Doxa;
- multiple independent Detail outputs;
- source fan-out to two or three views;
- typed application-wide coordinate graph;
- caret/focus provider reliability;
- UIAccess;
- same-monitor Inspect;
- presentation/share-safe behavior;
- HDR production support.

These have their own later spikes.

## 16. File and directory scope

Implementation may modify/create only the following unless the spike exposes a documented need:

- `lab/prototypes/spike1_wgc_d3d11_detail/**`
- `lab/benchmarks/spike1_wgc_d3d11_detail/**`
- `artifacts/` only for dated result summaries/measurements that should be retained
- documentation updates directly related to the spike outcome

Do not move spike code into `app/` during this experiment.

## 17. Expected initial repository layout

```text
lab/prototypes/spike1_wgc_d3d11_detail/
├── CHARTER.md
├── CMakeLists.txt
├── README.md
└── src/
    ├── main.cpp
    ├── capture.*
    ├── renderer.*
    ├── display_topology.*
    └── telemetry.*
```

This layout is provisional. Prefer fewer files if the implementation is clearer that way.

## 18. Build and execution baseline

Preferred configuration:

```text
CMake generator: Visual Studio 17 2022
Architecture: x64
Configuration: Release for measurements
Language: C++20
```

Debug builds may be used for development but must not be used for performance conclusions.

The verified local toolchain is documented in:

`docs/project/development_environment_baseline.md`

## 19. Raw result storage

Machine-readable run data:

`lab/benchmarks/spike1_wgc_d3d11_detail/`

Each retained measurement run should include:

- environment metadata;
- runtime configuration;
- telemetry CSV/JSONL or equivalent;
- brief operator notes for the scenario;
- build identifier.

Large disposable captures/video recordings should remain in ignored capture/recording directories rather than Git history.

## 20. Interpretation artifact

After measurements are complete, create a dated result report under `artifacts/` using the project naming convention.

The report must separate:

- observed measurements;
- reproducible failures;
- qualitative observations;
- implementation bugs found/fixed during the spike;
- conclusions about WGC;
- questions still unresolved;
- recommendation for the next spike.

## 21. Stop rule

Do not allow Spike 1 to turn into Visual Alpha.

Stop implementation and analyze results once the spike can reliably:

1. enumerate the interactive display environment;
2. capture the source monitor using WGC;
3. render a pointer-centred magnified crop to another monitor;
4. record useful timing/cadence telemetry;
5. exercise basic capture lifecycle recovery;
6. complete the defined measurement/soak scenarios.

Any feature request beyond those six capabilities requires a new decision or a later spike.
