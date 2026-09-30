# Architecture baseline

This document contains current architecture conclusions that are sufficiently supported to guide implementation. It is intentionally not a full product design.

## Current implementation direction

**Working, now supported by physical two-monitor evidence:** Windows Graphics Capture (WGC) + D3D11 is the leading capture/render path for the first cross-monitor Detail capability.

Spike 1 has demonstrated the path on a real physical two-monitor console session with a full deterministic 60-second scenario, no Present failures and no GPU-copy fallback. This is enough to continue building on the approach while keeping lifecycle recovery, USB-display/cross-adapter behavior, four-display scaling and user-visible latency characterization as unresolved engineering work.

Do not maintain a parallel Desktop Duplication implementation merely for symmetry. Revisit it only if WGC exposes a concrete limitation.

## Core transformation model

```text
Source
  -> Point of Interest evidence
  -> tracking / viewport policy
  -> View transformation
  -> Destination
```

The rendering subset is:

```text
Capture source
  -> GPU-backed frame
  -> crop / scale / visual transformation
  -> destination surface
```

The intent/tracking subset is:

```text
Pointer / caret / focus / app evidence
  -> POI candidates
  -> tracking policy
  -> viewport target
  -> View transformation
```

These layers should remain replaceable and independently testable.

## Technology baseline

Current direction:

- C++20;
- Win32 windowing/input/display APIs;
- C++/WinRT where appropriate;
- D3D11;
- DXGI;
- Windows Graphics Capture;
- Per-Monitor-V2 DPI awareness;
- QueryDisplayConfig/display-path evidence;
- QPC-based software timing;
- CMake / Visual Studio Build Tools.

Do not generalize this into a permanent requirement for every Visual component. Use it where it fits the mechanism being proven.

## Display model

The long-term model must support an arbitrary set of active displays, not exactly two.

A display record should eventually distinguish:

- persistent/physical identity where available;
- current Windows topology identity;
- bounds and orientation;
- DPI/scaling;
- resolution/refresh;
- adapter/path information;
- logical Visual role;
- availability state.

Windows display index/order is not a persistent product identity.

Public PowerToys implementation evidence supports using a composite/tolerant monitor identity rather than trusting one display number. The exact Visual matching algorithm remains unresolved and must be tested on real Doxa hardware, especially if several panels are identical.

## Representative topology

**Established product target:** laptop + three external Doxa displays = four active Windows screens.

**Engineering strategy:** two displays are sufficient for the first cross-monitor relationship spikes. Later tests expand to one source feeding multiple views, multiple relationships and four physical displays.

## Multi-view architecture

The architecture should permit:

- one source -> one destination;
- one source -> several destinations/views;
- several independent source/destination relationships;
- frozen/reference views that retain prior content;
- role-based destinations independent of physical monitor numbering.

Do not instantiate a separate high-cost capture pipeline simply because another destination exists. Reuse source frames/textures when practical, but measure fan-out cost rather than assuming it is free.

## Coordinate model

Coordinate spaces must be explicit and conversions testable.

Spike 2 has now established a successful physical mixed-DPI baseline using a Per-Monitor-V2-aware process. On the tested two-display topology, pointer positions crossed a real 150%/100% DPI boundary with zero expected-vs-observed coordinate error, and `GetMonitorInfo`, `EnumDisplaySettingsEx` and `QueryDisplayConfig` source geometry agreed.

The current reusable coordinate model explicitly distinguishes:

- virtual-desktop screen coordinates;
- monitor rectangles;
- monitor-local coordinates;
- normalized monitor coordinates.

Do not adopt an unlabelled single `x/y` domain. Windows APIs expose different coordinate semantics depending on DPI awareness, API family, window context and capture surface.

The design must handle:

- negative virtual-desktop coordinates;
- monitors arranged above/below/left/right;
- mixed DPI;
- mixed resolution/refresh;
- source texture size changing independently of desktop coordinates;
- pointer/caret/focus evidence reported in different spaces.

Synthetic tests cover negative/vertical layouts; targeted physical topology variants remain follow-up validation.

## POI/tracking model

Point-of-interest sources may include:

- mouse pointer;
- text caret;
- keyboard focus;
- active window/control;
- explicit user target;
- later application-specific evidence.

POI evidence is fallible. Tracking policy should decide what to follow, how quickly, when to hold still and how to recover when evidence disappears or conflicts.

Pointer/caret/focus visibility and viewport following are separate capabilities. A valid signal does not automatically require viewport movement.

## UI Automation and focus/caret evidence

UI Automation is an important conditional source for focus/text information, but not a universal solution.

Expect:

- applications with incomplete providers;
- embedded/browser/electron/custom controls;
- protected/elevated surfaces;
- multiple text APIs;
- stale or missing events.

The next tracking spike should compare UI Automation semantic evidence with Win32/WinEvent/GUI-thread evidence rather than hiding fallbacks inside rendering code.

Working fallback principle:

`semantic UIA evidence -> Win32 corroboration/fallback -> contextual focus evidence -> no automatic movement`

Incorrect automatic movement is worse than remaining still when the location evidence is unreliable.

## Feature-facing architecture

The architecture should remain compatible with the canonical `feature_roadmap.md`, especially:

- persistent Context + Detail;
- independent per-view visual state;
- inspect-and-return;
- pointer/caret/focus finding;
- fixed/frozen reference;
- monitor roles/workspace recall;
- simple per-view visual states;
- later presentation/share-safe workflows.

Avoid architecture that makes these require unrelated rewrites, but do not pre-build all of them before their value/mechanism is tested.

## Privilege model

UIAccess is not a general privileged accessibility solution and should not be treated as a shortcut around Windows isolation.

Visual should run at ordinary user privilege unless a specific bounded operation requires elevation. Installation/driver repair should use explicit elevation/UAC through a deterministic installer/support action.

## Hardware boundary

The Visual rendering/tracking architecture should not depend on a specific Doxa USB display controller.

Doxa-specific hardware management—driver/firmware detection, device health, installation and support—belongs behind a hardware/diagnostic boundary documented under `docs/project/hardware/`.

This separation lets Visual remain testable on normal Windows monitors while still supporting a certified Doxa hardware path.

## Public/open-source precedent boundary

Technical precedents that actively inform development are summarized in `implementation_precedents.md`.

They include:

- Microsoft PowerToys for composite monitor identity, workspace limitations and pointer utilities;
- Microsoft WGC/composition samples for capture interop reference;
- Microsoft Desktop Duplication samples as a comparator/fallback path;
- Microsoft Magnification samples as behavioral/prototype reference;
- HoverText as supporting evidence for layered/fallback accessibility strategies.

These precedents inform what to test. They do not replace project-specific experiments or provenance requirements for any actual source reuse.

## Open architecture questions

Still unresolved:

- user-visible latency/freshness characterization beyond software timing;
- WGC behavior across Doxa USB display adapters and cross-adapter paths;
- best caret/focus evidence hierarchy across representative applications;
- viewport arbitration and motion policy;
- monitor persistent-identity strategy for identical Doxa panels;
- exact Doxa USB graphics controller and firmware model;
- HDR/color-space behavior;
- one-source-to-many-view performance at four-display scale;
- eventual presentation model if D3D11 becomes limiting.

Resolve these through targeted experiments, not speculative abstraction.
