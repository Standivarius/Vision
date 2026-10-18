"""Independent A02 pixel evidence must reject forged or mismatched captures."""
import hashlib
import json
import runpy
import tempfile
import unittest
from pathlib import Path
from frame_recorder import png_from_bgra


scans=runpy.run_path(str(Path(__file__).with_name("A02-AnalyzeColourLatencyFast.py")))["scans"]


class ManifestSafety(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.folder=Path(self.tmp.name)/"right"
        self.folder.mkdir()
        png=png_from_bgra(bytes((0,255,255,255))*(128*72),128,72)
        (self.folder/"frame-00000.png").write_bytes(png)
        self.entry={"channel":"panel_capture","t_ms":1.0,
                    "monitor_role":"RIGHT","file":"frame-00000.png",
                    "sha256":hashlib.sha256(png).hexdigest()}
        self.write(self.entry)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self,entry):
        (self.folder/"frame_manifest.jsonl").write_text(
            json.dumps(entry)+"\n",encoding="utf-8")

    def test_valid_capture(self):
        rows=scans(self.folder,(0,0,128,72))
        self.assertEqual(len(rows),1)
        self.assertGreater(rows[0]["YELLOW"],1000)

    def test_sha_mismatch_cannot_pass(self):
        entry={**self.entry,"sha256":"0"*64}
        self.write(entry)
        with self.assertRaisesRegex(ValueError,"SHA-256"):
            scans(self.folder,(0,0,128,72))

    def test_role_mismatch_cannot_pass(self):
        entry={**self.entry,"monitor_role":"CENTRE"}
        self.write(entry)
        with self.assertRaisesRegex(ValueError,"monitor role"):
            scans(self.folder,(0,0,128,72))

    def test_path_escape_cannot_pass(self):
        entry={**self.entry,"file":"../other.png"}
        self.write(entry)
        with self.assertRaisesRegex(ValueError,"path escape"):
            scans(self.folder,(0,0,128,72))


if __name__=="__main__":
    unittest.main()
