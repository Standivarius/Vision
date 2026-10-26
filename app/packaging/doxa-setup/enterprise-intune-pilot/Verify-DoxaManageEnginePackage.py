"""Verify the exact ManageEngine Doxa pilot ZIP and run the EXTRACTED payload lifecycle.

Local-only verification: no endpoint manager or registry writes, no app install
outside TemporaryDirectory. Deployment qualification still requires an enrolled
separate Windows endpoint and Endpoint Central console logs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
DEFAULT_ARCHIVE = (HERE.parent.parent.parent.parent / "artifacts" / "releases" /
                   "managed" / "Doxa-Managed-AppOnly-Pilot-20261024-201607.zip")
EXPECTED_SHA256 = "4B96519BD8F7F6DD273E0B38514D36847B6BC8D78A6A46B2A38C4AD30AFB2425"
EXPECTED_PAYLOAD_SHA256 = "E5BFFBADDA7225069E73C3D362FA1269C21359821E3DFAD203C4F5C8D5C85C50"
ALLOWED = {"DoxaPilot.ps1", "DoxaSetupPayload.zip"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def verify_archive(path, *, run_lifecycle=True):
    path = Path(path).resolve(strict=True)
    package_hash = sha256(path)
    if package_hash != EXPECTED_SHA256:
        raise ValueError("Package checksum differs from pinned 2026-10-24 release")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names = [info.filename for info in entries]
        if len(names) != 2 or set(names) != ALLOWED:
            raise ValueError("Unexpected archive entries, names, paths or duplicates")
        if any(info.is_dir() or info.file_size > 8*1024*1024 for info in entries):
            raise ValueError("Unexpected directory/oversized entry")
        with tempfile.TemporaryDirectory(prefix="DoxaManageEngineVerify-") as temp:
            tempdir = Path(temp)
            for info in entries:
                dst = tempdir / info.filename
                dst.write_bytes(archive.read(info))
            script = tempdir / "DoxaPilot.ps1"
            payload = tempdir / "DoxaSetupPayload.zip"
            if sha256(payload) != EXPECTED_PAYLOAD_SHA256:
                raise ValueError("Inner Doxa payload checksum mismatch")
            if not script.read_bytes().startswith(b"param("):
                raise ValueError("Unexpected Doxa PowerShell entry")
            result = {
                "status": "PACKAGE_VERIFIED",
                "managed_software_platform": "ManageEngine Endpoint Central",
                "validation_type": "LOCAL_EXTRACTED_PACKAGE_ONLY",
                "archive_path": str(path),
                "sha256": package_hash,
                "payload_sha256": sha256(payload),
                "script_sha256": sha256(script),
                "distribution_files": sorted(names),
                "driver_msi_in_package": False,
                "cloud_ai_required": False,
                "actual_agent_deployment": "NOT_PERFORMED",
            }
            if run_lifecycle:
                tester = HERE / "Test-DoxaPilot.py"
                run = subprocess.run(
                    [sys.executable, str(tester), "--script", str(script),
                     "--payload", str(payload)],
                    capture_output=True, text=True, timeout=150,
                )
                if run.returncode != 0:
                    raise RuntimeError("Extracted Doxa payload lifecycle FAILED; code " +
                                       str(run.returncode) + "; " + run.stderr[-350:])
                tests = json.loads(run.stdout.strip())
                if tests.get("status") != "PASS" or tests.get("driver_installation") is not False:
                    raise RuntimeError("Extracted payload lifecycle did not pass")
                if len(tests.get("steps", [])) != 10:
                    raise RuntimeError("Expected exactly ten lifecycle assertions")
                result["local_lifecycle_steps"] = len(tests["steps"])
                result["local_lifecycle"] = "PASS"
            return result


if __name__ == "__main__":
    arg = argparse.ArgumentParser()
    arg.add_argument("--archive", default=str(DEFAULT_ARCHIVE))
    arg.add_argument("--no-execution", action="store_true")
    args = arg.parse_args()
    try:
        print(json.dumps(verify_archive(args.archive, run_lifecycle=not args.no_execution),
                         indent=2))
    except Exception as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
