"""A03 supplementary diagnostic: OS-sourced caret/cell versus Vision viewport.

NOT independent rendered-pixel acceptance. Do not use it as the primary PASS
oracle. The source rectangle is from controlled Word Win32 / Excel UIA evidence;
the viewport is *Vision telemetry*, useful to explain missing visual output.
"""
import csv
import json
import sys
from pathlib import Path


def phase_geometry(rows, source_rect, start, end, settle_ms=650):
    eligible = [r for r in rows if start + settle_ms <= r["ms"] < end - 150]
    if not eligible or not source_rect:
        return {"status": "INCONCLUSIVE", "samples": len(eligible)}
    within = [
        r["left"] <= source_rect["left"] and r["right"] >= source_rect["right"]
        and r["top"] <= source_rect["top"] and r["bottom"] >= source_rect["bottom"]
        for r in eligible
    ]
    runs = []
    miss = None
    for r, yes in zip(eligible, within):
        if not yes and miss is None:
            miss = r["ms"]
        if yes and miss is not None:
            runs.append(r["ms"] - miss)
            miss = None
    if miss is not None:
        runs.append(eligible[-1]["ms"] - miss)
    fraction = sum(within) / len(within)
    return {"status": "INSIDE" if fraction >= 0.9 else "DISPLACED",
            "samples": len(eligible),
            "inside_fraction": round(fraction, 3),
            "max_continuous_miss_ms": round(max(runs, default=0), 1),
            "first_viewport": [eligible[0][k] for k in ("left", "top", "right", "bottom")],
            "last_viewport": [eligible[-1][k] for k in ("left", "top", "right", "bottom")]}


def evaluate(run_dir: Path):
    meta = json.loads((run_dir / "result.json").read_text(encoding="utf-8-sig"))
    source = json.loads((Path(meta["source_report_path"]) / "result.json").read_text(encoding="utf-8-sig"))
    anchor = meta["anchor_qpc_ns"]
    rows = []
    with (run_dir / "vision-diagnostic.csv").open(encoding="utf-8-sig", newline="") as stream:
        for record in csv.DictReader(stream):
            if not record.get("frame", "").isdigit():
                continue
            try:
                rows.append({
                    "ms": (int(record["qpc"]) * 100 - anchor) / 1e6,
                    "left": float(record["view_left"]),
                    "top": float(record["view_top"]),
                    "right": float(record["view_right"]),
                    "bottom": float(record["view_bottom"]),
                })
            except (KeyError, ValueError):
                continue
    phases = []
    for item in source["observations"]:
        start = (item["phase_start_qpc_ns"] - anchor) / 1e6
        end = (item["phase_end_qpc_ns"] - anchor) / 1e6
        p = phase_geometry(rows, item.get("source_rect"), start, end)
        phases.append({"step": item["step"], "app": item["app"],
                       "target": item["target"], **p})
    return {"run": run_dir.name, "diagnostic_only": True, "phases": phases}


if __name__ == "__main__":
    for path in sys.argv[1:]:
        print(json.dumps(evaluate(Path(path)), indent=2))
