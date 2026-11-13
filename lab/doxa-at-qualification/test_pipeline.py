"""Pure, non-invasive tests for the Doxa qualification ledger."""
from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline as p


class QualificationPipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "artifacts").mkdir()
        self.source = self.root / "artifacts" / "proof.txt"
        self.source.write_text("evidence before review\n", encoding="utf-8")
        self.catalogue = {
            "schema_version": "1.0",
            "programme": "Doxa test",
            "rig": "synthetic test rig",
            "owner_acceptance_date": "2026-11-13",
            "cases": [
                {"id": "T1", "technology": "ZoomText", "title": "Observed text",
                 "outcome": "PASS", "basis": "observed", "evidence": ["artifacts/proof.txt"]},
                {"id": "T2", "technology": "NVDA", "title": "Not offered",
                 "outcome": "NOT_APPLICABLE", "basis": "not_offered",
                 "evidence": ["artifacts/proof.txt"]},
                {"id": "T3", "technology": "Performance", "title": "CPU measured",
                 "outcome": "MEASURED", "basis": "measured",
                 "evidence": ["artifacts/proof.txt"]},
            ],
        }

    def test_real_catalogue_is_structurally_valid(self):
        actual = p.load_catalogue()
        self.assertEqual(len(actual["cases"]), 24)
        self.assertEqual(len({c["id"] for c in actual["cases"]}), 24)

    def test_all_real_evidence_present(self):
        if not (p.ROOT / "artifacts/2026-11-10__sm770_closure/three_real_apps_magnifier_result_v2.json").is_file():
            self.skipTest("Raw physical evidence is local to Dell, intentionally absent on hosted CI")
        result = p.audit(p.load_catalogue())
        self.assertFalse(result["missing_files"])
        self.assertEqual(result["counts"]["PASS"], 19)

    def test_current_functional_report_matches_15_group_verdicts(self):
        import re
        report = (p.ROOT / "docs/project/hardware/2026-11-13__doxa_sm770_functional_qualification_v2.0.md").read_text(encoding="utf-8-sig")
        table = {match.group(1): match.group(2) for match in re.finditer(
            r"\| (M[1-5]|N[1-5]|Z[1-5]) \|[^\n]*\| \*\*(PASS|NOT APPLICABLE)", report
        )}
        current = {c["id"]: c["outcome"] for c in p.load_catalogue()["cases"] if c["id"] in table}
        self.assertEqual(len(table), 15)
        for name, outcome in table.items():
            self.assertEqual(outcome.replace(" ", "_"), current[name], name)

    def test_current_performance_report_contains_raw_controlled_means(self):
        source = p.ROOT / "artifacts/2026-11-13__zoomtext_performance_closure/eight_validated_intervals.csv"
        if not source.is_file():
            self.skipTest("Raw Dell performance data are not uploaded to hosted CI")
        import csv
        rows = list(csv.DictReader(source.open(encoding="utf-8-sig", newline="")))
        self.assertEqual(len(rows), 8)
        by_condition = {}
        for row in rows:
            by_condition.setdefault((row["Setting"], row["Workload"]), []).append(float(row["TrackedProcessesCPU"]))
        report = (p.ROOT / "docs/project/hardware/2026-11-13__doxa_sm770_performance_qualification_v2.0.md").read_text(encoding="utf-8-sig")
        for (setting, workload), samples in by_condition.items():
            self.assertEqual(len(samples), 2)
            average = sum(samples) / 2
            from decimal import Decimal, ROUND_HALF_UP
            conventional = Decimal(str(average)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            self.assertIn(f"{conventional}%", report)
    def test_hash_is_raw_file_hash(self):
        record = p.audit(self.catalogue, self.root)["cases"][0]["evidence_records"][0]
        self.assertTrue(record["exists"])
        self.assertEqual(record["sha256"], hashlib.sha256(self.source.read_bytes()).hexdigest())

    def test_missing_file_never_counts_verified(self):
        self.source.unlink()
        result = p.audit(self.catalogue, self.root)
        self.assertEqual(result["missing_files"], ["artifacts/proof.txt"])
        self.assertFalse(result["cases"][0]["verified"])

    def test_traversal_absolute_and_windows_paths_rejected(self):
        for path in ("../outside", "artifacts/../../other", "C:/Windows/system.ini",
                     "\\\\remote\\file", "/etc/passwd"):
            with self.subTest(path=path):
                with self.assertRaises(ValueError):
                    p.safe_evidence_path(path, self.root)

    def test_duplicate_and_false_not_offered_rejected(self):
        bad = copy.deepcopy(self.catalogue)
        bad["cases"].append(copy.deepcopy(bad["cases"][0]))
        path = self.root / "bad.json"
        path.write_text(json.dumps(bad), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            p.load_catalogue(path)
        bad["cases"].pop()
        bad["cases"][1]["outcome"] = "PASS"
        path.write_text(json.dumps(bad), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not-offered"):
            p.load_catalogue(path)

    def test_export_junit_html_json_and_summary(self):
        out = self.root / "results"
        result = p.export_closeout(self.catalogue, out, self.root)
        self.assertFalse(result["missing_files"])
        tree = ET.parse(out / "qualification.junit.xml")
        self.assertEqual(tree.getroot().attrib["tests"], "3")
        self.assertEqual(tree.getroot().attrib["skipped"], "2")
        self.assertEqual(tree.getroot().attrib["failures"], "0")
        self.assertEqual(len(tree.findall(".//testcase")), 3)
        self.assertIn("proof.txt", (out / "qualification.html").read_text(encoding="utf-8"))
        self.assertIn("PASS: 1", (out / "SUMMARY.md").read_text(encoding="utf-8"))
        with self.assertRaises(FileExistsError):
            p.export_closeout(self.catalogue, out, self.root)

    def test_absent_evidence_export_fails_open(self):
        self.source.unlink()
        out = self.root / "bad_results"
        result = p.export_closeout(self.catalogue, out, self.root)
        tree = ET.parse(out / "qualification.junit.xml")
        self.assertEqual(tree.getroot().attrib["failures"], "3")
        self.assertEqual(len(result["missing_files"]), 1)


if __name__ == "__main__":
    unittest.main()

