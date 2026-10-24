"""
Vision Test Farm Settings Manager (v0.1)

Provides isolated backup and exact byte-for-byte restoration of user settings
under %LOCALAPPDATA%\\Standivarius\\Visual\\settings.ini.
Strictly avoids machine-wide or elevated settings.
"""

from __future__ import annotations

import configparser
import hashlib
import os
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional


def _compute_file_sha256(path: Path) -> Optional[str]:
    if not path.is_file():
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest().upper()


@dataclass
class SettingsState:
    settings_path: Path
    backup_path: Path
    existed_before: bool
    hash_before: Optional[str]
    restored: bool = False
    hash_after: Optional[str] = None
    restored_exactly: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return {
            "settings_path": str(self.settings_path),
            "backup_path": str(self.backup_path),
            "existed_before": self.existed_before,
            "hash_before": self.hash_before,
            "restored": self.restored,
            "hash_after": self.hash_after,
            "restored_exactly": self.restored_exactly,
        }


class SettingsManager:
    """Manages scoped backup and byte-identical restoration of settings.ini."""

    def __init__(self, run_dir: Path, custom_settings_path: Optional[Path] = None):
        self.run_dir = run_dir
        self.run_dir.mkdir(parents=True, exist_ok=True)
        if custom_settings_path is not None:
            self.settings_path = custom_settings_path
        else:
            local_appdata = os.environ.get("LOCALAPPDATA", "")
            self.settings_path = Path(local_appdata) / "Standivarius" / "Visual" / "settings.ini"

        self.backup_path = self.run_dir / "settings.before.ini"
        self._state: Optional[SettingsState] = None

    def backup(self, initial_overrides: Optional[Dict[str, Dict[str, str]]] = None) -> SettingsState:
        """Create backup and compute initial hash before applying optional overrides."""
        existed = self.settings_path.is_file()
        hash_before = _compute_file_sha256(self.settings_path) if existed else None

        if existed:
            shutil.copy2(self.settings_path, self.backup_path)

        self._state = SettingsState(
            settings_path=self.settings_path,
            backup_path=self.backup_path,
            existed_before=existed,
            hash_before=hash_before,
        )

        if initial_overrides:
            self.apply_overrides(initial_overrides)

        return self._state

    def apply_overrides(self, overrides: Dict[str, Dict[str, str]]) -> None:
        """Apply in-memory section/key overrides to the active settings.ini."""
        config = configparser.ConfigParser()
        if self.settings_path.is_file():
            # Support utf-16 or utf-8
            try:
                config.read(self.settings_path, encoding="utf-16")
            except Exception:
                config.read(self.settings_path, encoding="utf-8")

        for section, kv in overrides.items():
            if not config.has_section(section):
                config.add_section(section)
            for k, v in kv.items():
                config.set(section, k, str(v))

        self.settings_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.settings_path, "w", encoding="utf-8") as f:
            config.write(f)

    def restore(self) -> SettingsState:
        """Restore settings file from backup and verify byte-for-byte identity."""
        if self._state is None:
            raise RuntimeError("Cannot restore settings without calling backup() first")

        if self._state.existed_before:
            if self.backup_path.is_file():
                shutil.copy2(self.backup_path, self.settings_path)
            hash_after = _compute_file_sha256(self.settings_path)
            self._state.hash_after = hash_after
            self._state.restored = True
            self._state.restored_exactly = (hash_after == self._state.hash_before)
        else:
            if self.settings_path.is_file():
                self.settings_path.unlink()
            self._state.restored = not self.settings_path.exists()
            self._state.hash_after = None
            self._state.restored_exactly = self._state.restored

        return self._state
