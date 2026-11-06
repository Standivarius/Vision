"""App-only Doxa managed upgrade acceptance: old intact package -> new approved package.
All operations use a disposable temp directory; never the system installation."""
import argparse, json, os, pathlib, subprocess, tempfile, zipfile

parser=argparse.ArgumentParser()
parser.add_argument('--old',required=True,help='verified preview10 source ZIP')
parser.add_argument('--new',required=True,help='verified preview11 source ZIP')
parser.add_argument('--script',required=True)
args=parser.parse_args()
ps=os.path.join(os.environ.get('WINDIR',r'C:\Windows'),'System32','WindowsPowerShell','v1.0','powershell.exe')
script=pathlib.Path(args.script)
old=pathlib.Path(args.old)
new=pathlib.Path(args.new)
for p in (script,old,new):assert p.is_file(),p
def version(path):
 with zipfile.ZipFile(path) as z:return json.loads(z.read('manifest.json')).get('preview_version','legacy-16')
old_version=version(old)
new_version=version(new)
assert old_version!=new_version,(old_version,new_version)
with tempfile.TemporaryDirectory(prefix='DoxaManagedUpgrade-') as t:
 target=pathlib.Path(t)/'Doxa-app'
 def act(action,payload=None,expect=None):
  cmd=[ps,'-NoProfile','-NonInteractive','-File',str(script),'-Action',action,'-TargetRoot',str(target)]
  if payload:cmd+=['-PayloadPath',str(payload)]
  if expect:cmd+=['-ExpectedVersion',expect]
  res=subprocess.run(cmd,capture_output=True,text=True,timeout=65)
  return {'action':action,'exit':res.returncode,'stdout':res.stdout.strip(),'stderr':res.stderr.strip()[-230:]}
 def current_version():
  return json.loads((target/'manifest.json').read_text(encoding='utf-8-sig')).get('preview_version','legacy-16')
 steps=[]
 def expect(action,exit_code,payload=None,version_arg=None,contents=None):
  x=act(action,payload,version_arg);steps.append(x)
  assert x['exit']==exit_code,x
  if contents is not None:assert contents in x['stdout'],x
  return x
 expect('Install',0,old,contents='INSTALLED')
 assert current_version()==old_version
 expect('Detect',0,version_arg=old_version)
 expect('Detect',1,version_arg=new_version)
 expect('Install',32,new)
 assert current_version()==old_version,'Unexpected automatic overwrite'
 expect('Upgrade',0,new,new_version,'UPGRADED')
 assert current_version()==new_version
 expect('Detect',0,version_arg=new_version)
 expect('Upgrade',0,new,new_version,'ALREADY_INSTALLED')
 extra=target/'company-file.txt'
 extra.write_text('protect')
 expect('Upgrade',32,old,old_version)
 assert extra.read_text()=='protect' and current_version()==new_version
 extra.unlink()
 expect('Uninstall',0,contents='REMOVED')
 expect('Detect',1)
 print(json.dumps({'status':'PASS','old_version':old_version,'new_version':new_version,'steps':steps,'driver_changes':False,'outside_temp_changes':False}))
