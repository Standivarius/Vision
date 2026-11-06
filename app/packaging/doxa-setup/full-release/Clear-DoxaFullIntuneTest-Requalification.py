"""Remove only the completed full-installer Dell-only Intune test assignment.
Requires actual absent Doxa app and existing signed hardware driver. Does not
delete the app from Intune's audit catalog, alter devices or enrollments.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import sys

here=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(here))
spec=importlib.util.spec_from_file_location("pub",here/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(spec);spec.loader.exec_module(pub)
record=Path(__file__).resolve().parents[4]/"artifacts"/"releases"/"doxa-requalification-intune-deployment-record.json"
NAME="Standivarius Doxa Setup - MARIUS-DELL customer enterprise requalification"

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    app_root=Path(r"C:\Program Files\Standivarius\DoxaSetup")
    assert not app_root.exists(), "App not removed locally"
    token=pub.get_token(allow_interactive=False)
    device=pub.get_one_device(token)
    pub.ensure(pub.members(token,pub.KNOWN_PILOT_GROUP_ID)=={device.lower()},"Pilot group changed")
    app_id=json.loads(record.read_text(encoding="utf-8"))["active_app_id"]
    app=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}",token)
    pub.ensure(app.get("displayName")==NAME,"Unexpected published app")
    rows=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",token).get("value",[])
    pub.ensure(len(rows)==1 and rows[0].get("intent")=="uninstall","Missing expected test-uninstall assignment")
    pub.ensure((rows[0].get("target") or {}).get("groupId","").lower()==pub.KNOWN_PILOT_GROUP_ID.lower(),"Not Dell-only assignment")
    print(json.dumps({"status":"PREFLIGHT_PASS","dell_application_absent":True,"intent":"uninstall","execute":args.execute}))
    if not args.execute:return
    pub.call("POST",f"/deviceAppManagement/mobileApps/{app_id}/assign",token,{"mobileAppAssignments":[]})
    after=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",token).get("value",[])
    pub.ensure(not after,"Intune test assignments were not cleared")
    print("FULL_DOXA_TEST_ASSIGNMENT_CLEARED=true")

if __name__=="__main__":
    main()
