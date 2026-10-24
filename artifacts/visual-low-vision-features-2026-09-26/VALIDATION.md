# Visual low-vision workspace feature validation — 2026-09-26

Source baseline before feature work: `66432a1` (`release: pin dependencies and emit supply-chain evidence`).

## Implemented

- zoom levels 1x, 1.5x, 2x, 3x and 4x;
- native keyboard-accessible Visual Settings window (`Ctrl+Alt+S` and Detail right-click menu);
- persisted settings under `%LOCALAPPDATA%\Standivarius\Visual\settings.ini`;
- independent pointer, text-caret and keyboard-focus follow controls;
- independent pointer, caret and focus marker visibility;
- Context-screen Detail View rectangle with optional translucent shading;
- Detail View indicator protected with `WDA_EXCLUDEFROMCAPTURE` and hidden if capture exclusion cannot be applied;
- Detail appearance modes: Normal, High contrast, Inverted colours and Grayscale;
- persisted Context, Detail and optional Reference display roles;
- display-role changes are restart-bound; other settings apply live;
- build script now always reapplies the canonical default version when no explicit version is supplied, preventing stale CMake test-version leakage.

## Build and automated tests

Final Release build reported canonical version `0.1.0-alpha.6`.

CTest: **7/7 passed**:

1. core_pipeline_tests
2. locator_model_tests
3. poi_arbitration_tests
4. view_return_tests
5. settings_model_tests
6. settings_store_tests
7. diagnostics_json

New coverage includes 1.5x geometry (1280x720 viewport on a 1920x1080 source), 3x geometry (640x360), setting-model validation, display-role validation and full settings-store round trip.

## Live Dell validation

Dell display topology during validation:

- DISPLAY1: primary, 1920x1080, 150% DPI;
- DISPLAY2: secondary, 1920x1080, 100% DPI.

Observed with the normal Visual session:

- Detail full-screen on DISPLAY2;
- Context Detail View indicator visible on DISPLAY1;
- `GetWindowDisplayAffinity` for the indicator returned `0x11` (`WDA_EXCLUDEFROMCAPTURE`);
- first rendered frames reported `present_hr=0`;
- settings window exists as a normal native top-level UI but stays hidden until requested.

### Live settings apply/persistence

Applied from the settings UI:

- zoom 1.5x;
- High contrast mode;
- keyboard-focus following off;
- Context shading off.

The values were written to `settings.ini` immediately. The Context rectangle resized to the correct 1.5x source region. After a full Visual restart, the first telemetry frame still reported zoom `1.5` and `present_hr=0`, proving settings persistence.

Defaults were then restored: zoom 2x, all follow/marker controls enabled, Context indicator and shading enabled, Normal appearance.

### Context indicator toggle

- disabled in Settings -> indicator hidden;
- re-enabled -> indicator visible again.

PASS.

### Display-role persistence

Saved Context=DISPLAY2 and Detail=DISPLAY1 while Visual was running. The active capture session intentionally remained unchanged. After restart:

- Detail moved to DISPLAY1;
- Context indicator moved to DISPLAY2;
- indicator affinity remained `0x11`;
- first frame reported zoom 2 and `present_hr=0`.

Roles were then restored to Context=DISPLAY1, Detail=DISPLAY2, Reference=None.

PASS.

### Fractional/3x graphics health

Bounded health checks on the final feature build:

- 1.5x: exit 0, rendered frames present, zero Present failures;
- 3x: exit 0, rendered frames present, zero Present failures.

PASS.

### Exact normal-view return

The existing return smoke produced:

- stable 1x phase;
- normal viewport `0,0,1920,1080`;
- exact restoration of the prior 2x viewport with zero coordinate error;
- zero Present failures;
- zero invalid decisions when analysis is restricted to actual numeric frame rows.

The pre-existing smoke script counts telemetry `# event=` rows as `ViewportAction::Invalid`; the two new feature lifecycle events therefore make its raw `invalid_frames` counter nonzero. Product frame behavior is correct; the untracked smoke script was not modified.

## Browser editing smoke A/B

The current feature build and an untouched detached `66432a1` baseline were tested with the same Edge browser-editing smoke on the same machine/session.

Current feature build:

- 167/166 phase frames in two runs;
- zero semantic caret frames during the scripted phase;
- zero Present failures.

Untouched `66432a1` baseline:

- 174 phase frames;
- zero semantic caret frames during the scripted phase;
- zero Present failures.

Therefore the current Edge/UIA caret-smoke failure is **not introduced by this feature work**. The repository already documents Chromium/Edge editing-caret reliability as open. Tracking/arbitration code was not changed to mask this environmental/pre-existing condition.

## Final machine state

- no `visual_app` process running;
- persisted user defaults: 2x, all follow/marker controls enabled, Context indicator+shade enabled, Normal appearance;
- Context=DISPLAY1;
- Detail=DISPLAY2;
- Reference unassigned.
