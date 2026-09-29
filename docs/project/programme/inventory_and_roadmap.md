# Visual / Doxa programme inventory and roadmap

**Snapshot:** 2026-09-29
**Repository:** `C:\dev\Visual`
**Current public application line:** Visual `0.1.0-alpha.11`
**Repository HEAD at inventory start:** `f8e53d4` (`visual: switch Ask Visual to NVIDIA Nemotron`)

## 1. Programme definition

Visual is one product/software line. “Vision” is not a separate product name; prior uses of that word were conversational confusion.

The programme has two closely related but separable concerns:

1. **Installation / lifecycle / Doxa hardware enablement** - installation, update, first-run setup, health checks, hardware/driver/firmware state and supportability.
2. **Visual low-vision software** - capture, magnification, tracking, viewport behaviour, monitor roles, visual enhancements, workspace behaviour and contextual assistance.

The separation is intentional. Velopack/lifecycle code should remain responsible for packaging and updates; Doxa setup should own deterministic hardware checks/remediation; the Visual renderer should not become a driver installer or hardware-management framework.

## 2. Current inventory

| Area | State | What exists now | Main evidence / remaining gap |
|---|---|---|---|
| Application/installer separation | **Implemented** | Velopack entry/lifecycle is separate from the Visual product main path; first-run setup and graphics health are distinct concerns. | `app/src/velopack_entry.cpp`, `app/packaging/README.md`, `docs/project/hardware/installation_and_support_architecture.md`. Real Doxa hardware adapter remains separate work. |
| Public packaging and updates | **Implemented** | Branded public Velopack alpha, Setup/full/delta/feed, release workflow, provenance/SBOM, update-check/apply, enterprise MSI path. | Public alpha.11 line; `app/packaging/`. Automatic user-facing update UX is still limited; code signing is absent. |
| Doxa setup / health planner | **Partial** | Deterministic surrogate setup, first-launch graphics health, topology/state checking, bounded actions and diagnostics exist. | `app/packaging/doxa-setup/`, graphics health path, hardware architecture docs. Hardware-specific controller/driver/firmware adapter is not implemented. |
| Core capture/render | **Implemented** | WGC capture, cached source texture, D3D11 crop/scale/present, steady interaction/render cadence, safe shutdown on topology invalidation. | `app/src/`, app README, physical dual-monitor evidence. Must be re-qualified on SM768 and later SM770. |
| Pointer / caret / keyboard-focus tracking | **Partial / strong** | Independent pointer, text-caret and keyboard-focus evidence; arbitration; UIA + Win32 fallbacks; highlight controls. | Current app and tests. Reliable Chromium/Edge editing-caret behaviour remains an explicit open compatibility area. |
| Viewport behaviour | **Implemented, tuning open** | Hold/comfort region, minimum pan, jump classification, bounds, negative coordinates, stale-evidence handling, exact return. | Core tests and app README. Human low-vision tuning of margins/jump behaviour still required. |
| Two-screen Context + Detail product | **Implemented alpha** | Context at 1x, magnified Detail, View Locator/shading, 1x/return, zoom 1/1.5/2/3/4x, settings, persistence, tracking controls, colour/contrast modes, single-instance behaviour. | `app/README.md`; public alpha.11. Usability/compatibility qualification is incomplete. |
| Screen roles | **Implemented for current model** | Persisted Context, Detail and optional Reference role assignment by display device name; changes restart-bound. | `app/README.md`. Doxa-specific identity/presets require real hardware. |
| Reference | **Partial** | Optional Reference display role exists as an ordinary Windows display. | It is deliberately **not** ZoomText Freeze View or SuperNova Hooked Areas; no fixed/frozen captured reference capability yet. |
| Visual enhancements | **Implemented alpha** | Normal, Increase Contrast, Inverted Colours, Grayscale; pointer/caret/focus highlights; View Locator. | Current settings/app implementation. More extensive enhancement choices remain a product/research question. |
| Contextual help / Ask Visual | **Implemented alpha** | Local deterministic help + provider-neutral Doxa cloud fallback; current primary backend NVIDIA Nemotron; curated product/implementation grounding; minimal state allowlist; one-shot Q&A. | `app/README.md`, `support/doxa-cloud/`. Shared embedded alpha client credential is not final per-device auth. |
| Automated tests / diagnostics | **Implemented foundation** | Current CMake defines 9 CTests; numerous deterministic/physical smoke scripts and structured diagnostics exist; release gates are established. | `app/CMakeLists.txt`, smoke scripts, `app/packaging/`. Hardware-specific regression suites still need real Doxa. |
| Single-instance / global hotkeys | **Implemented** | Second normal Visual launch exits instead of creating duplicate overlays; global hotkey registration is checked; health-check does not compete for hotkeys. | alpha.11 release and tests. |
| Code signing | **Not implemented** | Current alpha artifacts are unsigned. | `app/packaging/README.md`; SmartScreen/unknown-publisher warnings remain expected. |
| SM768 Doxa integration | **Hardware-dependent / next qualification target** | No SM768-specific product adapter is currently in the renderer. Existing architecture allows hardware observations to be injected without changing core magnification. | Physical older Doxa/SM768 required for IDs, driver/firmware baseline, topology and performance evidence. |
| SM770 Doxa integration | **Hardware-dependent / production qualification** | Current hardware docs assumed SM770 as the future production target, but no SM770-specific adapter is implemented. | Final production unit required after SM768 work to qualify differences and lock production baseline. |
| Four-screen Doxa workspace | **Designed / not implemented** | Leading concept: laptop organiser + Left stable workspace + Centre shared Detail + Right stable workspace, with intentional Detail ownership switching and View Locator. | `docs/project/foundation/doxa_dual_workspace_shared_detail_concept.md`. Requires product/user validation and Doxa hardware before becoming a default. |
| Broader ZoomText/SuperNova alternative | **Research programme, not yet a build commitment** | Existing work documents incumbent terminology/workflows and selected behaviours; Visual already borrows familiar concepts independently. | A separate commercial/feature/technical research programme is required before deciding product scope, editions, speech/reading requirements or parity goals. |
| Commercial opportunity | **Research not started as a programme** | UK presence through Standivarius is a potential launch advantage, but no canonical market/margin/channel model exists yet. | Requires market sizing, pricing, reseller/channel economics, competitor positioning and support-cost research. |
## 3. Important corrections to older documentation

The repository contains valuable earlier status documents, but they must not be treated as the current inventory without reconciliation:

- `foundation/two_screen_mvp_status.md` is dated 2026-09-23 and still describes 4/4 CTests and launch/distribution as unfinished. The current tree defines 9 CTests and has a proven public Velopack release/update path.
- `foundation/feature_roadmap.md` contains several statements written before current Settings, role persistence, View Locator, contextual assistance and public release work were implemented.
- `hardware/installation_and_support_architecture.md` says the next real adapter begins when an SM770 unit arrives. The near-term decision is now to qualify the available older **SM768 Doxa first**, while retaining SM770 as final production qualification.
- Several older docs still mention Dify/Muse as the active cloud model. The current hosted Ask Visual primary is NVIDIA Nemotron with Dify/Muse retained as fallback.
- Some older foundation files contain encoding artifacts; these are documentation hygiene issues, not product behaviour.

These files should be refreshed selectively rather than deleted; their historical reasoning remains useful.

## 4. Hardware strategy: SM768 first, SM770 later

### SM768 role

Treat the spare SM768-based Doxa as a **functional integration and development platform** for:

- installer/hardware detection development;
- driver and device enumeration;
- real Doxa display topology discovery;
- WGC/D3D capture-and-present qualification;
- sustained latency/smoothness testing;
- Context/Detail and tracking validation on Doxa;
- diagnostics/support-data design;
- early Doxa workspace prototypes where the physical topology permits.

SM768 evidence is valid for application behaviour and the older hardware generation. It is not final evidence for SM770 performance, driver packaging or production support.

### SM770 role

Use the SM770 generation later for **production qualification**:

- exact controller/device identity;
- signed production driver/firmware baseline;
- final topology and display capability;
- performance/latency/refresh acceptance;
- installer support matrix;
- regression against SM768 assumptions;
- final support and recovery procedures.

The application core should not fork into SM768 and SM770 editions. Hardware differences belong behind a small hardware/setup adapter and baseline manifest.

## 5. What can proceed before SM768 is available

A substantial amount of useful work is independent of the physical Doxa unit.

### 5.1 Visual two-screen hardening

Proceed now:

- close or bound Chromium/Edge caret compatibility;
- decide source-to-Detail pointer-boundary behaviour;
- run/tune viewport and locator usability tests;
- run Context+Detail productivity comparisons;
- improve failure/recovery UX and support diagnostics;
- expand deterministic regression coverage around real user workflows;
- improve accessibility of settings/help surfaces where evidence finds gaps.

### 5.2 Installer/lifecycle preparation

Proceed now:

- define a hardware-adapter interface/state model independent of SM768/SM770;
- define the production baseline-manifest schema for controller IDs, display expectations, driver/firmware versions and health codes;
- separate machine-level checks from interactive graphics health explicitly;
- define idempotent driver/firmware action contracts without shipping unverified packages;
- add support-bundle/export design;
- add Authenticode/Artifact Signing plan and release gate;
- keep application update policy separate from hardware driver/firmware maintenance.

Do **not** hard-code guessed SM768/SM770 IDs or driver versions before hardware/vendor evidence exists.

### 5.3 Four-screen Doxa preparation

Proceed before hardware only at architecture/simulation level:

- formalise the source-workspace / shared-Detail state model;
- define Detail ownership arbitration and hysteresis independent of physical monitor numbers;
- define logical roles for Left Workspace, Detail, Right Workspace and Organiser;
- define window/work-item assignment model for the laptop organiser;
- create unit-testable topology/state transitions;
- prototype behind a feature flag or simulator if useful.

Do not make speculative four-screen behaviour the default Visual product before physical/user validation.

### 5.4 Competitive/commercial research

This is entirely independent of SM768 and can begin whenever prioritised:

- market size and segments;
- UK channel/reseller opportunity and Standivarius launch advantage;
- ZoomText and SuperNova pricing/licensing/support models;
- reseller/distributor economics and likely gross-margin stack;
- feature/edition matrix;
- documented and observed workflows;
- technical feasibility/cost of independently implementing high-value behaviours;
- where Visual/Doxa has a differentiated multi-screen advantage;
- whether a low-cost standalone Visual product should remain magnification-first or expand toward speech/reader functionality.

This is a research stream, not permission to copy proprietary implementation or assets.
## 6. Work that specifically waits for SM768

The first physical SM768 session should be a **qualification sprint**, not ad-hoc feature work.

Required evidence:

1. enumerate USB/PnP/display adapters and stable identifiers;
2. capture installed Silicon Motion driver versions/provider/signing state;
3. map physical Doxa screens to Windows display identities and EDID/display paths;
4. record resolution/refresh/DPI/topology;
5. run the existing interactive graphics health path;
6. run sustained capture/render telemetry and tracking smokes;
7. test display disconnect/reconnect, reboot and first-run setup;
8. identify what installer actions are actually required versus already handled by Windows/vendor setup;
9. implement the smallest real `DoxaHardwareAdapter`/state provider using observed facts;
10. package and repeat from a clean/reproducible machine state where practical.

Only after this should the installer claim SM768 hardware support.

## 7. Work that specifically waits for SM770

SM770 is the final production qualification gate for hardware-specific claims:

- repeat hardware discovery and baseline capture;
- compare SM768/SM770 device and driver model;
- extend the same adapter rather than fork it;
- prove display topology/capture/render performance;
- lock production driver/firmware requirements;
- validate installer/update/support behaviour;
- execute final regression on the intended production physical configuration.

## 8. Roadmap

### Phase P0 - Programme reset and source of truth

**Goal:** eliminate ambiguity about current versus planned work.

Exit criteria:

- this inventory accepted;
- tracker-neutral work breakdown accepted;
- stale high-level status docs identified for refresh;
- tracker selected and linked back to repository IDs.

### Phase P1 - Pre-SM768 software hardening

**Goal:** make the two-screen Visual baseline strong enough that SM768 testing isolates hardware issues rather than basic app defects.

Exit criteria:

- browser-caret position is supported or explicitly bounded/documented;
- pointer-boundary policy decided and tested;
- core two-screen acceptance suite defined and passing;
- major View Locator/viewport usability findings resolved or documented;
- current installer/release path remains green;
- code-signing implementation path decided.

### Phase P2 - Installer/hardware adapter readiness

**Goal:** arrive at SM768 with a deterministic place to put real hardware facts.

Exit criteria:

- hardware state schema/adapter seam exists;
- baseline manifest schema exists;
- machine checks vs interactive graphics health are separated;
- driver/firmware action interfaces are deterministic and testable with fake data;
- no guessed production hardware values are embedded.

### Phase P3 - SM768 qualification and first Doxa integration

**Goal:** turn the older Doxa into the main physical Visual development bench.

Exit criteria:

- SM768 hardware/driver/display baseline documented;
- real hardware adapter implemented for observed SM768 state;
- installer/setup correctly identifies and validates the unit;
- Visual two-screen behaviour qualified on relevant SM768-connected displays;
- performance/support baseline captured;
- known SM768 limitations separated from generic Visual defects.

### Phase P4 - Doxa four-screen prototype

**Goal:** test the Ben/Oliver concept as a product hypothesis, not merely as a diagram.

Exit criteria:

- logical workspace roles implemented behind an experimental mode;
- one shared Detail can intentionally follow Left/Right workspaces;
- source workspace shows the exact View Locator region shown on Detail;
- switching policy is measurable and not twitchy;
- organiser prototype can assign/recall work items if retained;
- BCS/assessor/low-vision testing decides what to keep, change or drop.

Physical implementation timing depends on the actual available Doxa topology; architecture/simulation can precede it.

### Phase P5 - SM770 production qualification

**Goal:** convert successful SM768/Doxa learning into the production hardware line.

Exit criteria:

- SM770 adapter/baseline qualified;
- production performance targets pass;
- signed driver/firmware/install path is final;
- update/recovery/support procedures pass;
- no hidden SM768-only assumptions remain.

### Phase P6 - Broader Visual commercial decision

**Goal:** decide whether to develop Visual as a lower-cost standalone competitor/alternative in the ZoomText/SuperNova market.

Inputs required before a build commitment:

- commercial market/channel research;
- competitor feature and edition matrix;
- pricing/margin/support economics;
- technical effort and maintenance estimate for high-value feature groups;
- evidence of underserved customer needs;
- explicit product positioning and target price/support model.

Possible outcome is a magnification-focused product, a broader reader/magnifier product, or a decision not to pursue the standalone market. Do not assume the answer in advance.

## 9. Cross-cutting acceptance principles

Every stream should preserve these rules:

- observable behaviour and measured task outcomes beat feature-count parity;
- current implementation/test evidence beats stale planning text;
- no proprietary competitor source/assets/confidential details;
- no hardware fact is guessed when physical/vendor evidence can settle it;
- Visual core remains hardware-agnostic where practical;
- Doxa-specific behaviour should be a layer over shared Visual foundations, not a permanent fork;
- AI/cloud assistance remains optional/noncritical and does not own deterministic installation or magnification behaviour;
- accessibility, recovery and supportability are product features, not cleanup work.

## 10. Decisions that need owner input later

These should not block the inventory itself:

1. tracker choice (GitHub Projects vs Linear vs another system);
2. whether the four-screen prototype begins as soon as the state model/simulator is ready or waits for SM768;
3. code-signing provider/budget;
4. whether automatic in-app update UX should be productised or updates remain explicit/IT-managed;
5. when to start the standalone ZoomText/SuperNova commercial research stream;
6. after research, whether speech/reader functionality belongs in Visual or remains outside its product boundary.
