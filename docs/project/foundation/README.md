# Vision Development Foundation

Purpose: canonical current assumptions, product sequencing and engineering rules for material design, implementation and validation work in the Vision repository.

The foundation files synthesize conclusions from research, experiments and current programme decisions. Dated artifacts preserve provenance; they do not override a newer explicit foundation conclusion.

## Required reading order

Before material design or implementation work:

1. Read this file.
2. Read product_assumptions.md.
3. Read feature_roadmap.md — the canonical current development sequence.
4. Read engineering_principles.md.
5. Read architecture_baseline.md when touching implementation or architecture.
6. Read implementation_precedents.md when selecting Windows mechanisms or public/open-source precedents.
7. Read experimentation_and_validation.md when creating or interpreting a spike/test.
8. Read ../development_operating_model.md when delegating work or modifying the repository through agents.
9. Inspect the current implementation and STATUS.md before making claims or changes.

For Doxa hardware, firmware, drivers, installation or support work, also read ../hardware/README.md and the relevant files in that folder.

## Precedence

For current development decisions:

1. explicit current user instruction;
2. AGENTS.md repository safety/invariants;
3. docs/project/foundation/feature_roadmap.md for programme sequencing;
4. the other current foundation documents for product/architecture/engineering constraints;
5. active task/spike charter;
6. live implementation and verified test evidence;
7. dated research/artifacts as evidence and provenance.

If new evidence contradicts the foundation, record the evidence and update the relevant foundation document deliberately.

## Foundation map

- product_assumptions.md — product thesis, topology, broad value proposition and established constraints.
- feature_roadmap.md — single canonical current product/development roadmap and immediate sequence.
- engineering_principles.md — implementation discipline and design rules.
- architecture_baseline.md — current architecture conclusions and unresolved architecture questions.
- implementation_precedents.md — public/open-source technical patterns and their relevance.
- vision_adoption_and_contextual_assistance_spec.md — terminology alignment, deterministic contextual help and optional Ask Vision decisions.
- doxa_dual_workspace_shared_detail_concept.md — Doxa-specific two-workspace + shared-Detail concept.
- experimentation_and_validation.md — spike design, evidence interpretation and experimental conclusions.
- reconstruction_lab.md — calibrated REA/Ghidra + Windows runtime workflow for targeted binary/mechanism research.
- opus_5_5_prompting_instructions.md — current reusable Opus 5.5 review/prompting guidance.
- execution_plan.md — historical research-stage plan; superseded for sequencing by feature_roadmap.md.

## Status labels

- Established — accepted development assumption or repeatedly supported conclusion; build against it until deliberately changed.
- Working — current best hypothesis; suitable for experiments but not a permanent product promise.
- Unresolved — material uncertainty that should not be silently filled with an assumption.

## Evidence discipline

Always distinguish:

- repository-observed fact;
- test result;
- external documented fact;
- architectural/product hypothesis;
- recommendation.

Do not turn a spike or owner-debug observation into a broad user conclusion without stating environment and evidence limits.

## Current programme position — 2026-10-01

Structural extraction is no longer the next task.

Completed/current foundations include:

- Gates 0A/0B and structural Slices 1–9;
- P1 movement-owner and P2 overlay/follow separation;
- current raster decision;
- repository consolidation;
- mixed-DPI/UI/localisation foundation;
- same-monitor capability verdict;
- current Word/Excel bounded compatibility evidence.

The active tranche is hardening/validation:

- #20 UI/DPI/hotkey/localisation residuals;
- #21 Windows Magnifier + first genuine low-vision/assessor evidence;
- #23 compatibility ledger;
- combined physical #11/#13/#14 display identity/lifecycle/recovery qualification.

Then run #25 Opus + Astra review.

The first productisation tranche after that review begins with P3 active-source/view ownership + monitor-crossing policy, followed by orientation presets, viewport tuning and monitor-role productisation.

## Monitor-model clarification

Two-screen default:

one Context/source monitor -> one dedicated Detail/destination monitor.

Multi-source/shared-Detail behaviour is a first-product direction for configurations with more than one source-eligible workspace; it requires explicit active-source ownership/crossing policy rather than every view following every fresh signal.

## Last substantive update

2026-10-01 — consolidated completed engineering, incumbent/user research, current validation evidence and the upcoming active-view/crossing product tranche into feature_roadmap.md.
