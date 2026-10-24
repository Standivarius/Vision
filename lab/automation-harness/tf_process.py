"""
Vision Test Farm Process Runner & Desktop Routing (v0.1)

Handles subprocess execution with timeouts, stdout/stderr capture,
process-tree termination, and Windows desktop routing (WinSta0\\Default).
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class ProcessExecutionResult:
    command: str
    exit_code: int
    timed_out: bool
    duration_sec: float
    stdout_path: Path
    stderr_path: Path
    stdout_preview: str = ""
    stderr_preview: str = ""


def kill_process_tree(pid: int) -> None:
    """Forcefully kill process and all descendants to guarantee zero orphans."""
    try:
        subprocess.run(
            ["taskkill.exe", "/PID", str(pid), "/T", "/F"],
            capture_output=True,
            check=False,
            timeout=5.0,
        )
    except Exception:
        pass


def stop_lingering_vision_processes(known_exes: Optional[List[str]] = None) -> None:
    """Terminate lingering visual_app processes."""
    try:
        ps_cmd = (
            "Get-Process visual_app -ErrorAction SilentlyContinue | "
            "ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }"
        )
        subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps_cmd], capture_output=True, check=False, timeout=5.0)
    except Exception:
        pass


def run_process_with_desktop(
    cmd: str,
    cwd: Optional[Path],
    stdout_file: Path,
    stderr_file: Path,
    timeout_sec: float,
    desktop: Optional[str] = "WinSta0\\Default",
    env: Optional[Dict[str, str]] = None,
) -> ProcessExecutionResult:
    """
    Launch command on specific Windows desktop (e.g. WinSta0\\Default) using Win32 CreateProcessW,
    enforcing timeout and capturing stdout/stderr to files.
    """
    class STARTUPINFOW(ctypes.Structure):
        _fields_ = [
            ("cb", wintypes.DWORD),
            ("lpReserved", wintypes.LPWSTR),
            ("lpDesktop", wintypes.LPWSTR),
            ("lpTitle", wintypes.LPWSTR),
            ("dwX", wintypes.DWORD),
            ("dwY", wintypes.DWORD),
            ("dwXSize", wintypes.DWORD),
            ("dwYSize", wintypes.DWORD),
            ("dwXCountChars", wintypes.DWORD),
            ("dwYCountChars", wintypes.DWORD),
            ("dwFillAttribute", wintypes.DWORD),
            ("dwFlags", wintypes.DWORD),
            ("wShowWindow", wintypes.WORD),
            ("cbReserved2", wintypes.WORD),
            ("lpReserved2", ctypes.c_void_p),
            ("hStdInput", wintypes.HANDLE),
            ("hStdOutput", wintypes.HANDLE),
            ("hStdError", wintypes.HANDLE),
        ]

    class PROCESS_INFORMATION(ctypes.Structure):
        _fields_ = [
            ("hProcess", wintypes.HANDLE),
            ("hThread", wintypes.HANDLE),
            ("dwProcessId", wintypes.DWORD),
            ("dwThreadId", wintypes.DWORD),
        ]

    class SECURITY_ATTRIBUTES(ctypes.Structure):
        _fields_ = [
            ("nLength", wintypes.DWORD),
            ("lpSecurityDescriptor", ctypes.c_void_p),
            ("bInheritHandle", wintypes.BOOL),
        ]

    GENERIC_WRITE = 0x40000000
    FILE_SHARE_READ = 0x00000001
    FILE_SHARE_WRITE = 0x00000002
    CREATE_ALWAYS = 2
    OPEN_ALWAYS = 4
    STARTF_USESTDHANDLES = 0x00000100

    sa = SECURITY_ATTRIBUTES()
    sa.nLength = ctypes.sizeof(SECURITY_ATTRIBUTES)
    sa.bInheritHandle = True
    sa.lpSecurityDescriptor = None

    stdout_handle = ctypes.windll.kernel32.CreateFileW(
        str(stdout_file),
        GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        ctypes.byref(sa),
        CREATE_ALWAYS,
        0x80,  # FILE_ATTRIBUTE_NORMAL
        None,
    )
    stderr_handle = ctypes.windll.kernel32.CreateFileW(
        str(stderr_file),
        GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        ctypes.byref(sa),
        CREATE_ALWAYS,
        0x80,
        None,
    )

    si = STARTUPINFOW()
    si.cb = ctypes.sizeof(STARTUPINFOW)
    si.dwFlags = STARTF_USESTDHANDLES
    si.hStdOutput = stdout_handle
    si.hStdError = stderr_handle
    si.lpDesktop = desktop

    pi = PROCESS_INFORMATION()

    start_time = time.perf_counter()
    working_dir = str(cwd) if cwd else None

    # Inherit current environment or construct merged
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    ok = ctypes.windll.kernel32.CreateProcessW(
        None,
        cmd,
        None,
        None,
        True,  # bInheritHandles
        0,     # dwCreationFlags
        None,  # lpEnvironment (inherits)
        working_dir,
        ctypes.byref(si),
        ctypes.byref(pi),
    )

    # Close parent's duplicate file handles so reading process won't hang
    ctypes.windll.kernel32.CloseHandle(stdout_handle)
    ctypes.windll.kernel32.CloseHandle(stderr_handle)

    if not ok:
        err = ctypes.windll.kernel32.GetLastError()
        raise RuntimeError(f"CreateProcessW failed with Win32 error {err} for command: {cmd}")

    timed_out = False
    timeout_ms = int(timeout_sec * 1000)
    wait_res = ctypes.windll.kernel32.WaitForSingleObject(pi.hProcess, timeout_ms)

    if wait_res == 0x102:  # WAIT_TIMEOUT
        timed_out = True
        kill_process_tree(pi.dwProcessId)
        ctypes.windll.kernel32.WaitForSingleObject(pi.hProcess, 3000)

    exit_code_val = wintypes.DWORD()
    ctypes.windll.kernel32.GetExitCodeProcess(pi.hProcess, ctypes.byref(exit_code_val))
    ctypes.windll.kernel32.CloseHandle(pi.hProcess)
    ctypes.windll.kernel32.CloseHandle(pi.hThread)

    duration = time.perf_counter() - start_time
    exit_code = 124 if timed_out else exit_code_val.value

    # Read preview
    stdout_prev = ""
    stderr_prev = ""
    try:
        if stdout_file.is_file():
            with open(stdout_file, "r", encoding="utf-8", errors="replace") as f:
                stdout_prev = f.read(4096)
    except Exception:
        pass
    try:
        if stderr_file.is_file():
            with open(stderr_file, "r", encoding="utf-8", errors="replace") as f:
                stderr_prev = f.read(4096)
    except Exception:
        pass

    return ProcessExecutionResult(
        command=cmd,
        exit_code=exit_code,
        timed_out=timed_out,
        duration_sec=duration,
        stdout_path=stdout_file,
        stderr_path=stderr_file,
        stdout_preview=stdout_prev,
        stderr_preview=stderr_prev,
    )


def run_process_standard(
    cmd: List[str] | str,
    cwd: Optional[Path],
    stdout_file: Path,
    stderr_file: Path,
    timeout_sec: float,
    env: Optional[Dict[str, str]] = None,
) -> ProcessExecutionResult:
    """Run non-desktop standard subprocess with timeout and log redirection."""
    start_time = time.perf_counter()
    timed_out = False
    exit_code = 1

    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    with open(stdout_file, "w", encoding="utf-8", errors="replace") as out_f, \
         open(stderr_file, "w", encoding="utf-8", errors="replace") as err_f:
        try:
            p = subprocess.Popen(
                cmd,
                cwd=str(cwd) if cwd else None,
                stdout=out_f,
                stderr=err_f,
                env=merged_env,
                shell=isinstance(cmd, str),
            )
            try:
                p.wait(timeout=timeout_sec)
                exit_code = p.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                kill_process_tree(p.pid)
                p.kill()
                exit_code = 124
        except Exception as e:
            err_f.write(f"\nExecution failed: {e}\n")
            exit_code = 1

    duration = time.perf_counter() - start_time
    stdout_prev = ""
    stderr_prev = ""
    try:
        with open(stdout_file, "r", encoding="utf-8", errors="replace") as f:
            stdout_prev = f.read(4096)
    except Exception:
        pass
    try:
        with open(stderr_file, "r", encoding="utf-8", errors="replace") as f:
            stderr_prev = f.read(4096)
    except Exception:
        pass

    cmd_str = cmd if isinstance(cmd, str) else subprocess.list2cmdline(cmd)
    return ProcessExecutionResult(
        command=cmd_str,
        exit_code=exit_code,
        timed_out=timed_out,
        duration_sec=duration,
        stdout_path=stdout_file,
        stderr_path=stderr_file,
        stdout_preview=stdout_prev,
        stderr_preview=stderr_prev,
    )
