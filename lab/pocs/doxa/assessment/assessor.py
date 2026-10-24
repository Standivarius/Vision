"""Vision POC A assessment contracts and independent-evidence verdicts.

No application control here. Only accepts independent OS / visible-panel records.
Vision-internal telemetry may be attached but can never satisfy pass conditions.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

STATUSES = {"PASS", "FAIL", "INCONCLUSIVE", "BLOCKED"}
ROLES = {"LEFT", "RIGHT", "CENTRE", "LAPTOP", "NONE", "AMBIGUOUS"}
CHANNELS = {"os", "panel", "vision", "stimulus", "meta"}


def load_records(path: Path) -> list[dict]:
    rows = []
    for n, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        obj = json.loads(line)
        if not isinstance(obj, dict) or obj.get("channel") not in CHANNELS:
            raise ValueError(f"record {n}: invalid channel")
        if not isinstance(obj.get("t_ms"), (int, float)) or not math.isfinite(obj["t_ms"]):
            raise ValueError(f"record {n}: missing/invalid monotonic t_ms")
        rows.append(obj)
    if any(a["t_ms"] > b["t_ms"] for a, b in zip(rows, rows[1:])):
        raise ValueError("records must be in monotonic time order")
    return rows


def evaluate(plan: dict, records: list[dict]) -> dict:
    """Three-valued evidence gate: blocked / inconclusive / fail / verified pass.

    OS determines *whether the requested stimulus occurred*.
    Panel observation determines displayed output. Vision logs are diagnostic.
    """
    if plan.get("schema") != "vision-assessment-v1":
        raise ValueError("unsupported plan schema")
    scenarios = plan.get("phases")
    if not isinstance(scenarios, list) or not scenarios:
        raise ValueError("scenario must have nonempty phases")
    if any(r.get("channel") == "os" and r.get("locked") is True for r in records):
        return {"status": "BLOCKED", "reason": "LOCK_SCREEN", "phases": []}
    if any(r.get("channel") == "meta" and r.get("topology_ok") is False for r in records):
        return {"status": "BLOCKED", "reason": "TOPOLOGY_MISMATCH", "phases": []}

    results = []
    for phase in scenarios:
        name = phase["id"]
        beginning, end = float(phase["start_ms"]), float(phase["end_ms"])
        if end <= beginning:
            raise ValueError(f"{name}: invalid phase duration")
        if phase["expected_source"] not in {"LEFT", "RIGHT"}:
            raise ValueError(f"{name}: source must be LEFT or RIGHT")
        settle = float(phase.get("settle_ms", 1200))
        window = [r for r in records if beginning + settle <= r["t_ms"] < end]
        os_rows = [r for r in window if r["channel"] == "os" and r.get("role") in ROLES]
        output_rows = [r for r in window if r["channel"] == "panel" and r.get("source") in ROLES]
        errors, missing, detail = [], [], {}
        expected = phase["expected_source"]
        expected_foreground = phase.get("foreground_source", expected)
        # Foreground input is a precondition, not assumed because a script asked.
        if phase.get("require_foreground", True):
            if len(os_rows) < 2:
                missing.append("independent OS foreground observations")
            elif not any(r["role"] == expected_foreground for r in os_rows):
                missing.append(f"stimulus did not establish {expected_foreground} foreground")
            elif any(r["role"] != expected_foreground for r in os_rows):
                # Other windows legitimately stealing foreground void the trial.
                missing.append("foreground precondition interrupted")
        # Sparse samples at the end must not be mistaken for complete observation.
        max_sample_gap = float(phase.get("max_sample_gap_ms", 1500))
        for label, samples in (("OS", os_rows), ("panel", output_rows)):
            if len(samples) >= 2:
                gaps = [samples[0]["t_ms"] - (beginning + settle),
                        (end - samples[-1]["t_ms"])]
                gaps += [b["t_ms"] - a["t_ms"] for a, b in zip(samples, samples[1:])]
                if max(gaps) > max_sample_gap:
                    missing.append(f"{label} evidence coverage gap {max(gaps):.0f}ms")
        if len(output_rows) < 2:
            missing.append("independent displayed-output observations")
        else:
            if any(r.get("observed_by") not in
                   {"independent_image_analysis", "external_camera_analysis"}
                   for r in output_rows):
                missing.append("independent visual-observation provenance")
            mismatch = [r for r in output_rows if r["source"] != expected]
            if mismatch:
                errors.append(f"wrong displayed source ({len(mismatch)}/{len(output_rows)} samples)")
            if phase.get("require_caret_in_view", False):
                caret_values = [r.get("caret_in_view") for r in output_rows]
                if any(v is None for v in caret_values):
                    missing.append("independently mapped caret-to-detail viewport")
                elif not all(v is True for v in caret_values):
                    errors.append("caret outside magnified detail viewport")
            if phase.get("changing_content", False):
                counters = [r.get("counter") for r in output_rows]
                if any(not isinstance(x, int) or x < 0 for x in counters):
                    missing.append("independent visible content-change counter")
                elif len(set(counters)) < 2:
                    errors.append("frozen displayed content")
                elif any(a > b for a, b in zip(counters, counters[1:])):
                    errors.append("displayed content counter regressed")
                else:
                    # Compute time between *actual content changes*, not between
                    # adjacent samples: a stale plateau must be visible to the oracle.
                    change_rows = [output_rows[0]]
                    change_rows.extend(b for a, b in zip(output_rows, output_rows[1:])
                                       if b["counter"] != a["counter"])
                    gaps = [b["t_ms"] - a["t_ms"] for a, b in
                            zip(change_rows, change_rows[1:])]
                    gaps.append(output_rows[-1]["t_ms"] - change_rows[-1]["t_ms"])
                    gap = max(gaps, default=0)
                    detail["max_observed_update_interval_ms"] = round(gap, 2)
                    if gap > phase.get("max_update_gap_ms", 2500):
                        errors.append(f"display refresh gap {gap:.0f} ms too long")
            if phase.get("require_zoom") is not None:
                # Software frame acquisition can sample a temporary repaint before
                # the ruler is visible. Do NOT require impossible 100% measurement
                # coverage, but do demand a dense independent temporal series.
                # A wrong independently measured zoom is never treated as missing.
                measured = [r for r in output_rows
                            if isinstance(r.get("scale"), (int, float))
                            and math.isfinite(r["scale"])]
                fraction = len(measured) / len(output_rows)
                min_fraction = float(phase.get("min_zoom_sample_fraction", 0.90))
                max_zoom_gap = float(phase.get("max_zoom_evidence_gap_ms", 1800))
                if not 0 < min_fraction <= 1 or max_zoom_gap <= 0:
                    raise ValueError(f"{name}: invalid zoom evidence thresholds")
                detail["zoom_measured_fraction"] = round(fraction, 3)
                detail["zoom_measured_samples"] = len(measured)
                if len(measured) < 3 or fraction < min_fraction:
                    missing.append("independent visual zoom measurement coverage")
                else:
                    clock = [beginning + settle]
                    clock.extend(r["t_ms"] for r in measured)
                    clock.append(end)
                    worst_gap = max(b - a for a, b in zip(clock, clock[1:]))
                    detail["max_zoom_evidence_gap_ms"] = round(worst_gap, 2)
                    if worst_gap > max_zoom_gap:
                        missing.append(f"independent zoom evidence gap {worst_gap:.0f}ms")
                tolerance = float(phase.get("zoom_tolerance", 0.25))
                if any(abs(r["scale"] - phase["require_zoom"]) > tolerance
                       for r in measured):
                    errors.append("incorrect displayed magnification")
        # A FAIL is legitimate only when the environment/OS preconditions are met.
        status = "INCONCLUSIVE" if missing else "FAIL" if errors else "PASS"
        results.append({"id": name, "status": status, "expected_source": expected,
                        "os_samples": len(os_rows), "panel_samples": len(output_rows),
                        "missing": missing, "errors": errors, "metrics": detail})
    statuses = {r["status"] for r in results}
    overall = "INCONCLUSIVE" if "INCONCLUSIVE" in statuses else "FAIL" if "FAIL" in statuses else "PASS"
    # Without a dedicated external physical-panel observation / validated capture
    # calibration, a PASS is software-visible only, NOT user-visible photon truth.
    return {"status": overall, "evidence_scope": "independent_os_plus_annotated_panel_not_photon_latency",
            "scenario": plan.get("id"), "phases": results,
            "vision_logs_used_for_verdict": False}


def main() -> int:
    parser = argparse.ArgumentParser(description="Vision local independent-evidence assessor")
    sub = parser.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("evaluate")
    e.add_argument("scenario", type=Path)
    e.add_argument("evidence", type=Path)
    e.add_argument("--output", type=Path)
    m = sub.add_parser("merge")
    m.add_argument("--os", type=Path, required=True)
    m.add_argument("--panel", type=Path, required=True)
    m.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.cmd == "merge":
        os_rows = load_records(args.os)
        panel_rows = load_records(args.panel)
        def anchor(rows):
            matches = {r.get("anchor_qpc_ns") for r in rows
                       if r["channel"] == "meta" and r.get("anchor_qpc_ns") is not None}
            if len(matches) != 1:
                raise ValueError("evidence stream missing unique shared QPC anchor")
            return matches.pop()
        if anchor(os_rows) != anchor(panel_rows):
            raise ValueError("OS and panel observations have different QPC origins")
        if not any(r["channel"] == "os" for r in os_rows):
            raise ValueError("OS observer stream missing")
        if not any(r["channel"] == "panel" for r in panel_rows):
            raise ValueError("independent panel annotation stream missing")
        combined = sorted(os_rows + panel_rows, key=lambda r: r["t_ms"])
        if args.output.exists():
            raise FileExistsError("Refusing to overwrite combined evidence")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n"
                                       for r in combined), encoding="utf-8")
        print(json.dumps({"status": "MERGED_NOT_ASSESSED", "records": len(combined),
                          "shared_qpc_origin": anchor(os_rows)}))
        return 0
    if args.cmd == "evaluate":
        report = evaluate(json.loads(args.scenario.read_text(encoding="utf-8-sig")),
                          load_records(args.evidence))
        text = json.dumps(report, indent=2)
        if args.output:
            if args.output.exists():
                raise FileExistsError("Evidence report exists; refusing overwrite")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(text + "\n", encoding="utf-8")
        print(text)
        return {"PASS": 0, "FAIL": 2, "INCONCLUSIVE": 3, "BLOCKED": 4}[report["status"]]
    return 1


if __name__ == "__main__":
    sys.exit(main())

