# Doxa dual-workspace + shared-Detail concept

**Date:** 2026-09-27
**Status:** Working product concept; pre-hardware and pre-user-validation
**Implementation status:** Not implemented in current Visual

## Purpose

Capture the current Doxa-specific low-vision workstation concept without turning it into current two-screen Visual behavior prematurely.

The concept should be discussed with Ben Carroll and Oliver Jones / BCS and then adapted from their feedback before implementation. Physical Doxa hardware and real low-vision user testing remain required before this becomes a product default.

## Relationship to current Visual

Current Visual remains the main two-screen product and engineering line.

Continue improving that line with reusable capabilities such as:

- capture/render reliability;
- pointer, text-cursor and keyboard-focus tracking;
- viewport policy and intent arbitration;
- established ZoomText / SuperNova terminology and workflow alignment;
- visual enhancements;
- settings and persistence;
- contextual assistance / future AI support where validated.

The Doxa concept is a separate **product track / future workspace mode**, not a reason to build speculative three-screen behavior into current Visual now.

When Doxa implementation begins, start from the then-current Visual baseline so the Doxa mode inherits those improvements. Avoid a long-lived divergent code fork if a shared core plus Doxa-specific workspace layer can express the design cleanly.

A temporary implementation branch may be appropriate when hardware work begins; the architectural intention is shared foundations, not duplicated products.

## Core concept

Use the three external Doxa displays as:

1. **Left workspace** - a stable application/window context.
2. **Centre shared Detail** - the readable magnified view of the workspace currently being used.
3. **Right workspace** - a second stable application/window context.

Use the laptop as a **workspace organiser / controller**, not primarily as another automatically magnified reading surface.

Example:

- Left workspace: Outlook.
- Right workspace: Excel.
- Centre Detail: 2x view of the precise Outlook or Excel region currently being worked on.
- Laptop: shows what occupies Left and Right plus other available open windows.

The main proposition is:

> Keep two work contexts spatially stable while one central Detail surface provides readable magnification wherever active work is happening.

This tries to preserve the productivity benefit of normal dual-monitor work while reducing the context loss caused by conventional magnification.

## Behaviour model

### Stable side workspaces

The left and right external screens should normally remain spatially stable.

They are useful for:

- keeping two related applications/windows visible;
- comparison and transcription;
- source + destination work;
- orientation and spatial memory;
- knowing where another task remains while Detail follows current work.

Do not assume these side screens must be comfortably readable at 1x for every user. They may function partly as context/orientation surfaces while the centre screen provides readable detail.

### Shared centre Detail

The centre screen magnifies the active region of either the left or right workspace.

The source workspace should show a clear **View Locator** / highlighted region corresponding exactly to what the centre Detail screen displays.

The centre should follow the user's **active point of work**, not merely the physical mouse position.

Likely evidence includes:

- deliberate pointer movement;
- text cursor activity;
- keyboard focus;
- recent interaction history.

Existing Visual pointer/caret/focus arbitration is therefore directly reusable.

### Intentional switching, not twitch switching

Crossing a screen boundary should not automatically make the centre Detail jump on every incidental pointer movement.

Candidate protections to test:

- an intent threshold;
- short hysteresis before switching Detail ownership;
- caret/focus retaining ownership while typing;
- deliberate pointer activity taking ownership when the user starts working in the other workspace;
- optional temporary **Lock Detail** behavior.

This must be user-tested. The objective is predictable attention transfer, not maximum responsiveness.

### Laptop workspace organiser

The laptop should represent **windows/work items**, not only application names, because users may have several windows from one application.

Initial conceptual layout:

- **Left** - window currently assigned to the left Doxa workspace;
- **Available** - other open windows/work items;
- **Right** - window currently assigned to the right Doxa workspace.

Prefer large, low-vision-friendly selections and explicit actions such as **Put Left** / **Put Right** over requiring accurate drag-and-drop. Drag/drop can remain a convenience if later useful.

The organiser should not become a complex window manager unless testing demonstrates a real need.

## Potential Windows desktop topology

The physical order is likely:

**Left workspace | Centre Detail | Right workspace**

The Windows logical desktop topology does not necessarily need to match that physical order.

A useful experiment is to make the left and right source workspaces logically adjacent while keeping the centre Detail output outside the normal pointer path. This could allow direct pointer movement between the two working contexts without forcing the pointer through a display whose main purpose is passive magnified output.

This is an engineering hypothesis, not yet a requirement.

## Why this may be valuable

The strongest use cases are tasks where ordinary dual-monitor work is productive but magnification normally destroys context:

- email + spreadsheet;
- source document + form/data entry;
- browser/reference + Word;
- two documents being compared;
- CRM/application + email;
- instructions/reference + primary work.

Potential benefits to test:

- less window switching;
- less panning/searching;
- stable spatial memory for two work contexts;
- faster comparison/reference;
- readable detail without hiding both contexts;
- fewer moments of "where did the other application go?".

These are hypotheses, not established benefits.

## Main risks / failure modes

### Detail switching may become distracting

If the centre changes too readily, the solution may create more disorientation than it removes.

### Three external screens may be too much for some users

Restricted visual field, clutter sensitivity, head/neck movement or other individual factors may make a large physical workspace tiring or confusing.

### Side screens may not provide useful context at the user's vision level

For some users the side screens may be too difficult to interpret unless lightly magnified or visually enhanced. Do not assume literal 1x is always appropriate.

### Laptop control may add complexity

The organiser is useful only if it makes workspace assignment easier than ordinary Windows window management. It must not become another system users have to manage continuously.

### Spatial transitions may be physically costly

The value of persistent information must outweigh additional gaze/head movement.

## Deliberate non-goals for the first Doxa prototype

Do not start with:

- independent complex magnification on all three external displays;
- more than one automatically moving magnified Detail surface;
- AI-based automatic application arrangement;
- central split-screen magnification;
- many user-selectable layouts;
- automatic guessing of which applications belong together;
- a large custom window-management framework.

The first prototype should test the smallest meaningful proposition:

> Two stable workspaces + one shared Detail screen + simple workspace assignment.

## Relationship to terminology and contextual assistance work

The current ZoomText / SuperNova alignment and contextual-assistance research belongs in the main Visual line first.

The Doxa workspace should inherit the resulting terminology and assistance model when implementation begins rather than creating a second vocabulary.

The repaired `artifacts/2026-09-27__low_vision_research_addendum_v0.1.md` supports doing terminology/workflow alignment and contextual help as one coherent pass. The consolidated main-line product decisions are captured in `visual_adoption_and_contextual_assistance_spec.md`.

For Doxa specifically, future contextual assistance may help explain genuinely new workspace behavior, but the concept should first be made understandable through familiar terminology and direct interaction. AI is not a prerequisite for the workspace to function.

## BCS / Ben and Oliver concept validation

Present this as a **concept to challenge**, not a finished feature.

Short framing:

> Doxa could preserve two normal work contexts on the left and right while the centre supplies one readable magnified Detail view that follows intentional activity. The laptop could simply organise which windows occupy those workspaces.

Questions to test with BCS:

1. Do low-vision workers commonly lose productivity because magnification makes two-application comparison/reference difficult?
2. For which user profiles would two stable side contexts be useful?
3. Which users would find three external screens visually or physically overwhelming?
4. Is one shared Detail surface likely to be sufficient?
5. Should Detail switch automatically with activity, require explicit switching, or support both?
6. Would side screens still be useful mainly as context if the user cannot comfortably read them at 1x?
7. Does the laptop organiser simplify normal Windows window management, or add unnecessary complexity?
8. What would make an assessor decide **not** to recommend this configuration?

## Validation once Doxa is available

Start with representative cross-application tasks and compare at minimum:

- conventional one-screen magnification;
- current two-screen Visual arrangement;
- ordinary extended dual-monitor use;
- Doxa dual-workspace + shared Detail.

Representative tasks:

- email -> spreadsheet transfer;
- document/reference writing;
- form transcription;
- two-document comparison;
- browser/reference + primary application.

Measure:

- task time and errors;
- window/application switches;
- zoom/pan adjustments;
- Detail ownership switches;
- unexpected Detail switches;
- pointer/caret/focus reacquisition;
- orientation loss;
- head/gaze transitions;
- fatigue / visual load;
- user preference and reasons.

Do not treat preference alone as proof. The concept is useful only if it reduces total task cost without creating equal or greater visual/ergonomic burden.

## Decision status

**Working:** the dual-workspace + shared-Detail arrangement is the leading concrete Doxa-specific concept to discuss and later prototype.

**Established:** current Visual development remains two-screen and should continue improving reusable foundations.

**Unresolved:** whether the Doxa arrangement is genuinely better for target users, which users benefit, how Detail ownership should switch, whether side screens need their own magnification, and whether the laptop organiser adds value.

**Next evidence:** Ben/Oliver feedback, physical Doxa investigation, then low-vision user testing.
