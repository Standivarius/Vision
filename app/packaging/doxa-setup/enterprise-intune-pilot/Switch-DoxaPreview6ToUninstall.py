"""Flip ONLY the verified Doxa preview.6 Dell-only managed app from Required to Uninstall.

Default read-only. Never changes first Doxa pilot, group membership or SMI driver.
"""
from __future__ import annotations
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

HERE=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location("preview6", HERE/"Publish-DoxaPreview6Intune.py")
pilot=importlib.util.module_from_spec(sp)
sp.loader.exec_module(pilot)
pub=pilot.pub
APP_ID="ec42c2b2-af21-43ff-8b68-e5c0f9c0583d"
TARGET=r"C:\Program Files\Standivarius\DoxaSetup-preview6"


def installed():
    shell=r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    result=subprocess.run([shell,"-NoProfile","-NonInteractive","-File",
                           str(HERE/"DoxaPilot.ps1"),"-Action","Detect",
                           "-TargetRoot",TARGET],
                          capture_output=True,text=True,timeout=45)
    pub.ensure(result.returncode in (0,1),"Unexpected detection result")
    return result.returncode==0


def verify(token, expected_intent):
    device_id,exists=pilot.preflight(token)
    pub.ensure(exists and pub.active_pilot_app_id().lower()==APP_ID, "Wrong preview6 app ID")
    path="/deviceAppManagement/mobileApps/"+APP_ID
    app=pub.call("GET",path,token)
    pub.ensure(app.get("id","").lower()==APP_ID and
               app.get("displayName")==pilot.NEW_APP_NAME and
               app.get("publisher")=="DMR Ergonomics SRL (Standivarius)" and
               app.get("publishingState")=="published" and
               app.get("@odata.type","").endswith("win32LobApp") and
               str(app.get("committedContentVersion"))=="1" and
               app.get("installExperience",{}).get("runAsAccount")=="system",
               "Unexpected preview6 app identity/version/system install")
    for key,action in (("installCommandLine","Install"),("uninstallCommandLine","Uninstall")):
        value=app.get(key,"")
        pub.ensure("DoxaSetup-preview6" in value and "-Action "+action in value and
                   "C:\\Program Files\\Standivarius\\" in value and
                   "DoxaPilot.ps1" in value, "Wrong isolated "+action+" command")
    a=pub.call("GET",path+"/assignments",token)
    assignments=a.get("value",[])
    pub.ensure(len(assignments)==1 and "@odata.nextLink" not in a and
               assignments[0].get("intent")==expected_intent and
               assignments[0].get("target",{}).get("groupId","").lower()==pub.KNOWN_PILOT_GROUP_ID.lower(),
               "Expected unique Dell-only "+expected_intent+" assignment")
    return path


def request_uninstall(token):
    pub.ensure(installed(),"Actual preview6 installation not detected; refuse uninstall")
    path=verify(token,"required")
    body={"mobileAppAssignments":[{
        "@odata.type":"#microsoft.graph.mobileAppAssignment",
        "intent":"uninstall",
        "target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget",
                  "groupId":pub.KNOWN_PILOT_GROUP_ID}}]}
    pub.call("POST",path+"/assign",token,body)
    verify(token,"uninstall")
    print("PREVIEW6_DELL_ONLY_INTUNE_UNINSTALL_ASSIGNMENT_CONFIRMED=true",flush=True)
    print("UNINSTALL_DEVICE_EXECUTION_PENDING=true",flush=True)
    print("SILICON_MOTION_DRIVER_OPERATION=false",flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    token=pub.get_token(allow_interactive=False)
    verify(token,"required" if args.execute else "required")
    pub.ensure(installed(),"No qualifying preview6 install")
    print("PREVIEW6_INSTALLED_AND_REQUIRED_PASS=true",flush=True)
    if not args.execute:
        print("READ_ONLY_NO_ASSIGNMENT_CHANGE=true",flush=True)
        return
    request_uninstall(token)

if __name__=="__main__":
    try:main()
    except Exception as exc:
        print("PREVIEW6_UNINSTALL_GUARD_STOPPED="+type(exc).__name__,file=sys.stderr,flush=True)
        raise SystemExit(1)
