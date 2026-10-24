"""Estimate software-visible magnification from known 128px vertical ruler marks.

Requires separately captured disposable source fixture with black 14px bars
repeated every 128 source pixels. This is NOT proof of physical photons.
Never use Vision's zoom telemetry for the measurement.
"""
from pathlib import Path
import sys
from marker_oracle import decode_png


def black_runs(path: Path, y_pct: float) -> list[tuple[int, int]]:
    w, h, raster = decode_png(path.read_bytes())
    y = min(h - 1, int(h * y_pct))
    off = y * (w * 3 + 1) + 1
    black = []
    for x in range(w):
        rgb = raster[off + x * 3:off + x * 3 + 3]
        # Reject coloured background independent of which tint is visible.
        black.append(max(rgb) < 68)
    groups = []
    start = None
    for i, b in enumerate(black + [False]):
        if b and start is None:
            start = i
        if not b and start is not None:
            if i - start >= 3:
                groups.append((start, i - 1))
            start = None
    return groups


def main():
    folder = Path(sys.argv[1])
    frames = sorted(folder.glob("frame-*.png"))
    if not frames:
        raise SystemExit("No PNGs")
    for frame in [frames[0], frames[len(frames) // 2], frames[-1]]:
        print("FRAME", frame.name)
        for pct in (0.32, 0.48, 0.62, 0.75, 0.86):
            runs = black_runs(frame, pct)
            mid = [(a + b) / 2 for a, b in runs]
            distances = [round(b - a, 1) for a, b in zip(mid, mid[1:])]
            print(f" y={pct}: {runs[:15]} | deltas {distances[:12]}")


if __name__ == "__main__":
    main()

