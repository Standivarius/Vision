"""Scope-locked cleanup for late Intune install after test assignment clearance.
Only the corrected Doxa Win32 app and the existing single Dell test group.
The signed Windows display driver is never touched.
"""
import argparse,importlib.util,json,sys
from pathlib import Path
here=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(here))
s=importlib.util.spec_from_file_location("pub",here/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(s);s.loader.exec_module(pub)
record=Path(__file__).resolve().parents[4]/"artifacts"/"releases"/"doxa-corrected-intune-deployment-record.json"
APP_NAME="Standivarius Doxa Setup - MARIUS-DELL corrected installer qualification"
def main():
 p=argparse.ArgumentParser();p.add_argument("--execute",action="store_true");a=p.parse_args()
 token=pub.get_token(allow_interactive=False)
 pub.ensure(pub.tenant_id().lower()==pub.TENANT_ID.lower(),"Wrong tenant")
 device=pub.get_one_device(token)
 pub.ensure(pub.members(token,pub.KNOWN_PILOT_GROUP_ID)=={device.lower()},"Not Dell-only")
 app_id=json.loads(record.read_text(encoding="utf-8"))["active_app_id"]
 app=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}",token)
 pub.ensure(app.get("displayName")==APP_NAME and app.get("publishingState")=="published","Unexpected app")
 pub.ensure(app.get("uninstallCommandLine")=="DoxaDeploy.exe /uninstall","Unrecognised uninstall")
 rows=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",token).get("value",[])
 pub.ensure(not rows,"Another assignment exists; no overwrite")
 print(json.dumps({"preflight":"PASS","single_device":"MARIUS-DELL","old_assignments":0,"target":"uninstall","execute":a.execute}))
 if not a.execute:return
 pub.call("POST",f"/deviceAppManagement/mobileApps/{app_id}/assign",token,{"mobileAppAssignments":[{
   "@odata.type":"#microsoft.graph.mobileAppAssignment","intent":"uninstall",
   "target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":pub.KNOWN_PILOT_GROUP_ID}}]})
 after=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",token).get("value",[])
 pub.ensure(len(after)==1 and after[0].get("intent")=="uninstall","Failed to assign managed uninstall")
 print("CORRECTED_DOXA_UNINSTALL_ASSIGNED_SINGLE_DELL=true")
if __name__=="__main__":main()
