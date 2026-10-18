import runpy
import unittest
from pathlib import Path

score = runpy.run_path(str(Path(__file__).with_name("A02-AnalyzeColourLatencyFast.py")))["assess_phases"]


def step(delay=400, source=5, centre=5, src_frames=6, dst_frames=6):
    return {
        "source_frames": src_frames,
        "centre_frames": dst_frames,
        "source_colour_visible": source,
        "centre_colour_visible": centre,
        "latency_ms": delay,
    }


class TestA02ColourLatency(unittest.TestCase):
    def test_all_visible_with_bounded_delays_pass(self):
        self.assertEqual(score([step(0), step(450), step(-80)]), "PASS_MARKERS_WITHIN_2S")

    def test_missing_centre_target_fails_when_source_visible(self):
        self.assertEqual(score([step(400), step(400, centre=0)]),
                         "FAIL_MISSING_MARKERS")

    def test_excess_latency_fails(self):
        self.assertEqual(score([step(2501)]), "FAIL_VISIBLE_LATENCY_OVER_2S")

    def test_unobservable_source_is_not_a_fail(self):
        self.assertEqual(score([step(centre=4, source=0)]), "INCONCLUSIVE")

    def test_too_few_independent_frames_is_inconclusive(self):
        self.assertEqual(score([step(src_frames=2)]), "INCONCLUSIVE")

    def test_wrong_clock_alignment_is_inconclusive(self):
        self.assertEqual(score([step(-1500)]), "INCONCLUSIVE_TIMESTAMP_ALIGNMENT")

    def test_no_phases_cannot_pass(self):
        self.assertEqual(score([]), "INCONCLUSIVE")


if __name__ == "__main__":
    unittest.main()
