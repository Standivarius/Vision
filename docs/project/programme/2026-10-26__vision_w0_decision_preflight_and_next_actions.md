# Vision / Doxa accessibility comparison ? W0 preparatory gate

**Date:** 26 October 2026. **Project:** Vision on MARIUS-DELL. **Owner's current decision:** Doxa first; compare what Windows and installed alternatives can already do before extending Vision. This does not revive deferred R2/R3 endurance sessions.

## What I have actually completed unattended

- Executed read-only physical-console A02 and hashed PnP monitor identity probes on Dell, without monitor or driver changes. Four independent active 1920?1080 desktops, three distinct external physical interface hashes, console unlocked.
- Added a new self-contained Windows read-only W0 preflight in lab/accessibility/w0_readonly_baseline.py. It checks console session, active monitor count, distinct external monitor identity, and simultaneously active magnifier conflicts without launching a magnifier or writing system settings.
- Six deterministic guard regressions pass: four unique monitors, reject RDP session, reject two simultaneous magnifier engines, reject three monitors, reject duplicate IDs, reject missing PnP identity. Live Dell W0 preflight: PASS_READ_ONLY_PREP. No active magnifier engine. A ZoomText UAC helper process alone is not treated as proof its magnifier is running.
- Saved two machine-readable JSON snapshots of physical console and hardware identity. The evidence is read-only software truth; it cannot prove optical readability or physical user experience.
- Created an explicit empty product ? task ? layout CSV with two configurations and ten shared task IDs, all NOT_TESTED. The scorecard deliberately contains no unearned product PASS verdict.

## Current passive software inventory

- Windows Magnifier and Narrator are present; the older native Magnifier docked-only proof does NOT qualify fully interactive independent laptop zoom.
- SuperNova Magnifier 25.05 installed.
- ZoomText 2026 installed; actual license/demo/restart state must be handled at a genuine product trial, not inferred from registry entries. Registry contains versions 2026.2606.73.400 and 20.5.10.0; treat those as installed-program entries, not two independent products.
- PowerToys 0.100.2 and Copilot present; Copilot is not a magnifier.
- NVDA not found in normal installed-product registry/paths; do not install it without authorization.
- Vision is a functional generic two-screen low-vision alpha with WGC/D3D11, Context + Detail and point-of-interest tracking. Passing Office R1 and limited Edge-only R2 evidence do not prove either Doxa four-screen A or B; the original composite R2 was owner-accepted at its existing scope and R3 remains deferred.

## The two configurations that must be compared without changing them now

- A: LEFT and RIGHT stay usable source workspaces; CENTRE is a live, independent 2?/4? Detail view of deliberately chosen source; LAPTOP may organize. Cross-monitor source?centre must truly work.
- B: LEFT/CENTRE/RIGHT stay normal wide extended Doxa workspaces; laptop has independently interactive 2?/4? magnification including click, keyboard focus and caret without disturbing Doxa panels.

The current four-screen configuration is a prerequisite, not proof either A or B is available.

## Next work that does not need the owner

1. Keep the W0 preflight and CSV scorecard versioned and reproducible. Populate exact build/edition/license *metadata only*, not subjective vendor PASS decisions.
2. Prepare disposable synthetic Word, Excel, Edge HTML and mixed table/PDF test materials for the shared T0?T9 portfolio. Avoid user files and user browser profiles.
3. Prepare reversible, narrowly scoped automated probes for candidate features using isolated app profiles, starting with native Windows accessibility API evidence. Do not open Magnifier/Narrator/ZoomText/SuperNova GUI, play speech, alter OS preferences or launch visual comparisons unattended.
4. Improve instrumentation for orientation, pointer/caret and source ownership only where an existing W0?W6 task has a specific gap. Avoid broad refactors or implementing Doxa hardware assumptions in Vision core.

## Work that waits for the owner or low-vision assessor

- Actual 5?15 minute W1 Windows Magnifier/Narrator experience on the physical Doxa screens; observer scores comfort, readability, click/drag, orientation and restoration.
- W2 ZoomText/SuperNova user-facing trials, trial or licence screens, and any required restart decisions. One magnifier at a time.
- Approval if installing NVDA is necessary. No silent installation or audio start.
- Later W5 Vision versus the best actually working native/vendor method, only after matched tasks; and W6 real low-vision user acceptance.
- Any display topology or SMI driver changes require a separate recoverable hardware procedure and authorization.

## Decision boundary

If free/native accessibility meets meaningful Doxa tasks, keep Vision optional; do not engineer features just for parity. If an important user-facing gap remains in layout A or B, scope Vision to that measured gap. Track A and B independently. See GitHub issues #63, #65?70 and the 20 October accepted R2 disposition.

Evidence files:
- 2026-10-26__vision_w0_native_preflight.json
- 2026-10-26__vision_dell_display_readonly_evidence.json
- 2026-10-26__vision_qualification_A_B_scorecard.csv

No manufacturer driver, monitor topology, user profile or incumbent settings were modified during this preparation.
