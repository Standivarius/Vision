# Engineering principles

## 1. Prove capabilities before integrating them

Build the smallest coherent mechanism that can answer a technical question. Avoid creating application architecture around an unproven behavior.

A spike may intentionally be narrow. Its implementation must not accidentally become the product architecture unless later evidence supports that promotion.

## 2. Design multi-monitor code as 1 -> N, not primary -> secondary

No reusable component may assume exactly two displays unless that assumption is explicit in a spike charter.

Prefer concepts such as:

- `DisplayId`;
- `Source`;
- `PointOfInterest`;
- `View`;
- `Destination`;
- `DisplayRole`.

Avoid architecture built around `primaryMonitor` / `secondaryMonitor` semantics.

## 3. Keep Source -> POI -> View -> Destination separable

The core conceptual pipeline is:

**Source -> Point of Interest -> View transformation -> Destination**

Capture is not tracking. Tracking is not viewport policy. View transformation is not display identity. Keep these separable so failures can be diagnosed and mechanisms can be replaced independently.

## 4. POI signals are evidence, not truth

Pointer position, UI Automation focus, text caret, Win32 focus and application-specific signals can disagree or disappear.

Tracking policy should:

- know the evidence source;
- carry confidence/freshness where useful;
- tolerate missing signals;
- recover without catastrophic state changes.

Do not treat UI Automation as a universal caret/focus oracle.

## 5. Coordinate spaces must be explicit

Do not use an implicit universal pixel space.

Name and convert between relevant spaces explicitly, including:

- virtual-desktop screen coordinates;
- per-monitor physical pixels;
- DPI-scaled logical coordinates where APIs expose them;
- source texture coordinates;
- destination/view coordinates;
- application/client coordinates where needed.

Tests must include negative virtual-desktop coordinates and mixed DPI/topology.

## 6. Per-view state, not one global magnifier

Long-term state should be attributable to a view/destination or logical role:

- zoom;
- source;
- crop/viewport;
- follow policy;
- visual effects;
- frozen/live state;
- locator behavior.

Global state should exist only when the product concept genuinely requires it.

## 7. Recovery is normal operation

Display hot-plug, sleep/wake, docking, source resize, application destruction, WGC lifecycle changes and missing accessibility signals are expected states.

Design recovery paths early enough that a successful happy-path prototype does not hide an unusable lifecycle model.

## 8. Share expensive work

Four displays must not imply four redundant full-rate capture pipelines.

Where multiple views originate from one source, prefer shared GPU-backed capture/frame state and separate lightweight view transformations.

Static/frozen/reference views should not consume active-Detail resources unnecessarily.

## 9. Deterministic mechanisms before AI

If Windows, telemetry or a rule can determine a fact reliably, use that mechanism.

Do not place cloud AI in latency-critical paths such as:

- capture/render;
- pointer/caret/focus tracking;
- viewport movement;
- frame scheduling.

AI may assist diagnosis, routing, support and interpretation where latency and nondeterminism are acceptable.

## 10. Privileged actions must be bounded

Installers and support agents may reason broadly, but execution must go through explicit deterministic actions.

Examples:

- enumerate hardware;
- inspect driver package/version;
- stage/install an approved signed package;
- restart an approved service;
- collect logs;
- run a known diagnostic;
- restore a known configuration.

Do not give an LLM unrestricted administrator shell authority as a product support mechanism.

## 11. Windows-native and simple by default

Prefer direct Windows APIs and minimal dependencies where they fit the problem.

Do not add frameworks, abstraction layers or services merely for architectural neatness.

New dependencies require a concrete benefit in reliability, development speed, deployment or maintainability.

## 12. Measure before optimizing

Measure:

- capture cadence;
- software frame timing;
- Present behavior;
- recovery time;
- CPU/GPU cost;
- repeated/stale frames;
- user-visible behavior when possible.

Do not label software timestamp differences as photon/user-visible latency without evidence that supports that interpretation.

## 13. Separate accessibility quality from benchmark quality

A good p95 timing number does not prove a good low-vision experience. Jitter, unexpected viewport movement, pointer loss and loss of context can be more damaging than modest absolute delay.

Combine objective telemetry with repeatable visual scenarios and human observation.

## 14. Preserve clean-room boundaries

Competitor behavior may be observed through legitimate use and public documentation. Open-source implementations may be studied subject to license requirements.

Do not obtain or incorporate proprietary competitor source, assets or confidential implementation details.

Record OSS provenance when code is reused.

## 15. Preserve unrelated work

Before editing existing implementation:

1. inspect relevant files;
2. understand dependencies and local conventions;
3. make the smallest coherent change;
4. verify it;
5. do not overwrite unrelated work.

No destructive Git operations without explicit authorization.
