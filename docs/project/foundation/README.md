# Visual Development Foundation

**Purpose:** canonical current assumptions and engineering rules for material design, implementation and validation work in the Visual repository.

These files synthesize conclusions from research, experiments and project decisions. They are deliberately shorter and more stable than dated research artifacts.

## Required reading order

Before material design or implementation work:

1. Read this file.
2. Read `product_assumptions.md`.
3. Read `feature_roadmap.md` when choosing, sequencing or integrating product capabilities.
4. Read `engineering_principles.md`.
5. Read `architecture_baseline.md` when touching implementation or architecture.
6. Read `implementation_precedents.md` when selecting Windows mechanisms or considering public/open-source implementation patterns.
7. Read `experimentation_and_validation.md` when creating or interpreting a spike/test.
9. Read `../development_operating_model.md` when delegating work or modifying the repository through agents.
9. Inspect the current implementation before making claims or changes.

For Doxa hardware, firmware, drivers, installation or support work, also read `../hardware/README.md` and the relevant files in that folder.

## Precedence

For current development decisions, use this order:

1. explicit current user instruction;
2. `AGENTS.md` repository safety/invariants;
3. `docs/project/foundation/` current synthesized baseline;
4. active task/spike charter or feature specification;
5. current implementation and verified test evidence;
6. dated research/artifacts as evidence and provenance.

Older research does not automatically override a newer foundation conclusion. If new evidence contradicts the foundation, record the evidence and update the relevant foundation document deliberately.

## Foundation map

- `product_assumptions.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â product thesis, topology, broad value proposition and established product constraints;
- `feature_roadmap.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â research-backed feature families, sequencing and first usable-alpha target;
- `engineering_principles.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â implementation discipline and design rules;
- `architecture_baseline.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â current architecture conclusions and unresolved architecture questions;
- `implementation_precedents.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â public/open-source technical patterns and how they should influence Visual development;
- `vision_adoption_and_contextual_assistance_spec.md` - terminology alignment, deterministic contextual help and optional Ask Visual implementation decisions;
- `doxa_dual_workspace_shared_detail_concept.md` - current working Doxa-specific two-workspace + shared-Detail concept;
- `experimentation_and_validation.md` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â spike design, evidence interpretation and current experimental conclusions.

## Status labels

Foundation statements should use these meanings:

- **Established** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â accepted development assumption or repeatedly supported by evidence; build against it until deliberately changed.
- **Working** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â current best hypothesis; suitable for experiments but not a permanent product promise.
- **Unresolved** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â material uncertainty that should not be silently filled with an assumption.

## Evidence discipline

Always distinguish:

- repository-observed fact;
- test result;
- external documented fact;
- architectural/product hypothesis;
- recommendation.

Do not turn a spike result into a broad product conclusion without stating the environment and limits of the evidence.

## Research provenance

Primary dated research and experiment reports live under `artifacts/`. They remain useful for evidence, citations, historical reasoning and reassessment. The foundation files are the current synthesis, not a replacement for provenance.

## Current major product assumption

**Established:** normal Doxa deployment should be designed around a laptop plus three external Doxa displays: four active Windows screens. Two displays remain a valid minimum engineering topology for proving cross-monitor mechanisms.

## Current development position

- Spike 1 has positive physical evidence for WGC + D3D11 cross-monitor Detail.
- Spike 2 has positive physical evidence for PMv2 pointer/coordinate behavior across a real 150%/100% two-monitor boundary.
- The next independent capability area is caret/focus evidence, followed by viewport policy and then integration into the first internally usable Visual alpha.
- The broader product feature roadmap remains active and includes inspect-and-return, pointer/caret/focus finding, independent per-view state, monitor roles, fixed reference, simple visual states and later presentation/share-safe workflows.

## Last substantive update

2026-09-22 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â reconciled feature/workflow research, technical implementation precedents, Spike 1/2 evidence and the next integrated-alpha sequence into the canonical foundation.
