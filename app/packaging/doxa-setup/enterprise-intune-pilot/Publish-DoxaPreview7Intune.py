"""Doxa preview.7 app-only, single-Dell SYSTEM install via original proven Intune uploader.

Default = read-only identity/package/old-pilot checks. --execute creates a NEW
version-named managed app, uploads the verified package and assigns it to
the existing Dell-only group. No changes to original pilot or SMI driver.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("DoxaPilotPublisher", HERE / "Publish-DoxaIntunePilot.py")
pub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pub)

SOURCE_SHA = "08dceb23c65c84890042490fe8c098cfae9107e3"
PACKAGE_SHA = "1339ae3baf3d954783e91cd15111edef278628464b7f7b91a55c97199dd83a2c"
NEW_APP_NAME = "Standivarius Doxa Setup - MARIUS-DELL preview.7 app-only qualification"
OLD_APP_ID = "62fcb7ce-ebc2-4407-9b51-0710cb809c32"
PREVIOUS_APP_ID = "ec42c2b2-af21-43ff-8b68-e5c0f9c0583d"
TARGET_SUFFIX = r"Standivarius\DoxaSetup-preview7"

pub.APP_NAME = NEW_APP_NAME
pub.PILOT_ID_FILE = pub.BRANCH_ROOT / "artifacts" / "releases" / "intune" / "doxa-preview7-active-app.json"


def preflight(token):
    pub.ensure(pub.tenant_id().lower() == pub.TENANT_ID.lower(), "Unexpected DMR tenant")
    device_id = pub.get_one_device(token)
    members = pub.members(token, pub.KNOWN_PILOT_GROUP_ID)
    pub.ensure(members == {device_id.lower()}, "Existing group not exactly one Dell device")
    legacy = pub.call("GET", f"/deviceAppManagement/mobileApps/{OLD_APP_ID}", token)
    pub.ensure(legacy.get("displayName") == "Standivarius Doxa Setup - MARIUS-DELL app-only pilot",
               "Original Intune pilot identity unexpectedly changed")
    assignment = pub.call("GET", f"/deviceAppManagement/mobileApps/{OLD_APP_ID}/assignments", token)
    old = assignment.get("value", [])
    pub.ensure(len(old) == 1 and old[0].get("intent") == "uninstall",
               "Previous pilot must remain assigned uninstall; refuse")
    # The previous one-device preview must be fully uninstalled, not resurrected
    # by a conflicting Required policy against the older Program Files folder.
    previous = pub.call("GET", f"/deviceAppManagement/mobileApps/{PREVIOUS_APP_ID}", token)
    pub.ensure(previous.get("displayName") ==
               "Standivarius Doxa Setup - MARIUS-DELL preview.6 app-only qualification",
               "Wrong prior preview6 app")
    previous_assignment = pub.call("GET", f"/deviceAppManagement/mobileApps/{PREVIOUS_APP_ID}/assignments", token)
    previous_rows = previous_assignment.get("value", [])
    pub.ensure(len(previous_rows) == 1 and previous_rows[0].get("intent") == "uninstall",
               "Previous preview6 app must remain assigned Uninstall")
    pub.ensure(not Path(r"C:\Program Files\Standivarius\DoxaSetup-preview6").exists(),
               "Previous preview6 app not yet removed from Dell")
    found = pub.call("GET", "/deviceAppManagement/mobileApps", token,
                     params={"$filter": f"displayName eq '{NEW_APP_NAME}'", "$select":"id,displayName,publishingState"})
    matches = found.get("value", [])
    pub.ensure(len(matches) <= 1, "Ambiguous preview7 test app")
    if matches:
        pub.ensure(matches[0].get("id", "").lower() == pub.active_pilot_app_id().lower(),
                   "Unexpected app with preview7 name; refuse")
    return device_id, bool(matches)


def package():
    file, encrypted, clear_size, crypto = pub.read_package()
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    pub.ensure(digest == PACKAGE_SHA, "Specific approved preview7 Intune package hash mismatch")
    pub.ensure(file.name == "DoxaPilot.intunewin" and
               "preview7-08dceb2" in str(file.parent), "Package source directory mismatch")
    pub.ensure(b"Get-DoxaSha256" in (HERE / "DoxaPilot.ps1").read_bytes(),
               "Install script must strictly verify hashes without Get-FileHash")
    return file, encrypted, clear_size, crypto, digest


def create_preview7_app(token):
    """Publish a separate SYSTEM app with a dedicated path that old Intune
    'uninstall' cannot possibly remove; strong package/detection isolation.
    """
    import uuid
    source=(HERE/"DoxaPilot.ps1").read_text(encoding="utf-8-sig")
    needle="if(-not $TargetRoot){$pf=if($env:ProgramW6432){$env:ProgramW6432}else{$env:ProgramFiles};$TargetRoot=Join-Path $pf 'Standivarius\\DoxaSetup'}"
    pub.ensure(source.count(needle)==1, "Unknown detection source layout")
    default="if(-not $TargetRoot){$TargetRoot=Join-Path $env:ProgramFiles '"+TARGET_SUFFIX+"'}"
    detection=source.replace(needle,default,1)
    pub.ensure("Get-DoxaSha256" in detection and "Get-FileHash -LiteralPath" not in detection,
               "Source integrity detection unavailable")
    subpath="C:"+chr(92)+"Program Files"+chr(92)+TARGET_SUFFIX
    install="powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\\DoxaPilot.ps1 -Action Install -TargetRoot "+chr(34)+subpath+chr(34)
    uninstall=install.replace("-Action Install","-Action Uninstall")
    rule={"@odata.type":"#microsoft.graph.win32LobAppPowerShellScriptRule",
          "ruleType":"detection",
          "scriptContent":base64.b64encode(detection.encode("utf-8-sig")).decode("ascii"),
          "enforceSignatureCheck":False,"runAs32Bit":False}
    body={"@odata.type":"#microsoft.graph.win32LobApp",
          "displayName":NEW_APP_NAME,
          "description":"One Dell-only Doxa Setup preview7 application test, no Silicon Motion driver, no remote AI by installation",
          "publisher":"DMR Ergonomics SRL (Standivarius)",
          "notes":"One-host preview7 path isolated from historical uninstall pilot",
          "installCommandLine":install,"uninstallCommandLine":uninstall,
          "setupFilePath":"DoxaPilot.ps1","fileName":"IntunePackage.intunewin",
          "allowedArchitectures":"x64","minimumSupportedWindowsRelease":"Windows11_23H2",
          "rules":[rule],
          "installExperience":{"@odata.type":"microsoft.graph.win32LobAppInstallExperience",
                               "runAsAccount":"system","deviceRestartBehavior":"suppress"},
          "returnCodes":[{"@odata.type":"microsoft.graph.win32LobAppReturnCode",
                          "returnCode":0,"type":"success"}]}
    published=pub.call("POST","/deviceAppManagement/mobileApps",token,body)
    app_id=str(uuid.UUID(published["id"]))
    pub.record_active_pilot_app_id(app_id)
    print("PREVIEW6_ISOLATED_MANAGED_APP_CREATED="+app_id,flush=True)
    return app_id


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true", help="Create/assign only dedicated Dell preview7 app")
    args = parser.parse_args()
    file, encrypted, clear_size, crypto, digest = package()
    token = pub.get_token(allow_interactive=False)
    device_id, existing = preflight(token)
    print(json.dumps({"preflight":"PASS","source_sha":SOURCE_SHA,
                      "exact_package_sha256":digest,"device":"MARIUS-DELL",
                      "group_exactly_one_dell":True,"old_pilot_uninstall_preserved":True,
                      "new_app_already_exists":existing,"requested_deployment":args.execute}), flush=True)
    if not args.execute:
        return
    pub.ensure(not existing, "Pre-existing preview7 app; do not silently modify or reassign")
    app_id = create_preview7_app(token)
    pub.upload_app(token, app_id, encrypted, clear_size, crypto)
    pub.assign_only_dell(token, app_id, pub.KNOWN_PILOT_GROUP_ID, device_id)
    print(json.dumps({"preview7_managed_app_created":True,"app_id":app_id,
                      "assignment_scope":"MARIUS-DELL only","intent":"required",
                      "no_driver_actions":True}),flush=True)


if __name__ == "__main__":
    main()
