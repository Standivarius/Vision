from pathlib import Path
import hashlib
import tempfile
import unittest
import zipfile
from importlib.machinery import SourceFileLoader

ROOT=Path(__file__).resolve().parent
import importlib.util
spec=importlib.util.spec_from_file_location("doxa_zip", ROOT/"Build-DoxaStableZip.py")
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class StableZipTest(unittest.TestCase):
    def test_reproducible_across_file_times_and_order(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            inp=root/"source"
            (inp/"a").mkdir(parents=True)
            (inp/"z.txt").write_text("Hello",encoding="utf8")
            (inp/"a"/"zero.txt").write_text("World",encoding="utf8")
            first=root/"first.zip"
            second=root/"second.zip"
            mod.create(inp,first)
            for f in inp.rglob("*"):
                if f.is_file(): f.touch()
            mod.create(inp,second)
            self.assertEqual(checksum(first),checksum(second))
            with zipfile.ZipFile(first) as z:
                self.assertEqual(z.namelist(),["a/zero.txt","z.txt"])
                self.assertEqual(z.getinfo("z.txt").date_time,mod.ZIP_TIME)
    def test_output_must_not_be_replaced_or_inside_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            inp=root/"source"
            inp.mkdir()
            (inp/"a").write_text("A")
            out=root/"release.zip"
            mod.create(inp,out)
            with self.assertRaises(ValueError):mod.create(inp,out)
            with self.assertRaises(ValueError):mod.create(inp,inp/"bad.zip")
            with self.assertRaises(ValueError):mod.create(inp,inp/"nested"/"bad.zip")
if __name__=="__main__":
    unittest.main()
