"""Marker accuracy and evidence-integrity tests with artificial PNG bytes."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from frame_recorder import png_from_bgra
from marker_oracle import PALETTES, analyse, classify_frame


def image(rgb, width=64, height=64):
    red, green, blue = rgb
    return png_from_bgra(bytes((blue, green, red, 255)) * (width * height),
                         width, height)


class MarkerOracleTests(unittest.TestCase):
    def test_detects_left_all_shades(self):
        for colour in PALETTES["LEFT"]:
            self.assertEqual(classify_frame(image(colour))["source"], "LEFT")

    def test_detects_right_all_shades(self):
        for colour in PALETTES["RIGHT"]:
            self.assertEqual(classify_frame(image(colour))["source"], "RIGHT")

    def test_rejects_unfamiliar_colours(self):
        self.assertEqual(classify_frame(image((20, 20, 20)))["source"],
                         "UNOBSERVABLE")

    def test_detects_corrupted_recorded_image(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            picture = image(PALETTES["LEFT"][0])
            (root / "frame-00000.png").write_bytes(picture)
            manifest = root / "frame_manifest.jsonl"
            manifest.write_text(json.dumps({
                "channel": "panel_capture", "method": "GDI_SOFTWARE_PIXELS_NOT_PHYSICAL_CAMERA",
                "t_ms": 100, "file": "frame-00000.png",
                "sha256": hashlib.sha256(picture).hexdigest()}) + "\n",
                encoding="utf-8")
            records = analyse(manifest)
            self.assertEqual(records[0]["source"], "LEFT")
            self.assertEqual(records[0]["observed_by"], "independent_image_analysis")
            (root / "frame-00000.png").write_bytes(picture + b"tamper")
            with self.assertRaises(ValueError):
                analyse(manifest)

    def test_changing_shades_are_new_visible_states(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            entries = []
            for i, shade in enumerate(PALETTES["RIGHT"]):
                png = image(shade)
                name = f"frame-{i:05d}.png"
                (root / name).write_bytes(png)
                entries.append({"channel": "panel_capture", "t_ms": i * 500,
                                "file": name, "sha256": hashlib.sha256(png).hexdigest(),
                                "method": "GDI_SOFTWARE_PIXELS_NOT_PHYSICAL_CAMERA"})
            manifest = root / "frame_manifest.jsonl"
            manifest.write_text("".join(json.dumps(x) + "\n" for x in entries))
            self.assertEqual([x["counter"] for x in analyse(manifest)], [1, 2, 3, 4])


if __name__ == "__main__":
    unittest.main()

