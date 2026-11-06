# Vision and Doxa — release & qualification register (6 November 2026)

## Decision: two products, one repository, separate release trains

**Doxa Setup** owns hardware setup, the pinned original signed Silicon Motion SM770 MSI, a bilingual single-window GUI, read-only hardware/detection assistance, deterministic driver/repair/uninstall, optional Doxa-only Online AI, and native Windows managed deployment. **Vision** owns the hardware-independent C++ Windows magnification application, WGC/D3D11 tracking/renderer, settings, Velopack updates, and accessibility qualification. Do not share installer identities, update feeds, cloud-service names, or signing decisions between products.

| | Doxa Setup | Vision |
|---|---|---|
| Intended source line | `release/doxa-unified-20261106` (GitHub PR for integration required) | `master` and the established Vision product development plan |
| Local source worktree | `C:\wt\doxa-release-canonical-20261106` (clean isolated consolidation; do not edit old review worktrees) | `C:\dev\Vision` (has substantial pre-existing dirty/untracked work: **do not reset/clean**); governance changes isolated in `C:\wt\vision-release-governance-20261106` |
| Owner-test/public release | 5 Nov private unsigned owner test: `doxa-universal-online-live-validated-20261105-owner-test` (GitHub draft; not production) | Public `v0.1.0-alpha.11` (27 Sep); no later public Vision release verified |
| Update route | Rebuild one committed Doxa source, validate both EXEs, sign and timestamp, regenerate personal + Intune + ManageEngine from **identical signed reviewed managed EXE** | Preserve existing Velopack `Standivarius.Visual` compatibility identity and `alpha` channel, `.github/workflows/release-alpha.yml` |
| Cloud | `doxa-installer-assistant` Worker, separately deployed; 5 Nov fresh Windows profile + existing Dell returned real model answers | Distinct `doxa-visual-assistant` compatibility service; do not repoint it to Doxa Setup |
| Key block | Publisher signature, OEM MSI redistribution right, genuine fresh-host/managed pilot, final privacy/owner review | Next low-vision user/assessor validation, multi-display regression, compatibility and release acceptance for newer source |

### Doxa release single source of truth

Read the canonical release-train procedure committed in the Doxa consolidation branch: `docs/project/programme/2026-11-06__doxa_single_release_train_v1.0.md`. Existing approved implementation entrypoints are:

- `app/packaging/doxa-setup/full-release/Build-DoxaCompleteRelease.ps1` (reviewed complete source package and embedded MSI validation);
- `.../Build-DoxaRetailRelease.ps1` (two unsigned personal/managed EXEs + one Intune package for **review only**);
- `.../Finalize-DoxaSignedRelease.ps1` (**sole signed promotion step**: exact publisher identity/thumbprint, timestamp, PE contents unchanged, post-sign Intune/ManageEngine recalc);
- `.../Test-DoxaReleaseConsistency.py` (offline Intune package decryption and byte equality to ManageEngine EXE);
- `.../MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md` (active managed install/detect/verify/repair/uninstall contract);
- `app/packaging/doxa-setup/assistant/worker.mjs` and `wrangler.toml` (separate cloud backend, per-device/network limits and global budget).

The driver is embedded as the **exact signed** Silicon Motion MSI with SHA-256 `3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4`. Its signature does **not** sign the outer Doxa EXE. Never reinstall a healthy driver merely to test the UI. Disconnected hardware is not driver removal. `DoxaDeploy.exe /detect` measures installed **software**, while `/verify` and `/verify-panels` report hardware state separately. `3010` indicates a coordinated soft reboot, not permission to force one.

### Doxa current acceptance

On 5 Nov the cloud Worker was deployed with `authentication=automatic-device-signature` and `manual_device_approval=false`. A fully fresh temporary Windows signing profile returned an `answered` AI response; Dell's original identity also answered; an anonymous request was rejected with HTTP 401. Worker tests: **21/21 PASS**. Embedded application, native EXE and bilingual tests: PASS. These prove the development/owner-preview contract, not commercial uptime, publisher signing, user-wide physical installation or lawful redistribution.

**BLOCKERS before any commercial Doxa release:** exact publisher certificate and trusted timestamp for `DoxaSetup.exe` and `DoxaDeploy.exe`, validated production manifest and signed managed bytes; Silicon Motion/OEM redistribution permission; final reviewed GDPR notice and data-processing conditions; owner visual acceptance; signed genuine personal install/repair/uninstall and approved Intune SYSTEM / ManageEngine agent trials with rollback and logs. No mass endpoint targeting.

### Vision current release state

`v0.1.0-alpha.11` is the last confirmed published Vision alpha. The existing alpha workflow builds C++/CMake, verifies provenance/SBOM/dependencies and uses Velopack. Keep old published installation IDs `Standivarius.Visual` / `visual_app.exe` as compatibility identifiers until a separately qualified migration; user-visible naming is **Vision**. Never send DoxaSetup.exe as a Vision update or add Silicon Motion drivers to the generic Vision package.

The working engineering baseline has WGC + D3D11, pointer/caret/focus observation, Point-of-Interest arbitration, Context + Detail, zoom and recovery, and an evidence-backed two-screen alpha; see `STATUS.md`, `docs/project/foundation/feature_roadmap.md`, and the qualified release workflow. These are **not** claims that four-screen Vision production performance or every assistive technology is qualified.

### Doxa accessibility and competitor qualification: evidence, not extra shipped features

Authoritative *November 4* comparative synthesis: `docs/project/programme/2026-11-04__doxa_17_field_comparative_synthesis_v1.2.md`, using `2026-11-04__doxa_17_field_execution_ledger_v1.1.csv` and the individual reports for Microsoft Magnifier, NVDA and ZoomText. Four physical screens were present during those bounded tests. Microsoft Magnifier has the strongest physical evidence for independent laptop magnification; NVDA offers screen reading but not the claimed native magnifier mode; ZoomText demonstrated bounded functionality but **not** source-to-centre shared Detail or independent laptop-only magnification. SuperNova 25.05 is a documentary clean-room reference, not live verified in this suite. Do not turn `DOCUMENTED_ONLY`, `NOT_RUN`, `NOT_DEMONSTRATED` or `INCONCLUSIVE` into a pass.

`docs/project/programme/2026-11-04__gemini_execution_report_and_response_to_independent_review_v1.0.md` describes the revised evidence audit after independent objections. A final independent sign-off is **not yet recorded**; use these reports as qualified evidence with explicit limits, not as a certification certificate. Preserve raw evidence and the previous ledger version for traceability.

*November 5 status differs:* `docs/project/programme/2026-11-05__vision_gemini_resource_attribution_execution_summary_v1.0.md` and `...__vision_resource_attribution_w0_decision_v0.1.md` establish that Doxa was then disconnected (`FOUR_SCREEN_CONSOLE_NOT_OBSERVABLE`). They also withdraw earlier unsupported CPU superiority claims; the resource investigation identified a potential static-present bottleneck and drafted an event-driven presentation spike but did **not** implement that spike or prove a general Vision performance advantage. Reconnect Doxa for future physical four-screen tests; never substitute RDP screen counts or historical test photos for a new live console pass.

### Non-destructive retirement / housekeeping policy

Local legacy worktrees and prior PRs (#77, #78, #103–#108) are preserved, not alternative sanctioned release inputs. They should be closed as superseded **only after** the unified installer PR is validated and merged, with links back to their review provenance. The six older Doxa draft releases should be labelled `SUPERSEDED — DO NOT TEST` rather than deleting their assets; keep exactly one owner-test draft designated *current*. Never run `git clean`, `reset --hard`, mass worktree removals or branch deletes against the existing Dell work without individual evidence checks. This register becomes the discoverable present-state index; dated test artifacts remain the immutable audit trail.

### Next gates (order matters)

1. Finish unified Doxa source PR with reproducible CI and validated committed-build output; no more unmanaged EXEs from dirty source.
2. Validate the approved Doxa publisher signature, OEM MSI licence, signed packaging consistency and managed pilots; only then promote one versioned Doxa release.
3. Complete owner-test UI and fresh-host/managed acceptance; maintain a rollback Worker and previous signed installer.
4. Keep Vision in its own alpha/update line; reconcile newest 4-display usability and resource evidence, then run only the missing targeted AT tests before a new Vision alpha.
5. Prune stale branches/worktrees and superseded drafts **only after** confirmed merge, clean-state and evidence-retention audit; do not equate historical files with executable product features.