# Vision / Visual Compatibility Migration Report v1.0

**Date:** 2026-09-29  
**Host:** MARIUS-DELL  
**Repository:** `C:\dev\Vision`  
**Branch:** `master`  
**Public repository:** `Standivarius/Vision`

## Executive conclusion

The current alpha line can be rebranded visibly from **Visual** to **Vision** without becoming a second installed product, provided the published-alpha compatibility identity remains unchanged.

The safe boundary is:

- **Vision** = canonical product name and user-facing branding;
- **Visual** = retained only where it is an existing install/update/state/runtime/schema compatibility identifier, or historical evidence.

A local `0.1.0-alpha.12` compatibility candidate was built and packaged without publishing or installing it. Compared with the installed public alpha.11, the candidate keeps the same Velopack package ID, main executable, channel and AUMID while changing the friendly title from `Standivarius - Visual` to `Standivarius - Vision`.

## Verified live starting state

The live machine had public alpha.11 installed as one Velopack product:

| Item | Installed alpha.11 |
|---|---|
| Package ID | `Standivarius.Visual` |
| Install root | `%LOCALAPPDATA%\Standivarius.Visual` |
| Main executable | `visual_app.exe` |
| Channel | `alpha` |
| AUMID | `velopack.Standivarius.Visual` |
| Uninstall key | `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Standivarius.Visual` |
| Visible title | `Standivarius - Visual` |
| Persistent settings | `%LOCALAPPDATA%\Standivarius\Visual\settings.ini` |
| Start Menu shortcut | `Standivarius - Visual.lnk` -> installed `visual_app.exe` |

The public GitHub alpha.11 assets likewise use the `Standivarius.Visual` package lineage. Historical alpha.2 -> alpha.3 application-driven update continuity is already documented in the repository.

The repository was heavily dirty before this task. No reset, clean, bulk restore or destructive rewrite was used.

## A/B/C/D classification

### A — rename now

These are branding surfaces and may use Vision immediately:

- user-visible product copy;
- window titles and message-box titles;
- Settings / Help / Ask product wording;
- PE `FileDescription` and `ProductName`;
- Velopack friendly `packTitle`;
- release display names and workflow labels;
- current programme/support/product documentation.

### B — retain as compatibility/internal identifier

These remain deliberately Visual for the current alpha line:

- Velopack package ID `Standivarius.Visual`;
- install root `%LOCALAPPDATA%\Standivarius.Visual`;
- uninstall identity and AUMID;
- `visual_app.exe` and `visual_diagnostics.exe`;
- process-name-dependent scripts/tests;
- `Local\Standivarius.Visual.App.v1` and `Local\Standivarius.Visual.Setup.v1`;
- `VisualDetailWindow` and existing internal Win32 class names;
- C++ `visual::` namespaces and internal target names;
- persistent root `%LOCALAPPDATA%\Standivarius\Visual`;
- registry policy root `SOFTWARE\Standivarius\Visual`;
- existing `VISUAL_*` environment/build contracts;
- existing `visual_*` schema/diagnostic fields;
- deployed service identifier `doxa-visual-assistant`.

### C — migrate later, only with explicit backwards-compatible handling

These may be renamed in a future major migration if there is a concrete benefit:

- persistent settings/log/setup path;
- registry policy path;
- public/deployment environment variable names;
- backend/schema field names;
- executable/process names;
- package ID/install root/AUMID.

Any such migration should use explicit aliases, dual-read/migrate-once logic, schema versioning or an installer-supported migration path. It should not be a search-and-replace exercise.

### D — historical

Leave historical evidence unchanged:

- published tags and GitHub releases;
- old release notes;
- dated evidence and benchmark artefacts;
- previous conversation archives/handovers;
- historical names quoted in release or test evidence.

## Exact safe changes implemented

1. User-facing runtime branding was completed as Vision where residual Visual strings remained.
2. PE metadata now has:
   - `ProductName = Standivarius - Vision`;
   - `FileDescription = Standivarius - Vision low-vision magnification software`;
   - `InternalName = Visual` retained deliberately.
3. Velopack `packTitle` is now `Standivarius - Vision`.
4. Velopack `packId = Standivarius.Visual`, `mainExe = visual_app.exe` and `channel = alpha` remain unchanged.
5. Release workflow display labels/release friendly name now say Vision, while package/evidence filenames and existing `VISUAL_RELEASE_VERSION` contract remain unchanged.
6. Current product/programme/support docs were reconciled to Vision, without globally renaming path/package/schema contracts.
7. Generated Vision assistant knowledge was rebuilt from the current sources.
8. A compatibility guard was added at:
   - `app/packaging/verify-vision-brand-compatibility.ps1`
   - invoked by `app/build.ps1`;
   - invoked by `app/packaging/package.ps1`.

The guard fails if key retained identities are changed accidentally.

## Validation performed

### Build and unit/integration tests

Local candidate version: `0.1.0-alpha.12`

- Release build: **PASS**
- CTest: **9/9 PASS**
- compatibility guard before build: **PASS**
- assistant source mirror check: **PASS**
- mirror: **25 files / 107 chunks**
- mirror digest: `872dfb1c7e5bfc9a2e970c0269dd4c7bc7dec88f3edb6edf3fe52b8bb69ab460`

Candidate PE metadata:

| Field | Candidate |
|---|---|
| FileVersion | `0.1.0-alpha.12` |
| ProductVersion | `0.1.0-alpha.12` |
| ProductName | `Standivarius - Vision` |
| FileDescription | `Standivarius - Vision low-vision magnification software` |
| InternalName | `Visual` |

### Candidate package comparison

The candidate was packaged locally with the pinned Velopack 1.2.0 binaries and was **not published or installed**.

| Identity | Installed alpha.11 | Vision candidate alpha.12 | Result |
|---|---|---|---|
| Package ID | `Standivarius.Visual` | `Standivarius.Visual` | same |
| Main executable | `visual_app.exe` | `visual_app.exe` | same |
| Channel | `alpha` | `alpha` | same |
| AUMID | `velopack.Standivarius.Visual` | `velopack.Standivarius.Visual` | same |
| Friendly title | `Standivarius - Visual` | `Standivarius - Vision` | intentionally changed |

The candidate `sq.version` passed the compatibility guard.

### Installed state protection

No candidate Setup was run and no live update was scheduled. The installed alpha.11 metadata and user settings remained in their existing locations and were not modified by this task.

## Upgrade consequences

With this boundary, a future published Vision-branded alpha remains in the existing Velopack product lineage and can use the existing update path rather than creating a second installed product.

Expected continuity:

- same install root;
- same update/uninstall identity;
- same executable target for shortcuts/update lifecycle;
- same persisted settings and setup state;
- same policy/environment/schema contracts;
- visible branding changes to Vision.

A full physical alpha.11 -> future published Vision update should still be run before declaring the next public release accepted, specifically to verify how Velopack rewrites the existing shortcut and Apps & Features display title during a real update. That publication-time acceptance test is deliberately separate from this local compatibility assessment.

## Packaging-tool observation

The normal local packaging script restored the pinned `vpk 1.2.0` tool successfully, but `dotnet tool run vpk` then failed because the local .NET tool shim was unavailable even though `dotnet tool list --local` reported vpk.

For this assessment, packaging was completed by invoking the exact pinned vpk DLL directly with the same pack arguments. This proves the package metadata/compatibility boundary but does **not** resolve the local-tool shim issue.

Treat that as a separate release-tooling maintenance item; do not conflate it with the Vision naming migration.

## Deliberately retained Visual identifiers

The presence of Visual in the following places is intentional and should not be treated as incomplete branding:

- `Standivarius.Visual`;
- `visual_app.exe`;
- `visual_diagnostics.exe`;
- `%LOCALAPPDATA%\Standivarius\Visual`;
- `SOFTWARE\Standivarius\Visual`;
- `VISUAL_*`;
- active `visual_*` schema keys;
- internal C++ namespaces/target names/window classes/mutexes;
- `doxa-visual-assistant`;
- historical release notes and evidence.

## Decision

**Compatibility assessment: settled for the current alpha.**

Proceed with ordinary Vision programme work using the live programme documents. Do not rename the retained compatibility identifiers casually. If a later commercial/major-version requirement justifies removing the Visual internals, treat that as a separate migration project with backwards-compatible transition design and its own update/uninstall tests.
