# Independent Review Work Order — Doxa Setup Preview.10

**27 October 2026 · REVIEW ONLY — NO IMPLEMENTATION OR MERGE**

Repository: Standivarius/Vision
Source branch: doxa/preview10-brand-tabs-20261027
PR base: doxa/installer-clean-pr-20261024
Related issues: #98 (owner UX), #99 (full physical installer), #75 (overall installer)
Prior baseline: Preview.9 at commit 06c7f80

## Mandate

Act as an independent, sceptical senior Windows desktop application engineer, security reviewer and usability reviewer. Read the **actual changed source files** and inspect relevant supporting code; do not rely solely on the PR description, provided screenshots, or passing smoke tests. Do not change any code, request another model, change hardware, reinstall drivers, alter display topology, or merge.

The product is the independent Doxa hardware setup application, **not** Vision's low-vision magnifier. The owner wants a usable install experience; passing unit tests does not establish visual correctness.

## Intended Preview.10 behaviour

- Brand and colour: genuine Standivarius logo, predominantly white/neutral UI with burgundy accents; simple monitor illustrations.
- One native Windows Forms window throughout welcome/permissions, connection choice and setup. No closing/reopening or visible replacement effect.
- Three primary selectable tabs: Detect Doxa; Set up screens; Install signed driver. The active tab must visually connect to **one continuous coloured boundary around the entire workspace, including its right-hand contextual area**, while inactive tabs remain neutral.
- Set up screens contains two secondary subtabs: Connect Doxa and Arrange four screens; contextual guidance updates with the selected subtab.
- Diagram: three same-size stand-free external monitors numbered Screen 2, Screen 3, Screen 4 from left to right; laptop Screen 1 below the central Screen 3; Windows screen numbering may differ.
- Physical connector drawing: **TOP USB-C socket is POWER; BOTTOM USB-C socket is DATA/SIGNAL**, both behind the central screen. Connect power first, then data.
- Offer a direct Windows Display settings link and human-readable guidance for Extend, Identify, arranging, Apply, and mouse movement laptop-up-to-centre, then left/right.
- Doxa Help must allow reversible offline/online selection. No remote AI calls without explicit consent; organisational policy may prohibit online AI.
- Preserve safe, gated driver diagnostics. Never force an unnecessary reinstall when a healthy signed driver is already installed.

## Tough questions — answer EACH with line citations and explicit evidence

1. **Does one-window really mean one *coherent* UI?** Walk consent -> connected selection -> Detect -> Set up -> Arrange -> Install -> Detect again. Does the same HWND remain? Are resizing, focus, event subscriptions, old Form controls, stale labels, tab highlights and the right-hand context handled correctly? Where can the user's experience still appear as an abrupt screen replacement?

2. **Can revoked AI consent be violated by a race?** Inspect offline -> online -> offline switching while an online job is pending, policy changes, first consent, repeated opt-in, language changes, async timer, and any remote request already underway. Distinguish cancellation of a local job from actual cancellation of remote inference. Suggest an enforceable and testable consent state machine.

3. **Are detection results trustworthy?** Can the installer mislabel USB/PnP devices as three independently usable external Windows displays? Can remote desktop topology, driver-store presence, version mismatches, unexpected port/controller states, or a display sleeping lead to misleading green checks? Clearly separate cosmetic diagram labels from Windows-assigned IDs and actual observed evidence.

4. **Could the driver action damage the working system?** Trace the exact Install signed driver handler through signed MSI selection, signature/hash checks, admin elevation, PowerShell argument quoting, target hardware qualification, no-op behaviour, and rollback. Identify security/trust-boundary weaknesses. Do not test with real driver removal or installation.

5. **Is the interface accessible at real-world Windows sizes?** Verify high DPI, 125/150/200% scaling, 1280×720 laptop screen, narrow windows, multi-monitor taskbars, keyboard traversal, focus indication, screen readers, contrast, live result announcements, language switching, and scroll reachability. Which important controls are clipped or invisible? Provide reproducible checks rather than blanket PASS claims.

6. **Is the port graphic accurate and unambiguous?** Compare diagram, text, local offline help, Romanian strings and user-approved orientation: upper = power, lower = signal/data. Do any paths contradict this? Could a different physical Doxa hardware revision invalidate the guidance? Suggest a design that stays readable even without colour.

7. **Is the layout guidance actionable without making unsafe changes?** Do tabs merely explain, or misleadingly imply they arrange Windows displays? Is the ms-settings:display link accurately described? How should Identify and Windows's actual monitor numbering be explained? What minimum validated mechanism, transaction/preview, explicit approval and rollback would be needed for a later AI-suggested screen arrangement?

8. **What do the tests NOT prove?** Assess BrandTest, SeamlessTest, GUI smoke tests, extracted-ZIP checks, use of static Form properties, hash verification, logo asset lifecycle, packaging, event handlers, and error paths. Name at least **three highest-value additional tests** that would realistically catch regressions missed by the current suite. Is any old UI or click handler still live underneath the new tabs?

## Scope of code inspection

Changed files:
- app/packaging/doxa-setup/personal-ui/Doxa-BrandTabs.ps1
- app/packaging/doxa-setup/personal-ui/assets/standivarius-official-logo.png
- app/packaging/doxa-setup/personal-ui/Start-DoxaSetup.ps1
- app/packaging/doxa-setup/personal-ui/Start-DoxaGuidedSetup.ps1
- app/packaging/doxa-setup/Build-DoxaPersonalBundle.ps1
- app/packaging/doxa-setup/Test-DoxaPersonalBundle.ps1

Review the existing help/client, hardware detection, policy and driver-install code called by these files, and AGENTS.md. Inspect file-by-file diff against the PR base, not an unrelated Vision master diff.

## What the current checks show — do not overstate

On Dell on 27 October, the extracted Preview.10 ZIP test reported PASS (20 hashed source entries, 23 archive files, English/Romanian flows, same-form checks, no network requests and no driver modifications during testing). Local tested archive SHA-256:
9C57E647B71411DF409EDC11F56ECBB4BD59E0AB6FF4D9549FD651A4E61DBF35

This is an **UNSIGNED APP-ONLY PREVIEW**; there is no Silicon Motion redistributable driver payload. Full first-time driver installation, OEM redistribution permission, automatic topology apply/rollback and production signing remain open. Do not treat a passing smoke test as human UI acceptance.

## Expected answer format

A. **Verdict:** ACCEPT / ACCEPT WITH CHANGES / REJECT, with reasons.
B. **Findings table:** P0/P1/P2 severity, file:line, reproducible condition, impact, correction, minimal test. Separate confirmed defects and hypotheses.
C. **Eight hard-question answers**, succinct and evidence based.
D. **Top five fixes or simplifications**, prioritised by effect, risk and implementation effort. Avoid ornamental redesign.
E. **Release blockers** versus acceptable preview limitations; explicitly state what remains untested on physical Windows hardware.
F. **Suggested code changes**: precise patch guidance, not code changes made in the repository.

Review only: no pushes, merges, code edits, autonomous delegation or physical device actions.
