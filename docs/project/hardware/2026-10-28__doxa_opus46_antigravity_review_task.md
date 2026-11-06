# Manual Antigravity task — full independent Opus 4.6 Doxa installer review

**Model to select in Antigravity:** Claude Opus 4.6 (Thinking), exact model ID `claude-opus-4-6-thinking`. Use the Antigravity subscription interface, not direct Anthropic/OpenAI API keys.

**Open this existing isolated Vision worktree:** `C:\wt\doxa-review-package-20261028`

**Required final output file (FULL ABSOLUTE PATH):**

`C:\wt\doxa-review-package-20261028\docs\project\hardware\2026-10-28__doxa_opus46_antigravity_independent_review.md`

**Do not use a relative output path and do not save the report in the dirty main checkout.**

## How to execute in the Antigravity desktop UI

1. Open `C:\wt\doxa-review-package-20261028` as the folder/workspace in Antigravity.
2. Select **Claude Opus 4.6 (Thinking)**.
3. Give it this entire task file, either by pointing it to this path or pasting its contents.
4. Allow it to read actual code and test scripts, but not install or uninstall anything, modify drivers or screens, run live deployment, use network deployment tools, or call other AI agents.
5. **The sole authorized file modification is creating the output report at the exact required path above.** No source edits, no staging or commits, no new branches.
6. Have it provide complete substantive findings and save them to the output path; do not stop after a plan, progress narration, or a claim it will inspect files later.
7. After it finishes, ask it to verify the saved file exists and includes concrete file-and-line citations for its claims. Report the full path and a short summary.

Do not read existing Sol, Muse, Gemini or previous Opus review reports before finishing the independent assessment. A report from the local Antigravity CLI has **not** yet been obtained; it authenticated successfully but broad prompts only yielded preliminary statements. The manual UI task must generate the complete report.

---
# Independent Claude Opus 4.6 (Thinking) review — entire Standivarius Doxa Windows installer

You are an INDEPENDENT engineering reviewer, working manually in the Google Antigravity desktop UI with model **claude-opus-4-6-thinking**. The user specifically commissioned a second independent review of the **ENTIRE Doxa installer application**, not the Vision magnifier and not merely the new Fault Lab.

## STRICT BOUNDARIES

- **READ-ONLY SOURCE INSPECTION** in repository worktree: `C:\wt\doxa-review-package-20261028` (branch `doxa/review-package-20261028`; commit `430dc7229c471a9ae69d9f4d4759149ac0699718`).
- Use Antigravity file-reading and analysis capabilities. The ONLY exception to the no-write rule is creating the required output report Markdown file. Do not modify source, delete, stage, commit, push, clean, stash, install or uninstall anything. The main `C:\dev\Vision` checkout is dirty and MUST NOT be changed.
- Do not interact with physical Windows monitors, graphics adapters, services, drivers, installed packages, Intune/ManageEngine, Cloudflare production or accounts. Do not run installer binaries, publisher/cloud deployment commands, MSI, `pnputil`, `Disable-PnpDevice`, or any non-read-only test. Never run real Fault Lab trials, even if source suggests it.
- Read local files and use safe text/grep or static test source inspection as needed; avoid network or terminal commands that could mutate state. No other LLM or agent calls, no API provider substitutions, no delegation. Do not access local secrets or `.env` values.
- Existing review conclusions by **Sol, Gemini, Muse, or other agents** are deliberately withheld. Do NOT open their raw reports, triage reports, or handover review conclusions. Do not assume they are correct. Work from actual source and neutral product brief below. Analyze the software as currently committed rather than a historical version.

## FULL APP SCOPE

Review **all production components and their actual cross-component call paths** for the Doxa Windows installer in `app/packaging/doxa-setup` (including its `README.md` and relevant tests), especially:

1. Personal customer WinForms native host: `full-release/DoxaSetupHost.cs`; `full-release/Build-DoxaCompleteRelease.ps1`, `Build-DoxaRetailRelease.ps1`, `Finalize-DoxaSignedRelease.ps1`, tests/checkers.
2. The complete guided installer: `personal-ui/Start-DoxaGuidedSetup.ps1`, `Start-DoxaSetup.ps1`, `Doxa-BrandTabs.ps1`, consent, language, help chat, monitor illustrations and checkmarks, driver install actions, Windows settings and errors.
3. Device diagnostics: `Get-DoxaDriverState.ps1`, `personal-ui/Get-DoxaSetupExperience.ps1`, `Get-DoxaCompatibility.ps1`, installation and physical monitor identity assumptions, driver preservation, stage boundaries.
4. Online AI service **for this installer**: `personal-ui/Ask-DoxaInstaller.ps1`, `Get-DoxaDeviceSignature.ps1`, `Get-DoxaCloudAIPolicy.ps1`, `Get-DoxaKnowledgeAnswer.ps1`, `knowledge/*`, `assistant/worker.mjs`, `assistant/scope.mjs`, `assistant/curated-kb.mjs`, assistant tests. Assess privacy, authentication, anti-replay, scope, hallucination boundaries, network failure and tool-execution risk. Do not confuse it with `support/doxa-cloud/visual-assistant-worker`, which belongs to the separate Vision assistant.
5. Enterprise packaging/maintenance: native `DoxaDeploy.exe` behavior, detection versus verification, repair/uninstall, first-time USB-disconnected staging, unattended SYSTEM, Intune/ManageEngine content, existing `enterprise-intune-pilot` and `full-release` deploy/cleanup scripts, signing and SHA-256/inventory parity, WDAC/AppLocker expectations.
6. Safe recovery/testing: `recovery/*`, `scenarios/*`, and `fault-lab/DoxaDisplayPath.cs`, `Invoke-DoxaFaultLab.ps1`, `fault-catalog.json`, `Test-DoxaFaultLab.ps1`. Specifically evaluate primary monitor safety and detached watchdog/restore implementation, distinguishing read-only validation from real restore proof.
7. Any critical `support/doxa-cloud` file only if actually imported/called by this Doxa installer. Avoid irrelevant magnification implementation, obsolete plans, and other project areas.

## PRODUCT AND ACCEPTANCE GOAL

Standivarius Doxa is a portable three-external-monitor accessory for a Windows laptop. The desired consumer deliverable is a single branded installer EXE: power first, USB-C data second; a **logical** non-repeating setup flow; detect Doxa once at the right stage; recognize all three external monitor identities and mark each separately; guide Windows Extend and four-display layout; install only the trusted original signed Silicon Motion driver if necessary with UAC; preserve healthy existing driver; no unexpected restart, no hidden legacy installer dialogs. Local read-only hardware checks require explicit consent; optional online Doxa AI requires separate consent and respects IT policy. User-facing UI should be responsive, English/Romanian, high-DPI and screen-reader usable. The persistent right-side panel is a genuine Doxa Help chatbot, not the step instructions masquerading as chat.

The enterprise native silent installer must share a verified package baseline for Intune (.intunewin) and ManageEngine; software detection must not flap on USB hotplug; hardware verification must not overclaim active four-screen Extend mode; repair/uninstall must work. First-time driver-less clean installs, full live enterprise agent tests, retail publisher signing, and deployment policy checks are distinct test gates.

The separate Doxa Fault Lab is an **attended developer test utility, not bundled in retail**. It can simulate five problems and may temporarily disable *one non-primary external Windows display* for 15–90 seconds using an independently running restore watchdog. It must never make cloud AI execute commands. Only READ-ONLY selftests, CCD validation and snapshot roundtrip have been done so far; no actual physical monitor-disable/restore test is established.

## EVIDENCE HANDLING

- Investigate the actual call graph, interfaces, release scripts and self-test assertions. Where two different scripts coexist, determine which one is actually shipped/invoked (and note obsolete pathways, not just file existence).
- Separate **source-confirmed defect**, **probable risk needing live confirmation**, **release gate currently unproven**, and **cosmetic/low-risk issue**.
- Cite exact relative source paths and line numbers or method/function names for EVERY material issue. Explain the causal failure path and observable impact; don't invent bugs or claim a runtime failure solely from static suspicion.
- Challenge self-tests claiming broader coverage than they exercise. A virtual/fixture pass is not a physical installation test. Do not count missing signing or acceptance gates as a code defect unless code itself mishandles them.
- Do not cite earlier reviewers or present yourself as having performed physical tests. You may read existing non-review release evidence/manifests if it supports a claim.
- Provide the most practical minimal fixes/tests. Prioritize actual customer install failure, display safety, data privacy and enterprise trust over aesthetic polishing.

## REQUIRED OUTPUT

Write a thorough final review in the required Markdown output file at the absolute destination path at the top of this task, and summarize it briefly in your Antigravity response. This is the ONLY authorized file write:
A. Executive decision: production readiness for *retail*, *Intune*, and *ManageEngine* **independently** (PASS / CONTROLLED PILOT / HOLD, with exact reason).
B. Component inventory and **actual complete end-to-end customer journey** as currently coded: from double-click to physical screens to optional AI; note dead ends/repetition or surprising sequence.
C. Prioritized table of up to 15 **material** findings (P0/P1/P2), classification, specific location/call path, evidence, impact, minimum remedy and targeted test.
D. Deep assessment of online AI architecture and safe test utilities/watchdog, including what can/cannot be automatically repaired; privacy and permissions.
E. What is genuinely working, what read-only/source fixtures prove, what remains unproven on a real driver-free Windows computer.
F. A minimal ordered remediation + verification sequence fit for shipping a commercially useful installer, avoiding overengineering.

Target ~2,000–3,500 words; accurate and well-referenced. Do not ask follow-up questions; inspect source, write the report to the exact output path, verify that it exists, and finish the independent review now.