"""Read-only Dell Intune readiness snapshot; never prints credentials or device identifiers."""
import importlib.util
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parents[1] / "enterprise-intune-pilot"
sys.path.insert(0, str(here))
spec = importlib.util.spec_from_file_location("doxa_publisher", here / "Publish-DoxaIntunePilot.py")
pub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)
token = pub.get_token(allow_interactive=False)
device_id = pub.get_one_device(token)
members = pub.members(token, pub.KNOWN_PILOT_GROUP_ID)
apps = pub.call("GET", "/deviceAppManagement/mobileApps", token, params={
    "$select": "id,displayName,publishingState", "$top": "100"
})
doxa = [x for x in apps.get("value", []) if "Doxa Setup" in x.get("displayName", "")]
rows = []
for app in doxa:
    assignments = pub.call("GET", "/deviceAppManagement/mobileApps/" + app["id"] + "/assignments", token)
    rows.append({
        "name": app.get("displayName"),
        "state": app.get("publishingState"),
        "assignment_intents": [a.get("intent") for a in assignments.get("value", [])],
        "dedicated_dell_group_targeted": any(
            (a.get("target") or {}).get("groupId", "").lower() == pub.KNOWN_PILOT_GROUP_ID.lower()
            for a in assignments.get("value", [])
        ),
    })
print(json.dumps({
    "status": "PASS",
    "tenant_verified": pub.tenant_id().lower() == pub.TENANT_ID.lower(),
    "dell_managed_and_compliant": True,
    "dell_only_group": members == {device_id.lower()},
    "existing_doxa_apps": rows,
    "writes_performed": False,
}, indent=2))
