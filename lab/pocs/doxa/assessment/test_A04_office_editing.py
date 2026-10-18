"""A04 strict source-input and independent visible-output qualification gates."""
import runpy
import unittest
from pathlib import Path

score=runpy.run_path(str(Path(__file__).with_name("A04-QualifyOfficeEditing.py")))["qualify"]
PASS="PASS_OFFICE_EDIT_4X_TYPED_AND_SCROLLED_VISIBLE_WITH_CARET"

def fixtures():
    src={
        "status":"PASS_SOURCE_SWITCH_TRUTH",
        "workbook_saved":False,"document_saved":False,
        "pointer_restored":True,"focus_restored":True,
        "source_verified_steps":6,"typed_verified_steps":6,"scroll_verified_steps":6,
        "observations":[]
    }
    for i in range(6):
        src["observations"].append({
            "step":i,"app":"WORD" if i%2==0 else "EXCEL",
            "typed_token":"VISIONA04"+("W" if i%2==0 else "E")+str(i),
            "input_method":"Win32 SendInput Unicode and virtual keys",
            "foreground_owned":True,"foreground_owned_at_measurement":True,
            "expected_pid":12345,"foreground_pid_at_measurement":12345,
            "typed_verified":True,
            "scroll_verified":True,"navigation_before":0,"navigation_after":10,
            "target_verified":True,"window_on_right":True
        })
    capture={"office_script_exit":0,"preview_shutdown":"NORMAL","display_count":3,
             "right_frames":250,"centre_frames":250}
    base={"status":"PASS_OFFICE_SWITCH_4X_VISIBLE_WITHIN_2S"}
    strict={"status":"PASS_OFFICE_SWITCH_4X_INDEPENDENT_PIXELS_WITH_CARET_CONTAINMENT",
            "phases":[{"inside_fraction":1.0} for _ in range(6)]}
    return src,capture,base,strict

class A04EditingSafety(unittest.TestCase):
    def test_all_evidence_required(self):
        self.assertEqual(score(*fixtures()),PASS)

    def test_pixel_missing_cannot_pass(self):
        args=list(fixtures());args[2]["status"]="FAIL_MISSING_MARKERS"
        self.assertEqual(score(*args),"FAIL_MISSING_MARKERS")

    def test_viewport_displaced_cannot_pass(self):
        args=list(fixtures());args[3]["status"]="FAIL_ACTUAL_CARET_OUTSIDE_DETAIL_VIEW"
        self.assertEqual(score(*args),"FAIL_ACTUAL_CARET_OUTSIDE_DETAIL_VIEW")

    def test_unverified_word_typing_fails(self):
        args=list(fixtures());args[0]["typed_verified_steps"]=5
        self.assertEqual(score(*args),"FAIL_EDIT_TEXT_NOT_CONFIRMED")

    def test_unverified_excel_pagedown_fails(self):
        args=list(fixtures());args[0]["scroll_verified_steps"]=5
        self.assertEqual(score(*args),"FAIL_EDIT_PAGEDOWN_NOT_CONFIRMED")

    def test_wrong_keyboard_method_cannot_pass(self):
        args=list(fixtures());args[0]["observations"][0]["input_method"]="COM"
        self.assertEqual(score(*args),"INCONCLUSIVE_EDIT_INPUT_METHOD")

    def test_wrong_target_token_cannot_pass(self):
        args=list(fixtures());args[0]["observations"][1]["typed_token"]="VISIONA04E2"
        self.assertEqual(score(*args),"FAIL_EDIT_INPUT_SEQUENCE")

    def test_no_keyboard_navigation_cannot_pass(self):
        args=list(fixtures());args[0]["observations"][0]["navigation_after"]=0
        self.assertEqual(score(*args),"FAIL_EDIT_PAGEDOWN_NO_MOVEMENT")

    def test_foreground_stolen_after_keyboard_input_is_rejected(self):
        args=list(fixtures())
        args[0]["observations"][5]["foreground_owned_at_measurement"]=False
        args[0]["observations"][5]["foreground_pid_at_measurement"]=6789
        self.assertEqual(score(*args),"FAIL_EDIT_WRONG_FOREGROUND")
    def test_unrestored_desktop_rejected(self):
        args=list(fixtures());args[0]["focus_restored"]=False
        self.assertEqual(score(*args),"FAIL_EDIT_DESKTOP_NOT_RESTORED")

    def test_preview_force_close_rejected(self):
        args=list(fixtures());args[1]["preview_shutdown"]="FORCED"
        self.assertEqual(score(*args),"FAIL_EDIT_PREVIEW_SHUTDOWN")

    def test_unknown_display_rejected(self):
        args=list(fixtures());args[1]["display_count"]=None
        self.assertEqual(score(*args),"INCONCLUSIVE_DISPLAY_TOPOLOGY")

    def test_missing_frames_rejected(self):
        args=list(fixtures());args[1]["right_frames"]=0
        self.assertEqual(score(*args),"INCONCLUSIVE_EDIT_CAPTURE_LENGTH")

    def test_docs_saved_rejected(self):
        args=list(fixtures());args[0]["document_saved"]=True
        self.assertEqual(score(*args),"FAIL_EDITED_DOCUMENT_SAVED")

if __name__=="__main__":
    unittest.main()
