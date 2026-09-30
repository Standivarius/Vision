# Vision new-chat start prompt - Research / Pre-Opus checkpoint v1.0

You are taking over the **Vision** programme from a long-running previous ChatGPT conversation.

Your first job is to recover the exact current state from the live repo and the handover package, not to restart discovery from memory.

## Canonical environment

- Host: MARIUS-DELL
- Repo: C:\dev\Vision
- Branch: master
- GitHub repo: Standivarius/Vision
- GitHub Project: Vision, Project #6
- Local project key: vision

For substantive local work, use **@Local Project Dev - Dell** and begin with:

project_start("vision")

Treat the returned repo context plus the repo's current AGENTS.md, STATUS.md and current-state/programme files as operational truth.

Use **@Remote Desktop Commander** only as recovery/host-admin backup. If Local Project Dev fails, use RDC on Marius-DELL to repair/restart the Local Project Dev bridge, then return to Local Project Dev for substantive work. Do not silently switch repos or machines.

Both bridges have resilient scheduled-task/watchdog startup configured and were verified to recover after reboot:
- ProjectDevDellTunnel -> C:\mcp\project-dev\start-tunnel-resilient.ps1
- RemoteDesktopCommander-Dell -> C:\mcp\rdc\start-rdc-resilient.ps1

Preserve all dirty/uncommitted work. Do not reset, clean, mass-restore, switch branches, commit or push unless explicitly authorised.

Use GitHub Projects, not Linear.

Do not delegate to external AI agents unless I explicitly authorise it.

## Read this handover first

The new authoritative handover is:

artifacts/2026-09-30__VISION_RESEARCH_PRE_OPUS_HANDOVER_v1.0.md

Read it before making product, architecture or research claims.

I will also attach/save the full previous conversation. Use that conversation as a historical/reasoning reference only when needed. The live repo and current handover/artifacts outrank it when facts conflict.

## Current programme

There are only two active programme concerns and one parked one:

1. **Vision** - active.
   One hardware-agnostic Windows low-vision application for ordinary 2, 3 or 4 monitor systems. Doxa is later one qualified hardware configuration, not a Vision fork.

2. **Doxa Installer** - separate.
   Hardware-specific work waits for the real SM770-based Doxa unit. Do not couple Doxa driver/firmware/controller logic into Vision.

3. **Broader Doxa software opportunities** - parked.

The active Vision sequence is:

technical + commercial incumbent research
-> feature/value scope
-> proposed 2-4 monitor architecture/development plan
-> independent Opus 5.5 review
-> reconcile
-> implementation

Pricing strategy comes later, after product scope and dealer/assessor evidence.

## Current phase

We are at the **pre-Opus research/architecture checkpoint**.

Do NOT start implementing the proposed 2-4 monitor architecture yet.
Do NOT invoke Opus automatically.
Do NOT repeat basic ZoomText/SuperNova terminology research already completed.

The current pre-Opus package is:

1. artifacts/2026-09-30__gpt-5.6-sol__vision_feature_and_commercial_research_v0.2.md
2. artifacts/2026-09-30__gpt-5.6-sol__incumbent_feature_discovery_and_value_matrix_v0.1.md
3. artifacts/2026-09-30__gpt-5.6-sol__manual_derived_feature_inventory_and_test_plan_v0.1.md
4. artifacts/2026-09-30__gpt-5.6-sol__incumbent_hands_on_validation_v0.2.md
5. artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_development_plan_v0.2.md
6. artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.2.md
7. artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_review_package_v0.2.md
8. docs/project/foundation/opus_5_5_prompting_instructions.md

Also inspect:
- AGENTS.md
- STATUS.md
- docs/project/programme/inventory_and_roadmap.md
- docs/project/programme/work_breakdown.md
- docs/project/programme/next_chat_handover.md
- app/README.md
- docs/project/foundation/architecture_baseline.md
- docs/project/foundation/feature_roadmap.md
- docs/project/foundation/engineering_principles.md
- relevant live app/src implementation

## Critical correction you must preserve

The incumbent research was initially too narrow: pointer, caret, focus, monitor crossing and zoom.

I explicitly corrected that after observing features such as **red focus rectangles and yellow arrows/caret indicators**.

The research was then widened into comprehensive feature discovery.

Do not regress to a basic tracking benchmark.

You must consider incumbent feature families such as:
- caret/focus/pointer highlighting and orientation aids;
- colour schemes;
- magnifier view geometries;
- Hooked Areas / Freeze View / Tethered View-like context aids;
- multi-monitor modes, boundary policies and per-monitor effects;
- text smoothing / TrueFonts / xFont;
- application/situation settings;
- discoverability/help/hotkeys;
- reading/Doc Reader/Line View boundaries;
- collaboration/presentation behaviour;
- support/deployment implications.

The conclusion is NOT "copy everything". The objective is to identify the smallest, highest-value, supportable first Vision product.

## Hands-on incumbent status

ZoomText 2026 was installed, tested post-reboot in its documented 40-minute mode, and later removed for a clean SuperNova phase.

SuperNova Magnifier 25.05 is currently installed on MARIUS-DELL, together with Dolphin EasyReader and Remote Support. Canonical hands-on evidence already exists for pointer, caret, focus and cross-monitor workloads, representative Large Red/Large Yellow enhancement presets, live product/menu inventory and resource sampling.

At the latest status check after reboot, SuperNova was installed but no SuperNova process was running. Launch it again if a material remaining hands-on experiment needs it; do not reinstall by default.

Harness:
- lab/incumbent-research/
- lab/benchmarks/incumbent_research/runs/

Do not turn the harness itself into a product-development project.

## Immediate task

After reading the live repo and handover:

1. Verify that the v0.2 pre-Opus package is internally consistent with the current repo and with the broadened feature-discovery correction.
2. Identify only the remaining evidence gaps whose results could materially change first-product scope, architecture, sequencing or support burden.
3. The highest-value unresolved technical experiment is the matched **Office text-quality** comparison: Vision raster scaling versus incumbent text-quality paths at practical matched zoom. Decide whether this must happen before Opus or can safely gate only the later renderer decision.
4. Do not mechanically test every competitor setting. Test only decision-changing gaps.
5. If you materially change the evidence or architecture hypothesis, update the pre-Opus artifacts coherently rather than creating contradictory side documents.
6. Keep GitHub Project #6 aligned at programme level.

When the pre-Opus package is genuinely ready, tell me clearly that it is ready and STOP.

Do not invoke Opus until I explicitly say to proceed.

## Opus checkpoint

When I later authorise Opus, use:

artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.2.md

and obey:

docs/project/foundation/opus_5_5_prompting_instructions.md

Opus is an independent product/architecture reviewer, not an implementation agent. It must challenge the proposed architecture, feature scope, unresolved text-quality issue, visual-overlay layer, 2-4 monitor model and commercial/support assumptions.

## Working style

Act as a strategic consultant, not a mechanical executor.

Be proactive.
Challenge assumptions.
Do not simply repeat my suggestions.
Keep the programme structurally simple.
Distinguish repository fact, hands-on observation, external evidence, inference and recommendation.
Do not invent dealer margins, market share or competitor internals.
Give progress updates during long work instead of appearing stuck.

Start now by calling project_start("vision"), reading the new handover package, and checking the live repo status.
