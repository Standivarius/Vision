"""Non-destructive source-contract test; does not sign or install."""
from pathlib import Path
source=(Path(__file__).parent/"Finalize-DoxaSignedRelease.ps1").read_text(encoding="utf-8-sig")
checker=(Path(__file__).parent/"Test-DoxaReleaseConsistency.py").read_text(encoding="utf-8-sig")
fields=("source_commit","native_host_source_sha256","retail_builder_source_sha256",
        "embedded_application_payload_sha256","embedded_vendor_msi_sha256",
        "embedded_package_source_sha256")
for field in fields:
    assert f"{field}=$old.{field}" in source, field
assert "path=$_.FullName.Substring(" in source
assert "rel=record[\"path\"]" in checker
assert "if(-not $old.$field)" in source
assert "expected_files=release.get(\"files\")" in checker
print("PASS: signed and unsigned release manifest contract aligned (source only)")
