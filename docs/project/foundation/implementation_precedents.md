# Implementation precedents and technical discoveries

This document promotes the most relevant public/open-source implementation findings from the dated technical research into the current development baseline.

These are **precedents and hypotheses**, not instructions to copy an external architecture wholesale.

## Clean-room boundary

Commercial magnifier documentation may inform observable behavior and requirements only.

Do not infer or reproduce proprietary internals from ZoomText, SuperNova or other closed-source products.

Open-source code may be studied or adapted only with provenance and license handling consistent with `AGENTS.md`.

## Current precedents already influencing implementation

### Windows Graphics Capture + D3D11

Research finding:

- WGC provides monitor/window capture as GPU-backed Direct3D surfaces;
- D3D11 is sufficient for crop, scale, simple pixel effects and presentation;
- the architecture naturally supports an independent Detail window without transforming the source/context monitor.

Current project use:

- this directly informed Spike 1;
- the physical two-monitor WGC + D3D11 path is now validated strongly enough to remain the leading implementation direction.

Do not move to D3D12 without measured need.

### Source -> POI -> View -> Destination

Research finding:

A monitor should not be the root object of the magnifier architecture.

Current project use:

The canonical model is:

`Source -> Point-of-Interest evidence -> tracking/viewport policy -> View transformation -> Destination`

This enables:

- one source -> multiple views;
- cross-monitor Detail;
- independent view state;
- frozen/reference views;
- logical display roles independent of monitor numbering.

This is already reflected in `architecture_baseline.md` and should govern future integration.

### Per-Monitor V2 DPI + explicit coordinate spaces

Research finding:

Windows exposes several coordinate semantics; mixed DPI and RDP can silently virtualize geometry.

Current project use:

- Spike 2 embeds PMv2 awareness;
- `GetMonitorInfo`, `EnumDisplaySettingsEx` and `QueryDisplayConfig` are compared explicitly;
- pointer coordinates are represented as named screen/monitor-local/normalized spaces;
- the previous DPI-virtualized 1280x720 laptop geometry was experimentally distinguished from the PMv2 1920x1080 physical desktop geometry.

The implementation must continue to avoid unlabelled generic `x/y` coordinate assumptions.

### Layered caret/focus evidence

Research finding:

No single public Windows API is a universal caret/focus oracle.

Useful public mechanisms include:

- UI Automation focus events;
- UI Automation `TextPattern2` / caret ranges where supported;
- WinEvent hooks;
- `GetGUIThreadInfo` / classic GUI caret/focus evidence;
- current foreground/focus context.

Current development implication:

Spike 3 should compare these sources and build a provider/fallback model.

Working fallback principle:

`semantic UIA evidence -> Win32 corroboration/fallback -> contextual focus evidence -> no automatic movement`

An uncertain automatic pan is worse than remaining still.

### QueryDisplayConfig for topology/path evidence

Research finding:

`QueryDisplayConfig` / `DisplayConfigGetDeviceInfo` provide active display-path/source/target information without relying on simple monitor numbering.

Current project use:

- Spike 2 already records QueryDisplayConfig geometry and identity evidence;
- future monitor-role persistence should build on this rather than `Monitor 1/2/3` numbering.

## Open-source/public implementation precedents to retain

### Microsoft PowerToys

Research provenance:

- repository: `https://github.com/microsoft/PowerToys`;
- license: MIT;
- research snapshot examined at commit `cb25632f5b61eb2e57a3b0b52053409403ae9e98` dated 2026-09-18.

Relevant patterns:

- FancyZones persists multiple monitor identity signals rather than trusting one display number;
- monitor records include concepts such as monitor instance ID, serial, number, DPI, virtual desktop identity and geometry;
- Workspaces demonstrates best-effort app launch/reposition behavior and practical limitations;
- Mouse Utilities provide public precedent for Find My Mouse, Mouse Jump, crosshairs and monitor-transition utilities.

Visual implication:

- use a composite/tolerant monitor identity model;
- treat workspace restoration as best-effort;
- pointer locator/jump/boundary features are established interaction patterns worth selectively adapting conceptually.

Do not copy PowerToys components blindly. If source is reused, record exact files, license/provenance and modifications.

### Microsoft Windows.UI.Composition-Win32-Samples

Research provenance:

- Microsoft repository;
- MIT;
- examined at commit `ee50e2ea137dcef7b82ba504eff7435e5ebf5294`.

Relevant pattern:

- concrete Win32 GPU screen-capture/composition examples.

Visual implication:

- educational/reference implementation for Windows capture/composition interop;
- useful when hardening or comparing our own WGC setup;
- not a production architecture to import wholesale.

### Microsoft Windows classic Desktop Duplication sample

Research provenance:

- `Microsoft/Windows-classic-samples`;
- repository-level MIT with normal per-file/license due diligence required;
- research examined the official DXGI Desktop Duplication sample.

Relevant pattern:

- per-output `IDXGIOutputDuplication` capture into D3D11 textures;
- useful comparator/fallback if WGC exposes a material limitation.

Visual implication:

Desktop Duplication remains a measured alternative, not a parallel implementation to maintain merely for symmetry.

### Microsoft Windows Magnification API sample

Relevant pattern:

- public example of Windows' assistive magnification control model.

Visual implication:

- useful for behavior/reference spikes and possibly cheap same-screen experiments;
- not currently preferred for the many-source/many-view product architecture.

### HoverText

Research provenance:

- repository: `https://github.com/ferhas/hovertext`;
- MIT;
- examined around commit `df3419496bd11db380ffd843793b23c181a8cfb1`, version 0.2.0, 2026-06-05.

Relevant pattern:

- independently uses layered/fallback strategies rather than assuming one Windows mechanism works everywhere;
- includes multiple magnifier backends and UI Automation-first text handling with fallbacks.

Visual implication:

- supports the general architectural idea of capability/fallback layers;
- maturity is insufficient to treat its specific implementation choices as proven production guidance;
- OCR-heavy behavior is not an initial Visual runtime goal.

## Technical hypotheses still intentionally unresolved

### Desktop Duplication versus WGC

Earlier research recommended head-to-head comparison as a possibility.

Current evidence update:

- WGC + D3D11 has now passed the first physical two-monitor viability hurdle;
- therefore a parallel Desktop Duplication implementation is **not currently justified**;
- revisit it only if WGC shows concrete limitations in latency, USB-display compatibility, multi-adapter behavior or lifecycle recovery.

### Cross-adapter / USB-display behavior

Still unresolved until Doxa or representative USB-display hardware is attached.

Need to measure:

- WGC source behavior;
- D3D resource/device ownership;
- cross-adapter presentation/copy costs;
- capture freshness;
- four-display scheduling and source fan-out.

### Monitor persistence identity

PowerToys demonstrates composite identity as a practical precedent, but Visual's exact matching algorithm remains unresolved.

Working future hierarchy:

`exact strong identity -> strong hardware metadata -> topology/geometry match -> user reassignment`

This must be validated on real Doxa panels, especially if several are identical.

### Fixed/frozen reference

Research suggests this is technically natural in a custom renderer: retain one captured texture/view or update only on demand.

Do not over-engineer arbitrary semantic hooked regions before whole-view/reference workflows are proven useful.

### One source -> multiple destinations

The custom GPU architecture makes source-frame fan-out plausible.

Do not assume it is free. Measure it later with multiple active Doxa views rather than instantiating redundant capture pipelines by default.

## Development rule

When implementing a subsystem covered by this document:

1. inspect the current Visual code and evidence first;
2. use these precedents to choose what to test, not to skip testing;
3. prefer the smallest Windows-native implementation that answers the question;
4. retain provenance if any third-party code is actually adapted;
5. update this foundation when experiment evidence materially changes a precedent or hypothesis.

## Provenance

Primary technical evidence remains in:

- `artifacts/2026-09-19__gpt-5.6-sol__technical_feasibility_implementation_patterns_architecture_hypotheses_v0.1.md`;
- `artifacts/2026-09-19__gpt-5.6-sol__adversarial_technical_review_architecture_hypotheses_v0.1.md`;
- relevant dated Spike 1 and Spike 2 evidence artifacts.

This file is the current implementation-facing synthesis.
