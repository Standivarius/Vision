# Spike 4 — Viewport policy

**Date:** 2026-09-22  
**Project:** Visual  
**Status:** implementation starting

## Question

Can Visual turn a reliable point-of-interest rectangle into predictable magnified-viewport movement without unnecessary recentering, jitter or provider-specific logic?

## Product reason

Correct tracking evidence is not enough. A low-vision magnifier can still be uncomfortable if every pointer/caret/focus update moves the view.

The viewport policy should preserve spatial stability whenever the active target is already comfortably visible, then move only enough to restore a useful margin when the target leaves that comfort area.

## Primary hypothesis

A small, deterministic policy based on:

- a configurable comfort/safe area inside the current viewport;
- minimum required translation;
- source-bound clamping;
- an explicit hold / pan / jump decision;
- upstream POI arbitration;

is sufficient for a first two-screen Visual alpha and can later be tuned with physical/user evidence without rewriting the rendering path.

## Architecture boundary

Input:

- source bounds in one explicit coordinate space;
- current viewport rectangle in that same space;
- selected POI rectangle in that same space;
- viewport policy configuration;
- manual-follow enabled/disabled state.

Output:

- action: `Hold`, `Pan`, `Jump` or `Invalid`;
- target viewport rectangle;
- requested translation;
- reason/diagnostic state.

The policy does **not** know whether the POI came from mouse, caret, focus, UI Automation or Win32. Provider selection belongs upstream.

The policy does **not** render or animate. A later motion layer may interpolate a `Pan` target. The renderer receives a resulting viewport transformation.

## Baseline policy

1. Define an inner comfort rectangle by insetting the current viewport by configurable horizontal/vertical margin ratios.
2. If the POI fits inside that comfort rectangle, hold the viewport exactly still.
3. Otherwise compute the minimum translation needed to place the POI back inside the comfort area.
4. If the POI is larger than the comfort area on an axis, center that POI on that axis rather than chasing both edges.
5. Clamp the target viewport to source bounds.
6. Classify a small displacement as `Pan` and a large displacement as `Jump` using a configurable fraction of viewport width/height.
7. If tracking is disabled/manual override is active, hold.
8. Invalid geometry must not create movement.

## Initial configuration is experimental

Default margin/jump values in the spike are test parameters, not product promises.

The first goal is deterministic behavior and clean separation of policy from rendering. User testing should later tune:

- comfort margins;
- separate horizontal/vertical margins;
- jump threshold;
- pan animation speed/easing;
- pointer versus caret policy differences if evidence supports them;
- hysteresis/re-entry behavior;
- temporary manual override.

## Synthetic scenarios

Automated tests should cover:

- target already safely visible -> exact hold;
- target slightly beyond left/right/top/bottom comfort edge -> minimum pan;
- far target -> jump classification;
- source-bound clamping;
- oversized POI;
- negative-coordinate source spaces;
- manual tracking disable;
- invalid source/viewport/POI geometry;
- stable repeated input (no drift).

## Success criteria

The spike succeeds when:

- identical input produces identical target/output;
- a safe POI produces zero viewport movement;
- movement is the minimum required by the configured comfort margins, subject to source clamping;
- negative source origins work without special cases;
- provider/API details are absent from the viewport component;
- tests make the behavior auditable enough to tune later.

## Explicit exclusions

Do not include yet:

- GPU rendering;
- UI Automation;
- pointer/caret provider selection;
- animation/easing implementation;
- app-specific rules;
- settings UI;
- four-screen role logic;
- persistence;
- complex predictive motion.

## Graduation target

The output contract should be suitable for the first integrated two-screen alpha:

`POI evidence -> POI selection -> viewport policy -> renderer`

After the pure policy is proven, integrate it first with deterministic/synthetic POIs, then with Spike 1 rendering and Spike 2/3 live evidence.
