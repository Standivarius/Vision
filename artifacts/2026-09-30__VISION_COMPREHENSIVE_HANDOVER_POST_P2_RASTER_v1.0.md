# VISION — COMPREHENSIVE NEW-CHAT HANDOVER PACKAGE v1.0

**Date:** 2026-09-30  
**Prepared by:** GPT-5.6 Sol  
**Project:** Vision  
**Canonical host:** MARIUS-DELL  
**Canonical repository:** `C:\dev\Vision`  
**Git branch:** `master`  
**Public repo:** `Standivarius/Vision`  
**Current execution plan:** `artifacts/2026-09-30__gpt-5.6-sol__vision_development_plan_v0.5.md`

This is the freshest operational checkpoint for the next ChatGPT conversation.

## 0. Current state in one page

Vision is no longer a small two-monitor prototype. The current development cycle has completed the structural architecture extraction through **Slices 1–9**, plus intentional interaction-policy changes **P1** and **P2**.

The validated foundation now includes explicit View identity/state; shared evidence sampling; a pure view-update step; explicit GPU device ownership; CaptureSource/OutputPresenter separation; WorkspaceCoordinator and ViewSession; MonitorRegistry with intended-vs-resolved workspace; in-process topology reconciliation; one source feeding two independently paced outputs; a second source and generic N-view runtime; one explicit movement owner; pointer-leave hold semantics; overlay visibility separate from follow/movement; WGC capture + D3D11 rendering; pointer/caret/focus tracking and arbitration; exact temporary 1x/return; Context + Detail; colour modes; settings/help; Velopack distribution/update infrastructure; deterministic tests; and physical two-screen acceptance.

Latest clean full default regression after the newest work:

- **19/19 CTests PASS**
- **8/8 canonical two-screen acceptance PASS**
- evidence: `lab/benchmarks/integrated_app/runs/2026-09-30_21-21-23__two_screen_acceptance`
- Present failures: **0**
- exact 1x return delta: **0 px**
- settings restored exactly: **True**
- live locator/render: 327 frames, 69 locator-visible; Hold/Pan/Jump/Invalid = 303/24/0/0.

The current open engineering experiment is **GitHub #19 — raster reconstruction/text quality**. It reached a human evidence gate, and the newest human observation materially changes the interpretation:

1. Owner judged **Vision at 2x in Word “very good.”**
2. Owner initially observed visible pixelation in ChatGPT/browser at 2x.
3. Owner then photographed the **source/main display itself** close-up and showed the pixel/subpixel structure already present there, explicitly saying we were “chasing the wrong rabbit”: magnifying source pixels cannot invent missing detail and may only enlarge that structure.
4. Owner then tested **Word at 4x** and explicitly judged Vision **“better than ZoomText at 4x.”**
5. Therefore, do **not** continue chasing generic renderer sharpness as if Vision has a proven global blur defect. The browser case is at minimum source/application-path dependent, and the latest matched Word judgement strongly favours the current baseline. Image metrics are engineering evidence, not a mandate to replace the baseline.

At handover time the dev executable is running:

`C:\dev\Vision\app\build\Release\visual_app.exe --zoom 4 --reconstruction 0 --log C:\dev\Vision\lab\benchmarks\raster_reconstruction\runs\human_baseline_4x_2026-09-30_22-13-31.csv`

Mode 0 is the unchanged/current bilinear production baseline.

### Naming trap

The product and UI are **Vision**, but compatibility identifiers deliberately remain **Visual** for the current alpha line:

- executable: `visual_app.exe`
- package/install identity: `Standivarius.Visual`
- installed-state and many `VISUAL_*` identifiers remain
- installed public alpha seen in acceptance: **0.1.0-alpha.11**
- local dev candidate builds use **0.1.0-alpha.12**.

Do not casually rename these compatibility identifiers.

## 1. Operating rules

For substantive local work use **Local Project Dev – Dell**.

Project instructions say to call `project_start("visual")` first. On this machine that currently returns `INVALID_ARGUMENT / Error executing tool` because the registry key is mismatched. Immediately fall back to:

`project_start("vision")`

This resolves MARIUS-DELL / `C:\dev\Vision` / `master`. Do not waste time repairing the alias unless the user explicitly asks.

The repository is heavily dirty/uncommitted. Hard rules:

- no `git reset`
- no `git clean`
- no forced checkout
- no branch switch unless explicitly requested
- no stash-all
- no mass deletion
- no sweeping unrelated files into a commit
- preserve all pre-existing dirty/uncommitted work
- no commits have been made for the structural/P1/P2/raster work described here.

The user explicitly said: **“Do not stop for approvals unless you need me.”** Continue autonomously through planned implementation/test gates. Interrupt only for genuine human-only dependencies: UAC/elevation, reboot, physical monitor/cable/sleep action, disruptive system settings, subjective visual/usability judgement, an irreducibly ambiguous product decision, or a failure where continuing risks existing work.

Use GitHub Projects/issues, not Linear.

Do not invoke Codex, Claude, Gemini, Opus, Astra or other AI agents unless the owner explicitly authorises it. Gemini was authorised only for the completed test-farm assignment.

## 2. Product framing

Vision is a **hardware-agnostic Windows low-vision magnification application** intended for ordinary 2-, 3- and 4-monitor systems.

Doxa is a future qualified hardware configuration, not a separate Vision architecture. Doxa Installer/hardware work is separate and blocked on real SM770 hardware. Do not leak Doxa-specific firmware/driver/install assumptions into Vision’s renderer/tracking core.

Context + Detail is the initial/default two-monitor hypothesis, **not** an architecture invariant. Stable monitor roles, independent per-view state, temporary inspect/return, pointer/caret/focus visibility, reference/frozen views, compatibility and low-vision usefulness remain the product themes.

Canonical conceptual model:

**Source → evidence / Point of Interest → transformation & view policy → Destination**

Graphics and intent/tracking remain separate.


## 3. Authoritative documents to read

Mandatory foundation:

- `AGENTS.md`
- `docs/project/foundation/README.md`
- `docs/project/foundation/product_assumptions.md`
- `docs/project/foundation/feature_roadmap.md`
- `docs/project/foundation/engineering_principles.md`
- `docs/project/foundation/architecture_baseline.md`
- `docs/project/foundation/implementation_precedents.md`
- `docs/project/foundation/experimentation_and_validation.md`
- `docs/project/development_operating_model.md`

Primary current plan:

- `artifacts/2026-09-30__gpt-5.6-sol__vision_development_plan_v0.5.md`

Prior independent reviews:

- `artifacts/2026-09-30__opus-5.5-xhigh__vision_product_architecture_review_v0.1.md`
- `artifacts/2026-09-30__gpt-6-astra-xhigh__vision_independent_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__opus_astra_reconciliation_v0.1.md`

Incumbent/product evidence:

- `artifacts/2026-09-30__gpt-5.6-sol__zoomtext_comprehensive_assessment_v0.3.md`
- `artifacts/2026-09-30__gpt-5.6-sol__supernova_comprehensive_assessment_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__incumbent_cross_product_synthesis_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__incumbent_synthesis_and_feature_priorities_v0.1.md`

Execution evidence:

- `artifacts/2026-09-30__gpt-5.6-sol__batch1_gate0_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice1_view_state_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice2_evidence_sampler_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice3_view_update_checkpoint_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice4_graphics_lifetime_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice5_workspace_coordinator_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice6_display_identity_topology_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__display_lifecycle_census_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice7_topology_reconciliation_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice8_fanout_review_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__slice9_multisource_generic_runtime_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__policy_p1_movement_owner_pointer_leave_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__policy_p2_visibility_follow_separation_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__raster_reconstruction_experiment_v0.1.md`

Gemini farm:

- `artifacts/2026-09-30__test_farm_assignment_v0.1.md`
- `artifacts/2026-09-30__gemini-3.8-flash-m__test_farm_engineering_report_v0.1.md`
- `lab/automation-harness/`

**Freshness warning:** `STATUS.md` still contains older “pre-refactor / Batch 1 next” material. That is stale relative to the work completed later on 2026-09-30. Do not let those paragraphs rewind the programme. The live code + latest execution artifacts + this handover are fresher.

## 4. What Opus/Astra agreed

The prior dual review established:

1. narrow behaviour-preserving extraction before feature breadth;
2. Context + Detail is a hypothesis, not an invariant;
3. separate Source / Evidence / View / Destination;
4. use a workspace-level coordinator;
5. one explicit movement owner initially;
6. overlays/visibility separate from movement/follow;
7. same-monitor fallback does not prove usable same-monitor magnification;
8. WGC/D3D11 is the default path, not a universal guarantee;
9. explicit GPU/device ownership;
10. do not carry a global present-wide graphics mutex into multi-output;
11. improve raster before considering semantic text rendering;
12. lifecycle/recovery, compatibility and accessible configuration are product-critical;
13. start low-vision/assessor evidence early;
14. compatibility burden remains substantial.

Reconciliation specifics: one explicit GPU domain initially; generic source-region/update-policy/destination-placement primitives rather than a named “Tethered” subsystem; same-monitor capability-gated; replay oracle + geometry contract before refactor.

## 5. Plan v0.5 status

The sequence was:

- Gate 0A replay/baseline oracle
- Gate 0B geometry/magnification contract
- Slice 1 explicit View identity/state
- Slice 2 EvidenceSampler
- Slice 3 pure view-update step
- Slice 4 GPU domain + CaptureSource + OutputPresenter
- Slice 5 WorkspaceCoordinator + one ViewSession
- Slice 6 MonitorRegistry + intended/resolved topology
- Slice 7 in-process topology reconciliation
- Slice 8 one source → two outputs
- Slice 9 second source + generic N-view runtime
- P1 movement owner + pointer-leave hold
- P2 overlays separate from following.

**All of those implementation stages are complete.**

GitHub states:

- #1/#7 Gate 0A — CLOSED
- #2/#8 Gate 0B — CLOSED
- #4 Slice 1 — CLOSED
- #5 Slice 2 — CLOSED
- #6 Slice 3 — CLOSED
- #9 Slice 4 — CLOSED
- #10 Slice 5 — CLOSED
- #12 Slice 6 — CLOSED
- #15 Slice 8 — CLOSED
- #16 Slice 9 — CLOSED
- #17 P1 — CLOSED
- #18 P2 — CLOSED

Open:

- #11 display identity stability
- #13 lifecycle/debounce experiment
- #14 Slice 7 physical qualification
- #19 raster reconstruction
- #20 UI/DPI/AltGr/localisation
- #21 Windows Magnifier + low-vision/assessor evidence
- #22 same-monitor capability
- #23 compatibility ledger.

## 6. Gate 0A replay/baseline oracle

Key files:

- `app/src/core/replay_oracle.h`
- `app/tests/replay_oracle_tests.cpp`
- `docs/project/foundation/replay_baseline_oracle.md`

Golden observed case:

- 2x pointer around `(640,360)-(641,361)`
- viewport `(160.5,90.5)-(1120.5,630.5)`.

Coverage includes deterministic replay, deliberate perturbation, pointer-intent barrier, locator/follow behaviour, exact 1x/return and later P2 independent locator/follow semantics.

## 7. Gate 0B geometry contract

Key files:

- `app/src/core/geometry_contract.h`
- `app/tests/geometry_contract_tests.cpp`
- `docs/project/foundation/geometry_magnification_contract.md`

Frozen principles:

- physical source/destination pixels are the base geometry;
- DPI/logical coordinates converted at API boundaries;
- 1x means 1 source pixel → 1 destination pixel where possible;
- overview/fit is separate from 1x;
- viewport ≈ destination/zoom;
- uniform scale;
- clamp + letterbox/pillarbox;
- deterministic re-resolution after topology change.


## 8. Structural slices — implementation details

### Slice 1 — explicit View state

Key file: `app/src/core/view_state.h`

Includes `ViewId`, `kCurrentDetailViewId{1}`, `ViewBinding`, `ViewState` and compatibility mapping. Runtime now has explicit View identity instead of a hidden single-view assumption.

### Slice 2 — EvidenceSampler

Key file: `app/src/tracking/evidence_sampler.h`

Introduces immutable `EvidenceSnapshot` and one acquisition sample per tick. Pointer/caret/focus acquisition is no longer conceptually owned by one capture/render relation.

### Slice 3 — pure view-update

Key file: `app/src/core/view_update_step.h`

The same near-pure update step is used by runtime and deterministic replay.

### Slice 4 — graphics lifetime

Introduced `GpuDeviceDomain`, `CaptureFrameSnapshot`, `CaptureSource`, `OutputPresenter`. Renderer no longer owns the graphics lifetime in the original monolithic way. Present happens outside the immediate-context mutex. Generation telemetry/invariants were added.

### Slice 5 — WorkspaceCoordinator

Key file: `app/src/core/workspace_coordinator.h`

Includes `ViewSessionState`, `WorkspaceSnapshot`, `WorkspaceCoordinator`.

Important separation:

- selected view != movement owner;
- movement permission is explicit;
- command targeting is separate from viewport movement authority.

### Slice 6 — monitor/topology model

Includes `WorkspaceIntent`, `ResolvedWorkspace`, `MonitorRegistry`, DPI/orientation/identity hints.

Persisted monitor roles represent **user intent**. Runtime resolution is transient.

### Slice 7 — in-process topology reconciliation

Key file: `app/src/core/topology_reconciler.h`

The former one-shot app lifetime was refactored into `run_workspace_generation(...)`; outer `wWinMain` owns `TopologyReconciler(500)`; `WM_DISPLAYCHANGE` causes same-process whole-workspace rebuild after a resettable quiet window.

Engineering flag: `--topology-reconcile-self-test`.

Implementation is complete. GitHub #14 remains open only for physical unplug/reconnect, sleep/wake, DPI/resolution/primary changes, lock/unlock and empirical debounce qualification.

### Slice 8 — fan-out

One CaptureSource can feed two independent outputs.

Engineering flag: `--fanout-self-test`.

A secondary output deliberately incurred 120 ms Present delay while primary remained healthy, proving output pacing isolation.

Evidence: `lab/benchmarks/integrated_app/runs/fanout_self_test.csv`.

### Slice 9 — second source + generic runtime

Important components:

- `app/src/core/workspace_runtime_graph.h`
- `SourceId`
- `RuntimeNodeState`
- `SourceRuntimeNode`
- `ViewRuntimeNode`
- `WorkspaceRuntimeGraph`
- `app/src/tracking/evidence_hub.h`
- `PublishedEvidence`
- `EvidenceHub`
- `CaptureOnlyPump`
- `WorkspaceRuntimeCollection`.

Engineering flag: `--multisource-self-test`.

Verified: source 2 starts, emits, is deliberately stopped; dependent view suspends; primary continues; evidence sampling is not duplicated.

## 9. Policy P1 — movement owner / pointer leave

Issue #17 CLOSED.

Root defect found in `app/src/core/poi_evidence.h`: `select_best_poi` previously derived latest pointer time only from currently routed pointer candidates. Once the pointer left the source, the pointer candidate disappeared, so stale caret/focus could reclaim the viewport.

Fix:

- `select_best_poi(... pointer_intent_barrier_qpc)`
- `ViewController::update(... pointer_intent_barrier_qpc)`
- `ViewStepInput.pointer_intent_barrier_qpc`
- primary runtime passes `EvidenceSnapshot.pointer_movement_qpc`.

Semantics:

- pointer movement is an intent barrier;
- when pointer leaves the source, stale semantic evidence cannot reclaim;
- genuinely newer caret/focus may transfer;
- pointer leave holds current viewport.

Physical crossing evidence:

`lab/benchmarks/visual_regression/runs/2026-09-30_19-22-10__pointer_crossing`

Key result: 1,167/1,167 successful telemetry frames; all secondary near/sweep/far phases Hold; no secondary Pan/Jump from stale semantic evidence.

Artifact: `artifacts/2026-09-30__gpt-5.6-sol__policy_p1_movement_owner_pointer_leave_v0.1.md`.

## 10. Policy P2 — visibility is not movement

Issue #18 CLOSED.

Old coupling: `ViewUpdateStep` filtered evidence by `should_follow` before both movement arbitration and locator creation. Thus disabling “Follow Caret” also made its locator impossible.

New model:

- movement path receives follow-enabled candidates;
- visibility path examines original evidence separately;
- display policy (`show_pointer_locator`, `show_caret_locator`, `show_focus_locator`) is independent;
- locator must intersect current viewport;
- locator evidence still obeys freshness;
- stale cues expire;
- overlay presence does not grant movement authority.

Key seam: `select_locator_target(...)` in `locator_model.h`.

Tests prove fresh caret can be visible while caret following is off, viewport remains Hold, out-of-view cue hides, stale cue expires, legacy movement behaviour remains intact.

Duplicate-pointer boundary: WGC uses `session_.IsCursorCaptureEnabled(false)`; P1 removes source-pointer evidence after the pointer leaves Context; Vision therefore does not add a second destination pointer cue beside the OS cursor.

Artifact: `artifacts/2026-09-30__gpt-5.6-sol__policy_p2_visibility_follow_separation_v0.1.md`.

## 11. Gemini test farm — useful, but do not overtrust its failure labels

User authorised Gemini to build the farm.

Assignment: `artifacts/2026-09-30__test_farm_assignment_v0.1.md`  
Report: `artifacts/2026-09-30__gemini-3.8-flash-m__test_farm_engineering_report_v0.1.md`  
Harness: `lab/automation-harness/`

Architecture: scenario catalogue → resolver/preflight → isolated execution → evidence bundle → deterministic assertions → aggregation/failure signatures/human-review queue.

Independent re-check by GPT-5.6 Sol: **SWA-01..13 = 13/13 PASS**.

Two caveats:

1. A `safe-smoke` tool call exceeded the bridge execution window. Outer cancellation left the farm Python runner alive; it had to be killed explicitly. So arbitrary external-controller cancellation is not fully covered by farm v0.1.
2. Gemini labelled six smoke failures as one production `WM_CLOSE` regression. Independent reruns produced mixed outcomes: several previously failing scenarios passed while another lifecycle case failed. Therefore the blanket “six production regressions caused by WM_CLOSE” claim is not established.

**No production WM_CLOSE fix was made merely to green the farm.**

Treat the farm core as useful deterministic infrastructure, but improve cancellation robustness and failure taxonomy later.


## 12. Canonical harness robustness fixes made during #19

Raster testing exposed two **test harness** timing assumptions. These are not product feature changes.

### exact-return smoke

File: `app/run-return-smoke.ps1`

Old behaviour launched Vision, slept 650 ms, sent Ctrl+Alt+0, and assumed a rendered 2x “before” frame already existed. On a slower/static source, the hotkey could arrive before the first 2x rendered telemetry frame, making the oracle impossible to segment.

Fix:

- explicitly wait until telemetry contains a rendered 2x seed frame;
- only then begin the 1x/return sequence.

After correction:

- 94 frames;
- 40/40 stable 1x;
- exact return 0 px;
- zero Present failures.

### UI restart smoke

File: `app/run-ui-surface-smoke.ps1`

Two issues:

1. PowerShell result-shape instability when exactly one restart frame existed;
2. restart path slept fixed 600 ms then quit, sometimes before `first_render_frame`.

Fixes:

- stable array construction for restart telemetry;
- wait explicitly for `# event=first_render_frame` before exit.

After correction:

- isolated UI smoke PASS;
- first/restart 55/7 frames;
- zero Present failures;
- duplicate launch/settings/help/restart/exit all PASS.

These harness changes are uncommitted and must be preserved.

## 13. Raster reconstruction experiment #19 — exact state

GitHub #19 remains OPEN.

### Engineering-only modes

`app/src/main.cpp` accepts:

`--reconstruction <0..3>`

- **0** current/default bilinear
- **1** Catmull-Rom bicubic
- **2** Lanczos-2
- **3** lightweight adaptive unsharp over bilinear.

Normal/default Vision remains mode 0. There is no persisted/user-facing selector.

### Controlled fixture

Files:

- `lab/raster-reconstruction/text_quality_fixture.html`
- `lab/raster-reconstruction/capture_raster_matrix.ps1`
- `lab/raster-reconstruction/show_candidate.ps1`
- `lab/raster-reconstruction/capture_office_shortlist.ps1`

Valid browser/text matrix:

`lab/benchmarks/raster_reconstruction/runs/2026-09-30_21-11-13__text_matrix`

Captured 2x/3x/4x with modes 0–3 on current machine around 150% scaling / current ClearType state.

The capture harness was corrected to wait for `first_render_frame`.

### Throughput sanity

With continuously changing source content, all four modes sustained the existing render cadence in the 2x sanity run with zero Present failures. 3x/4x probes also showed no convincing mode-specific pacing problem. A few early one-frame cells were single-instance/sequencing artefacts and were not used as performance evidence.

### Sampled edge metric — NOT a quality score

Mean sampled edge strength:

- 2x: bilinear 8.449; Catmull 8.975; Lanczos2 8.972; sharpen 9.007
- 3x: bilinear 9.098; Catmull 9.775; Lanczos2 9.762; sharpen 9.859
- 4x: bilinear 12.346; Catmull 11.115; Lanczos2 12.899; sharpen 13.273.

Before the latest human test, this suggested removing Catmull from the shortlist and visually comparing bilinear vs Lanczos2 vs sharpen.

Do not interpret higher edge strength as automatically better: it may represent ringing, halos or stroke swelling.

### Office automation attempt — INVALID evidence

Disposable Word/Excel automation was attempted only after checking neither app was already running.

Foreground placement was unreliable. Several supposed Office 4x screenshots had hashes exactly identical to the browser fixture. Therefore those Office images are **invalid and must not be used as evidence**.

Disposable instances were closed without saving and no user Office work was touched.

### System-wide matrix cells not run

The original issue includes 100% vs 150% scaling and ClearType on/off.

Only current environment was used. 100% DPI and ClearType-off remain deferred because they are disruptive system-wide changes and should not be changed autonomously while the owner is working.

### Critical latest human evidence — fresher than the raster artifact

The owner observed:

- **2x Word:** “very good”
- **2x ChatGPT/browser:** visible pixelation
- owner then supplied a close-up photo of the **main/source screen itself**, showing the pixel/subpixel structure already visible there
- owner explicitly said we were “chasing the wrong rabbit”: magnifying source pixels will naturally enlarge source structure
- **4x Word:** owner explicitly said Vision is **“better than ZoomText at 4x.”**

This is the most decision-relevant quality result currently available.

Therefore:

- do not automatically replace mode 0 with Lanczos/sharpen;
- do not infer a universal renderer defect from the browser case;
- current bilinear baseline is already very strong in Word at both 2x and 4x;
- browser quality should be treated as source/application-path dependent until proven otherwise;
- semantic/xFont-like rerendering is **not justified by current evidence**;
- preserve any semantic rendering seam only as future contingency.

The existing raster artifact was written before the final human observations, so this handover is fresher than:
`artifacts/2026-09-30__gpt-5.6-sol__raster_reconstruction_experiment_v0.1.md`.

### Runtime at handover

At package creation, process inspection showed:

- PID 16776
- `C:\dev\Vision\app\build\Release\visual_app.exe`
- `--zoom 4 --reconstruction 0`
- log: `lab\benchmarks\raster_reconstruction\runs\human_baseline_4x_2026-09-30_22-13-31.csv`.

Thus the owner’s “better than ZoomText at 4x” judgement corresponds specifically to **baseline mode 0**.

## 14. Final clean acceptance after raster/harness work

Canonical final run:

`lab/benchmarks/integrated_app/runs/2026-09-30_21-21-23__two_screen_acceptance`

Result:

- 8/8 steps PASS
- 19/19 CTests PASS
- installed product start PASS
- settings roles/colour PASS
- settings/help PASS
- UI duplicate/help/restart PASS
- zoom/tracking hotkeys PASS
- exact 1x/return PASS
- live locator/render PASS
- Present failures 0
- exact return 0 px
- settings restored exactly
- 327 live frames
- 69 locator-visible
- Hold/Pan/Jump/Invalid 303/24/0/0.

This is the current default-bilinear regression baseline.


## 15. Display identity and lifecycle — open physical qualification

### #11 durable display identity

Current PnP/WMI observations:

Integrated:
- `DISPLAY\BOE07BB\4&3623380F&0&UID265988`
- BOE / product 07BB / serial `0`

HDMI:
- `DISPLAY\SGT2271\4&3623380F&0&UID198171`
- SGT / product 2271 / serial `0`

Conclusion:

- EDID serial cannot be the only durable key;
- current PnP instance paths distinguish endpoints;
- stability across reboot/unplug/port swap is unproven.

Probe exists:
`lab/automation-harness/display_identity_probe.ps1`

Do not freeze a durable display-key schema before physical evidence.

### #13 / #14 lifecycle

In-process reconciliation code exists, but these physical cases remain unqualified:

- HDMI/DP unplug + reconnect
- sleep/wake
- resolution change
- scaling/DPI change
- primary display change
- lock/unlock
- potentially port swap.

Current quiet/debounce window is 500 ms and has not been empirically tuned.

Do not close #14 until the physical cases are tested.

## 16. Current physical environment

Recent bench configuration:

- two side-by-side 1920×1080 displays;
- monitor 1 approximately `(0,0)-(1920,1080)`;
- monitor 2 approximately `(1920,0)-(3840,1080)`;
- effective DPI around 144 / 150%.

Canonical acceptance roles:

- Context = `\\.\DISPLAY1`
- Detail = `\\.\DISPLAY2`
- Reference unused.

Do not encode this geometry into reusable architecture.

## 17. Incumbent state

ZoomText and SuperNova were installed and studied.

ZoomText:
- 2026 build observed: 2026.2606.73.400
- resting/default magnification must remain **1x** outside deliberate testing
- captured screenshots can be misleading if capture bypasses the magnified path
- phone photos/direct human judgement can be more informative for perceived quality.

SuperNova:
- Magnifier 25.05
- startup scheduled task disabled
- support services intentionally enabled.

Broad terminology/feature research is complete. Do not restart generic incumbent research unless a specific unresolved decision requires it.

Most important newer subjective result:
**Vision baseline 4x in Word was judged better than ZoomText at 4x.**

This is newer than earlier broad remarks that Vision could look softer at high zoom.

## 18. Naming / launching compatibility boundary

This caused confusion immediately before handover.

User-facing product name is **Vision**.

Current alpha compatibility deliberately retains:

- executable `visual_app.exe`
- package identity `Standivarius.Visual`
- install root under `%LOCALAPPDATA%\Standivarius.Visual`
- persistent/support identifiers may still use Visual / `VISUAL_*`
- current dev executable: `C:\dev\Vision\app\build\Release\visual_app.exe`.

If the user says “I cannot start Vision / is it still called Visual?”, explain this boundary clearly.

Do not cosmetically rename these identifiers. See:
`artifacts/2026-09-29__VISION_VISUAL_COMPATIBILITY_MIGRATION_REPORT_v1.0.md`.

## 19. Recommended remaining work order

The architecture extraction is complete enough that the programme should now emphasise **evidence and product hardening**, not another abstraction rewrite.

### A. Finish/reframe #19 raster quality

Use the newest human evidence.

A sensible next decision is whether:
- baseline mode 0 remains the production choice and #19 can be considered answered for now;
- one tightly scoped browser/application-specific comparison is still useful;
- or an actual deficit appears elsewhere that justifies testing Lanczos/sharpen.

Do not adopt semantic text rerendering without evidence.

### B. #20 UI / DPI / AltGr / localisation

Planned work:
- AltGr collision tests, especially Romanian Programmers and German layouts;
- Settings/Help at DPI/text scaling;
- replace fragile caption lookup with control IDs where needed;
- prepare string resources before UI grows;
- language-neutral persistence/diagnostic identifiers.

### C. #21 Windows Magnifier + low-vision/assessor evidence

Add Windows Magnifier as the free baseline comparator.

Run formative tasks:
- Context + Detail vs full-screen magnification
- orientation/recovery
- Word/Excel/browser
- perceived working-zoom quality
- low-vision/assessor reactions.

Engineering metrics must not substitute for low-vision usefulness.

### D. #22 same-monitor capability spike

Before promising one-monitor/full-screen self-magnification, test:
- capture recursion/exclusion
- click/drag/selection/wheel correspondence
- cursor duplication/hiding
- focus retention
- Start / Alt+Tab / menus / notifications
- elevated-window boundary
- WGC vs Magnification API if useful.

Keep it a capability experiment until evidence is strong.

### E. #23 compatibility ledger

Grow task-level coverage across:
- Windows shell/dialogs
- Word
- Excel
- Outlook
- Edge
- Chrome
- Teams
- WebView/Electron
- PDF
- pilot user’s essential application(s).

Track app version, Windows build, DPI/topology, evidence-provider health, movement correctness, overlay correctness and recovery.

### F. #11/#13/#14 physical qualification

Run when the owner is physically available, because some cases require cable/sleep/display interaction.

## 20. When to ask for another Opus/Astra review

Do **not** invoke another review automatically.

The prior review guided this implementation successfully.

A high-value next dual review is after enough new evidence exists to challenge choices, especially:
- final raster conclusion
- same-monitor result
- lifecycle/identity evidence
- first meaningful compatibility ledger
- early low-vision/assessor feedback.

Then:
- Opus: adversarial architecture/product review of the now-working multi-view system, debt, hidden coupling, 3–4 monitor scaling, recovery, adherence to prior principles.
- Astra: independent fresh review of interaction model, Windows edge cases, accessibility implications and which defaults are genuinely justified.

Then reconcile into likely **Development Plan v0.6 / architecture candidate v1**.

Bring a review earlier only if a current experiment exposes a true architectural contradiction rather than an ordinary bug.

## 21. Known technical risks / cleanup notes

- multi-thread telemetry/concurrency should remain scrutinised as more workers are added;
- `WorkspaceRuntimeGraph` has config-time pointer/inspection seams that should not silently become concurrent mutation;
- EvidenceHub exists, but future multi-view evidence routing policy is not yet fully productised;
- same-monitor interactive mode is unproven;
- physical topology qualification is incomplete;
- some telemetry labels from earlier generations may be semantically awkward;
- renderer quality work must distinguish source/application rasterisation from Vision reconstruction;
- there is currently no evidence-based reason to introduce D3D12;
- do not prematurely build a universal semantic/xFont-style renderer.

## 22. Testing philosophy

Evidence hierarchy:

1. deterministic unit/replay contracts
2. telemetry with explicit semantics
3. physical harness evidence
4. screenshots/video where meaningful
5. direct human perception for visual quality/usability
6. low-vision/assessor feedback for product decisions.

Do not call software timestamp differences photon latency.

Do not treat a screenshot as proof of ZoomText perceived output if capture may bypass its visual path.

Do not turn an edge-acutance metric into a user-quality verdict.

Do not modify production merely to make a flaky harness pass before proving whether the failure is product or harness.

## 23. User interaction/style

Owner prefers:
- concise, concrete, technically reasoned progress reports;
- proactive engineering judgement, not merely executing suggestions;
- British English;
- visible progress during substantive tool work;
- no repetitive approval pauses;
- no superficial “honestly/blunt take” phrasing.

After a pause, a short orientation is useful:
- where we are
- what is proven
- what is current
- the exact next gate.

## 24. First actions for the next chat

1. Call `project_start("visual")` as required; expect current failure.
2. Immediately call `project_start("vision")`.
3. Read `AGENTS.md`, this handover, plan v0.5, raster artifact and P1/P2 artifacts.
4. Inspect live `git status`; preserve everything.
5. Check whether `visual_app.exe` is still running before launching another instance.
6. Reconcile #19 with newest human evidence:
   - 2x Word very good
   - source/main-screen pixel structure already visible in browser case
   - 4x Word baseline better than ZoomText.
7. Do **not** automatically switch to Lanczos/sharpen.
8. Decide whether #19 is sufficiently answered or needs one tight application-specific follow-up.
9. Continue into evidence/product-hardening, not a new architecture rewrite.
10. Ask the user only when the next step genuinely requires their eyes, hardware interaction or disruptive system settings.

## 25. Do not lose these facts

- current default renderer remains mode 0 bilinear;
- `--reconstruction` 1/2/3 are engineering-only;
- latest human judgement: **baseline Word 4x better than ZoomText 4x**;
- browser pixelation is not proof of a generic Vision reconstruction defect;
- Slices 1–9 done;
- P1 and P2 done;
- #14 implementation done, issue open for physical qualification;
- #19 open at a human/interpretation gate;
- latest full regression 19/19 + 8/8;
- project registry key currently `vision`, not `visual`;
- product brand Vision, compatibility executable/package still Visual;
- no commits made for this work;
- preserve dirty tree;
- no new AI agent/reviewer without explicit owner authorisation.

## 26. Relevant files modified/untracked in the current development line

At least:

- `app/src/main.cpp`
- `app/src/core/locator_model.h`
- `app/src/core/poi_evidence.h`
- `app/src/core/view_controller.h`
- `app/src/core/view_update_step.h`
- `app/src/core/view_state.h`
- `app/src/core/workspace_coordinator.h`
- `app/src/core/workspace_runtime_graph.h`
- `app/src/core/geometry_contract.h`
- `app/src/core/monitor_registry.h`
- `app/src/core/topology_reconciler.h`
- `app/src/core/replay_oracle.h`
- related tests under `app/tests/`
- `app/run-return-smoke.ps1`
- `app/run-ui-surface-smoke.ps1`
- `lab/raster-reconstruction/`
- `lab/automation-harness/`
- dated execution artifacts.

This is **not** a claim that all other dirty files belong to this stream. There is much older/unrelated dirty work. Never sweep the whole worktree into one commit.

## 27. Programme orientation

The programme has passed the “can we safely construct the architecture?” stage.

The central question is increasingly:

**What exact Vision product behaviour and quality should be frozen, and what compatibility/recovery evidence is needed before a broader external alpha?**

Core architectural uncertainty is substantially reduced.

Remaining risk is concentrated in:
- usability/defaults
- application compatibility
- display lifecycle
- same-monitor viability
- 3/4-monitor qualification
- accessible UI
- empirical low-vision value.

That is the correct next frontier.

