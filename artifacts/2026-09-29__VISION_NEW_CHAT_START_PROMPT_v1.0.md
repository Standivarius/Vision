# Vision New Chat Start Prompt v1.0

You are taking over ongoing development of **Vision**, the Standivarius/Doxa Windows low-vision product.

## Canonical setup

- Product/project: **Vision**
- Host: `MARIUS-DELL`
- Repo: `C:\dev\Vision`
- Branch: `master`
- GitHub repo: `Standivarius/Vision`
- GitHub Project: **Vision**, Project #6
- Primary local tool: **Local Project Dev – Dell**
- Project key: `vision`

Begin with:

```text
project_start("vision")
```

## Source hierarchy

Use this order:

1. live repository and current tests;
2. current `AGENTS.md`, `STATUS.md`, programme docs and Git/GitHub state;
3. the reconciled master handover:
   `artifacts\2026-09-29__VISION_MASTER_HANDOVER_v1.0.md`
4. the full archived previous development conversation:
   `artifacts\2026-09-29__VISION_PREVIOUS_DEVELOPMENT_CONVERSATION_ARCHIVE.md`

The archive is historical context only. Do not treat it as current repo truth.

## Initial reading order

After `project_start("vision")`, read:

1. `AGENTS.md`
2. `STATUS.md`
3. `docs/project/programme/inventory_and_roadmap.md`
4. `docs/project/programme/work_breakdown.md`
5. `docs/project/programme/next_chat_handover.md`
6. `artifacts\2026-09-29__VISION_MASTER_HANDOVER_v1.0.md`
7. only then consult the full conversation archive if historical rationale is missing
8. relevant implementation/package docs for the active task

Do not reread the entire repo or entire archive unnecessarily.

## Operating rules

- The live repo is factual truth.
- Preserve all pre-existing dirty/uncommitted work.
- Do not perform destructive cleanup or bulk restore against unknown work.
- Use GitHub Projects, not Linear, for execution tracking.
- Use Remote Desktop Commander only as recovery/admin if the project MCP is unavailable or cannot do the required host-level operation.
- Do not repair or revive the old ngrok bridge unless explicitly asked.
- Do not invoke external AI agents unless explicitly authorised.
- Do not globally replace `Visual` with `Vision`.

Infrastructure is already configured. Focus on **Vision product/concept/development work**, not infrastructure setup.

## First task

Finish the remaining **Visual -> Vision compatibility assessment** before ordinary feature work.

First establish the current live state and audit active legacy identifiers.

Classify significant identifier families as:

- **A — rename now**
- **B — retain as internal/compatibility identifier**
- **C — migrate later with explicit backwards-compatible handling**
- **D — historical**

Pay particular attention to:

- Velopack package/update continuity;
- `Standivarius.Visual`;
- already-installed alpha detection;
- executable names;
- `%LOCALAPPDATA%\Standivarius\Visual`;
- registry/install/uninstall identity;
- Start Menu/shortcuts;
- update feeds/channels;
- release automation;
- deployed cloud-service identifiers;
- schema/config/environment contracts;
- scripts/tests that depend on old executable/process names.

The key compatibility question is:

> Can a machine already running an old Visual alpha upgrade normally to a Vision-branded build, preserve settings/state, remain one installed product, and uninstall/update coherently?

Before changing compatibility-sensitive identifiers, report:

1. verified live current state;
2. A/B/C/D classification;
3. recommended compatibility boundary for the current alpha;
4. upgrade consequences;
5. exact safe changes proposed now.

Only then implement safe changes, regenerate authoritative outputs, rebuild/test, verify upgrade continuity, document what deliberately remains `Visual`, and save a durable migration report under `artifacts/`.

## After naming compatibility is settled

Return to the current programme in the live repo. The master handover preserves the historical product reasoning, but current programme docs determine the actual next work item.

Do not let historical handover text override current implementation evidence.


## Long-running execution harness

For builds, tests, packaging, or other commands likely to exceed roughly 10-20 seconds, use the persistent job tools rather than blocking the chat behind one long process:
- `project_job_start`
- `project_job_poll`
- `project_job_cancel`
- `project_job_list`

Poll periodically so the model regains control and can recover from failures. If the chat reconnects, call `project_job_list` first to discover any still-running or completed local jobs. A `possible_stall` flag is a diagnostic hint, not proof of failure.
