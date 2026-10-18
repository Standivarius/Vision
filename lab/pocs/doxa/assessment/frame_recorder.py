"""Optional independent GDI frame recorder for a guarded Vision Doxa POC trial.

GDI screen pixels != photons from the physical panel. No OCR/marker validation
is claimed. Never run over personal content or while Windows is locked.
Dependency-free, on-host, read-only capture. Reversible: creates files only.
"""
from __future__ import annotations
import argparse
import ctypes as C
import datetime as dt
import hashlib
import json
import struct
import sys
import time
import zlib
from pathlib import Path
from ctypes import wintypes as W
from win_observer import monitors, roles, physical_lock

g = C.WinDLL("gdi32", use_last_error=True)
u = C.WinDLL("user32", use_last_error=True)
HBITMAP = W.HANDLE


class BITMAPINFOHEADER(C.Structure):
    _fields_ = [("biSize", W.DWORD), ("biWidth", W.LONG), ("biHeight", W.LONG),
                ("biPlanes", W.WORD), ("biBitCount", W.WORD),
                ("biCompression", W.DWORD), ("biSizeImage", W.DWORD),
                ("biXPelsPerMeter", W.LONG), ("biYPelsPerMeter", W.LONG),
                ("biClrUsed", W.DWORD), ("biClrImportant", W.DWORD)]

class BITMAPINFO(C.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", W.DWORD * 3)]

u.GetDC.argtypes = [W.HWND]
u.GetDC.restype = W.HDC
u.ReleaseDC.argtypes = [W.HWND, W.HDC]
g.CreateCompatibleDC.argtypes = [W.HDC]
g.CreateCompatibleDC.restype = W.HDC
g.CreateDIBSection.argtypes = [W.HDC, C.POINTER(BITMAPINFO), W.UINT,
                              C.POINTER(C.c_void_p), W.HANDLE, W.DWORD]
g.CreateDIBSection.restype = HBITMAP
g.SelectObject.argtypes = [W.HDC, W.HANDLE]
g.SelectObject.restype = W.HANDLE
g.StretchBlt.argtypes = [W.HDC, C.c_int, C.c_int, C.c_int, C.c_int, W.HDC,
                        C.c_int, C.c_int, C.c_int, C.c_int, W.DWORD]
g.StretchBlt.restype = W.BOOL
g.SetStretchBltMode.argtypes = [W.HDC, C.c_int]
g.DeleteObject.argtypes = [W.HANDLE]
g.DeleteDC.argtypes = [W.HDC]


def chunk(tag, body):
    return (struct.pack("!I", len(body)) + tag + body +
            struct.pack("!I", zlib.crc32(tag + body) & 0xffffffff))


def png_from_bgra(src: bytes, width: int, height: int) -> bytes:
    """Encode top-down BGRA to RGB PNG without external libraries."""
    stride = width * 4
    compressor = zlib.compressobj(level=4)
    out = bytearray()
    for y in range(height):
        row = src[y * stride:(y + 1) * stride]
        rgb = bytearray(width * 3)
        for x in range(width):
            at = x * 4
            dest = x * 3
            rgb[dest:dest + 3] = bytes((row[at + 2], row[at + 1], row[at]))
        out.extend(compressor.compress(b"\0" + rgb))
    out.extend(compressor.flush())
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, height,
            8, 2, 0, 0, 0)) + chunk(b"IDAT", bytes(out)) + chunk(b"IEND", b""))


class Grabber:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.screen = u.GetDC(None)
        self.memory = g.CreateCompatibleDC(self.screen)
        self.bitmap = None
        self.old = None
        if not self.screen or not self.memory:
            raise RuntimeError("cannot create GDI DC")
        bi = BITMAPINFO()
        bi.bmiHeader.biSize = C.sizeof(BITMAPINFOHEADER)
        bi.bmiHeader.biWidth = width
        bi.bmiHeader.biHeight = -height  # top-down
        bi.bmiHeader.biPlanes = 1
        bi.bmiHeader.biBitCount = 32
        bi.bmiHeader.biCompression = 0
        self.bits = C.c_void_p()
        self.bitmap = g.CreateDIBSection(self.screen, C.byref(bi), 0,
                                         C.byref(self.bits), None, 0)
        if not self.bitmap or not self.bits.value:
            raise RuntimeError("cannot create DIB section")
        self.old = g.SelectObject(self.memory, self.bitmap)
        g.SetStretchBltMode(self.memory, 3)  # COLORONCOLOR, avoid costly smoothing

    def read_png(self, bounds):
        if not g.StretchBlt(self.memory, 0, 0, self.width, self.height,
                            self.screen, bounds["left"], bounds["top"],
                            bounds["right"] - bounds["left"],
                            bounds["bottom"] - bounds["top"], 0x00CC0020):
            raise RuntimeError("GDI capture failed")
        return png_from_bgra(C.string_at(self.bits, self.width * self.height * 4),
                             self.width, self.height)

    def close(self):
        if self.old:
            g.SelectObject(self.memory, self.old)
        if self.bitmap:
            g.DeleteObject(self.bitmap)
        if self.memory:
            g.DeleteDC(self.memory)
        if self.screen:
            u.ReleaseDC(None, self.screen)


def main():
    ap = argparse.ArgumentParser(description="Guarded read-only GDI frame evidence; not optical proof")
    ap.add_argument("--output-dir", type=Path, required=True)
    ap.add_argument("--role", choices=["LEFT", "CENTRE", "RIGHT", "LAPTOP"], default="CENTRE")
    ap.add_argument("--seconds", type=float, default=120)
    ap.add_argument("--fps", type=float, default=2)
    ap.add_argument("--width", type=int, default=640)
    ap.add_argument("--height", type=int, default=360)
    ap.add_argument("--anchor-qpc-ns", type=int)
    ap.add_argument("--confirm-disposable-content", action="store_true",
                    help="Required; never capture private documents without explicit permission")
    args = ap.parse_args()
    if not args.confirm_disposable_content:
        ap.error("capture requires --confirm-disposable-content")
    if not 0 < args.seconds <= 180 or not 0 < args.fps <= 5:
        ap.error("limit runs to <=180s and <=5fps")
    if not 128 <= args.width <= 960 or not 72 <= args.height <= 540:
        ap.error("unsupported frame dimensions")
    try:
        u.SetProcessDpiAwarenessContext(C.c_void_p(-4))
    except (AttributeError, OSError):
        pass
    role_map = roles(monitors())
    if args.role not in role_map or physical_lock(role_map) is not False:
        print(json.dumps({"status": "BLOCKED",
                          "reason": "NOT_FOUR_PHYSICAL_DISPLAYS_OR_LOCKED"}))
        return 4
    if args.output_dir.exists():
        raise FileExistsError("Refusing existing capture directory")
    args.output_dir.mkdir(parents=True)
    recorder = Grabber(args.width, args.height)
    start = time.perf_counter_ns()
    origin = args.anchor_qpc_ns if args.anchor_qpc_ns is not None else start
    deadline = start + int(args.seconds * 1e9)
    next_at = start
    n = 0
    manifest = args.output_dir / "frame_manifest.jsonl"
    try:
        with manifest.open("x", encoding="utf-8") as fh:
            fh.write(json.dumps({"channel": "meta", "t_ms": 0,
                                 "anchor_qpc_ns": origin,
                                 "capture_method": "GDI_SOFTWARE_PIXELS_NOT_PHYSICAL_CAMERA",
                                 "role": args.role, "width": args.width,
                                 "height": args.height}) + "\n")
            while time.perf_counter_ns() < deadline:
                if physical_lock(role_map) is not False or roles(monitors()).get(
                        args.role, {}).get("bounds") != role_map[args.role]["bounds"]:
                    fh.write(json.dumps({"channel": "meta", "t_ms": (time.perf_counter_ns()-origin)/1e6,
                                         "blocked": True, "reason": "LOCK_OR_TOPOLOGY_CHANGE"}) + "\n")
                    return 4
                now = time.perf_counter_ns()
                frame = recorder.read_png(role_map[args.role]["bounds"])
                name = f"frame-{n:05d}.png"
                (args.output_dir / name).write_bytes(frame)
                fh.write(json.dumps({"channel": "panel_capture",
                                     "t_ms": round((now - origin) / 1e6, 3),
                                     "method": "GDI_SOFTWARE_PIXELS_NOT_PHYSICAL_CAMERA",
                                     "monitor_role": args.role, "file": name,
                                     "sha256": hashlib.sha256(frame).hexdigest(),
                                     "utc": dt.datetime.now(dt.timezone.utc).isoformat()}) + "\n")
                n += 1
                next_at += int(1e9 / args.fps)
                time.sleep(max(0, (next_at - time.perf_counter_ns()) / 1e9))
    finally:
        recorder.close()
    print(json.dumps({"status": "FRAMES_CAPTURED_NOT_VERDICT", "frames": n,
                      "output": str(args.output_dir)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

