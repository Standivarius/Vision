## CURRENT OPERATIONAL CHECKPOINT — 2026-09-30 POST-RASTER

This section is the current operational truth and supersedes older same-file wording that says Batch 1, the structural refactor, or Slices 1–9 have not started.

- Structural Gates 0A/0B and Slices 1–9: complete.
- Policy P1 movement owner / pointer-leave hold: complete.
- Policy P2 visibility independent of following: complete.
- Raster #19: complete for the current baseline; mode 0 bilinear remains default after human evidence (Word 2x very good; Word 4x judged better than ZoomText 4x; browser source pixel structure was already visible on the source display).
- Post-raster canonical regression: 19/19 CTests and 8/8 two-screen acceptance PASS at lab/benchmarks/integrated_app/runs/2026-09-30_22-41-56__two_screen_acceptance; Present failures 0; exact return 0 px; settings restored exactly.
- GitHub #24 repository consolidation: complete. Checkpoints: ae8b37f, c0ccb6a, 1d303df, 7dfe786, d7aa305 plus the final repository-policy commit; raw/generated evidence remains local and ignored.
- Next hardening streams after #24: #20 UI/DPI/AltGr/localisation, #21 Windows Magnifier + early low-vision/assessor evidence, #22 same-monitor capability, #23 compatibility ledger, and physical qualification/evidence for #11/#13/#14.
- GitHub #25 is the next Opus+Astra independent-review gate. Trigger it only after materially new hardening evidence exists across raster, cleanup, UI/DPI, low-vision/assessor tasks, same-monitor, compatibility and display lifecycle/identity/recovery; call earlier only for a genuine architectural contradiction.
- artifacts/2026-09-30__gpt-5.6-sol__vision_development_plan_v0.5.md remains the historical sequencing rationale; its 'implementation not yet started' language is stale.
## Vision naming and alpha compatibility

Vision is the canonical product and user-facing brand. The current published alpha line deliberately retains the former Visual identity only where changing it would split or destabilise installed-product continuity.

Compatibility boundary for the current alpha line:

- Velopack package/install/uninstall identity remains `Standivarius.Visual`;
- executable/process identities remain `visual_app.exe` and `visual_diagnostics.exe`;
- installed root remains `%LOCALAPPDATA%\Standivarius.Visual`;
- persistent settings/log/setup state remains under `%LOCALAPPDATA%\Standivarius\Visual`;
- update-policy registry/environment contracts remain `SOFTWARE\Standivarius\Visual` and `VISUAL_UPDATE_MODE`;
- current `VISUAL_*`, `visual_*`, internal window/mutex and deployed `doxa-visual-assistant` contracts remain compatibility identifiers;
- visible product/UI/release-friendly branding is Vision / `Standivarius - Vision`.

A compatibility guard now runs from both normal build and packaging paths. A local `0.1.0-alpha.12` probe built with 9/9 CTests passing and produced package metadata with the same package ID, main executable, alpha channel and AUMID as installed public alpha.11 while changing only the friendly title to `Standivarius - Vision`. The candidate was not installed or published.

Canonical report: `artifacts/2026-09-29__VISION_VISUAL_COMPATIBILITY_MIGRATION_REPORT_v1.0.md`.
# Vision / Doxa project status

**Date:** 2026-09-29
**Canonical machine:** `MARIUS-DELL`
**Canonical workspace:** `C:\dev\Vision`
**Public repo:** `https://github.com/Standivarius/Vision`

## Product direction

Vision is the current Windows magnification/tracking component and two-monitor engineering test bed for Doxa. Doxa research should evaluate magnification/access, productivity/context and ergonomics together rather than assuming more active displays are automatically better.

## Current Vision state

Vision is a functional two-monitor alpha with validated WGC capture, cached source texture, D3D11 Detail rendering, independent interaction/render cadence, pointer/UIA caret/keyboard-focus evidence, POI arbitration, viewport hold/pan/jump, locators, global zoom/tracking controls, exact normal/return, non-activating Detail, topology-invalidating shutdown/relaunch and native production tests.

Hotkeys:

- `Ctrl+Alt+1` -> 1x
- `Ctrl+Alt+2` -> 2x
- `Ctrl+Alt+4` -> 4x
- `Ctrl+Alt+0` -> normal/return
- `Ctrl+Alt+T` -> tracking toggle
- `Ctrl+Alt+Q` -> exit

Browser/Chromium semantic-caret support is validated for the deterministic Edge 153 HTML textarea scenario: three consecutive 2026-09-29 runs showed 100% UIA caret presence, 88.3-89.4% caret-selected frames and zero Present failures. Rich/custom web editors and other browser/version combinations remain outside this bounded claim.

## Pointer regression - closed for current build

Canonical crossing run:

`lab/benchmarks/visual_regression/runs/2026-09-24_10-40-18__pointer_crossing`

Key evidence:

- two physical 1920x1080 displays;
- PMv2-aware harness;
- 948/948 successful Presents;
- 659 independent cursor samples;
- flushed lifecycle markers including `first_source_frame` and `first_render_frame`;
- graceful Visual exit.

The source-to-Detail boundary behavior is current POI policy, not capture/render failure. Once the pointer leaves the source monitor, pointer evidence is filtered from the candidate set and semantic focus can take over, causing the Detail viewport to jump. Pointer POI resumes immediately when the native cursor returns to the source. This remains a UX-policy decision.

Canonical fast-visibility run:

`lab/benchmarks/visual_regression/runs/2026-09-24_11-04-26__pointer_visibility`

Results:

- 793/793 successful Presents;
- 561 independent cursor samples;
- zero Present failures;
- zero locator-missing frames in slow horizontal, fast horizontal, fast zig-zag and edge-teleport phases;
- video/contact-sheet review found no genuine rendered-locator disappearance;
- six telemetry anomaly rows were short timing/source-selection artifacts, not renderer loss.

Do not spend further cycles on generic pointer-loss reruns unless tracking/rendering changes or a new user-visible reproduction appears.

## Telemetry/harness changes

`app/src/main.cpp` now flushes the telemetry header and first numeric row immediately and emits flushed lifecycle markers:

- `telemetry_started`
- `capture_started`
- `first_source_frame`
- `first_render_frame`
- `capture_failure`

The physical harnesses establish PMv2 awareness before display enumeration, require a successful rendered telemetry row, detect early exit/readiness failure, and request graceful shutdown before force-kill fallback.

## Velopack lifecycle and public update milestone complete

Public prereleases `v0.1.0-alpha.2` and `v0.1.0-alpha.3` are published. Alpha.2 contains the lifecycle/update transport implementation; alpha.3 is a version-only transport-validation target used to prove the application-driven update path end to end.

Alpha.1 history:

- was packaged with `--skipVeloAppCheck true`;
- did not initialize the native Velopack lifecycle handler;
- physical installation showed `Install Partially Succeeded` although Visual could run;
- the historical alpha.1 Setup log was not recovered, so missing lifecycle integration is the leading explanation rather than a conclusively proven historical root cause.

### Current alpha.2 implementation

- pinned Velopack C/C++ SDK `1.2.0`;
- pinned native SDK ZIP SHA-256 `547262ed7a1ab1ff62f580aa53851ede2f1a451ac61b8974eb7bc01117488835`;
- pinned .NET SDK `8.0.425` for the CLI;
- pinned `vpk 1.2.0` tool manifest;
- `app/src/velopack_entry.cpp` owns real `wWinMain`;
- `Velopack::VelopackApp::Build().Run()` executes before normal Visual initialization;
- normal app implementation remains in `main.cpp` as renamed `VisualProductMain`;
- explicit `--update-check` and `--update-now` maintenance commands execute before normal magnifier startup;
- packaging no longer uses `--skipVeloAppCheck`.

Velopack SDK archive files remain:

- `lib/velopack_libc_win_x64_msvc.dll`
- `lib/velopack_libc_win_x64_msvc.dll.lib`

The import library encodes the runtime basename `velopack_libc.dll`; CMake copies/renames the archive DLL to that name beside `visual_app.exe`, and the package ships `lib/app/velopack_libc.dll`.

### Proven local alpha.2 result

Final candidate build/package result on MARIUS-DELL:

- Release build: success;
- CTest: 5/5 passed;
- Visual ProductVersion: `0.1.0-alpha.2`;
- Visual PE machine: x64 (`0x8664`);
- native Velopack PE machine: x64 (`0x8664`);
- normal `vpk 1.2.0` package: success with lifecycle validation enabled;
- full package: `Standivarius.Visual-0.1.0-alpha.2-alpha-full.nupkg`;
- Setup: `Standivarius.Visual-alpha-Setup.exe`;
- package payload contains `lib/app/velopack_libc.dll`.

A first alpha.2 package installed successfully at the Setup level but its lifecycle hook/update check returned `0xC0000135` because the runtime DLL had been staged under the SDK archive filename. `dumpbin /dependents` proved `visual_app.exe` imports `velopack_libc.dll`. Copying the same SDK DLL under that imported name immediately made installed `--update-check` work. CMake/package/verifiers were then corrected.

Clean corrected reinstall proof:

- uninstall exit: `0`;
- corrected Setup exit: `0`;
- Setup log: `Hook executed successfully`;
- Setup log: `Installation completed successfully!`;
- installed version: `0.1.0-alpha.2`;
- installed `velopack_libc.dll`: present;
- legacy wrong runtime filename: absent;
- installed `Update.exe`: present;
- installed `--update-check` exit: `0`;
- log: `installed_version=0.1.0-alpha.2`;
- log: `result=no_update`.

The hardened verifier was rerun against the corrected installation and reported:

- `setup_exit_code=0`;
- `hook_failure_lines=0`;
- `hook_success_lines=1`;
- `installed_update_check_exit_code=0`;
- `LIFECYCLE_RESULT=PASS`.

Canonical evidence:

- `app/packaging/alpha2-candidate-verification.log`;
- `artifacts/velopack_0.1.0-alpha.2_lifecycle_verification.log`;
- `artifacts/velopack_0.1.0-alpha.2_setup.log`;
- `artifacts/velopack_0.1.0-alpha.2_setup_corrected.log`;
- `%LOCALAPPDATA%\Standivarius.Visual\visual_update.log`.

## Update claim boundaries

1. package/feed production - proven;
2. native lifecycle startup - proven locally for alpha.2;
3. installed update-check transport - proven locally for alpha.2;
4. download/apply transport - proven end to end: installed public alpha.2 detected/downloaded/applied public alpha.3 through `--update-now`;
5. polished automatic-update UX/policy - not implemented.

Alpha.1 cannot initiate its own alpha.1 -> alpha.2 update because it contains no update client. The first application-driven update proof therefore starts from public alpha.2 and is now complete against public alpha.3.

## Release state

Public release chain:

- `v0.1.0-alpha.2` -> release commit `7215af2`; GitHub Actions release completed successfully;
- `v0.1.0-alpha.3` -> validation commit `712cba2`; GitHub Actions release completed successfully;
- installed public alpha.2 detected alpha.3 (`exit 10`, `available_version=0.1.0-alpha.3`), downloaded it, scheduled apply, and the installed ProductVersion became `0.1.0-alpha.3`;
- updated alpha.3 then returned `result=no_update` and passed a normal launch + graceful `Ctrl+Alt+Q` exit (`0`).

Canonical update proof:

`artifacts/2026-09-24__alpha2_to_alpha3_update_proof.md`

The worktree still contains substantial unrelated modified/untracked bridge, Doxa research, harness and artifact work. Those remain intentionally outside the release commits.

## Two-screen acceptance suite - passing

`VIS-005` is complete for the current software baseline.

Canonical entry point:

`app/run-two-screen-acceptance.ps1`

Canonical passing run:

`lab/benchmarks/integrated_app/runs/2026-09-29_17-37-51__two_screen_acceptance`

Key evidence:

- 8/8 acceptance steps passed on two active displays;
- installed public alpha `0.1.0-alpha.11` starts under the retained `Standivarius.Visual` compatibility identity;
- guarded Release build passed 9/9 CTests;
- Screen Roles and Colour & Contrast Settings surfaces are present;
- duplicate launch, Help, restart and `Ctrl+Alt+Q` exit passed on the current build;
- zoom telemetry observed 1x/2x/4x and tracking on/off;
- exact 1x/return restored the viewport with 0 px maximum coordinate delta;
- live mouse/viewport run recorded 358 pointer-source frames, 50 locator-visible frames, zero Present failures and zero invalid viewport decisions;
- the pre-run settings file was restored exactly after the suite.

Durable report:

`artifacts/2026-09-29__gpt-5.6-sol__vis005_two_screen_acceptance_v1.0.md`
## Programme reset - research before architecture

The current programme is deliberately simpler than the earlier Doxa/four-screen roadmap:

1. **Doxa Installer** is an independent hardware/setup workstream. Hardware-specific implementation waits for the real SM770-based Doxa unit; do not couple it into Vision.
2. **Vision** is the active product: one hardware-agnostic Windows low-vision application intended to support ordinary 2, 3 or 4 monitor systems and later run naturally on Doxa as one qualified hardware configuration.
3. **Broader non-low-vision Doxa software opportunities are parked.** Do not spend development/research effort there until Vision's opportunity is clearer.

Before major Vision architecture work, the active sequence is: incumbent technical/commercial research -> feature/value prioritisation -> proposed 2-4 monitor architecture/development plan -> independent Opus review -> implementation planning/build.

Pre-Opus evidence package:

- `artifacts/2026-09-30__gpt-5.6-sol__vision_feature_and_commercial_research_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__supernova_comprehensive_assessment_v0.1.md`
- `artifacts/2026-09-30__gpt-5.6-sol__zoomtext_comprehensive_assessment_v0.3.md`
- `artifacts/2026-09-30__gpt-5.6-sol__incumbent_cross_product_synthesis_v0.2.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_development_plan_v0.4.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.3.md`
- `artifacts/2026-09-30__gpt-5.6-sol__vision_pre_opus_review_package_v0.5.md`

The Dell incumbent-comparison harness under `lab/incumbent-research/` is validated against Vision for pointer, caret, focus and cross-monitor workloads. ZoomText 2026 and SuperNova Magnifier 25.05 have both been installed and studied. Broad manual-derived assessments are complete for both products and are reconciled into a cross-product problem/feature synthesis. Evidence levels are kept explicit: earlier hands-on behaviour, current installed state, vendor-documented semantics and bounded unverified behaviour are not conflated.

Remaining bounded uncertainties include matched **2x** Vision-vs-ZoomText perceived quality as a release benchmark, ZoomText MultiView/Tethered/Live Text task feel, SuperNova Mouse Buffer/Hooked-Area task feel, physical 3/4-monitor usability and user preference among full-screen, Context+Detail and contextual/lens modes. The 2x/4x Word comparison has already narrowed the renderer architecture decision: Vision should improve raster/GPU reconstruction first and preserve targeted semantic/clean-text seams rather than commit to a universal xFont-like renderer. These are now review inputs rather than reasons to restart broad incumbent research.

## Immediate priority

Do **not** begin the proposed 2-4 monitor refactor yet.

The research gate is complete enough for independent review. The next programme sequence is:

1. when explicitly authorised by the user, invoke the independent Opus 5.5 review using `artifacts/2026-09-30__gpt-5.6-sol__vision_opus_review_prompt_v0.3.md`;
2. reconcile the review against live repo truth and the frozen evidence package;
3. run only the smallest genuinely decision-blocking experiments identified by that review;
4. revise/accept the feature scope and architecture;
5. only then turn the accepted direction into an implementation sequence.

Pricing and route-to-market remain later decisions after product scope is credible and dealer/assessor evidence is collected. Doxa Installer remains separate and hardware-gated on SM770.



### Independent dual review complete (2026-09-30)
Opus 5.5 xhigh and GPT-6 Astra xhigh completed independent repo-aware reviews. Canonical reconciliation: artifacts/2026-09-30__gpt-5.6-sol__opus_astra_reconciliation_v0.1.md. No architecture implementation has started from these reviews.


### Current executable development plan (2026-09-30)
Canonical plan: artifacts/2026-09-30__gpt-5.6-sol__vision_development_plan_v0.5.md.
Immediate implementation gate: Batch 1 only - replay/baseline oracle + geometry/magnification contract + full two-screen acceptance rerun. No architecture refactor slice has started yet.
