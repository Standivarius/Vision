# Vision Automation Test Farm (v0.1)

**Canonical workspace:** `C:\dev\Vision`
**Host machine:** `MARIUS-DELL`
**Harness version:** `0.1.0`
**Target platform:** Windows 11 (Win32, C++20, C++/WinRT, D3D11, WGC)

---

## 1. Overview and Architecture

The Vision Test Farm is an automated, non-elevated, deterministic test execution and evidence collection framework designed for multi-monitor Windows low-vision magnification software. It enforces strict separation between intent/tracking and graphics pipelines, models displays as arbitrary $1 \to N$ destinations, and produces structured, reproducible run bundles.

```
+-------------------------------------------------------------------------------+
|                             Scenario Catalogue                                 |
|         (Versioned JSON definitions with capabilities, flags, assertions)      |
+---------------------------------------+---------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                       Planner & Capability Resolver                           |
|       (Probes host displays, session, binaries; preflights RUN/SKIP/BLOCK)     |
+---------------------------------------+---------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                        Isolated Execution Runner                              |
|   (Interactive desktop lock, settings backup/restore, WinSta0\Default routing, |
|              timeout enforcement, process-tree orphan elimination)            |
+---------------------------------------+---------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                        Deterministic Evidence Bundle                          |
|    (scenario.resolved.json, environment.json, events.jsonl, assertions.json,  |
|             telemetry CSV, logs, result.json, SUMMARY.md)                     |
+---------------------------------------+---------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                     Aggregator & Signature Clustering                         |
|     (Exact counts, deterministic failure clustering, human-review queue,      |
|                        aggregate.json, AGGREGATE.md)                          |
+-------------------------------------------------------------------------------+
```

---

## 2. Core Architecture Components

| Module | Source File | Responsibilities |
|---|---|---|
| **Schema & Validation** | `tf_schema.py` | Schema v0.1 definitions, required field validation, operator types, canonical JSON SHA256 scenario hashing, and stable variant expansion (`<base_id>@<variant>`). |
| **Capability Probe** | `tf_environment.py` | Probes Windows build, session (Console vs RDP), Desktop/WindowStation, display topology, non-elevation (`IsUserAnAdmin`), git HEAD + bounded change provenance, and Vision binaries. |
| **Planner & Resolver** | `tf_resolver.py` | Discovers catalogue scenarios, filters by pack/tags/category, and preflights each into `RUNNABLE`, `SKIPPED_CAPABILITY`, `BLOCKED_INTERVENTION`, or `INVALID`. Unavailable capabilities never fail Vision. |
| **Settings Manager** | `tf_settings.py` | Backs up `%LOCALAPPDATA%\Standivarius\Visual\settings.ini`, computes SHA256 before the test, restores in `finally` (even on exceptions), and proves byte-for-byte identity. Never touches machine-wide settings. |
| **Concurrency Guard** | `tf_concurrency.py` | Serializes interactive desktop scenarios via named mutex `Local\Vision_TestFarm_Interactive_Desktop_Lock` and process guards. Non-interactive tests bypass lock safely. |
| **Process Runner** | `tf_process.py` | Subprocess execution with strict timeouts, standard handle logging, process tree killing (`taskkill /PID /T /F`), and Windows `WinSta0\Default` desktop routing to prevent `DXGI_STATUS_OCCLUDED`. |
| **Assertion Oracle** | `tf_assertions.py` | Evaluates assertions (`exit_code`, `telemetry_metric`, `file_exists`, `regex_match`). Emits `PASS`, `FAIL`, or `NOT_EVALUATED` (when metrics/columns are missing). |
| **Aggregator** | `tf_aggregator.py` | Clusters failures by deterministic signature (`<id>::<assertion>::<class>`), builds human-review queue, handles interrupted runs (`INCOMPLETE`), and emits `aggregate.json` and `AGGREGATE.md`. |
| **CLI & PowerShell** | `tf_cli.py`, `run-farm.ps1` | Unified operator commands: `list`, `dry-run`, `run`, `safe-smoke`, `aggregate`, and `swa-suite`. |

---

## 3. Desktop Routing & Occlusion Avoidance

When automation tools run in isolated worker sessions (e.g. `exebox-...`), child processes inherit an invisible desktop where Windows DWM marks DXGI swapchains as occluded (`DXGI_STATUS_OCCLUDED` = `0x087A0001` = `142213121`).

`tf_process.py` solves this deterministically for interactive scenarios by invoking Win32 `CreateProcessW` with `STARTUPINFOW.lpDesktop = L"WinSta0\\Default"`. This ensures the application attaches directly to the active user console desktop where physical displays are mapped, rendering frames at full rate without occlusion.

---

## 4. Operator Commands

### Python CLI
```powershell
# 1. View catalogue scenarios
python lab/automation-harness/tf_cli.py list

# 2. Dry-run preflight against current environment
python lab/automation-harness/tf_cli.py dry-run

# 3. Execute the mandatory Software Acceptance test suite (SWA-01..13)
python lab/automation-harness/tf_cli.py swa-suite

# 4. Execute a specific scenario
python lab/automation-harness/tf_cli.py run --scenario unit_ctest
python lab/automation-harness/tf_cli.py run --scenario lifecycle_smoke
python lab/automation-harness/tf_cli.py run --scenario exact_return

# 5. Execute the canonical safe smoke pack
python lab/automation-harness/tf_cli.py safe-smoke

# 6. Aggregate existing run directories
python lab/automation-harness/tf_cli.py aggregate --runs-dir lab/benchmarks/integrated_app/runs
```

### PowerShell Wrapper
```powershell
.\lab\automation-harness\run-farm.ps1 -List
.\lab\automation-harness\run-farm.ps1 -DryRun
.\lab\automation-harness\run-farm.ps1 -SwaSuite
.\lab\automation-harness\run-farm.ps1 -SafeSmoke
.\lab\automation-harness\run-farm.ps1 -Scenario exact_return
```

---

## 5. Mandatory Software Acceptance Verification (SWA-01..13)

The harness includes a self-test suite validating all thirteen mandatory acceptance criteria:

| Test ID | Title | Verification Result | Evidence Description |
|---|---|:---:|---|
| **SWA-01** | Schema & Variants | **PASS** | Valid schema accepted; missing required fields, wrong versions, and invalid ops rejected usefully; variant compound IDs stable (`<id>@<var>`). |
| **SWA-02** | Dry-Run & Capabilities | **PASS** | Preflight decisions `RUNNABLE`, `SKIPPED_CAPABILITY`, and `BLOCKED_INTERVENTION` resolved correctly without launching Vision or altering state. |
| **SWA-03** | Runner Success | **PASS** | Deterministic fixture executed; stdout/stderr captured; `PASS` status recorded; complete bundle generated with all required JSON and logs. |
| **SWA-04** | Runner Failure | **PASS** | Controlled non-zero exit code (42) classified accurately; aggregator ingested failing bundle without error; harness survived. |
| **SWA-05** | Timeout & Tree Termination | **PASS** | Long-running sleeping process terminated within deadline; classified as `TIMEOUT`; process tree killed with zero orphaned processes. |
| **SWA-06** | Assertion Evaluation | **PASS** | Passing, failing, and missing metric assertions classified as `PASS`, `FAIL`, and `NOT_EVALUATED` with stable IDs. |
| **SWA-07** | Settings Restoration | **PASS** | `settings.ini` copied and hashed before run; restored in `finally` block even under injected exceptions; proven byte-identical (`after_hash == before_hash`). |
| **SWA-08** | Fan-In & Signature Clustering | **PASS** | Exact counts computed across 7 diverse runs; identical signatures clustered; distinct failures kept separate; review queue populated. |
| **SWA-09** | Deterministic Rerun | **PASS** | Stable scenario hashes and resolved identities reproduced identically across repeated evaluations. |
| **SWA-10** | Dirty-Tree Provenance | **PASS** | Recorded git HEAD, dirty status (`is_dirty: true`), and bounded change summary without dumping massive file contents. |
| **SWA-11** | Concurrency Guard | **PASS** | Simultaneous interactive desktop acquisition raised `ConcurrencyConflictError`; non-interactive scenarios bypassed lock safely. |
| **SWA-12** | Interrupted Recovery | **PASS** | Incomplete and aborted runs flagged as `INCOMPLETE` / `INTERRUPTED`, never marked `PASS`. |
| **SWA-13** | Non-Elevated Execution | **PASS** | Full self-test suite and runner verified operating strictly within standard non-elevated user token (`is_admin: false`). |

**Summary: 13 PASSED, 0 FAILED out of 13.**

---

## 6. Future Visual-Evaluator Seam (Design Only)

Per assignment requirements, this section designs the visual-evaluation pipeline interface for future automated visual defect triage without invoking model SDKs or services in v0.1.

### Four-Layer Visual Evaluation Pipeline

```
+-------------------------------------------------------------------------------+
| Layer 1: Deterministic Oracle                                                  |
| - Process exit code, telemetry row count, present_hr != 0                     |
| - Return coordinate delta (delta == 0 px)                                      |
| - Viewport hold/pan/jump validity, locator visibility                         |
+---------------------------------------+---------------------------------------+
                                        |
                   Anomaly detected or Visual Review Flag
                                        |
                                        v
+-------------------------------------------------------------------------------+
| Layer 2: Visual Evidence Emitter                                              |
| - Keyframe snapshot captures (target viewport, context indicator, locator)    |
| - Video contact sheets with timestamp overlays                                |
| - Pixel delta bounding boxes                                                  |
+---------------------------------------+---------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
| Layer 3: Cheap Local Evaluator (Fast Heuristic / Lightweight CV)              |
| - Blank / black / uniform frame detector (color variance check)               |
| - High-contrast locator template matching (crosshair present / misplaced)     |
| - Viewport jitter detector (frame-to-frame optical flow acceleration threshold)|
+---------------------------------------+---------------------------------------+
                                        |
                     Suspicious / Inconclusive Evidence
                                        |
                                        v
+-------------------------------------------------------------------------------+
| Layer 4: Human Review Queue & Stronger Model Inspection                       |
| - Manifest entry in review_queue with structured visual evidence paths        |
| - Questions answered: Viewport jump? Duplicate caret? Text tear?             |
+-------------------------------------------------------------------------------+
```

### Visual Review Manifest Schema (`visual_manifest.json`)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "run_id": "2026-09-30_18-32-02__mouse_viewport_smoke__zoom2",
  "scenario_id": "mouse_viewport_smoke@zoom2",
  "visual_artifacts": {
    "contact_sheet": "evidence/contact_sheet.png",
    "video_recording": "evidence/run_recording.mp4",
    "anomaly_frames": [
      {
        "frame_number": 42,
        "qpc_timestamp": 169621415976,
        "image_path": "evidence/frame_0042.png",
        "suspicion_reason": "locator_missing_while_source_active",
        "heuristic_score": 0.82
      }
    ]
  },
  "triage_questions": [
    "Is the Detail viewport rendering black or blank output?",
    "Is the View Locator overlay rendered over the correct context monitor area?",
    "Does the viewport jump abruptly without corresponding POI motion?"
  ]
}
```

---

## 7. Safety Invariants Maintained

- **Production code untouched:** Zero modifications to `app/src/**`, `app/tests/**`, `app/CMakeLists.txt`, or production settings.
- **Dirty workspace preserved:** Unrelated dirty files and untracked artifacts remain completely intact.
- **Non-elevated operation:** Runs purely under normal user session; capability-gates any tests requiring elevation or hardware disconnects.
- **Settings restored:** Backs up and byte-verifies `%LOCALAPPDATA%\Standivarius\Visual\settings.ini`.
- **Deterministic acceptance:** Canonical `run-two-screen-acceptance.ps1` runs clean (8/8 steps passing, 0 Present failures, 0 px return delta, 17/17 CTests).
