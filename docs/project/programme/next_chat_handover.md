# Next-chat handover: Visual / Doxa programme

## User intent

The next phase is a structured programme, not an isolated feature sprint. Build against the canonical inventory and work breakdown in `docs/project/programme/`.

Terminology correction: **Visual** is the product/software name. “Vision” was accidental wording and is not a separate product.

## Start here

Read, in order:

1. `docs/project/programme/README.md`
2. `docs/project/programme/inventory_and_roadmap.md`
3. `docs/project/programme/work_breakdown.md`
4. `docs/project/programme/tracker_strategy.md`
5. `app/README.md`
6. `app/packaging/README.md`
7. `docs/project/hardware/installation_and_support_architecture.md`
8. `docs/project/foundation/doxa_dual_workspace_shared_detail_concept.md`
9. `docs/project/foundation/visual_adoption_and_contextual_assistance_spec.md`
10. relevant current implementation before making claims

## Current baseline

- Canonical repo: `C:\dev\Visual` on `MARIUS-DELL`.
- Current public line: `0.1.0-alpha.11`.
- Inventory-start HEAD: `f8e53d4` (`visual: switch Ask Visual to NVIDIA Nemotron`).
- Visual two-screen alpha is real and publicly installable/updateable.
- Current core includes Context 1x + magnified Detail, tracking, viewport, View Locator, settings/persistence, colour modes, help/Ask Visual and single-instance behaviour.
- Current CMake defines 9 CTests.
- Ask Visual primary backend is NVIDIA Nemotron through the Doxa Cloudflare Worker, with Dify/Muse fallback.
- Alpha artifacts are still unsigned.

## Hardware decision

Near-term: use the available older **SM768-based Doxa** as the first real Doxa hardware/integration bench.

Later: use **SM770** for final production qualification.

Do not fork Visual by chip generation. Put hardware differences behind the Doxa setup/hardware adapter and qualified baseline data.

## Product tracks

1. Installer/lifecycle/hardware enablement.
2. Visual two-screen low-vision product hardening.
3. Doxa four-screen workspace concept: laptop organiser + Left Workspace + Centre shared Detail + Right Workspace.
4. Ask Visual/support infrastructure.
5. Later competitive/commercial investigation of a lower-cost standalone Visual alternative to ZoomText/SuperNova.

The competitive/commercial stream is **planned research**, not a current feature-parity implementation request.

## Immediate work before SM768

Prefer work items in `work_breakdown.md`, especially:

- `GOV-001` status-doc reconciliation;
- `VIS-001` browser caret;
- `VIS-002` pointer-boundary policy;
- `VIS-005` two-screen acceptance suite;
- `INS-001` hardware adapter interface;
- `INS-002` baseline manifest schema;
- `INS-003` machine-vs-interactive health separation;
- `INS-006` code signing;
- `D4-001` and `D4-002` architecture/state model only.

Do not invent SM768 IDs/driver versions before observing the hardware.

## Once SM768 is available

Treat the first session as structured qualification:

- enumerate controller/PnP/display/driver state;
- capture exact topology/resolution/refresh/DPI;
- run graphics health + sustained Visual smokes;
- test reboot/disconnect/reconnect;
- implement the smallest real hardware adapter from observed facts;
- then validate installer and Visual behaviour.

Only after that should physical four-screen Doxa prototyping become a mainline activity.

## Repository safety

The working tree contains unrelated modified/untracked bridge/scripts/artifacts. Preserve them. Stage only files belonging to the current work item. Avoid destructive Git operations.

## Tracker status

The repository bridge has a Linear integration, but as of this handover it is disabled because `LINEAR_API_KEY` is not configured.

Do not let tracker availability block engineering. The canonical work IDs live in `docs/project/programme/work_breakdown.md`. If a tracker is configured, mirror those IDs into it and keep repository docs authoritative.

## Key design constraints

- Visual core should remain Windows-native and hardware-agnostic where practical.
- Doxa workspace behaviour should reuse the Visual core, not become a permanent fork.
- AI is optional/noncritical; deterministic setup/render/tracking must not depend on it.
- No proprietary competitor source/assets/confidential implementation details.
- Use observed behaviour and public documentation for ZoomText/SuperNova research.
- Distinguish implemented behaviour, test evidence, design hypotheses and commercial research.
