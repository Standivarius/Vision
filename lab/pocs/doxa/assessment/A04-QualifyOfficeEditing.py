"""A04 Windows keyboard-edited Word/Excel 4x, fail-closed acceptance.

A03's independent software-visible source/Detail pixel scorer AND A03's
negative-only caret containment veto must PASS first. A04 additionally
requires six real Windows-keyboard-message edits to be independently
verified by Office COM, PageDown navigation verified by Word selection or
Excel ScrollRow, and source process/cleanup evidence. No telemetry can
turn a failed screenshot into PASS.
"""
import json
import sys
from pathlib import Path


SUCCESS = "PASS_OFFICE_EDIT_4X_TYPED_AND_SCROLLED_VISIBLE_WITH_CARET"


def qualify(source, capture, base, strict):
    if base.get("status") != "PASS_OFFICE_SWITCH_4X_VISIBLE_WITHIN_2S":
        return base.get("status", "INCONCLUSIVE_INDEPENDENT_VISUAL")
    if strict.get("status") != "PASS_OFFICE_SWITCH_4X_INDEPENDENT_PIXELS_WITH_CARET_CONTAINMENT":
        return strict.get("status", "INCONCLUSIVE_CARET_CONTAINMENT")
    if source.get("status") != "PASS_SOURCE_SWITCH_TRUTH":
        return "INCONCLUSIVE_EDIT_SOURCE_TRUTH"
    if capture.get("office_script_exit") != 0:
        return "FAIL_EDIT_SCRIPT_EXIT"
    if capture.get("preview_shutdown") != "NORMAL":
        return "FAIL_EDIT_PREVIEW_SHUTDOWN"
    if capture.get("display_count") not in (3, 4):
        return "INCONCLUSIVE_DISPLAY_TOPOLOGY"
    if any(source.get(name) is not False for name in ("workbook_saved", "document_saved")):
        return "FAIL_EDITED_DOCUMENT_SAVED"
    if source.get("pointer_restored") is not True or source.get("focus_restored") is not True:
        return "FAIL_EDIT_DESKTOP_NOT_RESTORED"
    if (capture.get("right_frames", 0) < 90
            or capture.get("centre_frames", 0) < 90):
        return "INCONCLUSIVE_EDIT_CAPTURE_LENGTH"
    samples = source.get("observations") or []
    if len(samples) != 6 or source.get("source_verified_steps") != 6:
        return "INCONCLUSIVE_EDIT_STEP_COUNT"
    if source.get("typed_verified_steps") != 6:
        return "FAIL_EDIT_TEXT_NOT_CONFIRMED"
    if source.get("scroll_verified_steps") != 6:
        return "FAIL_EDIT_PAGEDOWN_NOT_CONFIRMED"
    for i, observation in enumerate(samples):
        expected_app = "WORD" if i % 2 == 0 else "EXCEL"
        expected = f"VISIONA04{'W' if i % 2 == 0 else 'E'}{i}"
        if (observation.get("step") != i
                or observation.get("app") != expected_app
                or observation.get("typed_token") != expected):
            return "FAIL_EDIT_INPUT_SEQUENCE"
        if observation.get("input_method") != "Win32 SendInput Unicode and virtual keys":
            return "INCONCLUSIVE_EDIT_INPUT_METHOD"
        if (observation.get("foreground_owned") is not True
                or observation.get("foreground_owned_at_measurement") is not True
                or observation.get("foreground_pid_at_measurement") != observation.get("expected_pid")):
            return "FAIL_EDIT_WRONG_FOREGROUND"
        if (observation.get("typed_verified") is not True
                or observation.get("scroll_verified") is not True):
            return "FAIL_EDIT_INTERACTION_NOT_CONFIRMED"
        before = observation.get("navigation_before")
        after = observation.get("navigation_after")
        if not isinstance(before, int) or not isinstance(after, int) or after <= before:
            return "FAIL_EDIT_PAGEDOWN_NO_MOVEMENT"
        if (observation.get("target_verified") is not True
                or observation.get("window_on_right") is not True):
            return "FAIL_EDIT_CARET_OR_CELL_NOT_SOURCE_OWNED"
    strict_phases = strict.get("phases") or []
    if len(strict_phases) != 6 or any(
            p.get("inside_fraction") != 1.0 for p in strict_phases):
        return "INCONCLUSIVE_EDIT_CARET_CONTAINMENT"
    return SUCCESS


def main(folder: Path):
    capture = json.loads((folder / "result.json").read_text(encoding="utf-8-sig"))
    source = json.loads((Path(capture["source_report_path"]) / "result.json").read_text(
        encoding="utf-8-sig"))
    base = json.loads((folder / "office-switch-independent-verdict.json").read_text(
        encoding="utf-8-sig"))
    strict = json.loads((folder / "office-switch-caret-qualified-v2.json").read_text(
        encoding="utf-8-sig"))
    status = qualify(source, capture, base, strict)
    report = {
        "status": status, "run": folder.name,
        "independent_visual_verdict": base["status"],
        "caret_containment_verdict": strict["status"],
        "type_confirmed_steps": source.get("typed_verified_steps"),
        "page_down_confirmed_steps": source.get("scroll_verified_steps"),
        "right_frames": capture.get("right_frames"),
        "centre_frames": capture.get("centre_frames"),
        "max_sampled_frame_lag_ms": base.get("max_observed_lag_ms"),
        "desktop_restored": bool(source.get("focus_restored") and source.get("pointer_restored")),
        "caveat": "SendInput simulated Windows key events and application-state check; not human typing or photonic latency",
    }
    output = folder / "office-edit-qualified-v1.json"
    if output.exists():
        raise FileExistsError("Refuse overwrite of evidence verdict")
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    return 0 if status == SUCCESS else 3


if __name__ == "__main__":
    raise SystemExit(main(Path(sys.argv[1])))
