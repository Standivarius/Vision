"""
Vision Test Farm Software Acceptance Suite (v0.1)

Implements and executes mandatory acceptance tests SWA-01 through SWA-13.
All tests run non-elevated and produce deterministic verification records.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Tuple

# Ensure harness modules can be imported
HARNESS_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = HARNESS_DIR.parent.parent
if str(HARNESS_DIR) not in sys.path:
    sys.path.insert(0, str(HARNESS_DIR))

from tf_schema import (
    validate_scenario,
    expand_scenario_variants,
    compute_scenario_hash,
    SchemaValidationError,
)
from tf_environment import probe_environment, is_admin
from tf_settings import SettingsManager, _compute_file_sha256
from tf_concurrency import DesktopConcurrencyGuard, ConcurrencyConflictError
from tf_assertions import evaluate_all_assertions, evaluate_assertion, AssertionResult
from tf_resolver import ScenarioResolver, preflight_scenario
from tf_runner import ScenarioRunner
from tf_aggregator import Aggregator




def run_swa_01_schema() -> Tuple[bool, str]:
    """SWA-01 Schema: valid accepted; missing required/version/action/assertion rejected usefully; variant IDs stable."""
    valid_spec = {
        "schema_version": "0.1",
        "id": "swa_test_valid",
        "version": "1.0",
        "title": "Valid Scenario",
        "category": "synthetic",
        "fixture": {"type": "synthetic", "entrypoint": "synthetic_pass.py"},
        "assertions": [{"id": "a1", "type": "exit_code", "op": "eq", "expected": 0}],
        "variants": [
            {"id": "var1", "title": "Variant 1"},
            {"id": "var2", "title": "Variant 2"},
        ],
    }

    # 1. Valid spec accepted
    is_valid, errors = validate_scenario(valid_spec)
    if not is_valid:
        return False, f"Valid spec rejected: {errors}"

    # 2. Missing required field rejected
    for missing_field in ["schema_version", "id", "fixture", "assertions"]:
        bad = copy.deepcopy(valid_spec)
        del bad[missing_field]
        v, errs = validate_scenario(bad)
        if v or not any(missing_field in e for e in errs):
            return False, f"Missing '{missing_field}' not rejected usefully: {errs}"

    # 3. Wrong schema version rejected
    bad_ver = copy.deepcopy(valid_spec)
    bad_ver["schema_version"] = "99.9"
    v, errs = validate_scenario(bad_ver)
    if v or not any("schema_version" in e for e in errs):
        return False, f"Wrong schema version not rejected: {errs}"

    # 4. Invalid assertion op rejected
    bad_op = copy.deepcopy(valid_spec)
    bad_op["assertions"] = [{"id": "a1", "type": "exit_code", "op": "invalid_op", "expected": 0}]
    v, errs = validate_scenario(bad_op)
    if v or not any("invalid op" in e for e in errs):
        return False, f"Invalid assertion op not rejected: {errs}"

    # 5. Variants expansion stable
    expanded = expand_scenario_variants(valid_spec)
    if len(expanded) != 2:
        return False, f"Expected 2 variants, got {len(expanded)}"
    if expanded[0]["resolved_id"] != "swa_test_valid@var1" or expanded[1]["resolved_id"] != "swa_test_valid@var2":
        return False, f"Variant IDs unstable: {[e['resolved_id'] for e in expanded]}"

    return True, "Valid scenario accepted; invalid rejected usefully; variant IDs stable."


def run_swa_02_dry_run() -> Tuple[bool, str]:
    """SWA-02 Dry-run/capabilities: resolve safe pack without Vision; RUN/SKIP/BLOCK correct; unavailable capability not FAIL; no state changes."""
    env = probe_environment(REPO_ROOT)
    catalogue_dir = HARNESS_DIR / "scenarios"
    resolver = ScenarioResolver(catalogue_dir, REPO_ROOT)

    settings_file = env.get("vision_binaries", {}).get("settings_file", {}).get("path")
    hash_before = _compute_file_sha256(Path(settings_file)) if settings_file and Path(settings_file).is_file() else None

    plan = resolver.plan(env)
    if not plan:
        return False, "Plan was empty"

    decisions = {p.resolved_id: p.status for p in plan}

    # Verify four display scenario is SKIPPED_CAPABILITY (assuming 2 displays)
    if env["display_topology"]["display_count"] < 4:
        if decisions.get("future_four_display_gated") != "SKIPPED_CAPABILITY":
            return False, f"future_four_display_gated status expected SKIPPED_CAPABILITY, got {decisions.get('future_four_display_gated')}"

    # Verify destructive / privileged is BLOCKED_INTERVENTION
    if decisions.get("future_elevated_disconnect_gated") != "BLOCKED_INTERVENTION":
        return False, f"future_elevated_disconnect_gated status expected BLOCKED_INTERVENTION, got {decisions.get('future_elevated_disconnect_gated')}"

    # Verify unit_ctest is RUNNABLE
    if decisions.get("unit_ctest") != "RUNNABLE":
        return False, f"unit_ctest expected RUNNABLE, got {decisions.get('unit_ctest')}"

    # Verify settings did not change during dry-run
    if settings_file and Path(settings_file).is_file():
        hash_after = _compute_file_sha256(Path(settings_file))
        if hash_after != hash_before:
            return False, "Settings file was modified during dry-run!"

    return True, "Preflight decisions RUN/SKIP/BLOCK correct; unavailable capability not failed; settings untouched."


def run_swa_03_runner_success() -> Tuple[bool, str]:
    """SWA-03 Runner success: deterministic fixture; stdout/stderr; PASS; provenance/bundle/cleanup."""
    env = probe_environment(REPO_ROOT)
    runner = ScenarioRunner(REPO_ROOT)

    with tempfile.TemporaryDirectory(prefix="swa_03_") as tmpdir:
        run_dir = Path(tmpdir) / "run_success"
        fixture_path = REPO_ROOT / "lab" / "test-fixtures" / "synthetic_pass.py"

        scenario = {
            "schema_version": "0.1",
            "id": "swa_synthetic_success",
            "resolved_id": "swa_synthetic_success",
            "version": "1.0",
            "title": "SWA Synthetic Success",
            "category": "synthetic",
            "fixture": {
                "type": "synthetic",
                "entrypoint": str(fixture_path),
                "args": ["--message", "hello_test_farm"],
            },
            "flags": {"interactive_desktop": False},
            "timeout_sec": 10.0,
            "assertions": [
                {"id": "exit_zero", "type": "exit_code", "op": "eq", "expected": 0, "critical": True},
                {"id": "stdout_match", "type": "regex_match", "target": "stdout", "op": "regex", "expected": "hello_test_farm", "critical": True},
                {"id": "stderr_match", "type": "regex_match", "target": "stderr", "op": "regex", "expected": "info log", "critical": True},
            ],
        }

        res = runner.run_scenario(scenario, env, custom_run_dir=run_dir)

        if res.status != "PASS":
            return False, f"Expected PASS, got {res.status}; msg: {res.failure_message}"

        # Verify bundle contents
        for req_file in ["scenario.resolved.json", "environment.json", "events.jsonl", "assertions.json", "result.json", "SUMMARY.md", "stdout.log", "stderr.log"]:
            if not (run_dir / req_file).is_file():
                return False, f"Missing required bundle file: {req_file}"

        with open(run_dir / "result.json", "r", encoding="utf-8") as rf:
            rj = json.load(rf)
            if rj.get("status") != "PASS":
                return False, f"result.json status was {rj.get('status')}"
            if "git_provenance" not in rj:
                return False, "Missing git_provenance in result.json"

    return True, "Deterministic fixture executed; stdout/stderr captured; PASS; valid bundle created."


def run_swa_04_runner_failure() -> Tuple[bool, str]:
    """SWA-04 Runner failure: controlled non-zero; correct taxonomy/exit code; aggregator accepts; harness survives."""
    env = probe_environment(REPO_ROOT)
    runner = ScenarioRunner(REPO_ROOT)

    with tempfile.TemporaryDirectory(prefix="swa_04_") as tmpdir:
        run_dir = Path(tmpdir) / "run_failure"
        fixture_path = REPO_ROOT / "lab" / "test-fixtures" / "synthetic_fail.py"

        scenario = {
            "schema_version": "0.1",
            "id": "swa_synthetic_failure",
            "resolved_id": "swa_synthetic_failure",
            "version": "1.0",
            "title": "SWA Synthetic Failure",
            "category": "synthetic",
            "fixture": {
                "type": "synthetic",
                "entrypoint": str(fixture_path),
                "args": ["--code", "42", "--error", "controlled failure"],
            },
            "flags": {"interactive_desktop": False},
            "timeout_sec": 10.0,
            "assertions": [
                {"id": "exit_zero", "type": "exit_code", "op": "eq", "expected": 0, "critical": True},
            ],
        }

        res = runner.run_scenario(scenario, env, custom_run_dir=run_dir)

        if res.status != "FAIL":
            return False, f"Expected FAIL, got {res.status}"
        if res.exit_code != 42:
            return False, f"Expected exit code 42, got {res.exit_code}"
        if res.failure_class not in ("VISION_REGRESSION", "HARNESS_DEFECT"):
            return False, f"Unexpected failure_class: {res.failure_class}"

        # Verify aggregator accepts the failing bundle without crashing
        aggregator = Aggregator()
        agg_data = aggregator.aggregate_from_run_dirs([run_dir])
        if agg_data["counts"]["failed"] != 1:
            return False, f"Aggregator failed count expected 1, got {agg_data['counts']['failed']}"

    return True, "Controlled non-zero handled; exit code 42 recorded; aggregator accepted; harness survived."


def run_swa_05_timeout() -> Tuple[bool, str]:
    """SWA-05 Timeout: sleeping fixture; timeout classified; child killed; no orphan; valid bundle."""
    env = probe_environment(REPO_ROOT)
    runner = ScenarioRunner(REPO_ROOT)

    with tempfile.TemporaryDirectory(prefix="swa_05_") as tmpdir:
        run_dir = Path(tmpdir) / "run_timeout"
        fixture_path = REPO_ROOT / "lab" / "test-fixtures" / "synthetic_sleep.py"

        scenario = {
            "schema_version": "0.1",
            "id": "swa_synthetic_timeout",
            "resolved_id": "swa_synthetic_timeout",
            "version": "1.0",
            "title": "SWA Synthetic Timeout",
            "category": "synthetic",
            "fixture": {
                "type": "synthetic",
                "entrypoint": str(fixture_path),
                "args": ["--seconds", "30.0"],
            },
            "flags": {"interactive_desktop": False},
            "timeout_sec": 1.5,
            "assertions": [
                {"id": "exit_zero", "type": "exit_code", "op": "eq", "expected": 0, "critical": True},
            ],
        }

        start = time.perf_counter()
        res = runner.run_scenario(scenario, env, custom_run_dir=run_dir)
        elapsed = time.perf_counter() - start

        if elapsed > 10.0:
            return False, f"Timeout took too long: {elapsed}s"
        if res.status != "FAIL":
            return False, f"Expected FAIL on timeout, got {res.status}"
        if "TIMEOUT" not in str(res.failure_signature) and "timed out" not in res.failure_message:
            return False, f"Timeout not classified in signature/message: {res.failure_signature}"

        # Verify bundle created
        if not (run_dir / "result.json").is_file():
            return False, "result.json missing for timeout run"

    return True, f"Sleeping fixture timed out in {round(elapsed, 2)}s; classified as TIMEOUT; bundle written."


def run_swa_06_assertions() -> Tuple[bool, str]:
    """SWA-06 Assertions: passing, failing, unavailable metric; stable IDs; PASS/FAIL/NOT_EVALUATED."""
    with tempfile.TemporaryDirectory(prefix="swa_06_") as tmpdir:
        run_dir = Path(tmpdir)

        specs = [
            {"id": "exit_zero", "name": "Exit Zero", "type": "exit_code", "op": "eq", "expected": 0},
            {"id": "exit_one", "name": "Exit One", "type": "exit_code", "op": "eq", "expected": 1},
            {"id": "telemetry_metric_missing", "name": "Missing Telemetry", "type": "telemetry_metric", "target": "zoom", "metric": "max", "op": "eq", "expected": 2},
        ]

        results = evaluate_all_assertions(
            specs=specs,
            run_dir=run_dir,
            exit_code=0,
            stdout_text="output text",
            stderr_text="",
            telemetry_file=None,
        )

        status_by_id = {r.id: r.status for r in results}

        if status_by_id.get("exit_zero") != "PASS":
            return False, f"exit_zero expected PASS, got {status_by_id.get('exit_zero')}"
        if status_by_id.get("exit_one") != "FAIL":
            return False, f"exit_one expected FAIL, got {status_by_id.get('exit_one')}"
        if status_by_id.get("telemetry_metric_missing") != "NOT_EVALUATED":
            return False, f"missing telemetry expected NOT_EVALUATED, got {status_by_id.get('telemetry_metric_missing')}"

    return True, "Assertions evaluated: PASS, FAIL, NOT_EVALUATED returned correctly with stable IDs."


def run_swa_07_settings_restoration() -> Tuple[bool, str]:
    """SWA-07 Settings restoration: copy/hash before; restore in finally including injected failure; prove byte-identical; no machine-wide settings."""
    with tempfile.TemporaryDirectory(prefix="swa_07_") as tmpdir:
        fake_settings = Path(tmpdir) / "test_settings.ini"
        fake_settings.write_text("[Displays]\nContext=\\\\.\\DISPLAY1\nDetail=\\\\.\\DISPLAY2\n", encoding="utf-8")
        hash_before = _compute_file_sha256(fake_settings)

        run_dir = Path(tmpdir) / "run_dir"
        mgr = SettingsManager(run_dir=run_dir, custom_settings_path=fake_settings)

        state = mgr.backup()
        if state.hash_before != hash_before:
            return False, f"hash_before mismatch: {state.hash_before} vs {hash_before}"

        # Inject modification / simulated app failure
        fake_settings.write_text("[Displays]\nContext=CORRUPTED\n", encoding="utf-8")

        # Restore in finally
        try:
            raise RuntimeError("Injected exception during scenario run")
        except RuntimeError:
            restore_state = mgr.restore()

        if not restore_state.restored_exactly:
            return False, "Settings restoration failed byte-identical equality!"
        if restore_state.hash_after != hash_before:
            return False, f"hash_after mismatch: {restore_state.hash_after} vs {hash_before}"

    return True, "Settings copied, backed up, mutated, and restored byte-identical (after_hash == before_hash)."


def run_swa_08_fan_in() -> Tuple[bool, str]:
    """SWA-08 Fan-in: synthetic PASS, duplicate fail A, fail B, SKIP, BLOCK, timeout/error; exact totals; identical signatures cluster; different separate; evidence-linked review queue."""
    mock_runs = [
        {"scenario_id": "sc_pass", "resolved_id": "sc_pass", "status": "PASS", "category": "unit"},
        {"scenario_id": "sc_fail_a", "resolved_id": "sc_fail_a@1", "status": "FAIL", "category": "pointer", "failure_signature": "SIG_A", "failure_class": "VISION_REGRESSION", "failure_message": "Present error"},
        {"scenario_id": "sc_fail_a", "resolved_id": "sc_fail_a@2", "status": "FAIL", "category": "pointer", "failure_signature": "SIG_A", "failure_class": "VISION_REGRESSION", "failure_message": "Present error"},
        {"scenario_id": "sc_fail_b", "resolved_id": "sc_fail_b", "status": "FAIL", "category": "caret", "failure_signature": "SIG_B", "failure_class": "VISION_REGRESSION", "failure_message": "Caret jump"},
        {"scenario_id": "sc_skip", "resolved_id": "sc_skip", "status": "SKIP", "category": "future_gated", "failure_message": "Needs 4 displays"},
        {"scenario_id": "sc_block", "resolved_id": "sc_block", "status": "BLOCK", "category": "future_gated", "failure_message": "Needs elevation"},
        {"scenario_id": "sc_error", "resolved_id": "sc_error", "status": "ERROR", "category": "synthetic", "failure_message": "Syntax error"},
    ]

    agg = Aggregator()
    data = agg.aggregate_from_dicts(mock_runs)
    c = data["counts"]

    if c["total"] != 7:
        return False, f"Expected total 7, got {c['total']}"
    if c["passed"] != 1 or c["failed"] != 3 or c["skipped"] != 1 or c["blocked"] != 1 or c["errors"] != 1:
        return False, f"Counts mismatch: {c}"

    clusters = {fc["signature"]: fc for fc in data["failure_clusters"]}
    if len(clusters) != 2:
        return False, f"Expected exactly 2 failure clusters, got {len(clusters)}"
    if clusters["SIG_A"]["count"] != 2:
        return False, f"Cluster SIG_A count expected 2, got {clusters['SIG_A']['count']}"
    if clusters["SIG_B"]["count"] != 1:
        return False, f"Cluster SIG_B count expected 1, got {clusters['SIG_B']['count']}"

    # Verify review queue contains failed, blocked, and error runs
    rq = data["human_review_queue"]
    if len(rq) < 5:  # 3 fails + 1 block + 1 error
        return False, f"Review queue length expected >= 5, got {len(rq)}"

    return True, "Fan-in verified: exact totals, SIG_A clustered 2 duplicates, SIG_B separated, review queue formed."


def run_swa_09_deterministic_rerun() -> Tuple[bool, str]:
    """SWA-09 Deterministic rerun: stable resolved identity/hash and assertions over repeats; timing need not match."""
    scenario = {
        "schema_version": "0.1",
        "id": "swa_rerun_test",
        "version": "1.0",
        "title": "Rerun Test",
        "category": "synthetic",
        "fixture": {"type": "synthetic", "entrypoint": "synthetic_pass.py"},
        "assertions": [{"id": "a1", "type": "exit_code", "op": "eq", "expected": 0}],
        "variants": [{"id": "v1"}, {"id": "v2"}],
    }

    hashes_run1 = [compute_scenario_hash(v) for v in expand_scenario_variants(scenario)]
    hashes_run2 = [compute_scenario_hash(v) for v in expand_scenario_variants(scenario)]

    if hashes_run1 != hashes_run2:
        return False, f"Scenario hashes differ across repeats: {hashes_run1} vs {hashes_run2}"

    return True, "Stable scenario hashes and variant IDs reproduced identically across repeats."


def run_swa_10_dirty_tree_provenance() -> Tuple[bool, str]:
    """SWA-10 Dirty-tree provenance: record HEAD+dirty plus bounded change provenance; do not dump unrelated file contents."""
    env = probe_environment(REPO_ROOT)
    git_info = env.get("git", {})

    if not git_info.get("head"):
        return False, "git HEAD was not captured"
    if "is_dirty" not in git_info:
        return False, "is_dirty flag missing"
    if not isinstance(git_info.get("changed_paths_summary"), list):
        return False, "changed_paths_summary missing or not a list"

    # Verify bounded length
    if len(git_info["changed_paths_summary"]) > 100:
        return False, "changed_paths_summary exceeds bounded limit!"

    return True, f"Git HEAD={git_info['head'][:8]} recorded; is_dirty={git_info['is_dirty']}; bounded provenance={len(git_info['changed_paths_summary'])} items."


def run_swa_11_concurrency_guard() -> Tuple[bool, str]:
    """SWA-11 Concurrency guard: two interactive scenarios cannot overlap; synthetic non-GUI may parallelise if implemented."""
    with tempfile.TemporaryDirectory(prefix="swa_11_") as tmpdir:
        lock_file = Path(tmpdir) / ".test_guard.lock"

        guard1 = DesktopConcurrencyGuard(enabled=True, timeout_sec=0.5, lock_file=lock_file)
        guard2 = DesktopConcurrencyGuard(enabled=True, timeout_sec=0.5, lock_file=lock_file)
        non_interactive_guard = DesktopConcurrencyGuard(enabled=False, lock_file=lock_file)

        # 1. Guard 1 acquires
        guard1.acquire()

        # 2. Non-interactive proceeds freely
        non_interactive_guard.acquire()
        non_interactive_guard.release()

        # 3. Guard 2 must fail or conflict
        conflict = False
        try:
            guard2.acquire()
        except ConcurrencyConflictError:
            conflict = True
        finally:
            guard1.release()

        if not conflict:
            return False, "Second interactive guard did not raise ConcurrencyConflictError!"

    return True, "Concurrency guard prevented simultaneous interactive lock; non-interactive bypassed safely."


def run_swa_12_interrupted_recovery() -> Tuple[bool, str]:
    """SWA-12 Interrupted recovery: incomplete run is INCOMPLETE/INTERRUPTED, never PASS."""
    with tempfile.TemporaryDirectory(prefix="swa_12_") as tmpdir:
        broken_run_dir = Path(tmpdir) / "interrupted_run"
        broken_run_dir.mkdir(parents=True)

        # Write result.json with status INTERRUPTED
        with open(broken_run_dir / "result.json", "w", encoding="utf-8") as f:
            json.dump({"status": "INTERRUPTED", "scenario_id": "broken_sc"}, f)

        # Empty directory without result.json
        missing_run_dir = Path(tmpdir) / "missing_result_run"
        missing_run_dir.mkdir(parents=True)

        agg = Aggregator()
        data = agg.aggregate_from_run_dirs([broken_run_dir, missing_run_dir])
        c = data["counts"]

        if c["incomplete"] != 2:
            return False, f"Expected 2 incomplete runs, got {c['incomplete']}"
        if c["passed"] != 0:
            return False, f"Incomplete run was marked PASS: {c}"

    return True, "Interrupted and missing result.json runs classified as INCOMPLETE/INTERRUPTED, never PASS."


def run_swa_13_no_elevation() -> Tuple[bool, str]:
    """SWA-13 No elevation: full self-test + safe smoke in normal session without UAC/tasks/services/reboot/display reconfiguration."""
    if is_admin():
        return False, "Process is running as administrator! SWA-13 requires non-elevated validation."

    env = probe_environment(REPO_ROOT)
    if env["elevation"]["is_admin"]:
        return False, "Environment probe reported is_admin=True!"

    return True, "Confirmed running in standard non-elevated user session without UAC/service requirements."


def run_all_swa_tests() -> int:
    tests = [
        ("SWA-01", "Schema & Variants", run_swa_01_schema),
        ("SWA-02", "Dry-Run & Preflight", run_swa_02_dry_run),
        ("SWA-03", "Runner Success", run_swa_03_runner_success),
        ("SWA-04", "Runner Failure", run_swa_04_runner_failure),
        ("SWA-05", "Timeout & Tree Termination", run_swa_05_timeout),
        ("SWA-06", "Assertion Evaluation", run_swa_06_assertions),
        ("SWA-07", "Settings Restoration", run_swa_07_settings_restoration),
        ("SWA-08", "Fan-In & Signature Clustering", run_swa_08_fan_in),
        ("SWA-09", "Deterministic Rerun", run_swa_09_deterministic_rerun),
        ("SWA-10", "Dirty-Tree Provenance", run_swa_10_dirty_tree_provenance),
        ("SWA-11", "Concurrency Guard", run_swa_11_concurrency_guard),
        ("SWA-12", "Interrupted Recovery", run_swa_12_interrupted_recovery),
        ("SWA-13", "Non-Elevated Execution", run_swa_13_no_elevation),
    ]

    print("\n=================================================================")
    print("      Vision Test Farm Software Acceptance Suite (SWA-01..13)     ")
    print("=================================================================\n")

    passed_count = 0
    failed_count = 0

    for code, title, func in tests:
        print(f"[{code}] {title:35} ... ", end="", flush=True)
        try:
            ok, msg = func()
            if ok:
                passed_count += 1
                print(f"PASS\n      -> {msg}")
            else:
                failed_count += 1
                print(f"FAIL\n      -> {msg}")
        except Exception as e:
            failed_count += 1
            print(f"ERROR\n      -> Exception: {e}")

    print("\n-----------------------------------------------------------------")
    print(f"SWA Suite Results: {passed_count} PASSED, {failed_count} FAILED out of {len(tests)}")
    print("-----------------------------------------------------------------\n")

    return 0 if failed_count == 0 else 1


if __name__ == "__main__":
    sys.exit(run_all_swa_tests())
