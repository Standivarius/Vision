# Vision POC A independent four-screen qualification — 2026-10-18

## Executive result

Core POC A manual and optional automatic source selection on the real Dell
four-monitor physical-console arrangement: **PASS at the independently
observed software-pixel level**, including correct source, visible content
freshness, and measured 2.000x zoom.

This is NOT a camera-based verification of the physical Doxa SMI770 panel,
a real-user ergonomic judgement, or proof of Word/Excel semantic caret follow.

## Test methodology

A protected disposable WinForms source on Left or Right paints distinctive
yellow/green animated backgrounds and fixed-pitch black ruler lines every
128 native source pixels. The existing Vision POC controller selects source.
An independent Win32 observer samples true OS foreground windows at 10Hz,
and a separate GDI recorder captures the Centre display at 480x270 and 3fps.
Both streams use the same QPC origin; raw frames have SHA-256 manifests.

The independent image checker reconstructs source identity, visible changes
and zoom from PNG pixels, without using Vision's own frame/source/zoom logs.
Expected 2x ruler spacing is 128 source px x 2 zoom x 480/1920 = 64 PNG px.
Any wrong observed source or measured zoom is a failure. Missing evidence is
inconclusive, bad topology or locked desktop blocked.

Each zoom phase requires >=90% independent ruler observations and <=1800ms
between verified measurements, in addition to broader evidence coverage.

## Qualified run 1: manual roundtrip

Run: artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-110741-777a54

- Scenario: LEFT -> RIGHT -> LEFT -> RIGHT.
- Verdict: PASS (all four phases, source + freshness + independent 2x zoom).
- Evidence: 183 centre PNG frames, 610 Windows OS samples, 171 independently
  measured zoom frames. Observed scale range in measured frames: exactly 2.000x.
- Within each qualified stable phase, zoom-measurement coverage was 100%;
  measured max zoom-evidence gap <=743ms and content-update gap <=1036ms.
- Vision telemetry was diagnostic only. 3 live renderer source rebinds; one
  continuous preview process; clean exit; pointer restored.
- Side-effect conditions: no document, driver or display-setting modifications.
  Previous foreground window was NOT reliably restored (cleanup limitation).

## Qualified run 2: automatic foreground following

Run: artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-111020-4db96f

- Scenario: optional auto-follow defaults OFF; explicitly enabled. Five
  independent OS segments: LAPTOP / RIGHT / LAPTOP / RIGHT / LEFT.
- Verdict: PASS (all five source + visible freshness + independent 2x phases).
  During laptop focus, Detail held the previous source as intended.
- Evidence: 258 independent centre PNG frames, 860 OS samples, 242 measured
  zoom frames, observed range exactly 2.000x.
- Stable phases achieved 100% independent ruler coverage; maximum qualified
  zoom evidence gap <=789ms and visible update interval <=1122ms.
- Two automatic source rebinds; one Vision preview process; clean exit.
- Actual observed source changes were derived from OS foreground timestamps,
  not from delayed PowerShell click-return times.
- Pointer restored. Original foreground not reliably restored.

## False-positive controls

For EACH qualified run, seven independent evidence mutations produced the
expected verdicts without changing original evidence:

1. Wrong visible source -> FAIL.
2. Frozen visible content counter -> FAIL.
3. Wrong observed 4x instead of 2x -> FAIL.
4. Missing independent panel evidence -> INCONCLUSIVE.
5. Missing independent zoom evidence -> INCONCLUSIVE.
6. Locked Windows desktop -> BLOCKED.
7. Invalid display topology -> BLOCKED.

32 dependency-light unittest checks pass, covering assessor rules, GDI RGB
PNG encoding, SHA/CRC validation, stale images, ruler classification,
1x/2x/4x scale discrimination and missing/late observations.

Earlier diagnostic runs with incomplete zoom measurements remain retained
under their own unique IDs, not overwritten or retrospectively relabelled.
The native-control runner replaced unreliable UI Automation patterns.
The opaque ruler background avoids intermittent transparent overlay loss.

## Important residual gaps

- The independent camera/optical fidelity assessment is still outstanding.
  GDI output captured on physical-console Windows does NOT prove visible
  photons on the SMI770 USB display, nor photonic latency. Physical camera
  and recording ON/OFF comparison must be conducted separately.
- Word/Excel semantic caret-in-view and 4x/other zoom levels are not proven
  by this POC A ruler test. Scenario charter files A02-A06 are not claimed
  executed by this report.
- Original app foreground restoration currently fails; while pointer and
  preview cleanup pass, do not claim full desktop focus restoration.
- The bridge-level limited-user recovery watchdog is installed and verified.
  The privileged Windows RDP-to-console recovery task is not installed,
  because that task requires an elevated Windows admin context. Development
  and the accepted physical tests were conducted using the working bridge.

## Repository and reproducibility

Canonical code: lab/pocs/doxa/assessment/
Runbook: lab/pocs/doxa/assessment/README.md
Baseline project: GitHub Vision Project #6 / issue #61.

Commands:
  python -m unittest discover -s lab/pocs/doxa/assessment -p "test_*.py" -q
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/Test-VisionTriangulatedManualZoomAtomic.ps1
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/Test-VisionTriangulatedAutoZoomAtomic.ps1

Do not run these tests while personal/private content is displayed or when
another test or Vision preview is already open. Scripts require an unlocked
four-display console, use unique evidence paths, and deliberately do not
modify Windows drivers/policies or other development sessions.

