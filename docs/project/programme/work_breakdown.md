# Visual / Doxa tracker-neutral work breakdown

This file is the canonical work-item index. Stable IDs should be copied into whichever task tracker is selected so repository history and tracker history remain linkable.

## Status values

`Backlog` | `Ready` | `In progress` | `Blocked` | `Validation` | `Done` | `Deferred`

## Hardware gates

`None` | `SM768` | `SM770` | `User/assessor validation`

## Programme / governance

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| GOV-001 | Reconcile stale high-level foundation/status docs with current alpha.11 | Ready | None | Current-status claims no longer contradict current implementation/release evidence. |
| GOV-002 | Select and configure execution tracker | Ready | None | Tracker is accessible from both desktops and links each item to these stable IDs. |
| GOV-003 | Define release/feature evidence register | Backlog | None | Each product claim can point to code/test/hardware/user evidence and date. |

## Visual two-screen product

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| VIS-001 | Close/bound Chromium/Edge editing-caret support | Ready | None | Supported scenarios pass deterministic tests or limitation/fallback is explicit and accepted. |
| VIS-002 | Decide source-to-Detail pointer-boundary UX | Ready | User/assessor validation | Policy is documented, implemented and tested; Detail does not jump unexpectedly across monitors. |
| VIS-003 | Tune viewport comfort/jump policy | Ready | User/assessor validation | Parameters are supported by task-use evidence and regression tests. |
| VIS-004 | Run Context+Detail productivity comparison | Ready | User/assessor validation | Comparison evidence exists for representative tasks and informs product decisions. |
| VIS-005 | Two-screen acceptance suite | Ready | None | Repeatable acceptance script covers install/start, roles, zoom, tracking, 1x/return, locator, colour, restart, duplicate launch, exit and help. |
| VIS-006 | Review Reference/freeze requirement | Backlog | Research/User validation | Decision recorded on whether to implement a true fixed/frozen reference view and its minimum behaviour. |
| VIS-007 | Accessibility/usability pass on Settings + Help | Backlog | User/assessor validation | Keyboard/navigation/readability issues from first-use testing are addressed or documented. |

## Installer / lifecycle / hardware enablement

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| INS-001 | Define Doxa hardware state/adapter interface | Ready | None | Core setup consumes abstract observed state; renderer contains no SM768/SM770-specific logic. |
| INS-002 | Define qualified hardware baseline manifest schema | Ready | None | Schema covers hardware/revision, driver/firmware, display expectations, software version and health checks. |
| INS-003 | Separate/test machine checks vs interactive graphics health | Ready | None | Each check has a clear execution context, result code and test double. |
| INS-004 | Deterministic driver/firmware action contract | Backlog | None | Fake packages/states can exercise install/reboot/retry policy without guessed vendor facts. |
| INS-005 | Add signed support-bundle/export design | Backlog | None | Support can collect bounded logs/state without user secrets or arbitrary files. |
| INS-006 | Add Authenticode/Artifact Signing | Ready | None | Setup/MSI/binaries are signed in release pipeline and verification fails on missing/invalid signatures. |
| INS-007 | Improve user-facing update UX/policy if desired | Backlog | None | Product decision and implementation make updates discoverable without breaking IT-managed mode. |
| INS-008 | SM768 discovery and baseline capture | Blocked | SM768 | Controller/USB/PnP/driver/display/resolution/refresh/DPI evidence is recorded. |
| INS-009 | Implement real SM768 hardware adapter | Blocked | SM768 | Setup identifies observed SM768 Doxa reliably and reports qualified state. |
| INS-010 | Integrate/validate SM768 driver requirements | Blocked | SM768 | Required signed package/version/actions are known and reproducibly validated. |
| INS-011 | SM770 production requalification | Blocked | SM770 | Same adapter model supports SM770; final production baseline and regression pass. |
## Doxa workspace / four-screen product track

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| D4-001 | Formalise four-screen logical role/state model | Ready | None | Left Workspace, Detail, Right Workspace and Organiser semantics are independent of monitor numbers. |
| D4-002 | Define shared-Detail ownership arbitration | Ready | None | Explicit state machine covers focus/caret/pointer intent, hysteresis, lock and manual switching. |
| D4-003 | Create topology/state simulator + unit tests | Backlog | None | Switching/role behaviour is testable without physical four-screen hardware. |
| D4-004 | Prototype organiser/window assignment model | Backlog | None | Prototype represents windows/work items and can assign/recall Left/Right roles without becoming a window manager replacement. |
| D4-005 | Experimental four-screen rendering integration | Blocked | SM768 or suitable physical topology | Shared Detail follows selected source workspace and source View Locator matches exactly. |
| D4-006 | BCS/assessor/low-vision validation | Blocked | User/assessor validation | Evidence answers whether the concept improves task cost and which users benefit. |
| D4-007 | Decide product/default status | Blocked | D4-006 | Keep/change/drop decision is explicit; unvalidated behaviour is not made default. |

## Ask Visual / cloud assistance

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| ASK-001 | Replace shared alpha client credential with per-device/client production auth | Backlog | None | Revocable/scoped production authentication exists without provider credentials on clients. |
| ASK-002 | Decide whether conversational history is useful | Deferred | User validation | Product decision based on actual support use; privacy/context limits are defined first. |
| ASK-003 | Maintain grounded provider regression suite | Backlog | None | Key Visual/incumbent questions are automatically checked for capability hallucinations and role reversals. |

## Quality / release / support

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| QLT-001 | Consolidate smoke scripts into documented acceptance tiers | Ready | None | Unit, deterministic desktop, physical monitor and hardware-qualified suites have clear entry/exit criteria. |
| QLT-002 | Establish performance baseline schema | Backlog | None | FPS/latency/present errors/POI age and hardware identity can be compared across Dell, ASUS, SM768 and SM770. |
| QLT-003 | SM768 regression suite | Blocked | SM768 | Repeatable install/start/capture/tracking/topology/update/support test passes on qualified older Doxa. |
| QLT-004 | SM770 production regression suite | Blocked | SM770 | Final hardware passes production acceptance and compares cleanly to SM768 learning. |

## Competitive / commercial research

These items are deliberately research, not implementation commitments.

| ID | Work item | Initial status | Gate | Done when |
|---|---|---|---|---|
| RES-001 | ZoomText/SuperNova market and segment research | Backlog | None | Credible UK/global market/customer/channel picture exists with sources and uncertainty. |
| RES-002 | Competitor feature/edition/workflow matrix incl. Windows Magnifier baseline | Backlog | None | Documented + legitimately observed functionality is mapped by user value, not just feature names. |
| RES-003 | Pricing, reseller and margin-stack research | Backlog | None | Licences/subscriptions/channel economics/support obligations and likely margins are documented. |
| RES-004 | Standivarius UK launch/channel assessment | Backlog | None | Existing relationships/presence are mapped to realistic routes to market and pilot customers. |
| RES-005 | Independent technical feasibility/cost assessment | Backlog | None | High-value feature families are sized for implementation/maintenance/test/support without proprietary copying. |
| RES-006 | Product positioning/options paper | Blocked | RES-001..005 | Decision compares Doxa-only, standalone magnifier, and broader low-vision product options with economics and scope. |
| RES-007 | Go/no-go and product boundary decision | Blocked | RES-006 | Owner decision defines target customer, feature boundary, pricing hypothesis and next build phase. |

## Suggested initial execution order

1. `GOV-001`, `GOV-002`.
2. In parallel: `VIS-001`, `VIS-002`, `VIS-005`, `INS-001`, `INS-002`, `INS-003`, `INS-006`.
3. Architecture-only Doxa work: `D4-001`, `D4-002`, then `D4-003` if useful before hardware.
4. When SM768 arrives: `INS-008` -> `INS-009` -> `INS-010` plus `QLT-003`.
5. Only after SM768 baseline is stable: physical `D4-005` and `D4-006`.
6. SM770 production qualification: `INS-011`, `QLT-004`.
7. Competitive/commercial research (`RES-*`) can start independently whenever owner priority permits; do not block core engineering on it.
