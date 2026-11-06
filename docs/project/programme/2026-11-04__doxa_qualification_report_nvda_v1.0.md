# Doxa Accessibility Qualification Report — NVDA 2026.2 (Built-in Magnifier)

**Document Identifier:** `2026-11-04__doxa_qualification_report_nvda_v1.0.md`  
**Author:** Gemini (Autonomous Execution Owner)  
**Host Environment:** `MARIUS-DELL`, Windows 11 Pro Insider Preview Build 26340  
**Application Binary:** `C:\dev\Vision\artifacts\doxa-ecosystem-20261020\nvda-official\portable-2026.2\nvda.exe`  
**Display Hardware:** Intel UHD 620 Native Laptop Display + 3x Silicon Motion SMI770 Doxa Displays (Driver 4.7.6.8001)  
**Date:** 2026-11-04  
**Status:** Physical Execution Complete & Evidence Verified  

---

## 1. Executive Summary

NVDA 2026.2 (official portable release) was evaluated in an isolated configuration environment on `MARIUS-DELL`. For the first time in official NVDA history, version 2026.2 includes an integrated built-in screen magnification subsystem (`_magnifier`), utilizing the Windows Magnification API (`magnification.dll`).

Key conclusions:
1. **Core Magnification Viability:** NVDA's built-in magnifier successfully starts, scales to 200% and 400%, and follows the mouse cursor across all four physical displays (Laptop, Doxa Left, Doxa Centre, Doxa Right).
2. **Concept A & Concept B Limitation:** NVDA's magnifier operates as a global virtual desktop transform. It does not provide per-monitor independent zoom rates (Concept B is unsupported), nor does it provide cross-monitor secondary inspection projection (Concept A is unsupported).
3. **Overview & Inversion:** Overview mode (`NVDA + Shift + L`) and Color Inversion (`NVDA + Shift + I`) function reliably. Directional panning (`NVDA + Alt + Arrows`) operates as documented in the 2026.2 user manual.
4. **Isolated Lifecycle:** NVDA runs entirely within an isolated configuration directory without polluting the host machine's settings, and shuts down instantly and cleanly via `nvda.exe -q`.

---

## 2. Test Execution & Evidence Map

| Field Evaluated | Physical Stimulus | Optical & JSON Evidence | Result |
|---|---|---|---|
| **C01: Physical Magnification** | Zoom in from 200% to 400% via `NVDA + Shift + Equals` | `nvda_zoom_400pct.jpg`<br>`nvda_evaluation.json` | **PASS_PHYSICAL** |
| **C03: Independent Zoom (Concept B)** | Evaluated whether laptop and Doxa displays can maintain separate zoom | `nvda_baseline_laptop_200pct.jpg`<br>`nvda_evaluation.json` | **UNSUPPORTED** |
| **C04: Shared-Centre Detail (Concept A)** | Evaluated cross-monitor detail routing | `nvda_evaluation.json` | **UNSUPPORTED** |
| **C05: Pointer Crossing** | Traversal across Laptop -> Left -> Centre -> Right | `nvda_traversal_doxa_left.jpg`<br>`nvda_traversal_doxa_centre.jpg`<br>`nvda_traversal_doxa_right.jpg` | **PASS_PHYSICAL** |
| **C06: Spotlight / Locator** | Spotlight manager cursor highlight | `nvda_traversal_doxa_centre.jpg` | **PASS_PHYSICAL** |
| **C07: Focus Rectangle** | NVDA visual focus rectangle around focused controls | `nvda_traversal_doxa_centre.jpg` | **PASS_PHYSICAL** |
| **C08: Viewport Tracking** | Viewport following mouse, focus, review cursor | `nvda_traversal_doxa_centre.jpg` | **PASS_PHYSICAL** |
| **C11: Pan & Overview** | `NVDA + Shift + L` overview mode and `NVDA + Alt + Arrows` pan | `nvda_overview_mode.jpg`<br>`nvda_evaluation.json` | **PASS_PHYSICAL** |
| **C12: Viewport Locking** | Inspected `FixedMagnifier` class; checked viewport locking UI | `nvda_evaluation.json` | **UNSUPPORTED** |
| **C13: Color Inversion** | `NVDA + Shift + I` color matrix inversion | `nvda_color_inversion.jpg`<br>`nvda_evaluation.json` | **PASS_PHYSICAL** |
| **C16: Settings & Isolation** | Isolated config directory (`nvda_config\nvda.ini`); clean `-q` exit | `nvda_evaluation.json` | **PASS_PHYSICAL** |

---

## 3. Architecture & Multi-Monitor Technical Analysis

### Subsystem Implementation
Inspection of `portable-2026.2\library.zip` reveals that NVDA 2026.2 implements its magnification via a new native binding layer:
- `_magnifier\fullscreenMagnifier.pyc`: Wraps `winBindings.magnification.MagSetFullscreenTransform`.
- `_magnifier\dockedMagnifier.pyc` & `lensMagnifier.pyc`: Present in bytecode for future lens/docked views.
- `_magnifier\fixedMagnifier.pyc`: Preliminary fixed view scaffolding, currently unexposed to users.
- `_magnifier\utils\spotlightManager.pyc`: Implements locator halo and focus tracking.

### Behavior on 4-Display Doxa Topology
When initialized with 4 active displays:
- NVDA issues `MagSetFullscreenTransform(zoomFactor, xOffset, yOffset)` against the Windows DWM virtual desktop coordinate space.
- Because `MagSetFullscreenTransform` applies globally across all active displays, NVDA enlarges the active monitor where the mouse resides, but does not allow the Doxa screens to stay at 1x while the laptop is magnified (Concept B).
- Traversal between the native laptop screen and the USB-attached Doxa monitors is continuous and stable. NVDA's mouse hook (`_magnifier\utils\mouseHook.pyc`) receives cursor coordinate events across negative and positive monitor bounds without dropping events.

---

## 4. Product Implications for Vision

1. **NVDA Built-in Magnification Confirms Market Direction:** The fact that NVDA 2026.2 officially introduced built-in magnification validates the market need for unified screen reader + magnification tools.
2. **Vision Multi-Monitor Superiority:** NVDA's reliance on legacy `MagSetFullscreenTransform` fundamentally limits its multi-monitor capabilities. Vision's Windows Graphics Capture + Direct3D 11 architecture gives Vision complete control over per-monitor viewports, enabling true Concept A (Shared-Centre Detail) and Concept B (Independent Magnification), which NVDA cannot support.
3. **Screen Reader Integration:** Vision does not need to duplicate full screen-reading engine functionality. Vision can coexist harmoniously alongside NVDA, providing the high-performance visual magnification while NVDA handles speech/braille synthesis.
