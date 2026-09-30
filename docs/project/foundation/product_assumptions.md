# Product assumptions

## Product thesis

**Established:** Visual is a Windows low-vision magnification/accessibility product associated with Doxa, but the software architecture should remain useful on ordinary Windows multi-monitor systems rather than being technically locked to Doxa hardware.

**Established:** Visual should not attempt to clone ZoomText or SuperNova feature-for-feature. The initial value thesis is narrower: use multiple physical displays to preserve context while providing reliable detail, finding and task-state behavior.

## Representative Doxa topology

**Established:** the representative Doxa setup is:

- laptop built-in display;
- three external Doxa displays;
- four active Windows screens in total.

Two-screen setups remain valid for capability spikes because the major architectural discontinuity is one display -> multiple independent displays. Two -> three -> four should be scaling/topology work if the abstractions are correct.

The representative four-screen topology must influence interfaces and tests, but individual spikes should stay as small as possible.

## Capability-first development

**Established:** build and validate important mechanisms separately before integrating them into the product application.

Examples:

- capture/render;
- pointer tracking;
- caret tracking;
- keyboard-focus tracking;
- coordinate translation;
- monitor identity/roles;
- inspect-and-return;
- frozen/reference view;
- workspace restoration;
- topology/hot-plug recovery;
- visual enhancements.

A spike should answer whether one behavior can be made reliable enough on Windows. Integration comes after the individual mechanisms are understood.

## Early product value

**Working, strongly supported by research:** the strongest early Visual proposition is:

**independent monitor state + persistent overview/detail + fast temporary enlargement + reliable pointer/focus finding + simple monitor roles/workspace recall.**

The value is not merely higher zoom. It is reducing disorientation and preserving context while the user works.

## Four-screen behavior

**Working:** four displays should not become four continuously moving magnified surfaces. A credible default product model is stable physical roles with one highly dynamic Detail surface and more stable supporting surfaces.

Potential roles include:

- Work;
- Detail;
- Context/Reference;
- Communication/Control.

Roles are logical and configurable; they must not be hard-wired to physical monitor numbers. The laptop screen may be a poor reading surface for some users and should not be assumed to be the primary Work display.

## Adoption and contextual assistance

**Working:** current user-facing terminology and assistance decisions are consolidated in `vision_adoption_and_contextual_assistance_spec.md`. The intended order is familiarity first, deterministic contextual help second, optional user-invoked Ask Visual third. AI should not compensate for unnecessarily unfamiliar UI.

## Doxa-specific workspace concept

**Working:** the leading concrete Doxa-specific concept is two stable external workspaces (left/right) feeding one shared magnified centre Detail view, with the laptop used primarily as a simple workspace organiser. This is documented in `doxa_dual_workspace_shared_detail_concept.md`.

**Established development constraint:** current Visual remains the two-screen main line. Doxa-specific implementation should begin only after assessor feedback and physical hardware availability, and should inherit the then-current Visual core rather than becoming a permanently divergent codebase.
## Multi-monitor state

**Established:** magnification, visual effects, source assignment, follow policy and frozen/live state should eventually be independently representable per view/display. A single global magnifier state is not a sufficient long-term model.

## Accessibility behavior

**Established:** pointer visibility, pointer following, caret visibility, caret following, keyboard-focus highlighting and keyboard-focus following are distinct user needs. Do not collapse them into one automatic tracking switch.

**Working:** automatic viewport movement is necessary for some workflows but can itself cause disorientation. Physical overview/detail separation should be used to reduce unnecessary motion where possible.

## Product complexity

**Established:** optimize for measurable behavior and reliability, not feature-count parity.

Do not add mature-product configuration complexity until a user problem and technical mechanism are demonstrated. Prefer a small number of understandable behaviors over reproducing every historical magnifier mode.

## Hardware relationship

**Unresolved:** exact Doxa electronics, USB display controller family, firmware update path, audio implementation, power-delivery implementation and factory software process are not yet verified in this repository.

The user has indicated that Doxa uses USB-C power/data and HDMI and may use Silicon Motion display technology. Treat that as a lead to investigate, not as a confirmed bill of materials.

Hardware-specific conclusions belong in `docs/project/hardware/` and must be tied to device IDs, vendor documentation, physical inspection or manufacturer information.

## Commercial/deployment direction

**Established:** normal Visual functionality and Doxa installation must not depend on a cloud LLM being available.

**Working:** a cloud-assisted support layer could materially improve installation and troubleshooting if it reasons over structured diagnostics and proposes bounded actions for user approval.

The deterministic installer/diagnostic system remains authoritative for privileged actions.
