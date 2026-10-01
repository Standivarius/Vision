# Vision feature and development roadmap

**Date:** 2026-10-01
**Status:** canonical current roadmap for product sequencing and implementation planning
**Supersedes for sequencing:** the earlier research-stage content in `execution_plan.md` and dated development-plan artifacts. Those remain provenance, not current instructions.

## 1. How to use this roadmap

This file is the single current roadmap for deciding what Vision builds next.

Precedence remains:

1. explicit current user instruction;
2. `AGENTS.md` safety and repository invariants;
3. current foundation documents, with this roadmap controlling sequencing;
4. active task/spike charter;
5. live implementation and verified evidence;
6. dated artifacts as provenance.

If a dated plan says a completed slice has not started, this roadmap and the live repository win.

## 2. Product direction already decided

Vision is not pursuing feature parity with ZoomText or SuperNova.

The first product is a focused Windows low-vision magnification system built around six quality pillars:

1. **Magnification quality** good enough that text is not a competitive disadvantage.
2. **Orientation** through pointer/caret/focus visibility and fast context recovery.
3. **Predictable tracking and viewport behaviour**, including conflict handling.
4. **Coherent multi-monitor behaviour** with explicit roles, independent per-view state and explicit active-view/crossing policy.
5. **Context preservation** through Context + Detail now, with selected pinned/frozen/relocated context later only if evidence promotes it.
6. **Supportability** through persistence, lifecycle recovery, install/update, diagnostics, contextual help and compatibility evidence.

The canonical conceptual model remains:

> **Source -> Point-of-Interest evidence -> transformation / view policy -> Destination**

Capture does not own tracking policy. Evidence collection does not own active-view policy. Overlay visibility does not automatically imply viewport movement.

## 3. Monitor/product model

### 3.1 Generic scope

**Established:** Vision is a hardware-agnostic Windows product designed for ordinary 2-, 3- and 4-monitor environments. Doxa is a future qualified hardware configuration, not a separate software architecture.

### 3.2 Two-screen default

**Established default for the first product:** one normal **Context/source** monitor feeds one dedicated magnified **Detail/destination** monitor.

Consequences:

- the user works on Context;
- Detail is a dedicated magnified output;
- pointer/caret/focus evidence outside the configured Context source is not eligible to drive that Detail;
- moving an application onto the Detail monitor does not make Detail silently become a new source;
- roles may be swapped/configured, but a single physical display should not simultaneously be treated as full interactive source and full-screen Detail without a separately qualified interaction mechanism.

This matches the current working alpha and avoids conflating same-monitor interaction with multi-monitor source switching.

### 3.3 Multi-source / shared-Detail mode

**First-product capability direction, not yet productised:** in a 3+ monitor configuration, more than one normal source/workspace may be eligible to feed a shared Detail display.

This is where **active-view / crossing policy** becomes first-class:

- exactly one source/view owns active following for a shared Detail at a time;
- explicit user selection always wins;
- ownership may transfer after deliberate activity/crossing into another eligible source;
- transfer requires intent/hysteresis so fresh signals on multiple sources do not create chaotic movement;
- pointer, caret and keyboard-focus evidence may contribute to transfer policy, but the shared EvidenceHub publishes evidence rather than deciding ownership;
- a Detail-only destination is not source-eligible unless the workspace configuration explicitly gives it a source role.

The three-screen Doxa concept is one concrete expression of this generic model: two stable source workspaces feeding one shared Detail.

## 4. What is already built

The architecture/refactor tranche is complete enough that the programme should not restart it.

### 4.1 Structural foundation — complete

- Gate 0A deterministic replay / baseline oracle.
- Gate 0B explicit geometry and magnification contract.
- Slice 1 explicit View identity/state.
- Slice 2 shared EvidenceSampler.
- Slice 3 pure view-update step.
- Slice 4 explicit GPU device domain + CaptureSource + OutputPresenter.
- Slice 5 WorkspaceCoordinator + ViewSession.
- Slice 6 MonitorRegistry + intended-vs-resolved workspace.
- Slice 7 in-process topology reconciliation — implementation complete; physical qualification remains open.
- Slice 8 one CaptureSource feeding two independently paced outputs.
- Slice 9 second CaptureSource + generic N-view runtime.

### 4.2 Interaction-policy foundation — complete

- P1 explicit movement owner + pointer-leave hold.
- P2 pointer/caret/focus visibility independent of following.

These are necessary foundations for, but are not equivalent to, cross-source active ownership.

### 4.3 Rendering/raster tranche — complete for current baseline

- Controlled reconstruction study complete.
- Bilinear mode 0 remains production default.
- Word 2x human quality judged very good.
- Word 4x human quality judged better than ZoomText in the observed task.
- Browser/ChatGPT pixelation evidence showed source/application pixel structure already present before Vision magnification; no generic semantic-rerendering programme is justified.
- Experimental reconstruction modes remain engineering aids only.

### 4.4 Repository/operational foundation — complete

- Repository consolidation completed into coherent Git checkpoints.
- Raw/generated evidence is kept outside Git history where appropriate.
- Current alpha compatibility identifiers remain intentionally stable.
- Build/test/package/update infrastructure remains operational.

### 4.5 UI/DPI/localisation foundation — substantially complete

Implemented:

- Per-monitor DPI-aware Settings and Help geometry/font refresh.
- Physical 150% <-> 100% mixed-DPI UI smoke passes.
- Caption-based Settings layout lookup removed.
- Stable language-neutral UI string keys introduced for major Settings/Help surfaces.
- Commands separated from physical hotkey bindings.
- AltGr collision demonstrated for the current Ctrl+Alt shortcut family.
- Current Ctrl+Alt profile explicitly marked internal-alpha only / not safe for external release.

Still open before broader external alpha:

- final user-facing shortcut model;
- one genuine Windows text-size/accessibility-scale qualification pass;
- extend stable string keys to remaining smaller menu/hint/error surfaces as touched.

### 4.6 Same-monitor capability — decided for current architecture

Current WGC + D3D11 same-monitor support is **bounded viewing fallback only**, not first-class interactive self-magnification.

Proven:

- WDA_EXCLUDEFROMCAPTURE accepted on current system;
- bounded same-monitor rendering stable with zero Present failures;
- non-activating Detail preserves foreground focus.

Falsified for first-class interaction:

- Detail owns pointer hit-testing;
- no source-coordinate click/drag/wheel remapping/forwarding exists;
- simple click-through would not solve magnified-coordinate correspondence.

Do not market current same-monitor mode as equivalent to Windows Magnifier/ZoomText full interactive magnification.

### 4.7 Current workplace compatibility evidence

Current bounded-good task evidence includes:

- Vision Settings/Help across real mixed DPI.
- Standard focusable-control navigation.
- Word 16.0.20326.20158 ordinary document editing, selection, ribbon focus and return to editing.
- Excel 16.0.20326.20158 grid navigation and formula-bar editing.

Current known issue:

- Edge 154 ordinary textarea semantic accessibility no longer reproduces the validated Edge 153 UIA geometry/focus behaviour. Treat as a browser/accessibility-provider compatibility issue until a current path is proven.

The living source of truth is `docs/project/compatibility_ledger.md`.

## 5. Current tranche — validation and hardening before the next independent review

This is the programme's current position.

### 5.1 #20 UI/DPI/hotkey/localisation residuals

**Status:** substantially complete / remain in progress.

Do now only where it is non-disruptive and evidence-driven.

Before broader external alpha:

- choose final shortcut model after accessibility/user evidence;
- qualify Windows text-size/accessibility scaling;
- continue resource/string-key migration as UI surfaces are touched.

Do not delay the next independent review merely because every minor string is not yet catalogued.

### 5.2 #21 Windows Magnifier + low-vision/assessor evidence

**Status:** owner/debug comparator session underway; genuine low-vision/assessor evidence still required.

Owner/debug findings already established on current Dell/Word setup:

- Windows Magnifier **Full screen** treats the extended desktop as one magnified workspace rather than preserving independent Context and Detail monitor roles.
- **Lens** preserves normal desktop area, but did not follow the Word insertion caret in the observed task even though Keyboard focus and Text cursor follow settings were verified ON.
- **Docked** follows the Word caret, but uses a full-width magnified band attached to the top of the physical screen and reduces the normal application workspace.
- Vision at 4x preserved one full 1x Context workspace plus one independent full-screen 4x Detail and followed Word caret correctly when Word was on the configured Context source.
- Moving Word onto the Detail/output monitor did not drive Vision, which matches the current explicit source-role filtering rather than representing a Word tracking defect.

Next evidence required:

- first genuine low-vision user or experienced assessor session;
- use task-level comparison, not generic preference voting;
- explicitly test whether designated Context + dedicated Detail is understandable and useful;
- in 3+ monitor scenarios, test expectations around switching between multiple source workspaces feeding one Detail.

The owner/debug session is protocol/evidence preparation, not a substitute for low-vision-user evidence.

### 5.3 #23 compatibility ledger

**Status:** active living workstream.

Next priority applications/workflows:

1. current Chromium/Edge semantic-editing path and the Edge 154 regression;
2. Outlook compose/read/navigation;
3. Teams / modern web-app compose and controls;
4. real PDF application selected from actual pilot use;
5. pilot user's essential application.

Compatibility claims remain task/version/topology bounded.

### 5.4 #11 + #13 + #14 combined physical display qualification

**Status:** implementation foundation exists; physical evidence remains.

Use one controlled owner-at-Dell session to collect:

- **#11 identity:** whether the same physical displays remain distinguishable across changes, especially identical-panel/port/reboot cases;
- **#13 lifecycle:** actual event ordering and whether the current debounce is supported by evidence;
- **#14 recovery:** whether Vision survives/rebuilds and returns to intended roles without stale-generation movement or wrong-monitor binding.

The combined protocol is:
`artifacts/2026-09-30__gpt-5.6-sol__display_physical_qualification_protocol_v0.1.md`.

Do not run three independent disruption campaigns.

## 6. Review Gate #25 — Opus + Astra

Call the next independent Opus + Astra review **after** the current validation/hardening tranche has produced enough new evidence.

Already satisfied for the gate:

- architecture Slices 1-9;
- P1/P2;
- raster conclusion;
- repository consolidation;
- mixed-DPI/UI/localisation foundation;
- same-monitor verdict;
- living compatibility ledger with meaningful Word/Excel current evidence;
- Windows Magnifier owner/debug comparison.

Still required before the normal gate:

- first genuine low-vision or assessor evidence;
- physical #11/#13/#14 display identity/lifecycle/recovery evidence.

A targeted earlier review is justified only if new evidence creates a genuine architectural contradiction.

The review should specifically challenge:

- active-source/view ownership and crossing model;
- whether ownership belongs inside WorkspaceCoordinator or a distinct policy controller;
- role semantics for 2-, 3- and 4-monitor configurations;
- topology/identity implications for active-source transfer;
- defaults/presets implied by user evidence;
- remaining compatibility risks before broader alpha.

Use the current Opus 5.5 prompting guidance in `opus_5_5_prompting_instructions.md`; do not automatically use xhigh/max without evidence that it helps.

## 7. Next product tranche after Review Gate #25

This is the first **productisation** tranche on top of the completed structural foundation.

### P3 — active source/view ownership and monitor-crossing policy

**Priority:** P0 / first product.

Goal: make generic multi-monitor Vision behaviour understandable and predictable when more than one source workspace is eligible to drive a shared Detail.

Initial policy to prototype:

1. one active source/view owns Detail movement;
2. explicit source selection wins immediately;
3. deliberate activity on another source may request ownership transfer;
4. pointer boundary crossing alone should not cause immediate thrash;
5. caret/focus activity can be stronger evidence of intentional work than passive pointer position;
6. apply hysteresis/cooldown/intent thresholds;
7. expose current active source clearly enough that the user knows what Detail is following;
8. two-screen Context+Detail remains the default special case with only one source-eligible workspace.

Acceptance must include:

- deterministic replay of ownership transitions;
- no simultaneous independent following of fresh evidence from multiple sources;
- intentional switch transfers Detail predictably;
- accidental pointer excursions do not steal ownership;
- explicit selection overrides automatic policy;
- returning to a previous source does not lose its independent view state;
- physical 3-monitor qualification before claiming multi-source shared-Detail support.

### P4 — orientation presets and active-source indication

Productise existing overlay foundations:

- small strong preset family for pointer, caret and keyboard focus;
- consistent geometry and intensity;
- per-view visibility independent of following;
- indication of which source currently owns Detail;
- minimal terminology aligned with incumbent mental models where useful.

Do not reproduce every ZoomText/SuperNova locator option.

### P5 — viewport comfort/predictability tuning

Tune rather than redesign:

- dead zones;
- margins;
- hysteresis;
- pan cadence;
- conflict policy between pointer/caret/focus;
- source-transfer hysteresis from P3.

Use real task evidence and replay fixtures.

### P6 — monitor roles and workspace productisation

Turn source/destination wiring into understandable product concepts:

- Context/source;
- Detail;
- optional Work/Reference source roles;
- persistence and restoration;
- explicit role conflicts/fallbacks;
- active-source eligibility.

Keep configuration simple enough for non-specialist users.

### P7 — simple visual-state presets

Extend the current colour/contrast subset only where evidence supports value:

- normal;
- contrast;
- inversion/grayscale where useful;
- small number of useful presets;
- independent per-view state where meaningful.

### P8 — supportability and external-alpha readiness

- final shortcut model;
- remaining localisation/resource seam;
- text-size/accessibility-scale qualification;
- compatibility expansion;
- diagnostics and recovery messaging;
- contextual help;
- packaging/update checks.

## 8. Second-layer features — evidence-gated, not first-product defaults

Preserve architecture seams but do not prebuild:

- pinned/frozen reference views;
- Tethered-style semantic relocation;
- clean-text / semantic readability fallback;
- app-specific profiles/overrides beyond a minimal seam;
- presentation/share-safe special modes;
- richer colour/tint families;
- first-class same-monitor full-screen interaction.

Promote only when task evidence shows value.

## 9. Explicitly deferred / separate workstreams

- Doxa Installer remains a separate hardware/install workstream.
- Hardware qualification waits for actual target hardware where required.
- Pricing/commercial packaging is not part of this roadmap.
- Semantic text rerendering is not justified by current evidence.
- D3D12 is not a target without evidence that D3D11 is insufficient.
- A broad C++ -> Rust rewrite is not on the critical path.

### Post-alpha Rust architecture spike — non-blocking

Rust is a valid future option for isolated components because state/concurrency safety may become valuable as topology and active-source policy grow.

If tested:

- choose one isolated non-rendering component such as diagnostics/topology logic;
- use `windows-rs`;
- compare Windows API friction, unsafe boundary size, binary/deployment integration, code complexity and maintainability;
- do not migrate WGC/D3D11 core runtime unless the spike demonstrates a clear benefit.

## 10. Release/quality gates

Every runtime-affecting product slice should preserve:

- Release build and full CTest pass;
- canonical two-screen acceptance;
- zero Present failures in supported baseline scenarios;
- exact 1x/return behaviour;
- settings persistence/restoration;
- compatibility ledger update where application behaviour changes;
- bounded physical evidence for topology-sensitive changes.

For multi-source/crossing work, add:

- deterministic ownership-transition replay;
- 3-monitor physical acceptance;
- clear telemetry for active source, ownership reason and transfer reason.

## 11. Immediate execution order

Unless new evidence creates a contradiction, execute in this order:

1. **Finish the current #21 owner/debug documentation** and retain the comparator findings.
2. **Run combined #11/#13/#14 physical display qualification** when the owner can safely perform the required display actions.
3. **Obtain the first genuine low-vision/assessor #21 session.**
4. **Continue #23 compatibility opportunistically**, prioritising Edge current-version semantics, Outlook and Teams; do not block the physical/user gates on exhaustive coverage.
5. **Complete only necessary #20 residuals** before broader external alpha; final shortcut choice should use the user evidence.
6. **Run Review Gate #25: Opus + Astra.**
7. **Implement P3 active-source/view ownership + crossing policy.**
8. **Then P4/P5/P6 orientation, viewport and monitor-role productisation.**
9. Continue P7/P8 visual presets/supportability toward broader alpha.
10. Re-evaluate second-layer features and the optional Rust spike after the first-product behaviour stabilises.

## 12. What should not happen next

Do not:

- reopen the structural architecture extraction without contradictory evidence;
- chase generic raster filters because synthetic sharpness metrics look better;
- treat Windows Magnifier, ZoomText or SuperNova feature breadth as a parity checklist;
- make every view independently follow every fresh evidence signal;
- confuse the dedicated Detail output with another normal source workspace;
- interpret the current two-screen fixed-source behaviour as the final generic 3/4-monitor interaction policy;
- call Opus/Astra repeatedly before the new human/physical evidence arrives;
- let older research-stage roadmap prose override this file.
