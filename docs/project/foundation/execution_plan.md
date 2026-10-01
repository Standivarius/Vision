> **HISTORICAL / SUPERSEDED FOR SEQUENCING (2026-10-01).**
> This file records the earlier research-stage execution plan. Do not use it to decide current next work.
> The canonical current sequence is `docs/project/foundation/feature_roadmap.md`.
# Visual / Doxa execution plan

**Date:** 2026-09-23
**Status:** canonical working plan

## Product objective

The product objective is to make **Doxa a strong workstation for people with low vision**.

Visual is the enabling magnification software and experimental platform. It is not currently being developed as a broad standalone magnifier competitor to ZoomText or SuperNova.

The working value proposition is:

> **Magnification + persistent useful information + productivity, within an ergonomically manageable workspace.**

This remains a hypothesis to validate with low-vision users and Doxa hardware.

## Phase 1 â€” Finish the two-monitor Visual POC

Purpose: create a stable experimental magnifier before Doxa hardware arrives.

### Completed in the current engineering slice

- fast-mouse / pointer-to-caret lag architecture corrected by decoupling interaction/render cadence from WGC frame arrival;
- pointer movement age, UIA sample age/status, selected POI age and selected POI rectangle added to telemetry;
- UIA semantic-caret evidence now survives a transient provider miss only with its original timestamp, so normal freshness rules still expire it;
- Release build succeeds;
- CTest: **4/4 passed**;
- short steady-cadence smoke: pass;
- fast pointer stress: pass;
- deterministic pointer -> caret handoff: pass;
- 60-second integrated soak: pass;
- deterministic UIA focus regression: pass.

Key evidence is recorded in:

`artifacts/2026-09-23__gpt-5.6-sol__interaction_cadence_fix_and_browser_compatibility_v0.1.md`

### Still required for Phase 1

- short **human** regression of fast mouse movement and pointer -> caret handoff when the user is back at the machine;
- reliable browser editing-caret validation;
- keep UI/packaging minimal;
- preserve the existing two-monitor Context + Detail architecture.

### Browser status

**2026-09-29 update:** the deterministic Edge editing smoke now explicitly reacquires the fixture textarea by UI Automation (AutomationId=e), verifies that it exposes TextPattern, and measures sustained caret availability/selection. Three consecutive Edge 153 runs showed UIA caret presence for 100% of the measured phase, caret selection for 88.3-89.4% of frames, and zero Present failures. This closes the original fixture-level uncertainty. The result is intentionally bounded and does not certify arbitrary contenteditable, rich-editor or embedded-Chromium scenarios.

Do not spend unbounded time on Chromium accessibility before the human regression. Browser support is important, but it should remain a targeted compatibility task rather than expanding Vision into a browser-accessibility project.

### Definition of done

- live second-screen magnification is stable;
- pointer/caret/focus tracking feels responsive in human use;
- exact normal/return works;
- topology failure shuts down safely;
- telemetry can explain tracking failures;
- application can be launched easily enough for experiments.

Do **not** expand into a general-purpose ZoomText/SuperNova replacement.

## Phase 2 â€” Test persistent context / reference

Purpose: test the most important research mechanism before Doxa arrives.

### Prepared

The first A/B/C experiment protocol now exists at:

`lab/experiments/context_persistence/PROTOCOL.md`

Reusable fixtures exist under:

`lab/experiments/context_persistence/fixtures/`

The initial comparison is:

1. ordinary one-screen magnification;
2. current Visual two-screen dynamic Detail + persistent source/context;
3. ordinary two-screen extended desktop without Visual.

This is deliberately tested **before** adding more software. The current two-screen Visual configuration already provides the essential Context + Detail condition, so the first experiment can determine whether the mechanism has value without prematurely implementing Freeze View.

### After the first A/B/C session

Only if the results show that a separately preserved reference region would remove additional navigation cost, implement the smallest useful Freeze/Reference prototype:

- user explicitly pins the information to preserve;
- dynamic Detail continues following the active POI;
- preserved reference remains spatially stable;
- no broad feature family or polished workspace system yet.

Representative tasks:

- writing/editing from a reference document;
- record/data comparison;
- form/data entry;
- spreadsheet/reference work.

Record task time, errors, viewport movement, zoom changes, screen transitions, pointer/caret reacquisition and subjective workload/orientation.

## Phase 3 â€” Doxa research before Doxa-specific software

Continue literature/user-workflow research while waiting for the hardware.

Research question:

> Does additional physical screen space reduce magnification-navigation cost faster than it increases visual search, head/gaze movement and clutter?

Do not assign permanent monitor roles yet.

Prepare experiments for:

- 1 vs 2 vs 3 vs 4 active displays;
- upper-centre Detail vs laptop-close Detail;
- stable secondary surfaces vs several dynamic surfaces;
- flat vs inward-angled side panels;
- task-dependent layouts;
- individual differences in magnification, viewing distance, usable visual field and input habits.

## Phase 4 â€” When Doxa arrives: physical experiments first

Before writing Doxa-specific behavior:

1. inventory the exact display/controller/driver topology;
2. test physical geometry and viewing distance;
3. run the prepared productivity/accessibility experiments;
4. observe which layouts users naturally prefer;
5. identify which screen configurations improve total task performance rather than merely reducing software panning;
6. only then define Doxa defaults/presets.

Allow the possibility that:

- two screens are best for some users/tasks;
- three aligned Doxa screens are best for others;
- the laptop is useful only for a subgroup;
- four active screens may be detrimental for some users.

## Phase 5 â€” Doxa-specific Visual

Only after physical evidence exists, reduce variability deliberately around the known Doxa environment.

Potential product capabilities:

- reliable Doxa display identification;
- a small number of evidence-based workspace presets;
- persistent Context/Reference surfaces;
- one primary dynamic magnified Detail surface unless testing supports more;
- quick layout switching by task;
- low-vision locator/tracking defaults;
- per-user preferences;
- simplified recovery behavior.

Avoid broad arbitrary-hardware support unless it directly serves the Doxa product.

## Phase 6 â€” Packaging and support

Do not build custom infrastructure unless necessary.

Current preferred adoption path:

- packaging/update: Velopack;
- release hosting: GitHub Releases;
- code signing when external distribution begins: Microsoft/Azure signing path if eligible;
- remote support: RustDesk OSS;
- diagnostics: small Visual-owned structured diagnostic bundle;
- LLM support: later, using a platform such as Dify around diagnostic bundles and product knowledge;
- central telemetry only when field deployments justify it.

Hardware-driver/firmware installation remains separate until the actual Doxa controller/vendor package is known.

## Deferred ideas

Do not pursue now:

- broad generic installer/platform engineering;
- arbitrary multi-monitor architecture beyond what current POC and Doxa require;
- full screen reader/speech suite;
- ZoomText/SuperNova feature parity;
- TableView-style arbitrary webpage restructuring;
- autonomous LLM with unrestricted machine control;
- automatic hot-plug rebinding unless real usage makes relaunch unacceptable.

## Next actions

### Without user physical interaction

- checkpoint the interaction-cadence fix and evidence;
- keep Chromium caret compatibility as a bounded regression surface and expand coverage only for concrete editor scenarios;
- refine the Context/Reference experiment harness/materials;
- maintain the two-monitor POC, not feature expansion.

### When the user is back at the machine

1. rerun the fast mouse -> caret task for one minute;
2. confirm whether the previously perceived ~2 s lag / ~1 s cross-to-caret delay is gone;
3. if the fix feels good, run the first Context+Detail productivity comparison using the prepared fixtures;
4. use those results to decide whether a dedicated Freeze/Reference prototype is justified.
