# Vision POC A — independent four-display assessment

Status: 2026-10-18. Evidence-backed, physically attached four-monitor
Doxa setup, with independent OS foreground and recorded software-display
assessment. This is NOT external optical-camera or genuine-user acceptance.

## Verified acceptance

Environment: MARIUS-DELL, physical Windows console, laptop + 3 Doxa
screens, no active RDP. No drivers, settings or personal documents changed.

- MANUAL source+freshness: LEFT -> RIGHT -> LEFT -> RIGHT; 4 of 4 phases
  passed, 122 centre GDI frames, 610 OS foreground observations, 3
  renderer rebinds, one preview process, clean shutdown. Raw:
  artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-092023-3be9e0
- AUTOMATIC foreground source+freshness: all 5 real OS phases pass
  (LAPTOP -> RIGHT -> LAPTOP -> RIGHT -> LEFT). 172 independent software
  frames, 2 renderer rebinds, laptop-focus hold, clean shutdown. Repeat:
  artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-093436-3c89b3
- MANUAL source+freshness+independently measured 2x: 4 of 4 phases
  passed, 183 independent centre images, three source rebinds, 171
  independently observed 2x ruler frames, one preview, clean shutdown.
  Raw: artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-110741-777a54
- AUTOMATIC source+freshness+independently measured 2x: 5 of 5 OS
  foreground segments passed, 258 independent centre images, 2 rebinds,
  laptop hold, one preview, clean shutdown. Raw:
  artifacts/vision-poc-a-graphics-20261017/triangulated-20261018-111020-4db96f
- Fault injection: wrong source and frozen image -> FAIL; missing
  independent output -> INCONCLUSIVE; locked session or invalid topology ->
  BLOCKED. Original evidence remains immutable.
- Pure tests: 32 tests passed (2026-10-18), including wrong 1x and 4x
  magnification, PNG CRC, stale image and evidence gaps.

Zoom ruler: the disposable WinForms source contains black vertical bars
repeating every 128 native source pixels. A 1920px destination sampled to
480px should have 64px PNG bar spacing at 2x. That 2x spacing was observed
independently of Vision's own reported zoom. The scorer requires at least
90% zoom-measurement coverage per phase, and no more than 1800ms between
verified samples. Wrong measured zoom cannot be hidden by missing frames.
Opaque pre-rendered source tiles keep ruler and tint visible together.

## Independent assessment architecture

1. STIMULUS: existing POC A controller with disposable LEFT and RIGHT
   Windows Forms sources; optional focus-follow OFF by default. No personal
   documents read. The colour/ruler animation is deterministic.
2. OS OBSERVER: win_observer.py samples actual Win32/DWM foreground
   process/window/monitor geometry and lock state, 10Hz, with QPC.
3. FRAME RECORDER: frame_recorder.py separately captures Doxa Centre
   software-visible GDI pixels, original PNG SHA-256 and QPC stamps.
4. VISUAL ORACLES: marker_oracle.py classifies LEFT/RIGHT tint changes.
   zoom_oracle.py estimates actual software-visible magnification from
   repeated ruler spacing, never from Vision telemetry.
5. VERDICT: assessor.py merges two independently recorded streams on the
   exact same QPC origin and uses dynamic stimulus/OS phases to score
   source, freshness, zoom and observation coverage. Unobservable means
   INCONCLUSIVE, not a guessed PASS.

For automatic focus, assess_auto_live_segments.py scores every contiguous
actual OS foreground period, including laptop interruption. Do not use
delayed PowerShell click-return timestamps to infer Windows focus.
check_live_evidence_mutations.py falsifies live copies without modifying
originals.

## Repeatable commands (on unlocked 4-monitor physical console)

From C:\dev\Vision:

    python -m unittest discover -s lab/pocs/doxa/assessment -p "test_*.py" -q
    python lab/pocs/doxa/assessment/win_observer.py --preflight

Manual complete assessment:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/Test-VisionTriangulatedManualZoomAtomic.ps1

Automatic complete assessment:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File lab/pocs/doxa/assessment/Test-VisionTriangulatedAutoZoomAtomic.ps1

Run serially. They guard against lock, wrong topology and an existing
Vision preview. All output uses distinct run names. They close their
disposable windows and preview and attempt foreground/pointer restoration;
pointer restoration verified, original foreground-window restoration
NOT achieved in accepted runs. Do not assume full UI cleanup passed.

The six scenarios in scenarios/ include unrun deeper cases and should
not be conflated with proven independent four-screen acceptance.

## Limitations / outstanding work

- GDI software-visible capture on a physical console is NOT a physical
  camera measuring photons emitted by the SMI770 Doxa panel. Camera/optical
  calibration and recorder ON/OFF perturbation evaluation still outstanding.
- Word/Excel semantic caret location and viewport follow, real-world
  freeze/recovery, extended mixed-DPI scenarios, and low-vision usability
  with William are not established by this source/zoom assessment.
- The Doxa GDI DISPLAY numbers can change; they are NOT stable connector IDs.
- The user-level VisionBridgeRecoveryUser scheduled task is installed and
  passed live execution. The privileged Windows VisionConsoleRecovery task
  is NOT installed; Windows requires a legitimate one-time elevated
  registration to enable future RDP-to-console recovery without manual tscon.
- Do not overwrite old evidence, reset another developer's files, or claim
  camera-level fidelity from OS/GDI measurements.

