"""The A03 mixed-office output assessor must reject corrupted conditions."""
import runpy
import unittest
from pathlib import Path

assess=runpy.run_path(str(Path(__file__).with_name("A03-AnalyzeMixedOffice.py")))["evaluate"]


def phases():
    return [
        {"app":"WORD" if i%2==0 else "EXCEL",
         "expected_colour":"YELLOW" if i%2==0 else "GREEN",
         "source_identity_valid":True,
         "source_frames":8,"centre_frames":8,
         "source_colour_visible":7,"centre_colour_visible":7,"latency_ms":400}
        for i in range(6)
    ]


def source():
    return {"status":"PASS_SOURCE_MIXED_OFFICE",
            "focus_restored":True,"documents_saved":False}


def capture():
    return {"display_count":3,"mixed_script_exit":0,
            "preview_shutdown":"NORMAL","right_frames":156,"centre_frames":156}


class MixedOfficeGates(unittest.TestCase):
    def test_good_mixed_session_passes(self):
        self.assertEqual(assess(phases(),source(),capture()),
                         "PASS_MIXED_OFFICE_4X_SOURCE_AND_VISIBLE_OUTPUT")

    def test_wrong_order_fails(self):
        data=phases()
        data[3]["app"]="WORD"
        self.assertEqual(assess(data,source(),capture()),
                         "FAIL_MIXED_APPLICATION_SEQUENCE")

    def test_wrong_colour_order_fails(self):
        data=phases()
        data[4]["expected_colour"]="GREEN"
        self.assertEqual(assess(data,source(),capture()),
                         "FAIL_MIXED_MARKER_SEQUENCE")

    def test_wrong_application_focus_fails(self):
        data=phases()
        data[1]["source_identity_valid"]=False
        self.assertEqual(assess(data,source(),capture()),
                         "FAIL_SOURCE_PROVENANCE")

    def test_missing_destination_marker_fails(self):
        data=phases()
        data[3]["centre_colour_visible"]=0
        self.assertEqual(assess(data,source(),capture()),
                         "FAIL_MISSING_MARKERS")

    def test_delayed_marker_fails(self):
        data=phases()
        data[5]["latency_ms"]=2500
        self.assertEqual(assess(data,source(),capture()),
                         "FAIL_VISIBLE_LATENCY_OVER_2S")

    def test_bad_clock_is_not_pass(self):
        data=phases()
        data[0]["latency_ms"]=-900
        self.assertEqual(assess(data,source(),capture()),
                         "INCONCLUSIVE_TIMESTAMP_ALIGNMENT")

    def test_missing_phase_does_not_pass(self):
        self.assertEqual(assess(phases()[:-1],source(),capture()),
                         "FAIL_MIXED_APPLICATION_SEQUENCE")

    def test_three_or_four_screens_only(self):
        c=capture();c["display_count"]=2
        self.assertEqual(assess(phases(),source(),c),"INCONCLUSIVE_TOPOLOGY")

    def test_source_inconclusive_does_not_pass(self):
        s=source();s["status"]="INCONCLUSIVE"
        self.assertEqual(assess(phases(),s,capture()),"INCONCLUSIVE_SOURCE_OFFICE")

    def test_forced_exit_fails(self):
        c=capture();c["preview_shutdown"]="OWNED_PROCESS_FORCE_AFTER_TIMEOUT"
        self.assertEqual(assess(phases(),source(),c),"FAIL_PREVIEW_SHUTDOWN")

    def test_workbook_saved_fails(self):
        s=source();s["documents_saved"]=True
        self.assertEqual(assess(phases(),s,capture()),"FAIL_SOURCE_CLEANUP")


if __name__=="__main__":
    unittest.main()
