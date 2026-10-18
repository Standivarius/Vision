"""Regression: visual colour alone may not qualify an offscreen Word caret."""
import runpy
import unittest
from pathlib import Path

root = Path(__file__).resolve().parent
functions = runpy.run_path(str(root / "A03-QualifyOfficeSwitchCaret.py"))
strict = functions["strict_verdict"]


def independent(status="PASS_OFFICE_SWITCH_4X_VISIBLE_WITHIN_2S"):
    return {"status": status}


def geometry(statuses=None):
    statuses = statuses or ["INSIDE"] * 6
    return {"diagnostic_only": True, "phases": [
        {"status": status, "samples": 80, "inside_fraction": 1 if status == "INSIDE" else 0}
        for status in statuses
    ]}


class OfficeSwitchCaretVeto(unittest.TestCase):
    def test_colour_and_caret_required(self):
        self.assertEqual(strict(independent(), geometry()),
                         "PASS_OFFICE_SWITCH_4X_INDEPENDENT_PIXELS_WITH_CARET_CONTAINMENT")

    def test_wrong_word_crop_vetoes_visual_colour_pass(self):
        g = geometry()
        g["phases"][2]["status"] = "DISPLACED"
        self.assertEqual(strict(independent(), g),
                         "FAIL_ACTUAL_CARET_OUTSIDE_DETAIL_VIEW")

    def test_multiple_displaced_word_phases_are_not_hidden(self):
        self.assertEqual(strict(independent(), geometry(
            ["DISPLACED", "INSIDE", "DISPLACED", "INSIDE", "DISPLACED", "INSIDE"])),
            "FAIL_ACTUAL_CARET_OUTSIDE_DETAIL_VIEW")

    def test_unobservable_caret_is_inconclusive(self):
        g = geometry()
        g["phases"][4]["status"] = "INCONCLUSIVE"
        self.assertEqual(strict(independent(), g),
                         "INCONCLUSIVE_CARET_GEOMETRY_COVERAGE")

    def test_missing_stable_samples_is_inconclusive(self):
        g = geometry()
        g["phases"][1]["samples"] = 3
        self.assertEqual(strict(independent(), g),
                         "INCONCLUSIVE_CARET_GEOMETRY_COVERAGE")

    def test_absent_geometry_never_passes(self):
        self.assertEqual(strict(independent(), {"diagnostic_only": True, "phases": []}),
                         "INCONCLUSIVE_NO_CARET_GEOMETRY")

    def test_telemetry_never_rescues_missing_visual_evidence(self):
        self.assertEqual(strict(independent("INCONCLUSIVE"), geometry()), "INCONCLUSIVE")

    def test_telemetry_never_rescues_wrong_visible_source(self):
        self.assertEqual(strict(independent("FAIL_MISSING_MARKERS"), geometry()),
                         "FAIL_MISSING_MARKERS")


if __name__ == "__main__":
    unittest.main()
