"""Exact one-device Intune test uninstall. Default read-only; --execute requires strict checks."""
from pathlib import Path
import argparse
import importlib.util
import json
import sys

here=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(here))
spec=importlib.util.spec_from_file_location("pub",here/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(spec);spec.loader.exec_module(pub)
record=Path(__file__).resolve().parents[4]/"artifacts"/"releases"/"doxa-corrected-intune-deployment-record.json"
NAME="Standivarius Doxa Setup - MARIUS-DELL corrected installer qualification"

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    tok=pub.get_token(allow_interactive=False)
    device=pub.get_one_device(tok)
    pub.ensure(pub.members(tok,pub.KNOWN_PILOT_GROUP_ID)=={device.lower()},"Not Dell-only")
    app_id=json.loads(record.read_text(encoding="utf-8"))["active_app_id"]
    app=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}",tok)
    pub.ensure(app.get("displayName")==NAME,"Unexpected Intune app identity")
    pub.ensure(app.get("publishingState")=="published","Not published")
    pub.ensure(app.get("installCommandLine")=="DoxaDeploy.exe /install" and
               app.get("uninstallCommandLine")=="DoxaDeploy.exe /uninstall","Unexpected managed commands")
    assignments=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",tok).get("value",[])
    pub.ensure(len(assignments)==1 and assignments[0].get("intent")=="required","Not the one required assignment")
    pub.ensure((assignments[0].get("target") or {}).get("groupId","").lower()==pub.KNOWN_PILOT_GROUP_ID.lower(),"Wrong target group")
    print(json.dumps({"preflight":"PASS","target":"single Dell", "current":"required","change_to":"uninstall","execute":args.execute}))
    if not args.execute:return
    pub.call("POST",f"/deviceAppManagement/mobileApps/{app_id}/assign",tok,
        {"mobileAppAssignments":[{"@odata.type":"#microsoft.graph.mobileAppAssignment",
           "intent":"uninstall",
           "target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":pub.KNOWN_PILOT_GROUP_ID}}]})
    after=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",tok).get("value",[])
    pub.ensure(len(after)==1 and after[0].get("intent")=="uninstall","Uninstall assignment not confirmed")
    print("DELL_FULL_DOXA_UNINSTALL_ASSIGNED=true")
    print("ACTUAL_AGENT_REMOVAL_PENDING=true")

if __name__=="__main__":
    main()
