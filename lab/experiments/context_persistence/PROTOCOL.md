# Visual context-persistence experiment protocol

**Date:** 2026-09-23
**Purpose:** test whether a second display reduces magnification-navigation cost because useful context stays visible, rather than merely because more desktop area exists.

## Core hypothesis

> Dynamic magnified Detail plus persistent task-relevant Context reduces the total cost of maintaining context compared with one-screen magnification, without replacing software panning with excessive screen switching or physical search.

This is an exploratory engineering/usability protocol. It is not a clinical study and results from the current developer/operator are not generalizable to low-vision users.

## Conditions

### A — one-screen magnification baseline

Use a conventional single-screen magnification workflow. For current pre-Doxa testing, Windows Magnifier is the preferred comparator because it is available on the test machine and represents the default Windows solution.

The second display should not contain task-relevant information.

### B — Visual Context + Detail

Use the current Visual two-screen configuration:

- source/work screen remains a stable whole-workspace/context surface;
- second screen is the dynamic magnified Detail view following pointer/caret/focus.

No extra reference automation is required for the first experiment. This condition tests whether persistent spatial context plus a dedicated Detail surface has measurable value.

### C — ordinary two-screen extended desktop

Visual is off.

Use both screens conventionally and allow the participant to arrange windows freely. This controls for the generic productivity benefit of extra desktop area.

If B outperforms A but not C, the benefit may mainly be ordinary multi-monitor productivity rather than Visual's Context+Detail relationship.

## Tasks

Use the same task content in all three conditions. Counterbalance condition order in later multi-participant work.

### Task 1 — reference-based editing

Open an instruction/reference document and a working document.

Apply a sequence of edits that requires repeatedly consulting the reference while preserving the current working location.

Primary costs to observe:

- leaving/reacquiring editing position;
- application/window switches;
- panning or zoom changes;
- reference reacquisition time.

### Task 2 — record comparison

Compare several records with 4-6 attributes and answer questions requiring cross-record comparison.

Examples:

- lowest price subject to two constraints;
- identify records where values disagree;
- rank three options using specified attributes.

Primary costs:

- back-and-forth panning;
- remembering values that are no longer visible;
- screen/window switching;
- comparison errors.

### Task 3 — data transcription / form entry

Read a source record and enter values into a destination form/document.

Primary costs:

- source/destination switching;
- missed/wrong field values;
- losing the current destination field;
- pointer/caret reacquisition.

### Task 4 — table/reference work

Use a grid-like source where row/column context matters while editing or answering questions.

Primary costs:

- losing headers/labels;
- panning to reference values;
- return-to-cell errors;
- zoom changes.

## Measurements

### Objective

For each condition/task record:

- task completion time;
- answer/edit errors;
- Visual viewport hold/pan/jump counts where applicable;
- zoom changes;
- pointer/caret/focus source transitions;
- pointer-to-caret handoff delays;
- display transitions when observable;
- application/window switches;
- explicit 'lost place' events reported by participant.

### Subjective

After each task ask:

- How easy was it to keep your place?
- How much searching did you do?
- Did the extra screen reduce work or merely move the searching elsewhere?
- Was anything visible but distracting?
- Did you feel you were moving your eyes/head too much?
- Which information did you want to remain stable?
- Which display would you remove if forced to remove one?

Use a simple 1-7 rating for:

- orientation confidence;
- perceived efficiency;
- visual load;
- physical effort;
- overall preference.

## Telemetry requirements

For Visual condition B preserve:

- frame/QPC;
- viewport rectangle/action;
- selected POI source/rectangle;
- pointer age;
- UIA snapshot age/status;
- selected POI age;
- zoom/tracking state;
- Present result.

The 2026-09-23 interaction-cadence update provides these fields.

## First developer/operator session

Purpose is protocol debugging, not product validation.

Run Task 1 and Task 2 under A/B/C.

Questions:

1. Can the same task be completed naturally in every condition?
2. Are timing/error measurements easy to collect?
3. Does condition B visibly reduce viewport/search operations?
4. Are there confounds such as browser caret compatibility or different window layouts?
5. What additional telemetry is genuinely needed before low-vision participant testing?

## Doxa reuse

When Doxa arrives, keep the same tasks and measurements and add display-count conditions:

- 1 active display;
- 2 active displays;
- 3 aligned Doxa displays;
- 3 Doxa + laptop.

Do not assign fixed semantic roles at first. Let participants arrange information, then record recurring patterns.

The primary Doxa outcome remains total context-maintenance cost, not number of monitors used.
