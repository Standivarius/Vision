param(
 [ValidateSet('Install','Uninstall','Detect')][string]$Action='Detect',
 [string]$TargetRoot='',
 [string]$PayloadPath=''
)
# Intune Win32 PILOT: installs Doxa Setup application only; no vendor driver,
# no display modifications, no credentials, no reboot.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $TargetRoot){$pf=if($env:ProgramW6432){$env:ProgramW6432}else{$env:ProgramFiles};$TargetRoot=Join-Path $pf 'Standivarius\DoxaSetup'}
if(-not $PayloadPath){$PayloadPath=Join-Path $PSScriptRoot 'DoxaSetupPayload.zip'}
$target=[IO.Path]::GetFullPath($TargetRoot)
function IsInstalled([string]$folder) {
 $manifestPath=Join-Path $folder 'manifest.json'
 if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){return $false}
 try{
  $m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$m.product -cne 'Standivarius Doxa Setup' -or @($m.files).Count -ne 16){return $false}
  foreach($f in @($m.files)){
   $rel=[string]$f.file
   if($rel -notmatch '^app/packaging/doxa-setup/(?:[A-Za-z0-9._-]+|(?:personal-ui|assistant|knowledge|profiles)/[A-Za-z0-9._-]+)$'){return $false}
   $path=[IO.Path]::GetFullPath((Join-Path $folder ($rel.Replace('/','\'))))
   if(-not $path.StartsWith(([IO.Path]::GetFullPath($folder).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){return $false}
   if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $false}
   if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine [string]$f.sha256){return $false}
  }
  return $true
 }catch{return $false}
}
if($Action -eq 'Detect'){
 if(IsInstalled $target){'DETECTED:DoxaSetupPilot';exit 0}
 exit 1
}
if($Action -eq 'Uninstall'){
 if(-not(Test-Path -LiteralPath $target)){'ALREADY_REMOVED';exit 0}
 $manifestPath=Join-Path $target 'manifest.json'
 if(-not(Test-Path -LiteralPath $manifestPath)){[Console]::Error.WriteLine('Refusing to delete unrecognized directory');exit 33}
 try{$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json}
 catch{[Console]::Error.WriteLine('Invalid manifest');exit 33}
 if([string]$manifest.product -cne 'Standivarius Doxa Setup'){[Console]::Error.WriteLine('Not a Doxa folder');exit 33}
 try{Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop;'REMOVED:DoxaSetupPilot';exit 0}
 catch{[Console]::Error.WriteLine('Could not remove Doxa pilot files');exit 35}
}
if(IsInstalled $target){'ALREADY_INSTALLED:DoxaSetupPilot';exit 0}
if(Test-Path -LiteralPath $target){[Console]::Error.WriteLine('Existing target differs; no automatic overwrite');exit 32}
if(-not(Test-Path -LiteralPath $PayloadPath -PathType Leaf)){[Console]::Error.WriteLine('Payload missing');exit 21}
$parent=Split-Path -Parent $target
$staging=Join-Path $parent ('doxa-pilot-stage-'+[Guid]::NewGuid().ToString('N'))
try{
 if(-not(Test-Path -LiteralPath $parent)){New-Item -Path $parent -ItemType Directory -Force|Out-Null}
 Expand-Archive -LiteralPath $PayloadPath -DestinationPath $staging -ErrorAction Stop
 if(-not(IsInstalled $staging)){throw 'Bundle manifest or source hashes failed'}
 $forbidden=@(Get-ChildItem -LiteralPath $staging -Recurse -File|Where-Object {$_.Extension -in @('.msi','.sys','.cat','.pfx','.key','.dpapi','.dll')})
 if($forbidden.Count){throw 'Driver or secret files not allowed'}
 Move-Item -LiteralPath $staging -Destination $target -ErrorAction Stop
 'INSTALLED:DoxaSetupPilot'
 exit 0
}catch{
 [Console]::Error.WriteLine('Doxa pilot install refused: '+$_.Exception.Message)
 exit 30
}finally{
 if(Test-Path -LiteralPath $staging){Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue}
}
