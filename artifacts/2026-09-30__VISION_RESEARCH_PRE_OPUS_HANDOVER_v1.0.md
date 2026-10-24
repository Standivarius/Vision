# Vision Research / Pre-Opus Handover v1.0

Date: 2026-09-30
Purpose: authoritative handover for the next Vision chat after the technical/commercial incumbent-research phase and before the independent Opus 5.5 architecture/product review.

## 0. Authority and source hierarchy

When facts conflict, use this order:

1. Live repository and live tests at `C:\dev\Vision` on `MARIUS-DELL`.
2. Current `AGENTS.md`, `STATUS.md`, `docs/project/programme/`, `app/README.md`, foundation docs, current Git/GitHub state.
3. This handover package.
4. Current pre-Opus research artifacts listed below.
5. The saved full conversation from the current ChatGPT chat, which the owner will attach to the new chat.
6. Older dated handovers/artifacts.

The saved conversation is valuable for exact reasoning, corrections and user intent. It must not override newer live-repo truth.

## 1. Canonical project identity

- Product/project: Vision.
- Host: `MARIUS-DELL`.
- Repo: `C:\dev\Vision`.
- Branch: `master`.
- GitHub repo: `Standivarius/Vision`.
- GitHub Project: Vision, Project #6.
- Local Project Dev registry key: `vision`.
- Correct startup call: `project_start("vision")`.

The former `Visual` name is legacy. Do not globally replace legacy internal identifiers or compatibility-sensitive `Visual` / `visual` strings without evidence that they are safe to change.

## 2. Mandatory tool / execution rules

### Primary local-development path

Use @Local Project Dev - Dell for substantive repo work. At the beginning of a substantive session call project_start("vision") and treat the returned repo context plus AGENTS.md, STATUS.md and current-state documents as operational truth.

### Recovery / host-admin path

Use @Remote Desktop Commander as the backup/recovery path, not as the normal development environment.

If Local Project Dev fails or its tunnel is unhealthy:
1. Use RDC on Marius-DELL to diagnose/recover the local bridge.
2. Check/restart the scheduled task/watchdog for Local Project Dev.
3. Return to Local Project Dev for substantive work once healthy.
4. Continue through RDC only if Local Project Dev genuinely cannot be restored.

If both access paths fail, ask the owner for a local recovery step or provide a tightly scoped local recovery prompt. Do not silently switch to another repo or machine.

### Auto-recovery already configured

After Windows reboot both bridges should recover automatically:
- ProjectDevDellTunnel -> C:\mcp\project-dev\start-tunnel-resilient.ps1
- RemoteDesktopCommander-Dell -> C:\mcp\rdc\start-rdc-resilient.ps1

The old Project Dev Startup-folder shortcut was backed up as C:\mcp\project-dev\ProjectDevDellTunnel.startup-backup.lnk.

A reboot during this chat verified that both Local Project Dev and RDC returned automatically.

### Other operating constraints

- Preserve all pre-existing dirty/uncommitted work.
- No reset, clean, mass restore, branch switching, or destructive Git operations.
- Do not commit or push unless explicitly asked.
- Use GitHub Projects, not Linear, for programme tracking.
- Do not delegate to external AI agents unless the owner explicitly authorises it.
- Opus 5.5 is the next intended independent reviewer, but it has not yet been invoked.

## 3. Repository safety / current worktree condition

The tree is very dirty and contains a mixture of current Vision work, older migration work, generated artifacts, deleted legacy paths, build/test evidence and untracked research outputs. Treat the dirty tree as working context, not cleanup debt.

Before any broad edit:
1. inspect actual Git status;
2. identify pre-existing modifications;
3. touch only files needed for the current task;
4. preserve unrelated edits;
5. do not infer that untracked/generated paths are disposable.

## 4. Current programme decision

The owner simplified the programme on 2026-09-29.

### Doxa Installer

This is independent from Vision. Hardware-specific work waits for the real SM770-based Doxa unit. Driver/firmware/controller logic must not leak into Vision architecture.

### Vision

Vision is the active product: one hardware-agnostic Windows low-vision application intended to support ordinary 2, 3 and 4 monitor systems. Doxa later becomes one qualified hardware configuration, not a fork.

### Broader Doxa software

Parked. Do not spend effort on broader Doxa productivity/ergonomics opportunities unless the owner reactivates that work.

### Active sequence

technical + commercial incumbent research -> feature/value scope -> proposed 2-4 monitor architecture/development plan -> independent Opus 5.5 review -> reconcile -> implementation

Pricing strategy is later, after product scope is credible and dealer/assessor evidence exists.

## 5. Current Vision engineering baseline

The current two-screen alpha is real and tested. Important current capabilities include:

- Windows Graphics Capture of a physical source monitor;
- D3D11 crop/scale/render path with a steady interaction/render loop;
- pointer tracking;
- Win32 caret/focus evidence;
- UI Automation caret/focus evidence;
- freshness/intent arbitration between pointer, caret and focus;
- viewport controller with hold/pan/jump behaviour and comfort margins;
- Context + Detail model;
- View Locator;
- temporary exact 1x and return;
- colour transforms including contrast/invert/grayscale;
- settings persistence;
- Help / Ask Vision surfaces;
- installer/update/diagnostic infrastructure;
- current two-screen acceptance and multiple smoke/regression runners.

Key implementation/document references:
- app/README.md
- app/src/main.cpp
- app/src/core/
- app/src/tracking/
- app/src/settings_store.cpp
- app/src/settings_window.cpp
- docs/project/foundation/architecture_baseline.md
- docs/project/foundation/feature_roadmap.md
- docs/project/foundation/engineering_principles.md
- artifacts/2026-09-29__gpt-5.6-sol__vis005_two_screen_acceptance_v1.0.md

Important architectural limitation:

The runtime enumerates multiple monitors, but the live product model is still effectively one physical source monitor -> one CaptureRunner -> one Renderer/Detail view, plus an optional unmanaged Reference monitor. Genuine generic 2-4 monitor support therefore requires an architectural generalisation, not merely exposing more monitor selectors.

## 6. Current research conclusion

Do not pursue ZoomText/SuperNova feature parity.

The current working product boundary is a focused low-vision magnifier for users with useful functional vision, not a reduced full screen reader.

The strongest likely first-product value cluster is:
- high-quality magnification and text rendering;
- reliable pointer/caret/focus tracking;
- predictable viewport movement;
- quick orientation/context recovery;
- colour/contrast controls;
- visible pointer/caret/focus orientation aids;
- robust application compatibility;
- coherent 2-4 monitor behaviour;
- simple persistence/configuration;
- reliable install/update/diagnostics.

Full screen-reader semantics, Braille, deep blind-user navigation and comparable JAWS/SuperNova Screen Reader behaviour remain outside the initial scope unless evidence changes the product boundary.

## 7. Commercial research status

The commercial research is intentionally feature-linked rather than a separate pricing exercise.

Current evidence supports these points:
- current specialist magnifier pricing is materially above a commodity utility price;
- incumbent pricing includes compatibility maintenance, support, training/channel familiarity and enterprise deployment value, not only magnification code;
- dealer/distributor channels matter because assessment, installation, training and support can be economically significant;
- exact dealer gross margins were not found publicly and must not be invented;
- UK Access to Work evidence shows visual-impairment workplace support sits inside a funded specialist ecosystem, but those figures are not a screen-magnifier market size;
- final pricing/route-to-market is deliberately deferred until product scope, Opus review and dealer/assessor evidence.

Primary research reference:
- artifacts/2026-09-30__gpt-5.6-sol__vision_feature_and_commercial_research_v0.2.md

## 8. Critical feature-discovery correction

The first hands-on plan over-weighted benchmark mechanics: pointer, caret, focus, zoom and monitor crossing.

The owner explicitly corrected this during the chat after observing features such as red rectangles and yellow arrows around the caret/focus. The research was widened into a comprehensive feature-discovery sweep.

This correction is important: mature magnifiers invest heavily in orientation and visibility aids, not only viewport tracking.

SuperNova Magnifier 25.05 live inventory includes:
- multiple magnifier view modes;
- extensive colour schemes;
- highlighting presets such as Large Red, Large Red with Mouse, Large Blue, Large Blue with Mouse, Large Yellow, Large Yellow with Mouse and Custom;
- mouse-pointer settings;
- Hooked Areas;
- Multiple Monitors;
- Doc Reader settings;
- application/situation settings;
- advanced visual settings;
- touchscreen and ancillary media/support features.

ZoomText research similarly identified:
- pointer locator schemes;
- cursor/caret locator shapes such as wedges/circles/frames;
- focus enhancement shapes such as frames/blocks/underlines;
- View Locator;
- Freeze View;
- multiple-monitor modes;
- xFont/text smoothing;
- Tethered View;
- Live Text View;
- application-specific configurations;
- camera/OCR/touch/support tooling.

The practical product lesson is not to copy this breadth. It is that a focused first Vision product likely needs an explicit orientation/enhancement layer, with a small number of strong presets.

Canonical references:
- artifacts/2026-09-30__gpt-5.6-sol__incumbent_feature_discovery_and_value_matrix_v0.1.md
- artifacts/2026-09-30__gpt-5.6-sol__manual_derived_feature_inventory_and_test_plan_v0.1.md

## 9. Hands-on incumbent status

### ZoomText 2026

Official Freedom Scientific build 2026.2606.73.400 was installed, signature-verified, rebooted as required, and used in the documented 40-minute unlicensed mode.

Hands-on evidence includes:
- pointer tracking;
- caret navigation;
- focus navigation;
- zoom stepping;
- temporary 1x and return;
- useful cross-monitor evidence;
- process/resource observations.

ZoomText was then removed for a clean SuperNova phase. Reinstallation remains possible later for further 40-minute-mode checks.

### SuperNova Magnifier 25.05

Official Dolphin SuperNova Magnifier 25.05 was downloaded from Dolphin, signature-verified and installed. Dolphin EasyReader and Remote Support were also installed as package components.

Hands-on evidence already recorded includes:
- pointer sweep;
- caret navigation;
- focus navigation;
- cross-monitor movement;
- representative visual enhancement presets including Large Red and Large Yellow;
- live SuperNova menu/control-panel inventory;
- resource observations.

A transient UIA issue occurred in one caret run; the harness was hardened to deterministic foreground/keyboard fallback and recorded the fallback. Do not label this a SuperNova defect without stronger evidence.

Current machine state at handover:
- SuperNova Magnifier 25.05 remains installed.
- EasyReader and Dolphin Remote Support remain installed.
- After the most recent restart, no SuperNova process was running at the instant of the handover status check.
- Launch SuperNova again if further live feature testing is needed; do not reinstall unless necessary.

Canonical hands-on reference:
- artifacts/2026-09-30__gpt-5.6-sol__incumbent_hands_on_validation_v0.2.md

Harness:
- lab/incumbent-research/
- lab/benchmarks/incumbent_research/runs/

The harness is supporting infrastructure, not the product. Do not turn research tooling into a development project.

## 10. Remaining research gaps that matter

The pre-Opus evidence is substantially complete, but these gaps remain explicit:

1. Matched Office text-quality comparison: Vision raster scaling versus incumbent xFont/TrueFonts paths at practical matched zoom. This is the most important unresolved renderer decision experiment.
2. Subjective low-vision preference among full-screen, Context+Detail and one-monitor lens/fixed/contextual alternatives.
3. Real-task value of Hooked Areas / Freeze View / Tethered View-style context aids.
4. Full hands-on behaviour of per-monitor zoom/colour, Mouse Buffer, monitor switching, clone/span/presentation modes.
5. Physical 3/4-monitor usability; current Dell bench is two physical displays.
6. Dealer/assessor evidence on minimum feature set, training/support burden and procurement expectations.

Not every gap must block architecture extraction. Opus should decide which gaps are true preconditions and which can gate later renderer/product decisions.

GitHub Project #6 includes a separate Todo item:
- Vision - Office text-quality decision experiment

## 11. Proposed pre-Opus architecture hypothesis

This is a proposal for independent review, not permission to implement.

### Monitor / topology layer
A MonitorRegistry-like service should own enumeration, DPI, geometry, topology changes and stable identity. Long-term identity should not rely only on transient DISPLAY1-style names.

### Capture source layer
A CaptureSource should own WGC lifecycle and latest source texture independently of a destination window. Several views should be able to consume one source without duplicate capture when appropriate.

### Evidence layer
Pointer and semantic accessibility evidence should be sampled independently of rendering. The current proposal uses a shared EvidenceHub-like responsibility, but Opus must challenge whether evidence should be global, source-scoped, view-scoped or hybrid.

### View session layer
A ViewSession should bind:
- a capture source;
- a destination monitor/window;
- its own viewport controller;
- zoom/visual settings;
- output/render state.

The model should express:
- current Context A -> magnified Detail B;
- self-monitor magnification A -> A;
- independent A -> A and B -> B;
- one Context feeding several views;
- mixed magnified/unmanaged displays;
- later clone/presentation behaviour if justified.

### Visual overlay / enhancement layer
Hands-on feature discovery added an explicit architectural correction:

POI/viewport policy and visual-overlay policy are separate consumers of pointer/caret/focus evidence.

The first product should have a dedicated overlay/enhancement responsibility supporting a small set of high-visibility pointer/caret/focus presets, per view/monitor where appropriate. Do not bury locator styling inside POI arbitration.

### One-monitor contextual view seam
Do not encode every incumbent lens/split geometry now, but preserve a clean path for one useful non-full contextual/lens/fixed view on a single monitor.

### Renderer / text-quality gate
Do not build a semantic text renderer during architecture extraction.

Preserve a seam for:
1. raster scaling baseline;
2. shader-based sharpening/reconstruction;
3. semantic text enhancement only if matched Office testing proves it materially necessary.

### Application-scoped settings
Do not build a large profile editor now, but design the state model so later app-specific overrides for zoom, visual transformations, overlay presets and view assignment are possible.

### Localisation
English first. Make the app localisation-ready before the settings/UI surface grows:
- string/resource keys;
- Unicode;
- language-neutral stored IDs;
- translation-tolerant layouts;
- no English labels as persistent state.

Canonical architecture reference:
- artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_development_plan_v0.2.md

## 12. GitHub Project #6 status

Current programme items:

- Vision - technical + commercial incumbent research: Done
- Vision - hands-on ZoomText / SuperNova validation: Done
- Vision - pre-Opus product scope + architecture plan: Done
- Vision - Opus independent review checkpoint: Todo
- Vision - 2-4 monitor core implementation: Todo
- Vision - localisation-ready foundation: Todo
- Vision - dealer / assessor commercial validation: Todo
- Vision - pricing and route-to-market decision: Todo
- Doxa Installer - resume on SM770 arrival: Parked/Todo
- Doxa adjacent software opportunities: Parked/Todo
- Vision - Office text-quality decision experiment: Todo

Use GitHub Project #6 for execution visibility, but do not let board administration block technical/research work. The repository documents remain the richer source of technical truth.

## 13. Canonical pre-Opus artifact set

Read these before making product/architecture claims:

1. artifacts/2026-09-30__gpt-5.6-sol__vision_feature_and_commercial_research_v0.2.md
2. artifacts/2026-09-30__gpt-5.6-sol__incumbent_feature_discovery_and_value_matrix_v0.1.md
3. artifacts/2026-09-30__gpt-5.6-sol__manual_derived_feature_inventory_and_test_plan_v0.1.md
4. artifacts/2026-09-30__gpt-5.6-sol__incumbent_hands_on_validation_v0.2.md
5. artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_development_plan_v0.2.md
6. artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.2.md
7. artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_review_package_v0.2.md
8. docs/project/foundation/opus_5_5_prompting_instructions.md

Also read:
- AGENTS.md
- STATUS.md
- docs/project/programme/inventory_and_roadmap.md
- docs/project/programme/work_breakdown.md
- docs/project/programme/next_chat_handover.md
- app/README.md
- docs/project/foundation/architecture_baseline.md
- docs/project/foundation/feature_roadmap.md
- docs/project/foundation/engineering_principles.md

Historical/context references:
- artifacts/2026-09-29__VISION_MASTER_HANDOVER_v1.0.md
- artifacts/2026-09-29__VISION_PREVIOUS_DEVELOPMENT_CONVERSATION_ARCHIVE.md
- the full saved current conversation that the owner will attach to the new chat

Do not blindly re-research terminology already covered in:
- artifacts/2026-09-27__low_vision_magnifier_mental_models_and_migration_research_v0.1.md
- artifacts/2026-09-27__low_vision_research_addendum_v0.1.md

## 14. Immediate next-chat objective

The next chat should NOT restart the project from first principles.

First:
1. call project_start("vision");
2. read this handover;
3. inspect live AGENTS.md / STATUS.md / programme docs / git status;
4. read the v0.2 pre-Opus artifact set;
5. use the saved full conversation only to recover reasoning/corrections that are not explicit in the files.

Then assess whether any decision-material incumbent feature gaps still need hands-on closure before Opus.

Do not regress to a basic pointer/caret/focus benchmark. The owner explicitly requires comprehensive feature consideration, including orientation/highlighting, view modes, multi-monitor behaviours, settings/profiles and context aids.

The highest-value remaining technical experiment is the matched Office text-quality gate. Before spending time on it, decide whether its result could change the architecture that Opus is being asked to review. If yes, run it. If it can safely gate only the later renderer decision, leave it as an explicit open gate and let Opus arbitrate.

Likewise, do not mechanically exercise every SuperNova menu item. Prioritise only tests whose result could materially change:
- first-product scope;
- architecture;
- sequencing;
- commercial/support burden.

## 15. Opus checkpoint

The current Opus assignment is already prepared:
- artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.2.md

Prompting rules:
- docs/project/foundation/opus_5_5_prompting_instructions.md

Package index:
- artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_review_package_v0.2.md

Do not invoke Opus automatically on chat start.

First confirm the package is internally consistent with the live repo and the feature-discovery correction. If you make material changes, update the pre-Opus artifacts coherently rather than creating contradictory parallel plans.

When the package is ready, tell the owner clearly that the Opus checkpoint is ready. Invoke Opus only when explicitly authorised.

## 16. Work after Opus, if the review supports the direction

Likely sequence, subject to the independent review:

1. Reconcile Opus findings into a final architecture/product decision record.
2. Convert accepted architecture into an incremental implementation plan that preserves the passing two-screen baseline after every slice.
3. Extract monitor/topology, capture-source, evidence and view-session responsibilities without intended feature change.
4. Generalise workspace/state semantics to ordinary 2-4 monitor systems.
5. Add the explicit visual-overlay/enhancement layer with a small strong preset set.
6. Add localisation-ready resource handling before the UI surface grows.
7. Qualify one-monitor contextual/lens/fixed behaviour if retained.
8. Run the Office text-quality gate before choosing any semantic text-enhancement path.
9. Expand the application compatibility matrix: Word, Excel, Outlook, Edge/Chrome, Teams/Electron and common Windows UI.
10. Add app-scoped overrides only after the state model is stable.
11. Evidence-gate second-layer features such as Hooked Areas/Freeze-like regions, clone/presentation, Doc Reader, basic speech/read-aloud.
12. Validate with low-vision users and dealer/assessor interviews.
13. Only then decide pricing and route to market.

Separately:
- resume Doxa Installer hardware-specific work when the real SM770 hardware arrives;
- keep broader Doxa software opportunities parked unless explicitly reactivated.

## 17. Working style / decision discipline

The owner expects strategic-consultant behaviour, not mechanical execution.

- Think proactively and challenge assumptions.
- Do not simply mirror the owner's suggestions; identify missing dimensions and implications.
- Keep the programme simple; do not create many artificial workstreams.
- Give progress updates during long work rather than appearing stuck.
- When a tool fails, diagnose briefly and recover; do not let infrastructure troubleshooting consume the product task.
- Prefer evidence-driven prioritisation over feature-count thinking.
- Distinguish documented incumbent capability, hands-on observation, user-value inference, architecture hypothesis and commercial inference.
- Never turn a provisional planning percentage into a factual measurement.
- Do not infer dealer margins or installed-base market share without evidence.

## 18. Completion condition for the pre-Opus phase

The pre-Opus phase is complete when:
- the live repo and current research package are mutually consistent;
- comprehensive incumbent feature families have been considered, not just tracking;
- any architecture-changing evidence gaps have either been tested or explicitly handed to Opus as bounded uncertainties;
- the v0.2 Opus prompt reflects the current research and architecture hypothesis;
- the owner is told clearly that the package is ready.

At that point, STOP. Do not begin the 2-4 monitor refactor and do not invoke Opus without explicit owner approval.

## 19. Saved-conversation reference

The owner will save and attach the full conversation that produced this handover.

Use that conversation when you need:
- the exact sequence of user corrections;
- why the programme was simplified;
- why technical and commercial research were joined;
- why the incumbent research was widened beyond pointer/caret/focus;
- the detailed ZoomText/SuperNova installation/testing history;
- the bridge-recovery/autostart decisions;
- the reasoning behind the pre-Opus architecture hypotheses.

Do not force the new chat to reread the entire conversation before doing anything. Read this handover and the canonical artifacts first; use the conversation selectively when an unresolved historical question matters.
