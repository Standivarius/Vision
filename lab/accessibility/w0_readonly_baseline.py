"""Vision W0: read-only physical Dell four-screen comparison preflight.

No window launch, monitor/driver setting writes, audio playback, UI screenshots,
network calls, remote desktop attachment or installer invocation.
"""
from __future__ import annotations

import csv
import ctypes as c
from ctypes import wintypes as w
import hashlib
import io
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone

MAGNIFIER_EXES = {
    "magnify.exe", "nvda.exe", "zoomtext.exe", "zt.exe",
    "supernova.exe", "visual_app.exe",
}
NON_MAGNIFIER_CONTROL = {"ztuac.exe"}
GET_DEVICE_INTERFACE_NAME = 1

class DisplayDevice(c.Structure):
    _fields_ = [("cb", w.DWORD), ("DeviceName", w.WCHAR * 32),
                ("DeviceString", w.WCHAR * 128), ("StateFlags", w.DWORD),
                ("DeviceID", w.WCHAR * 128), ("DeviceKey", w.WCHAR * 128)]


def enum_display_devices(parent: str | None, index: int, flags: int = 0):
    user32 = c.WinDLL("user32", use_last_error=True)
    fn = user32.EnumDisplayDevicesW
    fn.argtypes = [w.LPCWSTR, w.DWORD, c.POINTER(DisplayDevice), w.DWORD]
    fn.restype = w.BOOL
    item = DisplayDevice()
    item.cb = c.sizeof(item)
    if not fn(parent, index, c.byref(item), flags):
        return None
    return item


def enumerate_active_displays():
    displays = []
    for index in range(32):
        a = enum_display_devices(None, index)
        if a is None:
            break
        if not a.StateFlags & 1:
            continue
        m = enum_display_devices(a.DeviceName, 0, GET_DEVICE_INTERFACE_NAME)
        identifier = (m.DeviceID if m else "") or ""
        displays.append({
            "gdi_name": a.DeviceName,
            "adapter_friendly_name": a.DeviceString,
            "physical_id_hash": hashlib.sha256(identifier.upper().encode()).hexdigest()[:20] if identifier else None,
            "has_physical_interface": bool(identifier),
            "primary": bool(a.StateFlags & 4),
        })
    return displays


def process_exes():
    result = subprocess.run(["tasklist", "/fo", "csv", "/nh"], capture_output=True,
                            text=True, timeout=12, check=True)
    return sorted({row[0].strip().lower() for row in csv.reader(io.StringIO(result.stdout)) if row})


def verdict(monitors: list, physical_console: bool, active_magnifiers: list):
    if not physical_console:
        return "BLOCKED_NOT_PHYSICAL_CONSOLE"
    if len(monitors) != 4:
        return "BLOCKED_FOUR_MONITORS_NOT_PRESENT"
    if len(active_magnifiers) > 1:
        return "BLOCKED_CONFLICTING_MAGNIFIERS"
    external = [x["physical_id_hash"] for x in monitors if not x["primary"]]
    if len(external) != 3 or None in external or len(set(external)) != 3:
        return "IDENTITY_AMBIGUOUS"
    return "PASS_READ_ONLY_PREP"


def observe():
    kernel = c.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcessId.restype = w.DWORD
    kernel.WTSGetActiveConsoleSessionId.restype = w.DWORD
    kernel.ProcessIdToSessionId.argtypes = [w.DWORD, c.POINTER(w.DWORD)]
    kernel.ProcessIdToSessionId.restype = w.BOOL
    session = w.DWORD()
    valid = bool(kernel.ProcessIdToSessionId(kernel.GetCurrentProcessId(), c.byref(session)))
    console_session = kernel.WTSGetActiveConsoleSessionId()
    physical = valid and session.value == console_session
    try:
        user32 = c.WinDLL("user32", use_last_error=True)
        user32.SetProcessDpiAwarenessContext.argtypes = [c.c_void_p]
        user32.SetProcessDpiAwarenessContext(c.c_void_p(-4))
    except OSError:
        pass
    displays = enumerate_active_displays()
    exes = process_exes()
    active = sorted(set(exes) & MAGNIFIER_EXES)
    return {
        "schema_version": 1,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "machine_expected": "MARIUS-DELL",
        "os_version": platform.version(),
        "physical_console": physical,
        "display_count": len(displays),
        "displays": displays,
        "active_magnifier_processes": active,
        "present_nonmagnifier_helpers": sorted(set(exes) & NON_MAGNIFIER_CONTROL),
        "audio_muted": "NOT_CHECKED_NO_AUDIO_PLAYED",
        "visual_quality": "NOT_TESTED_HUMAN_REQUIRED",
        "changes_to_windows": False,
        "changes_to_driver": False,
        "verdict": verdict(displays, physical, active),
    }


if __name__ == "__main__":
    if os.name != "nt":
        print("W0_REQUIRES_WINDOWS", file=sys.stderr)
        raise SystemExit(2)
    try:
        data = observe()
        print(json.dumps(data, indent=2))
        raise SystemExit(0 if data["verdict"] == "PASS_READ_ONLY_PREP" else 4)
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        print("W0_PREFLIGHT_ERROR:" + type(exc).__name__, file=sys.stderr)
        raise SystemExit(3)
