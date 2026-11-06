# Doxa Setup — single release and deployment train (6 November 2026)

## Scope and authority

Doxa Setup is an **independent hardware installation product**. Do not mix it with the separately released Vision magnifier. For customer features, retain only: branded bilingual single-window guided installer; signed Silicon Motion SM770 display driver handling; read-only detection and screen arrangement guidance; optional Online AI with an independent Cloudflare Worker and reviewed Doxa-only knowledge; signed personal and managed deployment channels; deterministic repair and uninstall.

The canonical candidate source is the clean `release/doxa-unified-20261106` branch. The previous installer worktree `C:\wt\doxa-visual-support-20261029` stays unchanged as historical provenance. Only a Git-committed, reproducibly tested source revision may enter the release train. No EXE assembled from uncommitted source is a production release. GitHub issue #109 tracks AI acceptance; #98 and #99 track end-user flow and physical driver qualification; #75 tracks commercial readiness.

## One source, three Windows distributions, one AI backend

| Deliverable | Canonical implementation | Deployment identity | Readiness |
|---|---|---|---|
| Personal | `app/packaging/doxa-setup/full-release/Build-DoxaRetailRelease.ps1` -> `Personal/DoxaSetup.exe` | Authenticode-signed Doxa Setup EXE, after signing finalisation | **Unsigned owner-test**, not commercially distributable |
| Intune | Same reviewed source -> `Intune/DoxaDeploy.intunewin` | Signed `DoxaDeploy.exe`, packaged **after** signing | Technical package checks passed; full signed unattended qualification outstanding |
| ManageEngine | Same reviewed source -> `ManageEngine/DoxaDeploy.exe` and matching ZIP | **Identical signed managed EXE** as Intune, byte-for-byte | Controlled pilot only; signed mass deployment not qualified |
| Cloud AI | `app/packaging/doxa-setup/assistant/worker.mjs` plus `wrangler.toml`, curated knowledge | Independently deployed Cloudflare Worker `doxa-installer-assistant` | Live 5 Nov automatic-identity checks passed; commercial privacy and operations gates outstanding |

**Driver:** the pinned Silicon Motion `SMIUSBDisplaySW770.msi` is bundled unchanged (SHA-256 `3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4`). The MSI's Silicon Motion signature must remain `Valid`. The *Doxa EXE* requires separate publisher Authenticode signing and timestamp. Obtain OEM redistribution permission before external commercial release; technical embedding does not prove licensing rights. A healthy installed driver must never be needlessly replaced.

## Build -> test -> sign -> package -> qualify -> release

1. Use a clean committed Git worktree and record exact source commit, toolchain, version and pinned MSI hash. Do not build from the dirty canonical master or an old preview worktree.
2. Build complete package with `full-release/Build-DoxaCompleteRelease.ps1` using an explicitly pinned vendor MSI and a fresh, never-overwritten output directory. Validate embedded app, both languages, physical-detection contract, no driver mutation and native EXE `/selftest`.
3. Use `full-release/Build-DoxaRetailRelease.ps1` against **that same candidate**. Generate personal and managed unsigned review EXEs from identical embedded application+MSI bytes. The review EXE is for owner testing only.
4. Sign BOTH `DoxaSetup.exe` and `DoxaDeploy.exe` with the **approved publisher certificate** and trusted timestamp, then run `full-release/Finalize-DoxaSignedRelease.ps1` with exact approved publisher subject and certificate thumbprint. It validates signatures, timestamps, byte-for-byte source code/resources excluding the PE certificate table, managed ZIP and post-signing Intune `.intunewin`. Never package Intune/ManageEngine from unsigned review bits for general release.
5. Verify `RELEASE-MANIFEST.json`, all SHA-256 file hashes, signature status and complete pairing across all channels. A release with missing signature, mismatch or undocumented MSI rights is **STOP**, not a conditional go.
6. Qualify personal install/repair/uninstall on a fresh Windows host with and without Doxa attached, then perform one approved real Intune and one approved ManageEngine pilot on separate endpoint(s); include reboot handling, policy refusal, detection, rollback, logs and four-screen optical evidence. Automatic mass targeting requires independent sign-off.
7. Publish **one** versioned release, e.g. `doxa-setup-vX.Y.Z-rc.N` for private candidate and `doxa-setup-vX.Y.Z` for signed accepted commercial release. Record source commit, backend version, channel assets, hashes, certificate, results and rollback. Retain superseded drafts only as clearly marked historical evidence.

### Managed detection contract

`DoxaDeploy.exe /install` = install application as SYSTEM, do not force reboot; `/detect` = *software installed*, independent of whether Doxa is currently plugged in; `/verify` = driver/hardware separate; `/verify-panels` = PnP identities, **not** proof of physical Windows Extend arrangement; `/repair` and `/uninstall` must preserve healthy unrelated/vendor driver as specified. Exit 0 success, 3010 soft reboot coordinated with IT, other nonzero failure. No silent driver installation with Doxa disconnected; do not turn disconnected hardware into an endless managed redeployment loop. Refer to `full-release/MANAGEENGINE-NATIVE-PILOT-RUNBOOK.md` for the active pilot contract; old preview scripts are historical.

### Online AI contract and release order

Cloud AI is optional, subject to explicit notice/opt-in; IT machine policy can block it. A fresh client automatically creates its per-user DPAPI-protected signing key, sends **only the public JWK** with each signed, timestamped request, and requires no manual device approval. This is *not* proof of a purchased product; the server applies Doxa-only scope, validated diagnostics, per-device/network limits and the global daily budget. No screenshot/USB serial/password uploads; no driver/control action may be executed by the AI. No silent local answer substitution when Online AI is selected.

Deploy and validate the Worker **before** distributing a client that relies on new authentication. Test on staging first; preserve the prior deployed Worker version for rollback. In production: `/health` must show automatic-device-signature, manual_device_approval=false, model binding and read-only actions. Run one real signed request from a fresh Windows profile, a regression request from the previous Dell identity, and a rejected anonymous request. Check error and limit categories. Document the client/Worker compatibility range in the release manifest. Never use or alter the independent `doxa-visual-assistant` service for Doxa Setup.

## Freeze/retire rules (non-destructive)

Old preview branches, chained PRs, and untagged EXE drafts are historical *until merged or explicitly withdrawn*. They must not silently become an update feed. **Do not delete** their Git branches, raw evidence, untracked output or local worktrees as part of release promotion. When the unified source PR is reviewed and accepted, close superseded stacked PRs with a pointer and then prune **only clean** worktrees after evidence retention is verified; do not reset or clean dirty trees. Keep Vision tests, magnification software, and Vision Velopack alpha releases separate.

## Commercial release STOP conditions still open

- Publisher code-signing identity, signed final binaries and timestamp have not been evidenced for this new Doxa EXE.
- Written vendor/OEM right to redistribute the specific Silicon Motion MSI has not been evidenced.
- Signed fresh-host physical install/repair/uninstall, Intune SYSTEM and ManageEngine agent acceptance are not complete for this source revision.
- Owner's latest layout confirmation and customer-grade GDPR/controller/processor notice, retention and support policy remain pending.
- Cloud service usage cap (300 inference attempts per UTC day) is operational safeguard, not guaranteed cost or uptime for all installers.

**Never claim a commercial release until every STOP gate is cleared with linked evidence.**