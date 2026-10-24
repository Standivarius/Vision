# Vision Master Handover v1.0

**Date:** 2026-09-29  
**Purpose:** single reconciled handover for the new Vision development chat. It merges the historical development intelligence from the previous long-running Vision/Visual development chat with the post-migration infrastructure and repository context established in the newer infrastructure chat.

---

## 0. Authority and source hierarchy

Use this order when facts conflict:

1. **Live repository and tests** at `C:\dev\Vision`
2. Current `AGENTS.md`, `STATUS.md`, programme docs, packaging/update docs, and current Git/GitHub state
3. This master handover
4. The archived previous development conversation
5. Older dated artifacts

The previous development chat lost live repo access when its ngrok bridge went offline. Its value is therefore **historical reasoning and previously verified development knowledge**, not post-migration truth.

The infrastructure chat did have live access to the renamed repo and verified the current project binding, path migration, worktree repair, build/test state, and tooling cutover described below.

---

## 1. Canonical identity

The only correct current project/product name is **Vision**.

Canonical state:

- host: `MARIUS-DELL`
- repo: `C:\dev\Vision`
- branch: `master`
- GitHub repo: `Standivarius/Vision`
- GitHub Project: **Vision**, Project #6
- Dell project-MCP key: `vision`
- normal local-development plugin: **Local Project Dev – Dell**

The former name **Visual** is legacy. It may remain only where it is:

- historical evidence;
- an intentional internal implementation identifier;
- or a compatibility-sensitive install/update/config/schema contract.

Do **not** globally replace `Visual`, `visual`, `VISUAL_*`, or `Standivarius.Visual`.

---

## 2. New-chat operating model

For substantive local work, use:

```text
project_start("vision")
```

Normal execution path:

```text
Vision ChatGPT Project
    -> Local Project Dev – Dell
    -> C:\dev\Vision
```

Supporting layers:

- **GitHub** = remote repository, issues, releases and GitHub Project execution view
- **Remote Desktop Commander** = break-glass recovery/host-admin only
- old Custom-GPT/ngrok bridge = legacy rollback/history, not the canonical route

The new development chat should treat infrastructure as **settled** unless explicitly asked to work on it.

Do not spend opening turns repairing ngrok, rebuilding plugin infrastructure, or changing host topology.

Do not invoke external AI agents unless explicitly authorised.

---

## 3. Infrastructure cutover completed

The broader migration moved development away from a bespoke Custom-GPT/ngrok model toward a project-aware local MCP/plugin model.

### Local Project Dev – Dell

Installation:

```text
C:\mcp\project-dev
```

Registry:

```text
C:\mcp\project-dev\projects.json
```

Current binding:

```text
vision -> C:\dev\Vision -> read_write
```

The MCP provides:

- project-root validation;
- project-scoped PowerShell/process execution;
- structured Git status;
- `project_start`;
- `project_status`;
- limited host maintenance (`list_projects`, `system_info`, `reload_registry`).

It intentionally cannot restart its own tunnel.

### Startup

Local Project Dev has a Windows Startup shortcut launching:

```text
C:\mcp\project-dev\run-silent.vbs
```

### Remote Desktop Commander

RDC is paired to:

- `Marius-DELL`
- `ASUS-DESKTOP-HOME`

Dell RDC has a durable at-logon scheduled task:

```text
RemoteDesktopCommander-Dell
```

with neutral working directory:

```text
C:\mcp\rdc
```

Use RDC only when the primary project MCP is unavailable or cannot perform the required host-level operation.

### Legacy ngrok bridge

The old Custom-GPT/ngrok bridge was not deleted.

Its autostart shortcut was disabled and preserved at:

```text
C:\mcp\legacy-startup-disabled\Restart Visual Bridge.lnk
```

Do not restore it merely because it exists, and do not delete it merely for cleanup.

---

## 4. Visual -> Vision migration already completed

### GitHub / project identity

```text
Standivarius/Visual -> Standivarius/Vision
GitHub Project "Visual" -> "Vision"
```

The GitHub Project is Project #6.

### Local repo

```text
C:\dev\Visual -> C:\dev\Vision
```

### MCP key

```text
visual -> vision
```

### Persisted PATH

Dell user-PATH references to the old repo root were corrected.

Final audit:

```text
old C:\dev\Visual... entries: 0
corresponding C:\dev\Vision... entries: 2
```

### Worktrees

The parent-folder rename broke administrative pointers for:

- `artifacts\_work_alpha6_muse`
- `artifacts\_work_alpha6_muse_auditfix`
- `artifacts\_work_alpha7_candidate`

They were repaired with Git's worktree-repair mechanism.

Preservation verification:

```text
Git-status entries before move: 635
Git-status entries after repair: 635
PRESERVATION_MATCH
```

No dirty/uncommitted work was intentionally discarded.

---

## 5. Dirty-tree rule

The repo was substantially dirty before this migration.

That dirty tree is **working context**, not migration debris.

At final infrastructure verification:

- branch: `master`
- staged changes: `0`
- MCP health: `healthy`
- canonical root: `C:\dev\Vision`

Before broad modifications:

1. inspect actual Git state;
2. identify files already modified;
3. preserve unrelated edits;
4. keep staging explicit;
5. avoid destructive cleanup or bulk restore against unknown work.

Rename-related delete/new pairs may be intentional until inspected.

---

## 6. User-facing and project-facing Vision naming already done

A controlled branding pass changed active user-facing/project-facing references to **Vision**.

Examples:

- Vision Settings
- Vision Help / Ask Vision
- Ask Vision
- Vision Setup
- Vision hint
- Vision Detail View indicator
- visible setup/error/help wording
- Windows resource description using Vision

Relevant source files touched include:

- `app/app.manifest`
- `app/src/assistant_client.cpp`
- `app/src/assistant_client.h`
- `app/src/context_overlay.cpp`
- `app/src/core/help_catalog.h`
- `app/src/help_window.cpp`
- `app/src/hint_window.cpp`
- `app/src/main.cpp`
- `app/src/settings_store.cpp`
- `app/src/settings_window.cpp`
- `app/src/setup_orchestrator.cpp`
- `app/src/velopack_entry.cpp`
- `app/src/version.rc.in`

Current operational docs/path references were also updated, including parts of:

- `AGENTS.md`
- root `README.md`
- `STATUS.md`
- `.github/workflows/release-alpha.yml`
- `docs/project/development_operating_model.md`
- programme docs
- packaging/release docs
- `scripts/handoff-to-doxa.ps1`
- GitHub update-source references

`AGENTS.md` now establishes the policy: use Vision for new project/product/repository references, while deliberate compatibility/internal/historical `Visual` identifiers may remain.

---

## 7. Project/support paths already renamed

Already migrated:

```text
scripts/start-visual-bridge.ps1
    -> scripts/start-vision-bridge.ps1

scripts/start-visual-tunnel.ps1
    -> scripts/start-vision-tunnel.ps1

scripts/watch-visual-bridge.ps1
    -> scripts/watch-vision-bridge.ps1

docs/project/foundation/visual_adoption_and_contextual_assistance_spec.md
    -> docs/project/foundation/vision_adoption_and_contextual_assistance_spec.md

support/dify/visual-support-knowledge.md
    -> support/dify/vision-support-knowledge.md

support/knowledge/visual
    -> support/knowledge/vision

support/doxa-cloud/visual-assistant-knowledge
    -> support/doxa-cloud/vision-assistant-knowledge

support/doxa-cloud/visual-assistant-worker
    -> support/doxa-cloud/vision-assistant-worker
```

Active path references were updated.

Final audit:

```text
OLD_PATH_TOKEN_HITS 0
```

The Git index was deliberately returned to **0 staged changes** after the moves.

Generated support outputs were rebuilt:

- Dify source: `support/knowledge/vision`
- Dify bundle: `support/dify/vision-support-knowledge.md`
- Ask Vision knowledge: `support/doxa-cloud/vision-assistant-knowledge`
- generated worker: `support/doxa-cloud/vision-assistant-worker`

Latest generation check during the migration:

- 25 mirrored files
- 107 chunks
- `Vision assistant source mirror OK`

Do not hand-edit generated mirror/worker outputs when their generator is authoritative.

---

## 8. Build checkpoint after the repo move

The old CMake cache still embedded `C:\dev\Visual`, so it could not be reused.

The old build tree was preserved at:

```text
C:\mcp\project-dev\vision-build-pre-rename-20260929
```

A fresh build under `C:\dev\Vision` then passed:

- Release build: **PASS**
- native CTest suite: **9/9 PASS**
- Ask Vision source-mirror consistency: **PASS**

Other safety copies retained outside the repo:

```text
C:\mcp\project-dev\vision-rename-backup-20260929
C:\mcp\project-dev\vision-brand-backup-20260929
C:\mcp\project-dev\vision-build-pre-rename-20260929
C:\mcp\project-dev\projects.pre-vision-rename.json
C:\mcp\project-dev\server.pre-structured-status-20260929.py
```

Do not delete these yet.

---

# DEVELOPMENT INTELLIGENCE FROM THE PREVIOUS CHAT

## 9. Product thesis

Vision is a Windows low-vision magnification product associated with Doxa / Standivarius.

The product thesis is broader than “magnify the screen”:

1. build a reliable, high-performance Windows-native low-vision magnifier;
2. reduce navigation/orientation cost through intelligent multi-monitor use;
3. use Doxa as a differentiated hardware environment for low-vision workflows;
4. gradually evolve the current two-screen product toward a broader low-vision offering, informed by ZoomText, SuperNova, Windows Magnifier and other relevant products;
5. separately research whether Doxa has valuable software-led use cases beyond low vision.

Repeated engineering principles:

- measured behaviour beats feature-count parity;
- prefer simple Windows-native solutions;
- AI must remain optional/noncritical;
- installer/update/supportability are first-class product concerns;
- competitor behaviour may be studied legitimately, but proprietary implementation/assets must not be copied;
- hardware claims require real hardware evidence.

---

## 10. Two-screen Context + Detail model

Core semantics:

- **Context** = full 1x overview
- **Detail** = magnified working view
- optional **Reference** = ordinary independent display role

These meanings must never be reversed.

The physical monitors assigned to Context/Detail may change; role meaning does not.

User benefit: reduce the “where am I?” orientation cost of conventional single-screen magnification.

Historically verified capabilities before the migration included:

- zoom 1x, 1.5x, 2x, 3x, 4x;
- Context and Detail roles;
- optional Reference role;
- View Locator;
- pointer, text-caret and keyboard-focus tracking;
- pointer/caret/focus highlights;
- settings persistence;
- visual transforms;
- 1x/return;
- contextual help / Ask product;
- global shortcuts;
- single-instance protection;
- packaged updater/release path.

Re-verify exact current behaviour in the live tree.

---

## 11. Capture/render architecture

Historical product direction:

- Windows Graphics Capture (WGC);
- D3D11 textures;
- source-region crop;
- GPU scale/present to Detail;
- steady interaction/render cadence;
- explicit topology-change handling;
- fail-safe shutdown/restart instead of silently rendering invalid monitor state.

The renderer should remain mostly hardware-agnostic. Doxa-specific controller/driver/display knowledge belongs in setup/hardware adapters, not magnification rendering.

---

## 12. Tracking / POI arbitration

Three conceptually distinct point-of-interest sources:

1. mouse pointer;
2. text caret;
3. keyboard focus.

Each can be controlled independently.

Blindly following every event causes twitching and bad editing behaviour, so arbitration evolved around:

- source identity;
- freshness/age;
- intent/priority;
- movement significance;
- stale-evidence rejection.

Guiding principle:

> Follow the user's likely working point, not every event indiscriminately.

Chromium/Edge editing-caret reliability was still an important compatibility area before the naming cutover. Re-check current code/tests before assuming it is still open.

---

## 13. Viewport and locator reasoning

Viewport behaviour historically included:

- comfort/hold region;
- minimum movement before panning;
- normal pan vs large jump;
- source bounds;
- negative coordinates;
- stale-event handling;
- exact return.

Goal: avoid both constant micro-chasing and excessive lag.

The **View Locator** is central to orientation: Context should show the exact source region currently represented on Detail.

This later became important to the four-screen Doxa concept: whichever source workspace owns the shared Detail should display the matching View Locator.

Real low-vision usability tuning remains more important than arbitrary parameter perfection.

---

## 14. User terminology and controls

Established user-facing terminology:

- Zoom Level
- Enable Tracking
- Follow Pointer
- Follow Text Cursor
- Follow Keyboard Focus
- Pointer Locator
- Text Cursor Highlight
- Focus Highlight
- View Locator
- Colour & Contrast
- Screen Roles

Historically implemented visual modes:

- Normal
- Increase Contrast
- Inverted Colours
- Grayscale

Historically verified shortcuts:

- Ctrl+Alt+1/2/3/4 — zoom
- Ctrl+Alt+0 — 1x View / Return
- Ctrl+Alt+T — Tracking
- Ctrl+Alt+S — Settings
- Ctrl+Alt+H — Help / Ask Vision
- Ctrl+Alt+Q — exit

The product intentionally did not hijack Windows Magnifier's Win+Plus/Minus shortcuts.

---

## 15. Important solved bug: duplicate instances / hotkeys

A significant alpha bug caused overlapping instances when the app was started twice.

Symptoms included:

- duplicate Context/Detail overlays;
- darker transparency;
- slight misalignment;
- unreliable Ctrl+Alt+Q because one process did not own the hotkey.

Root cause:

- no app-wide single-instance guard;
- ignored global-hotkey registration failures.

Implemented fix:

- app-wide named mutex;
- second normal launch exits quickly;
- existing instance may be flashed/activated;
- hotkey registration must succeed or startup fails clearly;
- partial registrations roll back;
- graphics-health mode does not compete for product hotkeys;
- health-check remains exempt from the normal app mutex.

This was tested on local/public alpha.11 before the naming migration.

---

## 16. Ask Vision architecture and lessons

Product rule:

> local deterministic help first; cloud assistance second.

Historically the client sent:

- user's question;
- narrow structured Vision state;
- retrieved product/source excerpts.

It intentionally did not send arbitrary screenshots, typed text, raw monitor IDs, files or secrets.

Historical provider-neutral route:

```text
Vision client
-> Cloudflare Worker
-> NVIDIA NIM / Nemotron primary
-> Dify / Muse fallback
```

Re-verify live deployment names/URLs.

A live Nemotron migration exposed a grounding bug that reversed Context and Detail. The fix reinforced authoritative role grounding:

- Context = full 1x overview
- Detail = magnified working view

Each Ask request historically remained independent; no conversation history was sent.

Ask UX lesson from cloud latency:

- show explicit working state;
- disable input/button while working;
- show `Working...`;
- refocus/re-enable after completion;
- support Ctrl+A correctly in the edit control.

---

## 17. Installer / lifecycle architecture

Keep a strong separation between:

**Vision application**

and

**installer/update/Doxa hardware lifecycle**

Velopack owns:

- install;
- application update;
- versioning;
- uninstall.

Doxa setup/health should own:

- hardware detection;
- driver/firmware prerequisites;
- graphics health;
- deterministic remediation;
- diagnostics.

The magnifier renderer should not become a hardware-management framework.

---

## 18. Release history known by the previous development chat

Before the naming migration, the public alpha sequence included:

- 0.1.0-alpha.7
- alpha.8
- alpha.9
- alpha.10
- alpha.11

Important milestones recorded by that chat:

- alpha.8 — packaging/CI repair
- alpha.9 — release provenance fixes
- alpha.10 — Ask progress feedback + Ctrl+A
- alpha.11 — single-instance + reliable hotkeys

The last public version personally verified by the old development chat was **0.1.0-alpha.11**.

A public alpha.10 -> alpha.11 update was explicitly tested successfully.

This makes upgrade continuity central to the Visual -> Vision compatibility decision.

---

# REMAINING NAMING/COMPATIBILITY TASK

## 19. Compatibility-sensitive identifiers deliberately unresolved

The infrastructure chat intentionally stopped before globally changing identifiers that may affect released-alpha continuity.

Important families include:

- `Standivarius.Visual`
- `visual_app.exe`
- `visual_diagnostics.exe`
- CMake targets such as `visual_app`
- C++ namespace `visual::`
- `VISUAL_*` env/build/config identifiers
- `%LOCALAPPDATA%\Standivarius\Visual`
- registry/install/update state
- Start Menu/shortcut identity
- package filenames such as `Standivarius.Visual-*`
- update manifests/channels
- deployed Worker/service name `doxa-visual-assistant`
- schema markers such as `visual-source`
- generator markers such as `__VISUAL_KNOWLEDGE_BUNDLE__`
- historical release artifacts

These are **not all supposed to be renamed**.

Classify significant families as:

- **A — rename now**
- **B — retain as internal/compatibility identifier**
- **C — migrate later with explicit backwards-compatible migration**
- **D — historical**

Highest-priority success condition:

> A machine already running an old Visual alpha should ideally upgrade normally to a future Vision build, keep settings/state, remain one installed product, and uninstall/update coherently.

Do not sacrifice that continuity merely to eliminate every occurrence of the word `Visual`.

Historical provisional stance to verify live:

- `Standivarius.Visual`: likely high-risk package/update identity;
- `visual_app.exe`: may be referenced by updater, shortcuts, tests, setup or process detection;
- `%LOCALAPPDATA%\Standivarius\Visual`: may hold settings/update state;
- `doxa-visual-assistant`: deployed internal service name with little user-facing value in renaming;
- `visual::`: internal namespace, large noisy diff, little product benefit;
- `VISUAL_*`: classify individually; some may be public/developer contracts;
- schema/marker identifiers: leave alone unless there is a real migration reason.

---

## 20. Doxa hardware strategy

Do not fork the product by hardware generation.

Programme direction:

- **SM768 Doxa** = first real development/integration/functional qualification bench
- **SM770 Doxa** = later production qualification platform

Use one Vision core.

Hardware differences belong behind a small setup/hardware adapter plus qualified baseline data.

Do not guess hardware IDs, driver versions or firmware requirements before observing real hardware or vendor evidence.

---

## 21. Four-screen Doxa concept

A later concept proposed:

- laptop/organiser surface;
- left stable workspace;
- centre shared magnified Detail;
- right stable workspace.

The shared Detail would follow the active source workspace, while the source shows the matching View Locator.

This is a **designed concept, not a validated default**.

Important future questions:

- what owns Detail: pointer, caret, focus, explicit choice?
- how much hysteresis is needed?
- can Detail be locked?
- what should the organiser do?
- does it improve real task performance?
- does Doxa topology support it cleanly?

---

## 22. Broader product direction

The current two-screen Vision is not a dead-end MVP.

It should evolve incrementally toward a broader low-vision product informed by:

- ZoomText;
- SuperNova;
- Windows Magnifier;
- other relevant tools.

Research should examine user value, workflows, pricing/licensing, channel economics, support burden, feature value and maintenance cost.

The goal is **not** to clone incumbents.

The question is:

> Which capabilities create enough user and commercial value to justify adding them to Vision?

Separately, Doxa should have an opportunity-discovery research stream beyond accessibility, looking for software-led multi-monitor use cases and producing a ranked opportunity map plus testable concepts.

---

## 23. Programme / tracker direction

The Git repository/programme docs remain canonical programme truth.

GitHub Issues + GitHub Project #6 are the execution/status surface.

The previous programme package contained:

- inventory/roadmap;
- work breakdown;
- handover;
- tracker strategy.

The backlog had expanded to 49 items across:

- governance;
- two-screen Vision;
- installer/hardware;
- four-screen Doxa;
- Ask Vision;
- quality/release;
- low-vision commercial/competitive research;
- broader Doxa opportunity research.

Verify current programme files rather than assuming the historical count is still exact.

---

## 24. Testing philosophy

Keep layered validation:

1. unit/deterministic tests;
2. desktop smoke tests;
3. physical multi-monitor behaviour;
4. installer/update tests;
5. Doxa hardware-qualified regression.

The infrastructure chat verified a fresh post-move Release build and **9/9 native tests**.

The old development chat did not independently verify that post-migration state.

---

## 25. Important rejected/avoided approaches

Do not re-open these without new evidence:

- no global Visual -> Vision replacement;
- no separate SM768 and SM770 applications;
- Reference is not ZoomText Freeze View or SuperNova Hooked Areas;
- do not claim unsupported incumbent feature equivalents;
- do not hijack Windows Magnifier Win+Plus/Minus shortcuts;
- do not make AI/cloud critical to core operation;
- do not infer Doxa hardware support from Dell surrogate displays;
- do not hand-edit generated Worker/mirror files when a generator is authoritative;
- do not use feature-count parity as the main product metric.

---

## 26. Open questions to re-check live

1. Chromium/Edge editing-caret reliability.
2. Pointer movement across source/Detail/other-monitor boundaries.
3. Viewport comfort/jump tuning.
4. View Locator usability with real low-vision users.
5. Whether a true frozen/fixed reference capability is worthwhile.
6. User-facing update policy.
7. Code signing.
8. Production authentication for Ask Vision.
9. Whether Ask Vision should ever gain conversation history.
10. Exact SM768 driver/display behaviour.
11. Exact SM770 production behaviour.
12. Four-screen shared-Detail arbitration.
13. Whether the laptop organiser concept survives user testing.
14. Which broader low-vision capabilities should be added first.
15. Whether Vision remains magnification-first or expands toward speech/reader.
16. Which non-accessibility Doxa use cases are commercially attractive.

---

## 27. Immediate takeover task

Before ordinary feature work, finish the remaining Visual -> Vision compatibility assessment:

1. start `project_start("vision")`;
2. verify root/origin/branch/HEAD/dirty tree/worktrees/version/package identities;
3. read current `AGENTS.md`, `STATUS.md`, programme and packaging docs;
4. audit active `Visual` / `visual` / `VISUAL_*` / `Standivarius.Visual` uses;
5. distinguish active source/config from generated output, compatibility contracts and historical artifacts;
6. classify significant identifier families A/B/C/D;
7. analyse consequences for an already-installed old Visual alpha;
8. report the recommended compatibility boundary **before** changing sensitive identifiers;
9. implement only safe/agreed changes;
10. regenerate authoritative generated outputs;
11. rebuild/test;
12. prove update/upgrade continuity;
13. list identifiers intentionally remaining Visual;
14. save a durable naming-migration report under `artifacts/`.

Do not perform another broad search-and-replace.

---

## 28. Last state personally verified by the previous development chat

Before its repo access was lost, the old development chat personally verified:

- public alpha.11 release/update path;
- alpha.10 -> alpha.11 update;
- single-instance/hotkey fix;
- NVIDIA Nemotron primary cloud route with Dify/Muse fallback;
- privacy allowlist behaviour;
- corrected Context/Detail AI grounding;
- installed alpha working without runtime developer environment variables;
- programme docs/backlog committed before the migration cutover.

After the infrastructure chat moved/renamed the repo, that old chat did **not** regain live access.

Therefore its post-migration claims must not be treated as independently verified.

---

## 29. Post-migration state verified by the infrastructure chat

Verified on 2026-09-29:

- `project_start("vision")`: ready
- Dell project MCP: healthy
- canonical root: `C:\dev\Vision`
- branch: `master`
- origin: `https://github.com/Standivarius/Vision.git`
- GitHub repo: `Standivarius/Vision`
- GitHub Project #6: Vision
- staging state: 0 staged changes
- Local Project Dev startup: configured
- Dell RDC durable startup: configured
- old Visual/ngrok autostart: disabled but preserved
- stale persisted `C:\dev\Visual` PATH entries: 0
- repo/worktree move preservation verified
- fresh Release build passed
- 9/9 native tests passed
- Vision assistant generated-source consistency passed

---

## 30. Files supplied to the new chat

This master handover should be used together with:

### Full previous-development conversation archive

```text
artifacts\2026-09-29__VISION_PREVIOUS_DEVELOPMENT_CONVERSATION_ARCHIVE.md
```

Use it only when this handover or the live repo does not contain enough historical rationale.

### New-chat bootstrap prompt

```text
artifacts\2026-09-29__VISION_NEW_CHAT_START_PROMPT_v1.0.md
```

The bootstrap prompt tells the new chat how to initialise and what to read.

---

# Bottom line

The new Vision chat should:

- treat infrastructure as settled;
- use the live `C:\dev\Vision` repo as factual truth;
- use this master handover for reconciled development + migration context;
- use the full archived conversation only for missing historical rationale;
- finish the compatibility-sensitive Visual -> Vision migration first;
- then return to the current Vision/Doxa programme and product work.


## Long-running execution harness

On 2026-09-30 the Dell project MCP was extended with persistent background jobs so long local commands do not monopolise a ChatGPT turn. Jobs persist state/logs under `C:\mcp\project-dev\runs` and are recoverable after reconnect/restart.

Tools: `project_job_start`, `project_job_poll`, `project_job_cancel`, `project_job_list`. Prefer them for operations likely to exceed roughly 10-20 seconds. The aim is frequent control return, explicit stall detection, and resumable checkpoints rather than one opaque long-running command.
