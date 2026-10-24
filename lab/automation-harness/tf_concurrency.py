"""
Vision Test Farm Concurrency Guard (v0.1)

Enforces serialization for interactive desktop scenarios using a system named mutex,
file lock, and in-process guard. Non-interactive / synthetic scenarios may run
without holding the lock.
"""

from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
import time
from pathlib import Path
from typing import Optional

MUTEX_NAME = "Local\\Vision_TestFarm_Interactive_Desktop_Lock"


class ConcurrencyConflictError(Exception):
    pass


class DesktopConcurrencyGuard:
    """Serializes interactive scenarios so no two interactive tests overlap."""

    _process_locked = False

    def __init__(
        self,
        enabled: bool = True,
        timeout_sec: float = 30.0,
        lock_file: Optional[Path] = None,
        use_mutex: bool = True,
    ):
        self.enabled = enabled
        self.timeout_sec = timeout_sec
        self.use_mutex = use_mutex
        self.h_mutex: Optional[int] = None
        self._acquired = False
        self._lock_file = lock_file or (Path(__file__).parent / ".desktop.lock")
        self._file_handle = None

    def acquire(self) -> bool:
        if not self.enabled:
            return True

        # In-process conflict check (Win32 Mutex is reentrant on the same thread, but tests must not overlap)
        if DesktopConcurrencyGuard._process_locked:
            raise ConcurrencyConflictError("Interactive desktop locked by another active scenario in this process")

        if self.use_mutex:
            # First try Windows named mutex
            try:
                self.h_mutex = ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)
                if self.h_mutex:
                    timeout_ms = int(self.timeout_sec * 1000)
                    res = ctypes.windll.kernel32.WaitForSingleObject(self.h_mutex, timeout_ms)
                    if res in (0, 0x80):  # WAIT_OBJECT_0 = 0, WAIT_ABANDONED = 0x80
                        self._acquired = True
                        DesktopConcurrencyGuard._process_locked = True
                        return True
                    elif res == 0x102:  # WAIT_TIMEOUT
                        raise ConcurrencyConflictError(f"Interactive desktop locked by another scenario (timeout {self.timeout_sec}s)")
                    else:
                        raise ConcurrencyConflictError(f"Mutex wait failed with code {res}")
            except Exception as e:
                if isinstance(e, ConcurrencyConflictError):
                    raise
                # Fall back to file-based locking if mutex fails
                pass

        # Fallback / file-based lock
        start = time.time()
        while time.time() - start < self.timeout_sec:
            try:
                self._lock_file.parent.mkdir(parents=True, exist_ok=True)
                self._file_handle = os.open(str(self._lock_file), os.O_CREAT | os.O_EXCL | os.O_RDWR)
                os.write(self._file_handle, f"pid={os.getpid()}\n".encode("utf-8"))
                self._acquired = True
                DesktopConcurrencyGuard._process_locked = True
                return True
            except FileExistsError:
                time.sleep(0.1)
        raise ConcurrencyConflictError(f"Interactive desktop file locked (timeout {self.timeout_sec}s)")

    def release(self) -> None:
        if not self.enabled or not self._acquired:
            return

        DesktopConcurrencyGuard._process_locked = False

        if self.h_mutex:
            try:
                ctypes.windll.kernel32.ReleaseMutex(self.h_mutex)
                ctypes.windll.kernel32.CloseHandle(self.h_mutex)
            except Exception:
                pass
            self.h_mutex = None

        if self._file_handle is not None:
            try:
                os.close(self._file_handle)
                if self._lock_file.is_file():
                    self._lock_file.unlink(missing_ok=True)
            except Exception:
                pass
            self._file_handle = None

        self._acquired = False

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
