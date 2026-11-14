"""Doxa SM770 qualification evidence pipeline.

Read-only provenance audit and export. Physical test execution is separately
gated by Invoke-DoxaATTest.ps1 and the existing Vision Test Farm.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
CATALOGUE = Path(__file__).with_name("cases.json")
OUTCOMES = {"PASS", "NOT_APPLICABLE", "MEASURED"}
BASES = {"observed", "owner_accepted", "not_offered", "measured"}


def load_catalogue(path: Path = CATALOGUE) -> dict:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if data.get("schema_version") != "1.0" or not isinstance(data.get("cases"), list):
        raise ValueError("Unsupported catalogue schema")
    ids: set[str] = set()
    for item in data["cases"]:
        if not all(isinstance(item.get(k), str) and item[k] for k in
                   ("id", "technology", "title", "outcome", "basis")):
            raise ValueError("Invalid case identity")
        if item["id"] in ids:
            raise ValueError("Duplicate case ID " + item["id"])
        ids.add(item["id"])
        if item["outcome"] not in OUTCOMES or item["basis"] not in BASES:
            raise ValueError("Invalid verdict or basis in " + item["id"])
        if item["basis"] == "not_offered" and item["outcome"] != "NOT_APPLICABLE":
            raise ValueError("Unsupported not-offered verdict")
        if item["basis"] == "owner_accepted" and item["outcome"] != "PASS":
            raise ValueError("Owner acceptance must be a PASS")
        if item["basis"] == "measured" and item["outcome"] != "MEASURED":
            raise ValueError("A measurement must use MEASURED")
        if not isinstance(item.get("evidence"), list) or not item["evidence"]:
            raise ValueError("Missing evidence references for " + item["id"])
        for entry in item["evidence"]:
            safe_evidence_path(entry)
    return data


def safe_evidence_path(value: str, root: Path = ROOT) -> Path:
    """No absolute paths, URL paths, traversal, network paths or workspace escapes."""
    if not isinstance(value, str) or "\\" in value or not value or ":" in value:
        raise ValueError("Invalid evidence reference")
    rel = Path(value)
    if rel.is_absolute() or any(piece in ("..", ".") for piece in rel.parts):
        raise ValueError("Path traversal is not permitted: " + value)
    resolved = (root / rel).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError("Evidence outside repository: " + value) from exc
    return resolved


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def audit(data: dict, root: Path = ROOT) -> dict:
    records = []
    for case in data["cases"]:
        files = []
        for name in case["evidence"]:
            p = safe_evidence_path(name, root)
            if p.is_file():
                files.append({"path": name, "bytes": p.stat().st_size,
                              "sha256": sha256_file(p), "exists": True})
            else:
                files.append({"path": name, "exists": False})
        records.append({**case, "verified": all(x["exists"] for x in files),
                        "evidence_records": files})
    return {
        "schema_version": "1.0",
        "programme": data["programme"],
        "rig": data["rig"],
        "accepted_on": data["owner_acceptance_date"],
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "cases": records,
        "counts": dict(Counter(c["outcome"] for c in records)),
        "missing_files": sorted({f["path"] for c in records
                                 for f in c["evidence_records"] if not f["exists"]}),
    }


def write_junit(ledger: dict, target: Path) -> None:
    items = ledger["cases"]
    suite = ET.Element("testsuite", name="Doxa_SM770_qualification",
                       tests=str(len(items)),
                       failures=str(sum(not c["verified"] for c in items)),
                       errors="0",
                       skipped=str(sum(c["outcome"] != "PASS" and c["verified"] for c in items)))
    for c in items:
        node = ET.SubElement(suite, "testcase", classname=c["technology"], name=c["id"] + " " + c["title"])
        if not c["verified"]:
            ET.SubElement(node, "failure", message="Missing referenced evidence").text = "\n".join(
                x["path"] for x in c["evidence_records"] if not x["exists"])
        elif c["outcome"] != "PASS":
            ET.SubElement(node, "skipped", message=c["outcome"] + " — " + c["basis"])
        ET.SubElement(node, "system-out").text = json.dumps(
            {"basis": c["basis"], "evidence": c["evidence_records"]}, ensure_ascii=False)
    ET.ElementTree(suite).write(target, encoding="utf-8", xml_declaration=True)


def write_html(ledger: dict, output: Path, root: Path = ROOT) -> None:
    lines = ["<!doctype html><html lang='en'><meta charset='utf-8'>",
             "<title>Doxa SM770 qualification ledger</title>",
             "<style>body{font:15px system-ui,sans-serif;max-width:1200px;margin:2rem auto;padding:0 1rem;color:#18202c}"
             "table{border-collapse:collapse;width:100%}td,th{padding:10px;text-align:left;border-bottom:1px solid #cbd5e1}"
             "th{background:#f1f5f9}a{overflow-wrap:anywhere}small{color:#596579}</style>",
             "<h1>Doxa SM770 — qualification ledger</h1>",
             "<p>Acceptance verdicts are separate from the underlying historical observations.</p>",
             "<table><tr><th>Case</th><th>Technology</th><th>Accepted outcome</th><th>Basis</th><th>Evidence</th></tr>"]
    for case in ledger["cases"]:
        links = []
        for f in case["evidence_records"]:
            target = safe_evidence_path(f["path"], root)
            href = quote(os.path.relpath(target, output.parent).replace("\\", "/"), safe="/.-_")
            label = html.escape(Path(f["path"]).name)
            links.append(f"<a href='{html.escape(href, quote=True)}'>{label}</a>"
                         + ("" if f["exists"] else " [MISSING]"))
        columns = [case["id"] + " — " + case["title"], case["technology"],
                   case["outcome"] if case["verified"] else "EVIDENCE ERROR", case["basis"]]
        lines.append("<tr>" + "".join("<td>" + html.escape(v) + "</td>" for v in columns)
                     + "<td>" + "<br>".join(links) + "</td></tr>")
    lines.extend(["</table>", "<p><small>Original raw files are never modified by this report.</small></p>", "</html>"])
    output.write_text("\n".join(lines), encoding="utf-8")


def export_closeout(data: dict, output: Path, root: Path = ROOT) -> dict:
    if output.exists() and any(output.iterdir()):
        raise FileExistsError("Closeout output is not empty: " + str(output))
    output.mkdir(parents=True, exist_ok=True)
    ledger = audit(data, root)
    (output / "qualification.json").write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n",
                                                encoding="utf-8")
    write_junit(ledger, output / "qualification.junit.xml")
    write_html(ledger, output / "qualification.html", root)
    count = ledger["counts"]
    summary = [
        "# Doxa SM770 qualification evidence ledger",
        f"Generated: {ledger['generated_utc']}",
        f"Owner acceptance: {ledger['accepted_on']}",
        "",
        f"PASS: {count.get('PASS', 0)} | Not applicable: {count.get('NOT_APPLICABLE', 0)} "
        f"| Measured diagnostics: {count.get('MEASURED', 0)}",
        f"Missing referenced files: {len(ledger['missing_files'])}",
        "",
        "## Cases",
        "",
        "| ID | Accepted outcome | Basis | Evidence verified |",
        "|---|---|---|---|",
    ]
    summary.extend(f"| {c['id']} | {c['outcome']} | {c['basis']} | "
                   f"{'YES' if c['verified'] else 'NO'} |" for c in ledger["cases"])
    (output / "SUMMARY.md").write_text("\n".join(summary) + "\n", encoding="utf-8")
    return ledger


def preflight() -> int:
    """Only calls the pre-existing read-only physical-console topology probe."""
    probe = ROOT / "lab/pocs/doxa/assessment/A02_display_preflight.py"
    result = subprocess.run([sys.executable, str(probe)], cwd=probe.parent,
                            text=True, capture_output=True, timeout=20, check=False)
    print(result.stdout.strip())
    if result.stderr:
        print(result.stderr.strip(), file=sys.stderr)
    if result.returncode:
        print("BLOCKED: physical-console topology is not qualified", file=sys.stderr)
    return result.returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Doxa SM770 qualification closeout")
    parser.add_argument("command", choices=["catalogue", "audit", "closeout", "preflight"])
    parser.add_argument("--output", help="New, empty output directory for closeout")
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    args = parser.parse_args(argv)
    if args.command == "preflight":
        return preflight()
    try:
        data = load_catalogue(args.catalogue)
        if args.command == "catalogue":
            for c in data["cases"]:
                print(f"{c['id']:<13} {c['outcome']:<16} {c['title']}")
            return 0
        if args.command == "audit":
            result = audit(data)
            print(json.dumps({"counts": result["counts"], "missing_files": result["missing_files"]},
                             indent=2))
            return 2 if result["missing_files"] else 0
        if not args.output:
            parser.error("--output is required for closeout")
        dest = Path(args.output).resolve()
        if not dest.is_relative_to(ROOT.resolve()):
            raise ValueError("Output directory must be inside Vision repository")
        ledger = export_closeout(data, dest)
        print("Closeout records: " + str(dest))
        print(json.dumps({"counts": ledger["counts"], "missing_files": ledger["missing_files"]}, indent=2))
        return 2 if ledger["missing_files"] else 0
    except (ValueError, FileExistsError, OSError) as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

