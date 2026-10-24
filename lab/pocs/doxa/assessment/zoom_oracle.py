"""Independent software-pixel zoom estimate using disposable 128px source ruler.

The source fixture renders 14px black vertical lines every 128 native source
pixels. A separate GDI recorder downsamples the full 1920-wide destination
into 640px. A 2x view therefore yields 85.333px ruler spacing in the PNG.

Neither Vision telemetry nor the requested zoom value is used in estimation.
This does not measure light emitted by the physical Doxa panel.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import statistics
from pathlib import Path

from marker_oracle import analyse, decode_png


SCANLINES = (0.32, 0.48, 0.62, 0.75, 0.86)


def black_bands(raw: bytes, width: int, height: int, fraction: float):
    y = min(height - 1, int(height * fraction))
    off = y * (width * 3 + 1) + 1
    bands = []
    start = None
    for i in range(width + 1):
        dark = False
        if i < width:
            rgb = raw[off + i * 3:off + i * 3 + 3]
            dark = max(rgb) < 68
        if dark and start is None:
            start = i
        if not dark and start is not None:
            if 3 <= i - start <= 27 and start >= 3 and i < width - 3:
                bands.append((start + i - 1) / 2)
            start = None
    return bands


def measure_zoom(png: bytes, destination_width: int,
                 source_ruler_spacing: int = 128):
    if destination_width <= 0 or source_ruler_spacing <= 0:
        raise ValueError("invalid calibration dimensions")
    width, height, raw = decode_png(png)
    candidates = []
    band_counts = []
    for frac in SCANLINES:
        marks = black_bands(raw, width, height, frac)
        if len(marks) < 3:
            continue
        steps = [b - a for a, b in zip(marks, marks[1:])]
        typical = statistics.median(steps)
        if typical < 8:
            continue
        if not all(abs(step - typical) <= max(3, typical * 0.12)
                   for step in steps):
            continue
        candidates.append(typical)
        band_counts.append(len(marks))
    if len(candidates) < 3:
        return {"scale": None, "reason": "ruler marks not independently observable",
                "accepted_scanlines": len(candidates)}
    typical = statistics.median(candidates)
    if any(abs(v - typical) > max(3, typical * 0.12) for v in candidates):
        return {"scale": None, "reason": "inconsistent ruler spacing",
                "accepted_scanlines": len(candidates)}
    # PNG is a full-destination-width software capture.
    # Device pixels per source ruler interval = detected_png_pitch*dest_width/png_width.
    zoom = typical * destination_width / (width * source_ruler_spacing)
    return {"scale": round(zoom, 4), "ruler_pitch_png_px": round(typical, 3),
            "observed_bands": min(band_counts),
            "accepted_scanlines": len(candidates),
            "observed_by": "independent_gdi_ruler_analysis",
            "calibration": {
                "source_ruler_pitch_native_px": source_ruler_spacing,
                "destination_screen_width_native_px": destination_width,
                "png_full_screen_width_px": width,
            }}


def annotate(manifest_path: Path, destination_width: int,
             source_ruler_spacing: int = 128):
    source = manifest_path.resolve()
    rows = [json.loads(line) for line in source.read_text(encoding="utf-8-sig").splitlines()
            if line.strip()]
    captures = [r for r in rows if r.get("channel") == "panel_capture"]
    annotations = analyse(source)  # independent source-colour oracle, verifies SHA
    panels = [r for r in annotations if r.get("channel") == "panel"]
    if len(panels) != len(captures):
        raise ValueError("frame-to-panel annotation alignment failed")
    for captured, panel in zip(captures, panels):
        frame = (source.parent / captured["file"]).resolve()
        if frame.parent != source.parent:
            raise ValueError("frame path escape")
        png = frame.read_bytes()
        if hashlib.sha256(png).hexdigest() != captured["sha256"]:
            raise ValueError("ruler source file checksum mismatch")
        metric = measure_zoom(png, destination_width, source_ruler_spacing)
        if metric["scale"] is not None:
            panel["scale"] = metric["scale"]
        else:
            panel["scale"] = None
        panel["zoom_oracle"] = metric
    return annotations


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--destination-screen-width", type=int, required=True)
    ap.add_argument("--source-ruler-spacing", type=int, default=128)
    args = ap.parse_args()
    if args.output.exists():
        raise FileExistsError("Refuse to overwrite existing panel evidence")
    rows = annotate(args.manifest, args.destination_screen_width,
                    args.source_ruler_spacing)
    panels = [r for r in rows if r["channel"] == "panel"]
    valid = [r for r in panels if isinstance(r.get("scale"), (int, float))]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n"
                                   for r in rows), encoding="utf-8")
    scales = [r["scale"] for r in valid]
    result = {"status": "INDEPENDENT_SOFTWARE_ZOOM_ANNOTATED_NOT_PHYSICAL",
              "frames": len(panels), "valid_zoom_frames": len(valid),
              "median_zoom": statistics.median(scales) if scales else None,
              "range": [min(scales), max(scales)] if scales else [],
              "output": str(args.output)}
    print(json.dumps(result))
    return 0 if len(valid) >= 2 else 3


if __name__ == "__main__":
    raise SystemExit(main())

