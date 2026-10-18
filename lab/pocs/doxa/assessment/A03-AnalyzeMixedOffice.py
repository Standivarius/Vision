"""A03 independent Right/Detail mixed Word/Excel 4x assessment.

GDI pixels, Office-created stimulus evidence and OS process identity.
No Vision diagnostic field is used as the visual PASS oracle.
"""
import json
import statistics
import sys
from pathlib import Path
from importlib import util

script=Path(__file__).with_name("A02-AnalyzeColourLatencyFast.py")
spec=util.spec_from_file_location("mixed_shared_colours",str(script))
lib=util.module_from_spec(spec)
spec.loader.exec_module(lib)
scans=lib.scans
assess=lib.assess_phases


def evaluate(phases,source,capture):
    if ([r.get("app") for r in phases] !=
        ["WORD","EXCEL","WORD","EXCEL","WORD","EXCEL"]):
        return "FAIL_MIXED_APPLICATION_SEQUENCE"
    if any(r.get("expected_colour")!=("YELLOW" if i%2==0 else "GREEN")
           for i,r in enumerate(phases)):
        return "FAIL_MIXED_MARKER_SEQUENCE"
    if capture.get("display_count") not in (3,4):
        return "INCONCLUSIVE_TOPOLOGY"
    if source.get("status")!="PASS_SOURCE_MIXED_OFFICE" or len(phases)!=6:
        return "INCONCLUSIVE_SOURCE_OFFICE"
    if capture.get("mixed_script_exit")!=0:
        return "FAIL_SOURCE_SCRIPT_EXIT"
    if not source.get("focus_restored",False) or source.get("documents_saved") is not False:
        return "FAIL_SOURCE_CLEANUP"
    if capture.get("preview_shutdown")!="NORMAL":
        return "FAIL_PREVIEW_SHUTDOWN"
    if capture.get("right_frames",0)<50 or capture.get("centre_frames",0)<50:
        return "INCONCLUSIVE_CAPTURE"
    if any(not r.get("source_identity_valid",False) for r in phases):
        return "FAIL_SOURCE_PROVENANCE"
    status=assess(phases)
    return "PASS_MIXED_OFFICE_4X_SOURCE_AND_VISIBLE_OUTPUT" if status.startswith("PASS") else status


def main(path):
    run=Path(path)
    meta=json.loads((run/"result.json").read_text(encoding="utf-8-sig"))
    source=json.loads((Path(meta["source_report_path"])/"result.json").read_text(encoding="utf-8-sig"))
    screen=source["right_bounds"]
    # Exclude title bars and menus (both Office apps are positioned in Right).
    roi=(36,70,430,223)
    src=scans(run/"right",roi)
    dst=scans(run/"centre",(4,30,476,260))
    origin=meta["anchor_qpc_ns"]
    phases=[]
    for item in source["observations"]:
        step=int(item["step"])
        colour=item["colour"]
        app=item["app"]
        start=(item["phase_start_qpc_ns"]-origin)/1e6
        end=(item["phase_end_qpc_ns"]-origin)/1e6
        source_frames=[r for r in src if start-350<=r["t_ms"]<=end-200]
        output_frames=[r for r in dst if start-350<=r["t_ms"]<=end-200]
        source_visible=[r for r in source_frames if r[colour]>=(60 if app=="WORD" else 200)]
        output_visible=[r for r in output_frames if r[colour]>=(190 if app=="WORD" else 320)]
        sf=source_visible[0]["t_ms"] if source_visible else None
        df=output_visible[0]["t_ms"] if output_visible else None
        lag=round(df-sf,1) if sf is not None and df is not None else None
        bounds=item.get("uia_bounds") if app=="EXCEL" else item.get("word_caret")
        within=(bounds is not None and
            bounds["left"]>=screen["left"] and bounds["right"]<=screen["right"] and
            bounds["top"]>=screen["top"] and bounds["bottom"]<=screen["bottom"])
        native_ok=bool(item.get("foreground_matches") and
            item["foreground_pid"]==item["expected_pid"] and within)
        if app=="EXCEL":
            native_ok=native_ok and (
                item.get("uia_focus_pid")==source.get("excel_pid") and
                item.get("uia_focus_name")==item.get("target_cell") and
                item.get("com_cell")==item.get("target_cell"))
        phases.append({
            "step":step,"app":app,"expected_colour":colour,
            "source_identity_valid":native_ok,
            "source_frames":len(source_frames),"centre_frames":len(output_frames),
            "source_colour_visible":len(source_visible),
            "centre_colour_visible":len(output_visible),
            "latency_ms":lag,
            "source_median_colour_pixels":statistics.median([r[colour] for r in source_frames]) if source_frames else None,
            "centre_median_colour_pixels":statistics.median([r[colour] for r in output_frames]) if output_frames else None,
        })
    verdict=evaluate(phases,source,meta)
    result={"status":verdict,"phases":phases,"run":run.name,
            "source_frames_total":len(src),"centre_frames_total":len(dst),
            "max_observed_lag_ms":max((r["latency_ms"] for r in phases if r["latency_ms"] is not None),default=None),
            "evidence_scope":"software-visible GDI screenshots of generated unsaved Word/Excel content, not camera or real human typing"}
    target=run/"mixed-office-independent-verdict.json"
    if target.exists():
        raise FileExistsError("Refusing evidence overwrite")
    target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result))
    return 0 if verdict.startswith("PASS") else 3


if __name__=="__main__":
    raise SystemExit(main(sys.argv[1]))
