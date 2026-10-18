"""Independent Excel 4x source-cell identity plus output-marker assessment.

Source truth: COM active cell and UI Automation address/geometry in disposable
workbook. Output truth: independent right/Centre software GDI pixels only.
No magnifier self-telemetry is used to declare visible acceptance.
"""
from pathlib import Path
import json
import statistics
import sys
from importlib import util

_script=Path(__file__).with_name("A02-AnalyzeColourLatencyFast.py")
_spec=util.spec_from_file_location("word_colour_latency_shared",str(_script))
_module=util.module_from_spec(_spec)
_spec.loader.exec_module(_module)
scans=_module.scans
assess_phases=_module.assess_phases


def assess_excel_phases(phases, source_status):
    if source_status != "PASS_SOURCE_CELL_IDENTITY" or len(phases) != 6:
        return "INCONCLUSIVE_SOURCE_CELL_IDENTITY"
    if not all(p["cell_identity_correct"] for p in phases):
        return "INCONCLUSIVE_SOURCE_CELL_IDENTITY"
    result = assess_phases(phases)
    return ("PASS_EXCEL_SOURCE_IDENTITY_AND_VISIBLE_MARKERS_WITHIN_2S"
            if result.startswith("PASS") else result)


def assess_excel_run(phases, source_report, capture_report):
    if capture_report.get("display_count") not in (3,4):
        return "INCONCLUSIVE_TOPOLOGY_EVIDENCE"
    if (capture_report.get("excel_script_exit") != 0 or
        source_report.get("workbook_saved") is not False or
        source_report.get("focus_restored") is not True):
        return "FAIL_SOURCE_FIXTURE_CLEANUP"
    if capture_report.get("preview_shutdown") != "NORMAL":
        return "FAIL_VISION_PREVIEW_SHUTDOWN"
    if capture_report.get("right_frames",0)<30 or capture_report.get("centre_frames",0)<30:
        return "INCONCLUSIVE_INDEPENDENT_CAPTURE"
    return assess_excel_phases(phases,source_report.get("status"))


def main(folder):
    run=Path(folder)
    meta=json.loads((run/"result.json").read_text(encoding="utf-8-sig"))
    source=json.loads((Path(meta["source_report_path"])/"result.json").read_text(encoding="utf-8-sig"))
    screen=source["physical_right_bounds"]
    bounds=source["excel_window_bounds"]
    # 480x270 GDI images of full 1920x1080 external source monitor.
    source_roi=((bounds["left"]+100-screen["left"])*480/1920,
                (bounds["top"]+210-screen["top"])*270/1080,
                (bounds["right"]-75-screen["left"])*480/1920,
                (bounds["bottom"]-75-screen["top"])*270/1080)
    right=scans(run/"right",source_roi)
    centre=scans(run/"centre",(4,30,476,260))
    anchor=meta["anchor_qpc_ns"]
    phases=[]
    for observation in source["observations"]:
        step=int(observation["step"])
        expected="YELLOW" if step%2==0 else "GREEN"
        start=(observation["phase_start_qpc_ns"]-anchor)/1e6
        end=(observation["phase_qpc_ns"]-anchor)/1e6
        eligible=lambda r:start-400<=r["t_ms"]<=end-150
        src=[r for r in right if eligible(r)]
        output=[r for r in centre if eligible(r)]
        srcVisible=[r for r in src if r[expected]>=70]
        outVisible=[r for r in output if r[expected]>=220]
        firstS=srcVisible[0]["t_ms"] if srcVisible else None
        firstO=outVisible[0]["t_ms"] if outVisible else None
        lag=firstO-firstS if firstS is not None and firstO is not None else None
        cell=observation["target_cell"]
        identity=(observation.get("com_active_cell")==cell and
                  observation.get("uia_focus_cell")==cell and
                  observation.get("uia_focus_pid")==source.get("spawned_excel_pid") and
                  observation.get("uia_bounds") is not None)
        phases.append({
            "step":step, "expected_cell":cell, "cell_identity_correct":identity,
            "expected_colour":expected, "source_frames":len(src),
            "centre_frames":len(output),
            "source_colour_visible":len(srcVisible),
            "centre_colour_visible":len(outVisible),
            "source_median_pixels":statistics.median([r[expected] for r in src]) if src else 0,
            "centre_median_pixels":statistics.median([r[expected] for r in output]) if output else 0,
            "latency_ms":round(lag,1) if lag is not None else None,
        })
    visible=assess_phases(phases)
    final=assess_excel_run(phases,source,meta)
    result={
        "status":final,
        "visible_subverdict":visible,
        "display_count":meta.get("display_count"),
        "source_roi":source_roi,
        "right_frames":len(right),
        "centre_frames":len(centre),
        "max_observed_lag_ms":max((p["latency_ms"] for p in phases if p["latency_ms"] is not None),default=None),
        "phases":phases,
        "limitations":"software pixels, not physical camera; 2fps coarse latency; no Word or screen-reader claim",
    }
    output_name=("excel-colour-identity-latency.json" if len(sys.argv)==2
                 else sys.argv[2])
    if output_name not in {"excel-colour-identity-latency.json",
                           "excel-colour-identity-qualified-v2.json"}:
        raise ValueError("unsupported output evidence name")
    target=run/output_name
    if target.exists():
        raise FileExistsError("Refusing to overwrite evidence")
    target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result))
    return 0 if final.startswith("PASS") else 2

if __name__=="__main__":
    raise SystemExit(main(sys.argv[1]))
