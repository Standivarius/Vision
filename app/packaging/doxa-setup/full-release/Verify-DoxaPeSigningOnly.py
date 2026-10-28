"""Verify signing did not change Doxa executable code or embedded payload.
Standard Python only. Excludes only the Authenticode certificate table,
security-directory entry and Windows PE checksum (the three signing changes).
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

def normalized(path: Path):
    data=bytearray(path.read_bytes())
    assert data[:2]==b"MZ", "Not a PE executable"
    peoff=struct.unpack_from("<I",data,0x3C)[0]
    assert peoff+256<len(data) and data[peoff:peoff+4]==b"PE\0\0", "Bad PE header"
    opt=peoff+24
    magic=struct.unpack_from("<H",data,opt)[0]
    assert magic in (0x10B,0x20B), "Unsupported PE optional header"
    check=opt+64
    directory=opt+(112 if magic==0x20B else 96)
    security=directory+8*4
    certoffset,certsize=struct.unpack_from("<II",data,security)
    # Signing updates the PE checksum and IMAGE_DIRECTORY_ENTRY_SECURITY,
    # and appends one WinCertificate table on an eight-byte boundary.
    data[check:check+4]=bytes(4)
    data[security:security+8]=bytes(8)
    if certoffset or certsize:
        assert certoffset and certsize and certoffset%8==0, "Malformed certificate table"
        assert certoffset+certsize==len(data), "Certificate not at PE end; unexpected trailing data"
        del data[certoffset:]
    return hashlib.sha256(data).hexdigest().upper(),bool(certsize)

def compare(unsigned: Path, signed: Path,require_signature=True):
    before,oldcert=normalized(unsigned)
    after,newcert=normalized(signed)
    assert not oldcert, "Reference release must not be pre-signed"
    if require_signature:assert newcert, "Final file has no Authenticode certificate"
    assert before==after, "Windows code/resources were modified, not merely signed"
    return {"unsigned_reference_sha256_without_signature":before,
            "signed_source_matches":True,"signature_certificate_present":newcert}

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--unsigned-personal",type=Path,required=True)
    p.add_argument("--signed-personal",type=Path,required=True)
    p.add_argument("--unsigned-managed",type=Path,required=True)
    p.add_argument("--signed-managed",type=Path,required=True)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    result={
       "personal":compare(a.unsigned_personal,a.signed_personal,not a.self_test),
       "managed":compare(a.unsigned_managed,a.signed_managed,not a.self_test),
       "status":"PASS"
    }
    print(json.dumps(result,indent=2))
if __name__=="__main__":main()
