"""Negative controls for independent striped-ruler zoom measurement."""
import unittest

from frame_recorder import png_from_bgra
from zoom_oracle import measure_zoom


def fixture(zoom, *, stripes=True):
    w, h = 640, 360
    bgra = bytearray(bytes((32, 214, 248, 255)) * (w * h))
    if stripes:
        step = 128 * zoom * w / 1920
        half = 14 * zoom * w / 1920 / 2
        centre = 38.0
        while centre < w:
            for x in range(max(0, int(centre-half)), min(w, int(centre+half)+1)):
                for y in range(h):
                    k = (y*w+x)*4
                    bgra[k:k+3] = b"\x00\x00\x00"
            centre += step
    return png_from_bgra(bytes(bgra), w, h)


class IndependentZoom(unittest.TestCase):
    def test_actual_two_times_pattern_is_recognised(self):
        result = measure_zoom(fixture(2), 1920)
        self.assertAlmostEqual(result["scale"], 2, delta=0.13)
        self.assertGreaterEqual(result["observed_bands"], 5)
        self.assertGreaterEqual(result["accepted_scanlines"], 3)

    def test_one_times_does_not_masquerade_as_two(self):
        self.assertAlmostEqual(measure_zoom(fixture(1), 1920)["scale"], 1, delta=0.12)

    def test_four_times_does_not_masquerade_as_two(self):
        self.assertAlmostEqual(measure_zoom(fixture(4), 1920)["scale"], 4, delta=0.24)

    def test_no_ruler_is_inconclusive(self):
        result = measure_zoom(fixture(2, stripes=False), 1920)
        self.assertIsNone(result["scale"])

    def test_calibration_dimensions_change_result(self):
        png = fixture(2)
        expected = measure_zoom(png, 1920)["scale"]
        bad_calibration = measure_zoom(png, 960)["scale"]
        self.assertAlmostEqual(bad_calibration, expected / 2, delta=0.1)

    def test_invalid_png_is_rejected(self):
        with self.assertRaises(ValueError):
            measure_zoom(b"not a PNG", 1920)


if __name__ == "__main__":
    unittest.main()

