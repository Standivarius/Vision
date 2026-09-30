# Visual terminology + contextual assistance validation — 2026-09-27

Baseline before this pass: `84b0d4a` (`visual: add low-vision workspace settings and context view`).

## Implemented

- user-facing terminology aligned around Zoom Level, Tracking, Pointer, Text Cursor, Keyboard Focus, View Locator, Colour & Contrast, and 1x View / Return;
- `Follow activity` removed from user-facing UI in favor of `Enable tracking` plus explicit tracking sources;
- Context/Detail/Reference kept for now, with plain-English role descriptions;
- `Detail View` rectangle renamed `View Locator`;
- Visual Settings now links directly to Help / Ask Visual;
- `Ctrl+Alt+H` and the Detail right-click menu open Help / Ask Visual;
- local help vocabulary covers Screen Roles, Tracking, View Locator, 1x View / Return, Freeze View / Hooked Areas, Colour & Contrast, shortcuts, settings, Reference, and Zoom Level;
- Freeze View help explicitly states that Visual does not currently implement ZoomText Freeze View / SuperNova Hooked Areas and does not falsely claim Reference is equivalent;
- first-use Context/Detail + View Locator hint with persistent suppression state;
- first-use 1x View / Return hint with persistent suppression state;
- hint window exposes its full message as an accessibility name and raises `EVENT_SYSTEM_ALERT`;
- optional provider-neutral Ask Visual HTTPS fallback behind `VISUAL_ASSISTANT_ENDPOINT`;
- known questions are answered locally before any remote request;
- remote context is structured/minimal: zoom, tracking/highlight flags, colour mode, monitor count, and role-assignment booleans; no monitor device IDs, screenshots, document content or typed text;
- no provider credential embedded in Visual; online help remains non-critical.

## Build and automated tests

Canonical Release build reported Visual `0.1.0-alpha.6`.

CTest: **9/9 passed**:

1. core_pipeline_tests
2. locator_model_tests
3. poi_arbitration_tests
4. view_return_tests
5. settings_model_tests
6. settings_store_tests
7. help_catalog_tests
8. assistant_client_tests
9. diagnostics_json

New tests verify:

- incumbent-term/help matching;
- truthful Freeze View migration response;
- View Locator and Tracking query recognition;
- unknown-query fallback behavior;
- assistant context privacy (no raw monitor device identifiers);
- known Ask Visual questions stay local;
- offline unknown questions fail soft to local help;
- assistance suppression state persists in `settings.ini`.

## Live Dell validation

- normal Visual launch remained healthy with Detail + Context View Locator active;
- View Locator capture affinity remained `0x11` (`WDA_EXCLUDEFROMCAPTURE`);
- first-use Context/Detail hint displayed once and persisted `ScreenRolesExplained=1` and `ViewLocatorExplained=1`;
- later restart did not re-show the screen-role hint;
- first `Ctrl+Alt+0` use displayed the 1x View / Return hint and persisted `OneXReturnExplained=1`;
- Visual returned to 2x after the second `Ctrl+Alt+0` command;
- telemetry observed 31 1x frames and then resumed 2x with zero Present failures;
- Visual Settings displayed the renamed terminology and the Help / Ask Visual button;
- Help / Ask Visual opened through `Ctrl+Alt+H` and through the Settings button;
- local question `Where is ZoomText Freeze View?` returned the truthful local migration answer;
- an unknown question with no configured endpoint returned the safe local-only fallback;
- no `VISUAL_ASSISTANT_ENDPOINT` was configured on the Dell during this validation, so no external AI request was made.

## Graphics health

Bounded 2x health check on the final build:

- exit code 0;
- rendered frames present;
- zero Present failures;
- explicit `health_check_pass` event.

## Not implemented in this pass

- NVIDIA/Nemotron backend connection (server-side endpoint/key still required and must be tested separately);
- proactive LLM suggestions;
- screenshot/screen-content AI context;
- Freeze View / Hooked Areas feature parity;
- additional settings profiles merely for incumbent parity;
- Doxa three-screen workspace concept.

The Doxa three-screen workspace remains a separate future track and should inherit this terminology/help infrastructure when implementation begins.
