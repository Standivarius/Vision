"""One-device Doxa Intune pilot: fix SYSTEM PowerShell execution policy.

Windows PowerShell event 4100 proved the initial SYSTEM installer was blocked
because scripts were disabled. Updates only the two Doxa Win32 command lines.
No system-wide policy adjustment, driver change, or new app/assignment.
"""
import argparse
import importlib.util
from pathlib import Path
import sys

from DoxaIntuneAuth import get_token

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("doxa_publisher", HERE / "Publish-DoxaIntunePilot.py")
pub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)

INSTALL_OLD = "powershell.exe -NoProfile -NonInteractive -File .\\DoxaPilot.ps1 -Action Install"
UNINSTALL_OLD = "powershell.exe -NoProfile -NonInteractive -File .\\DoxaPilot.ps1 -Action Uninstall"
INSTALL_NEW = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\DoxaPilot.ps1 -Action Install"
UNINSTALL_NEW = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\DoxaPilot.ps1 -Action Uninstall"


def validate_target(token):
    app_id = pub.active_pilot_app_id()
    pub.ensure(app_id != pub.KNOWN_PILOT_APP_ID, "Expected replacement Doxa app, not failed original")
    device_id = pub.get_one_device(token)
    group_id = pub.ensure_private_group(token, device_id)
    pub.ensure(group_id.lower() == pub.KNOWN_PILOT_GROUP_ID, "Unexpected pilot group")
    pub.ensure(pub.members(token,group_id) == {device_id.lower()}, "Group is not Dell only")
    url = "/deviceAppManagement/mobileApps/" + app_id
    app = pub.call("GET", url, token)
    pub.ensure(
        app.get("id","").lower()==app_id
        and app.get("displayName")==pub.APP_NAME
        and app.get("publisher")=="DMR Ergonomics SRL (Standivarius)"
        and app.get("@odata.type","").endswith("win32LobApp")
        and app.get("publishingState")=="published"
        and str(app.get("committedContentVersion"))=="1",
        "App identity or published package differs; refusal")
    assignments=pub.call("GET", url+"/assignments", token)
    items=assignments.get("value",[])
    pub.ensure(
        len(items)==1
        and "@odata.nextLink" not in assignments
        and items[0].get("intent")=="required"
        and items[0].get("target",{}).get("groupId","").lower()==group_id.lower(),
        "Not exactly one original Dell-only Required assignment; refusal")
    commands=(app.get("installCommandLine"),app.get("uninstallCommandLine"))
    pub.ensure(
        commands in ((INSTALL_OLD,UNINSTALL_OLD),(INSTALL_NEW,UNINSTALL_NEW)),
        "Unexpected installer command lines; refusal")
    return url,app,commands


def update_commands(token):
    url,app,commands=validate_target(token)
    if commands == (INSTALL_NEW, UNINSTALL_NEW):
        print("DOXA_APP_COMMANDS_ALREADY_CORRECT=true",flush=True)
        return
    print("DOXA_INSTALL_SCRIPT_POLICY_BLOCK_CONFIRMED_BY_POWERSHELL_EVENT_4100=true",flush=True)
    pub.call("PATCH",url,token,{
        "@odata.type":"#microsoft.graph.win32LobApp",
        "installCommandLine":INSTALL_NEW,
        "uninstallCommandLine":UNINSTALL_NEW,
    })
    reread=pub.call("GET",url,token)
    pub.ensure(
        (reread.get("installCommandLine"),reread.get("uninstallCommandLine"))
        ==(INSTALL_NEW,UNINSTALL_NEW)
        and reread.get("publishingState")=="published"
        and str(reread.get("committedContentVersion"))=="1",
        "Intune app did not retain the exact allowed update")
    new_assignments=pub.call("GET",url+"/assignments",token).get("value",[])
    pub.ensure(len(new_assignments)==1
               and new_assignments[0].get("intent")=="required"
               and new_assignments[0].get("target",{}).get("groupId","").lower()
               ==pub.KNOWN_PILOT_GROUP_ID,
               "Doxa pilot assignment unexpectedly changed")
    print("PILOT_INSTALL_COMMAND_UPDATED=true",flush=True)
    print("PILOT_UNINSTALL_COMMAND_UPDATED=true",flush=True)
    print("POWER_SHELL_POLICY_SYSTEM_WIDE_CHANGED=false",flush=True)
    print("INTUNE_APP_CONTENT_CHANGED=false",flush=True)


if __name__=="__main__":
    try:
        parser=argparse.ArgumentParser()
        parser.add_argument("--execute",action="store_true")
        args=parser.parse_args()
        pub.ensure(pub.active_pilot_app_id() != pub.KNOWN_PILOT_APP_ID,
                   "Doxa replacement app identifier not recorded")
        print("TARGET_DEVICE="+pub.DEVICE_NAME,flush=True)
        print("TARGET_APP="+pub.active_pilot_app_id(),flush=True)
        if not args.execute:
            print("DRY_RUN_NO_MICROSOFT_MUTATION=true",flush=True)
        else:
            pub.ensure(pub.tenant_id().lower() == pub.TENANT_ID,
                       "Dell workplace tenant mismatch")
            token=get_token(allow_interactive=False)
            try:
                update_commands(token)
            finally:
                token=None
    except Exception as error:
        print("DOXA_COMMAND_PATCH_STOPPED="+str(error),file=sys.stderr,flush=True)
        sys.exit(1)
