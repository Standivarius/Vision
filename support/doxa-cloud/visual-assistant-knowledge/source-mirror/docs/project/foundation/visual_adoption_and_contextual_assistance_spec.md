# Visual adoption and contextual-assistance specification

**Date:** 2026-09-27
**Status:** Working implementation specification derived from the 2026-09-27 incumbent mental-model research and contextual-assistance addendum
**Scope:** Current two-screen Visual main line. Doxa three-screen workspace remains a separate future product track.
**Implementation status: First pass implemented and Dell-validated on 2026-09-27.**

## Objective

The objective is not to teach Visual for its own sake. It is to minimise the time and effort required for a user to adopt Visual and become productive.

The order of preference is:

1. reuse knowledge the user already has from ZoomText, SuperNova or Windows Magnifier;
2. make the UI self-explanatory through familiar naming and direct feedback;
3. use small deterministic contextual assistance where a genuinely new Visual concept remains;
4. offer natural-language help only as a fallback for open-ended questions.

Success means users need *less* assistance over time.

## Research-derived product principles

1. **Exploit transfer before explaining.** Do not teach a Visual-specific term when an established term already describes the same concept.
2. **New terms must earn their existence.** Context/Detail/Reference are acceptable only where their semantics are genuinely different from incumbent concepts.
3. **Prefer recognition over recall.** The UI should expose familiar names and clear outcomes rather than require users to remember documentation.
4. **Keep help in the flow of work.** Small hints and explanations are preferred to mandatory tutorials.
5. **Offer; do not interrupt.** Proactive help should be rare, brief and dismissible.
6. **Fade help after successful use.** One-time and contextual assistance should suppress itself once the user has demonstrated the behavior.
7. **Explain unexpected behavior at the point of confusion.** Movement and tracking are more important to explain than basic zoom.
8. **Use deterministic state where possible.** Visual already knows its zoom, tracking policy, screen roles and current state; this should drive help before an LLM is considered.
9. **Keep natural-language help user-initiated initially.** The first LLM-backed feature should be an optional Ask Visual fallback, not an autonomous agent.
10. **Do not add incumbent features merely for parity.** Familiarity affects naming and workflow, not feature-count targets.

## Reconciliation against current Visual

### Zoom level

**Current:** Magnification selector with 1x, 1.5x, 2x, 3x and 4x.
**Decision:** Keep the numeric values. Use **Zoom Level** as the user-facing label rather than inventing another term.

### Tracking controls

**Current:** a master **Follow activity** checkbox plus separate Follow pointer / caret / focus controls.
**Decision:** remove **Follow activity** from user-facing terminology. It is vague and duplicates the more useful model.

Preferred settings structure:

**Tracking**

- Enable tracking
- Follow Pointer
- Follow Text Cursor (Caret)
- Follow Keyboard Focus

The internal master tracking switch can remain if useful to the implementation. The user-facing label should be **Enable tracking**, not Follow activity.

### Text caret terminology

**Current:** Follow text caret / caret marker.
**Decision:** use **Text Cursor** as the plain-language primary term, with **Caret** optionally retained in secondary help for experienced ZoomText users.

Suggested UI:

- Follow Text Cursor
- Text Cursor Highlight

### Context and Detail

The incumbent research treats **Context / Detail** as a reasonable new Visual/Doxa model, but confidence is only moderate because no incumbent uses exactly the same persistent physical-role semantics.

For the current two-screen Visual line, retain the terms for now but always pair them with explanatory subtitles:

- **Context - 1x overview**
- **Detail - magnified view**

Do not assume these names are final for the future three-screen Doxa workspace. BCS/user feedback may change them.

### View Locator

**Current:** Show the Detail View rectangle.
**Decision:** rename the user-facing feature to **View Locator**.

Suggested description:

> Shows on the Context screen which area is currently enlarged on Detail.

This reuses established ZoomText terminology and accurately describes current behavior.

### Temporary 1x and exact return

**Current:** Normal view / Return, Ctrl+Alt+0.
**Decision:** describe this as **1x View / Return** or **Toggle 1x View**.

It is *not* a Freeze View replacement. It is a familiar temporary 1x workflow with the useful Visual behavior of returning exactly to the previous magnified viewport.

When invoked for the first time, a short confirmation is sufficient:

> 1x view. Use the same command to return to your previous zoom and position.

### Freeze View / Hooked Areas

The research correctly identifies an incumbent expectation gap but overstates the equivalence of a Reference monitor.

**Decision:** do not claim that Reference *is* Freeze View.

Correct migration wording:

> Visual does not currently implement ZoomText Freeze View / SuperNova Hooked Areas. If the user's goal is simply to keep separate information visible, a Reference display may provide a simpler alternative.

If later testing shows that users need a fixed magnified region from the same source, implement a genuine pinned/frozen region rather than mislabelling a Reference screen as equivalent.

### Appearance / colour modes

**Current:** Normal, High contrast, Inverted colours, Grayscale.
**Important implementation fact:** Visual's current High contrast mode is a Detail-image contrast transform. It does not switch the Windows OS High Contrast theme.

**Decision:** do not label it **OS High Contrast** unless Visual actually delegates to Windows.

Preferred group name: **Colour & Contrast**.

Current modes can remain:

- Normal
- Increase Contrast
- Inverted Colours
- Grayscale

If OS High Contrast integration is added later, expose it as a distinct Windows setting/action.

### Screen roles

**Current:** Context, Detail, Reference.
**Decision:** keep **Screen Roles**. Do not replace it with the more bureaucratic "Monitor Role Assignments" recommendation.

Use concise descriptions beside the controls instead:

- Context - 1x overview
- Detail - magnified view
- Reference - optional normal Windows screen

Reference is currently only an assigned/persisted role; Visual does not manage its content.

### Shortcuts

Do not appropriate `Win + Plus/Minus`; those are Windows Magnifier shortcuts and would conflict with the operating system.

Do not change to ZoomText CapsLock shortcuts solely for familiarity without testing. A compatibility shortcut layer can be evaluated later if experienced-user testing shows a real adoption benefit.

Current Visual shortcuts remain valid engineering/product defaults for now.

## Contextual-assistance capabilities worth building

### 1. Screen-role explanation

**Barrier:** Context/Detail is a genuinely new persistent physical arrangement.
**Trigger:** first successful run with two screens, or first opening of Screen Roles.
**Intervention:** one concise, dismissible explanation.
**LLM:** No.

Suggested copy:

> Context keeps the full workspace visible. Detail shows the area you are working in enlarged. The View Locator on Context shows exactly what Detail is displaying.

**Fade:** once acknowledged or after successful repeated use.

### 2. First-use View Locator explanation

**Barrier:** user sees the rectangle but does not know what it represents.
**Trigger:** first time the View Locator becomes visible.
**Intervention:** brief label/tooltip associated with it or Settings.
**LLM:** No.

Suggested copy:

> View Locator - this frame shows the area currently enlarged on Detail.

### 3. 1x View / Return confirmation

**Barrier:** user may not realise the previous magnified position is preserved.
**Trigger:** first invocation.
**Intervention:** short toast/status message.
**LLM:** No.

### 4. Tracking explanation

**Barrier:** pointer, text cursor and keyboard focus can legitimately compete for Detail ownership.
**Trigger:** opening Tracking settings; later, only if a reliable unexpected-movement condition can be detected.
**Intervention:** concise inline descriptions, not a tutorial.
**LLM:** No initially.

Suggested descriptions:

- Pointer - follow deliberate mouse movement.
- Text Cursor - follow where you type or edit text.
- Keyboard Focus - follow the active control when navigating with the keyboard.

### 5. Migration/help vocabulary

**Barrier:** experienced users know a goal under an incumbent term such as Freeze View, Caret Enhancement, View Locator or X1/1x view.
**Trigger:** searching Help or Ask Visual.
**Intervention:** synonym-aware help content that maps incumbent terminology to Visual terminology and explicitly states when no equivalent exists.
**LLM:** Not required for exact known terms; useful for paraphrased natural-language questions.

### 6. Ask Visual

**Barrier:** user knows the goal but not the feature name or exact wording.
**Trigger:** user explicitly invokes **Ask Visual**.
**Intervention:** short natural-language answer grounded in current Visual capabilities and state.
**LLM:** Yes, potentially valuable here.

Initial scope:

- explanation of settings and terminology;
- "how do I..." guidance;
- incumbent-term translation;
- structured troubleshooting using known Visual state;
- no autonomous system actions.

Initial context supplied to the model should be structured and minimal, for example:

- current Visual version;
- current screen roles;
- zoom level;
- tracking options;
- appearance mode;
- last known Visual error/status;
- current Settings/help section;
- user question.

Do not send screenshots, document contents, typed text or arbitrary screen data by default.

Release builds now use the Doxa-owned `/v1/ask` route authenticated with the existing build-time Doxa client credential; the high-entropy `VISUAL_ROUTE_TOKEN` path remains a development-only override. The shared build-time client credential is acceptable for alpha testing but is not the final production device-authentication design.

The model/provider must remain behind a provider-neutral server boundary. As of 2026-09-27, the validated development backend is a dedicated Cloudflare `doxa-visual-assistant` gateway to the Dify `Visual Assistant` app using Muse Spark 1.3 Contributor. NVIDIA/Nemotron remains a planned replaceable backend once credentials are available; Visual must not be coupled to either provider.

## Implemented knowledge grounding

The optional online fallback now has a bounded retrieval layer rather than relying only on model memory or a static system prompt.

Evidence precedence is explicit:

1. **Current Visual source mirror / current Visual docs** are authoritative for what Visual presently implements.
2. **Official incumbent documentation** is authoritative only for the named incumbent product (ZoomText, SuperNova or Windows Magnifier).
3. **Project migration research** is interpretation/design rationale and must not override current Visual source/docs or official incumbent documentation.

The incumbent set contains short paraphrased, source-attributed entries for the concepts most likely to affect migration: tracking/follow behavior, magnifier/view modes, multiple-monitor behavior, ZoomText Freeze View, ZoomText Overview/View Locator, SuperNova Hooked Areas and Dolphin's published ZoomText-to-SuperNova terminology mappings. Full commercial manuals are not copied into the service.

The Visual implementation source is exposed through a **generated read-only mirror**, not through repository access. Its source list is explicit and limited to user-facing runtime/help/settings/tracking code plus this specification and current app documentation. Credentials, environment files, unrelated repository content and user files are outside the mirror. The model cannot browse or write the repository.

For each remote question, the Worker performs deterministic lexical/synonym retrieval and sends only a small matching evidence set (normally no more than seven chunks / roughly 12 KB) alongside the already-minimal structured Visual state. Migration questions force both relevant official incumbent evidence and current Visual evidence so an incumbent feature cannot silently become a claimed Visual feature.

The mirror manifest stores per-file SHA-256 hashes and an aggregate source-tree digest. `build-knowledge.ps1 -Check` fails when an allowlisted canonical file has changed since the snapshot was generated. The Worker's `/health` response exposes the non-secret retrieval version, chunk count and source-tree digest; each answer also returns non-secret retrieved chunk IDs for validation.

This satisfies the useful part of "code access" without giving the model direct codebase access: Muse can interpret selected current implementation excerpts but cannot enumerate, alter or exfiltrate arbitrary repository content.
## Assistance infrastructure to implement once, not feature-by-feature

When the implementation pass begins, add one small reusable assistance layer rather than ad-hoc MessageBoxes throughout the product.

It should provide:

- accessible inline help text / tooltips;
- a small non-blocking hint/toast surface;
- deterministic trigger IDs;
- local suppression state such as `screen_roles_explained=true`;
- "Don't show again" where appropriate;
- a Help / Ask entry point;
- a shared terminology/synonym table usable by static Help and future Ask Visual.

Do **not** build a general agent framework.

## What not to build in the first pass

- mandatory onboarding walkthrough;
- a long first-run wizard;
- proactive LLM prompts;
- automatic "user looks confused" inference based on idle time alone;
- screenshots sent to an AI model;
- automatic application arrangement;
- ZoomText Freeze View clone merely for parity;
- application profiles merely for parity;
- a new settings/profile management system before a user need is validated;
- the future Doxa three-screen workspace in current two-screen Visual.

## One coherent implementation backlog

### A. Terminology and settings UI

1. Magnification -> **Zoom Level**.
2. Follow activity -> **Enable tracking**.
3. Follow pointer -> **Follow Pointer**.
4. Follow text caret -> **Follow Text Cursor**.
5. Follow keyboard focus -> **Follow Keyboard Focus**.
6. Pointer/caret/focus marker terminology -> **Pointer Locator / Text Cursor Highlight / Focus Highlight**.
7. Detail View rectangle -> **View Locator**.
8. Appearance -> **Colour & Contrast**.
9. High contrast -> **Increase Contrast** unless/until OS High Contrast integration exists.
10. Screen Roles descriptions -> add plain-English subtitles; retain Context / Detail / Reference for now.
11. Normal view / Return -> **1x View / Return**.

### B. Deterministic assistance

1. first-use Context/Detail explanation;
2. first-use View Locator explanation;
3. first-use 1x-return confirmation;
4. inline Tracking descriptions;
5. searchable/static migration vocabulary for incumbent terms;
6. accessible error/recovery messages tied to actual Visual error states.

### C. Ask Visual seam

Build the product seam but keep the first version intentionally small:

1. Help / Ask Visual entry point;
2. structured context object;
3. provider-neutral HTTPS request/response contract;
4. concise answer surface;
5. allowlisted answer intents initially: explain, locate, guide, troubleshoot;
6. no arbitrary command execution.

The backend/model remains separately replaceable. The current development backend is Dify/Muse; NVIDIA Nemotron can be evaluated next when credentials are available.

### D. Validate before expanding

Test with experienced ZoomText/SuperNova users and less-experienced magnifier users. Measure:

- task completion time;
- terminology recognition;
- incorrect expectations;
- need for assistance;
- repeated help requests;
- ability to repeat a task without help;
- perceived interruption/annoyance.

Only then decide whether proactive AI, richer profiles, frozen regions or additional guidance are justified.

## Relationship to the Doxa workspace concept

The Doxa dual-workspace + shared-Detail concept is documented separately in `doxa_dual_workspace_shared_detail_concept.md`.

That future mode should inherit:

- this terminology where semantics still match;
- the same assistance infrastructure;
- the same provider-neutral Ask Visual capability;
- tracking and intent arbitration from the main Visual line.

Do not create a second terminology/help system for Doxa.

BCS/Ben/Oliver feedback may change the Doxa-specific names and interaction model before implementation.

## Source notes and caveats

Primary source artifacts:

- `artifacts/2026-09-27__low_vision_magnifier_mental_models_and_migration_research_v0.1.md`
- contextual-assistance addendum supplied by the user on 2026-09-27; the on-disk addendum artifact was corrupted before the complete text was supplied in chat.

Research recommendations are inputs, not automatic requirements. Where they conflict with current implementation truth or create false equivalence, this specification records the corrected product decision.
