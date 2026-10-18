"""Falsify actual independent POC A evidence without changing the originals.

Negative controls deliberately corrupt copies of real OS/panel observations.
The result is assessor self-validation, not new physical stimulus evidence.
"""
import argparse
import copy
import json
import sys
from pathlib import Path

from assessor import evaluate, load_records


def run(run_dir: Path) -> dict:
    plan = json.loads((run_dir / "scenario-source-only.json").read_text(encoding="utf-8"))
    original = load_records(run_dir / "merged-independent.jsonl")
    real = evaluate(plan, original)
    if real["status"] != "PASS":
        raise AssertionError("Refusing mutations: source-only baseline not PASS")
    phases = plan["phases"]
    right = phases[1]
    left_return = phases[2]

    def within(record, phase):
        return phase["start_ms"] + phase["settle_ms"] <= record["t_ms"] < phase["end_ms"]

    cases = {}

    changed = copy.deepcopy(original)
    # Mutate ONLY independently classified source frames. Converting a
    # genuinely unobservable frame would also introduce a missing counter,
    # confounding wrong-source detection with evidence incompleteness.
    eligible = [r for r in changed if r["channel"] == "panel"
                and within(r, right)
                and r.get("source") == right["expected_source"]
                and isinstance(r.get("counter"), int)]
    if len(eligible) < 3:
        raise AssertionError("Cannot target enough real right-panel observations")
    for rec in eligible:
        rec["source"] = "LEFT"
    cases["wrong_source"] = evaluate(plan, changed)["status"]

    changed = copy.deepcopy(original)
    eligible = [r for r in changed if r["channel"] == "panel" and within(r, left_return)]
    if len(eligible) < 3:
        raise AssertionError("Cannot target enough live-change observations")
    for rec in eligible:
        rec["counter"] = eligible[0]["counter"]
    cases["frozen_image"] = evaluate(plan, changed)["status"]

    changed = [r for r in original if r["channel"] != "panel"]
    cases["missing_visual_evidence"] = evaluate(plan, changed)["status"]

    changed = copy.deepcopy(original)
    changed.insert(0, {"channel": "meta", "t_ms": 0, "topology_ok": False})
    cases["wrong_topology"] = evaluate(plan, changed)["status"]

    changed = copy.deepcopy(original)
    locked_os = next(r for r in changed if r["channel"] == "os")
    locked_os["locked"] = True
    cases["lock_screen"] = evaluate(plan, changed)["status"]

    expected = {
        "wrong_source": "FAIL",
        "frozen_image": "FAIL",
        "missing_visual_evidence": "INCONCLUSIVE",
        "wrong_topology": "BLOCKED",
        "lock_screen": "BLOCKED",
    }
    full_path = run_dir / "scenario-full.json"
    if full_path.exists():
        full_plan = json.loads(full_path.read_text(encoding="utf-8"))
        qualified = evaluate(full_plan, original)
        if qualified["status"] == "PASS":
            changed = copy.deepcopy(original)
            measured = [r for r in changed if r["channel"] == "panel"
                        and isinstance(r.get("scale"), (int, float))]
            if len(measured) < 10:
                raise AssertionError("Insufficient qualified zoom samples")
            for row in measured:
                row["scale"] = 4.0
            cases["wrong_zoom"] = evaluate(full_plan, changed)["status"]

            changed = copy.deepcopy(original)
            for row in changed:
                if row["channel"] == "panel":
                    row["scale"] = None
            cases["missing_zoom"] = evaluate(full_plan, changed)["status"]
            expected["wrong_zoom"] = "FAIL"
            expected["missing_zoom"] = "INCONCLUSIVE"
    if cases != expected:
        raise AssertionError(f"Mutation regression! actual={cases}, expected={expected}")
    return {
        "status": "PASS",
        "real_baseline": real["status"],
        "synthetic_mutations_against_real_evidence": cases,
        "mutations": len(cases),
        "note": "Original evidence and report unmodified",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if args.output.exists():
        raise FileExistsError("Refuse overwrite")
    result = run(args.run_dir)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())

