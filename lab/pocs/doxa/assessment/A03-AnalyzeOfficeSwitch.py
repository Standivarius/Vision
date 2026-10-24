"""Independent A03 Word->Excel foreground and 4x viewport switch oracle.

Never use Vision telemetry as PASS authority; test-owned Office COM/UIA/Win32
source truth plus separately recorded GDI source and Centre PNGs.
"""
import json
import statistics
import sys
from pathlib import Path
from importlib import util

shared=Path(__file__).with_name("A02-AnalyzeColourLatencyFast.py")
spec=util.spec_from_file_location("a03_colour_scanner",shared)
lib=util.module_from_spec(spec)
spec.loader.exec_module(lib)
scans=lib.scans
score_visible=lib.assess_phases


def assess_office_switch(phases, stimulus, capture):
    expected_apps=["WORD","EXCEL","WORD","EXCEL","WORD","EXCEL"]
    if capture.get("display_count") not in (3,4):
        return "INCONCLUSIVE_TOPOLOGY"
    if len(phases)!=6 or [p.get("app") for p in phases]!=expected_apps:
        return "INCONCLUSIVE_SWITCH_SEQUENCE"
    if stimulus.get("status")!="PASS_SOURCE_SWITCH_TRUTH":
        return "INCONCLUSIVE_SOURCE_TRUTH"
    if capture.get("office_script_exit")!=0 or stimulus.get("focus_restored") is not True or stimulus.get("pointer_restored") is not True:
        return "FAIL_CLEANUP_OR_SOURCE_EXIT"
    if capture.get("preview_shutdown")!="NORMAL":
        return "FAIL_PREVIEW_SHUTDOWN"
    if capture.get("right_frames",0)<60 or capture.get("centre_frames",0)<60:
        return "INCONCLUSIVE_CAPTURE"
    if any(not phase.get("source_identity_valid") for phase in phases):
        return "FAIL_WRONG_FOREGROUND_OR_CARET"
    visual=score_visible(phases)
    return "PASS_OFFICE_SWITCH_4X_VISIBLE_WITHIN_2S" if visual.startswith("PASS") else visual


def main(folder):
    run=Path(folder)
    capture=json.loads((run/"result.json").read_text(encoding="utf-8-sig"))
    stimulus=json.loads((Path(capture["source_report_path"])/"result.json").read_text(encoding="utf-8-sig"))
    screen=stimulus.get("right_bounds") or {}
    if not screen:
        print(json.dumps({"status":"INCONCLUSIVE_NO_SOURCE_MONITOR"}))
        return 2
    # Local source monitor body; excludes shell/Office chrome.
    roi=(36,70,430,223)
    src=scans(run/"right",roi)
    dst=scans(run/"centre",(4,30,476,260))
    anchor=capture["anchor_qpc_ns"]
    phases=[]
    for row in stimulus.get("observations",[]):
        index=int(row["step"])
        colour=row["colour"]
        start=(row["phase_start_qpc_ns"]-anchor)/1e6
        end=(row["phase_end_qpc_ns"]-anchor)/1e6
        source=[r for r in src if start-300<=r["t_ms"]<=end-150]
        output=[r for r in dst if start-300<=r["t_ms"]<=end-150]
        minimum_src=55 if colour=="YELLOW" else 185
        minimum_dst=210 if colour=="YELLOW" else 260
        sourceHits=[r for r in source if r[colour]>=minimum_src]
        destHits=[r for r in output if r[colour]>=minimum_dst]
        first_src=sourceHits[0]["t_ms"] if sourceHits else None
        first_dst=destHits[0]["t_ms"] if destHits else None
        lag=first_dst-first_src if first_src is not None and first_dst is not None else None
        identity=bool(row.get("foreground_owned") and row.get("target_verified") and row.get("window_on_right"))
        phases.append({
          "step":index,"app":row["app"],"colour":colour,
          "source_identity_valid":identity,
          "source_frames":len(source),"centre_frames":len(output),
          "source_colour_visible":len(sourceHits),"centre_colour_visible":len(destHits),
          "latency_ms":round(lag,1) if lag is not None else None,
          "source_median_colour_pixels":statistics.median([r[colour] for r in source]) if source else 0,
          "centre_median_colour_pixels":statistics.median([r[colour] for r in output]) if output else 0,
        })
    verdict=assess_office_switch(phases,stimulus,capture)
    result={"status":verdict,"phases":phases,"source_frames":len(src),"centre_frames":len(dst),
            "max_observed_lag_ms":max((p["latency_ms"] for p in phases if p["latency_ms"] is not None),default=None),
            "scope":"2fps GDI software output only, no physical-camera/user acceptance"}
    output=run/"office-switch-independent-verdict.json"
    if output.exists():raise FileExistsError(output)
    output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result))
    return 0 if verdict.startswith("PASS") else 3


if __name__=="__main__":
    raise SystemExit(main(sys.argv[1]))
