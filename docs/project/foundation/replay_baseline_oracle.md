# Vision replay / baseline oracle v0.1

Status: Batch 1 Gate 0A test contract. The oracle is a refactor safety rail, not a new runtime subsystem.

## Purpose

A structural change may only be called behaviour-preserving when the current evidence/arbitration/viewport decisions can be replayed deterministically from recorded inputs.

The oracle therefore isolates the existing core decision path from live UIA, Win32 timing and WGC presentation.

## Replay input

Each replay frame contains:

- source physical rectangle
- zoom
- tracking enabled/disabled
- locator enabled/disabled
- candidate pointer/caret/focus/explicit-target evidence
- candidate geometry/source/confidence/timestamp/identity
- current replay timestamp and QPC frequency

A sequence is replayed through one persistent ViewController so temporary-normal/return and viewport history are preserved.

## Replay output

Each frame records:

- selected POI, if any
- viewport
- viewport action
- exact-return flag
- locator visibility/normalized geometry

## Golden evidence

The first golden case is seeded from:

`lab/benchmarks/integrated_app/runs/2026-09-30_16-57-00__mouse_viewport_smoke/visual_app_telemetry.csv`

Observed current behaviour at 2x:

- selected pointer rect: `(640,360)-(641,361)`
- resulting viewport: `(160.5,90.5)-(1120.5,630.5)`
- after pointer evidence ages out, older semantic evidence does not reclaim the viewport and the viewport holds

The test fixture recreates that observed output using the current core policy.

## Current coupling made explicit

The current core can hold the viewport while still deriving a locator from selected evidence. However, the runtime renderer still derives locator visibility from the **selected POI** produced by the shared arbitration path. This means target visibility is not yet an independently routed per-view concern.

Gate 0A therefore preserves two facts at once:

- tracking-off can hold the viewport while a selected target remains visible;
- the identity of that visible target is still coupled to the arbitration winner.

Policy Slice P2 is the named behaviour/model change that later separates visibility routing from movement/follow eligibility.

## Rules

- Known defects can remain golden during structural slices if explicitly labelled as known-current behaviour.
- Policy fixes require a named behaviour-change slice and updated expected output.
- A deliberate input perturbation must change the relevant golden output; otherwise the oracle is too weak.
- The replay suite runs before and after every structural slice.
- Raw acceptance evidence remains the evidence source; replay summaries do not replace it.
