import importlib.util
from pathlib import Path
import unittest

p=Path(__file__).with_name("w0_readonly_baseline.py")
s=importlib.util.spec_from_file_location("w0",p)
m=importlib.util.module_from_spec(s)
s.loader.exec_module(m)
def sample():
    return [{"primary":i==0,"physical_id_hash":("laptop" if i==0 else str(i))} for i in range(4)]

class W0Tests(unittest.TestCase):
    def test_physical_four_unique(self):
        self.assertEqual(m.verdict(sample(),True,[]),"PASS_READ_ONLY_PREP")
    def test_no_rdp_substitute(self):
        self.assertEqual(m.verdict(sample(),False,[]),"BLOCKED_NOT_PHYSICAL_CONSOLE")
    def test_no_magnifier_collision(self):
        self.assertEqual(m.verdict(sample(),True,["magnify.exe","zoomtext.exe"]),"BLOCKED_CONFLICTING_MAGNIFIERS")
    def test_one_missing_screen(self):
        self.assertEqual(m.verdict(sample()[:3],True,[]),"BLOCKED_FOUR_MONITORS_NOT_PRESENT")
    def test_repeated_physical_identifier(self):
        bad=sample()
        bad[3]["physical_id_hash"]=bad[2]["physical_id_hash"]
        self.assertEqual(m.verdict(bad,True,[]),"IDENTITY_AMBIGUOUS")
    def test_unreadable_identity(self):
        bad=sample()
        bad[1]["physical_id_hash"]=None
        self.assertEqual(m.verdict(bad,True,[]),"IDENTITY_AMBIGUOUS")
if __name__=="__main__":
    unittest.main()
