"""
Vision Test Farm Scenario Runner & Evidence Bundle Writer (v0.1)

Executes resolved scenarios inside isolated per-run directories, enforces desktop
locks and timeouts, captures stdout/stderr, backs up and restores settings,
evaluates assertions, and writes standardized evidence bundles.
"""

from __future__ import annotations

import datetime
import json
import os
import shutil
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional

from tf_schema import compute_scenario_hash
from tf_settings import SettingsManager, SettingsState
from tf_concurrency import DesktopConcurrencyGuard, ConcurrencyConflictError
from tf_process import (
    run_process_with_desktop,
    run_process_standard,
    stop_lingering_vision_processes,
    ProcessExecutionResult,
)
from tf_assertions import evaluate_all_assertions, AssertionResult, FAILURE_CLASSES


@dataclass
class ScenarioRunResult:
    scenario_id: str
    resolved_id: str
    scenario_hash: str
    status: str  # "PASS", "FAIL", "SKIP", "BLOCK", "ERROR", "INCOMPLETE"
    duration_sec: float
    exit_code: Optional[int]
    run_dir: Path
    category: str = "general"
    failure_class: Optional[str] = None
    failure_signature: Optional[str] = None
    failure_message: str = ""
    settings_restored_exactly: bool = True
    assertions_passed: int = 0
    assertions_failed: int = 0
    assertions_not_evaluated: int = 0
    summary_path: Optional[Path] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "scenario_id": self.scenario_id,
            "resolved_id": self.resolved_id,
            "scenario_hash": self.scenario_hash,
            "category": self.category,
            "status": self.status,
            "duration_sec": round(self.duration_sec, 3),
            "exit_code": self.exit_code,
            "run_dir": str(self.run_dir),
            "failure_class": self.failure_class,
            "failure_signature": self.failure_signature,
            "failure_message": self.failure_message,
            "settings_restored_exactly": self.settings_restored_exactly,
            "assertions_passed": self.assertions_passed,
            "assertions_failed": self.assertions_failed,
            "assertions_not_evaluated": self.assertions_not_evaluated,
            "summary_path": str(self.summary_path) if self.summary_path else None,
        }


class ScenarioRunner:
    """Manages isolated execution of a scenario and generates its evidence bundle."""

    def __init__(self, repo_root: Path, base_runs_dir: Optional[Path] = None):
        self.repo_root = repo_root
        self.base_runs_dir = base_runs_dir or (repo_root / "lab" / "benchmarks")

    def run_scenario(
        self,
        scenario: Dict[str, Any],
        env: Dict[str, Any],
        preflight_status: str = "RUNNABLE",
        preflight_reasons: Optional[List[str]] = None,
        custom_run_dir: Optional[Path] = None,
    ) -> ScenarioRunResult:
        sid = scenario.get("id", "unknown")
        resolved_id = scenario.get("resolved_id", sid)
        category = scenario.get("category", "benchmarks")
        sc_hash = scenario.get("scenario_hash") or compute_scenario_hash(scenario)

        timestamp_str = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        if custom_run_dir:
            run_dir = custom_run_dir
        else:
            cat_dir = self.base_runs_dir / category / "runs"
            run_dir = cat_dir / f"{timestamp_str}__{resolved_id.replace('@', '__')}"

        run_dir.mkdir(parents=True, exist_ok=True)

        # Write resolved scenario and environment JSON
        with open(run_dir / "scenario.resolved.json", "w", encoding="utf-8") as f:
            json.dump(scenario, f, indent=2)
        with open(run_dir / "environment.json", "w", encoding="utf-8") as f:
            json.dump(env, f, indent=2)

        events_file = run_dir / "events.jsonl"

        def _log_event(event_name: str, **kwargs):
            payload = {"event": event_name, "time": datetime.datetime.now().isoformat(), **kwargs}
            with open(events_file, "a", encoding="utf-8") as ef:
                ef.write(json.dumps(payload) + "\n")

        # Handle Preflight SKIPPED / BLOCKED / INVALID immediately
        if preflight_status == "SKIPPED_CAPABILITY":
            res = ScenarioRunResult(
                scenario_id=sid,
                resolved_id=resolved_id,
                scenario_hash=sc_hash,
                category=category,
                status="SKIP",
                duration_sec=0.0,
                exit_code=None,
                run_dir=run_dir,
                failure_class="ENVIRONMENT_CAPABILITY",
                failure_message="; ".join(preflight_reasons or ["Missing required capability"]),
            )
            self._write_result_files(res, scenario, env, [], None)
            return res

        elif preflight_status == "BLOCKED_INTERVENTION":
            res = ScenarioRunResult(
                scenario_id=sid,
                resolved_id=resolved_id,
                scenario_hash=sc_hash,
                category=category,
                status="BLOCK",
                duration_sec=0.0,
                exit_code=None,
                run_dir=run_dir,
                failure_class="HUMAN_REVIEW_REQUIRED",
                failure_message="; ".join(preflight_reasons or ["Blocked by intervention or elevation"]),
            )
            self._write_result_files(res, scenario, env, [], None)
            return res

        elif preflight_status == "INVALID":
            res = ScenarioRunResult(
                scenario_id=sid,
                resolved_id=resolved_id,
                scenario_hash=sc_hash,
                category=category,
                status="ERROR",
                duration_sec=0.0,
                exit_code=None,
                run_dir=run_dir,
                failure_class="TEST_SPEC_DEFECT",
                failure_message="; ".join(preflight_reasons or ["Scenario failed schema validation"]),
            )
            self._write_result_files(res, scenario, env, [], None)
            return res

        # RUNNABLE scenario execution
        # Write initial INTERRUPTED state to result.json (SWA-12 recovery)
        initial_interrupted = {
            "status": "INTERRUPTED",
            "scenario_id": sid,
            "resolved_id": resolved_id,
            "scenario_hash": sc_hash,
            "created_at": datetime.datetime.now().isoformat(),
        }
        with open(run_dir / "result.json", "w", encoding="utf-8") as rf:
            json.dump(initial_interrupted, rf, indent=2)

        _log_event("run_started", scenario_id=sid, resolved_id=resolved_id)

        flags = scenario.get("flags", {})
        is_interactive = bool(flags.get("interactive_desktop", False))
        timeout_sec = float(scenario.get("timeout_sec", 45.0))
        initial_settings = scenario.get("initial_settings")

        settings_mgr = SettingsManager(run_dir)
        settings_state: Optional[SettingsState] = None

        desktop_guard = DesktopConcurrencyGuard(enabled=is_interactive, timeout_sec=20.0)

        stdout_file = run_dir / "stdout.log"
        stderr_file = run_dir / "stderr.log"

        exec_res: Optional[ProcessExecutionResult] = None
        start_time = time.perf_counter()

        try:
            # 1. Concurrency lock
            desktop_guard.acquire()
            _log_event("desktop_lock_acquired", interactive=is_interactive)

            # 2. Settings backup & initial overrides
            settings_state = settings_mgr.backup(initial_settings)
            _log_event("settings_backed_up", hash_before=settings_state.hash_before)

            # 3. Clean any orphaned vision processes
            stop_lingering_vision_processes()

            # 4. Construct command line
            fixture = scenario.get("fixture", {})
            ftype = fixture.get("type", "process")
            entrypoint = fixture.get("entrypoint", "")
            args = fixture.get("args", [])
            custom_env = fixture.get("env", {})

            # Resolve entrypoint relative to repo if relative
            entry_path = Path(entrypoint)
            if not entry_path.is_absolute():
                entry_path = self.repo_root / entrypoint

            cmd_tokens: List[str] = []
            if ftype == "powershell":
                cmd_tokens = [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(entry_path),
                ] + [str(a) for a in args]
            elif ftype == "ctest":
                ctest_exe = env.get("tooling", {}).get("ctest") or "ctest.exe"
                cmd_tokens = [ctest_exe, "--test-dir", str(self.repo_root / "app" / "build"), "-C", "Release"] + [str(a) for a in args]
            elif ftype in ("python", "synthetic"):
                cmd_tokens = [env.get("tooling", {}).get("python", "python"), str(entry_path)] + [str(a) for a in args]
            else:
                cmd_tokens = [str(entry_path)] + [str(a) for a in args]

            cwd_rel = fixture.get("cwd")
            cwd = (self.repo_root / cwd_rel) if cwd_rel else self.repo_root

            cmd_line = " ".join(f'"{t}"' if " " in str(t) else str(t) for t in cmd_tokens)

            _log_event("process_spawning", command=cmd_line)

            # 5. Launch process
            # If interactive_desktop, route to WinSta0\Default
            if is_interactive and os.name == "nt":
                exec_res = run_process_with_desktop(
                    cmd=cmd_line,
                    cwd=cwd,
                    stdout_file=stdout_file,
                    stderr_file=stderr_file,
                    timeout_sec=timeout_sec,
                    desktop="WinSta0\\Default",
                    env=custom_env,
                )
            else:
                exec_res = run_process_standard(
                    cmd=cmd_tokens,
                    cwd=cwd,
                    stdout_file=stdout_file,
                    stderr_file=stderr_file,
                    timeout_sec=timeout_sec,
                    env=custom_env,
                )

            _log_event("process_finished", exit_code=exec_res.exit_code, timed_out=exec_res.timed_out, duration=exec_res.duration_sec)

        except ConcurrencyConflictError as cce:
            duration = time.perf_counter() - start_time
            res = ScenarioRunResult(
                scenario_id=sid,
                resolved_id=resolved_id,
                scenario_hash=sc_hash,
                category=category,
                status="BLOCK",
                duration_sec=duration,
                exit_code=None,
                run_dir=run_dir,
                failure_class="FLAKY_OR_NONDETERMINISTIC",
                failure_message=str(cce),
            )
            self._write_result_files(res, scenario, env, [], settings_state)
            return res

        except Exception as e:
            duration = time.perf_counter() - start_time
            res = ScenarioRunResult(
                scenario_id=sid,
                resolved_id=resolved_id,
                scenario_hash=sc_hash,
                category=category,
                status="ERROR",
                duration_sec=duration,
                exit_code=1,
                run_dir=run_dir,
                failure_class="HARNESS_DEFECT",
                failure_message=f"Harness exception: {e}",
            )
            self._write_result_files(res, scenario, env, [], settings_state)
            return res

        finally:
            stop_lingering_vision_processes()
            # 6. Restore settings
            if settings_state is not None:
                try:
                    settings_mgr.restore()
                    _log_event("settings_restored", restored_exactly=settings_state.restored_exactly)
                except Exception as se:
                    _log_event("settings_restore_error", error=str(se))
            # 7. Release lock
            desktop_guard.release()
            _log_event("desktop_lock_released")

        duration = time.perf_counter() - start_time

        # Check if telemetry CSV was generated inside run_dir or in integrated_app runs
        telemetry_file = run_dir / "visual_app_telemetry.csv"
        if not telemetry_file.is_file():
            # Check if fixture created it in integrated_app/runs
            integ_runs = self.repo_root / "lab" / "benchmarks" / "integrated_app" / "runs"
            if integ_runs.is_dir():
                subdirs = sorted(integ_runs.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)
                for sd in subdirs[:3]:
                    cand = sd / "visual_app_telemetry.csv"
                    if cand.is_file() and cand.stat().st_mtime >= (start_time - 5.0):
                        try:
                            shutil.copy2(cand, telemetry_file)
                            # Also copy analysis.json if present
                            cand_analysis = sd / "analysis.json"
                            if cand_analysis.is_file():
                                shutil.copy2(cand_analysis, run_dir / "analysis.json")
                            break
                        except Exception:
                            pass

        # 8. Evaluate Assertions
        assertion_specs = scenario.get("assertions", [])
        assertion_results = evaluate_all_assertions(
            specs=assertion_specs,
            run_dir=run_dir,
            exit_code=exec_res.exit_code,
            stdout_text=exec_res.stdout_preview,
            stderr_text=exec_res.stderr_preview,
            telemetry_file=telemetry_file if telemetry_file.is_file() else None,
        )

        with open(run_dir / "assertions.json", "w", encoding="utf-8") as af:
            json.dump([a.to_dict() for a in assertion_results], af, indent=2)

        pass_count = sum(1 for a in assertion_results if a.status == "PASS")
        fail_count = sum(1 for a in assertion_results if a.status == "FAIL")
        not_eval_count = sum(1 for a in assertion_results if a.status == "NOT_EVALUATED")

        # Determine overall outcome and failure taxonomy
        overall_status = "PASS"
        fail_class: Optional[str] = None
        fail_sig: Optional[str] = None
        fail_msg = ""

        if exec_res.timed_out:
            overall_status = "FAIL"
            fail_class = "VISION_REGRESSION"
            fail_sig = f"{resolved_id}::TIMEOUT::VISION_REGRESSION"
            fail_msg = f"Execution timed out after {timeout_sec}s"
        elif fail_count > 0 or not_eval_count > 0:
            overall_status = "FAIL"
            # Locate first critical failure
            first_fail = next((a for a in assertion_results if a.status in ("FAIL", "NOT_EVALUATED") and a.critical), None)
            if first_fail is None:
                first_fail = next((a for a in assertion_results if a.status in ("FAIL", "NOT_EVALUATED")), assertion_results[0])

            # Classify failure
            if first_fail.id == "exit_code":
                fail_class = "VISION_REGRESSION" if exec_res.exit_code != 0 else "HARNESS_DEFECT"
            elif "present_failures" in first_fail.id:
                fail_class = "VISION_REGRESSION"
            elif "return_delta" in first_fail.id:
                fail_class = "VISION_REGRESSION"
            elif first_fail.status == "NOT_EVALUATED":
                fail_class = "HARNESS_DEFECT"
            else:
                fail_class = "VISION_REGRESSION"

            fail_sig = f"{resolved_id}::{first_fail.id}::{fail_class}"
            fail_msg = first_fail.message or f"Assertion {first_fail.id} was {first_fail.status}"

        # If visual_review requested
        if flags.get("visual_review", False) and overall_status == "PASS":
            fail_class = "HUMAN_REVIEW_REQUIRED"

        restored_exactly = settings_state.restored_exactly if settings_state else True

        result = ScenarioRunResult(
            scenario_id=sid,
            resolved_id=resolved_id,
            scenario_hash=sc_hash,
            category=category,
            status=overall_status,
            duration_sec=duration,
            exit_code=exec_res.exit_code,
            run_dir=run_dir,
            failure_class=fail_class,
            failure_signature=fail_sig,
            failure_message=fail_msg,
            settings_restored_exactly=restored_exactly,
            assertions_passed=pass_count,
            assertions_failed=fail_count,
            assertions_not_evaluated=not_eval_count,
        )

        self._write_result_files(result, scenario, env, assertion_results, settings_state)
        return result

    def _write_result_files(
        self,
        res: ScenarioRunResult,
        scenario: Dict[str, Any],
        env: Dict[str, Any],
        assertions: List[AssertionResult],
        settings_state: Optional[SettingsState],
    ) -> None:
        run_dir = res.run_dir

        # Write result.json
        result_dict = res.to_dict()
        result_dict["scenario_title"] = scenario.get("title")
        result_dict["category"] = scenario.get("category")
        result_dict["settings"] = settings_state.to_dict() if settings_state else None
        result_dict["git_provenance"] = env.get("git")

        with open(run_dir / "result.json", "w", encoding="utf-8") as rf:
            json.dump(result_dict, rf, indent=2)

        # Write SUMMARY.md
        summary_lines = [
            f"# Test Farm Run Summary: {res.resolved_id}",
            "",
            f"- **Scenario:** {scenario.get('title')} (`{res.resolved_id}`)",
            f"- **Category:** {scenario.get('category')}",
            f"- **Status:** **{res.status}**",
            f"- **Duration:** {round(res.duration_sec, 2)}s",
            f"- **Exit Code:** {res.exit_code}",
            f"- **Settings Restored Exactly:** {res.settings_restored_exactly}",
            f"- **Git HEAD:** {env.get('git', {}).get('head')} (is_dirty: {env.get('git', {}).get('is_dirty')})",
            "",
        ]

        if res.failure_class:
            summary_lines.extend([
                f"- **Failure Class:** `{res.failure_class}`",
                f"- **Failure Signature:** `{res.failure_signature}`",
                f"- **Failure Message:** {res.failure_message}",
                "",
            ])

        summary_lines.extend([
            "## Assertions",
            "",
            "| ID | Name | Status | Expected | Actual | Message |",
            "|---|---|---:|---|---|---|",
        ])
        for a in assertions:
            summary_lines.append(f"| {a.id} | {a.name} | {a.status} | {a.op} {a.expected} | {a.actual} | {a.message} |")

        summary_lines.append("")
        summary_path = run_dir / "SUMMARY.md"
        with open(summary_path, "w", encoding="utf-8") as sf:
            sf.write("\n".join(summary_lines) + "\n")

        res.summary_path = summary_path
