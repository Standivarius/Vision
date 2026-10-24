**Recommendation: proceed with a narrow, behaviour-preserving extraction, but modify the proposed architecture before expanding its capabilities.** The central risks are input correctness, evidence ownership, geometry and recovery—not whether D3D11 can draw additional magnified windows.

**1. Executive assessment**

1. **The focused product boundary is coherent, but the target cohort remains unproven.** Magnifier-only products establish a legitimate category. They do not establish that Vision’s combination of 1x–4x, no integrated speech and Context + Detail covers a commercially useful cohort.

2. **Keep Context + Detail as the default two-monitor preset and initial entry hypothesis.** Do not make it an architectural invariant or assume an unmagnified context screen is useful to every low-vision user.

3. **Approve extraction of the existing relationship before broad hardware qualification.** Physical four-monitor testing, identical-panel matching, user preference between ownership models and matched 2x text quality need not block separating existing responsibilities.

4. **Reject the claim that the current single-monitor fallback proves interactive same-monitor magnification.** Capture exclusion addresses recursion; it does not establish correct clicking, dragging, selection, scrolling or focus through a transformed image.

5. **Add an explicit geometry contract.** Current crop dimensions depend on source size and zoom, while presentation stretches that crop to the destination. Unequal resolutions, portrait displays and partial-screen views therefore expose a foundational assumption that monitor enumeration alone cannot resolve.

6. **Use one explicit movement owner initially, with per-view retained state.** Shared evidence must not give every view permission to move. Active command target, source binding, movement ownership and native pointer location are separate concepts.

7. **Keep WGC/D3D11 as the default graphics path, not a universal compatibility promise.** Share capture and GPU resources within a compatible device domain. Do not commit either to one device per view or to one immutable global device for every hardware configuration.

8. **Promote compatibility, recovery and manual navigation to release-critical scope.** The proposed P1 treatment understates their importance. More monitors and stronger presets cannot compensate for inaccessible dialogs, unexplained jumps or lost configuration after undocking.

9. **Investigate raster quality first, without presuming sharpening will succeed.** Semantic enhancement and clean-text presentation are alternative later responses to demonstrated problems, not mandatory successive stages.

**Evidence basis.** I read the frozen package, relevant live runtime/settings/tracking/viewport/overlay code, test sources, saved acceptance evidence and decision-changing public sources. I did not inspect another independent review. The workspace is modified relative to HEAD `0495a3b`; conclusions refer to the live files.

**Test results reproduced during this review:** the existing `core_pipeline`, `locator_model`, `poi_arbitration`, `view_return` and `settings_model` test binaries passed. I did not rebuild or rerun physical acceptance in this read-only session. Saved September 29 evidence confirms 8/8 acceptance steps, 9/9 CTests, zero Present failures in the cited smoke and exact viewport return. No files were changed.

**2. Critical challenges — where the proposal currently overclaims**

| Observed repository fact | Decision implication |
|---|---|
| `CaptureRunner` owns WGC lifecycle, the render loop, both evidence providers and `ViewController`. | Extraction is justified; duplicating this object would duplicate expensive sampling and couple view failures. |
| Follow-disabled candidates are removed before selection; the selected candidate then supplies the sole locator. | Visibility and following are separate settings but not independent runtime capabilities. |
| The viewport uses `source.width()/zoom` and `source.height()/zoom`; the renderer maps it across the destination. | Effective magnification and aspect ratio depend on destination geometry. |
| The single-monitor window records capture-exclusion success but does not enforce it. No transformed-input path is present in the inspected runtime. | This is a development fallback, not a qualified interactive magnifier mode. |
| Any `WM_DISPLAYCHANGE` destroys the Detail window and ends the application. | Existing recovery means shutdown/relaunch, not continuous recovery or isolation of an affected view. |
| Startup replaces unavailable roles with defaults; single-monitor startup clears persisted roles. | Temporary topology changes can overwrite user intent. |
| UIA candidates do not populate the available `identity` field; unchanged process/geometry preserves the old activity timestamp. | Ownership cannot safely depend on the existing candidate model alone. |
| The graphics mutex covers rendering through `Present(1,0)`. | Naively sharing this path can couple capture and all outputs to a blocking presentation. |

These observations are directly supported by [the capture and interaction loop](C:/dev/Vision/app/src/main.cpp:637), [viewport geometry](C:/dev/Vision/app/src/core/view_controller.h:36), [window creation and role resolution](C:/dev/Vision/app/src/main.cpp:1018), and [UIA sampling](C:/dev/Vision/app/src/tracking/uia_evidence_provider.h:101).

Three further challenges matter:

- **“Independent per-view state” does not mean independent user intent.** A user can retain several views while deliberately moving only one. Conversely, a stable view may continue receiving live pixels.
- **“More monitors” does not imply more useful magnified surfaces.** Two work sources feeding one selected Detail, one source feeding two views and two independent source/output pairs are different workloads. They require separate evidence.
- **The baseline tests need more precise claims.** Recounting the saved mouse smoke produced 358 numeric frames, but only **50 selected-pointer frames**; 308 had no selected POI and nevertheless carried the default Pointer source value. The `locator_visible` field measures the shader POI cue, not successful drawing of the separate Context View Locator. The same smoke records DPI-virtualized 1280×720 primary bounds while runtime viewport evidence uses 1920×1080. These limitations do not invalidate the run; they limit what it proves. See [the smoke harness](C:/dev/Vision/app/run-integrated-smoke.ps1:1) and [raw telemetry](C:/dev/Vision/lab/benchmarks/integrated_app/runs/2026-09-29_17-38-23__mouse_viewport_smoke/visual_app_telemetry.csv).

The foundation documents also contain obsolete Doxa-specific assumptions and pre-integration milestones. Reconcile them before they become implementation instructions. Retire the plan’s percentage-complete estimates: they have no dependable relationship to remaining compatibility or product risk.

**3. Product-scope corrections — answers to A1–A6**

The better bounded framing is:

> **Vision provides predictable visual access for a defined set of Windows work tasks, initially through ordinary multi-monitor Context + Detail, with reliable orientation and recovery.**

That framing is narrower and more testable than “a smaller general-purpose magnifier supporting arbitrary 2–4-monitor arrangements.”

Magnifier-first is defensible: Freedom Scientific explicitly distinguishes magnification without speech from Magnifier/Reader. However, the cited Office study’s ten participants **all requested speech narration**. It supports the context/navigation problem, but cannot validate a speech-free product boundary. Neither observation justifies adding a full screen reader. [ZoomText FAQ](https://support.freedomscientific.com/Services/TrainingAndCertification/ZoomTextFAQs), [Office interaction study](https://pmc.ncbi.nlm.nih.gov/articles/PMC8871469/)

| Disposition | Corrected scope |
|---|---|
| **First-product must-have / P0** | Dependable capture and presentation; pointer/caret/focus compatibility in named tasks; independent visibility and following; predictable movement ownership; exact temporary overview/return; manual viewport exploration; emergency suspend/exit; basic colour adjustment; accessible configuration; persistent intended workspace; topology recovery; diagnosable failures. |
| **P0 for a claimed 2–4-monitor release** | Qualified configurations on two, three and four physical displays, including unequal geometry and representative adapter arrangements. Internal configurability alone is insufficient. |
| **P1 after core behaviour is dependable** | Additional comfort presets, simple application overrides, broader zoom choices, a qualified contextual single-monitor mode, configuration export/import. Promote particular items if pilot deployment requires them. |
| **Preserve a small seam** | Rectangular destinations, explicit source regions, independent frame lifetime, effective-settings resolution and non-raster content presentation. |
| **Defer** | Pinned live regions, snapshot references, dynamic context relocation, linked outputs, presentation modes and clean-text display until task evidence selects among them. |
| **Drop from the initial programme** | Span as a pillar, large style editors, situation automation, camera/media ecosystems, universal semantic reconstruction and screen-reader/Braille parity. |

**Overvalued:** the number of monitors as differentiation, a mandatory single-monitor mode before proving the initial cohort, and architecture provisions for every conceivable future feature.

**Undervalued:** manual pan without moving application focus, stationary target visibility, recovery without losing assignments, accessible error handling, settings rollback, application dialogs/menus, and compatibility with users’ existing accessibility tools.

**Missing:** a supported-task envelope, a clear magnification definition across different screens, transient-versus-persistent state, failure-visible stale-image handling, and a usability benchmark against Windows Magnifier plus native application zoom.

Windows already provides full-screen, lens and docked views, configurable following and temporary overview. Vision must demonstrate additional task value against that baseline, not merely against incumbent complexity. [Microsoft Magnifier documentation](https://support.microsoft.com/en-us/accessibility/windows/magnifier/use-magnifier-to-make-things-on-the-screen-easier-to-see)

**Context + Detail:** retain it as the initial default, with an easy reassignment/exit path. Its value is a hypothesis about reduced disorientation. Falsifiers include an unreadable context screen, excessive gaze movement, difficulty operating on one screen while viewing another, or no improvement over the user’s existing workflow.

**Single-monitor scope:** a contextual/lens/fixed mode can remain post-core for a clearly described 2–4-monitor first product. Nevertheless, loss of a display must leave the user able to recover, suspend Vision and restore the prior workspace. A broadly marketed standalone magnifier would require a qualified single-monitor workflow; the present fallback does not qualify. If demand emerges, evaluate one fixed inspection window first rather than eight geometries.

**Minimum orientation presets:** use two persistent presets—**Standard** and **Strong**—plus an independent **Find now** command. Give pointer, caret and focus distinct shapes with contrasting outlines; avoid flashing by default. Retain separate per-target visibility/follow controls and a small size adjustment independent of zoom. Presets should change cue appearance, not silently change movement policy.

**Likely assessor/deployment table stakes, still requiring interviews:** adjustable usable magnification, colour comfort, prominent target finding, predictable shortcuts, accessible setup, trial/reset procedures, dependable Office/browser behaviour, signing, controlled updates and portable configuration. Login/UAC access, remote desktops and managed deployment may be purchase vetoes for particular employers even when rarely exercised by the user.

**4. Architecture recommendation — answers to B7, B9, B11 and B12**

The proposed decomposition is directionally correct but incomplete. Add explicit ownership of geometry, scheduling and recovery. These are responsibilities, not a requirement for an elaborate interface hierarchy.

| Responsibility | Owns | Must not own |
|---|---|---|
| **Topology snapshot and binding resolver** | Current displays, paths, geometry, DPI, adapters, availability, matching confidence and topology generation | Viewport motion; changing Windows display configuration |
| **CaptureSource** | WGC item/session/frame pool, source availability, latest owned frame and source generation | Following, zoom, destination window |
| **Evidence service** | One pointer/Win32 sampling path and bounded UIA work; immutable observations and provenance | Selecting the active view |
| **Workspace interaction controller** | Movement eligibility, active command target, ownership transfers, holds and explicit commands | Pixel acquisition or shader execution |
| **ViewSession** | Source binding, viewport, zoom, follow settings, visual settings and temporary return state | Physical monitor identity or a private UIA sampler |
| **Overlay policy** | Independently selected visibility targets and their per-view presentation | Automatic viewport motion |
| **Graphics device context and scheduler** | Device lifetime, immediate-context ownership, GPU frame storage and submission scheduling | Product interaction decisions |
| **Output endpoint** | HWND/swap chain, destination rectangle, presentation and output-local failure | Capture-source identity |
| **Application host** | Workspace activation, settings transactions, commands and coordinated recovery | Detailed tracking heuristics |

A `ViewSession` should reference an output endpoint rather than mean “one physical monitor.” Initially each Detail can occupy one entire output. This preserves a rectangular-window extension without implementing a general compositor.

An unmanaged Reference monitor requires no capture session or fabricated view. It is simply available desktop space with an optional user label.

**Evidence routing must precede per-view arbitration.**

Each observation needs its kind/provider, physical desktop geometry, target process/window or element identity where available, observed time, last meaningful activity time, validity and topology generation. Associate semantic evidence with current foreground/focus context; expire cached evidence when that context becomes invalid.

Route through:

`observation → target/source eligibility → ownership permission → per-view POI arbitration → viewport`

Visibility consumes eligible observations separately.

Rectangle intersection is insufficient when a focused window spans monitors or several views share a source. Use the actual caret/pointer anchor and target context where available. For broad, ambiguous focus rectangles, hold or retain the current binding rather than moving every intersecting view.

Do not equate polling with intent. A stationary caret can be currently observed and worth highlighting without authorizing a new pan. The existing original-timestamp retention is valuable, but it needs separate observation-validity and activity semantics.

Keep UIA off the render and UI threads. Microsoft documents both threading hazards and provider timeout controls. Add bounded requests, provider-health reporting and a tested shutdown path; introduce a separate helper process only if evidence requires stronger isolation. [UIA threading](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-threading), [IUIAutomation2 timeout controls](https://learn.microsoft.com/en-us/windows/win32/api/uiautomationclient/nn-uiautomationclient-iuiautomation2)

**D3D11 sharing decision:** start with a shared device for the currently qualified configuration, with per-source frame storage and per-output presentation resources. Make the device an explicit dependency so another device domain can be introduced without rewriting view policy.

| Alternative | Assessment |
|---|---|
| One device per view | Reject as default: redundant resources, sharing/copy overhead and no guaranteed isolation from a common driver failure. |
| One global device for every configuration | Useful initial implementation, unsuitable permanent invariant. |
| Explicit device domains, initially one | Recommended: share efficiently where proven; add domains for measured adapter or recovery needs. |

WGC must use the appropriate WinRT wrapper for its device. Consumers cannot safely retain a checked-in capture surface indefinitely; an owned frame/cache with clear synchronization is required. Microsoft also requires serialized immediate-context use and documents scheduling considerations for multiple swap chains. [WGC frame lifetime](https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/screen-capture), [D3D11 threading](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-intro), [multiple swap chains](https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/dxgi-multiple-swap-chains)

Do not carry the present-wide mutex into a multi-output design unchanged. A slow or occluded output must not become the clock for evidence sampling or other outputs. Measure scheduling before selecting thread count, buffer count or presentation strategy.

On hybrid/USB systems, sharing a device does not eliminate cross-adapter transport. Windows documents hardware-dependent cross-adapter presentation paths and copy costs. Ordinary shared-resource APIs are not evidence of universally cheap inter-adapter sharing. [Microsoft cross-adapter documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/supporting-caso)

**Failure boundaries:** loss of one capture source suspends its consumers; loss of an output suspends that endpoint; device removal rebuilds its device domain. Independent devices can reduce some failure coupling, but cannot promise survival of a system-wide graphics reset.

**Same-monitor decision: insufficient evidence for first-class interactive support.** Allow source and destination equality in the conceptual model, but gate activation by a qualified capability. Required proof includes recursion exclusion, click/drag/selection/wheel correctness, cursor alignment, focus retention and recovery.

`WDA_EXCLUDEFROMCAPTURE` only addresses capture participation. Microsoft’s input-transform API is a separate mechanism with UIAccess requirements; it is not an established drop-in solution for Vision’s arbitrary multi-view renderer. [Capture exclusion](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity), [input transformation](https://learn.microsoft.com/en-us/windows/win32/api/magnification/nf-magnification-magsetinputtransform)

Also examine **cross-view recursion**: A→B and B→A can form a capture cycle even though neither binding is individually “same-monitor.” Exclusion and configuration validation must consider all Vision outputs.

**5. Active-view and crossing policy — answers to B8 and C15**

| Model | Benefit | Principal failure | Decision |
|---|---|---|---|
| Every view follows shared evidence independently | Minimal coordination | Multiple simultaneous pans; duplicated responses; ambiguous hotkeys | Reject as default |
| Each view follows only its local source | Clear spatial limits | Several views can still react to stale or overlapping semantic evidence | Useful eligibility rule, insufficient ownership model |
| Explicitly selected owner only | Predictable, easy to explain and test | Extra switching effort | Safe initial/manual policy |
| One transferable owner with explicit override | Follows deliberate work across sources while retaining stable views | False transfers if “fresh evidence” is mistaken for intent | Recommended default hypothesis |

The current ZoomText guide documents a single moving view in both MultiView modes. Local mode transfers activity between desktops; Global mode lets the selected view range across desktops. These are useful precedents, not proof that Vision users prefer either policy. [ZoomText 2026 guide, pp. 85–87](https://support.freedomscientific.com/content/documents/manuals/ZoomText/ZoomText_User_Guide_English_US.pdf)

Start with one movement owner per workspace. Preserve the possibility of later independently controlled groups without implementing them.

Recommended rules:

- Explicit view selection wins and produces a visible cue.
- Pointer activity on a **work source** can select that source’s associated Detail.
- Entering a passive Detail output does not automatically rebind it to capture itself.
- On leaving a pointer-owned source, retain the viewport and the pointer-intent barrier. Do not let removing the pointer candidate revive older semantic evidence.
- Transfer on credible new keyboard/focus activity in another eligible source, not merely a newly polled rectangle.
- Inactive views retain viewport state but may continue showing live content.
- Manual pan and inspect/return temporarily suppress automatic movement according to explicit state.
- Zoom, colour and follow commands target the selected view. Emergency suspend/exit remain workspace-wide.

For Context A → Detail B, activity on **A** controls the view on **B**. “Active view equals the monitor containing the native pointer” would be wrong.

Keep these distinct:

1. selecting the controlled view;
2. rebinding that view to another source;
3. moving the native pointer.

An explicit “switch view” command should not silently warp the pointer. A separate monitor-jump command can be added and tested.

**Architecture now:** owner identity, transfer reasons, explicit selection, pointer-leave hold, manual override and topology invalidation.

**Later UX experiments:** dwell thresholds, resistance, edge sounds, cue strength and cursor warping. Resistance affects real application input and dragging; it must not become a renderer dependency. Dolphin documents Mouse Buffer for accidental crossing, but that does not validate Vision’s preferred threshold or default. [Dolphin multiple-monitor training](https://learn.yourdolphin.com/supernova-magnifier-speech?lesson=multiple-monitors)

**6. Renderer and text-quality decision — answers to C16–C17**

Keep captured raster as the ordinary rendering path. First establish correct scaling, then compare modest reconstruction alternatives.

The Word observations establish a perceived softness problem at 4x and an attractive incumbent result at 2x. They do **not** establish:

- that a particular reconstruction filter will close the gap;
- that visible sharpness corresponds to better sustained reading;
- that xFont’s proprietary mechanism is semantic rerendering;
- that the photographed comparison controls physical scale, camera processing and source rasterization.

The appropriate sequence is therefore:

1. correct geometry, pixel alignment and colour handling;
2. controlled raster reconstruction experiments;
3. qualification by readability and motion;
4. choose targeted semantic enhancement **or** clean-text assistance only if an identified task remains inadequately served.

Do not require semantic scene enhancement before trying clean text. A separate text aid may address a narrow task with less synchronization and placement risk.

Before implementing a new quality path, compare:

| Experiment | Controls and outcomes |
|---|---|
| Matched static text | Same document, font, application zoom, DPI, physical destination size and product settings; 1x, 1.5x, 2x, 3x, 4x. |
| Reconstruction candidates | Current linear filter against a small number of alternatives; inspect halos, missing strokes, punctuation, digits, colour fringes and glyph deformation. |
| Moving content | Caret navigation, scrolling and panning; measure shimmer, temporal instability and frame cost. |
| Real reading/editing | Low-vision users, task accuracy, sustained comfort, task time and preference; appearance ratings alone are insufficient. |
| Native application zoom | Compare larger source text plus lower screen magnification against magnifying a small raster. |

Use Word and Excel as well as browser content. Dolphin documents that TrueFonts has application-dependent availability and falls back to Standard smoothing in hardware-accelerated browsers. [Dolphin rendering guidance](https://learn.yourdolphin.com/supernova-for-educators-course?lesson=3.-magnification)

**These experiments gate renderer changes and release-quality claims, not the source/view extraction.**

Preserve a seam for additional composition without defining a universal semantic scene representation. A future semantic overlay would need reliable text identity, geometry, clipping, selection, scrolling synchronization and immediate fallback. POI geometry alone supplies none of that.

Include format/colour-space metadata in the frame contract now. The current BGRA8 path is not a complete HDR policy; Microsoft specifically identifies clipping risks and higher-precision handling for HDR capture. Full HDR implementation can remain later qualification. [WGC colour guidance](https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/screen-capture)

**7. Safe migration sequence — answer to B10**

Keep behavioural corrections distinguishable from structural movement. Do not preserve known defects indefinitely, but do not hide their correction inside a nominally neutral refactor.

| Slice | Smallest change | Preserved acceptance criteria |
|---|---|---|
| **0. Establish the comparison baseline** | Build the unchanged candidate; retain raw evidence; correct misleading measurement labels and add missing assertions. | Existing two-screen acceptance; exact return; rendered-frame readiness; real POI presence; separately observed Context View Locator. |
| **1. Give the existing view an identity** | Move runtime settings and command targeting behind one application-owned view state. Still one source and one output. | Same hotkeys/settings, persistence, duplicate-launch behaviour, Help and shutdown. |
| **2. Extract evidence acquisition** | Move Win32/UIA lifetime out of `CaptureRunner`; retain the legacy filtering/arbitration adapter. | Existing pointer/caret traces, original timestamp behaviour, bounded Edge fixture, responsive render loop. |
| **3. Extract the view update step** | Separate viewport/return state and overlay computation from capture callbacks and presentation. Initially preserve existing visible behaviour. | Same crop trajectory, comfort margins and exact temporary-normal return. |
| **4. Separate graphics resources** | Extract device/context and output presenter; introduce explicit frame ownership while retaining one output. | No new copies without justification; same pixel output on the qualified geometry; zero Present failures in the acceptance workload. |
| **5. Extract CaptureSource lifecycle** | WGC publishes frames and status independently of a view. Add source generations and orderly teardown. | Startup, resize, closure and current topology shutdown behaviour remain deterministic. |
| **6. Introduce workspace resolution** | Represent the existing preset in a versioned model; separate saved intent from resolved topology. | Legacy settings migration is reversible; missing displays do not erase assignments; two-screen behaviour remains available. |
| **7. Add the second output under a capability gate** | First one source → two destinations; subsequently a second source. | Per-view state isolation, bounded scheduling, correct frame/source attribution and unaffected-output behaviour. |
| **8. Introduce product changes separately** | Ownership transfers, independent overlays, geometry corrections and improved recovery. | New behavioural assertions plus the retained legacy workflow acceptance. |

Run the existing two-screen suite after each runtime-affecting slice, supplemented by tests relevant to that slice. A suite that only confirms the same global settings and one output cannot validate isolation.

Do not bundle same-monitor interaction, shader quality, profile automation and localization conversion into the graphics split. The one-source→two-output step is the first useful scaling test; four physical screens are not needed to begin it.

**8. Minimum 2–4-monitor configuration model — answers to B13–B14 and D20–D23**

Persist **what the user intended**, and resolve it against a separate current topology snapshot.

| Persistent element | Minimum semantics |
|---|---|
| Workspace | Schema version, stable workspace ID, user label |
| Display bindings | Logical IDs, role labels and a collection of identity hints |
| Sources | Stable source IDs and bindings to logical displays |
| Views | Stable view ID, source ID, destination binding and output rectangle |
| View state | Zoom with explicit semantics, viewport anchor, follow settings, visual transform and overlay settings |
| Interaction policy | Policy identifier/version, eligible views and default command target |
| Application overrides | Optional typed patches with defined precedence; initially empty |
| Recovery policy | Behaviour for unavailable or ambiguous bindings |

Keep HWNDs, HMONITORs, process IDs, adapter LUIDs and live capture handles out of durable identity. They belong to runtime resolution.

Use `QueryDisplayConfig` and target/path information, complemented by hardware metadata where available. Microsoft exposes several useful identity signals, but not a promise that one value uniquely follows every panel through every dock/port change. [QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig), [target information](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name)

Recommended matching order:

1. unique, corroborated device/hardware identity;
2. compatible path/connector history plus hardware metadata;
3. topology/geometry as supporting evidence;
4. unresolved binding requiring reassignment.

Identical displays without unique serials can be inherently ambiguous after port changes. Geometry alone must not silently decide which screen is the user’s Detail.

Use immutable topology generations. Re-resolve atomically after change; reject evidence and frame geometry from obsolete generations. Preserve unavailable assignments. Do not rewrite the saved workspace merely because a temporary fallback was used.

**Geometry must be explicit.** For new general configurations, define magnification in source-pixel-to-destination-pixel terms, with aspect ratio preserved. “Fit the whole source” is a separate overview operation.

Currently, a 1920×1080 source at 2x yields a 960×540 crop regardless of destination. Mapping that to a portrait 1080×1920 output produces different horizontal and vertical scale factors. That is not a valid general magnification contract.

Preserve existing matched-screen behaviour during extraction, then deliberately migrate the meaning of overview/1x where output geometry differs. Temporary return must restore the view’s source binding, crop and zoom; exact restoration is possible only while the required geometry remains valid. Otherwise clamp predictably and disclose the adjustment.

**App-scoped overrides:** represent the possibility now, but keep the first schema conservative. Limit initial patches to zoom, visual, visibility and follow settings. Defer automatic source/destination reassignment. Define precedence, for example:

`defaults → workspace/view settings → matching app override → explicit session override`

Use stable application matching rules; do not rely on localized window titles or persist transient PIDs.

**Pinned/frozen/context-relocated views:** preserve three independent dimensions:

- source region selection;
- content update policy;
- destination placement.

A frozen snapshot retains pixels. A pinned live region retains its region while pixels update. Dynamic relocation changes the region or placement using task context. Treating all three as a retained texture would be the wrong abstraction. ZoomText’s documented Freeze View includes monitoring live regions, illustrating the terminology trap. [ZoomText guide, Freeze View](https://support.freedomscientific.com/content/documents/manuals/ZoomText/ZoomText_User_Guide_English_US.pdf)

**Clean text:** conceptually, it would be a presentation surface fed by a separate text-acquisition capability. It should not be fabricated as a raster `CaptureSource` or forced through POI records. Leave its concrete interface undefined until a target task exists. The ordinary output-window abstraction is sufficient preparation.

**Localization:** begin lightweight preparation during extraction and complete it before settings growth. String keys alone are insufficient. The current settings window locates controls by English captions and uses fixed pixel geometry/fonts. Replace caption-based lookup with IDs, make layout DPI-aware and expandable, preserve keyboard mnemonics/accessibility names, and keep persistence/diagnostic identifiers language-neutral. Test enlarged text and pseudolocalized strings before translation. [Settings UI](C:/dev/Vision/app/src/settings_window.cpp:183)

**9. Compatibility and supportability plan — answers to C18–C19 and D24**

Before claiming workplace usefulness, publish a task-level compatibility matrix rather than an application-name checklist.

| Application family | Minimum task coverage |
|---|---|
| Windows shell and native dialogs | Start/search, Explorer, open/save, menus, modal dialogs, Alt-Tab, focus restoration |
| Word | Typing, selection, long lines, ribbons, comments, search, page transitions |
| Excel | Cell navigation, edit mode, formula bar, ranges, sheet changes, menus/dialogs |
| Outlook variants | Message list, reading pane, compose editor, search, calendar and modal prompts |
| Edge/Chrome | Native controls, textarea, contenteditable/rich editor, menus, PDF viewer, web applications |
| Teams/Electron/WebView applications | Chat editor, navigation, pop-ups, meeting controls and share selection |
| PDF software | Search, selection, forms, text PDFs and scanned-image limitations |
| Pilot employer’s essential application | Its actual recurring tasks, including any custom/legacy controls |

The current Edge result is strong **for its textarea fixture**. It does not certify rich editors, Office, Electron or remote application semantics.

Cross representative tasks with DPI, negative origins, orientation, unequal resolution/refresh, source crossings, dialogs spanning displays and recovery transitions. Use a risk-based subset, not an unmanageable full Cartesian product.

Regression layers should include:

- deterministic policy/geometry/state tests;
- recorded evidence replay with provider/context generations;
- application fixtures verifying target geometry and viewport outcome;
- physical presentation and topology tests;
- low-vision task sessions for orientation and sustained readability;
- periodic checks against new Windows/application versions.

Measure wrong-view movements, target visibility, recovery time, source freshness, repeated frames and effective settings—not just successful Present calls. A successful Present can display an old image.

Represent visibility per target with **current validity, observed geometry, last activity, style and display policy**. Following uses different eligibility and freshness rules. Stationary pointer/caret cues should not disappear simply because movement intent expired. Prevent duplicate native/captured/custom pointers and keep overlay size tied to destination presentation units rather than zoomed source pixels.

Diagnostics should identify workspace/view/source IDs, topology generation, resolved binding confidence, selected adapter, frame sequence/age, evidence provider health, ownership-transfer reason, effective settings and device-removal/error codes. Keep routine collection free of document text and screenshots.

The debts that become disproportionately costly are:

1. global runtime state and unscoped commands;
2. absent source/view/frame generations;
3. geometry assumptions hidden inside viewport code;
4. visibility tied to the winning movement candidate;
5. weak target identity and activity semantics;
6. blocking graphics/UIA lifetime coupling;
7. destructive fallback persistence and non-transactional multi-key saves;
8. text-based UI lookup and fixed layout;
9. telemetry that cannot distinguish absence, staleness and actual selection.

These are more consequential than renaming classes.

**10. Pre-implementation experiments — answer to E25**

**No new broad physical or incumbent experiment is required before the first mechanical extraction slices.** The present evidence is sufficient to separate the existing responsibilities.

There are narrower gates before particular commitments:

| Rank | Smallest evidence required | What it blocks |
|---|---|---|
| **1** | Fresh unchanged-build baseline, with honest POI/overlay assertions and retained raw traces | The first runtime-affecting refactor comparison |
| **2** | Table-driven geometry examples covering unequal resolutions, portrait destinations and a partial window; explicitly decide zoom versus fit semantics | Freezing the generalized viewport/frame contract |
| **3** | One captured source presented into two independently paced outputs, including a delayed/occluded output and source shutdown | Adopting the multi-output scheduling/device-sharing implementation |
| **4, conditional** | Same-monitor exclusion plus input correctness across click, drag, selection and wheel | Enabling or promising interactive self-magnification |

The second item is primarily a contract check, not a hardware research programme. The third belongs immediately after minimal extraction makes it possible.

The fourth becomes a pre-architecture blocker **only if** the team insists that the initial architecture must immediately deliver arbitrary interactive same-monitor views. My recommendation avoids that commitment.

Physical 3/4-monitor usability, final identity matching on identical panels and renderer preference are not prerequisites for moving existing code into coherent responsibilities.

**11. Later validation — answers to E26 and remaining uncertainty**

After the necessary primitives exist, qualify in this order:

1. **One source → two outputs:** cadence, source freshness, independent state and slow-output interference.
2. **Two sources:** ownership transfers, overlapping target geometry and stale semantic events.
3. **Recovery:** remove an output/source, sleep/wake, docking, source resize and device-domain recreation.
4. **Physical three/four displays:** realistic layouts, resolutions, refresh rates and memory/bandwidth use.
5. **Hybrid and USB graphics:** adapter selection, copy paths, sustained performance and recovery on representative ordinary hardware.
6. **Identity ambiguity:** identical displays, reboot, reconnect to another port and changed primary display.
7. **Text quality:** controlled raster alternatives and sustained tasks at matched scale.
8. **Ownership usability:** explicit-only versus deliberate automatic transfer, then optional boundary aids.
9. **Context workflows:** one pinned live region, one snapshot and one relocation scenario tested separately.
10. **Conditional deployment capabilities:** screen sharing, elevated applications, secure desktop and remote environments.

Low-vision task observation and dealer interviews should start early alongside extraction; they need not wait for four monitors. Avoid deriving shipping thresholds from intuition: establish baseline variability and user-visible consequences before selecting limits.

**12. Revised development sequence and commercial implications — answers to E27–E30**

Change the proposed sequence in three ways: bring cohort/dealer evidence forward, bring compatibility/recovery ahead of feature expansion, and keep same-monitor interaction outside the initial extraction commitment.

1. Reconcile documentation and define the first supported tasks/cohort.
2. Establish the unchanged baseline and perform the narrow extraction.
3. Validate fan-out and introduce versioned workspace resolution.
4. Add ownership, independent visibility and non-destructive recovery.
5. Run early user tasks while improving geometry and text quality.
6. Qualify physical 2/3/4-monitor configurations and the application matrix.
7. Add only the second-layer capability that resolves a demonstrated task failure.
8. Finalize deployment obligations before pricing or route-to-market work.

**Support burden:** narrower scope reduces training choices, configuration interactions, semantic reading machinery and specialized integrations. It does not proportionally reduce Windows, GPU, Office, browser, accessibility-provider or topology compatibility obligations. If Vision promises broad workplace replacement, much of that burden approaches incumbent breadth.

The workplace survey cited in the package found software/site/document access challenges in 59.1% of its mixed blindness/low-vision sample. That supports prioritizing compatibility; it is not a Vision market-size or speech-free demand estimate. [Workplace AT study](https://pmc.ncbi.nlm.nih.gov/articles/PMC10703993/)

**Commercially useful capabilities beyond daily interaction:** signed installation, controlled updates, offline core operation, reproducible diagnostic bundles, configuration backup/reset/export, accessible onboarding, hotkey conflict handling, understandable recovery and clear supported-version documentation.

Remote deployment and secure-desktop access should be treated as segment eligibility decisions. Dolphin’s business offering explicitly includes managed deployment and remote environments; this establishes their commercial relevance, not that every first Vision customer needs them. [Dolphin business documentation](https://yourdolphin.com/SuperNova/Business)

Before pricing/route-to-market work, obtain concrete dealer/assessor evidence:

- recent cases that could plausibly use magnification without integrated speech;
- actual working zoom levels and reasons users switch tools;
- essential applications and deployment environments;
- procurement vetoes, including remote access, login/UAC and signing;
- training/setup tasks and recurrent support incidents;
- whether clients can use an unmagnified context surface;
- willingness to place a bounded Vision pilot and how success would be judged.

Ask for anonymized case examples and observed workflows. Do not substitute general enthusiasm or guessed margins.

**Strongest entry hypothesis:** visually working Office/browser users with an ordinary dual-display setup who experience repeated loss of context and value predictable Detail, target finding and exact return. Three/four-monitor capability supports this product but is not itself the initial reason to buy.

**Falsifiers:** no identifiable cohort fits the supported task envelope; essential work repeatedly requires missing speech/remote/secure capabilities; Context + Detail increases fatigue or errors; text quality remains unacceptable; Windows Magnifier plus application zoom performs as well with less setup; or recovery requires specialist intervention. Those outcomes should narrow or change the product framing before adding more modes.

**13. Decision table**

| Proposal | Decision | Rationale |
|---|---|---|
| **1. WGC/D3D11 universal baseline** | **Modify** | Keep as default graphics path. Reject “universal” as a compatibility or interactive-mode guarantee. |
| **2. Explicit topology, capture-source and view-session responsibilities** | **Modify** | Necessary extraction; add geometry, output scheduling, ownership and recovery responsibilities. |
| **3. Share expensive capture/evidence work** | **Modify** | Share within appropriate device/source domains; keep consumers bounded and permit measured exceptions. |
| **4. Attribute state per view/destination** | **Keep** | View owns visual/follow/return state; destination owns physical output properties. |
| **5. Context + Detail as default, not sole workflow** | **Keep** | Best-supported initial preset. Its cohort advantage remains a user-validation hypothesis. |
| **6. Separate orientation overlays from viewport motion** | **Keep** | Required; current implementation has a demonstrable coupling to remove. |
| **7. Explicit active-view/crossing policy** | **Keep** | Make movement permission explicit. Start with one owner and an explicit override. |
| **8. Raster improvement before semantic work** | **Modify** | Correct geometry first; test reconstruction. Semantic enhancement and clean text are optional alternatives, not mandatory stages. |
| **9. Preserve future settings/context/output seams** | **Modify** | Preserve small composable contracts. Avoid speculative view hierarchies, inactive mode taxonomies or a semantic renderer schema. |
| **10. Narrower first product than incumbents** | **Keep** | Coherent with an explicit cohort, task envelope and deployment boundary. |
| Current fallback proves interactive same-monitor readiness | **Reject** | Exclusion, interaction and recovery are distinct capabilities; only a limited fallback exists. |
| One D3D11 device per view | **Reject** | Unnecessary default cost and weak failure-isolation justification. |
| Automatic ownership transfer is preferred by users | **Insufficient evidence** | Architect for it; compare against explicit selection in real tasks. |
| GPU reconstruction will achieve incumbent-class perceived quality | **Insufficient evidence** | Requires matched task/perceptual evidence. |
| A single-monitor contextual mode must block the initial 2–4-monitor product | **Reject** | Preserve the seam and safe degraded operation; qualify the mode when the product promise requires it. |

The next consequential implementation should therefore be **the extraction of one validated source/view relationship with explicit state, geometry and lifetimes**. Expanding monitor count comes after that foundation can prove isolation and correct routing.
