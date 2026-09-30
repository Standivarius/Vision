# Next-chat handover: Vision / Doxa programme

> **Current authoritative transition package (2026-09-30):**
> - `artifacts/2026-09-30__VISION_RESEARCH_PRE_OPUS_HANDOVER_v1.0.md`
> - `artifacts/2026-09-30__VISION_NEW_CHAT_START_PROMPT_v1.0.md`
>
> These supersede older next-chat bootstrap instructions where they conflict.

## User intent

The next phase is a structured programme, not an isolated feature sprint. Build against the canonical inventory and work breakdown in `docs/project/programme/`.

Terminology correction: **Vision** is the product/software name. â€œVisionâ€ was accidental wording and is not a separate product.

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
9. `docs/project/foundation/vision_adoption_and_contextual_assistance_spec.md`
10. relevant current implementation before making claims

## Current baseline

- Canonical repo: `C:\dev\Vision` on `MARIUS-DELL`.
- Current public line: `0.1.0-alpha.11`.
- Inventory-start HEAD: `f8e53d4` (`visual: switch Ask Visual to NVIDIA Nemotron`).
- Vision two-screen alpha is real and publicly installable/updateable.
- Current core includes Context 1x + magnified Detail, tracking, viewport, View Locator, settings/persistence, colour modes, help/Ask Vision and single-instance behaviour.
- Current CMake defines 9 CTests.
- Ask Vision primary backend is NVIDIA Nemotron through the Doxa Cloudflare Worker, with Dify/Muse fallback.
- Alpha artifacts are still unsigned.

## Current programme decision

The owner simplified the programme on 2026-09-29. This replaces the older SM768-first/four-screen-Doxa execution plan.

1. **Doxa Installer** is independent from Vision. Hardware-specific work waits for the real SM770-based Doxa unit. Do not couple controller/driver/firmware logic into Vision.
2. **Vision** is the active product. It should be one generic Windows low-vision application supporting ordinary 2, 3 and 4 monitor systems; Doxa later becomes one qualified hardware configuration.
3. **Broader Doxa software/use-case research is parked.**

Vision's active sequence is:

`technical + commercial ZoomText/SuperNova research -> feature/value scope -> proposed 2-4 monitor architecture/development plan -> independent Opus review -> implementation`

Pricing strategy is intentionally later, after product scope and dealer/assessor evidence.

## Pre-Opus state

The following artifacts now define the pre-implementation package:

- `artifacts/2026-09-30__gpt-5.6-sol__vision_feature_and_commercial_research_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__incumbent_hands_on_validation_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_development_plan_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_review_package_v0.2.md`

The Dell comparison harness under `lab/incumbent-research/` has been validated against Vision using repeatable pointer, caret, focus and cross-monitor workloads with screen recording/ground-truth evidence. ZoomText/SuperNova hands-on runs remain explicitly unclaimed until their system-level installers are elevated and installed legitimately.

The proposed architecture is a hypothesis for review, not permission to implement: separate monitor/topology registry, capture sources, shared/appropriately-scoped evidence, and per-output view sessions so the current one-source/one-Detail baseline can evolve to generic 2-4 monitor behaviour without a Doxa fork.

Do **not** invoke Opus unless the owner asks to proceed from this checkpoint. Do **not** start the multi-monitor refactor before the independent review is reconciled.
## Repository safety

The working tree contains unrelated modified/untracked bridge/scripts/artifacts. Preserve them. Stage only files belonging to the current work item. Avoid destructive Git operations.

## Tracker status

**GitHub Projects is the selected execution tracker.** Linear is no longer the preferred path for this programme.

Do not let GitHub Project configuration block engineering. The canonical work IDs live in `docs/project/programme/work_breakdown.md`; mirror those IDs into GitHub issues/project items and keep repository docs authoritative.

## Key design constraints

- Vision core should remain Windows-native and hardware-agnostic where practical.
- Doxa workspace behaviour should reuse the Vision core, not become a permanent fork.
- AI is optional/noncritical; deterministic setup/render/tracking must not depend on it.
- No proprietary competitor source/assets/confidential implementation details.
- Use observed behaviour and public documentation for ZoomText/SuperNova research.
- Distinguish implemented behaviour, test evidence, design hypotheses and commercial research.
