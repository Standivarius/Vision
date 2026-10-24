# VISION — NEW CHAT BOOTSTRAP PROMPT v2.0

You are taking over the **Vision** Windows low-vision magnification project from a previous very long ChatGPT development conversation.

## Primary handover source

Read this file first:

`artifacts/2026-09-30__VISION_COMPREHENSIVE_HANDOVER_POST_P2_RASTER_v1.0.md`

It is deliberately comprehensive and is the freshest operational checkpoint. Do **not** rely on older `STATUS.md` “Batch 1 / pre-refactor” wording because those historical sections are stale.

After the handover, read live repo truth and the current artifacts named there.

## Canonical environment

- Host: **MARIUS-DELL**
- Repo: `C:\dev\Vision`
- Branch: `master`
- Product: **Vision**
- Local Project Dev registry key currently working: **`vision`**

Project instructions require trying `project_start("visual")` first. It currently fails with the known registry mismatch. Immediately fall back to:

`project_start("vision")`

Do not spend time repairing that alias unless I explicitly ask.

## Repository safety

The repo is heavily dirty/uncommitted.

- preserve all existing dirty work
- no reset/clean/stash-all/forced checkout/branch switch
- do not commit or push unless I explicitly ask
- inspect live code before changing it
- distinguish current Vision work from unrelated/pre-existing dirty files.

Use GitHub Projects/issues, not Linear.

Do not invoke Codex, Claude, Gemini, Opus, Astra or other AI agents unless I explicitly authorise it.

## How I want you to work

Continue autonomously. **Do not stop for approvals unless you genuinely need me.**

Interrupt only for UAC/elevation, reboot, physical monitor/cable/sleep actions, disruptive system-wide changes, subjective visual/usability judgement, a real product decision that cannot safely be inferred, or a failure where proceeding could damage existing work.

Do not pause simply because a test gate passed.

## Current engineering checkpoint

Structural development through **Slices 1–9 is complete**.

Policy slices are also complete:

- **P1 movement owner + pointer-leave hold — complete / #17 closed**
- **P2 visibility independent of following — complete / #18 closed**

Latest clean baseline:

- **19/19 CTests PASS**
- **8/8 canonical two-screen acceptance PASS**
- evidence: `lab/benchmarks/integrated_app/runs/2026-09-30_21-21-23__two_screen_acceptance`
- zero Present failures
- exact 1x return delta 0 px
- settings restored exactly.

## Current issue: #19 raster reconstruction

The repo contains engineering-only reconstruction modes:

- mode 0 = current bilinear baseline
- mode 1 = Catmull-Rom
- mode 2 = Lanczos-2
- mode 3 = adaptive sharpen.

They are selected only by `--reconstruction`; normal/default Vision remains mode 0.

**Critical latest human evidence:**

- I judged Vision **2x in Word “very good.”**
- I initially complained about pixelation in ChatGPT/browser.
- I then photographed the **main/source screen itself** close-up and showed that the pixel/subpixel structure is already visible there. I explicitly said we were “chasing the wrong rabbit”: magnifying source pixels naturally magnifies that source structure.
- I then checked **Word at 4x** and judged Vision **better than ZoomText at 4x**.

Therefore do **not** blindly optimise the renderer because a metric says Lanczos/sharpen is sharper. Reframe #19 using this human evidence. Preserve Word quality. Do not jump to semantic/xFont-style rerendering.

At handover time the dev app was running baseline 4x:

`C:\dev\Vision\app\build\Release\visual_app.exe --zoom 4 --reconstruction 0 --log C:\dev\Vision\lab\benchmarks\raster_reconstruction\runs\human_baseline_4x_2026-09-30_22-13-31.csv`

Check whether it is still running before launching another instance.

## Naming warning

The product is **Vision**, but current alpha compatibility deliberately retains:

- `visual_app.exe`
- `Standivarius.Visual`
- legacy Visual/`VISUAL_*` identifiers and install/state paths.

So if I say “I cannot find Vision / is it still Visual?”, do not interpret that as a branding rollback. The compatibility executable is still `visual_app.exe`.

## First actions

1. Connect to `vision` on MARIUS-DELL.
2. Read `AGENTS.md`.
3. Read the comprehensive handover file above.
4. Read:
   - `artifacts/2026-09-30__gpt-5.6-sol__vision_development_plan_v0.5.md`
   - `artifacts/2026-09-30__gpt-5.6-sol__raster_reconstruction_experiment_v0.1.md`
   - `artifacts/2026-09-30__gpt-5.6-sol__policy_p1_movement_owner_pointer_leave_v0.1.md`
   - `artifacts/2026-09-30__gpt-5.6-sol__policy_p2_visibility_follow_separation_v0.1.md`.
5. Inspect live Git status and current processes.
6. Reconcile #19 with my newest human observation.
7. Do **not** automatically switch to Lanczos/sharpen.
8. Continue into remaining evidence/product-hardening rather than restarting architecture work.

Likely remaining workstreams:

- #19 finish/reframe raster decision
- #20 DPI/AltGr/localisation/UI hardening
- #21 Windows Magnifier + low-vision/assessor evidence
- #22 same-monitor capability spike
- #23 compatibility ledger
- physical qualification for #11/#13/#14 when I am present.

Do not call another Opus/Astra review automatically. The previous review remains useful. A new high-value review comes after enough new evidence exists — especially raster conclusion, same-monitor result, lifecycle/identity evidence, compatibility evidence and early low-vision feedback — unless a genuine architectural contradiction appears earlier.

Proceed from the live repo and the handover. Do not ask me to restate this context.

