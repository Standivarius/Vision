"""Canonical cross-machine Doxa build ZIP writer. No install, credentials or network."""
from __future__ import annotations
import os
from pathlib import Path
import stat
import sys
import zipfile

ZIP_TIME = (2000, 1, 1, 0, 0, 0)


def is_under_source(source_key: str, destination_key: str) -> bool:
    """Drive-aware containment. Cross-drive paths are necessarily disjoint."""
    source_drive = os.path.splitdrive(source_key)[0].casefold()
    destination_drive = os.path.splitdrive(destination_key)[0].casefold()
    if source_drive != destination_drive:
        if not source_drive or not destination_drive:
            raise ValueError("Ambiguous drive in output containment check")
        return False
    return os.path.commonpath((source_key, destination_key)) == source_key


def create(source: Path, destination: Path) -> tuple[int, int]:
    source = source.resolve(strict=True)
    # Windows runners may resolve short/canonical directory aliases differently
    # from Path.absolute(); resolve BOTH ends before enforcing containment.
    destination = destination.resolve(strict=False)
    if not source.is_dir():
        raise ValueError("Source must be a directory")
    source_key = os.path.normcase(str(source))
    destination_key = os.path.normcase(str(destination))
    if is_under_source(source_key, destination_key):
        raise ValueError("Output must be outside ZIP source")
    if destination.exists():
        raise ValueError("Refuse to overwrite existing package")
    entries = []
    for p in source.rglob("*"):
        # Never archive symlinks/junctions or absolute/out-of-tree content.
        is_reparse = (bool(getattr(p.stat(follow_symlinks=False), "st_file_attributes", 0)
                            & stat.FILE_ATTRIBUTE_REPARSE_POINT) if os.name == "nt" else False)
        if p.is_symlink() or is_reparse:
            raise ValueError("Refuse symlink/reparse path")
        if p.is_file():
            rel = p.relative_to(source).as_posix()
            if not rel or rel.startswith("/") or ".." in p.relative_to(source).parts:
                raise ValueError("Unsafe ZIP path")
            entries.append((rel, p))
    if not entries:
        raise ValueError("Empty ZIP source")
    entries.sort(key=lambda entry: entry[0])
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "x") as archive:
        for rel, path in entries:
            info = zipfile.ZipInfo(rel, date_time=ZIP_TIME)
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_STORED
            with path.open("rb") as f:
                archive.writestr(info, f.read())
    return len(entries), destination.stat().st_size


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: Build-DoxaStableZip.py <stage_directory> <archive.zip>")
    try:
        count, size = create(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, OSError) as exc:
        print("DOXA_REPRODUCIBLE_ZIP_REFUSED: " + type(exc).__name__, file=sys.stderr)
        raise SystemExit(2)
    print("DOXA_REPRODUCIBLE_ZIP_PASS", count, size)
