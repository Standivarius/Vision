"""Mutation-style negative controls. stdlib only; no desktop input."""
import json
import unittest

from assessor import evaluate, load_records

PLAN = {
    "schema": "vision-assessment-v1", "id": "ASSESSOR-CANARY",
    "phases": [{"id": "left", "start_ms": 0, "end_ms": 4000,
                "expected_source": "LEFT", "settle_ms": 500,
                "require_foreground": True, "changing_content": True,
                "max_update_gap_ms": 1600, "require_zoom": 2.0}]
}


def healthy():
    rows = [{"channel": "meta", "t_ms": 0, "topology_ok": True}]
    for i in range(1, 7):
        t = i * 500
        rows.extend([
            {"channel": "os", "t_ms": t, "role": "LEFT", "locked": False},
            {"channel": "panel", "t_ms": t + 5, "source": "LEFT",
             "counter": i, "scale": 2.0,
             "observed_by": "independent_image_analysis"}
        ])
    return sorted(rows, key=lambda x: x["t_ms"])


class AssessorSelfDetection(unittest.TestCase):
    def verdict(self, records, plan=None):
        return evaluate(plan or PLAN, sorted(records, key=lambda x: x["t_ms"]))["status"]

    def test_clean_independent_evidence_passes(self):
        self.assertEqual(self.verdict(healthy()), "PASS")

    def test_wrong_source_is_detected(self):
        rows = healthy()
        for x in rows:
            if x["channel"] == "panel":
                x["source"] = "RIGHT"
        self.assertEqual(self.verdict(rows), "FAIL")

    def test_frozen_detail_is_detected(self):
        rows = healthy()
        for x in rows:
            if x["channel"] == "panel":
                x["counter"] = 1
        self.assertEqual(self.verdict(rows), "FAIL")

    def test_frame_gap_is_detected(self):
        rows = healthy()
        # Time span of consecutive content changes exceeds agreed timing bound.
        for x in rows:
            if x["channel"] == "panel" and x["counter"] in (2, 3, 4, 5):
                x["counter"] = 1
        self.assertEqual(self.verdict(rows), "FAIL")

    def test_wrong_zoom_is_detected(self):
        rows = healthy()
        for x in rows:
            if x["channel"] == "panel":
                x["scale"] = 4.0
        self.assertEqual(self.verdict(rows), "FAIL")

    def test_renderer_logs_cannot_substitute_visual_evidence(self):
        rows = [r for r in healthy() if r["channel"] != "panel"]
        rows.append({"channel": "vision", "t_ms": 3500, "source": "LEFT",
                     "frame_age_ms": 1, "claims_pass": True})
        self.assertEqual(self.verdict(rows), "INCONCLUSIVE")

    def test_failed_foreground_stimulus_is_inconclusive(self):
        rows = healthy()
        for x in rows:
            if x["channel"] == "os":
                x["role"] = "RIGHT"
        self.assertEqual(self.verdict(rows), "INCONCLUSIVE")

    def test_unexpected_foreground_interrupt_is_inconclusive(self):
        rows = healthy()
        next(x for x in rows if x["channel"] == "os")["role"] = "LAPTOP"
        self.assertEqual(self.verdict(rows), "INCONCLUSIVE")

    def test_missing_visible_counter_is_inconclusive(self):
        rows = healthy()
        for x in rows:
            if x["channel"] == "panel":
                x.pop("counter")
        self.assertEqual(self.verdict(rows), "INCONCLUSIVE")

    def test_locked_is_blocked_not_test_failure(self):
        rows = healthy()
        next(x for x in rows if x["channel"] == "os")["locked"] = True
        self.assertEqual(self.verdict(rows), "BLOCKED")

    def test_unqualified_topology_is_blocked(self):
        rows = healthy()
        rows[0]["topology_ok"] = False
        self.assertEqual(self.verdict(rows), "BLOCKED")

    def test_not_a_pass_without_any_records(self):
        self.assertEqual(self.verdict([]), "INCONCLUSIVE")

    def test_foreground_and_display_can_differ_during_manual_grace(self):
        rows = healthy()
        for row in rows:
            if row["channel"] == "os":
                row["role"] = "RIGHT"
        plan = json.loads(json.dumps(PLAN))
        plan["phases"][0]["foreground_source"] = "RIGHT"
        self.assertEqual(self.verdict(rows, plan), "PASS")

    def test_sparse_panel_evidence_cannot_pass(self):
        rows = [r for r in healthy() if r["channel"] != "panel"
                or r["t_ms"] >= 2500]
        self.assertEqual(self.verdict(rows), "INCONCLUSIVE")

    def test_caret_requires_independent_geometry(self):
        plan = json.loads(json.dumps(PLAN))
        plan["phases"][0]["require_caret_in_view"] = True
        rows = healthy()
        self.assertEqual(self.verdict(rows, plan), "INCONCLUSIVE")
        for r in rows:
            if r["channel"] == "panel":
                r["caret_in_view"] = True
        self.assertEqual(self.verdict(rows, plan), "PASS")
        next(r for r in rows if r["channel"] == "panel")["caret_in_view"] = False
        self.assertEqual(self.verdict(rows, plan), "FAIL")

    def test_invalid_scenario_does_not_silently_pass(self):
        bad = dict(PLAN, schema="wrong")
        with self.assertRaises(ValueError):
            self.verdict(healthy(), bad)


    def expanded_zoom_case(self):
        plan = json.loads(json.dumps(PLAN))
        plan["phases"][0]["end_ms"] = 8500
        rows = [{"channel": "meta", "t_ms": 0, "topology_ok": True}]
        for i in range(1, 17):
            t = i * 500
            rows += [
                {"channel": "os", "t_ms": t, "role": "LEFT", "locked": False},
                {"channel": "panel", "t_ms": t + 5, "source": "LEFT",
                 "counter": i, "scale": 2.0,
                 "observed_by": "independent_image_analysis"},
            ]
        return plan, rows

    def test_single_intermittent_unmeasurable_ruler_may_pass(self):
        plan, rows = self.expanded_zoom_case()
        next(r for r in rows if r.get("counter") == 4)["scale"] = None
        result = evaluate(plan, sorted(rows, key=lambda r: r["t_ms"]))
        self.assertEqual(result["status"], "PASS")
        self.assertGreaterEqual(result["phases"][0]["metrics"]["zoom_measured_fraction"], .90)

    def test_multiple_unmeasurable_zoom_frames_are_inconclusive(self):
        plan, rows = self.expanded_zoom_case()
        for r in rows:
            if r.get("counter") in (4, 6, 8):
                r["scale"] = None
        self.assertEqual(self.verdict(rows, plan), "INCONCLUSIVE")

    def test_wrong_measured_zoom_is_fail_even_with_missing_frames(self):
        plan, rows = self.expanded_zoom_case()
        next(r for r in rows if r.get("counter") == 4)["scale"] = None
        next(r for r in rows if r.get("counter") == 5)["scale"] = 4.0
        self.assertEqual(self.verdict(rows, plan), "FAIL")

    def test_zoom_measurements_with_prolonged_gap_not_pass(self):
        plan = json.loads(json.dumps(PLAN))
        plan["phases"][0]["end_ms"] = 18500
        rows = [{"channel": "meta", "t_ms": 0, "topology_ok": True}]
        for i in range(1, 37):
            t = i * 500
            rows.extend([
                {"channel": "os", "t_ms": t, "role": "LEFT", "locked": False},
                {"channel": "panel", "t_ms": t + 5, "source": "LEFT",
                 "counter": i, "scale": None if i in (9, 10, 11) else 2.0,
                 "observed_by": "independent_image_analysis"}
            ])
        self.assertEqual(self.verdict(rows, plan), "INCONCLUSIVE")

if __name__ == "__main__":
    unittest.main()

