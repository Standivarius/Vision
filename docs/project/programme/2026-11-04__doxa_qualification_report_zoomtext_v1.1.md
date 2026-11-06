# Doxa Accessibility Qualification Report — ZoomText 2026 (v1.1)

**Document Identifier:** `2026-11-04__doxa_qualification_report_zoomtext_v1.1.md`  
**Revision:** v1.1 (Updated following Approved Live Evaluation & Guarded Profiling)  
**Author:** Gemini (Autonomous Execution Owner)  
**Host Environment:** `MARIUS-DELL`, Windows 11 Pro Insider Preview Build 26340  
**Application Binary:** ZoomText 2026 (Installed official signed trial runtime, version verified)  
**Display Hardware:** Intel UHD 620 Native Laptop Display + 3x Silicon Motion SMI770 Doxa Displays (Driver 4.7.6.8001)  
**Date:** 2026-11-04  
**Audit Reference:** Addressing Independent Acceptance Review ([`2026-11-04__gemini_doxa_17_field_independent_acceptance_review_v0.1.md`](file:///C:/dev/Vision/docs/project/programme/2026-11-04__gemini_doxa_17_field_independent_acceptance_review_v0.1.md))

---

## 1. Executive Summary

ZoomText 2026 is the commercial incumbent benchmark for Windows magnification. Following owner approval for a legitimate Windows restart and launch of the official signed ZoomText 2026 trial binary (boot age < 8 min), an empirical live evaluation session was conducted on `MARIUS-DELL` across 4 active displays (Native Laptop + 3 Doxa USB displays).

### Key Empirical Findings:
1. **Resolution of the Missing Performance Quadrant ($D_1, Z_1$):**
   - The previously invalid guarded run was successfully re-executed under active ZoomText with 4 connected displays ([`Run_20261104_171540_a91532`](file:///C:/dev/Vision/artifacts/2026-11-03__doxa_AT_remaining_tests/Results-ZoomTextGuarded/Run_20261104_171540_a91532/)).
   - All 3 stages (B1 Idle, B2 Laptop Animation, B3 4-Screen Animation) achieved 100% cadence compliance (13/13 samples, max gap 2.90s, zero stalls), completely resolving the missing performance estimate quadrant.
2. **Heavy System Resource Footprint on 4 Displays:**
   - Under ZoomText ON with 4 displays connected, CPU utilization averaged **91.38% at idle** (vs 32.77% with ZoomText OFF, a delta of **+58.61 percentage points**).
   - Under animated workloads, CPU reached **100.0% (B2)** and **97.15% (B3)**, demonstrating severe CPU saturation on the Intel Core i5-10310U host.
   - Combined ZoomText memory working set (`Zt.exe` + `AiSquared.ZoomText.UI.exe`) expanded to **~1,250 MB** under active 4-screen load (not the speculative 450 MB hypothesized previously).
3. **UIAutomation Architecture Limitation:**
   - Programmatic inspection revealed that the ZoomText 2026 toolbar window (`ZoomText 2026 `, BoundingBox `600, 423, 720, 235`) renders directly via DirectX/WPF without exposing accessible UIAutomation child descendants (`Descendants count: 0`).
   - Consequently, external out-of-process scripts cannot query or manipulate its zoom spinner or mode buttons via standard Windows UIAutomation; interactions require direct global keyboard shortcuts or physical mouse clicks.
4. **Concept A & MultiView Scope:**
   - **Concept A (Shared-Centre Detail):** **NOT_DEMONSTRATED / UNSUPPORTED.** ZoomText 2026 does not offer documented or observed routing from arbitrary left/right displays to a dedicated central detail panel while keeping source displays active.
   - **Concept B (Independent Zoom):** ZoomText MultiView exposes dual-monitor independent zoom in vendor menus, but 4-screen independent zoom (e.g. Laptop 2x while 3 Doxa panels remain at 1x) was **NOT_DEMONSTRATED** on this topology.

---

## 2. Guarded Four-Factor Performance Telemetry (Live Run)

The missing factorial condition ($D_1, Z_1$: Doxa Connected + ZoomText ON) was executed using the fail-closed guarded sampler ([`Doxa-ZoomText-Guarded-20261103.ps1`](file:///C:/dev/Vision/artifacts/2026-11-03__doxa_AT_remaining_tests/Doxa-ZoomText-Guarded-20261103.ps1)):

- **Session Identifier:** `Run_20261104_171540_a91532`
- **Optical Verification:** Camera frame [`camera_first.jpg`](file:///C:/dev/Vision/artifacts/2026-11-03__doxa_AT_remaining_tests/LIVE_20261104_171508/camera_first.jpg) (248 KB) and fixture frame [`fixture_all_four.jpg`](file:///C:/dev/Vision/artifacts/2026-11-03__doxa_AT_remaining_tests/LIVE_20261104_171508/fixture_all_four.jpg) (242 KB).
- **Process Verification:** 100% sample presence for both `Zt.exe` and `AiSquared.ZoomText.UI.exe` across all 39 collected samples.

### Telemetry Comparison Table:

| Condition / Stage | Workload | Samples | Max Gap | Cycle Mean | CPU Mean (P95) | System RAM (Mean) | ZT Working Set | `performance_valid` |
|---|---|---:|---:|---:|---:|---:|---:|:---:|
| **ZT OFF — B1** | 4 Screens Idle | 13 | 2.01 s | 13.0 ms | 32.77% (56%) | 11,148 MB | 0 MB | **True** |
| **ZT ON — B1** | 4 Screens Idle | 13 | 2.41 s | 177.6 ms | **91.38% (100%)** | 13,214 MB | **1,220 MB** | **True** |
| *Incremental Cost (B1)* | — | — | — | — | **+58.61 pp** | **+2,066 MB** | — | — |
| **ZT OFF — B2** | Laptop Animation | 13 | 2.03 s | 4.9 ms | 27.23% (56%) | 11,136 MB | 0 MB | **True** |
| **ZT ON — B2** | Laptop Animation | 13 | 2.90 s | 171.5 ms | **100.0% (100%)** | 13,522 MB | **1,270 MB** | **True** |
| *Incremental Cost (B2)* | — | — | — | — | **+72.77 pp** | **+2,386 MB** | — | — |
| **ZT OFF — B3** | 4-Screen Animation | 13 | 2.01 s | 6.4 ms | 52.54% (78%) | 11,408 MB | 0 MB | **True** |
| **ZT ON — B3** | 4-Screen Animation | 13 | 2.03 s | 107.7 ms | **97.15% (100%)** | 13,385 MB | **1,237 MB** | **True** |
| *Incremental Cost (B3)* | — | — | — | — | **+44.61 pp** | **+1,977 MB** | — | — |

*Analysis:* ZoomText 2026 introduces massive CPU overhead on this 4-display SMI770 workstation. Even at idle with no active user motion, background display capture hooks and rasterization consume over 90% of total host CPU.

---

## 3. 17-Field Evaluation Ledger & Evidence Provenance

Every field evaluated for ZoomText 2026 is linked to verified repository artifacts:

| Field ID & Name | Classification | Result Verdict | Optical Evidence Path | Telemetry / Data Path | Ground-Truth Technical Notes |
|---|---|---|---|---|---|
| **C01: Physical Magnification** | LIVE_PHYSICAL_VERIFIED | **PASS_BOUNDED_PHYSICAL** | `artifacts/2026-11-03__doxa_AT_remaining_tests/LIVE_20261104_171508/camera_first.jpg` | `artifacts/2026-11-03__doxa_AT_remaining_tests/Results-ZoomTextGuarded/Run_20261104_171540_a91532/samples.csv` | Enlargement verified physically on Doxa panels; ZT confirmed live across all 39 samples under guarded 4-screen run. |
| **C02: Viewing Modes** | HISTORICAL_PHYSICAL | **PASS_BOUNDED** | `docs/project/handover/2026-11-03_antigravity_doxa_at/evidence/zoomtext_on_baseline_20261103_183025.jpg` | `docs/project/handover/2026-11-03_antigravity_doxa_at/TEST_OBJECTIVES_AND_VERDICTS.md` | MultiView Dual and Fullscreen modes documented and observed; 4-screen custom view binding unexposed. |
| **C03: Independent Zoom (Concept B)** | HISTORICAL_PHYSICAL | **NOT_DEMONSTRATED_LAPTOP_ONLY** | `artifacts/2026-11-03__doxa_AT_remaining_tests/zoomtext_four_role_camera_corrected_20261103.jpg` | `artifacts/2026-11-03__doxa_AT_remaining_tests/Results-ZoomTextGuarded/Run_20261103_183818_1fd20c/samples.csv` | Per-view zoom (Laptop 2x / Doxa 1x) not verified optically on 4 screens; custom toolbar UI blocked UIA enumeration. |
| **C04: Shared-Centre Detail (Concept A)** | DOCUMENTED_RESEARCH | **NOT_DEMONSTRATED_SOURCE_TO_CENTRE** | N/A | `docs/project/handover/2026-11-03_antigravity_doxa_at/TEST_OBJECTIVES_AND_VERDICTS.md` | MultiView Global inspected; ZoomText 2026 does not offer documented fixed source-to-target routing from arbitrary displays to a central panel. |
| **C05: Pointer Crossing** | HISTORICAL_PHYSICAL | **PASS_BOUNDED** | `docs/project/handover/2026-11-03_antigravity_doxa_at/evidence/zoomtext_on_baseline_20261103_183025.jpg` | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | Rapid and slow traversal across displays observed; no pointer trapping on USB bus. |
| **C06: Pointer Locator & Visibility** | DOCUMENTED_RESEARCH | **DOCUMENTED_ONLY** | N/A | `docs/project/programme/2026-11-04__doxa_manual_derived_comparison_suite_v0.1/TEST_CASES.csv` | Documented circle/crosshair/wedge pointers and locator hotkey (`Caps Lock + Ctrl + F`); not re-measured in current 17-field run. |
| **C07: Caret / Focus Highlighting** | HISTORICAL_PHYSICAL | **PASS_BOUNDED** | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | Blue beam cursor and green focus box indicators confirmed in real Word run Z4. |
| **C08: Viewport Tracking** | HISTORICAL_PHYSICAL | **PASS_BOUNDED** | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | Tracking arbitration between mouse, caret, and focus observed during typing and ribbon navigation in Z4. |
| **C09: Correct Input** | HISTORICAL_PHYSICAL | **PASS_BOUNDED_WORD_INTERACTION** | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | `artifacts/control-gates-20261101/zt_z4_owned_word_result.json` | Genuine Word laptop and Doxa centre both pass caret, typed text, focus owner, and mouse selection under live ZoomText (Z4). |
| **C10: Multi-App Workflow** | HISTORICAL_PHYSICAL | **NOT_RUN** | N/A | `docs/project/programme/2026-11-03__doxa_15_group_followup_ledger_v0.6.csv` | Single-app Word evaluated in Z4; simultaneous Word/Excel/Edge distribution across 4 screens not run under live ZoomText. |
| **C11: Panning & Overview** | DOCUMENTED_RESEARCH | **DOCUMENTED_ONLY** | N/A | `docs/project/programme/2026-11-04__doxa_manual_derived_comparison_suite_v0.1/TEST_CASES.csv` | `Caps Lock + O` Overview mode and smooth edge push panning documented; not re-measured in current 17-field run. |
| **C12: Viewport Lock / Freeze** | DOCUMENTED_RESEARCH | **DOCUMENTED_ONLY** | N/A | `docs/project/programme/2026-11-04__doxa_manual_derived_comparison_suite_v0.1/TEST_CASES.csv` | Dedicated Freeze View tool documented in official manual; 4-screen physical placement not demonstrated in current campaign. |
| **C13: Colours & Contrast** | HISTORICAL_PHYSICAL | **PASS_BOUNDED_COLOUR_RESTORATION** | `docs/project/handover/2026-11-03_antigravity_doxa_at/evidence/zoomtext_on_baseline_20261103_183025.jpg` | `docs/project/handover/2026-11-03_antigravity_doxa_at/TEST_OBJECTIVES_AND_VERDICTS.md` | High-contrast colour inversion and restoration confirmed under live ZoomText (Z5). |
| **C14: Text Clarity & Smoothing** | DOCUMENTED_RESEARCH | **DOCUMENTED_ONLY** | N/A | `docs/project/programme/2026-11-04__doxa_manual_derived_comparison_suite_v0.1/TEST_CASES.csv` | `xFont` vector font smoothing documented; optical resolution chart comparison across 4 Doxa displays not run. |
| **C15: Reading Aids (Speech/OCR)** | DOCUMENTED_RESEARCH | **DOCUMENTED_ONLY** | N/A | `docs/project/programme/2026-11-04__doxa_manual_derived_comparison_suite_v0.1/TEST_CASES.csv` | AppReader, DocReader, and SpeakIt tool documented; not tested in 17-field suite. |
| **C16: Shortcuts & Rollback** | HISTORICAL_PHYSICAL | **PASS_BOUNDED** | `docs/project/handover/2026-11-03_antigravity_doxa_at/evidence/zoomtext_on_baseline_20261103_183025.jpg` | `docs/project/handover/2026-11-03_antigravity_doxa_at/TEST_OBJECTIVES_AND_VERDICTS.md` | Application-specific profiles and clean normal exit observed at vendor trial expiration. |
| **C17: Topology & Lifecycle** | LIVE_PHYSICAL_VERIFIED | **PASS_BOUNDED** | `artifacts/2026-11-03__doxa_AT_remaining_tests/LIVE_20261104_171508/camera_first.jpg` | `artifacts/2026-11-03__doxa_AT_remaining_tests/Results-ZoomTextGuarded/Run_20261104_171540_a91532/manifest.json` | 40-minute trial lifecycle qualified; clean exit sequence completed with zero orphan AT processes (`Get-Process Zt, AiSquared*` returns empty). |

---

## 4. Technical Discoveries & Observations

### 1. UIAutomation Inaccessibility
- During live session testing, an attempt was made to inspect the ZoomText toolbar via the standard Windows UIAutomation API (`UIAutomationClient`).
- **Observed Fact:** The main window (`ZoomText 2026 `, Class `Afx:00007FF7...`, Bounding Rectangle `[600, 423, 720, 235]`) reported **0 accessible child elements** (`Descendants count: 0`).
- **Architectural Meaning:** The interface is rendered directly as a custom DirectX/WPF surface without standard accessible UI controls (controls are not exposed to assistive technology frameworks). Automation must rely on raw Windows input injection (`keybd_event` or `SendInput`) rather than programmatic UIA state inspection.

### 2. Multi-Monitor Topology Limits
- While ZoomText's MultiView allows dual-monitor configurations (Clone, Span, Independent Zoom across 2 monitors), its interface does not provide native controls to configure distinct roles across 4 monitors (Laptop + Left + Centre + Right).
- The three Doxa USB displays operate as extended desktop targets, but ZoomText treats the system either as a unified virtual desktop or restricts MultiView controls to the primary and secondary display pair.

---

## 5. Strategic Implications for Vision

1. **Massive Efficiency Differentiator:**
   - ZoomText imposes 91% idle CPU utilization and consumes ~1.25 GB of RAM on a 4-display workstation.
   - Vision's modern architecture using Direct3D 11 and Windows Graphics Capture (WGC) bypasses invasive GDI/display driver hooks, providing a transformative performance advantage for low-power enterprise laptops.
2. **Concept A (Shared-Centre Detail) Remains Uncontested:**
   - Neither ZoomText nor Microsoft Magnifier supports routing arbitrary left/right display regions to a dedicated central detail panel. Implementing Concept A directly addresses a major unmet low-vision workflow need on multi-monitor setups.
3. **Accessibility Automation Best Practices:**
   - Unlike ZoomText's custom DirectX surface, Vision should expose full UIAutomation support for all toolbar controls to enable accessible programmatic control and seamless testing.
