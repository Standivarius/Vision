# Vision Agent Guide

## Canonical environment

- Machine: `MARIUS-DELL`
- Canonical repository: `C:\dev\Vision`
- Repository/project identity: `Vision`
- Product: **Vision**, a Windows low-vision magnification application associated with Doxa
- Naming rule from 2026-09-29 onward: use **Vision** for all new project/product/repository references. Existing `Visual` / `Standivarius.Visual` identifiers may remain only where required for compatibility with published alphas, installed state, registry paths, generated historical evidence, or other legacy artifacts until deliberately migrated.

Treat this repository as the authoritative project state. Inspect relevant files before making claims about the current implementation.

## Purpose

Vision is a Windows low-vision magnification project. The goal is a reliable, high-performance Windows magnifier with excellent tracking, viewport behaviour, coordinate correctness, multi-monitor support, and measurable accessibility behaviour.

Do not optimize for superficial feature-count parity with incumbent products. Optimize for observable usefulness, compatibility, latency, predictability, and evidence-backed engineering decisions.

## Mandatory development baseline

Before material design or implementation work:

1. read `docs/project/foundation/README.md`;
2. read `docs/project/foundation/product_assumptions.md`;
3. read `docs/project/foundation/feature_roadmap.md` when choosing, sequencing or integrating product capabilities;
4. read `docs/project/foundation/engineering_principles.md`;
5. read `docs/project/foundation/architecture_baseline.md` when touching implementation or architecture;
6. read `docs/project/foundation/implementation_precedents.md` when selecting Windows mechanisms or considering public/open-source implementation patterns;
7. read `docs/project/foundation/experimentation_and_validation.md` when creating or interpreting a spike/test;
8. read `docs/project/development_operating_model.md` when delegating work or coordinating agents;
9. inspect the current implementation before modifying it.

For Doxa hardware, firmware, drivers, installation or support work, also read `docs/project/hardware/README.md` and the relevant files in that folder.

Current synthesized conclusions in `docs/project/foundation/` take precedence over older dated research artifacts unless the task is explicitly reassessing a conclusion. Dated artifacts remain the evidence/provenance layer.

## Product topology assumption

Vision is a **generic Windows low-vision application for 2, 3 or 4 active monitors**, independent of Doxa hardware. Development may use two physical displays to prove and validate mechanisms, but reusable components must not assume exactly two monitors.

A future Doxa/SM770 system is one qualified hardware configuration for Vision, not a separate Vision architecture. Doxa-specific driver, firmware and installation logic belongs to the independent Doxa Installer workstream and must not leak into the Vision renderer/tracking core.

Broader Doxa-specific multi-monitor workspace/product concepts are currently parked. Do not make the historical four-screen Doxa layout the default Vision model unless the owner explicitly reactivates that work.
## Capability-first development

Prove important mechanisms separately before integrating them into the application.

Examples include capture/render, pointer tracking, caret tracking, keyboard-focus tracking, coordinate translation, monitor identity/roles, inspect-and-return, frozen/reference views, workspace restoration, topology recovery and visual enhancements.

Do not combine several unproven mechanisms merely to make a more app-like demo.

The broader product roadmap remains active while spikes proceed. Do not let the current spike sequence erase research-backed features such as persistent Context + Detail, independent per-view state, fast inspect-and-return, pointer/caret/focus finding, monitor roles, fixed reference, simple visual states and later presentation/share-safe workflows.

## Clean-room rule

This project may study:

- public Windows documentation and APIs;
- publicly documented competitor behaviour;
- behaviour visible through legitimate ordinary use;
- legitimately licensed open-source implementations.

Do not obtain, reproduce, decompile, or incorporate proprietary source code, proprietary assets, confidential implementation details, or other non-public competitor material.

Keep a clear distinction between:

- observed behaviour;
- public documentation;
- licensed open-source material and its provenance;
- Visual's independent design and implementation.

For any third-party source considered for reuse, record the repository/source, exact commit or tag, retrieval date, licence, relevant licence-file hash where useful, files reused, modifications, and dependency licensing.

## Evidence-first workflow

Use this sequence for material technical decisions:

`research -> hypothesis -> experiment -> evidence -> architectural decision -> production implementation`

Do not turn a plausible hypothesis into production architecture merely by naming classes, modules, or folders around it.

When uncertainty can be resolved by repository inspection or a safe test, resolve it rather than asking the user to investigate manually.

## Current technical direction

Unless experiments provide contrary evidence:

- Windows-native implementation;
- modern C++;
- Win32 and C++/WinRT;
- Direct3D 11 as the initial rendering baseline;
- CMake;
- MSVC / Visual Studio and the Windows SDK;
- PowerShell/Python or other simple test tooling where useful.

For the first cross-monitor Detail capability, **Windows Graphics Capture + D3D11 is the current leading direction with positive physical two-monitor evidence**. Spike 1 has passed the basic physical viability hurdle; remaining work is targeted at recovery, USB/cross-adapter behavior, four-display scaling and stronger user-visible timing characterization.

DXGI Desktop Duplication and other capture approaches remain alternatives to investigate if WGC evidence exposes a material limitation. Do not maintain duplicate implementations merely for symmetry.

Treat the Windows Magnification API primarily as a behavioural/reference implementation and possible fallback candidate until evidence says otherwise.

Do not introduce D3D12 unless profiling or an experiment demonstrates a concrete need.

Keep two major pipelines conceptually separate:

1. graphics: capture -> GPU texture -> scaling/image processing -> presentation;
2. intent/tracking: mouse/caret/focus/window signals -> Point-of-Interest engine -> viewport controller -> graphics pipeline.

Do not bury Point-of-Interest policy inside capture/render code.

## Early engineering priorities

Prioritize measurable behaviour in this order:

- reliable low-latency screen capture and GPU presentation;
- mouse tracking and coordinate truth;
- keyboard-focus tracking;
- text-caret tracking and compatibility;
- Point-of-Interest arbitration;
- viewport motion, dead zones, hysteresis, margins, and conflict handling;
- inspect-and-return state behavior;
- pointer/caret/focus locator overlays;
- coordinate/input correctness under magnification;
- mixed-DPI and multi-monitor behaviour;
- independent per-view state and monitor roles;
- fixed/frozen reference behavior;
- simple visual enhancements relevant to low-vision users;
- deterministic behavioural testing.

Advanced semantic text rerendering, speech, OCR runtime, broad app-specific hacks, polished settings UI, and large feature matrices are not prerequisites for proving the initial architecture.

Doxa hardware/driver/installer investigation is a parallel hardware-support workstream and should not be coupled into the magnifier runtime until the actual hardware stack is identified.

## Implementation precedents

Public/open-source implementation discoveries are part of the development baseline and are summarized in `docs/project/foundation/implementation_precedents.md`.

Important current examples include:

- Microsoft PowerToys for composite monitor identity, workspace-restoration limits and pointer utilities;
- Microsoft WGC/composition samples for Windows capture/composition reference patterns;
- Microsoft Desktop Duplication samples as a comparator/fallback if WGC exposes a real limitation;
- Microsoft Magnification API samples as behavioural/prototype references;
- HoverText as supporting evidence for layered/fallback accessibility strategies.

Use these to inform what to test and how to avoid rediscovering known Windows patterns. Do not copy architectures blindly, and do not reuse source without explicit provenance/license handling.

## Implementation rules

Before modifying existing code:

1. inspect the relevant implementation and nearby dependencies;
2. understand project conventions and the specific question being solved;
3. preserve unrelated existing work;
4. make the smallest coherent correction or addition;
5. build or test it where practical;
6. report what changed, what the evidence shows, and what remains uncertain.

Prefer simple Windows-native mechanisms over unnecessary frameworks or abstraction layers.

Do not add abstractions merely because they might be useful later.

## Multi-monitor implementation rule

Reusable code should model displays/sources/views/destinations explicitly rather than using `primary` / `secondary` architecture.

The representative product topology is four screens, but spikes should stay minimal. A two-screen spike is valid when it proves one independent source/destination relationship.

Coordinate handling must eventually support arbitrary virtual-desktop layout, negative coordinates, mixed DPI, mixed resolution/refresh, hot-plug and logical display roles.

## Spike and experiment rules

Prototype/spike work belongs outside the production application until it has earned its way into `app/`.

For every spike:

1. state the question it answers;
2. define minimum scope;
3. define measurements and falsification/acceptance criteria before implementation;
4. build only enough to answer the question;
5. run the experiment;
6. store raw results separately from interpretation;
7. interpret the evidence in the context of the actual environment;
8. recommend graduation to reusable/production code only after the evidence supports it.

Comparable alternatives must use comparable workloads, instrumentation, and metrics.

## Testing philosophy

Prefer deterministic Windows tooling for behavioural tests. A model may decide what to investigate next, but measurement and execution should be reproducible without dependence on one model provider.

High-value tests include capture/frame pacing, overlay recursion, drag/click coordinate correctness, mouse edge tracking, Tab/focus navigation, long-line caret tracking, mouse-versus-caret conflict, mixed DPI, monitor hot-plug, and display/fullscreen transitions.

Measure geometry, timing, frame cadence/freshness, movement thresholds, final margins, overshoot, and recovery behaviour rather than relying only on impressions such as "seems smooth".

Do not call a software timestamp difference photon/end-to-end latency unless the measurement semantics support that claim.

## Hardware/install support rule

Doxa hardware-specific code must be based on verified device identity or authoritative vendor information, not inferred from marketing names.

Installation/support must remain deterministic without an LLM. A cloud assistant may interpret structured diagnostics and recommend approved actions, but privileged changes must execute through a bounded local action API with user approval/UAC as appropriate.

Do not give an LLM unrestricted administrator shell authority as a product support mechanism.

## Repository and Git safety

- The canonical workspace is only `C:\dev\Vision`.
- Do not access or modify unrelated repositories or user files through project tooling.
- Preserve unrelated local work.
- Do not run destructive Git operations such as reset, clean, forced checkout, history rewriting, or mass deletion unless the user explicitly authorizes them.
- Do not commit, push, or mutate remote state unless explicitly requested.

## Reporting vocabulary

When reporting findings, distinguish explicitly between:

- **Observed repository fact** â€” directly present in the current workspace;
- **Test result** â€” reproduced by a named test or command;
- **Documented external fact** â€” supported by a public source;
- **Hypothesis** â€” plausible but not yet demonstrated;
- **Recommendation** â€” proposed next action based on the available evidence.

Do not claim work is complete unless repository/tool evidence confirms it.

## Artifact naming convention

All new project artifacts under `artifacts/` must use:

`YYYY-MM-DD__agent-name__relevant_content_vMAJOR.MINOR.ext`

Use lowercase agent identifiers and concise underscore-separated content descriptors. Example:

`2026-09-18__gpt-5.6-sol__agentic_audit_m2_cutover_map_v0.1.md`

Increment the version when materially revising the same artifact rather than creating ambiguous names such as `final`, `new`, or `latest`.


## Long-running execution and recovery

For commands likely to run longer than roughly 10-20 seconds, prefer the persistent background-job tools over a blocking shell/process call.
Use `project_job_start` to launch, `project_job_poll` to regain control and inspect progress, `project_job_cancel` to stop a stuck process tree, and `project_job_list` to recover state after a reconnect or MCP restart.

Poll often enough that control returns to the model regularly. Treat `possible_stall` as a prompt to inspect or change strategy, not as proof that a silent process is broken.
After one or two failures of the same mechanism, diagnose the failure class and switch approach rather than repeating the same operation indefinitely.
Do not stop merely to ask the user to type `continue` when the next safe step is known. Stop only at a genuine user-decision boundary, unavailable evidence/tooling, or task completion.
