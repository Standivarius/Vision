"""Isolated Doxa app-only Intune pilot; no MSI, no company-wide assignment.

Run with no arguments to inspect the .intunewin locally (no authentication).
Run with --execute only with DMR administrator present to approve Microsoft's device-code flow.
Tokens and Azure Storage SAS URLs remain in memory. No login secrets persisted.

This is a *pilot*, not a signed production installer. No Windows driver operations.
"""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile

import requests

CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft Graph Command Line Tools
DEVICE_NAME = "MARIUS-DELL"
GROUP_NAME = "Doxa Intune pilot - MARIUS-DELL (24 October 2026)"
GROUP_ALIAS = "doxa-intune-marius-dell-pilot-20261024"
APP_NAME = "Standivarius Doxa Setup - MARIUS-DELL app-only pilot"
# IDs observed in the first genuine Microsoft tenant mutation; prevent duplicate
# objects or accidental re-use of a different app/group. Not credentials.
KNOWN_PILOT_GROUP_ID = "3f74c6a3-d470-4d78-8c17-756381465095"
KNOWN_PILOT_APP_ID = "5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4"
GRAPH = "https://graph.microsoft.com/v1.0"
SCOPES = [
    "DeviceManagementApps.ReadWrite.All",
    "DeviceManagementManagedDevices.Read.All",
    "Device.Read.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
]
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "artifacts" / "releases" / "intune"
# The worktree's artifacts live at its root; no files are copied out of approved directory.
BRANCH_ROOT = ROOT.parents[2]
AUTH_TIMEOUT = 600
SESSION = requests.Session()


def ensure(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest().upper()


def read_package():
    candidates = sorted((BRANCH_ROOT / "artifacts" / "releases" / "intune").glob(
        "doxa-intune-app-only-*/DoxaPilot.intunewin"), key=lambda p: p.stat().st_mtime, reverse=True)
    ensure(len(candidates) > 0, "Build DoxaIntunePilot.ps1 first; .intunewin not found.")
    file = candidates[0]
    with zipfile.ZipFile(file) as z:
        names = set(z.namelist())
        ensure(names == {
            "IntuneWinPackage/Contents/IntunePackage.intunewin",
            "IntuneWinPackage/Metadata/Detection.xml"}, "Unexpected files in .intunewin outer container")
        encoded = z.read("IntuneWinPackage/Contents/IntunePackage.intunewin")
        root = ET.fromstring(z.read("IntuneWinPackage/Metadata/Detection.xml"))
    get = lambda name: root.findtext(name)
    ensure(get("SetupFile") == "DoxaPilot.ps1", "Wrong setup script")
    ensure(get("Name") == "DoxaPilot.ps1", "Wrong metadata name")
    crypto = {node.tag[0].lower() + node.tag[1:]: node.text
              for node in root.find("EncryptionInfo")}
    expected = {"encryptionKey", "macKey", "initializationVector",
                "mac", "profileIdentifier", "fileDigest", "fileDigestAlgorithm"}
    ensure(set(crypto) == expected, "Unexpected encryption manifest shape")
    ensure(crypto["fileDigestAlgorithm"].upper() == "SHA256", "Unexpected digest")
    ensure(int(get("UnencryptedContentSize")) > 0, "Empty app bundle")
    return file, encoded, int(get("UnencryptedContentSize")), crypto


def tenant_id():
    import subprocess
    out = subprocess.check_output(["dsregcmd.exe", "/status"], text=True, errors="replace",
                                  timeout=20)
    for line in out.splitlines():
        if "WorkplaceTenantId" in line and ":" in line:
            guid = line.split(":", 1)[1].strip()
            import uuid
            uuid.UUID(guid)
            return guid
    raise RuntimeError("Dell has no discoverable DMR workplace tenant. Refusing arbitrary tenant")


def auth(tenant):
    base = "https://login.microsoftonline.com/" + tenant + "/oauth2/v2.0"
    scope = " ".join("https://graph.microsoft.com/" + s for s in SCOPES)
    resp = SESSION.post(base + "/devicecode", data={"client_id": CLIENT_ID, "scope": scope}, timeout=20)
    ensure(resp.ok, f"Microsoft device-code request failed HTTP {resp.status_code}")
    payload = resp.json()
    print("AUTHORIZE_URL=" + payload["verification_uri"], flush=True)
    print("AUTHORIZE_CODE=" + payload["user_code"], flush=True)
    print("PERMISSIONS=" + ", ".join(SCOPES), flush=True)
    deadline = time.monotonic() + min(AUTH_TIMEOUT, int(payload["expires_in"]))
    interval = max(5, int(payload.get("interval", 5)))
    while time.monotonic() < deadline:
        time.sleep(interval)
        r = SESSION.post(base + "/token", data={"client_id": CLIENT_ID,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "device_code": payload["device_code"]}, timeout=20)
        if r.ok:
            return r.json()["access_token"]
        code = r.json().get("error", "unknown") if r.headers.get("content-type","").startswith("application/json") else "unknown"
        if code == "authorization_pending":
            continue
        if code == "slow_down":
            interval += 5
            continue
        raise RuntimeError("Microsoft login stopped: " + code)
    raise RuntimeError("Microsoft authorization expired; no tenant changes attempted")


def call(method, path, token, payload=None, params=None):
    url = GRAPH + path
    response = SESSION.request(method, url,
        headers={"Authorization": "Bearer " + token, "Accept": "application/json",
                 "Content-Type": "application/json"},
        params=params, json=payload, timeout=40)
    if not response.ok:
        try:
            m = response.json().get("error", {})
            err = m.get("code", "unknown") if isinstance(m, dict) else "unknown"
        except ValueError:
            err = "unknown"
        # Print only Graph's schema/validation complaint, never URLs, credentials or tokens.
        details = ""
        try:
            import re
            message = m.get("message", "") if isinstance(m, dict) else ""
            # Redact instead of suppressing the full useful API validation message.
            message = re.sub(r"(?i)https?://[^\\s<>\\\"']+", "[URL]", message)
            message = re.sub(r"(?i)[\\w.+-]+@[\\w.-]+", "[EMAIL]", message)
            message = re.sub(r"(?i)bearer\\s+[^\\s]+", "[TOKEN]", message)
            message = re.sub(r"(?i)eyJ[A-Za-z0-9_-]{20,}\\.[A-Za-z0-9._-]+", "[TOKEN]", message)
            message = re.sub(r"(?i)[?&](sig|se|sp|sv)=[^\\s&]+", "[SAS]", message)
            if message:
                details = ", detail=" + re.sub(r"[^A-Za-z0-9 .:_/()'\\[\\]-]", "?", message)[:440]
        except Exception:
            pass
        raise RuntimeError(f"Microsoft Graph {method} {path.split('?')[0]}: HTTP {response.status_code}, error={err}{details}")
    return response.json() if response.content else {}


def get_one_device(token):
    query = call("GET", "/deviceManagement/managedDevices", token,
                 params={"$filter": f"deviceName eq '{DEVICE_NAME}'", "$select": "deviceName,azureADDeviceId,managementAgent,complianceState"})
    items = query.get("value", [])
    ensure(len(items) == 1 and items[0]["deviceName"].upper() == DEVICE_NAME,
           "Refusing deployment: Dell is not uniquely listed as managed")
    device = items[0]
    ensure(device.get("managementAgent", "").lower() == "mdm",
           "Refusing deployment: Dell not managed by MDM")
    ensure(device.get("complianceState", "").lower() == "compliant",
           "Refusing deployment: Dell not currently compliant")
    azure_id = device.get("azureADDeviceId")
    ensure(azure_id and azure_id != "00000000-0000-0000-0000-000000000000",
           "No Entra device ID returned")
    found = call("GET", "/devices", token, params={"$filter": f"deviceId eq '{azure_id}'",
                                                     "$select": "id,deviceId,displayName"})
    matches = [x for x in found.get("value", []) if x.get("deviceId", "").lower() == azure_id.lower()]
    ensure(len(matches) == 1, "Dell device has no unique Entra directory object")
    return matches[0]["id"]


def members(token, group_id):
    value = call("GET", f"/groups/{group_id}/members", token, params={"$select": "id"})["value"]
    return {r["id"].lower() for r in value}


def ensure_private_group(token, device_id):
    result = call("GET", "/groups", token, params={"$filter": f"displayName eq '{GROUP_NAME}'",
             "$select": "id,displayName,securityEnabled,mailEnabled"})
    found = [x for x in result.get("value", []) if x.get("displayName") == GROUP_NAME]
    ensure(len(found) <= 1, "Multiple matching pilot groups: manual reconciliation needed")
    if found:
        ensure(found[0].get("securityEnabled") and not found[0].get("mailEnabled"),
               "Existing group is not a dedicated security group")
        ensure(found[0].get("id", "").lower() == KNOWN_PILOT_GROUP_ID,
               "Unexpected group ID; refusing to target another group")
        group_id = found[0]["id"]
    else:
        group = call("POST", "/groups", token, {
            "displayName": GROUP_NAME,
            "description": "Doxa app-only evaluation; restricted to MARIUS-DELL; do not add other devices",
            "mailEnabled": False, "mailNickname": GROUP_ALIAS,
            "securityEnabled": True, "groupTypes": []})
        group_id = group["id"]
        print("CREATED_PILOT_GROUP=" + group_id, flush=True)
    actual = members(token, group_id)
    ensure(actual.issubset({device_id.lower()}), "Pilot group contains other members: refusing any app assignment")
    if not actual:
        call("POST", f"/groups/{group_id}/members/$ref", token,
             {"@odata.id": GRAPH + "/directoryObjects/" + device_id})
    for _ in range(8):
        actual = members(token, group_id)
        if actual == {device_id.lower()}:
            return group_id
        time.sleep(5)
    raise RuntimeError("Pilot group Dell-only membership was not yet confirmed")


def create_app(token, file, encrypted, clear_size):
    existing = call("GET", "/deviceAppManagement/mobileApps", token,
                    params={"$filter": f"displayName eq '{APP_NAME}'", "$select": "id,displayName,publishingState"})
    found = existing.get("value", [])
    ensure(len(found) <= 1, "More than one named pilot app; refuse to proceed")
    if found:
        ensure(found[0].get("id", "").lower() == KNOWN_PILOT_APP_ID,
               "Existing app is not the exact original Microsoft-created Doxa pilot")
        current = call("GET", f"/deviceAppManagement/mobileApps/{KNOWN_PILOT_APP_ID}", token)
        ensure(current.get("displayName") == APP_NAME and
               current.get("publisher") == "DMR Ergonomics SRL (Standivarius)" and
               current.get("@odata.type", "").endswith("win32LobApp") and
               "DoxaPilot.ps1" in current.get("installCommandLine", "") and
               current.get("publishingState") == "notPublished" and
               not current.get("committedContentVersion"),
               "Existing Intune app is changed or already published; manual reconciliation required")
        assignments = call("GET", f"/deviceAppManagement/mobileApps/{KNOWN_PILOT_APP_ID}/assignments", token)
        ensure(not assignments.get("value"), "Existing Doxa pilot has assignments; refusing mutation")
        print("REUSING_UNPUBLISHED_PILOT_APP=" + KNOWN_PILOT_APP_ID, flush=True)
        return KNOWN_PILOT_APP_ID
    script = (ROOT / "enterprise-intune-pilot" / "DoxaPilot.ps1").read_bytes()
    ensure(b"Get-FileHash" in script and b"'Detect'" in script,
           "Expected content-hash detection script missing")
    rule = {"@odata.type": "#microsoft.graph.win32LobAppPowerShellScriptRule",
            "ruleType": "detection", "scriptContent": base64.b64encode(script).decode("ascii"),
            "enforceSignatureCheck": False, "runAs32Bit": False}
    body = {"@odata.type": "#microsoft.graph.win32LobApp",
            "displayName": APP_NAME,
            "description": "Doxa installer APP ONLY pilot on MARIUS-DELL; no Silicon Motion driver, AI disabled by default, unsigned; NOT FOR PRODUCTION",
            "publisher": "DMR Ergonomics SRL (Standivarius)",
            "notes": "Restricted temporary test; assign exclusively to private Dell group",
            "installCommandLine": "powershell.exe -NoProfile -NonInteractive -File .\\DoxaPilot.ps1 -Action Install",
            "uninstallCommandLine": "powershell.exe -NoProfile -NonInteractive -File .\\DoxaPilot.ps1 -Action Uninstall",
            "setupFilePath": "DoxaPilot.ps1",
            # Required LOB package identity from Detection.xml (not the setup script name).
            "fileName": "IntunePackage.intunewin",
            "allowedArchitectures": "x64",
            # Use v1.0 minimumSupportedWindowsRelease as documented in the create API.
            "minimumSupportedWindowsRelease": "Windows11_23H2",
            "rules": [rule],
            "installExperience": {"@odata.type": "microsoft.graph.win32LobAppInstallExperience",
                                  "runAsAccount": "system", "deviceRestartBehavior": "suppress"},
            "returnCodes": [{"@odata.type":"microsoft.graph.win32LobAppReturnCode",
                             "returnCode":0,"type":"success"}]}
    app = call("POST", "/deviceAppManagement/mobileApps", token, body)
    print("CREATED_PILOT_APP="+app["id"],flush=True)
    return app["id"]


def upload_azure_blocks(sas, encrypted):
    """Azure Put Block/Put Block List, as in Microsoft's Win32 Intune uploader.
    A single Put Blob succeeded HTTP-wise but failed the actual Intune commit.
    Never output the SAS URI; only assert the final uploaded byte count.
    """
    ensure(sas.startswith("https://") and "?" in sas, "Invalid Azure SAS URI")
    ensure(len(encrypted) > 48, "Not an encrypted Intune package")
    BLOCK_SIZE = 4 * 1024 * 1024
    block_ids = []
    for i, start in enumerate(range(0, len(encrypted), BLOCK_SIZE)):
        block_id = base64.b64encode(f"{i:08d}".encode("ascii")).decode("ascii")
        block_ids.append(block_id)
        separator = "&" if "?" in sas else "?"
        url = sas + separator + urllib.parse.urlencode(
            {"comp": "block", "blockid": block_id})
        response = SESSION.put(url, data=encrypted[start:start+BLOCK_SIZE],
                               headers={"x-ms-version": "2020-10-02",
                                        "Content-Type": "application/octet-stream"},
                               timeout=100)
        ensure(response.status_code == 201, "Azure block upload failed HTTP " + str(response.status_code))
    # Commit the ordered list of uploaded blocks (distinct from Intune Graph /commit).
    xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>' + "".join(
        "<Latest>" + b + "</Latest>" for b in block_ids) + "</BlockList>"
    uri = sas + "&comp=blocklist"
    result = SESSION.put(uri, data=xml.encode("utf-8"),
                         headers={"Content-Type": "application/xml",
                                  "x-ms-version": "2020-10-02"}, timeout=100)
    ensure(result.status_code == 201, "Azure block list commit failed HTTP " + str(result.status_code))
    head = SESSION.head(sas, headers={"x-ms-version": "2020-10-02"}, timeout=30)
    ensure(head.status_code == 200, "Azure uploaded blob HEAD failed HTTP " + str(head.status_code))
    actual = int(head.headers.get("Content-Length", "-1"))
    ensure(actual == len(encrypted),
           f"Azure blob size mismatch: expected {len(encrypted)} bytes; actual {actual}")
    print("AZURE_BLOCK_UPLOAD_VERIFIED_BYTES=" + str(actual), flush=True)


def upload_app(token, app_id, encrypted, clear_size, crypto):
    url = f"/deviceAppManagement/mobileApps/{app_id}/microsoft.graph.win32LobApp"
    cv = call("POST", url + "/contentVersions", token,
              {"@odata.type":"#microsoft.graph.mobileAppContent"})
    version = str(cv["id"])
    file = call("POST", url + f"/contentVersions/{version}/files", token,
                {"@odata.type":"#microsoft.graph.mobileAppContentFile",
                 "name":"IntunePackage.intunewin", "size":clear_size,
                 "sizeEncrypted":len(encrypted), "isDependency":False})
    key = url + f"/contentVersions/{version}/files/{file['id']}"
    sas = None
    for _ in range(25):
        state = call("GET", key, token)
        if state.get("azureStorageUri"):
            sas = state["azureStorageUri"]
            break
        ensure("failed" not in str(state.get("uploadState", "")).lower(), "Azure upload URI failed")
        time.sleep(5)
    ensure(sas, "Microsoft never supplied an Azure Storage upload URI")
    upload_azure_blocks(sas, encrypted)
    # Azure Blob block-list is committed before asking Intune to decrypt and verify.
    time.sleep(5)
    call("POST", key + "/commit", token, {"fileEncryptionInfo": {
        "@odata.type": "microsoft.graph.fileEncryptionInfo", **crypto}})
    for _ in range(35):
        state = call("GET", key, token)
        s = str(state.get("uploadState", ""))
        if s == "commitFileSuccess":
            break
        ensure("fail" not in s.lower(), "Intune package commitment failed: " + s)
        time.sleep(5)
    else:
        raise RuntimeError("Intune content-file commitment confirmation timed out")
    call("PATCH", f"/deviceAppManagement/mobileApps/{app_id}", token, {"committedContentVersion":version})
    for _ in range(20):
        app = call("GET", f"/deviceAppManagement/mobileApps/{app_id}", token)
        if app.get("publishingState") == "published":
            print("PILOT_APP_PUBLISHED=true", flush=True)
            return
        time.sleep(5)
    raise RuntimeError("Intune app not published in time: do not assign")


def assign_only_dell(token, app_id, group_id, device_id):
    ensure(members(token, group_id) == {device_id.lower()}, "Pilot membership changed; refusing assignment")
    app = call("GET", f"/deviceAppManagement/mobileApps/{app_id}", token)
    ensure(app.get("publishingState") == "published", "App not published")
    current = call("GET", f"/deviceAppManagement/mobileApps/{app_id}/assignments", token)
    ensure(not current.get("value"), "Existing app assignments: refusing overwrite")
    call("POST", f"/deviceAppManagement/mobileApps/{app_id}/assign", token,
         {"mobileAppAssignments":[{"@odata.type":"#microsoft.graph.mobileAppAssignment",
            "intent":"required", "target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget",
                                            "groupId":group_id}}]})
    print("PILOT_GROUP_ONLY_REQUIRED_ASSIGNMENT=true", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true", help="Mutates only dedicated Doxa pilot app and Dell-only security group")
    args = parser.parse_args()
    file, encrypted, clear_size, crypto = read_package()
    ensure(file.stat().st_size < 1024*1024, "Unexpected large pilot content")
    print("DOXA_APP_ONLY_PACKAGE=" + str(file), flush=True)
    print("PACKAGE_SHA256=" + sha256_bytes(file.read_bytes()), flush=True)
    print("ENCRYPTED_CONTENT_BYTES=" + str(len(encrypted)), flush=True)
    print("TARGET_DEVICE=" + DEVICE_NAME, flush=True)
    print("ASSIGNMENT_SCOPE=DEDICATED_ONE_DEVICE_GROUP_ONLY", flush=True)
    if not args.execute:
        print("DRY_RUN_SUCCESS_NO_MICROSOFT_AUTH_OR_WRITES", flush=True)
        return
    tenant=tenant_id()
    token=auth(tenant)
    try:
        device_id=get_one_device(token)
        print("DELL_UNIQUELY_MANAGED_COMPLIANT=true",flush=True)
        group_id=ensure_private_group(token,device_id)
        app_id=create_app(token,file,encrypted,clear_size)
        upload_app(token,app_id,encrypted,clear_size,crypto)
        assign_only_dell(token,app_id,group_id,device_id)
        print("PILOT_DEPLOYMENT_REQUESTED=true",flush=True)
        print("DEVICE_MANAGEMENT_POLICY_CHANGED=false",flush=True)
    finally:
        token=None
        SESSION.headers.clear()


if __name__=="__main__":
    try:
        main()
    except Exception as exc:
        print("DOXA_INTUNE_PUBLISH_STOPPED="+str(exc), file=sys.stderr, flush=True)
        raise SystemExit(1)
