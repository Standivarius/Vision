"""Upload one exact Doxa full Windows package to Intune, target Dell only.
Default is read-only. --execute is restricted to a known one-device group.
No driver uninstalls, no reboots, no admin policy changes.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import importlib.util
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
SRC=Path(__file__).resolve().parents[1]/"enterprise-intune-pilot"
sys.path.insert(0,str(SRC))
spec=importlib.util.spec_from_file_location("doxa_publisher",SRC/"Publish-DoxaIntunePilot.py")
pub=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)

APP_NAME="Standivarius Doxa Setup - MARIUS-DELL independent High final test"
RELEASE=ROOT/"artifacts"/"releases"/"gemini-high-fix-build-20261028"
ARCHIVE=RELEASE/"Intune"/"DoxaDeploy.intunewin"
MANAGED=RELEASE/"ManageEngine"/"DoxaDeploy.exe"
MANIFEST=RELEASE/"RELEASE-MANIFEST.json"
CHECK_RECORD=ROOT/"artifacts"/"releases"/"doxa-highfinal-intune-deployment-record.json"
pub.APP_NAME=APP_NAME
pub.PILOT_ID_FILE=CHECK_RECORD
DETECTION=r'''
$path=Join-Path $env:ProgramW6432 'Standivarius\DoxaMaintenance\DoxaMaintenance-v2.exe'
if(-not(Test-Path -LiteralPath $path -PathType Leaf)){exit 1}
$output=& $path /detect 2>$null
if($LASTEXITCODE -eq 0 -and [string]$output -like 'AppInstalled*'){
 'DETECTED:DoxaFullWindows'
 exit 0
}
exit 1
'''.strip()

def package():
    assert ARCHIVE.is_file() and MANAGED.is_file(), "Missing frozen release artifacts"
    m=json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    expected={f["path"]:f["sha256"].upper() for f in m["files"]}
    for f,rel in [(ARCHIVE,"Intune/DoxaDeploy.intunewin"),(MANAGED,"ManageEngine/DoxaDeploy.exe")]:
        assert hashlib.sha256(f.read_bytes()).hexdigest().upper()==expected[rel], "Package mutated since manifest"
    with zipfile.ZipFile(ARCHIVE) as z:
        assert set(z.namelist())=={
            "IntuneWinPackage/Contents/IntunePackage.intunewin",
            "IntuneWinPackage/Metadata/Detection.xml"
        }, "Unknown outer Intune file"
        encoded=z.read("IntuneWinPackage/Contents/IntunePackage.intunewin")
        meta=ET.fromstring(z.read("IntuneWinPackage/Metadata/Detection.xml"))
    assert meta.findtext("SetupFile")=="DoxaDeploy.exe", "Wrong Intune setup executable"
    assert meta.findtext("Name")=="DoxaDeploy.exe", "Wrong Intune metadata identity"
    crypt={node.tag[0].lower()+node.tag[1:]:node.text for node in meta.find("EncryptionInfo")}
    assert crypt["fileDigestAlgorithm"]=="SHA256", "Unsupported encrypted package"
    return encoded,int(meta.findtext("UnencryptedContentSize")),crypt,hashlib.sha256(ARCHIVE.read_bytes()).hexdigest().upper()

def preflight(tok):
    pub.ensure(pub.tenant_id().lower()==pub.TENANT_ID.lower(),"Wrong tenant")
    device=pub.get_one_device(tok)
    pub.ensure(pub.members(tok,pub.KNOWN_PILOT_GROUP_ID)=={device.lower()},"Pilot group must be exactly one Dell")
    for old in ("Standivarius Doxa Setup - MARIUS-DELL app-only pilot",
                "Standivarius Doxa Setup - MARIUS-DELL preview.6 app-only qualification",
                "Standivarius Doxa Setup - MARIUS-DELL preview.7 app-only qualification"):
        found=pub.call("GET","/deviceAppManagement/mobileApps",tok,
                       params={"$filter":f"displayName eq '{old}'","$select":"id,displayName"})
        pub.ensure(len(found.get("value",[]))==1,"Legacy app catalog changed: "+old)
        items=pub.call("GET",f"/deviceAppManagement/mobileApps/{found['value'][0]['id']}/assignments",tok)
        pub.ensure(not items.get("value"),"Legacy uninstall policy remains: "+old)
    current=pub.call("GET","/deviceAppManagement/mobileApps",tok,
                     params={"$filter":f"displayName eq '{APP_NAME}'","$select":"id,displayName,publishingState"})
    pub.ensure(not current.get("value"),"Full release pilot already exists; refuse duplicate")
    return device

def create_app(tok):
    body={
        "@odata.type":"#microsoft.graph.win32LobApp",
        "displayName":APP_NAME,
        "description":"One-device full Doxa Windows installation evaluation; existing Dell signed driver preserved",
        "publisher":"DMR Ergonomics SRL (Standivarius)",
        "notes":"Review candidate only; exact encrypted package and Dell-only group; no automatic Windows restart",
        "installCommandLine":"DoxaDeploy.exe /install",
        "uninstallCommandLine":"DoxaDeploy.exe /uninstall",
        "setupFilePath":"DoxaDeploy.exe","fileName":"IntunePackage.intunewin",
        "allowedArchitectures":"x64","minimumSupportedWindowsRelease":"Windows11_23H2",
        "rules":[{"@odata.type":"#microsoft.graph.win32LobAppPowerShellScriptRule",
                  "ruleType":"detection",
                  "scriptContent":base64.b64encode(DETECTION.encode("utf-8-sig")).decode("ascii"),
                  "enforceSignatureCheck":False,"runAs32Bit":False}],
        "installExperience":{"@odata.type":"microsoft.graph.win32LobAppInstallExperience",
                             "runAsAccount":"system","deviceRestartBehavior":"suppress"},
        "returnCodes":[{"@odata.type":"microsoft.graph.win32LobAppReturnCode",
                        "returnCode":0,"type":"success"},
                       {"@odata.type":"microsoft.graph.win32LobAppReturnCode",
                        "returnCode":3010,"type":"softReboot"}]
    }
    app=pub.call("POST","/deviceAppManagement/mobileApps",tok,body)
    pub.record_active_pilot_app_id(app["id"])
    return app["id"]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--execute",action="store_true")
    args=parser.parse_args()
    encrypted,size,crypt,hash_value=package()
    token=pub.get_token(allow_interactive=False)
    device=preflight(token)
    print(json.dumps({"preflight":"PASS","package_sha256":hash_value,
      "device":"MARIUS-DELL","one_device_group":True,"legacy_assignments_absent":True,
      "managed_executable":"DoxaDeploy.exe","execute":args.execute}),flush=True)
    if not args.execute:return
    app_id=create_app(token)
    print("FULL_DOXA_PILOT_APP_CREATED="+app_id,flush=True)
    pub.upload_app(token,app_id,encrypted,size,crypt)
    pub.assign_only_dell(token,app_id,pub.KNOWN_PILOT_GROUP_ID,device)
    print(json.dumps({"status":"ASSIGNED_TO_MARIUS_DELL_ONLY","new_app_id":app_id,
      "package_sha256":hash_value,"expected_intune_install":"SYSTEM",
      "actual_agent_install":"AWAIT_AGENT_EVIDENCE"}),flush=True)

if __name__=="__main__":
    main()
