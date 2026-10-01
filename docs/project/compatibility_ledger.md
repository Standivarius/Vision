# Vision workplace compatibility ledger

Living document. Update this ledger when an application version, Windows build, Vision tracking/provider implementation, display/DPI topology, or recovery behaviour materially changes.

Current host baseline (2026-09-30):
- Host: MARIUS-DELL
- Windows: 10.0.26200.0
- Physical displays: 2 x 1920x1080
- DPI: DISPLAY1 144 DPI / 150%; DISPLAY2 96 DPI / 100%
- Office Click-to-Run: 16.0.20326.20158, O365BusinessRetail, x64, en-US
- Microsoft Edge currently installed: 154.0.4258.48
- Microsoft Teams currently installed: 26225.1806.5074.1452
- Adobe Acrobat/Reader: not found in the standard installed paths checked
- Current development regression baseline after #20 command/UI work: 21/21 CTests + 8/8 canonical two-screen acceptance PASS at lab/benchmarks/integrated_app/runs/2026-09-30_23-27-14__two_screen_acceptance.

## Status vocabulary

- Known-good — the named workflow/version/topology has current direct task evidence with no material qualification.
- Bounded-good — the named narrow scenario passes, but adjacent workflows, versions or control types remain untested.
- Known issue — a reproducible current failure or materially degraded compatibility condition exists.
- Untested — no direct evidence supports a compatibility claim.
- Historical — useful older evidence exists, but a current version/environment change prevents carrying the status forward unchanged.

A row is about the exact workflow named. It must not be generalised to the entire application family.

## Ledger

| Family / application | Version / environment | Workflow tested | Evidence-provider health | Movement / overlay / render | Recovery | Status | Evidence and boundary |
|---|---|---|---|---|---|---|---|
| Vision Settings + Help | Current working tree; Windows 26200; 144/96 DPI | Open Settings/Help, duplicate launch/restart, move both UI windows across 150% to 100% displays | Native Win32/UIA controls remain exposed; expected Settings and Help content visible after both DPI transitions | UI surfaces remain accessible; no runtime Present failures in associated acceptance | Restart and normal exit pass | Known-good | 2026-09-30_23-23-00__ui_surface_smoke, 2026-09-30_23-23-05__ui_dpi_smoke, and canonical 2026-09-30_23-27-14__two_screen_acceptance. This proves Vision's own UI surfaces, not arbitrary Windows applications. |
| Standard focusable controls / deterministic focus fixture | Windows 26200; two-display Dell | Button/checkbox keyboard-focus navigation | UIA focus selected on 109/109 focus-only frames | Locator visible 109/109; zero invalid viewport decisions; zero Present failures | Not a lifecycle test | Bounded-good | lab/benchmarks/integrated_app/runs/2026-09-23_08-06-44__focus_smoke: 578 frames total. This is a deterministic standard-control workload, not broad Windows-shell certification. |
| Microsoft Edge HTML textarea — historical validated build | Edge 153.0.4234.48; local deterministic HTML textarea; Vision 2x | Keyboard caret movement in ordinary textarea | UIA TextPattern present; 100% UIA-caret presence in three corrected runs | Caret selected 88.3–89.4%; zero Present failures | Clean Vision exit; no forced cleanup | Historical / bounded-good | artifacts/2026-09-29__gpt-5.6-sol__vis001_chromium_edge_caret_validation_v1.0.md; three consecutive runs at 2026-09-29_16-38-16, 16-38-35, 16-38-51. Does not cover rich editors, contenteditable frameworks or later Edge versions. |
| Microsoft Edge HTML textarea — current build | Edge 154.0.4258.48; Windows 26200; isolated local fixture; forced renderer accessibility | Same narrow textarea semantic-caret prerequisite | Regression signal: page textarea still appears as Chrome Textfield with TextPattern, but AutomationId is empty, IsKeyboardFocusable false, focused element remains RootWebArea/Document, selection has no bounds, and BoundingRectangle is infinite. Same result with force-only, force+UiaProvider and force-disable-UiaProvider browser modes. | Vision semantic-caret scenario cannot reach the previous deterministic precondition; pixel capture/render itself is not implicated | Not reached | Known issue | Current run-browser-editing-smoke.ps1 fails before Vision tracking because its old AutomationId=e locator no longer exists. Follow-up probes show this is not merely a locator rename: current Edge UIA geometry/focus for the Textfield is unusable in this fixture. Do not claim current Edge textarea caret support until a current-browser path is proven. |
| Microsoft Edge / Chromium rich editors, contenteditable, ChatGPT-style editors | Current Edge 154 and other Chromium versions | Rich/custom editing | Not directly measured | Not directly measured | Not directly measured | Untested | Historical textarea evidence never covered rich editors. The source-pixel observation in ChatGPT/browser was a raster-quality observation, not semantic caret evidence. |
| Microsoft Word — visual/raster quality only | Office version was not frozen in the human visual record; current install is 16.0.20326.20158 | Read/edit view visually inspected at 2x and 4x | Semantic caret/focus not established by this evidence | Baseline Vision mode 0 judged very good at 2x and better than ZoomText at 4x | Not tested | Bounded-good (visual only) | artifacts/2026-09-30__gpt-5.6-sol__raster_reconstruction_experiment_v0.1.md. Do not infer Word caret/focus compatibility from the visual-quality result. |
| Microsoft Word — caret/focus editing workflow | 16.0.20326.20158; Windows 26200; two-display Dell | Long-line typing, horizontal/vertical caret movement, selection, ribbon focus, return to editing | Word editing surface is a focusable Win32 Document with UIA TextPattern; caret present 100% during editing | Semantic caret selected 98.9%; locator visible 177/179 editing frames; ribbon focus selected; return-to-editing semantic caret observed; zero Present failures | Clean Vision exit; Word closed without saving | **Bounded-good** | Canonical run: lab/benchmarks/integrated_app/runs/2026-10-01_06-57-56__word_editing_smoke. This is strong evidence for ordinary Word document editing/ribbon return, not every Word dialog/add-in/layout mode. |
| Microsoft Excel | 16.0.20326.20158; Windows 26200; two-display Dell | Cell navigation, formula-bar caret editing, return to grid | Active cells expose GridItem/SelectionItem/TextPattern; formula bar exposes TextPattern. Grid target is represented primarily through Win32 caret + UIA focus; formula editing exposes semantic caret | Grid tracked-target ratio 98.7% across 26 distinct cell rectangles; formula caret present 88.7%, semantic caret selected 97%; locator present throughout; zero Present failures | Clean Vision exit; workbook closed without saving | **Bounded-good** | Canonical run: lab/benchmarks/integrated_app/runs/2026-10-01_06-57-30__excel_editing_smoke. Covers ordinary grid/formula-bar work, not charts, dialogs, complex panes or add-ins. |
| Microsoft Outlook classic desktop | Current install 16.0.20326.20158 | Message list/reading/compose, caret/focus transitions | No current direct evidence | No current task evidence | Untested | Untested | Requires dedicated task run. |
| Microsoft Teams | 26225.1806.5074.1452 | Chat compose/navigation, meeting controls, modern web-app focus/caret | No current direct evidence | No current task evidence | Untested | Untested | High-value compatibility family because modern web accessibility surfaces can differ from standard Win32/UIA controls. |
| PDF workflow | No Adobe Acrobat/Reader found in standard paths checked; Edge PDF remains possible but untested | Reading/navigation/search/form editing | No current direct evidence | No current task evidence | Untested | Untested | Select the actual pilot PDF application before testing rather than assuming Adobe. |
| Windows shell/dialogs broadly | Windows 26200 | Shell menus, common dialogs, Settings, notifications, Explorer | Only standard focus-fixture and Vision-own-UI evidence currently direct | Partial evidence only | Partial | Untested / partial evidence | Do not generalise the deterministic standard-control focus smoke into a broad shell claim. |
| Pilot user's essential application | Not yet named | Daily essential workflow | Unknown | Unknown | Unknown | Untested | Must be identified during pilot/assessor work; this row becomes release-critical once known. |

## Current compatibility priorities

1. Edge 154 semantic caret regression — determine whether this is an Edge accessibility-provider regression limited to the isolated local/file fixture, a changed browser security/accessibility condition, or a compatibility class requiring a Vision fallback. Do not add browser-specific production code merely to recover the old harness.
2. Word application-specific caret/focus task — strongest next Office test because Word already has positive visual-quality evidence.
3. Excel formula/cell workflow — materially different semantic/focus surface and a strong low-vision use case.
4. Teams / modern web application workflow — needed before claiming workplace breadth.
5. Actual PDF application and pilot essential app — select from real pilot workflow rather than an arbitrary benchmark application.

## Release rule

No application family becomes supported because a related application or generic control passed. Compatibility claims must name:
- application and version;
- Windows build;
- display/DPI topology;
- workflow/control type;
- evidence provider(s);
- movement/overlay behaviour;
- recovery behaviour where relevant;
- evidence path.

A material application update reopens the relevant row until a bounded current-version check passes.

### Edge 154 follow-up — transport check
The same unusable textarea UIA state reproduces over localhost HTTP as well as file://: empty AutomationId, non-focusable Chrome Textfield, invalid/infinite bounding rectangle and no selection bounds. This rules out the old file-URL fixture as the simple explanation. The result remains a browser/accessibility-provider compatibility issue; it is not evidence of Vision capture/render failure.
