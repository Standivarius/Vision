# Visual / Doxa programme

**Purpose:** canonical programme-level inventory, roadmap and handover for the Visual / Doxa work.

This directory answers four questions:

1. What exists now?
2. What is planned but not built?
3. What can proceed without physical Doxa hardware, and what is gated by SM768 or SM770?
4. What should the next engineering session work on, and against which acceptance criteria?

## Canonical documents

- `inventory_and_roadmap.md` - current programme inventory, dependencies, gates and phased roadmap.
- `work_breakdown.md` - tracker-neutral backlog with stable work-item IDs, dependencies and completion criteria.
- `next_chat_handover.md` - concise handover for a new ChatGPT session or engineer.
- `tracker_strategy.md` - current Linear/GitHub/self-hosted options and the recommended system-of-record strategy.

## Precedence

For programme status and sequencing, use this order:

1. explicit current user instruction;
2. current repository implementation and verified test/release evidence;
3. `inventory_and_roadmap.md` and `work_breakdown.md` in this directory;
4. tracked current product/architecture docs under `docs/project/foundation/` and `docs/project/hardware/`;
5. `docs/project/hardware/` for hardware/installer principles;
6. dated research and artifacts for provenance.

Older foundation/status documents remain valuable evidence, but some predate the current public alpha and must not be read as a current implementation inventory.

## Status vocabulary

- **Implemented** - present in the current application/tooling and supported by repository or test evidence.
- **Partial** - meaningful implementation exists, but important product/compatibility/qualification work remains.
- **Designed** - architecture/product behaviour is documented but not implemented as a product capability.
- **Research** - investigation or commercial/product validation is planned; no implementation commitment follows from it.
- **Hardware-dependent** - cannot be responsibly closed without the specified physical Doxa generation.
- **Deferred** - intentionally not in the current phase.

## System-of-record rule

The repository is the canonical source of programme truth. A task tracker (Linear, GitHub Projects, Plane, etc.) is an execution view of `work_breakdown.md`, not the sole copy of the plan.

This keeps the plan available on Dell, ASUS and future agent sessions through the same Git repository even if a SaaS account, API key or local service is unavailable.
