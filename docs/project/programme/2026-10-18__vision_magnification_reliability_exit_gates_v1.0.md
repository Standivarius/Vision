# Vision magnification reliability — fixed exit gates v1.0

Date: 2026-10-18
Project: Vision / MARIUS-DELL / C:\dev\Vision / master
Owner decision: stop open-ended isolated tests. Complete three bounded working sessions, then the demonstration gate. No speech/AI, additional feature work, driver changes or monitor reconfiguration in this tranche.

## Completed foundation: Word/Excel 4x

Status: COMPLETE FOR THE BOUNDED DEVELOPMENT TASK. No further isolated Word/Excel tests without a reproduced failure in the reliability sessions.

The two final A04 keyboard-editing runs:
- office-edit-4x-20261018-171840-58e2a7
- office-edit-4x-20261018-172202-fc1fc6

Each independently passed six Word/Excel app switches, six keyboard-generated edits, six Page Down movements, correct source and Detail software pixels, full selected-target containment in the stable interval, clean shutdown and desktop restoration. Report: artifacts/2026-10-18__vision_A04_office_edit_4x_qualification_v0.1.md.

This is NOT a full-day, camera or user-acceptance result.

## Reliability gate: exactly three working sessions of approximately 30 minutes

Use the same compiled Vision baseline and independent acceptance criteria across all three. Capture the installed build hash, Windows session/display topology, active foreground app, OS caret/cell/focus truth, source and Detail screenshots with integrity stamps, shutdown, and independently recorded failures. Log elapsed active testing time; setup and evidence scoring do not count toward the working minutes.

Each session needs 27-33 minutes of active task execution to count as one 30-minute session. No session may be reported as PASS based on the assistant's narrative, merely running a script, a single earlier six-phase A04 exercise, or Vision's own telemetry. Preserve failed/inconclusive raw evidence.

1. R1 — Office sustained work (approximately 30 minutes): Word typing, selection, long-document scrolling and repeated Excel cell editing/scrolling with 4x tracking, interleaved natural application switches. Include ongoing rather than only initial/final checks.
2. R2 — Mixed applications and navigation (approximately 30 minutes): Word, Excel and Edge/browser on permitted test content; pointer movement, typing, keyboard focus, tab and application switching; compare correct source and Detail. No personal browsing, accounts or documents.
3. R3 — Recovery and stability (approximately 30 minutes): repeat representative Office/browser tasks and deliberate focus changes, application close/reopen, caret/pointer interruption and recovery; track freshness, CPU/memory, crashes and normal exit. Do not power-cycle monitors, force lock/unlock, sleep/hibernate or change drivers unattended.

### Unchanged hard acceptance for every session

- No crash, freeze, stuck frame, unsupported source swap or forced Vision shutdown. Distinguish app-created fixture exit from crash.
- Correct active source, caret/pointer/keyboard-focus ownership and visible content for every qualified task checkpoint. No sustained target disappearance longer than two seconds. Transitions must meet the existing two-second source-to-Detail visibility budget, accounting honestly for recording resolution.
- Normal return/recovery after each expected change in application, focus, caret, or source; no cross-application stale target.
- No contamination by foreign process foreground, unapproved personal-file interaction or desktop lock. If a required independent observation is unavailable, mark the interval INCONCLUSIVE, not PASS.
- Independent source and Detail recordings are primary visible-output evidence. Compare with independently observed OS target state. Internal Vision telemetry is for diagnosis or a negative-only viewport containment veto, never sole PASS evidence.
- Clean closing/restoration of test-owned applications, pointer and foreground; no user data saved/modified. Preserve the unmodified raw record and compiled build identity.

A session FAIL or INCONCLUSIVE does NOT count. Repair the specific reproduced issue, update its regression, then repeat the **affected** session only; do not continually invent additional acceptance requirements. If the same problem remains after one bounded repair/retest cycle, mark the gate BLOCKED and seek an owner decision rather than expanding tests indefinitely. If a code change affects a previously passed session's safety assumptions, repeat only those materially affected parts.

### Stop rule

When R1, R2 and R3 each have a complete independently qualified PASS on the accepted baseline, mark MAGNIFICATION RELIABILITY COMPLETE, freeze the tested build/commit, publish a brief evidence ledger, and STOP further undirected reliability testing. Any subsequent issue needs a new reproducible defect or genuine user observation. Remaining long-term improvements go to backlog.

The four-screen physical configuration, which is currently absent from Windows, is a separate named topology acceptance gate. It does not retroactively invalidate qualified three-screen tests. It must not be silently claimed tested or silently restored by altering Windows displays.

## Demonstration gate (separate, not part of the three sessions)

A working, reversible, understandable installer/launcher; clear zoom and source controls; predictable escape/recovery; a brief task script on representative documents; and William or another genuine low-vision assessor able to conduct ordinary work without operator intervention. Record the actual participant's feedback and problems. Do not claim commercial release readiness until this gate is passed.

## Environment prerequisite / current blockage

At this checkpoint, the machine is on interactive Windows console session 2, but A02_display_preflight.py found only ONE active Windows desktop display and no qualifying Centre/Right screens. PnP sees only the integrated laptop monitor. Therefore no valid 3-display R1/R2/R3 session can begin now. This is BLOCKED_BY_PHYSICAL_DISPLAY_TOPOLOGY, not an app test failure. Do NOT mark any session completed or use RDP, the laptop screen alone, synthetic display declarations, or a restarted tunnel as a substitute. Do not change device/driver/display topology remotely without a separate safe recovery decision.

Recheck via python lab/pocs/doxa/assessment/A02_display_preflight.py when the physical display topology is restored. The preflight must be PASS before starting a GUI test, and no other Word, Excel or Vision process may already be running. Existing A04 guarded runner is available for a short regression but does NOT count as an R1 30-minute session.

## Status at creation

- Word/Excel 4x bounded development: COMPLETE.
- R1: BLOCKED (only one active display); 0 qualifying working minutes.
- R2: NOT STARTED.
- R3: NOT STARTED.
- Demonstration/assessor: NOT STARTED.
- Reliability baseline frozen: NO.

This plan defines when to stop; it does not imply tests ran while the Dell was physically unable to display them.
