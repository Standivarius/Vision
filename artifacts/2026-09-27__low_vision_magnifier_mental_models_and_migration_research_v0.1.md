# Visual / Doxa — Low-Vision Magnifier Mental Models, Feature Matrix & Migration Strategy v0.1

**Date:** 2026-09-27  
**Project:** Visual / Doxa  
**Basis:** User research on low-vision magnifier mental models (ZoomText, SuperNova, Windows Magnifier) and migration to Visual on multi-screen Doxa workstations  
**Status:** UX Research & Migration Specification v0.1  

---

## Executive Summary

Supporting low-vision users on a multi-screen Doxa system hinges on leveraging their existing magnifier knowledge while carefully introducing new concepts. In practice, most experienced users expect familiar terms like **“zoom level/magnification,”** **“pointer tracking,”** and **“text caret”** (also called the “text cursor”). They expect simple hotkeys for common actions: e.g. `CapsLock + Up/Down` to change zoom in ZoomText and `Win + Plus/Minus` in Windows Magnifier. They know that `Ctrl + Alt + I` in Windows Magnifier toggles invert colors and `CapsLock + C` in ZoomText inverts brightness. We should reuse well-known terminology wherever possible (for example, calling “magnification level” *Zoom Level* rather than inventing a new term) and adopt the simplest cross-product defaults and keybindings. Any genuinely new paradigm (such as fixed “monitor roles” or permanent reference views) should be clearly named and explained because it has no direct analogue in incumbent tools.

At the same time, we must avoid the entrenched complexity of existing magnifiers. For example, although ZoomText and SuperNova offer advanced features like multiple freeze/“hooked” regions, application-specific profiles, and dozens of hotkeys, these are seldom used by most users. Visual should deliberately skip or simplify little-used legacy functionality. Instead, we focus on the core tasks that frustrate users:
1. Maintaining orientation at high zoom;
2. Quickly toggling between overview and detail;
3. Keeping focus and pointer visible.

We will provide one-to-one migration familiarity for key concepts (e.g. use the standard names *“Invert Colors”*, *“High Contrast”*, *“Grayscale”* for color modes, and allow `CapsLock + Enter` to toggle 1× view as in ZoomText). At the same time, we will eliminate or rename confusing legacy terms. For instance, “Follow Activity” is obscure; users should see explicit **“Follow Pointer”**, **“Follow Text Insertion”**, and **“Follow Focus”** toggles instead. We may drop Windows-specific terms like “Narrator cursor” or ZoomText’s niche “MultiView” nomenclature.

Finally, to minimize learning time, Visual will proactively guide the user only when needed. We will embed contextual tips and tooltips (for example, hinting the 1× toggle key when at high zoom) rather than a heavy tutorial. Only tasks with real user uncertainty will get assistance, and only until the user demonstrates understanding. In short, Visual’s UI will be a familiar subset of ZoomText/SuperNova vocabulary and behavior wherever practical. New features (multi-monitor arrangements, “Context/Detail” modes) will be introduced with plain-English labels and optional short help to explain their advantage, while avoiding jargon. This balanced approach — maximum reuse of known terms and patterns, minimal but targeted innovation — will help users become productive on Visual as quickly as possible.

---

## A. Terminology / Behavior Matrix

Below is a cross-product comparison mapping incumbent assistive technologies to recommended Visual terminology, behavior, and hotkeys.

### Summary Matrix

| Concept | ZoomText (Freedom Scientific / Vispero) | SuperNova (Dolphin) | Windows Magnifier (Microsoft) | Recommended Visual Term | Proposed Visual Behavior & Hotkeys | Confidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Zoom Level** | “Zoom Level” (1×–60×), default 2× | “Zoom Level” / “Magnification level” (1×–64×) | “Zoom” / “Magnification level”, default 200% (2×) | **Zoom Level** or **Magnification** | Slider/control 100%–600% (1×–6×) default. Keys: `CapsLock+Up/Down`, `Win±`. | Strong |
| **Increase / Decrease Zoom** | `CapsLock+Up/Down`, Zoom In/Out buttons | `Insert+Up/Down`, `Ctrl+Alt+Plus/Minus` | `Win + Plus/Minus`, `Ctrl+Alt+Plus/Minus` | **Zoom In / Zoom Out** | Mouse-wheel with `CapsLock`, `Win+Plus/Minus`, toolbar buttons. | Strong |
| **Toggle 1× / Overview** | `CapsLock+Enter` (toggles zoom ↔ 1×) | `Insert+Enter` / menu toggle | `Ctrl+Alt+Minus` / `Ctrl+Alt+Space` (peek) | **Toggle Full View** or **1× View** | One-key toggle between 100% full-screen and current zoom. UI button. | Strong |
| **Window Types / Modes** | “Zoom Window Type” (Full, Span, PIP, Split, Docked) | “View Mode” (Full, Docked, Lens, Split) | 3 modes: Full, Lens, Docked (`Ctrl+Alt+F/D/L`) | **View Mode** (Full screen, Lens, Split view) | Default: Full screen on one monitor. Avoid jargon like “MultiView Local”. | Moderate |
| **Overview + Detail Mode** | “Overview Mode”, “View Locator”, “Span” | Dual-monitor 1× + magnified setup | Lens as detail; no native persistent overview pane | **Context View / Detail View** | One screen (Context) at 1×; second screen (Detail) magnified. Cross-reflection. | Moderate |
| **Pointer Tracking** | “Follow Pointer”, Pointer Locator, crosshair | “Follow Mouse Pointer”, enhancements | “Have Magnifier follow mouse pointer” (Center/Keep in view) | **Follow Pointer**, **Pointer Locator** | Re-center on move; optional crosshair / highlight color. | Strong |
| **Caret Tracking** | “Follow Text Caret”, Caret Enhancement | “Follow Text Cursor”, cursor enhancements | “Have Magnifier follow Text Cursor” | **Follow Text Insertion Point** (or Caret) | Typing/tabbing pans view; highlight/border to locate. | Strong |
| **Focus Tracking** | “Follow Keyboard Focus” | “Follow Keyboard Focus” | “Have Magnifier follow Keyboard focus” | **Follow Keyboard Focus** | Active control change ensures visibility / centering. | Strong |
| **Pointer Enhancement** | Pointer tab: sizes, colors, Pointer Locator | Pointer color/size in Control Panel | Windows Ease of Access pointer size/color | **Pointer Size / Color**, **Pointer Locator** | Large pointer color (e.g. white dot/invert) + pulsing locator ring. | Moderate |
| **Caret Enhancement** | Enlarge/highlight caret and focus | Caret thickness, focus ring | “Underline caret”, thickness | **Caret / Focus Highlight** | Enlarge caret or draw high-contrast box around keyboard focus. | Moderate |
| **Color / Contrast Modes** | Color themes (Normal, Invert, Yellow on Black) | Color & Contrast (Invert, Grayscale, High Contrast) | Invert (`Ctrl+Alt+I`), Grayscale checkbox, OS High Contrast | **Color Mode** (Normal, Inverted, Grayscale, High Contrast) | Support Normal, Inverted, Grayscale directly. Clarify OS high contrast hook. | Strong |
| **Panning / Viewport** | Auto-pan, arrow keys, sticky corners | Keyboard move, pointer pan | Dragging, edge-of-screen panning | **Pan** / **Scroll**, **Point of Interest (POI)** | Natural arrow keys, mouse edge pan, or scroll dragging. | Moderate |
| **Multiple Monitors** | MultiView Local/Global, Span, independent zoom | Independent zoom per monitor, combined span | Magnifier spans all monitors as single desktop | **Independent Monitor Zoom** | Independent zoom per Doxa screen; optional unified canvas span. | Moderate |
| **Monitor Switching** | Next/Previous Monitor (`CapsLock+Right/Left`) | `Insert+Up/Down` or switch hotkeys | `Alt+Tab` (apps only, not monitor-specific) | **Switch Display** (`Next/Prev Monitor`) | Hotkeys to cycle magnifier focus across displays. | Weak |
| **Freeze View / Hooked** | “Freeze View” (up to 4 pinned magnified boxes) | “Hooked Area” / “Pin Region” | Not supported | **Pinned Area** / **Reference Window** | Simplify or skip initially; leverage physical Reference monitor instead. | Weak |
| **Reading / Speech** | AppReader, DocReader | Speech toggle, text reading | Narrator (separate) | *Out of Scope* | No built-in TTS planned for initial Visual versions. | N/A |
| **Profiles / Persistence** | “Configurations” (per-app / global profiles) | User profiles / task setups | System-level settings store only | **Workspaces** / **Basic Settings** | Persist last-used zoom, colors, and layouts; skip heavy profile managers. | Moderate |
| **Onboarding / Help** | In-app help, hover tooltips on toolbar | Help system, context-sensitive hints | Web help articles, minimal in-app hints | **Contextual Tooltips**, **Getting Started** | Inline tooltips with hotkeys, contextual hints when stuck. | Strong |

---

### Detailed Concept Breakdown

#### 1. Zoom Level (Magnification Amount)
* **ZoomText:** “Zoom Level” (1×–60× via toolbar or `CapsLock + Up/Down`). Default 2× on startup.
* **SuperNova:** “Zoom Level” or “Magnification level”; supports high zoom (e.g. 1×–64× via `Insert + Up/Down` or shortcuts).
* **Windows:** “Zoom” or “Magnification level”; defaults around 200% (2×) when launched. `Win + Plus/Minus` or mouse wheel.
* **Equivalence:** All incumbent tools provide numeric magnification adjustments.
* **Visual Term:** **Zoom Level** or **Magnification** (support both in UI and documentation).
* **Behavior:** Numeric slider or control from 100% to 600% (1×–6×) by default. Hotkeys: `CapsLock + Up/Down` (for ZoomText users) and `Win + Plus/Minus` (for Windows users).
* **Rationale:** “Zoom Level” is shared by ZoomText and Windows Magnifier. Supporting both `CapsLock` and `Win` hotkeys preserves established muscle memory.
* **Confidence:** Strong.

#### 2. Increase / Decrease Zoom (Zoom In / Out)
* **ZoomText:** Hotkeys `CapsLock + Up/Down` and dedicated Zoom In/Out buttons.
* **SuperNova:** `Insert + Up/Down` or `Ctrl + Alt + Plus/Minus`.
* **Windows:** `Win + Plus/Minus` or `Ctrl + Alt + Plus/Minus`.
* **Equivalence:** All provide increment/decrement mechanisms.
* **Visual Term:** **Zoom In / Zoom Out**.
* **Behavior:** Increment/decrement zoom; support mouse-wheel while holding `CapsLock` (ZoomText habit) and standard plus/minus keys.
* **Rationale:** Standard plain-English labels. Provide legacy and native Windows shortcuts to satisfy all user cohorts.
* **Confidence:** Strong.

#### 3. Toggle to 1× (Fullscreen / Overview View)
* **ZoomText:** `CapsLock + Enter` toggles between current zoom and 1×. Fundamental workflow accelerator (zooms to 1× while keeping tracking and overlays active).
* **SuperNova:** `Insert + Enter` or menu command.
* **Windows:** `Ctrl + Alt + Minus` toggles to 1× (also `Ctrl + Alt + Space` temporarily zooms out to peek at the desktop).
* **Equivalence:** Concept exists in all: an instantaneous return to unmagnified normal view.
* **Visual Term:** **Toggle Full View** or **1× View**.
* **Behavior:** Single keypress returns to 100% full-screen; pressing again returns to previous zoom level. Clear toolbar button with tooltip.
* **Rationale:** Users require a rapid, one-touch orientation reset.
* **Confidence:** Strong.

#### 4. Magnifier Window Types / View Modes
* **ZoomText:** “Zoom Window Type” (Full Screen, Span, Picture-in-Picture, Split-Vertical, Split-Horizontal, Docked).
* **SuperNova:** “View Mode” (Full Screen, Docked, Lens, Split).
* **Windows:** Three modes: Full Screen, Lens, Docked (`Ctrl + Alt + F / L / D`).
* **Equivalence:** All offer configurable geometry for presentation.
* **Visual Term:** **View Mode** with explicit mode names (*Full screen*, *Lens*, *Split view*).
* **Behavior:** Default: Full screen on primary working monitor. Options for floating lens or docked panes. Avoid complex legacy jargon like “MultiView Local”.
* **Rationale:** “Full screen”, “Lens”, and “Docked” are industry standard.
* **Confidence:** Moderate.

#### 5. Overview + Detail Mode
* **ZoomText:** “Overview Mode” (semi-magnified context window) with “View Locator”. Also offers “Span” mode.
* **SuperNova:** Achievable on multi-monitor by keeping one display at 1× and another magnified.
* **Windows:** No persistent overview pane alongside detail view.
* **Equivalence:** ZoomText’s Overview Mode is unique; multi-monitor setups simulate it.
* **Visual Term:** **Context View / Detail View**.
* **Behavior:** One screen (Context) remains at 1×; second screen (Detail) presents the magnified working area. Pointer/caret motion in one reflects immediately in the other.
* **Rationale:** Novel to Visual in terms of fixed hardware roles. Requires plain labeling and visual indicators.
* **Confidence:** Moderate.

#### 6. Pointer Tracking
* **ZoomText:** “Follow Pointer”, pointer locator (crosshair option), pointer rendered above/below view, re-center hotkeys.
* **SuperNova:** “Follow Mouse Pointer”, size/color enhancements.
* **Windows:** “Have Magnifier follow mouse pointer” checkbox; centering options (Center on screen / Keep within view / No pan).
* **Equivalence:** All support keeping the mouse pointer visible in the magnified viewport.
* **Visual Term:** **Follow Pointer** (setting), **Pointer Locator** (highlight/sonar effect).
* **Behavior:** View automatically pans/re-centers as pointer moves. Optional crosshairs or ring locator.
* **Rationale:** “Follow Pointer” is identical across ZoomText and Windows.
* **Confidence:** Strong.

#### 7. Caret (Text Cursor) Tracking
* **ZoomText:** “Follow Text Caret”, “Caret Enhancement”.
* **SuperNova:** “Follow Text Cursor”, thickness and color enhancements.
* **Windows:** “Have Magnifier follow Text Cursor” checkbox; centering behavior dropdown.
* **Equivalence:** Blinking text insertion point is tracked across text editing contexts.
* **Visual Term:** **Follow Text Insertion Point** (or **Follow Caret**).
* **Behavior:** Moving the text cursor (typing, arrow keys, tabbing) causes the viewport to pan smoothly. Optional visual box/glow.
* **Rationale:** “Text Insertion Point (Caret)” clarifies the difference from the mouse pointer and system focus.
* **Confidence:** Strong.

#### 8. Keyboard Focus Tracking
* **ZoomText:** “Follow Keyboard Focus” (tracks active buttons, menus, and controls).
* **SuperNova:** “Follow Keyboard Focus”.
* **Windows:** “Have Magnifier follow Keyboard focus”.
* **Equivalence:** Identical across all products.
* **Visual Term:** **Follow Keyboard Focus**.
* **Behavior:** When keyboard focus moves (dialogs, tab stops, menus), the viewport centers or ensures visibility.
* **Rationale:** Highly standardized concept distinct from pointer and caret.
* **Confidence:** Strong.

#### 9. Pointer Enhancement
* **ZoomText:** Pointer tab with sizes, custom colors, and “Pointer Locator” (rings, radar, sonar).
* **SuperNova:** Size and color configuration in Control Panel.
* **Windows:** Ease of Access pointer customization; Magnifier color inversion.
* **Equivalence:** All permit styling and locating the mouse pointer.
* **Visual Term:** **Pointer Size / Color**, **Pointer Locator**.
* **Behavior:** User can select large pointer styles, contrasting colors, or a pulse/locator ring.
* **Rationale:** Standard accessibility expectation.
* **Confidence:** Moderate.

#### 10. Caret Enhancement
* **ZoomText:** Enlarge, highlight, or place markers around the text caret.
* **SuperNova:** Thickness adjustments and focus frames.
* **Windows:** Cursor thickness and indicator settings.
* **Equivalence:** Enhancement exists but naming varies.
* **Visual Term:** **Caret / Focus Highlight** (e.g. *“Highlight Caret”*).
* **Behavior:** Adjustable bracket, tint, or glow around active insertion point.
* **Rationale:** Must be plainly named to avoid confusion with pointer enhancements.
* **Confidence:** Moderate.

#### 11. Color / Contrast Modes
* **ZoomText:** Color schemes (Normal, Invert, Yellow on Black, etc.).
* **SuperNova:** Color and Contrast (Invert, Grayscale, High Contrast).
* **Windows:** Invert Colors (`Ctrl + Alt + I`), Grayscale checkbox, OS High Contrast integration.
* **Equivalence:** Invert and grayscale are universal; specialty high-contrast schemes vary.
* **Visual Term:** **Color Mode** (*Normal*, *Inverted*, *Grayscale*, *High Contrast*).
* **Behavior:** Fast software color transformation. Clearly differentiate internal color filters from the Windows OS high-contrast theme.
* **Rationale:** Exact terminology match with ZoomText and Windows reduces friction.
* **Confidence:** Strong.

#### 12. Panning / Viewport Behavior
* **ZoomText:** Auto-pans with pointer/caret/focus; manual pan with arrow keys or edge bumps; sticky corners.
* **SuperNova:** Pointer pan, edge panning, keyboard moves.
* **Windows:** Pointer push panning, viewport dragging.
* **Equivalence:** Core auto-pan and edge-push behaviors are universal.
* **Visual Term:** **Pan** or **Scroll**; **Point of Interest (POI)** for algorithmic tracking center.
* **Behavior:** Smooth auto-centering on POI; support manual arrow/drag panning without disorienting jumps.
* **Rationale:** Standard navigation; keep controls transparent and predictable.
* **Confidence:** Moderate.

#### 13. Multiple Monitors
* **ZoomText:** Advanced multi-monitor options: separate zoom per screen, span across displays, MultiView Local/Global.
* **SuperNova:** Independent monitor magnification or unified span.
* **Windows:** Magnifier treats multiple monitors as a single unified desktop surface (no independent zoom per monitor).
* **Equivalence:** Windows is unified single-zoom; ZoomText and SuperNova support per-monitor independence.
* **Visual Term:** **Independent Monitor Zoom**.
* **Behavior:** Each connected Doxa screen can maintain an independent zoom level, role, and filter.
* **Rationale:** Core architectural differentiator of Doxa hardware.
* **Confidence:** Moderate.

#### 14. Monitor Switching
* **ZoomText:** Dedicated next/previous monitor commands (`CapsLock + Right/Left`).
* **SuperNova:** Hotkeys to transfer magnifier focus.
* **Windows:** Uses standard Windows `Alt + Tab` / `Win + Shift + Left/Right`.
* **Equivalence:** Specialized magnifiers provide monitor-jump hotkeys.
* **Visual Term:** **Switch Display** (or *Next / Previous Monitor* hotkeys).
* **Behavior:** Hotkey instantly transitions active magnifier viewport between physical displays.
* **Rationale:** Essential for multi-display workflow efficiency.
* **Confidence:** Weak (lower priority for early iterations).

#### 15. Freeze View / Hooked Areas
* **ZoomText:** Pinned magnified callouts (up to 4 independent sub-windows).
* **SuperNova:** “Hooked Areas” or “Pin Regions”.
* **Windows:** Not supported.
* **Equivalence:** Complex niche feature in high-end legacy tools.
* **Visual Term:** **Pinned Area** or **Reference Window**.
* **Behavior:** Omit complex floating hooked windows; instead leverage Doxa's dedicated physical *Reference Monitor*.
* **Rationale:** Rarely used in practice; physical multi-screen layout makes virtual freeze windows redundant.
* **Confidence:** Weak (skip for MVP).

#### 16. Reading / Text-View (Speech)
* **ZoomText:** AppReader, DocReader, SpeakIt.
* **SuperNova:** Integrated speech and screen reading.
* **Windows:** Delegated to Windows Narrator.
* **Equivalence:** Integrated speech vs standalone magnification.
* **Visual Term:** *N/A (Out of scope).*
* **Rationale:** Visual is focused purely on spatial magnification and multi-screen visual workflows; speech engine is excluded.
* **Confidence:** N/A.

#### 17. Profiles / Settings Persistence
* **ZoomText:** “Configurations” (.zxc files) with app-specific auto-switching.
* **SuperNova:** User profiles and situational environments.
* **Windows:** Persistent user-level configuration registry.
* **Equivalence:** Incumbents offer deep configuration systems.
* **Visual Term:** **Workspaces** or **Saved Settings**.
* **Behavior:** Automatically persist zoom levels, display assignments, and color modes per user. Defer complex per-app switching.
* **Rationale:** Prevents configuration fatigue while guaranteeing state retention.
* **Confidence:** Moderate.

#### 18. Onboarding / Help
* **ZoomText:** Integrated manual, extensive toolbar hover tooltips.
* **SuperNova:** Control panel help system, context hints.
* **Windows:** Static web help documentation.
* **Equivalence:** Tooltips and context hints are standard; tutorials are external.
* **Visual Term:** **Contextual Tooltips**, **Getting Started Pane**.
* **Behavior:** Interactive, non-modal tooltips showing hotkeys; lightweight cue when a user appears disoriented.
* **Rationale:** Hover tooltips with shortcut cues provide the fastest learning curve.
* **Confidence:** Strong.

---

## B. Prior-Knowledge Model

Users approaching Visual bring distinct mental models depending on their background:

```
                          ┌───────────────────────────┐
                          │   Target User Profiles    │
                          └─────────────┬─────────────┘
          ┌──────────────────┬──────────┴──────────┬──────────────────┐
          ▼                  ▼                     ▼                  ▼
┌──────────────────┐ ┌───────────────┐   ┌──────────────────┐ ┌───────────────┐
│ Experienced      │ │ Experienced   │   │ Windows          │ │ Novice / New  │
│ ZoomText User    │ │ SuperNova     │   │ Magnifier User   │ │ to Zoom       │
│                  │ │ User          │   │                  │ │               │
│ • CapsLock keys  │ │ • Insert keys │   │ • Win++/Win--    │ │ • GUI buttons │
│ • View Locator   │ │ • Ctrl panel  │   │ • Ctrl+Alt+F/D/L │ │ • Plain text  │
│ • Independent    │ │ • Layered     │   │ • Simple toggles │ │ • Zero jargon │
│   monitors       │ │   shortcuts   │   │ • OS contrast    │ │ • Lost easily │
└──────────────────┘ └───────────────┘   └──────────────────┘ └───────────────┘
```

1. **Experienced ZoomText User (Magnifier edition):**
   * *Mental model:* Expects `CapsLock` modal hotkeys (`CapsLock + Up/Down`, `CapsLock + Enter` for 1× toggle).
   * *Expectations:* Relies on the “View Locator” (the bounding box on overview displays) and expects independent zoom settings on dual displays.
   * *Friction risk:* Extreme frustration if `CapsLock` hotkeys are unmapped or if overview boxes are missing.

2. **Experienced SuperNova User (Dolphin):**
   * *Mental model:* Accustomed to `Insert` or `Ctrl`-based shortcut layers and a centralized control panel.
   * *Expectations:* Looks for explicit “Options” dialogs rather than floating widget toolbars.
   * *Friction risk:* May search for layered key combinations (`Insert + Space`).

3. **Windows Magnifier User (Built-in Ease of Access):**
   * *Mental model:* Knows `Win + Plus/Minus`, `Ctrl + Alt + F` (Full), `Ctrl + Alt + L` (Lens), `Ctrl + Alt + D` (Docked), and `Ctrl + Alt + I` (Invert).
   * *Expectations:* Expects settings integrated directly into the OS shell. Unfamiliar with `CapsLock` or `Insert` modifier schemes.
   * *Friction risk:* Confused by non-standard modifiers; expects simple `Win` key shortcuts.

4. **Occasional / Basic Magnifier User:**
   * *Mental model:* Relies almost exclusively on graphical UI buttons, mouse clicks, or browser zoom (`Ctrl + Wheel`).
   * *Expectations:* Clear large buttons with visual cues; minimal hotkey dependency.
   * *Friction risk:* Lost if UI hides primary controls behind shortcuts.

5. **New to Screen Magnification:**
   * *Mental model:* No prior assistive tech vocabulary. Does not understand terms like “caret”, “POI”, or “hooked regions”.
   * *Expectations:* “Just works” out of the box with clear visual orientation.
   * *Friction risk:* Disorientation when zoomed in; high risk of losing pointer or text cursor off-screen.

6. **AT Trainer / Workplace Assessor:**
   * *Mental model:* Fluent in all tools and acronyms (ZoomText, MAGic, SuperNova).
   * *Expectations:* Seeks fine-grained settings toggles to customize configurations for specific pathologies (tunnel vision, macular degeneration, photophobia).
   * *Value proposition:* Consistency with industry standards reduces re-training hours.

---

## C. Visual Migration Table (Current → Recommended)

| Current Visual Label / Action | Recommended Visual Label | Rationale & Behavioral Adjustment |
| :--- | :--- | :--- |
| **`1x`, `1.5x`, `2x`, `3x`, `4x`** | **`1×`, `1.5×`, `2×`, `3×`, `4×`** (or `100%–400%`) | Retain numeric ratios. Matches ZoomText conventions while remaining intuitive for Windows Magnifier users. |
| **Follow pointer** | **Follow Pointer** | Standard across ZoomText and Windows. Keep label identical. |
| **Follow text caret** | **Follow Text Insertion Point (Caret)** | Clarifies meaning for mainstream users while preserving “Caret” for ZoomText veterans. |
| **Follow keyboard focus** | **Follow Keyboard Focus** | Standard industry term across all platforms. Retain as is. |
| **Independent markers (pointer/caret/focus)** | **Pointer Locator / Caret Highlight / Focus Box** | Clear, descriptive nouns explaining the visual enhancement rather than technical state. |
| **Context / Detail screens** | **Context (1× Overview) / Detail (Zoomed)** | Add explanatory subtitle in setup to clarify that “Context” is full overview and “Detail” is the active workspace. |
| **Magnified area rectangle on Context** | **Zoom Window** or **View Locator** | Matches ZoomText's well-known “View Locator” concept; immediately explains the bounding box. |
| **Normal / High Contrast / Inverted / Grayscale** | **Normal / Inverted / Grayscale / OS High Contrast** | Clarify that “High Contrast” delegates to the Windows OS theme, while Invert/Grayscale are instant Visual filters. |
| **Display roles: Context, Detail, Reference** | **Screen Roles: Context, Detail, Reference** | Plain-English names are sound; add inline tooltip descriptions explaining each monitor's purpose. |
| **Temporary normal view and exact return** | **Toggle 1× View (Return to Full View)** | Matches ZoomText’s `CapsLock + Enter` function. Clearly describe the one-touch toggle action. |
| **Follow activity** | *(Remove or split into specific follow toggles)* | “Follow activity” is vague. Replace entirely with explicit Pointer, Caret, and Focus toggles. |
| **Detail View (settings section)** | **Detail Display Settings** | Clarifies that settings apply to the physical monitor assigned the Detail role, not an abstract software mode. |
| **Screen roles (settings section)** | **Monitor Role Assignments** | Explicitly describes mapping physical displays to functional roles. |

---

## D. New Visual Concepts Needing Explanation

Visual introduces five concepts that have no direct analogue in single-screen incumbent tools:

1. **Fixed Monitor Roles (Context / Detail / Reference):**
   * *Concept:* Screens are assigned permanent, specialized functional roles:
     * **Context:** 1× overview display preserving global spatial layout.
     * **Detail:** Magnified active working canvas following active focus.
     * **Reference:** Static, unpanned display for reference documents, tools, or chat.
   * *User Onboarding:* Display an illustrated setup banner on first multi-screen launch:  
     *“Context = 1× overview; Detail = zoomed workspace; Reference = static reference info.”*

2. **Independent Per-Monitor Zoom:**
   * *Concept:* Each physical screen runs its own zoom level and filter pipeline, unlike Windows Magnifier which treats all screens as one stretched canvas.
   * *User Onboarding:* Label monitor headers with independent zoom controls: *“Each monitor zooms independently.”*

3. **View Locator (Screen Segment Bounding Box):**
   * *Concept:* A brightly bordered rectangle on the Context screen showing the exact boundary of what is currently magnified on the Detail screen.
   * *User Onboarding:* Tooltip on bounding box: *“This frame shows the region currently enlarged on your Detail screen.”*

4. **Temporary Snapback / Peeking:**
   * *Concept:* Momentarily pressing a shortcut or button to view the full screen at 1×, snapping back to previous magnification upon release.
   * *User Onboarding:* Tooltip on 1× toggle button: *“Press to toggle 1× overview; hold to peek.”*

5. **Focus vs. Caret Differentiation:**
   * *Concept:* Distinguishing between the active UI element (button, tab, menu) and the blinking text insertion bar.
   * *User Onboarding:* Clear inline setting descriptions:  
     * *Keyboard Focus:* Highlights active menus, lists, and buttons.  
     * *Text Insertion Point:* Tracks where typed letters appear.

---

## E. Review of Existing AI / In-App Help Features

* **Vispero Companion (ZoomText / JAWS Companion — 2026):**
  * *Nature:* Reactive LLM-powered help chat integrated into the accessibility suite.
  * *Observations:* Requires user to formulate and type questions (e.g. *“How do I invert colors?”*).
  * *Limitations:* Does not proactively detect confusion; answers are general to Vispero products and unhelpful for custom multi-screen workflows.
* **Dolphin SuperNova “Ask a Question”:**
  * *Nature:* Built-in search and knowledge-base assistant in the SuperNova control panel.
  * *Observations:* Primarily a searchable documentation index; purely reactive.
* **Lessons for Visual:**
  * Low-vision users under high zoom find switching to a chat box disruptive.
  * **Contextual inline tooltips and passive visual cues are substantially superior to conversational chatbots** for real-time magnification tasks.
  * AI chat should be reserved for deep support diagnostics, while the core magnification interface must rely on immediate, deterministic cues.

---

## F. Product Principles (Derived from Research)

1. **Maximize Transfer:** Reuse familiar terminology and behaviors from ZoomText, SuperNova, and Windows Magnifier. Introduce new terms only when naming genuine hardware innovations.
2. **Keep UI Paths Shallow:** Core actions (zoom in/out, 1× toggle, pointer locator) must be reachable in exactly one keypress or one click.
3. **Offer Dual Input Modalities:** Support both `CapsLock` (ZoomText convention) and `Win` (Windows convention) keybindings alongside high-contrast graphical buttons.
4. **Visual Clarity First:** High-contrast pointer and caret highlights must be enabled by default. Never let the user “lose” their cursor.
5. **Shy Away from Power Creep:** Omit rarely used legacy baggage (multiple freeze windows, complex per-app scripting, nested menus).
6. **Progressive Disclosure:** Expose only essential controls on the primary toolbar; place advanced display timings and monitor calibrations behind an “Advanced” tab.
7. **Parallel Training & UI Design:** Write help copy and UI labels simultaneously so that microcopy directly reinforces button text.
8. **Platform Consistency:** Align with Windows conventions (`Ctrl + Alt + ...`) for view modes and window management where expected.
9. **Highlight Co-Benefits:** Emphasize features that assist both low-vision and power users (e.g. large crosshairs, rapid 1× peeking, multi-screen snapping).
10. **Fail-Safe Defaults:** If a user makes an ambiguous gesture or presses a conflicting shortcut, fail gracefully to the safest default (e.g. 1× overview or centering pointer).

---

## G. Capability Cards

### Card 1: View Modes Explanation
* **Barrier:** Users may not realize they can select Full, Lens, or Docked modes, or understand “Context vs Detail”.
* **Prior Knowledge:** ZoomText users know “Full, Span, Docked”; Windows users know `Ctrl + Alt + F/L/D`.
* **Context:** First launch on multi-monitor setup; displays show different magnification levels.
* **Trigger:** First run or upon opening the display role selector.
* **Intervention:** Non-modal tooltip banner:  
  *“Full Screen: whole monitor is zoomed. Context: 1× overview. Detail: magnified work area.”*
* **User Learns:** How to identify and configure monitor roles and viewport modes.
* **Suppression:** Closes permanently once user changes a mode or dismisses banner.
* **LLM Required:** No (deterministic text).
* **Success Metric:** User selects appropriate mode without consulting external help.

### Card 2: Zoom In / Out and 1× Toggle
* **Barrier:** User does not know how to return to unmagnified view or adjust zoom level.
* **Prior Knowledge:** ZoomText uses `CapsLock + Up/Down` and `CapsLock + Enter`; Windows uses `Win±` and `Ctrl + Alt + Minus`.
* **Context:** User is magnified at ≥3× and remains idle or searches menus for >10 seconds.
* **Trigger:** Zoom level ≥ 3× with no typing/pointer movement for 10 seconds.
* **Intervention:** Contextual hint bubble near zoom badge:  
  *“Press CapsLock + Enter (or Win + Minus) to toggle 1× overview.”*
* **User Learns:** The quick toggle shortcut to regain orientation.
* **Suppression:** Suppressed once shortcut is executed successfully twice.
* **LLM Required:** No.
* **Success Metric:** >80% reduction in time required to reset to 100% view.

### Card 3: Pointer / Caret Lost Recovery
* **Barrier:** User pans into an empty area and loses the mouse pointer or text caret.
* **Prior Knowledge:** Familiar with ZoomText crosshairs or Windows mouse radar.
* **Context:** Pointer moves off-screen or user shakes the mouse rapidly without productive clicks.
* **Trigger:** Pointer off active detail viewport for >3 seconds while mouse motion is detected.
* **Intervention:** Dynamic high-contrast guide arrow at viewport boundary pointing toward mouse coordinates, with tooltip:  
  *“Pointer off-screen — press Ctrl to locate or enable ‘Follow Pointer’.”*
* **User Learns:** How to reacquire lost pointer and activate auto-tracking.
* **Suppression:** Disappears immediately when pointer re-enters viewport.
* **LLM Required:** No.
* **Success Metric:** Zero abandoned tasks due to lost cursor during testing.

### Card 4: Screen Roles Onboarding
* **Barrier:** Multi-screen roles (Context, Detail, Reference) are conceptually new.
* **Prior Knowledge:** Multi-monitor users are accustomed to simple desktop extension.
* **Context:** Connecting 2 or 3 screens to the Doxa hardware.
* **Trigger:** Hardware connection event of displays 2 and 3.
* **Intervention:** Visual overlay displaying roles on each physical panel:  
  * *Left:* Context (1× Overview)  
  * *Center:* Detail (Zoomed Work Canvas)  
  * *Right:* Reference (Static Reference Apps)
* **User Learns:** How physical geometry maps to functional roles.
* **Suppression:** Dismissed on click; recalled via “Identify Screens” button.
* **LLM Required:** No.
* **Success Metric:** Correct window placement by user on first attempt.

### Card 5: Inline Shortcut Reminders
* **Barrier:** User forgets modifier conventions (`CapsLock` vs `Win` vs `Insert`).
* **Prior Knowledge:** Mixed shortcut experience across past tools.
* **Context:** User hovers over any toolbar button or opens settings panel.
* **Trigger:** Pointer hover for >500ms on any action icon.
* **Intervention:** Tooltip displaying command name and dual shortcuts:  
  *“Zoom In (`CapsLock + Up` or `Win + Plus`)”*
* **User Learns:** Dual shortcut schema progressively during everyday use.
* **Suppression:** Standard tooltip timing.
* **LLM Required:** No.
* **Success Metric:** Increased ratio of hotkey usage over time in telemetry.

---

## H. Intervention Priorities

```
Priority 1: Mode & Role Overlay (Card 1 & 4)
  └─► Essential on first launch to explain the multi-screen Doxa metaphor.

Priority 2: 1× Toggle & Zoom Hints (Card 2)
  └─► Eliminates disorientation traps at high zoom.

Priority 3: Pointer Lost Indicator (Card 3)
  └─► Solves the #1 user frustration (losing cursor during editing).

Priority 4: Inline Shortcut Tooltips (Card 5)
  └─► Passive, low-risk, continuous discovery mechanism.
```

---

## I. Usability Test Plan

### Cohort Sampling
* **5 Experienced ZoomText Users:** Focus on `CapsLock` habit transfer and View Locator expectations.
* **5 Experienced SuperNova Users:** Focus on control layout clarity and tracking smoothness.
* **5 Windows Magnifier Users:** Focus on `Win` key shortcut compatibility and multi-screen comprehension.
* **5 Low-Vision Novices:** Focus on orientation retention and readability of default settings.

### Test Scenarios
1. **Basic Magnification:** Adjust zoom between 1× and 4×, execute 1× toggle, change color modes (Normal → Invert → Grayscale).
2. **Text Editing & Caret Tracking:** Type in a text document near screen boundaries; pan and verify automatic caret following.
3. **Dual-Screen Operation:** Drag a document from Context display to Detail display; verify View Locator tracking.
4. **View Mode Switching:** Switch between Full Screen and Lens mode using hotkeys and UI buttons.
5. **Three-Screen Workspace Setup:** Organize a multi-task workspace (reference PDF on Reference, code/editor on Detail, browser on Context).
6. **Error Recovery:** Intentionally pan away from pointer and recover using locator shortcuts and guide arrows.

### Target Metrics
* **Task Completion Rate:** ≥ 95% across all cohorts.
* **Time to First Recovery:** Time taken to regain 1× view when disoriented (< 5 seconds target).
* **Assistance Requests:** Zero external interventions required during standardized tasks.
* **Subjective SUS Score:** Target System Usability Scale score ≥ 85.

---

## J. Implementation Backlog (Integration)

1. **Terminology & UI Alignment:**  
   Update all string tables and UI controls to match the migration table (e.g. rename *Screen Roles* to *Monitor Role Assignments*; change *Follow text caret* to *Follow Text Insertion Point*).
2. **Dual-Scheme Hotkey Engine:**  
   Implement parallel key listeners supporting both ZoomText schemes (`CapsLock + Up/Down/Enter/C`) and Windows Magnifier schemes (`Win + Plus/Minus`, `Ctrl + Alt + I/F/L/D`).
3. **Color Transformation Filter:**  
   Standardize software color inversion and grayscale shaders; provide clean pass-through for Windows high-contrast themes.
4. **Rich Hover Tooltips:**  
   Add hover tooltips with embedded hotkey badges across all toolbar icons and configuration toggles.
5. **Contextual Assistance Engine:**  
   Implement non-modal hint triggers (idle zoom detection, off-screen pointer indicator, first-run multi-monitor overlay).
6. **High-Contrast View Locator:**  
   Ensure the bounding rectangle on the Context screen is clearly visible with configurable border colors (yellow, cyan, magenta).
7. **Telemetry & Validation Hooks:**  
   Instrument anonymous event telemetry to record hotkey usage vs UI clicks, recovery trigger events, and role assignment changes.

---

## Sources & Methodology

* **Freedom Scientific ZoomText User Guide & Reference Manual:** Analysis of standard magnification levels (1×–60×), `CapsLock` navigation layers, View Locator geometry, and MultiView display options.
* **Dolphin SuperNova Magnifier Documentation:** Comparative analysis of magnification modes, focus tracking, and layered key configurations.
* **Microsoft Windows Magnifier Documentation:** Modern Ease of Access shortcuts (`Win±`, `Ctrl + Alt + ...`), full/lens/docked viewport modes, and cursor tracking options.
* **Empirical Multi-Screen Low-Vision Research:** Synthesis of context vs detail viewing strategies, neck/gaze ergonomics, and spatial orientation on multi-display workstations.
