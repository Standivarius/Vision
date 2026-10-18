"""Strict A03 office-switch qualification with a negative-only viewport veto.

Independent GDI colour/source checks are still required to PASS. Source caret
or cell rectangles come from the test-owned Win32/UIA Office process. Vision
telemetry can only DISQUALIFY a run with a demonstrably excluded caret. It
CANNOT independently establish visible output or turn INCONCLUSIVE into PASS.
Historical visual verdicts remain unmodified.
"""
import json
import sys
from pathlib import Path
from importlib import util

root = Path(__file__).resolve().parent
path = root / "A03-AuditViewportCaretContainment.py"
spec = util.spec_from_file_location("a03_viewport_audit", path)
audit = util.module_from_spec(spec)
spec.loader.exec_module(audit)


def strict_verdict(independent, geometry):
    visual = independent.get("status", "INCONCLUSIVE_NO_VISUAL_VERDICT")
    if not visual.startswith("PASS_OFFICE_SWITCH"):
        return visual
    phases = geometry.get("phases", [])
    if len(phases) != 6 or geometry.get("diagnostic_only") is not True:
        return "INCONCLUSIVE_NO_CARET_GEOMETRY"
    if any(phase.get("status") == "DISPLACED" for phase in phases):
        return "FAIL_ACTUAL_CARET_OUTSIDE_DETAIL_VIEW"
    if any(phase.get("status") != "INSIDE" or phase.get("samples", 0) < 30
           for phase in phases):
        return "INCONCLUSIVE_CARET_GEOMETRY_COVERAGE"
    return "PASS_OFFICE_SWITCH_4X_INDEPENDENT_PIXELS_WITH_CARET_CONTAINMENT"


def qualify(folder: Path):
    base = json.loads((folder / "office-switch-independent-verdict.json").read_text(
        encoding="utf-8-sig"))
    geometry = audit.evaluate(folder)
    return {
        "status": strict_verdict(base, geometry),
        "independent_visual_verdict": base["status"],
        "geometry_veto_only": True,
        "source_coordinates": "test-owned Win32 caret or UI Automation selected cell",
        "viewport_coordinates": "Vision diagnostic telemetry, never a PASS oracle",
        "phases": geometry["phases"],
        "visual_phases": base.get("phases", []),
        "limitations": "GDI software-visible frames, not panel photons, 2 fps visual timing",
    }


if __name__ == "__main__":
    folder = Path(sys.argv[1])
    if len(sys.argv) > 2 and sys.argv[2] == "--no-write":
        result = qualify(folder)
    else:
        dest = folder / "office-switch-caret-qualified-v2.json"
        if dest.exists():
            raise FileExistsError(f"Refuse overwrite: {dest}")
        result = qualify(folder)
        dest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"run": folder.name, "status": result["status"],
                      "original": result["independent_visual_verdict"],
                      "inside_fractions": [p.get("inside_fraction") for p in result["phases"]]}))
    raise SystemExit(0 if result["status"].startswith("PASS") else 3)
