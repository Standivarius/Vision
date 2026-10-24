"""Read-only physical-console OS observer for Vision POC assessment.

Uses Win32 foreground + DWM window geometry independently of Vision.
No SendInput, cursor moving, unlocking, hooking or screen captures.
A running observer does not itself validate optical output.
"""
import argparse
import ctypes as C
import datetime as dt
import hashlib
import json
import os
import sys
import time
from ctypes import wintypes as W
from pathlib import Path

if sys.platform != "win32":
    raise SystemExit("Windows is required")
u = C.WinDLL("user32", use_last_error=True)
dwm = C.WinDLL("dwmapi")
kernel = C.WinDLL("kernel32", use_last_error=True)


class RECT(C.Structure):
    _fields_ = [("left", W.LONG), ("top", W.LONG), ("right", W.LONG), ("bottom", W.LONG)]

class POINT(C.Structure):
    _fields_ = [("x", W.LONG), ("y", W.LONG)]

class MONITORINFOEX(C.Structure):
    _fields_ = [("cbSize", W.DWORD), ("rcMonitor", RECT), ("rcWork", RECT),
                ("dwFlags", W.DWORD), ("szDevice", W.WCHAR * 32)]

class LASTINPUTINFO(C.Structure):
    _fields_ = [("cbSize", W.UINT), ("dwTime", W.DWORD)]


u.GetForegroundWindow.restype = W.HWND
u.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
u.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
u.GetClassNameW.restype = C.c_int
u.GetWindowRect.argtypes = [W.HWND, C.POINTER(RECT)]
u.GetWindowRect.restype = W.BOOL
u.GetMonitorInfoW.argtypes = [W.HMONITOR, C.POINTER(MONITORINFOEX)]
u.GetMonitorInfoW.restype = W.BOOL
u.GetCursorPos.argtypes = [C.POINTER(POINT)]
u.WindowFromPoint.argtypes = [POINT]
u.WindowFromPoint.restype = W.HWND
u.GetLastInputInfo.argtypes = [C.POINTER(LASTINPUTINFO)]
dwm.DwmGetWindowAttribute.argtypes = [W.HWND, W.DWORD, C.c_void_p, W.DWORD]
dwm.DwmGetWindowAttribute.restype = C.c_long
kernel.GetTickCount64.restype = C.c_ulonglong
kernel.QueryPerformanceFrequency.argtypes = [C.POINTER(C.c_longlong)]
C.WINFUNCTYPE  # assert callback available on native Windows

def rc(r):
    return {"left": r.left, "top": r.top, "right": r.right, "bottom": r.bottom}

def area(a, b):
    return max(0, min(a["right"], b["right"]) - max(a["left"], b["left"])) * max(
        0, min(a["bottom"], b["bottom"]) - max(a["top"], b["top"]))

def klass(hwnd):
    if not hwnd:
        return ""
    buf = C.create_unicode_buffer(160)
    u.GetClassNameW(hwnd, buf, len(buf))
    return buf.value

def monitors():
    found = []
    callback_type = C.WINFUNCTYPE(W.BOOL, W.HMONITOR, W.HDC, C.POINTER(RECT), W.LPARAM)
    def cb(hmon, hdc, r, data):
        m = MONITORINFOEX()
        m.cbSize = C.sizeof(m)
        if u.GetMonitorInfoW(hmon, C.byref(m)):
            found.append({"gdi_name": m.szDevice, "bounds": rc(m.rcMonitor),
                          "primary": bool(m.dwFlags & 1)})
        return True
    callback = callback_type(cb)
    u.EnumDisplayMonitors(None, None, callback, 0)
    return found

def roles(display):
    external = sorted((x for x in display if not x["primary"]), key=lambda x: x["bounds"]["left"])
    primary = [x for x in display if x["primary"]]
    if len(external) != 3 or len(primary) != 1:
        return {}
    return {"LEFT": external[0], "CENTRE": external[1],
            "RIGHT": external[2], "LAPTOP": primary[0]}

def physical_lock(lookup):
    # LockScreenInputOcclusionFrame was observed on current Dell. A necessary
    # but not sufficient unlock check; fail closed for unknown foreground.
    if not lookup:
        return None
    for entry in lookup.values():
        box = entry["bounds"]
        x = int((box["left"] + box["right"]) / 2)
        y = int((box["top"] + box["bottom"]) / 2)
        name = klass(u.WindowFromPoint(POINT(x, y)))
        if name == "LockScreenInputOcclusionFrame":
            return True
    return False

def one_sample(display_roles):
    hwnd = u.GetForegroundWindow()
    pid = W.DWORD(0)
    if hwnd:
        u.GetWindowThreadProcessId(hwnd, C.byref(pid))
    rect = RECT()
    actual_bounds = None
    if hwnd:
        d = dwm.DwmGetWindowAttribute(hwnd, 9, C.byref(rect), C.sizeof(rect))
        if d == 0:
            actual_bounds = rc(rect)
        elif u.GetWindowRect(hwnd, C.byref(rect)):
            actual_bounds = rc(rect)
    cloaked = W.DWORD(0)
    if hwnd:
        dwm.DwmGetWindowAttribute(hwnd, 14, C.byref(cloaked), C.sizeof(cloaked))
    lock = physical_lock(display_roles)
    scores = {k: area(actual_bounds, v["bounds"]) for k, v in display_roles.items()} if actual_bounds else {}
    total = sum(scores.values())
    ratios = {k: round(v / total, 4) for k, v in scores.items()} if total else {}
    winner = max(ratios, key=ratios.get) if ratios else "NONE"
    role = winner if ratios and ratios[winner] >= 0.95 and not cloaked.value else "AMBIGUOUS"
    if lock or not hwnd:
        role = "NONE"
    idle = LASTINPUTINFO()
    idle.cbSize = C.sizeof(idle)
    idle_ms = None
    if u.GetLastInputInfo(C.byref(idle)):
        idle_ms = (kernel.GetTickCount64() - idle.dwTime) & 0xffffffff
    return {"channel": "os", "hwnd": int(hwnd or 0), "pid": pid.value,
            "window_class": klass(hwnd), "window_bounds": actual_bounds,
            "cloaked": bool(cloaked.value), "role": role, "intersection_ratios": ratios,
            "locked": lock, "idle_ms": idle_ms}

def main():
    ap = argparse.ArgumentParser(description="Read-only Vision Windows foreground evidence")
    ap.add_argument("--preflight", action="store_true")
    ap.add_argument("--output", type=Path)
    ap.add_argument("--seconds", type=float, default=120)
    ap.add_argument("--hz", type=float, default=10)
    ap.add_argument("--anchor-qpc-ns", type=int, default=None,
                    help="Shared perf_counter_ns origin for other evidence collectors")
    args = ap.parse_args()
    if not args.preflight and not args.output:
        ap.error("--output required except in --preflight")
    if args.seconds <= 0 or args.seconds > 1800 or not 1 <= args.hz <= 20:
        ap.error("duration must be (0,1800] seconds; rate 1..20 Hz")
    try:
        u.SetProcessDpiAwarenessContext(C.c_void_p(-4))
    except (AttributeError, OSError):
        pass
    displays = monitors()
    mapping = roles(displays)
    qpc = C.c_longlong()
    kernel.QueryPerformanceFrequency(C.byref(qpc))
    fingerprint = hashlib.sha256(json.dumps(
        [{"role": k, "bounds": v["bounds"]} for k, v in sorted(mapping.items())],
        sort_keys=True).encode()).hexdigest()[:16]
    meta = {"channel": "meta", "t_ms": 0, "utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "topology_ok": bool(mapping), "topology_geometry_fingerprint": fingerprint,
            "display_count": len(displays), "monitors": displays, "qpc_frequency": qpc.value,
            "note": "GDI identifiers are volatile; software observation, not a camera",
            "anchor_qpc_ns": args.anchor_qpc_ns}
    status = one_sample(mapping)
    if args.preflight:
        print(json.dumps({"meta": meta, "foreground": status}, indent=2))
        return 4 if status["locked"] else 3 if not mapping or status["locked"] is None else 0
    if args.output.exists():
        raise FileExistsError("Refusing to overwrite evidence file")
    if not mapping or status["locked"] is not False:
        print(json.dumps({"status": "BLOCKED", "reason": "LOCKED_OR_UNQUALIFIED_TOPOLOGY"}))
        return 4
    args.output.parent.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter_ns()
    origin = args.anchor_qpc_ns if args.anchor_qpc_ns is not None else start
    final = start + int(args.seconds * 1e9)
    period = int(1e9 / args.hz)
    next_tick = start
    count = 0
    with args.output.open("x", encoding="utf-8") as out:
        out.write(json.dumps(meta) + "\n")
        while time.perf_counter_ns() < final:
            now = time.perf_counter_ns()
            row = one_sample(mapping)
            row["t_ms"] = round((now - origin) / 1e6, 3)
            if count % max(1, round(args.hz * 30)) == 0:
                row["utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
            out.write(json.dumps(row, separators=(",", ":")) + "\n")
            count += 1
            if row["locked"] is not False:
                out.flush()
                print(json.dumps({"status": "BLOCKED", "reason": "LOCK_SCREEN", "samples": count}))
                return 4
            next_tick += period
            time.sleep(max(0, (next_tick - time.perf_counter_ns()) / 1e9))
    print(json.dumps({"status": "CAPTURE_ONLY", "samples": count,
                      "note": "No visual evidence, no verdict; external panel evidence required",
                      "output": str(args.output)}))
    return 0

if __name__ == "__main__":
    sys.exit(main())

