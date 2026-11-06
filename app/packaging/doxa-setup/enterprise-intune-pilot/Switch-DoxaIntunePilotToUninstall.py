"""Dell-only Doxa app-only Intune uninstall test. No driver or enrollment changes.

Default is a read-only local dry run. Graph writes require --execute,
the exact expected existing assignment and successful DoxaPilot detection.
Do not run --execute until Intune has completed the actual first install.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

from DoxaIntuneAuth import get_token, TENANT_ID

HERE=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location("doxa_intune_publisher", HERE / "Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(sp)
sp.loader.exec_module(pub)

EXPECTED_INSTALL="powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\DoxaPilot.ps1 -Action Install"
EXPECTED_UNINSTALL="powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\DoxaPilot.ps1 -Action Uninstall"
EXPECTED_APP_ID="62fcb7ce-ebc2-4407-9b51-0710cb809c32"

def detect_install():
    """Validate packaged Doxa app-only installation; exit code 0 means installed."""
    powershell=Path("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
    result=subprocess.run([str(powershell),"-NoProfile","-NonInteractive",
                           "-ExecutionPolicy","Bypass","-File",
                           str(HERE/"DoxaPilot.ps1"),"-Action","Detect"],
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=45)
    if result.returncode not in (0,1):
        raise RuntimeError("Doxa detection returned unexpected code "+str(result.returncode))
    return result.returncode==0

def assert_single_dell_group(token):
    d=pub.get_one_device(token)
    g=pub.KNOWN_PILOT_GROUP_ID
    group=pub.call("GET", "/groups/"+g, token)
    pub.ensure(group.get("id","").lower()==g
               and group.get("displayName")==pub.GROUP_NAME
               and group.get("securityEnabled") is True
               and group.get("mailEnabled") is False,
               "The original dedicated Dell security group is missing or changed")
    pub.ensure(pub.members(token,g)=={d.lower()}, "Group is not exactly Dell")
    return g

def preflight(token, required_intent="required"):
    appid=pub.active_pilot_app_id()
    pub.ensure(appid==EXPECTED_APP_ID, "Pilot app ID changed; refuse")
    pub.ensure(pub.tenant_id().lower()==TENANT_ID, "Wrong Microsoft workplace tenant")
    group=assert_single_dell_group(token)
    base="/deviceAppManagement/mobileApps/"+appid
    app=pub.call("GET",base,token)
    pub.ensure(
        app.get("id","").lower()==appid
        and app.get("displayName")==pub.APP_NAME
        and app.get("publisher")=="DMR Ergonomics SRL (Standivarius)"
        and app.get("@odata.type","").endswith("win32LobApp")
        and app.get("publishingState")=="published"
        and str(app.get("committedContentVersion"))=="1"
        and app.get("installCommandLine")==EXPECTED_INSTALL
        and app.get("uninstallCommandLine")==EXPECTED_UNINSTALL,
        "App identity/version/install/uninstall commands changed; refuse")
    assigns=pub.call("GET",base+"/assignments",token)
    rows=assigns.get("value",[])
    pub.ensure(
        len(rows)==1 and "@odata.nextLink" not in assigns
        and rows[0].get("intent")==required_intent
        and rows[0].get("target",{}).get("groupId","").lower()==group,
        "Expected exactly one "+required_intent+" assignment to Dell-only group")
    return base, group

def request_uninstall(token, *, installed):
    """Change Required to Uninstall only after verified local install."""
    pub.ensure(installed, "DOXA_NOT_INSTALLED: refuse to switch assignment to Uninstall")
    base, group=preflight(token,required_intent="required")
    body={"mobileAppAssignments":[{
        "@odata.type":"#microsoft.graph.mobileAppAssignment",
        "intent":"uninstall",
        "target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":group},
    }]}
    pub.call("POST",base+"/assign",token,body)
    check=pub.call("GET",base+"/assignments",token)
    items=check.get("value",[])
    pub.ensure(len(items)==1 and "@odata.nextLink" not in check
               and items[0].get("intent")=="uninstall"
               and items[0].get("target",{}).get("groupId","").lower()==group,
               "Uninstall assignment not confirmed: investigate before another change")
    print("INTUNE_DELL_ONLY_UNINSTALL_ASSIGNED=true",flush=True)
    print("DRIVER_UNINSTALL_INCLUDED=false",flush=True)
    print("INTUNE_DEVICE_UNINSTALL_VERIFIED=false",flush=True)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    pub.ensure(pub.active_pilot_app_id()==EXPECTED_APP_ID, "Active Doxa pilot ID changed")
    installed=detect_install()
    print("DOXA_APP_DETECTED="+str(installed),flush=True)
    print("TARGET_DEVICE="+pub.DEVICE_NAME,flush=True)
    print("TARGET_APP="+EXPECTED_APP_ID,flush=True)
    if not args.execute:
        print("DRY_RUN_NO_MICROSOFT_GRAPH_MUTATION=true",flush=True)
        return
    pub.ensure(installed,"Doxa app not installed; do not request uninstall")
    token=get_token(allow_interactive=False)
    try:
        request_uninstall(token,installed=installed)
    finally:
        token=None

if __name__=="__main__":
    try:
        main()
    except Exception as error:
        print("DOXA_INTUNE_UNINSTALL_SWITCH_STOPPED="+str(error),file=sys.stderr,flush=True)
        raise SystemExit(1)
