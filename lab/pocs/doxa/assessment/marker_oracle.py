"""Independent colour-marker oracle for disposable Vision assessment fixtures.

Reads PNG + SHA256 manifest from frame_recorder, NOT Vision logs.
Does not infer zoom or caret; these require distinct independent measurement.
"""
import argparse
import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

PALETTES = {
    "LEFT": [(248, 214, 32), (243, 201, 51), (238, 188, 72), (232, 175, 91)],
    "RIGHT": [(35, 190, 130), (50, 181, 143), (65, 172, 156), (80, 163, 169)],
}
THRESHOLD_SQUARED = 32 * 32  # strict threshold to avoid matching ordinary application colours


def decode_png(png: bytes):
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("not PNG")
    pos = 8
    width = height = None
    compressed = bytearray()
    while pos + 12 <= len(png):
        n = struct.unpack_from("!I", png, pos)[0]
        tag = png[pos + 4:pos + 8]
        payload = png[pos + 8:pos + 8 + n]
        if len(payload) != n or pos + 12 + n > len(png):
            raise ValueError("truncated PNG chunk")
        expected = struct.unpack_from("!I", png, pos + 8 + n)[0]
        if zlib.crc32(tag + payload) & 0xffffffff != expected:
            raise ValueError("PNG chunk checksum mismatch")
        if tag == b"IHDR":
            width, height, bitdepth, typ, comp, filt, interlace = struct.unpack(
                "!2I5B", payload)
            if (bitdepth, typ, comp, filt, interlace) != (8, 2, 0, 0, 0):
                raise ValueError("unsupported PNG format; require fixture recorder RGB")
            if not 0 < width <= 960 or not 0 < height <= 540:
                raise ValueError("untrusted PNG dimensions")
        elif tag == b"IDAT":
            compressed.extend(payload)
        elif tag == b"IEND":
            break
        pos += 12 + n
    if width is None or height is None:
        raise ValueError("missing PNG dimensions")
    raw = zlib.decompress(bytes(compressed))
    stride = 3 * width + 1
    if len(raw) != height * stride:
        raise ValueError("unexpected PNG raster size")
    if any(raw[y * stride] != 0 for y in range(height)):
        raise ValueError("unsupported PNG filter")
    return width, height, raw


def classify_frame(data: bytes):
    width, height, raw = decode_png(data)
    stride = 3 * width + 1
    counts = {(source, i): 0 for source, shades in PALETTES.items()
              for i in range(len(shades))}
    # Interior grid leaves margins and large text/controls out.
    samples = 0
    for yi in range(4, 20):
        y = int(height * yi / 24)
        for xi in range(4, 20):
            x = int(width * xi / 24)
            at = y * stride + 1 + x * 3
            rgb = raw[at:at + 3]
            matches = []
            for source, shades in PALETTES.items():
                for i, shade in enumerate(shades):
                    dist = sum((int(rgb[j]) - shade[j]) ** 2 for j in range(3))
                    matches.append((dist, source, i))
            distance, source, i = min(matches)
            if distance < THRESHOLD_SQUARED:
                counts[(source, i)] += 1
            samples += 1
    left = sum(v for (source, i), v in counts.items() if source == "LEFT")
    right = sum(v for (source, i), v in counts.items() if source == "RIGHT")
    if max(left, right) < samples * 0.55 or abs(left - right) < samples * 0.4:
        return {"source": "UNOBSERVABLE", "shade": None,
                "coverage": round(max(left, right) / samples, 3)}
    source = "LEFT" if left > right else "RIGHT"
    shade = max(range(4), key=lambda i: counts[(source, i)])
    return {"source": source, "shade": shade,
            "coverage": round(max(left, right) / samples, 3)}


def analyse(manifest_path: Path) -> list[dict]:
    observations = []
    count = 0
    prior_pair = None
    for line in manifest_path.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        if item.get("channel") == "meta":
            if item.get("anchor_qpc_ns") is not None:
                observations.append({"channel": "meta", "t_ms": 0,
                                     "anchor_qpc_ns": item["anchor_qpc_ns"],
                                     "evidence_stream": "independent_gdi"})
            if item.get("blocked"):
                observations.append({"channel": "os", "t_ms": item["t_ms"], "locked": True,
                                     "role": "NONE"})
            continue
        if item.get("channel") != "panel_capture":
            continue
        if item.get("method") != "GDI_SOFTWARE_PIXELS_NOT_PHYSICAL_CAMERA":
            raise ValueError("untrusted frame method")
        file = (manifest_path.parent / item["file"]).resolve()
        if file.parent != manifest_path.parent.resolve():
            raise ValueError("frame path escape")
        png = file.read_bytes()
        digest = hashlib.sha256(png).hexdigest()
        if digest != item["sha256"]:
            raise ValueError("frame hash mismatch")
        result = classify_frame(png)
        pair = (result["source"], result["shade"])
        # A change counter is independent *visible state transitions*, not
        # renderer frames or the original app's intended text update count.
        if result["source"] != "UNOBSERVABLE" and pair != prior_pair:
            count += 1
            prior_pair = pair
        observations.append({"channel": "panel", "t_ms": item["t_ms"],
                             "source": result["source"], "counter": count
                             if result["source"] != "UNOBSERVABLE" else None,
                             "observed_by": "independent_image_analysis",
                             "capture_method": item["method"],
                             "frame_sha256": digest,
                             "coverage": result["coverage"],
                             "shade": result["shade"]})
    return observations


def main():
    ap = argparse.ArgumentParser(description="Read independent, local fixture colour-markers")
    ap.add_argument("manifest", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if args.output.exists():
        raise FileExistsError("Refuse to overwrite prior image annotations")
    records = analyse(args.manifest)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n"
                                   for r in records), encoding="utf-8")
    observed = sum(r.get("source") in {"LEFT", "RIGHT"} for r in records)
    print(json.dumps({"frames": len(records), "recognised": observed,
                      "status": "ANNOTATED_NOT_ASSESSED",
                      "note": "No physical camera, zoom or caret proof"}))
    return 0 if observed else 3


if __name__ == "__main__":
    sys.exit(main())

