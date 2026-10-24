# Doxa low-vision research framework

**Date:** 2026-09-23
**Status:** working research framework; hypotheses, not product decisions

## Product framing

The primary product is Doxa as a low-vision workstation.

Visual is the software companion and current two-monitor engineering test bed. Its primary technical purpose is magnification, tracking and viewport behavior. Until Doxa hardware is available, Visual should remain focused on making the two-monitor case work reliably rather than becoming a highly variable general-purpose magnifier product.

The central Doxa research question is not how to magnify four monitors. It is:

> How should the physical Doxa workspace be configured so that people with low vision gain both visual access and productivity without creating excessive visual search or ergonomic burden?

## Three outcome dimensions

Treat Doxa configuration as a balance among three outcomes.

### 1. Magnification / visual access

Questions:

- Can the user reliably read and interact with the active content?
- Is the magnified target easy to acquire and keep track of?
- Is enough surrounding context visible to preserve orientation?
- Does the system reduce unnecessary panning and zoom changes?

Magnification remains the primary purpose of Visual.

### 2. Productivity / information exposure

Working hypothesis:

More simultaneously visible, spatially stable information may reduce task switching and make comparison/reference work easier. This is strongly plausible from general multi-monitor use and from the known difficulty low-vision users face when magnification hides context, but it is not yet established that more monitors improve productivity for low-vision users in the Doxa arrangement.

Research should test whether additional screens help with:

- source/destination comparison;
- document + reference work;
- forms/data entry;
- research/browsing;
- communication while working;
- maintaining overview/context while one area is magnified.

Do not assume that maximum information exposure is always beneficial. More visible content may also increase search burden or distraction.

### 3. Ergonomics

Questions:

- How much head/neck movement is required?
- What viewing distances are comfortable and visually effective?
- Are repeated vertical gaze shifts between the upper Doxa row and the laptop tiring?
- Do inward-angled side panels reduce useful head movement or increase visual clutter?
- Which screen positions can be used for long periods without awkward posture?

Low-vision users may deliberately use shorter viewing distances than conventional workstation guidance, so ergonomics must be tested together with visual access rather than applying mainstream monitor-placement rules rigidly.

## Personalization is a moderator, not a fourth goal

Individual differences are expected and should shape the balance among the three outcomes.

Relevant variables include:

- preferred magnification;
- preferred viewing distance;
- central/peripheral visual-field characteristics;
- sensitivity to clutter and motion;
- contrast/brightness preference;
- mouse-heavy vs keyboard-heavy work;
- habitual magnifier strategy;
- willingness/ability to turn the head between displays;
- existing multi-monitor habits.

Research evidence already shows substantial individual differences in magnification modality and viewing configuration among people with low vision. Therefore the aim should be a small set of good defaults plus flexibility, not one universal layout.

## Screen count is an experimental variable

Do not assume that all four available screens should be used.

Candidate physical configurations to test:

### Two-screen mode

Useful as current Visual test bed and possibly as a real Doxa accessibility mode.

- one active/magnified surface;
- one stable context/reference surface.

### Three-screen upper-row mode

Use the three aligned Doxa panels while leaving the laptop visually secondary, closed if hardware permits, or used only for input/control.

Hypothesis:

The aligned upper row may provide a more coherent horizontal visual workspace and reduce vertical gaze switching.

### Four-screen mode

Use upper-left, upper-centre, upper-right plus laptop.

Hypothesis:

The laptop may add valuable close-detail, control or communication space, but may also increase vertical gaze movement and visual complexity.

### Reduced-field / simplified mode

Use only one or two active information surfaces even though more displays are physically available.

Hypothesis:

For some users, fewer active screens may improve orientation and reduce search load.

## Dynamic versus stable information is another experimental variable

One important hypothesis remains:

> Only one screen should normally move/follow pointer/caret automatically; other screens should remain spatially stable.

This is not yet a product rule. It should be compared against alternatives because stable context may be one of the main ways Doxa can compensate for the context loss caused by magnification.

## Initial research hypotheses

### H1 Ã¢â‚¬â€ Magnification + stable context improves task performance

A dedicated magnified Detail view plus a stable context/reference view may reduce panning, zoom changes and loss of orientation compared with one magnified screen alone.

### H2 Ã¢â‚¬â€ Additional screen area can improve low-vision productivity

Having source, destination and reference information simultaneously visible may improve comparison and multi-document tasks for some low-vision users.

This is currently a hypothesis, not an established low-vision result.

### H3 Ã¢â‚¬â€ More screens have diminishing or negative returns

Moving from two to three screens may help many tasks, while moving from three to four may add little benefit or increase visual/ergonomic burden for some users.

### H4 Ã¢â‚¬â€ Three aligned upper Doxa screens may be sufficient

The three-screen upper row may provide most of the productivity benefit while avoiding repeated vertical transitions to the laptop.

### H5 Ã¢â‚¬â€ Laptop may still be valuable as close Detail

Because some people with low vision prefer short viewing distances, the physically closer laptop screen may be useful for high-magnification reading even if the upper row is more ergonomically coherent.

### H6 Ã¢â‚¬â€ Individual preference will dominate some layout choices

There may be no single optimal Doxa layout. The product may need a small number of workflow/layout presets plus easy adjustment.

## Current concrete Doxa concept

**Working:** the leading concrete arrangement to discuss with assessors and later prototype is documented in `doxa_dual_workspace_shared_detail_concept.md`:

- left external screen = stable Workspace A;
- centre external screen = one shared magnified Detail surface;
- right external screen = stable Workspace B;
- laptop = simple workspace organiser/control surface;
- centre Detail follows intentional activity between the two side workspaces using pointer/text-cursor/focus evidence rather than raw screen crossing alone.

This is a concept to validate, not a replacement for the broader screen-count experiments below. Current two-screen Visual should not be expanded speculatively to implement it before assessor feedback and physical Doxa availability.
## Research tasks before Doxa hardware arrives

### Engineering

Continue the two-monitor Visual POC:

- fix real mouse/caret handoff lag found in human task-use;
- stabilize capture/tracking;
- tune magnification/viewport behavior;
- validate another application family;
- keep feature scope narrow.

### Domain research

Focus on questions that can change Doxa design:

1. How do people with low vision currently arrange multiple displays?
2. Which work tasks suffer most from loss of context under magnification?
3. When does simultaneous information improve performance versus create clutter?
4. How do viewing distance and display size affect preferred workspace arrangement?
5. What ergonomic problems arise from large multi-monitor fields for low-vision users?
6. Which preferences are stable personal preferences versus task-dependent choices?

Prefer empirical low-vision studies, rehabilitation/ergonomics literature and direct user accounts over generic accessibility feature lists.

## Experiments once Doxa arrives

Use the same representative tasks under different physical configurations.

### Physical configurations

- 2 screens;
- 3 aligned Doxa screens;
- all 4 screens;
- side panels flat vs inward angled;
- laptop close-detail vs laptop secondary/off.

### Representative workflows

- reading/writing;
- comparison/data entry;
- research/reference;
- spreadsheet/tabular work;
- communication + primary work.

### Measurements

Magnification/access:

- target acquisition failures;
- lost pointer/caret/focus events;
- zoom/pan adjustments;
- orientation loss.

Productivity:

- completion time;
- errors;
- number of task/application switches;
- comparison/reference actions;
- subjective efficiency.

Ergonomics:

- head turns / vertical gaze transitions;
- preferred viewing distance;
- discomfort/fatigue;
- subjective visual load.

Preference:

- preferred configuration;
- reasons for preference;
- whether preference changes by task.

## Current product position

Do not optimize for four screens simply because Doxa provides four screens.

The value proposition to test is:

> Doxa + Visual can combine strong magnification with spatially persistent information so that people with low vision can work with more context and less navigation cost, while keeping the physical workspace comfortable and configurable to individual needs.

That is a hypothesis to validate, not a claim to market yet.
