param(
 [ValidateSet('Install','Uninstall','Detect','Upgrade')][string]$Action='Detect',
 [string]$TargetRoot='',
 [string]$PayloadPath='',
 [string]$ExpectedVersion=''
)
# Intune Win32 PILOT: installs Doxa Setup application only; no vendor driver,
# no display modifications, no credentials, no reboot.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not $TargetRoot){$pf=if($env:ProgramW6432){$env:ProgramW6432}else{$env:ProgramFiles};$TargetRoot=Join-Path $pf 'Standivarius\DoxaSetup'}
if(-not $PayloadPath){$PayloadPath=Join-Path $PSScriptRoot 'DoxaSetupPayload.zip'}
$target=[IO.Path]::GetFullPath($TargetRoot)
# Use the built-in .NET SHA-256 implementation, independent of Get-FileHash
# cmdlet discovery in machine-run PowerShell 5.1 or restricted agent sessions.
function Get-DoxaSha256([string]$file) {
 $sha=[System.Security.Cryptography.SHA256]::Create()
 $stream=$null
 try{
  $stream=[System.IO.File]::Open($file,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
  $digest=$sha.ComputeHash($stream)
  return ([System.BitConverter]::ToString($digest)).Replace('-','')
 }finally{
  if($null -ne $stream){$stream.Dispose()}
  $sha.Dispose()
 }
}
function PayloadRejected([string]$code) {
 if($env:DOXA_PILOT_DIAGNOSTICS -eq '1'){
  [Console]::Error.WriteLine('DOXA_INTEGRITY_REASON: '+$code)
 }
 return $false
}
function IsInstalled([string]$folder) {
 $manifestPath=Join-Path $folder 'manifest.json'
 if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){return (PayloadRejected 'manifest_absent')}
 try{
  $m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$m.product -cne 'Standivarius Doxa Setup' -or @($m.files).Count -notin @(16,20)){return (PayloadRejected 'schema_or_filecount')}
   $versionField=$m.PSObject.Properties['preview_version']
   if($null -eq $versionField -and @($m.files).Count -eq 16){
    if([string]$m.channel -cne 'personal-preview'){return (PayloadRejected 'invalid_legacy_channel')}
   }elseif([string]$m.preview_version -notmatch '^0\.4\.0-preview\.[0-9]+$'){return (PayloadRejected 'invalid_version')}
   if(@($m.files).Count -eq 20){
    $allowedV11=@(
     'app/packaging/doxa-setup/Get-DoxaDriverState.ps1',
     'app/packaging/doxa-setup/profiles/smi770-observed.json',
     'app/packaging/doxa-setup/knowledge/entries.json',
     'app/packaging/doxa-setup/knowledge/scope-policy.json',
     'app/packaging/doxa-setup/assistant/client-public-key.json',
     'app/packaging/doxa-setup/personal-ui/Start-DoxaSetup.ps1',
     'app/packaging/doxa-setup/personal-ui/Doxa-BrandTabs.ps1',
     'app/packaging/doxa-setup/personal-ui/assets/standivarius-official-logo.png',
     'app/packaging/doxa-setup/personal-ui/Start-DoxaGuidedSetup.ps1',
     'app/packaging/doxa-setup/personal-ui/Get-DoxaCloudAIPolicy.ps1',
     'app/packaging/doxa-setup/personal-ui/AI-PRIVACY-NOTICE.txt',
     'app/packaging/doxa-setup/personal-ui/LOCAL-CHECK-NOTICE.txt',
     'app/packaging/doxa-setup/personal-ui/Show-DoxaConnectionGuide.ps1',
     'app/packaging/doxa-setup/personal-ui/Get-DoxaCompatibility.ps1',
     'app/packaging/doxa-setup/personal-ui/Get-DoxaSetupExperience.ps1',
     'app/packaging/doxa-setup/personal-ui/Get-DoxaKnowledgeAnswer.ps1',
     'app/packaging/doxa-setup/personal-ui/Ask-DoxaInstaller.ps1',
     'app/packaging/doxa-setup/personal-ui/Get-DoxaDeviceSignature.ps1',
     'app/packaging/doxa-setup/personal-ui/Test-DoxaPackageGate.ps1',
     'app/packaging/doxa-setup/personal-ui/Invoke-DoxaPersonalInstallation.ps1'
    )
    foreach($expected in $allowedV11){if(@($m.files.file) -cnotcontains $expected){return (PayloadRejected 'unapproved_version11_payload')}}
    if(@($m.files.file|Select-Object -Unique).Count -ne 20){return (PayloadRejected 'duplicate_source')}
   }
  $allowed=@((Join-Path $folder 'manifest.json'))
  foreach($f in @($m.files)){
   $rel=[string]$f.file
   if($rel -notmatch '^app/packaging/doxa-setup/(?:[A-Za-z0-9._-]+|(?:personal-ui|assistant|knowledge|profiles)/[A-Za-z0-9._-]+|personal-ui/assets/standivarius-official-logo\.png)$'){return (PayloadRejected 'unexpected_source_path')}
   $path=[IO.Path]::GetFullPath((Join-Path $folder ($rel.Replace('/','\'))))
   if(-not $path.StartsWith(([IO.Path]::GetFullPath($folder).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)){return (PayloadRejected 'path_escape')}
   if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return (PayloadRejected 'missing_source')}
   if((Get-DoxaSha256 $path) -ine [string]$f.sha256){return (PayloadRejected 'source_hash')}
   $allowed+=,$path
  }
  $generated=@($m.generated_files)
  if($generated.Count -ne 2){return (PayloadRejected 'generated_count')}
  $names=@($generated|ForEach-Object {[string]$_.file})
  if($names -notcontains 'Open Doxa Setup.cmd' -or $names -notcontains 'README-FIRST.txt'){return (PayloadRejected 'generated_names')}
  foreach($g in $generated){
   $path=Join-Path $folder ([string]$g.file)
   if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return (PayloadRejected 'generated_missing')}
   if((Get-DoxaSha256 $path) -ine [string]$g.sha256){return (PayloadRejected 'generated_hash')}
   $allowed+=,$path
  }
  # A valid manifest is insufficient if the unpacked payload contains extra files.
  # Keep detection and removal confined to the approved version-specific source list plus two generated files.
  $actual=@(Get-ChildItem -LiteralPath $folder -File -Recurse -ErrorAction Stop)
  if($actual.Count -ne $allowed.Count){return (PayloadRejected 'actual_count')}
  foreach($item in $actual){
   if($allowed -notcontains $item.FullName){return (PayloadRejected 'unexpected_file')}
   if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){return (PayloadRejected 'reparse_point')}
  }
  return $true
 }catch{
  if($env:DOXA_PILOT_DIAGNOSTICS -eq '1'){
   [Console]::Error.WriteLine('DOXA_INTEGRITY_EXCEPTION_CLASS: '+$_.Exception.GetType().Name)
   [Console]::Error.WriteLine('DOXA_INTEGRITY_EXCEPTION_LINE: '+[string]$_.InvocationInfo.ScriptLineNumber)
  }
  return (PayloadRejected 'unexpected_error')
 }
}
# The frozen first managed pilot had no preview_version. Only a verified
# 16-file personal-preview manifest may carry this legacy identity.
function Get-AppVersion([string]$folder){
 $m=Get-Content -LiteralPath (Join-Path $folder 'manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if($m.PSObject.Properties['preview_version']){return [string]$m.preview_version}
 if(@($m.files).Count -eq 16 -and [string]$m.channel -ceq 'personal-preview'){return 'legacy-16'}
 throw 'Unrecognised legacy package version'
}
if($Action -eq 'Detect'){
 if(IsInstalled $target){
   $installed=Get-AppVersion $target
   if($ExpectedVersion -and $ExpectedVersion -ne $installed){exit 1}
   'DETECTED:DoxaSetupPilot';exit 0
  }
 exit 1
}
if($Action -eq 'Uninstall'){
 if(-not(Test-Path -LiteralPath $target)){'ALREADY_REMOVED';exit 0}
 $manifestPath=Join-Path $target 'manifest.json'
 if(-not(Test-Path -LiteralPath $manifestPath)){[Console]::Error.WriteLine('Refusing to delete unrecognized directory');exit 33}
 try{$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json}
 catch{[Console]::Error.WriteLine('Invalid manifest');exit 33}
 if([string]$manifest.product -cne 'Standivarius Doxa Setup' -or -not(IsInstalled $target)){
  [Console]::Error.WriteLine('Refusing to remove an altered or unrecognized Doxa directory');exit 33
 }
 try{Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop;'REMOVED:DoxaSetupPilot';exit 0}
 catch{[Console]::Error.WriteLine('Could not remove Doxa pilot files');exit 35}
}
$wasInstalled=IsInstalled $target
if($Action -eq 'Upgrade'){
 if(-not $wasInstalled){[Console]::Error.WriteLine('Upgrade requires an intact recognised installation');exit 32}
}else{
 if($wasInstalled){
  if(-not(Test-Path -LiteralPath $PayloadPath -PathType Leaf)){[Console]::Error.WriteLine('Payload missing');exit 21}
  try{$desired=Get-AppVersion $target
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $a=[IO.Compression.ZipFile]::OpenRead($PayloadPath)
   try{$me=$a.GetEntry('manifest.json');if(-not $me){throw 'Manifest absent'};$rd=New-Object IO.StreamReader($me.Open());try{$newManifest=$rd.ReadToEnd()|ConvertFrom-Json
    $incoming=if($newManifest.PSObject.Properties['preview_version']){[string]$newManifest.preview_version}elseif(@($newManifest.files).Count -eq 16){'legacy-16'}else{throw 'Version missing'}}finally{$rd.Dispose()}}finally{$a.Dispose()}
  }catch{[Console]::Error.WriteLine('Unable to establish package version');exit 30}
  if($desired -ne $incoming){[Console]::Error.WriteLine('Different installed version; use controlled -Action Upgrade');exit 32}
  'ALREADY_INSTALLED:DoxaSetupPilot';exit 0
 }
 if(Test-Path -LiteralPath $target){[Console]::Error.WriteLine('Existing target differs; no automatic overwrite');exit 32}
}
if(-not(Test-Path -LiteralPath $PayloadPath -PathType Leaf)){[Console]::Error.WriteLine('Payload missing');exit 21}
$parent=Split-Path -Parent $target
$staging=Join-Path $parent ('doxa-pilot-stage-'+[Guid]::NewGuid().ToString('N'))
try{
 if(-not(Test-Path -LiteralPath $parent)){New-Item -Path $parent -ItemType Directory -Force|Out-Null}
 Expand-Archive -LiteralPath $PayloadPath -DestinationPath $staging -ErrorAction Stop
 if(-not(IsInstalled $staging)){throw 'Bundle manifest or source hashes failed'}
 $forbidden=@(Get-ChildItem -LiteralPath $staging -Recurse -File|Where-Object {$_.Extension -in @('.msi','.sys','.cat','.pfx','.key','.dpapi','.dll')})
 if($forbidden.Count){throw 'Driver or secret files not allowed'}
 if($Action -eq 'Upgrade'){
  $oldVersion=Get-AppVersion $target
  $newVersion=Get-AppVersion $staging
  if($oldVersion -eq $newVersion){'ALREADY_INSTALLED:DoxaSetupPilot';exit 0}
  $oldNumeric=if($oldVersion -eq 'legacy-16'){-1}else{[int]($oldVersion -replace '^0\.4\.0-preview\.','')}
  $newNumeric=if($newVersion -eq 'legacy-16'){-1}else{[int]($newVersion -replace '^0\.4\.0-preview\.','')}
  if($newNumeric -le $oldNumeric){throw 'Downgrades require a separately reviewed rollback procedure'}
  if($ExpectedVersion -and $ExpectedVersion -ne $newVersion){throw 'Requested target version differs from payload'}
  $backup=Join-Path $parent ('doxa-pilot-backup-'+[Guid]::NewGuid().ToString('N'))
  Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
  try{
   Move-Item -LiteralPath $staging -Destination $target -ErrorAction Stop
   if(-not(IsInstalled $target)){throw 'Installed upgrade did not pass integrity validation'}
  }catch{
   if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop}
   Move-Item -LiteralPath $backup -Destination $target -ErrorAction Stop
   throw 'Upgrade failed; previous app restored'
  }
  if(Test-Path -LiteralPath $backup){Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop}
  'UPGRADED:DoxaSetupPilot'
 }else{
  if($ExpectedVersion){
   $newVersion=(Get-Content -LiteralPath (Join-Path $staging 'manifest.json') -Raw|ConvertFrom-Json).preview_version
   if($newVersion -ne $ExpectedVersion){throw 'Unexpected application version'}
  }
  Move-Item -LiteralPath $staging -Destination $target -ErrorAction Stop
  'INSTALLED:DoxaSetupPilot'
 }
 exit 0
}catch{
 [Console]::Error.WriteLine('Doxa pilot install refused: '+$_.Exception.Message)
 exit 30
}finally{
 if(Test-Path -LiteralPath $staging){Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue}
}
