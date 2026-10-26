# Doxa Setup — guided visual review

**Candidate:** Private unsigned Doxa Setup 0.4.0-preview.7.
**Where:** At the physical MARIUS-DELL console, with three Doxa panels plus laptop display.
**Time:** 15–25 minutes. You can stop early.
**Goal:** Judge whether a new user understands the installer and can use it, not repeat the automated installation tests.

## Before starting

- Double-click **Doxa Setup - TEST preview.7** on Dell's desktop.
- Do not connect using Windows Remote Desktop/RDP: that creates a virtual display session. Physical Dell is preferred for this review.
- Do NOT click **Install signed driver...**. Do not approve an unexpected administrator dialog, unplug screens, reboot, change display topology or reinstall Silicon Motion.
- Keep the screens connected. If a display stops behaving as before, close Doxa Setup and stop the review. We handle driver failure recovery in a separate experiment.
- Romanian remains a placeholder. Check whether language switching works; do not demand finished Romanian copy.
- For each scenario record PASS / PROBLEM / NOT TESTED and one short comment for problems.

## A. Welcome and consent — 4 minutes

**A1 — First glance.** On Welcome to Doxa Setup, without pressing anything, can you tell what this program does and what to do next? Check font size, buttons, visuals, contrast, breathing room. EXPECT: no scan starts before you approve local checks.

**A2 — Privacy.** Locate the separate boxes for *local read-only Windows checks* and *optional cloud AI*. Open **What is sent to cloud AI? Privacy and AI details**. EXPECT: both choices default OFF and the notice is understandable; offline use remains possible.

**A3 — Move forward.** Approve **local checks only**, keep AI OFF, select Continue. On step two select **I will connect Doxa now (or it is already connected)**, then **Open Doxa Setup**. EXPECT: clear two-step flow; no surprise UAC prompt.

## B. Connected equipment — 4 minutes

**B1 — Check.** Select **Check Doxa**. EXPECT: current signed Silicon Motion driver and connected Doxa detected; no unnecessary reinstall recommendation. Are the status lines understandable to a nontechnical customer?

**B2 — Reality.** Visually confirm the laptop and three Doxa screens look as before. Do not move windows or rearrange displays. EXPECT: installer has not changed physical desktop configuration.

**B3 — Help.** Select **Connection steps**. EXPECT: simple steps for power, USB data, Windows display Extend, and checking Doxa. It must not run a driver-install command.

## C. Usability and accessibility — 5 minutes

**C1 — Design.** Evaluate text legibility, spacing, contrast, device illustration, clear main action and whether the help conversation is easy to find. What are the three most irritating elements?

**C2 — Compact.** If ordinary window resizing is available, try a narrower width. EXPECT: all main controls remain readable, especially the signed-driver label and help. If resizing is not available, mark NOT TESTED; automated 440/480/522-pixel checks already passed.

**C3 — Keyboard.** Press Tab and Shift+Tab. Use Enter or Space on a safe control such as **Connection steps**. EXPECT: visible focus indicator, sensible navigation, no keyboard trap. Optional: use NVDA if already installed, but do not install new programs for this review.

**C4 — Language.** Change English to **Romana** and back. EXPECT: main labels change without losing detection or hiding controls. Note serious broken layout/meaning; translation remains a placeholder.

## D. Troubleshooting — 4 minutes

**D1 — Offline first.** With remote AI still OFF, type **My Doxa USB screen is black. What should I check first?** in **Doxa help**, then click **Ask**. EXPECT: quick, practical offline answer with no automated driver repair.

**D2 — Context.** Ask **Remote Desktop shows one screen, but the Dell console has three Doxa screens. Should I reinstall the driver?** EXPECT: distinguishes RDP virtual session from physical screens; avoids reinstalling a known-good driver.

**D3 — Optional cloud AI.** Only if desired: close and reopen the installer, explicitly opt in to cloud AI at Welcome, repeat D1 once. EXPECT: offline advice appears immediately, with a separate AI answer if the signed service responds. Record time and whether AI adds value. You can use **Switch to offline help** afterwards. This is optional.

## E. Close and decide — 2 minutes

**E1 — Exit.** Close normally. EXPECT: Dell screens and driver still work, no reboot/elevation or topology change.

**E2 — Verdict.** Choose one: **Ready to show a customer / Needs polish / Confusing or blocked**. This verdict is only about usability of the private app, NOT a signed commercial release.

## Scorecard — fill only the problems if short on time

| ID | PASS / PROBLEM / NOT TESTED | One-line note if problem |
| --- | --- | --- |
| A1 Welcome understandable | | |
| A2 Consent and privacy | | |
| A3 Steps and navigation | | |
| B1 Driver and device status | | |
| B2 Screens unchanged | | |
| B3 Connection help | | |
| C1 Look and legibility | | |
| C2 Narrow-window behaviour | | |
| C3 Keyboard / optional NVDA | | |
| C4 Language switch | | |
| D1 Fast offline answer | | |
| D2 RDP versus physical display advice | | |
| D3 Optional AI | | |
| E1 Clean close | | |

**Three changes I want first:** 1. ____ 2. ____ 3. ____
**My verdict:** ____
**Minutes spent:** ____
**Screenshot names, if any (avoid private information):** ____

## Return feedback

In ChatGPT, write **Doxa preview 7 review**, then paste only failed or notable scorecard rows. If a screenshot helps, include it with the ID (for example, C3). Do not spend time reporting routine PASS entries.

**Outside this review:** driver removal, physical USB failure, topology changes, reboot, enterprise security-policy manipulation, paid signing, OEM distribution and public release. These require separate recoverable tests and approvals.
