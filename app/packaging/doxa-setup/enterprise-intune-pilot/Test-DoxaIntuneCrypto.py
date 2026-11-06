"""Offline verification of Microsoft Intune ProfileVersion1 .intunewin encryption metadata.
Does not print secrets or upload/read anything from the network.
"""
import base64
import hashlib
import hmac
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[4]
paths=sorted((root/'artifacts/releases/intune').glob('doxa-intune-app-only-*/DoxaPilot.intunewin'),key=lambda p:p.stat().st_mtime,reverse=True)
assert len(paths)>0
with zipfile.ZipFile(paths[0]) as z:
    encrypted=z.read('IntuneWinPackage/Contents/IntunePackage.intunewin')
    xml=ET.fromstring(z.read('IntuneWinPackage/Metadata/Detection.xml'))
info=xml.find('EncryptionInfo')
assert info is not None
values={child.tag:child.text for child in info}
keys={k:base64.b64decode(values[k],validate=True) for k in ('EncryptionKey','MacKey','InitializationVector','Mac','FileDigest')}
for k in keys:
    assert keys[k],k
assert values['ProfileIdentifier']=='ProfileVersion1'
assert values['FileDigestAlgorithm']=='SHA256'
print('ENCRYPTED_LENGTH='+str(len(encrypted)))
print('PLAINTEXT_SIZE_METADATA='+str(xml.findtext('UnencryptedContentSize')))
print('BASE64_FIELD_LENGTHS='+str({key:len(val) for key,val in keys.items()}))
checks={
  'META_IV_EQUALS_CONTENT_IV': hmac.compare_digest(keys['InitializationVector'],encrypted[32:48]),
  'META_MAC_EQUALS_CONTENT_MAC': hmac.compare_digest(keys['Mac'],encrypted[:32]),
  'CALCULATED_HMAC_EQUALS_CONTENT_MAC': hmac.compare_digest(
      hmac.new(keys['MacKey'],encrypted[32:],hashlib.sha256).digest(),encrypted[:32]),
  'FILE_DIGEST_LENGTH_32': len(keys['FileDigest'])==32,
  'ENCRYPTION_KEY_LENGTH_32': len(keys['EncryptionKey'])==32,
}
for label,passed in checks.items():
    print(label+'='+str(passed))
assert all(checks.values()), 'Local .intunewin encryption metadata verification failed'
print('INTUNE_CRYPTO_INTEGRITY=PASS')
