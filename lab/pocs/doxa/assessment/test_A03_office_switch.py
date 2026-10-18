"""Guarded mixed Word/Excel provenance and independent viewport verdict."""
import runpy
import unittest
from pathlib import Path


score=runpy.run_path(str(Path(__file__).with_name("A03-AnalyzeOfficeSwitch.py")))["assess_office_switch"]


def phases():
    return [
      {"app":"WORD" if i%2==0 else "EXCEL",
       "source_identity_valid":True,"source_frames":7,"centre_frames":7,
       "source_colour_visible":6,"centre_colour_visible":5,
       "latency_ms":430}
      for i in range(6)]


def stimulus():
    return {"status":"PASS_SOURCE_SWITCH_TRUTH",
            "focus_restored":True,"pointer_restored":True}


def capture():
    return {"display_count":3,"office_script_exit":0,
            "preview_shutdown":"NORMAL","right_frames":126,"centre_frames":126}


class OfficeSwitchAssessment(unittest.TestCase):
    def test_valid_two_app_sequence(self):
        self.assertEqual(score(phases(),stimulus(),capture()),
                         "PASS_OFFICE_SWITCH_4X_VISIBLE_WITHIN_2S")

    def test_stale_foreground_cannot_pass(self):
        p=phases();p[3]["source_identity_valid"]=False
        self.assertEqual(score(p,stimulus(),capture()),"FAIL_WRONG_FOREGROUND_OR_CARET")

    def test_wrong_app_order_cannot_pass(self):
        p=phases();p[2]["app"]="EXCEL"
        self.assertEqual(score(p,stimulus(),capture()),"INCONCLUSIVE_SWITCH_SEQUENCE")

    def test_source_inconclusive_not_pass(self):
        s=stimulus();s["status"]="INCONCLUSIVE"
        self.assertEqual(score(phases(),s,capture()),"INCONCLUSIVE_SOURCE_TRUTH")

    def test_old_evidence_mismatched_topology(self):
        c=capture();c["display_count"]=None
        self.assertEqual(score(phases(),stimulus(),c),"INCONCLUSIVE_TOPOLOGY")

    def test_no_source_frame_fails(self):
        p=phases();p[4]["centre_colour_visible"]=0
        self.assertEqual(score(p,stimulus(),capture()),"FAIL_MISSING_MARKERS")

    def test_very_slow_follow_fails(self):
        p=phases();p[4]["latency_ms"]=3500
        self.assertEqual(score(p,stimulus(),capture()),"FAIL_VISIBLE_LATENCY_OVER_2S")

    def test_force_shutdown_fails(self):
        c=capture();c["preview_shutdown"]="OWNED_PROCESS_FORCE_AFTER_TIMEOUT"
        self.assertEqual(score(phases(),stimulus(),c),"FAIL_PREVIEW_SHUTDOWN")

    def test_foreground_restoration_required(self):
        s=stimulus();s["focus_restored"]=False
        self.assertEqual(score(phases(),s,capture()),"FAIL_CLEANUP_OR_SOURCE_EXIT")


if __name__=="__main__":
    unittest.main()
