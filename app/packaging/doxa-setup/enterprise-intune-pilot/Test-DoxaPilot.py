import os, tempfile, subprocess, json, pathlib, hashlib, argparse, zipfile, shutil
base=pathlib.Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument("--script",default=str(base/"DoxaPilot.ps1"))
parser.add_argument("--payload",default=str(base/"DoxaSetupPayload.zip"))
opts=parser.parse_args()
script=pathlib.Path(opts.script).resolve()
payload=pathlib.Path(opts.payload).resolve()
assert script.is_file() and payload.is_file()
ps=os.path.join(os.environ.get("WINDIR","C:\\Windows"),"System32","WindowsPowerShell","v1.0","powershell.exe")
with tempfile.TemporaryDirectory(prefix="DoxaEnterprisePilotTest-") as tmp:
    target=pathlib.Path(tmp)/"Installed Doxa Setup"
    def run(action, payload_override=None):
        chosen_payload=payload_override if payload_override is not None else payload
        res=subprocess.run([ps,"-NoProfile","-NonInteractive","-File",str(script),"-Action",action,"-TargetRoot",str(target),"-PayloadPath",str(chosen_payload)],capture_output=True,text=True,timeout=50,env={**os.environ,"DOXA_PILOT_DIAGNOSTICS":"1"})
        # Keep deterministic, non-sensitive diagnostic code and exception type visible
        # even if a long stderr message would otherwise truncate their start.
        codes = [line.strip() for line in res.stderr.splitlines()
                 if line.startswith("DOXA_INTEGRITY_")]
        summary = " | ".join(codes)[-450:] if codes else res.stderr.strip()[-150:]
        return {"action":action,"exit":res.returncode,
                "out":res.stdout.strip()[-150:],"err":summary}
    steps=[]
    steps.append(run("Detect"));assert steps[-1]["exit"]==1,steps[-1]
    steps.append(run("Install"));assert steps[-1]["exit"]==0 and "INSTALLED" in steps[-1]["out"],steps[-1]
    steps.append(run("Detect"));assert steps[-1]["exit"]==0 and "DETECTED" in steps[-1]["out"],steps[-1]
    steps.append(run("Install"));assert steps[-1]["exit"]==0 and "ALREADY_INSTALLED" in steps[-1]["out"],steps[-1]
    names=[f.name.lower() for f in target.rglob("*") if f.is_file()]
    assert not [n for n in names if n.endswith((".msi",".cat",".sys",".dpapi",".pfx",".key",".dll"))]
    # A foreign file must never be silently accepted or deleted by the managed uninstaller.
    unexpected=target/"foreign-customer-file.txt"
    unexpected.write_text("must survive refusal",encoding="utf-8")
    steps.append(run("Detect"));assert steps[-1]["exit"]==1,steps[-1]
    steps.append(run("Uninstall"));assert steps[-1]["exit"]==33 and unexpected.read_text(encoding="utf-8")=="must survive refusal",steps[-1]
    unexpected.unlink()
    steps.append(run("Detect"));assert steps[-1]["exit"]==0,steps[-1]
    steps.append(run("Uninstall"));assert steps[-1]["exit"]==0 and not target.exists(),steps[-1]
    steps.append(run("Detect"));assert steps[-1]["exit"]==1,steps[-1]
    # An archive with all valid expected hashes but an unlisted executable must be rejected.
    tampered=pathlib.Path(tmp)/"tampered-extra.zip"
    shutil.copyfile(payload,tampered)
    with zipfile.ZipFile(tampered,"a") as archive:
        archive.writestr("unlisted-extra.exe",b"MZ-not-an-authorised-Doxa-file")
    steps.append(run("Install",tampered));assert steps[-1]["exit"]==30 and not target.exists(),steps[-1]
    assert any("DOXA_INTEGRITY_REASON:" in item["err"] for item in steps if item["exit"] != 0)
    print(json.dumps({"status":"PASS","test_root":"isolated_temp","driver_installation":False,"steps":steps,"payload_sha256":hashlib.sha256(payload.read_bytes()).hexdigest()}))
