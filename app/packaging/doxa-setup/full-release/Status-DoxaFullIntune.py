"""Read-only Intune publication, Dell targeting and agent-side service status."""
import importlib.util
import json
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(root))
spec=importlib.util.spec_from_file_location("doxa_pub",root/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)
app_record=Path(__file__).resolve().parents[4]/"artifacts"/"releases"/"doxa-full-intune-deployment-record.json"
app_id=json.loads(app_record.read_text(encoding="utf-8"))["active_app_id"]
assert app_id, "No published app ID"
tok=pub.get_token(allow_interactive=False)
app=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}",tok)
assignment=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/assignments",tok)
try:
    statuses=pub.call("GET",f"/deviceAppManagement/mobileApps/{app_id}/deviceStatuses",tok)
except RuntimeError:
    statuses={"value":[]}
print(json.dumps({
    "published":app.get("publishingState"),
    "app_name":app.get("displayName"),
    "assignment_count":len(assignment.get("value",[])),
    "assignment_intents":[r.get("intent") for r in assignment.get("value",[])],
    "device_statuses":[{"state":r.get("installState"),"error":r.get("errorCode")} for r in statuses.get("value",[])],
    "mutations":False,
},indent=2))
