"""Summarize independent baseline of Vision UI Automation polling stalls."""
import csv
import json
import statistics
import sys
from pathlib import Path


def evaluate(run: Path):
    with (run / "vision-diagnostic.csv").open(encoding="utf-8-sig", newline="") as fp:
        rows = [r for r in csv.DictReader(fp) if r.get("frame","").isdigit()]
    result = json.loads((run / "result.json").read_text(encoding="utf-8-sig"))
    ages = [float(r["uia_snapshot_age_ms"]) for r in rows if r.get("uia_snapshot_age_ms")]
    good = [age for age in ages if 0 <= age <= 2500]
    stale = [age for age in ages if age > 2500]
    current = 0
    longest = 0
    for age in ages:
        current = current + 1 if age > 2500 else 0
        longest = max(longest, current)
    return {
        "run": run.name,
        "frames": len(rows),
        "uia_max_age_ms": max(ages) if ages else None,
        "uia_median_age_ms": statistics.median(ages) if ages else None,
        "frames_with_uia_stale_over_2_5s": len(stale),
        "fraction_stale": round(len(stale) / len(ages), 3) if ages else None,
        "longest_stale_interval_approx_ms": round(longest * 1000 / 60),
        "preview_shutdown": result.get("preview_shutdown"),
        "source_word_result": result.get("source_side_word_result"),
        "note": "Diagnostic telemetry is only for root-cause analysis, never output acceptance.",
    }


if __name__ == "__main__":
    base=Path(sys.argv[1])
    paths=sorted(base.glob("word-4x-visual-*"))
    print(json.dumps([evaluate(p) for p in paths], indent=2))
