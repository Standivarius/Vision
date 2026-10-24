"""
Vision Test Farm Deterministic Oracle & Assertion Engine (v0.1)

Evaluates assertions against execution evidence (exit code, telemetry CSV,
analysis JSON, logs) and produces structured assertion outcomes:
PASS, FAIL, or NOT_EVALUATED.
"""

from __future__ import annotations

import csv
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

FAILURE_CLASSES = {
    "HARNESS_DEFECT",
    "VISION_REGRESSION",
    "KNOWN_VISION_BEHAVIOUR",
    "ENVIRONMENT_CAPABILITY",
    "FLAKY_OR_NONDETERMINISTIC",
    "HUMAN_REVIEW_REQUIRED",
    "TEST_SPEC_DEFECT",
}


@dataclass
class AssertionResult:
    id: str
    name: str
    status: str  # "PASS", "FAIL", "NOT_EVALUATED"
    op: str
    expected: Any
    actual: Any
    critical: bool = True
    message: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "status": self.status,
            "op": self.op,
            "expected": self.expected,
            "actual": self.actual,
            "critical": self.critical,
            "message": self.message,
        }


def _compare(actual: Any, op: str, expected: Any) -> bool:
    try:
        if op == "eq":
            return actual == expected
        elif op == "ne":
            return actual != expected
        elif op == "lt":
            return float(actual) < float(expected)
        elif op == "lte":
            return float(actual) <= float(expected)
        elif op == "gt":
            return float(actual) > float(expected)
        elif op == "gte":
            return float(actual) >= float(expected)
        elif op == "contains":
            return str(expected) in str(actual)
        elif op == "not_contains":
            return str(expected) not in str(actual)
        elif op == "regex":
            return bool(re.search(str(expected), str(actual)))
    except Exception:
        return False
    return False


def _read_telemetry_csv(csv_path: Path) -> Tuple[bool, List[Dict[str, str]]]:
    """Read telemetry CSV, ignoring comment lines starting with #."""
    if not csv_path.is_file():
        return False, []
    try:
        rows: List[Dict[str, str]] = []
        with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            header = None
            for row in reader:
                if not row or not row[0].strip():
                    continue
                if row[0].startswith("#"):
                    continue
                if header is None:
                    header = [c.strip() for c in row]
                else:
                    if len(row) == len(header):
                        rows.append(dict(zip(header, [c.strip() for c in row])))
        return True, rows
    except Exception:
        return False, []


def evaluate_assertion(
    spec: Dict[str, Any],
    run_dir: Path,
    exit_code: int,
    stdout_text: str,
    stderr_text: str,
    telemetry_file: Optional[Path] = None,
) -> AssertionResult:
    aid = spec.get("id", "unnamed_assertion")
    name = spec.get("name", aid)
    atype = spec.get("type", "exit_code")
    op = spec.get("op", "eq")
    expected = spec.get("expected")
    critical = spec.get("critical", True)

    # 1. Exit code
    if atype == "exit_code":
        actual = exit_code
        passed = _compare(actual, op, expected)
        status = "PASS" if passed else "FAIL"
        msg = f"Exit code was {actual}, expected {op} {expected}"
        return AssertionResult(aid, name, status, op, expected, actual, critical, msg)

    # 2. File exists
    elif atype == "file_exists":
        target = spec.get("target")
        target_path = run_dir / target if target else run_dir
        actual = target_path.exists()
        passed = _compare(actual, op, expected)
        status = "PASS" if passed else "FAIL"
        msg = f"File {target} existence was {actual}"
        return AssertionResult(aid, name, status, op, expected, actual, critical, msg)

    # 3. Regex match on stdout/stderr/file
    elif atype in ("regex_match", "log_event"):
        target_stream = spec.get("target", "stdout")
        text = ""
        if target_stream == "stdout":
            text = stdout_text
        elif target_stream == "stderr":
            text = stderr_text
        else:
            file_path = run_dir / target_stream
            if file_path.is_file():
                try:
                    text = file_path.read_text(encoding="utf-8", errors="replace")
                except Exception:
                    pass
            else:
                return AssertionResult(
                    aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Log target file {target_stream} not found"
                )
        passed = _compare(text, op, expected)
        status = "PASS" if passed else "FAIL"
        actual = f"{len(text)} bytes checked"
        msg = f"Pattern {expected} in {target_stream}: {passed}"
        return AssertionResult(aid, name, status, op, expected, actual, critical, msg)

    # 4. Telemetry metrics
    elif atype == "telemetry_metric":
        telem_path = telemetry_file or (run_dir / "visual_app_telemetry.csv")
        found, rows = _read_telemetry_csv(telem_path)
        if not found or not rows:
            return AssertionResult(
                aid, name, "NOT_EVALUATED", op, expected, None, critical, "Telemetry file not available or empty"
            )

        col = spec.get("target")
        metric = spec.get("metric", "count")  # count, sum, min, max, non_zero_count, zero_count, distinct_count

        if col and col not in rows[0]:
            return AssertionResult(
                aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Telemetry column '{col}' not found"
            )

        try:
            if metric == "count":
                actual = len(rows)
            elif metric == "non_zero_count":
                actual = sum(1 for r in rows if float(r.get(col, 0)) != 0)
            elif metric == "zero_count":
                actual = sum(1 for r in rows if float(r.get(col, 0)) == 0)
            elif metric == "max":
                actual = max(float(r.get(col, 0)) for r in rows)
            elif metric == "min":
                actual = min(float(r.get(col, 0)) for r in rows)
            elif metric == "distinct_count":
                actual = len(set(r.get(col, "") for r in rows))
            elif metric == "last":
                actual = rows[-1].get(col)
            elif metric == "first":
                actual = rows[0].get(col)
            else:
                return AssertionResult(
                    aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Unsupported metric: '{metric}'"
                )
        except Exception as e:
            return AssertionResult(
                aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Metric evaluation error: {e}"
            )

        passed = _compare(actual, op, expected)
        status = "PASS" if passed else "FAIL"
        msg = f"Telemetry metric {col}.{metric} was {actual}, expected {op} {expected}"
        return AssertionResult(aid, name, status, op, expected, actual, critical, msg)

    # 5. Fallback for custom / analysis assertions
    elif atype == "custom":
        analysis_path = run_dir / "analysis.json"
        if not analysis_path.is_file():
            return AssertionResult(
                aid, name, "NOT_EVALUATED", op, expected, None, critical, "analysis.json not found"
            )
        try:
            with open(analysis_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            key = spec.get("target")
            if key not in data:
                return AssertionResult(
                    aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Key '{key}' not in analysis.json"
                )
            actual = data[key]
            passed = _compare(actual, op, expected)
            status = "PASS" if passed else "FAIL"
            msg = f"Analysis {key} was {actual}, expected {op} {expected}"
            return AssertionResult(aid, name, status, op, expected, actual, critical, msg)
        except Exception as e:
            return AssertionResult(
                aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Custom analysis error: {e}"
            )

    return AssertionResult(aid, name, "NOT_EVALUATED", op, expected, None, critical, f"Unknown assertion type: {atype}")


def evaluate_all_assertions(
    specs: List[Dict[str, Any]],
    run_dir: Path,
    exit_code: int,
    stdout_text: str,
    stderr_text: str,
    telemetry_file: Optional[Path] = None,
) -> List[AssertionResult]:
    """Evaluate full list of assertions against run artifacts."""
    results: List[AssertionResult] = []
    for spec in specs:
        res = evaluate_assertion(spec, run_dir, exit_code, stdout_text, stderr_text, telemetry_file)
        results.append(res)
    return results
