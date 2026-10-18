"""Fast single-pass, two-colour GDI Word marker latency inspection.

No program telemetry is permitted to establish visible marker presence.
Each image is decoded once. Report statuses are scoped to marker evidence.
"""
import json,sys,statistics,hashlib
from pathlib import Path
from marker_oracle import decode_png


def scans(folder, roi):
    folder=Path(folder)
    x0,y0,x1,y1=(int(n) for n in roi)
    results=[]
    for line in (folder/"frame_manifest.jsonl").read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():continue
        row=json.loads(line)
        if row.get("channel")!="panel_capture":continue
        name=row["file"]
        if Path(name).name!=name:
            raise ValueError("frame manifest path escape")
        if row.get("monitor_role")!=folder.name.upper():
            raise ValueError("frame manifest monitor role mismatch")
        payload=(folder/name).read_bytes()
        if row.get("sha256")!=hashlib.sha256(payload).hexdigest():
            raise ValueError("independent frame SHA-256 mismatch")
        width,height,raw=decode_png(payload)
        lx=max(0,x0);rx=min(width,x1);ty=max(0,y0);by=min(height,y1)
        yellow=green=0
        for y in range(ty,by):
            start=y*(width*3+1)+1
            for x in range(lx,rx):
                i=start+3*x
                r,g,b=raw[i],raw[i+1],raw[i+2]
                yellow+=(r>218 and g>180 and b<112)
                green+=(g>171 and r<160 and b<160)
        results.append({"t_ms":row["t_ms"],"YELLOW":yellow,"GREEN":green})
    return results


def assess_phases(phases, maximum_latency_ms=2000):
    """Conservative, testable visible-output acceptance with provenance gates."""
    if not phases:
        return "INCONCLUSIVE"
    if any(p["source_frames"] < 3 or p["centre_frames"] < 3 for p in phases):
        return "INCONCLUSIVE"
    if any(p["source_colour_visible"] >= 2 and p["centre_colour_visible"] == 0
           for p in phases):
        return "FAIL_MISSING_MARKERS"
    if any(p["source_colour_visible"] < 2 or p["centre_colour_visible"] < 2
           for p in phases):
        return "INCONCLUSIVE"
    lags=[p["latency_ms"] for p in phases]
    if any(lag is None for lag in lags):
        return "INCONCLUSIVE"
    # Independent 2fps clocks may differ by one capture interval. A larger
    # apparent negative latency indicates bad alignment rather than a PASS.
    if any(lag < -600 for lag in lags):
        return "INCONCLUSIVE_TIMESTAMP_ALIGNMENT"
    if any(lag > maximum_latency_ms for lag in lags):
        return "FAIL_VISIBLE_LATENCY_OVER_2S"
    return "PASS_MARKERS_WITHIN_2S"


def main(base):
    run=Path(base)
    meta=json.loads((run/"result.json").read_text(encoding="utf-8-sig"))
    word=json.loads((Path(meta["source_report_path"])/"result.json").read_text(encoding="utf-8-sig"))
    origin=meta["anchor_qpc_ns"]
    screen=word["physical_left_bounds"];bounds=word["word_window_bounds"]
    left_roi=(
       (bounds["left"]+110-screen["left"])*480/1920,
       (bounds["top"]+170-screen["top"])*270/1080,
       (bounds["right"]-100-screen["left"])*480/1920,
       (bounds["bottom"]-110-screen["top"])*270/1080,
    )
    left=scans(run/"left",left_roi)
    centre=scans(run/"centre",(4,30,476,260))
    phases=[]
    for obs in word["observations"]:
        step=int(obs["step"])
        colour="YELLOW" if step%2==0 else "GREEN"
        start=(obs["phase_start_qpc_ns"]-origin)/1e6
        end=(obs["phase_qpc_ns"]-origin)/1e6
        source=[r for r in left if start-400<=r["t_ms"]<=end-150]
        target=[r for r in centre if start-400<=r["t_ms"]<=end-150]
        sourceSeen=[r for r in source if r[colour]>=55]
        targetSeen=[r for r in target if r[colour]>=200]
        firstS=sourceSeen[0]["t_ms"] if sourceSeen else None
        firstC=targetSeen[0]["t_ms"] if targetSeen else None
        latency=firstC-firstS if firstS is not None and firstC is not None else None
        phases.append({
            "step":step,"expected_colour":colour,
            "source_frames":len(source),"centre_frames":len(target),
            "source_colour_visible":len(sourceSeen),"centre_colour_visible":len(targetSeen),
            "median_source_colour_pixels":statistics.median([r[colour] for r in source]) if source else None,
            "median_centre_colour_pixels":statistics.median([r[colour] for r in target]) if target else None,
            "source_first_ms":round(firstS,1) if firstS is not None else None,
            "centre_first_ms":round(firstC,1) if firstC is not None else None,
            "latency_ms":round(latency,1) if latency is not None else None,
        })
    verdict=assess_phases(phases)
    output={"status":verdict,"phases":phases,"max_observed_lag_ms":max((p["latency_ms"] for p in phases if p["latency_ms"] is not None),default=None),
            "note":"Two colour Word highlight source-vs-Centre software pixels, 2fps resolution; not camera/optical truth."}
    dest=run/"alternating-highlight-latency-fast.json"
    if dest.exists():raise FileExistsError(dest)
    dest.write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(output))
    return 0 if verdict.startswith("PASS") else 2


if __name__=="__main__":
    raise SystemExit(main(sys.argv[1]))
