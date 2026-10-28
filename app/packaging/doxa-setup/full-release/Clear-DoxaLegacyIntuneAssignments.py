"""Remove only obsolete Dell-only *Uninstall* policies after local app is absent.
Default is read-only. Never changes another app, group or device.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import sys

root=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(root))
spec=importlib.util.spec_from_file_location("doxa_intune_publisher",root/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)

LEGACY={
    "Standivarius Doxa Setup - MARIUS-DELL app-only pilot",
    "Standivarius Doxa Setup - MARIUS-DELL preview.6 app-only qualification",
    "Standivarius Doxa Setup - MARIUS-DELL preview.7 app-only qualification",
}
FOLDERS=[
    Path(r"C:\Program Files\Standivarius\DoxaSetup"),
    Path(r"C:\Program Files\Standivarius\DoxaSetup-preview6"),
    Path(r"C:\Program Files\Standivarius\DoxaSetup-preview7"),
]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    tok=pub.get_token(allow_interactive=False)
    device=pub.get_one_device(tok)
    pub.ensure(pub.tenant_id().lower()==pub.TENANT_ID.lower(),"Wrong tenant")
    pub.ensure(pub.members(tok,pub.KNOWN_PILOT_GROUP_ID)=={device.lower()},"Group not Dell only")
    pub.ensure(not any(f.exists() for f in FOLDERS),"One prior Doxa application folder remains: refuse")
    result=pub.call("GET","/deviceAppManagement/mobileApps",tok,params={"$top":"100","$select":"id,displayName,publishingState"})
    found={a["displayName"]:a for a in result.get("value",[]) if a.get("displayName") in LEGACY}
    pub.ensure(set(found)==LEGACY,"Missing or ambiguous original test apps; manual reconciliation needed")
    approved=[]
    for name in sorted(LEGACY):
        app=found[name]
        rows=pub.call("GET",f"/deviceAppManagement/mobileApps/{app['id']}/assignments",tok).get("value",[])
        if len(rows)==0:
            continue
        pub.ensure(len(rows)==1 and rows[0].get("intent")=="uninstall","Legacy app has unexpected intent")
        pub.ensure((rows[0].get("target") or {}).get("groupId","").lower()==pub.KNOWN_PILOT_GROUP_ID.lower(),"Legacy app targets unexpected group")
        approved.append(app)
    print(json.dumps({"preflight":"PASS","obsolete_uninstall_policies":len(approved),
      "one_target_dell_only":True,"old_app_directories_absent":True,"execute":args.execute}))
    if not args.execute:return
    for app in approved:
        pub.call("POST",f"/deviceAppManagement/mobileApps/{app['id']}/assign",tok,
                 {"mobileAppAssignments":[]})
        after=pub.call("GET",f"/deviceAppManagement/mobileApps/{app['id']}/assignments",tok).get("value",[])
        pub.ensure(len(after)==0,"Old uninstall policy remains active: stop")
        print("REMOVED_OBSOLETE_DELL_UNINSTALL="+app["displayName"],flush=True)
    print("ALL_LEGACY_DELL_UNINSTALL_CONFLICTS_REMOVED=true",flush=True)

if __name__=="__main__":
    main()
