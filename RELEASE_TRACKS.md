# Release tracks — Vision repository

**Current release operations entry point (6 November 2026).** This repository contains two products, **not** one installer:

| Product | Contents | Current customer-facing release | Promotion |
|---|---|---|---|
| **Doxa Setup** | Branded Windows installer; original pinned Silicon Motion SM770 MSI; deterministic detection/driver handling; optional Doxa-only Online AI Cloudflare Worker; personal, Intune and ManageEngine channels | Private, unsigned owner-test candidate only. **NOT commercially releasable** | See [single Doxa release train](docs/project/programme/2026-11-06__vision_doxa_release_register_v1.0.md). Active code consolidation: GitHub branch `release/doxa-unified-20261106`. Doxa's own release-train document is on that branch. |
| **Vision** | Hardware-agnostic Windows low-vision software, WGC/D3D11 rendering, pointer/caret/focus, monitor/view roles, settings, telemetry, tests and Velopack updates | Public alpha **v0.1.0-alpha.11**; newer source and Doxa tests are development evidence, not in that build | Keep `.github/workflows/release-alpha.yml`, Velopack identity/alpha channel and app-level tests. No Doxa driver or Doxa installer should be bundled into Vision. |

**Rules:** One source commit + one version + one manifest per release; review builds must never be confused with signed production releases. Use different release labels and signing/evidence gates. Do not publish from uncommitted worktrees, obsolete Doxa previews or local test EXEs. Keep historical source branches and raw test evidence intact; an archive marker is not deletion.

For product status, current qualification evidence and unresolved release gates read [the release/qualification register](docs/project/programme/2026-11-06__vision_doxa_release_register_v1.0.md). For Vision product sequencing, `docs/project/foundation/feature_roadmap.md` remains authoritative. For driver details, `docs/project/hardware/README.md` applies. GitHub issues #75, #98, #99 and #109 cover Doxa release readiness, UI, physical installation and Online AI; #63 covers compatibility qualification.