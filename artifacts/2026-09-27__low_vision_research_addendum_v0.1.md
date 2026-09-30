# Low-Vision Research Addendum v0.1

**Date:** 2026-09-27  
**Status:** Research addendum recovered from the complete text supplied by the user in chat after the original on-disk copy was found corrupted. Formatting has been normalised; the research framing and recommendations are preserved.

# Executive Summary

Most **adoption barriers** in Visual come from new multi-screen concepts and subtle behavior differences, not basic magnification. Users already know *zoom in/out, pointer/caret tracking, color modes*, etc., so we must *align terminology* and *explain only what’s different*. The biggest gaps are understanding **screen roles (Detail vs Context)**, the **“Inspect+Return”** flow, and the absence of legacy features like ZoomText’s “Freeze View.” Unexpected behavior (e.g. detail view jumping) must be promptly explained.

**Contextual assistance** should be minimal and tailored. In practice this means tooltips, brief inline hints or one-time guides triggered by user actions or confusion, rather than unsolicited teaching. For example, when first using two monitors, a brief pop-up can explain that one monitor shows a magnified *Detail* view and the other shows a fixed *Context*. If the user’s action suggests confusion (e.g. moving focus with no effect), a short hint can clarify what to do next.

**LLM/chatbot assistance** is likely *unnecessary for most tasks*. Users benefit more from clear labels and tiny hints. Only high-level, unspecific “How do I...?” questions might justify a chat interface. (For instance, FS Companion in JAWS allows free-form questions and provides task-specific answers, but that is a secondary mode.) In Visual’s case, simpler interventions—better naming, static help text, guided prompts—should solve most problems. We recommend reserving LLM-style help for occasional “Ask a Question” usage, where user poses a natural-language query and the system responds with concise, actionable guidance.

In short, reuse familiar terms and behaviors wherever possible, fill in the gaps with on-screen hints or brief help panels, and only use AI/chat for truly open-ended user questions. This approach minimises re-training time and leverages users’ existing knowledge, answering their implicit “Now what?” with the **smallest** useful nudge at the right moment.

# Remaining Adoption Barriers

After aligning terminology and basic workflows, the main barriers are:

- **Multi-Monitor Roles:** Users struggle with the idea that displays have *roles*. (E.g. “Which screen is magnified?”) ZoomText didn’t have fixed roles, so users may not expect a “Context” vs “Detail” split.
- **Inspect+Return vs Freeze View:** Visual’s *temporary zoom* (Inspect+Return) is new. Users of ZoomText’s “Freeze View/Hooked Areas” may wonder where that is. They may not know how to quickly view 1× then return.
- **“Follow Activity” Semantics:** Visual introduces “Follow activity” plus separate pointer/caret tracking. Users may be unclear what each mode does, or why focus isn’t always tracking.
- **Pointer/Caret Visibility:** Differences in pointer enhancements or caret highlighting need explanation. For example, if Visual uses a crosshair or enlarged pointer by default, a user might not notice or understand it.
- **Color Mode Differences:** ZoomText/Windows used “Invert” or “Contrast” differently. Visual’s “Inverted Colours” vs “High Contrast” may need clarification.
- **Unexpected Movements:** If the magnified view jumps or pans in a way the user doesn’t expect (e.g. due to typing at edge), the user may be confused. They need to know *why* it moved and how to control it.
- **Lack of Legacy Features:** If users look for “Freeze View” or similar and don’t find it, they’ll be stuck. Visual must offer clear alternatives (e.g. pinning to a reference monitor) or explain design choices.
- **Discovering Shortcuts:** Experienced users expect keyboard shortcuts for common actions (zoom toggle, pan, etc.). If these aren’t obvious, users will flounder.
- **Settings & Profiles:** Users expect to save and restore preferences (like ZoomText’s “Config Names”). Visual must explain how settings persist and how to quickly configure default views.
- **Onboarding & Errors:** First-time tasks (setting up triple monitors, docking/undocking) could overwhelm users. Likewise, if Visual fails to start or a display is disconnected, the user will need guidance to recover.

# Intervention Strategy Table

| **Barrier** | **Static UI** | **Deterministic Help** | **LLM/Chat** |
|---|---|---|---|
| Screen Roles (Context vs Detail) | Tooltips, labels (“Detail View: magnified,” etc.) | First-use pop-up or one-time tutorial when second monitor detected | No |
| Inspect+Return (temporary zoom) | Clear label/button (e.g. “Full Screen Preview”) | Hint when toggling (e.g. “Release to return”) | No |
| Follow Modes (Activity vs Pointer vs Caret) | Explicit UI labels (“Follow pointer” etc.) | Short explanation panel or pop-up on first use | No |
| Pointer/Caret Highlighting | UI options clearly labeled; default high contrast pointer | If pointer is lost, show hotspot locator (e.g. flash) | Maybe (if asked how to find pointer) |
| Color Modes (Invert/Contrast) | Mode names and icons matching common terms | Tooltip or panel explaining difference (on selection) | No |
| Unexpected Panning/Movement | Hard to capture statically | Contextual alert explaining recentering behavior | No |
| Legacy “Freeze View” missing | N/A (feature absent) | Note explaining available alternatives | No |
| Keyboard Shortcuts unknown | UI menu with cheat-sheet of keys | Initial hint/pop-up listing common keys | No |
| Settings/Profiles | UI for Save/Load with familiar icons (“Default”) | Tutorial tip: “Click here to save settings” | No |
| Onboarding (multi-monitor setup) | Clear indication of connected monitors | Quick-start guide on first launch | No |

In practice, nearly every barrier can be met with **static labels** and **short deterministic hints**. If an “Ask a Question” feature is included, it should mainly cover free-form user queries; most of the above do **not** require an AI response.

# Key Capability Cards

## 1. Explain Screen Roles (Context vs Detail)

**Barrier:** Users don’t understand why one monitor is fixed (Context) and the other is magnified (Detail). They may try to pan the Context screen or expect both to move.

**Expected prior knowledge:** ZoomText users know one screen can be “Main” (magnified) and the other “Linked,” but they didn’t have a fixed Context. Windows Magnifier users rarely use a second monitor for overview.

**Observable context:** User is using dual/triple display with Visual; Detail view is active but user’s pointer moves do not affect Context.

**Trigger:** On first launch with a second monitor (or when the user first moves their pointer and sees that only one screen changes).

**Intervention:** Brief splash note or tooltip:

> “Detail View is zoomed. Move mouse or type in the Context screen (left) to change what you see magnified on the Detail screen (right). The Context display itself stays fixed for orientation.”

**Outcome:** User understands that “Context” is static and how to navigate (via pointer/caret on Context).

**Suppression:** Only show once per session or until user manually reads help docs.

**LLM required?** No.

**Success metric:** User quickly uses the Context screen to move the Detail focus without further confusion or help requests.

## 2. Temporary Zoom (“Inspect and Return”)

**Barrier:** Users may not realize how to jump to a full-screen 100% view and back (ZoomText’s “X1 view”). They might scroll instead or get lost.

**Expected prior knowledge:** Windows Magnifier had “Full Screen/Fixed” modes and hotkeys. ZoomText had an “X1” toggle.

**Observable context:** User is in a magnified Detail view and invokes the normal/full-view control.

**Trigger:** When user clicks or invokes the control.

**Intervention:** Show an inline hint or toast:

> “Full view enabled. Press the same key or click again to return to the previous zoom level.”

**Outcome:** User knows how to exit full view and that it returns exactly to prior state.

**Suppression:** Only needed when the feature is used.

**LLM required?** No.

**Success metric:** Users successfully exit full view without overshooting, and don’t report confusion about where they returned to.

## 3. Follow Modes Clarification

**Barrier:** The setting “Follow activity” vs “Follow pointer/caret/keyboard focus” may confuse users. They may not understand why sometimes the view follows focus and other times the pointer, or what “activity” covers.

**Expected prior knowledge:** Users know concepts such as follow mouse, text cursor and keyboard focus; “Follow activity” is new wording.

**Observable context:** User changes a follow setting or notices the magnifier isn’t moving as expected.

**Trigger:** When user toggles a follow mode or first encounters the settings.

**Intervention:** Inline explanation of the tracking choices.

**Outcome:** User distinguishes the individual tracking sources.

**Suppression:** Once user has changed settings or after first session with help read.

**LLM required?** No.

**Success metric:** Users correctly use pointer vs focus follow and do not mistakenly leave follow off because “activity” sounded ambiguous.

## 4. Replacing “Freeze View” (Pinning Reference)

**Barrier:** Legacy ZoomText users expect a “freeze area” or hooked region, but Visual doesn’t have that. They may ask “Where is Freeze View?” or try to click to pin.

**Expected prior knowledge:** ZoomText’s Freeze View pinned a region of the screen; users might not know about alternative approaches.

**Observable context:** The user seeks a way to keep reference content visible.

**Trigger:** User accesses Help or searches for Freeze/Reference terminology.

**Intervention:** Help text explaining Visual’s alternative Reference workflow where appropriate.

**Outcome:** User understands the available Visual workflow instead of assuming a Freeze View exists.

**Suppression:** After first hint or until user closes the suggestion.

**LLM required?** No.

**Success metric:** Users can keep reference material visible or understand that Visual does not currently provide an equivalent pinned region.

## 5. Proactive Chat for Unanswered Questions

**Barrier:** Users sometimes know the goal but not how to describe it in Visual’s terms, e.g. “How do I keep this area from moving?”

**Expected prior knowledge:** They may not remember new terminology.

**Observable context:** The user explicitly invokes help (e.g. a Help button or chat icon).

**Trigger:** User asks a natural-language question or clicks “Ask a Question.”

**Intervention:** A guided answer, either static FAQs or an LLM-powered chat that can interpret the query.

**Outcome:** User finds the desired solution even if they did not know the feature name.

**Suppression:** Ends when user is satisfied or closes help.

**LLM required?** Yes for flexible free-form Q&A, though a scripted database can answer known exact questions.

**Success metric:** User’s question is resolved and they complete the task.

# LLM vs Deterministic Assistance

Most help should be **deterministic**: tooltips, short messages and static text. An LLM or chat can be included as an optional fallback for free-form user questions.

Situations where LLM help may justify itself include:

- terminology is unknown but the user can describe the goal;
- multi-step tasks where the user knows the desired outcome but not the Visual workflow.

LLM answers should be short, actionable and safe. Everyday questions about settings should be covered by clear UI or one-line hints where possible.

**Key principle:** Don’t interrupt users unless they ask or clearly need it. Allow them to discover by doing, with minimal scaffolding. This honors the paradox of the active user by not forcing tutorials, while still helping users who hesitate.

# Top 3–5 Interventions

1. **Screen-roles Tooltip/Guide:** On detecting a multi-monitor setup, show a one-time explanation of Context vs Detail and how navigation works. High priority.
2. **Follow Mode Descriptions:** Replace vague labels like “Follow activity” with clearer terms and add concise explanations of each mode. High priority.
3. **Temporary Zoom Hint:** When the user enters/exits the 1x/full view, show a brief message explaining the action and return behavior. Medium priority.
4. **“Freeze View” Replacement Note:** In Help, explain the relevant Reference workflow or explicitly state that Freeze View is not currently implemented. Medium priority.
5. **Basic AI Help (Chat):** Provide an optional Ask feature that can answer simple free-form queries. Lower priority initially, but preserve a clean integration seam.

# Usability Test Plan

**Participants:**

- 5–8 experienced users who know ZoomText/SuperNova well but are new to Visual.
- 5–8 less-experienced users who have used Windows Magnifier or similar tools occasionally.

**Tasks:**

1. Basic pan/zoom and cross-application work.
2. Temporary 1x/full view and exact return.
3. Keeping reference content visible while working elsewhere.
4. Switching contrast/inversion/colour modes.
5. An ad-hoc “how would you figure this out?” query to observe use of UI, help or chat.

**Measurements:**

- completion time;
- error count and orientation loss;
- assistance needed;
- confusion points and questions asked;
- terminology interpretation;
- whether hints reduce repeated help needs.

# Implementation Backlog (Combined)

Combine terminology fixes and contextual help in one pass:

- **Rename UI elements:** update confusing names based on the migration research; replace “Follow activity” with explicit tracking terminology.
- **Tooltips/Inline Help:** add succinct explanations for key options such as screen roles, follow modes, colour modes and 1x/return.
- **First-run Guide:** if used, keep it optional and minimal; focus only on genuinely new multi-screen concepts.
- **Interactive Hints:** trigger single-line hints in response to specific actions; suppress them after successful use.
- **Help/FAQ Content:** add searchable help covering incumbent terminology and common expectation gaps such as Freeze View.
- **Ask a Question:** add an optional natural-language help entry point; begin with narrow answers and later integrate an LLM backend if validated.

This unified approach avoids renaming UI and adding help in separate redesign cycles. User feedback should determine whether richer AI/chat assistance is justified.
