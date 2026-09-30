# Test farm assignment

## Safety and concurrency
Read AGENTS.md first, then docs/project/foundation/README.md, engineering_principles.md, architecture_baseline.md, experimentation_and_validation.md, docs/project/development_operating_model.md and STATUS.md. Inspect live code. Another stream is actively refactoring production. DO NOT modify app/src/**, app/tests/**, app/CMakeLists.txt, production settings or unrelated dirty files. Writable scope: lab/automation-harness/**, new lab/test-fixtures/** if needed, new raw evidence under lab/benchmarks/**/runs/**, and a dated final test-farm report in artifacts. You may RUN existing build/test/acceptance entry points but not alter them. Preserve dirty work; no reset/clean/forced checkout/branch switch/mass deletion; no commit/push. Work non-elevated: no services/tasks, machine-wide policy, reboot, monitor disconnect/reconfiguration or UAC. Capability-gate such tests. Do not invoke another AI coding agent. Harness PASS/FAIL must not depend on a model service.

## Current boundary and reuse
Current production path: EvidenceSampler -> EvidenceSnapshot -> ViewUpdateStep -> ViewUpdate/Locator -> Renderer. ReplayOracle and explicit geometry/magnification contract exist. Inspect but do not modify. Latest validation is at least 14/14 CTests, 8/8 canonical physical acceptance, exact temporary 1x/return delta 0 px and zero unexpected Present failures. Canonical external acceptance: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\app\\run-two-screen-acceptance.ps1. Reuse lab/automation-harness/**, lab/benchmarks/integrated_app/** and existing pointer/caret/focus/arbitration/return/lifecycle/browser/stress evidence. Consolidate; do not create a competing framework.

## Required architecture
Use: scenario catalogue -> planner/resolver -> isolated execution -> evidence bundle -> deterministic oracle -> aggregate/failure signatures -> human-review queue. Keep contracts suitable for later Windows workers. Local sequential execution is sufficient; interactive-desktop scenarios MUST serialize.

### Scenario/evidence contracts
Create a small versioned human-readable schema (JSON fine): stable ID/version/title/category/tags; capabilities; topology assumptions; fixture/app; initial settings; ordered actions; settle conditions; assertions; requested evidence; timeout/cleanup; deterministic/visual-review/physical-only/privileged/destructive/not-yet-automatable flags; compact variants. Preflight as RUNNABLE, SKIPPED_CAPABILITY, BLOCKED_INTERVENTION or INVALID; absent physical/privileged capability is never a Vision failure.
Each run bundle should contain as applicable scenario.resolved.json, environment.json, events.jsonl, assertions.json, result.json, telemetry/reference, stdout/stderr, requested screenshots/video and SUMMARY.md. Record scenario identity/hash, git HEAD, dirty flag plus bounded change provenance, Vision binary/version/hash where practical, Windows build, display topology/DPI where available, timestamps and harness version. Never imply HEAD alone reproduces a dirty build.

### Oracle/fan-in and catalogue
Deterministic facts are authoritative where possible: exit/liveness, viewport geometry, selected POI/source, tracking/follow state, binding, frame count/freshness, Present failures, invalid decisions, return delta and transitions. Screens/video support them. Do not call software timing photon/end-to-end latency. Aggregate into PASS/FAIL/SKIP/BLOCK/ERROR counts, category summaries, deterministic failure signatures, evidence paths, human-review queue, aggregate.json and Markdown. No model clustering in v0.1.
Catalogue: lifecycle; zoom/return; pointer paths/edges/leave-return/toggles; caret typing/navigation/disappear/conflicts; keyboard focus/navigation/app switch/conflicts; arbitration and stale/recent/simultaneous evidence; geometry including unequal/portrait/negative-origin/clamp/resize/overview-vs-1x/mixed-DPI metadata; rendering health; native/browser fixtures; stress/soak; future multi-view, ownership, monitor-change and 3/4-display scenarios. Physical topology changes and unsupported multi-view cases are catalogued but gated, not failed.

## Required v0.1
Deliver README/architecture/operator note; schema+validator; capability/environment probe; planner/resolver; runner with timeout/cleanup/per-run directory/stdout-stderr/settings backup-restore/exit classification; stable assertion IDs; evidence writer; aggregator; starter catalogue; safe-smoke command; list/dry-run command; aggregate JSON+Markdown. Prefer standard-library Python plus PowerShell/existing facilities and reuse proven scripts.
Required real scenarios where safe: replay/unit-test pack; normal start/exit; duplicate launch; zoom/tracking hotkey; exact temp 1x/return; live pointer/viewport/locator; caret; focus; arbitration/stale evidence; browser editing if unattended; pointer stress; short soak. Gate anything needing elevation/human intervention.

# Mandatory Software Acceptance tests - implement AND execute
SWA-01 Schema: valid accepted; missing required/version/action/assertion rejected usefully; variant IDs stable.
SWA-02 Dry-run/capabilities: resolve safe pack without Vision; RUN/SKIP/BLOCK correct; unavailable capability not FAIL; no state changes.
SWA-03 Runner success: deterministic fixture; stdout/stderr; PASS; provenance/bundle/cleanup.
SWA-04 Runner failure: controlled non-zero; correct taxonomy/exit code; aggregator accepts; harness survives.
SWA-05 Timeout: sleeping fixture; timeout classified; child killed; no orphan; valid bundle.
SWA-06 Assertions: passing, failing, unavailable metric; stable IDs; PASS/FAIL/NOT_EVALUATED.
SWA-07 Settings restoration: copy/hash before; restore in finally including injected failure; prove byte-identical; no machine-wide settings.
SWA-08 Fan-in: synthetic PASS, duplicate fail A, fail B, SKIP, BLOCK, timeout/error; exact totals; identical signatures cluster; different separate; evidence-linked review queue.
SWA-09 Deterministic rerun: stable resolved identity/hash and assertions over repeats; timing need not match.
SWA-10 Dirty-tree provenance: record HEAD+dirty plus bounded change provenance; do not dump unrelated file contents.
SWA-11 Concurrency guard: two interactive scenarios cannot overlap; synthetic non-GUI may parallelise if implemented.
SWA-12 Interrupted recovery: incomplete run is INCOMPLETE/INTERRUPTED, never PASS.
SWA-13 No elevation: full self-test + safe smoke in normal session without UAC/tasks/services/reboot/display reconfiguration.

## End-to-end acceptance
After SWAs are green or explicitly justified N/A: run current CTest/replay through the farm; safe lifecycle; exact 1x/return; pointer/locator; caret/focus/arbitration where safe; aggregate them; then run canonical two-screen acceptance unchanged. Final conditions: valid bundles/aggregate, canonical acceptance green, settings restored exactly, no orphan processes, no elevation/reboot/manual intervention, no production files modified.
Failure classes: HARNESS_DEFECT, VISION_REGRESSION, KNOWN_VISION_BEHAVIOUR, ENVIRONMENT_CAPABILITY, FLAKY_OR_NONDETERMINISTIC, HUMAN_REVIEW_REQUIRED, TEST_SPEC_DEFECT. Never modify Vision to make a harness test pass. Preserve real failures; record reruns rather than retry-until-green.

## Future visual-evaluator seam - design only
Document a manifest/interface for deterministic checks -> suspicious visual evidence -> cheap visual evaluator -> stronger model/human. Potential future questions: viewport jump, missing/duplicate pointer/caret, blank/corrupt output, unstable scrolling text, misplaced overlay. Do not add or call model SDKs/services in v0.1.

## Deliverables and completion
Create working harness/docs/config, catalogue/fixtures, executed SWA evidence, one executed safe-pack+aggregate, and a dated final test-farm engineering report under artifacts. Report architecture, exact changed files, catalogue, SWA-01..13 outcomes, real scenarios, aggregate, canonical acceptance, blockers, limitations/v0.2, and confirm production untouched/no elevation/reboot/manual intervention. Include exact commands for dry-run, self-tests, safe pack, one scenario and aggregation.
Do not stop at design. Complete only after harness runs, SWAs execute, representative Vision pack executes, evidence is aggregated, canonical acceptance reruns, report exists, and final worktree inspection proves production/unrelated files untouched. If environment blocks one item, finish everything else and document exact evidence; do not request owner intervention merely to green a gated scenario.

Final response only: overall PASS/PASS WITH BLOCKERS/FAIL; SWA passed/failed/N-A counts; real Vision PASS/FAIL/SKIP/BLOCK counts; canonical two-screen acceptance result; final report path; exact changed files/directories; owner action needed.
