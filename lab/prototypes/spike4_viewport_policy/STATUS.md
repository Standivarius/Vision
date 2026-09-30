# Spike 4 Status

**Date:** 2026-09-22

## Current state

Spike 4 has a working deterministic viewport-policy baseline and has produced code suitable for promotion into the application core.

The baseline policy implements:

- hold when the selected POI is already comfortably visible;
- minimum required pan when the POI exits the comfort area;
- jump classification for large displacements;
- source-bound clamping;
- oversized-POI centering;
- manual tracking disable;
- negative-coordinate source spaces;
- invalid-geometry rejection;
- stable repeated input with no drift.

## Validation

Release build succeeds.

CTest result:

- `viewport_policy_tests`: 1/1 passed;
- failures: 0.

The defaults are experimental policy values, not product promises:

- horizontal comfort margin: 20%;
- vertical comfort margin: 20%;
- jump threshold: 75% of viewport dimension.

These must later be tuned using actual magnified use rather than treated as final UX values.

## Product interpretation

The viewport controller now has a clean boundary:

`selected POI rectangle -> hold/pan/jump target viewport`

It does not know whether the POI came from the mouse, UI Automation, Win32 caret evidence or explicit user input.

That is the intended architecture for the two-screen MVP.

## Promotion

The proven renderer-independent concepts from Spikes 2–4 have now begun promotion into:

`app/src/core/`

Application-core components currently include:

- `coordinate_model.h`;
- `poi_evidence.h`;
- `viewport_policy.h`.

The application pipeline test validates the combined chain:

`coordinate model -> POI selection -> viewport decision`

Current application-core Release result:

- build succeeds;
- `core_pipeline_tests`: 1/1 passed.

## Next work

The next major step is no longer another pure policy spike. It is integration work:

1. create the first real Visual application executable target;
2. bring the proven Spike 1 WGC/D3D11 capture/render path into the app behind a small source/detail interface;
3. feed pointer evidence through the promoted POI/viewport core;
4. then add caret/focus providers behind the same POI interface;
5. add zoom/return commands and basic locator behavior;
6. run the first integrated two-screen alpha.

Animation/easing and detailed viewport tuning can remain simple initially; correctness and predictable hold/minimum-movement behavior come first.
