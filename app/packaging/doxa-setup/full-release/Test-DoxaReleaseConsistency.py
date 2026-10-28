"""Local independent proof that Intune + ManageEngine carry exactly one native installer.
Do not contact endpoint managers or execute installers; no credentials required.
Usage: python Test-DoxaReleaseConsistency.py --release C:\\path\\to\\release
"""
import argparse
import base64
import hashlib
import hmac
import io
import json
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7

def digest(data):
    return hashlib.sha256(data).hexdigest().upper()

def verify(folder):
    deploy = (folder / "ManageEngine" / "DoxaDeploy.exe").read_bytes()
    with zipfile.ZipFile(folder / "ManageEngine" / "Doxa-Managed-Windows.zip") as z:
        if z.namelist() != ["DoxaDeploy.exe"]:
            raise AssertionError("ManageEngine archive must contain exactly one executable")
        if not hmac.compare_digest(digest(z.read("DoxaDeploy.exe")), digest(deploy)):
            raise AssertionError("ManageEngine executable differs")
    with zipfile.ZipFile(folder / "Intune" / "DoxaDeploy.intunewin") as z:
        meta = ET.fromstring(z.read("IntuneWinPackage/Metadata/Detection.xml"))
        fields = {elem.tag: elem.text for elem in meta.find("EncryptionInfo")}
        enc = z.read("IntuneWinPackage/Contents/IntunePackage.intunewin")
        assert fields["ProfileIdentifier"] == "ProfileVersion1"
        assert fields["FileDigestAlgorithm"] == "SHA256"
        keys = {k: base64.b64decode(fields[k], validate=True)
                for k in ("Mac", "MacKey", "EncryptionKey", "InitializationVector", "FileDigest")}
        assert hmac.compare_digest(keys["Mac"], enc[:32]), "Intune MAC metadata differs"
        assert hmac.compare_digest(keys["InitializationVector"], enc[32:48]), "Intune IV differs"
        assert hmac.compare_digest(hmac.new(keys["MacKey"], enc[32:], hashlib.sha256).digest(), enc[:32]), "Intune HMAC invalid"
        cipher = Cipher(algorithms.AES(keys["EncryptionKey"]), modes.CBC(keys["InitializationVector"]))
        decryptor = cipher.decryptor()
        padded = decryptor.update(enc[48:]) + decryptor.finalize()
        unpad = PKCS7(128).unpadder()
        plain = unpad.update(padded) + unpad.finalize()
        assert hmac.compare_digest(hashlib.sha256(plain).digest(), keys["FileDigest"]), "Intune decrypted archive digest differs"
        with zipfile.ZipFile(io.BytesIO(plain)) as packaged:
            found = packaged.namelist()
            assert found == ["DoxaDeploy.exe"], f"Unexpected content in Intune: {found}"
            unpacked = packaged.read("DoxaDeploy.exe")
            assert hmac.compare_digest(digest(unpacked), digest(deploy)), "Intune host differs from ManageEngine"
    person = folder / "Personal" / "DoxaSetup.exe"
    assert person.exists(), "Missing native personal installer"
    result = {
        "status": "PASS",
        "intune_mac_and_digest": "PASS",
        "intune_executable_matches_manageengine": True,
        "managed_single_executable_sha256": digest(deploy),
        "personal_setup_embedded_executable_sha256": digest(person.read_bytes()),
        "network_operations": False,
        "real_agent_deployment": "NOT_RUN",
    }
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.release), indent=2))
