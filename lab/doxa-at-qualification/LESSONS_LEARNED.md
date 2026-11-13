# Doxa SM770 assessment — lessons learned, 3–13 November 2026

## What cost time, and what must change next time

| Observed problem | Corrected practice for future test design |
|---|---|
| Windows UI reports 1280 × 720 while hardware is physically 1920 × 1080 | Set per-monitor DPI awareness before measuring display bounds. Record physical/native and DPI-virtualised logical coordinates separately. |
| ZoomText MultiView and Span showed black/unrelated areas | Establish the active zoom view, anchor source-to-screen explicitly, and photograph the labelled source before diagnosing renderer failure. The virtual desktop has dead rectangles between monitors. |
| Pointer teleport did not change the ZoomText Overview locator | Trigger genuine relative mouse motion, validate the locator, then click; direct SetCursorPos is not a substitute for all vendor tracking semantics. |
| NVDA Alt+NVDA+Right was interpreted as a numpad gesture | Use KEYEVENTF_EXTENDEDKEY for real arrow keys; check NVDA's own input trace before blaming the device. |
| Early Word/Edge/Excel input checks targeted wrong Edge process/window | Use a separate browser profile, labelled accessible input, exact ValuePattern readback and explicit foreground/settle check. |
| Freeze shortcut from older guides was wrong | Version the vendor shortcut contract: ZoomText 2027 Freeze creation uses Caps Lock + Ctrl + N. Confirm actual creation and toggle via vendor controls. |
| A menu was clicked without a corresponding camera-visible change | Do not call vendor UI selection a feature pass. Pair command/readback, source-target labels, actual physical camera proof and task effect. |
| ZoomText toolbar existed late, not immediately after its process started | Wait for the correct ZoomTextMainWindow, read its toggle/factor, and refuse CPU samples unless magnification is ON at the intended factor both before and after. |
| Vendor trial sessions are time-limited | Preflight camera, power, content, source labels and scripts before starting the legitimate trial; run the few decisive checks first. Never bypass licence enforcement. |
| Single-output Windows changes auto-reactivated all screens | Avoid screen toggling as an uncontrolled per-output experiment. Snapshot geometry, prefer stable configurations, add timeout/rollback/watchdog and do not disturb a working driver. |
| An earlier test targeted a constantly changing desktop and attributed all CPU to ZoomText | Control source content and actual update cadence, measure separate driver-host/DWM/vendor process CPU and proper no-AT baselines. |
| Some static tests showed active SMI host; others idle SMI host with hot ZoomWnd.dll thread | Treat ZoomText runtime modes as distinct states. Repeat ABBA within one boot rather than averaging incompatible states into a single claim. |
| GPU profiler event counts were interpreted too literally | Attribute device handles and allocations to the right process/adapter, distinguish allocation notifications from lifetime and actual USB transfers; do not equate them with physical frame rate. |
| Vendor performance setting reduced SMI CPU but increased ZoomText CPU | Report the **sum of measured processes and each constituent**; state if fine-font quality was actually assessed rather than claiming an identical experience. |
| Dated reports remained stale after decisive retests | Maintain one versioned current acceptance report per category plus immutable historical evidence, with acceptance decision and observations recorded separately. |
| Many exploratory scripts write the same fixed artifact filenames | Freeze old scripts as historical, redirect only vetted scripts to unique run directories, hash every evidence item and refuse overwrites. |
| Several tests ran while the machine had existing dirty work | Never reset, clean, modify or commit unrelated Vision work. Explicitly list only the files added by a qualification closeout. |

## Closure policy

A result accepted by the owner for the stated scope is **PASS** in the final acceptance table. A product feature not offered by that AT product is **NOT APPLICABLE**. Measured performance figures remain **MEASURED**, not fictitious pass/fail acceptance tests.

Keep precise empirical observations and owner decisions in distinct evidence fields. Do not turn an owner's acceptance into an invented camera image or a researcher's unmeasured performance claim. Corrections should update the current versioned report, not rewrite a dated original.

Retest only if an identified device/software change affects a qualified mechanism, a customer reports a reproducer, or the owner authorises a new specific qualification. Repeating all 15 groups or re-running CPU sweeps without a decision-changing hypothesis is unnecessary.

