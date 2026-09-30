# Experimentation and validation

## Purpose

Spikes exist to answer bounded engineering questions with evidence. They are not mini-products and should not accumulate unrelated features.

## Required spike charter

Every material spike should state:

- hypothesis;
- minimum scope;
- environment;
- measurements/evidence;
- falsification criteria;
- allowed files;
- build/test command;
- raw results location;
- interpretation/report location;
- explicit exclusions.

## Capability-first sequence

Prefer this progression:

1. prove one mechanism;
2. reproduce it reliably;
3. characterize failure/recovery;
4. test representative edge cases;
5. record conclusions;
6. only then integrate with another proven mechanism.

Do not integrate several unproven mechanisms merely to make a more app-like demo.

## Evidence classes

Label evidence by environment because these are not interchangeable:

- physical console / physical monitor;
- RDP/remote display;
- screen recording;
- synthetic/test stimulus;
- external camera;
- user subjective observation;
- software telemetry;
- external documentation.

A successful RDP run proves the software path can execute in that environment. It does not prove physical-display performance.

## Timing discipline

Record raw clocks and API timestamps before interpreting them.

Do not call a timestamp subtraction:

- photon latency;
- end-to-end latency;
- frame age;

unless the clocks/semantics justify that label.

For user-visible timing, correlate deterministic stimulus, software telemetry and recorded/external visual evidence where practical.

## Automated scenario model

Repeatable scenarios should be preferred to ad-hoc manual motion when diagnosing graphics/tracking behavior.

A good run bundle can contain:

- environment metadata;
- scenario event log with QPC timestamps;
- Visual telemetry;
- screen recording where useful;
- run manifest;
- analysis summary;
- short human observation.

Recorded runs are diagnostic and may perturb performance. Compare important performance results with an equivalent unrecorded run.

## Current Spike 1 interpretation

Spike 1 asks whether WGC + D3D11 is credible for the first cross-monitor Detail relationship.

Earlier single-monitor/RDP runs validated the harness/tooling path but remain remote-session evidence rather than physical-display performance evidence.

### Physical dual-monitor evidence

The strongest current physical run is:

`lab/benchmarks/spike1_wgc_d3d11_detail/runs/2026-09-22_16-39-33__spike1_auto`

Observed/tested facts:

- session: physical `Console`;
- monitors reported by Visual: 2;
- mode: `cross_monitor_validation`;
- user observed correct live Detail behavior across the two physical displays;
- all six deterministic scenario phases ran;
- 3050 WGC frames over ~61.12 s;
- effective capture cadence ~49.89 fps;
- Present failures: 0;
- GPU-copy fallback: 0 frames;
- Present-call p95 ~0.33 ms;
- inter-arrival p95 ~33.04 ms;
- maximum inter-arrival ~44.01 ms.

The earlier ~169 ms tail outlier from the 20-second smoke did not recur in the 60-second run.

Interpretation:

The basic WGC + D3D11 physical cross-monitor viability question is sufficiently supported to stop being the main development blocker. Spike 1 remains available for targeted recovery, recording, soak, mixed-topology and later Doxa/four-display validation.

See:

`artifacts/2026-09-22__gpt-5.6-sol__spike1_physical_dual_monitor_validation_v0.2.md`

## Current Spike 2 interpretation

Spike 2 asks whether Visual can establish a reliable pointer/monitor coordinate foundation across mixed-DPI multi-monitor Windows topologies.

Strongest current physical run:

`lab/benchmarks/spike2_pointer_coordinate_truth/runs/2026-09-22_17-22-32__spike2_coordinate_truth`

Observed/tested facts:

- process is Per-Monitor-V2 aware;
- active physical displays: 2;
- virtual desktop: 3840x1080;
- DISPLAY1: 1920x1080 at 144 DPI (150% implied);
- DISPLAY2: 1920x1080 at 96 DPI (100% implied);
- 530 deterministic pointer samples;
- 10 monitor-transition samples;
- maximum expected-vs-observed pointer error: 0 px;
- inside-monitor violations: 0;
- normalized-coordinate violations: 0;
- expected-monitor mismatches: 0;
- `GetMonitorInfo`, `EnumDisplaySettingsEx` and `QueryDisplayConfig` source geometry agree for the tested topology.

The live probe now uses the same reusable coordinate component covered by automated tests.

Automated coordinate-model tests additionally cover negative X/Y monitor origins, vertical layouts, half-open Win32 rectangle edges, normalized round trips and invalid inputs. They pass in Release.

Interpretation:

The current mixed-DPI physical baseline supports using an explicit PMv2 screen -> monitor-local -> normalized coordinate model for subsequent POI work.

The earlier 1280x720 laptop geometry observed from a PowerShell/RDP-oriented collector was DPI-virtualized collection evidence, not the canonical physical coordinate space for Visual.

Targeted physical follow-up remains for negative-origin layouts, above/below arrangements, primary-display swap and eventually the four-screen Doxa topology.

See:

`artifacts/2026-09-22__gpt-5.6-sol__spike2_pointer_coordinate_baseline_v0.1.md`

## Monitor topology test progression

The target product is four active displays, but experiments should scale deliberately:

1. one display — local development and harness validation;
2. two displays — first independent source -> destination relationship;
3. one source -> two destinations;
4. two independent source/destination relationships;
5. four active physical displays with logical roles;
6. remove/reconnect one display during operation;
7. mixed DPI/resolution/refresh and non-trivial layout;
8. Doxa USB graphics hardware and any cross-adapter path.

The two-monitor stage now has positive physical evidence for both rendering/capture and pointer-coordinate behavior. It remains the minimum proof topology, not the product topology assumption.

## Tracking spike validation

Pointer/caret/focus spikes should record:

- evidence source;
- reported coordinate space;
- freshness/event timing;
- target application;
- success/failure mode;
- fallback path;
- recovery after target destruction/change.

Test across representative application families rather than relying on one well-behaved native control.

## Recovery tests

Treat these as ordinary test cases, not exotic faults:

- display sleep/wake;
- dock/undock;
- monitor hot-plug;
- WGC source resize;
- captured window closure;
- device/driver reset where safely reproducible;
- DPI/topology change;
- loss of POI evidence;
- application elevation mismatch;
- rendering/device loss where applicable.

## Promotion criteria

A mechanism may move from spike to reusable component when:

- its purpose and interface are clear;
- the main success path is repeatable;
- important failure/recovery paths are characterized;
- its evidence is recorded;
- its interface does not encode a known obsolete assumption;
- integration value is concrete.

Do not promote code solely because it already exists.

## Interpretation artifacts

Raw run output belongs under lab/benchmark locations and may be Git-ignored.

Decision-relevant conclusions should be promoted into dated `artifacts/` reports using the repository naming convention.

When a conclusion becomes stable enough to govern future development, synthesize it into `docs/project/foundation/`.
