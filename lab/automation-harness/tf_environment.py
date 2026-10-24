"""
Vision Test Farm Environment & Capability Probe (v0.1)

Probes the host environment, session, desktop, displays, privileges, git provenance,
and binary availability without mutating host state.
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import hashlib
import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

HARNESS_VERSION = "0.1.0"


def _sha256_file(path: Path) -> Optional[str]:
    if not path.is_file():
        return None
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None


def get_git_provenance(repo_root: Path) -> Dict[str, Any]:
    """Capture git HEAD, dirty status, and bounded change provenance."""
    result: Dict[str, Any] = {
        "head": None,
        "is_dirty": False,
        "modified_count": 0,
        "untracked_count": 0,
        "changed_paths_summary": [],
    }
    try:
        head_proc = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            check=False,
        )
        if head_proc.returncode == 0:
            result["head"] = head_proc.stdout.strip()

        status_proc = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            check=False,
        )
        if status_proc.returncode == 0:
            lines = [l for l in status_proc.stdout.splitlines() if l.strip()]
            result["is_dirty"] = len(lines) > 0
            changed_paths: List[str] = []
            mod_count = 0
            untracked_count = 0
            for line in lines:
                status = line[:2]
                path = line[3:].strip()
                if status.startswith("??"):
                    untracked_count += 1
                else:
                    mod_count += 1
                if len(changed_paths) < 50:
                    changed_paths.append(f"{status.strip()} {path}")
            result["modified_count"] = mod_count
            result["untracked_count"] = untracked_count
            result["changed_paths_summary"] = changed_paths
    except Exception as e:
        result["error"] = str(e)
    return result


def is_admin() -> bool:
    """Check if the current process is running with elevated administrator rights."""
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def get_session_info() -> Dict[str, Any]:
    """Determine Windows session ID and whether it matches the active console."""
    info: Dict[str, Any] = {
        "process_session_id": None,
        "active_console_session_id": None,
        "is_console_session": False,
    }
    try:
        proc_sess = ctypes.windll.kernel32.GetCurrentProcessId()
        # QueryProcessId to SessionId
        sess_id = wintypes.DWORD()
        if ctypes.windll.kernel32.ProcessIdToSessionId(proc_sess, ctypes.byref(sess_id)):
            info["process_session_id"] = sess_id.value
        console_sess = ctypes.windll.kernel32.WTSGetActiveConsoleSessionId()
        info["active_console_session_id"] = console_sess
        info["is_console_session"] = (
            info["process_session_id"] is not None and info["process_session_id"] == console_sess
        )
    except Exception as e:
        info["error"] = str(e)
    return info


def get_desktop_info() -> Dict[str, Any]:
    """Inspect current WindowStation and Desktop name."""
    info: Dict[str, Any] = {"window_station": None, "desktop": None}
    try:
        h_winsta = ctypes.windll.user32.GetProcessWindowStation()
        h_desk = ctypes.windll.user32.GetThreadDesktop(ctypes.windll.kernel32.GetCurrentThreadId())
        buf = ctypes.create_unicode_buffer(256)
        needed = wintypes.DWORD()
        if ctypes.windll.user32.GetUserObjectInformationW(h_winsta, 2, buf, 512, ctypes.byref(needed)):
            info["window_station"] = buf.value
        if ctypes.windll.user32.GetUserObjectInformationW(h_desk, 2, buf, 512, ctypes.byref(needed)):
            info["desktop"] = buf.value
    except Exception as e:
        info["error"] = str(e)
    return info


def get_display_topology() -> Dict[str, Any]:
    """Enumerate connected Windows displays using EnumDisplayMonitors."""
    displays: List[Dict[str, Any]] = []

    class RECT(ctypes.Structure):
        _fields_ = [
            ("left", wintypes.LONG),
            ("top", wintypes.LONG),
            ("right", wintypes.LONG),
            ("bottom", wintypes.LONG),
        ]

    class MONITORINFOEXW(ctypes.Structure):
        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("rcMonitor", RECT),
            ("rcWork", RECT),
            ("dwFlags", wintypes.DWORD),
            ("szDevice", wintypes.WCHAR * 32),
        ]

    MONITOR_ENUM_PROC = ctypes.WINFUNCTYPE(
        wintypes.BOOL,
        wintypes.HMONITOR,
        wintypes.HDC,
        ctypes.POINTER(RECT),
        wintypes.LPARAM,
    )

    def _monitor_enum_callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
        info = MONITORINFOEXW()
        info.cbSize = ctypes.sizeof(MONITORINFOEXW)
        if ctypes.windll.user32.GetMonitorInfoW(hMonitor, ctypes.byref(info)):
            is_primary = bool(info.dwFlags & 1)  # MONITORINFOF_PRIMARY
            r = info.rcMonitor
            displays.append({
                "device_name": info.szDevice,
                "is_primary": is_primary,
                "left": r.left,
                "top": r.top,
                "right": r.right,
                "bottom": r.bottom,
                "width": r.right - r.left,
                "height": r.bottom - r.top,
            })
        return True

    try:
        proc = MONITOR_ENUM_PROC(_monitor_enum_callback)
        ctypes.windll.user32.EnumDisplayMonitors(None, None, proc, 0)
    except Exception as e:
        # Fallback to WinForms display query if available
        pass

    # If EnumDisplayMonitors returned 0 (e.g. non-interactive desktop), fall back to PowerShell
    if not displays:
        try:
            ps_cmd = (
                "Add-Type -AssemblyName System.Windows.Forms; "
                "[System.Windows.Forms.Screen]::AllScreens | "
                "Select-Object DeviceName, Primary, "
                "@{N='left';E={$_.Bounds.X}}, @{N='top';E={$_.Bounds.Y}}, "
                "@{N='width';E={$_.Bounds.Width}}, @{N='height';E={$_.Bounds.Height}} | "
                "ConvertTo-Json"
            )
            p = subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps_cmd], capture_output=True, text=True, check=False)
            if p.returncode == 0 and p.stdout.strip():
                data = json.loads(p.stdout)
                if isinstance(data, dict):
                    data = [data]
                for s in data:
                    displays.append({
                        "device_name": s.get("DeviceName"),
                        "is_primary": s.get("Primary", False),
                        "left": s.get("left", 0),
                        "top": s.get("top", 0),
                        "right": s.get("left", 0) + s.get("width", 0),
                        "bottom": s.get("top", 0) + s.get("height", 0),
                        "width": s.get("width", 0),
                        "height": s.get("height", 0),
                    })
        except Exception:
            pass

    return {
        "display_count": len(displays),
        "displays": displays,
    }


def probe_vision_binaries(repo_root: Path) -> Dict[str, Any]:
    """Inspect Vision dev executable and installed alpha executable."""
    dev_exe = repo_root / "app" / "build" / "Release" / "visual_app.exe"
    installed_root = Path(os.environ.get("LOCALAPPDATA", "")) / "Standivarius.Visual"
    installed_exe = installed_root / "current" / "visual_app.exe"
    settings_file = Path(os.environ.get("LOCALAPPDATA", "")) / "Standivarius" / "Visual" / "settings.ini"

    return {
        "dev_executable": {
            "path": str(dev_exe),
            "exists": dev_exe.is_file(),
            "sha256": _sha256_file(dev_exe),
            "size_bytes": dev_exe.stat().st_size if dev_exe.is_file() else None,
        },
        "installed_executable": {
            "path": str(installed_exe),
            "exists": installed_exe.is_file(),
            "sha256": _sha256_file(installed_exe),
            "size_bytes": installed_exe.stat().st_size if installed_exe.is_file() else None,
        },
        "settings_file": {
            "path": str(settings_file),
            "exists": settings_file.is_file(),
            "sha256": _sha256_file(settings_file),
        },
    }


def find_tooling() -> Dict[str, Any]:
    """Locate build and test tools (CMake, CTest, PowerShell)."""
    tools: Dict[str, Any] = {
        "python": sys.executable,
        "python_version": platform.python_version(),
        "powershell": "powershell.exe",
        "ctest": None,
        "cmake": None,
    }
    # Check VS Build Tools CMake/CTest
    vswhere = Path("C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe")
    if vswhere.is_file():
        try:
            p = subprocess.run([str(vswhere), "-latest", "-products", "*", "-property", "installationPath"], capture_output=True, text=True, check=False)
            vs_root = p.stdout.strip()
            if vs_root:
                cmake_cand = Path(vs_root) / "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
                ctest_cand = Path(vs_root) / "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/ctest.exe"
                if cmake_cand.is_file():
                    tools["cmake"] = str(cmake_cand)
                if ctest_cand.is_file():
                    tools["ctest"] = str(ctest_cand)
        except Exception:
            pass
    return tools


def probe_environment(repo_root: Optional[Path] = None) -> Dict[str, Any]:
    """Produce the complete, structured environment probe dictionary."""
    if repo_root is None:
        repo_root = Path(__file__).resolve().parent.parent.parent

    session_info = get_session_info()
    desktop_info = get_desktop_info()
    topology = get_display_topology()
    git_info = get_git_provenance(repo_root)
    binaries = probe_vision_binaries(repo_root)
    tooling = find_tooling()

    return {
        "harness_version": HARNESS_VERSION,
        "os": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "node": platform.node(),
            "windows_build": platform.version(),
        },
        "session": session_info,
        "desktop": desktop_info,
        "elevation": {
            "is_admin": is_admin(),
        },
        "display_topology": topology,
        "git": git_info,
        "vision_binaries": binaries,
        "tooling": tooling,
    }


if __name__ == "__main__":
    env = probe_environment()
    print(json.dumps(env, indent=2))
