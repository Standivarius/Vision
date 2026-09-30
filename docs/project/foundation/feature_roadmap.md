# Feature roadmap

This document is the current product-feature synthesis for Visual. It promotes the strongest conclusions from the dated feature/workflow research into a development-facing roadmap.

It is **not** a promise to reproduce incumbent feature sets. It separates product value from engineering sequence.

## Product principle

**Established:** Visual's strongest proposition is not simply higher magnification. It is using multiple physical displays to preserve orientation and task context while detail changes.

The current value thesis is:

**independent monitor state + persistent overview/detail + fast temporary enlargement + reliable pointer/caret/focus finding + simple monitor roles/workspace recall.**

Performance, predictability and recovery are product features. A technically impressive feature that causes unexplained movement, freezes or configuration burden has failed.

## Feature families

### 1. Persistent Context + Detail

**Priority: foundational / highest**

User problem:

- magnification makes detail readable but destroys surrounding spatial context;
- conventional full-screen magnification must continually move the viewport.

Visual direction:

- one display can remain a stable context/reference surface;
- another display can present magnified Detail;
- context may be 1x, lightly magnified or visually enhanced rather than always literally unmagnified;
- stable context should not move merely because pointer/caret/focus moves elsewhere.

Current engineering status:

- first two-display physical WGC + D3D11 Detail path validated in Spike 1;
- full product integration and per-view state remain future work.

### 2. Independent per-view / per-monitor visual state

**Priority: foundational / high differentiation**

Each view should eventually be able to represent its own:

- source;
- zoom;
- tracking policy;
- colour/contrast state;
- live/frozen state;
- logical role.

Do not model the product as one global magnifier setting applied to every display.

A single source may feed several destinations; several independent relationships may coexist.

### 3. Fast enlargement + exact return

**Priority: early alpha**

Research supports rapid enlargement and equally rapid recovery of context.

Target interaction:

- temporary Inspect / Detail enlargement around the current point of interest;
- preserve the target while zoom changes;
- release/escape returns to the exact prior Visual state rather than merely resetting to an arbitrary default;
- instant 1x/normal return remains cheap.

For early Doxa use, a dedicated Detail display is preferred over same-screen capture overlays because it is simpler and avoids self-capture recursion.

### 4. Pointer finding and monitor finding

**Priority: early alpha**

Separate these needs:

- make the pointer visually easy to locate;
- decide whether the magnified viewport should follow it;
- deliberately move/jump the pointer between monitors;
- optionally add boundary resistance or cues.

Do not conflate pointer enhancement with automatic viewport motion.

Potential early interactions:

- on-demand locator/spotlight;
- strong pointer state while switching monitors;
- explicit monitor jump;
- later configurable boundary resistance/cues.

Spike 2 has established the baseline pointer/coordinate foundation on a real mixed-DPI two-monitor desktop.

### 5. Caret and keyboard-focus finding + selective following

**Priority: early alpha / essential for sustained work**

Visual must distinguish:

- caret visibility/enhancement;
- caret following;
- keyboard-focus visibility/highlighting;
- keyboard-focus following.

A professional keyboard-first workflow cannot depend on mouse-only tracking.

Automatic movement must remain policy-driven. A valid focus/caret signal does not automatically mean the viewport should move immediately.

Current engineering direction:

- investigate UI Automation semantic signals;
- corroborate/fallback through Win32 GUI/accessibility signals;
- preserve a safe "no automatic movement" state when location evidence is unreliable.

### 6. Viewport behaviour

**Priority: early alpha / major UX differentiator**

Predictability matters more than raw animation smoothness.

The viewport controller should eventually support experimentally validated behavior for:

- dead zones;
- margins;
- hysteresis;
- slow pan vs jump;
- target anchoring during zoom;
- pointer-vs-caret-vs-focus conflict;
- manual override;
- recovery when POI evidence disappears.

Working product principle:

**visibility first, movement second.**

If the target remains comfortably visible, unnecessary movement should be avoided.

### 7. Monitor roles + workspace recall

**Priority: early-to-mid product**

Representative roles:

- Work;
- Detail;
- Context/Reference;
- Communication/Control.

Roles are logical and configurable; they are not physical monitor numbers.

Visual should distinguish:

- restoring Visual view/role state, which Visual controls;
- restoring ordinary application windows, which is best-effort;
- restoring application-internal state, which Visual generally cannot guarantee.

The normal Doxa topology is laptop + three external Doxa displays, but the same role model should work on ordinary Windows multi-monitor systems.

### 8. Fixed / frozen reference view

**Priority: early-to-mid product**

Useful workflows include keeping visible:

- source material;
- spreadsheet headings/formula areas;
- status information;
- instructions/checklists;
- a chosen application/region while Detail moves elsewhere.

Prefer simple whole-view/reference behavior before exposing specialist arbitrary-region configuration.

A custom capture/render architecture makes a frozen retained texture/view a natural extension.

### 9. Simple visual states

**Priority: early-to-mid product**

Candidate states include:

- contrast/inversion;
- brightness/glare-reduction style treatments;
- simple colour presets;
- pointer/caret/focus enhancement;
- possibly per-view state.

Rendering quality is an outcome first. Do not begin with a large specialist colour-rule or sharpening control surface.

### 10. Presentation / share-safe state

**Priority: later validation unless user need pulls it forward**

Potential Doxa workflow:

- private magnified Detail for the user;
- clean ordinary output for audience/share;
- optional third screen for notes/meeting state.

The workflow has precedent in specialist magnifiers, but frequency and conferencing/screen-capture compatibility require dedicated validation before major investment.

## Mainline Visual and Doxa concept track

Development is intentionally split by maturity rather than by duplicating the product.

**Current Visual main line:** keep the implemented product focused on the proven two-screen case while improving reusable foundations such as tracking, viewport behavior, terminology alignment, settings, visual enhancement and contextual assistance.

The current terminology/help decisions are specified in `vision_adoption_and_contextual_assistance_spec.md`. They should be implemented as one coherent product pass rather than piecemeal renaming followed by a second help redesign.

**Future Doxa workspace track:** the current leading concept is two stable side workspaces plus one shared centre Detail surface, with the laptop acting as a simple workspace organiser. See `doxa_dual_workspace_shared_detail_concept.md`.

Do not build that speculative three-screen behavior into the current Visual line before Doxa hardware and assessor/user validation. When implementation starts, branch from the then-current Visual baseline and reuse the same core capabilities rather than maintaining a permanent divergent fork.
## Feature sequence for the first usable Visual alpha

The engineering sequence is intentionally narrower than the full feature list.

### Foundation already under test

1. cross-monitor capture/render ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Spike 1;
2. pointer + coordinate truth ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Spike 2.

### Next independent capabilities

3. caret/focus evidence and fallbacks;
4. viewport policy and POI arbitration;
5. inspect-and-return state model;
6. pointer/caret/focus locator overlays.

### First integrated internal alpha

Combine:

- stable Context + magnified Detail;
- mouse, caret and keyboard-focus POI evidence;
- predictable viewport policy;
- zoom up/down and instant normal/return;
- basic pointer/caret/focus finding;
- independent state for the initial source/detail views.

This should be the first build intended for actual task use rather than mechanism testing.

### Next product layer

Then add, in evidence-driven order:

- fixed/frozen reference;
- monitor roles and role persistence;
- one source -> multiple views;
- four-screen Doxa topology;
- simple visual-state presets;
- topology/hot-plug/sleep recovery hardening;
- best-effort workspace restoration;
- monitor-transition assistance;
- presentation/share-safe workflows if validated.

## Explicit non-goals for the first product phase

Do not make these prerequisites for the first useful Visual:

- full screen-reader/speech system;
- every historical lens/docked/line/overlay geometry;
- 60x+ zoom as a product target;
- elaborate automatic application profiles;
- deep image-sharpening/font-rendering control panels;
- camera/CCTV integrations;
- complex incumbent-style Global/Local mode taxonomy;
- OCR-heavy reading pipeline as a core runtime feature.

These can be revisited only when a concrete user need justifies them.

## Provenance

Primary feature/workflow evidence remains in the dated research artifacts, especially:

- `artifacts/2026-09-18__gpt-5.6-sol__feature_value_workflow_competitive_ux_v0.1.md`;
- `artifacts/2026-09-19__gpt-5.6-sol__doxa_multimonitor_workflow_product_concepts_v0.1.md`.

This file is the current development synthesis, not a replacement for those sources.
