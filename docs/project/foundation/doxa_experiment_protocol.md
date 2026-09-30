# Doxa low-vision experiment protocol

**Date:** 2026-09-23
**Status:** working protocol derived from the current low-vision research; hypotheses remain open

## Purpose

Use Visual first on the existing two-monitor setup and later on Doxa to test one central proposition:

> Does persistent additional screen space reduce the total cost of maintaining context under magnification without creating equal or greater visual-search and ergonomic costs?

The protocol intentionally does not assume that more screens are better, that four screens should be active, or that particular Doxa screens should have fixed semantic roles.

## Primary outcome model

Evaluate three outcome dimensions together:

1. **Magnification / visual access** — readable detail, reliable target acquisition, orientation, caret/pointer/focus recovery.
2. **Productivity / context** — less panning, fewer window switches, easier comparison/reference, fewer errors, faster task completion.
3. **Ergonomics / visual load** — head/gaze movement, fatigue, clutter, distraction, viewing distance and posture.

Personal preference, functional vision, habitual magnification strategy and task type are expected to modify the optimum.

## Phase A — current two-monitor exploratory protocol

This is an engineering/usability experiment, not a generalizable low-vision study.

### Conditions

Run the same task under three conditions:

**A1 — one-screen conventional magnification**

- user works on one display;
- no persistent second-screen context.

**A2 — Visual Detail + persistent Context**

- one display contains the active magnified Detail view;
- the other preserves task-relevant context.

**A3 — ordinary two-monitor extended desktop**

- same physical screen area as A2;
- no dedicated persistent-context behavior;
- user manages windows conventionally.

A3 is essential because it separates the value of **persistent context** from the generic benefit of additional desktop area.

### Representative tasks

Use tasks that require relating spatially separated information:

1. **Reference writing** — read from a source document/web page and write/edit a second document.
2. **Comparison** — compare several records/options and answer questions or make a selection.
3. **Spreadsheet/data entry** — enter or modify values while relying on headers/reference cells that can leave a magnified viewport.
4. **Form/transcription** — transfer values from a source into a form.
5. **Document review** — edit text while responding to comments/changes/reference notes.

Do not use only continuous prose reading; that would under-test the productivity hypothesis.

### Measures

Capture objective measures where practical:

- task completion time;
- task errors;
- viewport/pan count and distance;
- zoom changes;
- application/window switches;
- pointer/caret/focus reacquisition events;
- pointer crossings between displays;
- display transitions;
- renderer/capture stalls and Present failures.

Capture subjective measures after each condition:

- orientation confidence;
- perceived efficiency;
- visual load/clutter;
- fatigue/discomfort;
- perceived responsiveness;
- preferred configuration and reason.

### Decision criterion

Do not count reduced panning alone as success.

A context condition is useful only if it produces a meaningful reduction in total task cost — time and/or errors and/or interaction burden — without an offsetting increase in visual load, physical movement or confusion.

## Phase B — Doxa display-count dose response

Once Doxa hardware is available, repeat representative tasks across:

1. one active upper display;
2. two active upper displays;
3. all three upper Doxa displays;
4. three upper displays plus laptop.

Do not assign fixed roles initially. Let the user arrange the task information, then record what configurations recur.

Questions:

- Does the second display deliver most of the benefit?
- Does a third add measurable value?
- Does the laptop add value, no value or burden?
- At what point do visual search and physical movement rise faster than navigation savings?

## Phase C — laptop-as-close-Detail experiment

Compare:

1. Detail on upper-centre Doxa screen;
2. Detail on the closer laptop display;
3. unrestricted user choice.

Use sustained reading/editing and precision interaction rather than a brief preference trial.

Record:

- chosen magnification;
- chosen viewing distance;
- task performance;
- gaze/head transitions;
- neck/postural discomfort;
- visual fatigue;
- preference after sustained use.

The expected trade-off is real: the closer laptop may provide useful physical magnification while increasing vertical gaze/postural cost.

## Phase D — stable versus dynamic secondary surfaces

Compare:

1. one dynamic magnified view only;
2. dynamic magnified view + stable secondary information;
3. more than one automatically changing view;
4. secondary view changes only on explicit user request.

Measure:

- unexpected display changes;
- reported disorientation;
- reacquisition time;
- display-search time;
- gaze/head switching;
- workload;
- motion/distraction ratings.

Working hypothesis: unnecessary secondary-screen movement is a risk, but this remains to be tested rather than encoded as a rule.

## Participant/context variables to record

For every participant or pilot user, capture at minimum:

- habitual magnification level/range;
- habitual magnifier type;
- habitual monitor size and viewing distance;
- central versus peripheral field-loss profile when known;
- acuity when available;
- contrast/light sensitivity;
- motion/clutter sensitivity;
- mouse/touchpad/keyboard usage;
- pointer-enhancement use;
- speech/TTS use;
- years of magnifier experience;
- task-specific workstation habits.

Do not assume medical diagnosis alone predicts the correct Doxa configuration.

## Post-task interview prompts

Ask mechanism-focused questions:

- At what points did you need information you could no longer see?
- When you moved to another screen, how did you find your place again?
- Were there moments when you knew information existed but did not know which screen contained it?
- Did another screen change how much magnification you wanted?
- Which information did you want to stay exactly where it was?
- Did anything move or change before you wanted it to?
- Was the lower laptop easier to see because it was closer, or harder because of its position?
- Which display transitions felt physically costly or tiring?
- Did any visible information help initially but later become distracting?
- If one display had to disappear, which would you remove and what would you lose?
- What task, if any, genuinely required an extra display?
- Would you arrange the screens differently for reading, writing, spreadsheets, research or meetings?

## Immediate engineering link

Before running Phase A seriously, Visual should first correct and instrument the mouse-to-caret handoff issue observed in the first human task-use session.

Required additional telemetry:

- exact last physical pointer-movement timestamp;
- pointer evidence age;
- UIA sample timestamp/age;
- UIA caret availability/failure status;
- selected POI rectangle;
- source transition reason where practical.

This allows later experiments to distinguish human-perceived delay from pointer freshness, semantic-caret availability and render/capture stalls.

## Scope guardrails

Until Doxa arrives:

- keep Visual focused on the two-monitor magnification/tracking POC;
- do not build speculative four-screen behavior;
- do not assume four active displays are desirable;
- do not hard-code Doxa screen roles;
- keep installer/LLM/distribution work secondary to the core POC and Doxa research.
