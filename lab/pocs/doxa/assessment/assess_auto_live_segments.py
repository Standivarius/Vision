"""Independent event-relative automatic-focus visual verdict.

Use ALL contiguous real OS foreground-role segments rather than delayed
PowerShell call-return timestamps. Expected source is the source selected by
POC foreground-follow policy (LEFT/RIGHT); LAPTOP means hold last source.
Never use panel labels to choose expected source/segments.
"""
import argparse
import json
import sys
from pathlib import Path

from assessor import evaluate, load_records


def derive(run_dir: Path) -> dict:
    merged = load_records(run_dir / "merged-independent.jsonl")
    os_rows = [r for r in merged if r["channel"] == "os"]
    panel_rows = [r for r in merged if r["channel"] == "panel"]
    if len(os_rows) < 100 or len(panel_rows) < 40:
        raise ValueError("Not enough independent evidence to derive segments")
    if any(r.get("locked") is True for r in os_rows):
        raise ValueError("Locked desktop; do not reinterpret trial")
    periods = []
    for r in os_rows:
        role = r.get("role")
        if role not in {"LEFT", "RIGHT", "LAPTOP", "CENTRE", "NONE", "AMBIGUOUS"}:
            raise ValueError(f"Unknown OS role: {role}")
        if not periods or periods[-1]["role"] != role:
            periods.append({"role": role, "start_ms": r["t_ms"]})
    # Keep every real foreground transition; do not cherry-pick calm windows.
    # CENTRE/NONE/AMBIGUOUS mean stimulus cannot be reliably attributed,
    # so require explicit review instead of silently skipping evidence.
    role_sequence = [p["role"] for p in periods]
    if any(role in {"CENTRE", "NONE", "AMBIGUOUS"} for role in role_sequence):
        raise ValueError(f"Ambiguous OS foreground history: {periods}")
    first_right = next((i for i, role in enumerate(role_sequence) if role == "RIGHT"), None)
    if first_right is None or not any(role == "LEFT" for role in role_sequence[first_right + 1:]):
        raise ValueError(f"No verified RIGHT -> LEFT focus journey: {periods}")
    last_observed = min(os_rows[-1]["t_ms"], panel_rows[-1]["t_ms"]) - 180
    if last_observed <= periods[-1]["start_ms"] + 5000:
        raise ValueError("Final physical-console interval is too short")
    phases = []
    prior_source = "LEFT"  # POC started with owner-selected LEFT
    counts = {"LEFT": 0, "RIGHT": 0, "LAPTOP": 0}
    for i, period in enumerate(periods):
        role = period["role"]
        counts[role] += 1
        if role in {"LEFT", "RIGHT"}:
            prior_source = role
        beginning = period["start_ms"]
        end = periods[i + 1]["start_ms"] if i + 1 < len(periods) else last_observed
        settle = 250 if role == "LAPTOP" and i > 0 else 3000
        if end - beginning - settle < 1500:
            raise ValueError(f"Segment {i} has insufficient observations")
        phases.append({
            "id": f"{role.lower()}-{counts[role]}",
            "start_ms": round(beginning, 3),
            "end_ms": round(end, 3),
            "settle_ms": settle,
            "expected_source": prior_source,
            "foreground_source": role,
            "require_foreground": True,
            "changing_content": True,
            "max_update_gap_ms": 2500,
            "max_sample_gap_ms": 1500,
        })
    source_plan = {
        "schema": "vision-assessment-v1",
        "id": "A03-actual-OS-foreground-segments",
        "notes": "All real OS role periods kept, including laptop interruption. "
                 "Expected source derives from policy, never the panel labels.",
        "phases": phases,
    }
    full_plan = {
        **source_plan,
        "id": "A03-full-independent-zoom-required",
        "phases": [{**p, "require_zoom": 2} for p in phases],
    }
    for name, obj in (
        ("scenario-source-only.json", source_plan),
        ("scenario-full.json", full_plan),
    ):
        dest = run_dir / name
        if dest.exists():
            raise FileExistsError(f"Refusing overwrite: {dest}")
        dest.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")

    source_score = evaluate(source_plan, merged)
    full_score = evaluate(full_plan, merged)
    for name, score in (
        ("verdict-source-only.json", source_score),
        ("verdict-full-zoom.json", full_score),
    ):
        dest = run_dir / name
        if dest.exists():
            raise FileExistsError(f"Refusing overwrite: {dest}")
        dest.write_text(json.dumps(score, indent=2) + "\n", encoding="utf-8")
    return {
        "source_verdict": source_score["status"],
        "full_zoom_verdict": full_score["status"],
        "phases": [
            {
                "name": p["id"],
                "os_role": p["foreground_source"],
                "expected_panel_source": p["expected_source"],
                "verdict": v["status"],
                "panel_samples": v["panel_samples"],
                "os_samples": v["os_samples"],
                "errors": v["errors"],
                "missing": v["missing"],
            }
            for p, v in zip(phases, source_score["phases"])
        ],
        "display_photon_proof": False,
        "note": "Corrected delayed harness timestamps, not raw OS or panel evidence",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=Path)
    args = ap.parse_args()
    result = derive(args.run_dir)
    print(json.dumps(result, indent=2))
    return 0 if result["source_verdict"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())

