"""A02 Excel evidence gates: guard against misattributed visuals and wrong IDs."""
import unittest
from importlib import util
from pathlib import Path


def load():
    path=Path(__file__).with_name("A02-AnalyzeExcelVisual.py")
    spec=util.spec_from_file_location("excel_a02_visual_score",path)
    module=util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.assess_excel_phases


score=load()
run_score=__import__("runpy").run_path(str(Path(__file__).with_name("A02-AnalyzeExcelVisual.py")))["assess_excel_run"]


def phase(delay=400, cell=True, visible=6, source=6):
    return {"cell_identity_correct":cell, "source_frames":8,
            "centre_frames":8,"source_colour_visible":source,
            "centre_colour_visible":visible,"latency_ms":delay}


class ExcelScore(unittest.TestCase):
    def test_six_correct_steps_pass(self):
        self.assertEqual(score([phase() for _ in range(6)],"PASS_SOURCE_CELL_IDENTITY"),
                         "PASS_EXCEL_SOURCE_IDENTITY_AND_VISIBLE_MARKERS_WITHIN_2S")

    def test_wrong_cell_can_never_pass(self):
        values=[phase() for _ in range(6)]
        values[2]["cell_identity_correct"]=False
        self.assertEqual(score(values,"PASS_SOURCE_CELL_IDENTITY"),
                         "INCONCLUSIVE_SOURCE_CELL_IDENTITY")

    def test_inconclusive_source_cannot_pass(self):
        self.assertEqual(score([phase() for _ in range(6)],"INCONCLUSIVE"),
                         "INCONCLUSIVE_SOURCE_CELL_IDENTITY")

    def test_fewer_steps_cannot_pass(self):
        self.assertEqual(score([phase() for _ in range(5)],"PASS_SOURCE_CELL_IDENTITY"),
                         "INCONCLUSIVE_SOURCE_CELL_IDENTITY")

    def test_missing_visible_marker_fails(self):
        v=[phase() for _ in range(6)];v[3]=phase(visible=0)
        self.assertEqual(score(v,"PASS_SOURCE_CELL_IDENTITY"),"FAIL_MISSING_MARKERS")

    def test_slow_visible_marker_fails(self):
        v=[phase() for _ in range(6)];v[4]=phase(delay=2800)
        self.assertEqual(score(v,"PASS_SOURCE_CELL_IDENTITY"),
                         "FAIL_VISIBLE_LATENCY_OVER_2S")

    def test_wrong_qpc_clock_is_inconclusive(self):
        v=[phase() for _ in range(6)];v[4]=phase(delay=-1000)
        self.assertEqual(score(v,"PASS_SOURCE_CELL_IDENTITY"),
                         "INCONCLUSIVE_TIMESTAMP_ALIGNMENT")



def qualified_source():
    return {"status":"PASS_SOURCE_CELL_IDENTITY",
            "workbook_saved":False,"focus_restored":True}

def qualified_capture():
    return {"display_count":3,"excel_script_exit":0,"preview_shutdown":"NORMAL",
            "right_frames":148,"centre_frames":148}


class ExcelRunSafety(unittest.TestCase):
    def test_realistic_qualified_run(self):
        self.assertEqual(run_score([phase() for _ in range(6)],qualified_source(),qualified_capture()),
                         "PASS_EXCEL_SOURCE_IDENTITY_AND_VISIBLE_MARKERS_WITHIN_2S")

    def test_unverified_topology_not_pass(self):
        capture=qualified_capture();capture["display_count"]=None
        self.assertEqual(run_score([phase() for _ in range(6)],qualified_source(),capture),
                         "INCONCLUSIVE_TOPOLOGY_EVIDENCE")

    def test_forced_shutdown_fails(self):
        capture=qualified_capture();capture["preview_shutdown"]="OWNED_PROCESS_FORCE_AFTER_TIMEOUT"
        self.assertEqual(run_score([phase() for _ in range(6)],qualified_source(),capture),
                         "FAIL_VISION_PREVIEW_SHUTDOWN")

    def test_original_focus_not_restored_fails(self):
        source=qualified_source();source["focus_restored"]=False
        self.assertEqual(run_score([phase() for _ in range(6)],source,qualified_capture()),
                         "FAIL_SOURCE_FIXTURE_CLEANUP")

    def test_missing_capture_is_inconclusive(self):
        capture=qualified_capture();capture["right_frames"]=3
        self.assertEqual(run_score([phase() for _ in range(6)],qualified_source(),capture),
                         "INCONCLUSIVE_INDEPENDENT_CAPTURE")

if __name__=="__main__":
    unittest.main()
