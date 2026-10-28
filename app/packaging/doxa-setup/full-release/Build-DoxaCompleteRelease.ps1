param(
 [string]$VendorMsiPath='C:\dev\Vision\artifacts\vendor\silicon-motion\2026-09-25\msi\SMIUSBDisplaySW770.msi',
 [string]$ContentPrepTool='C:\dev\Vision\tools\intune-win32-content-prep-v1.8.7\IntuneWinAppUtil.exe',
 [string]$OutputDirectory='',
 [switch]$SkipIntune
)
# Build three release-candidate delivery formats with one binary/payload baseline.
# No driver installation, endpoint management or display changes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'artifacts\releases\complete-release-20261028'}
$expectedDriver='3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4'
if(-not(Test-Path $VendorMsiPath -PathType Leaf)){throw 'Missing known vendor MSI'}
if((Get-FileHash $VendorMsiPath -Algorithm SHA256).Hash -ne $expectedDriver){throw 'Unexpected driver package fingerprint'}
$sign=Get-AuthenticodeSignature -LiteralPath $VendorMsiPath
if($sign.Status -ne 'Valid' -or -not $sign.SignerCertificate -or $sign.SignerCertificate.Subject -notmatch 'Silicon Motion'){throw 'Driver Authenticode verification failed'}
if(-not $SkipIntune){
 $toolsign=Get-AuthenticodeSignature -LiteralPath $ContentPrepTool
 if($toolsign.Status -ne 'Valid' -or $toolsign.SignerCertificate.Subject -notmatch 'Microsoft Corporation'){throw 'Microsoft package tool not verified'}
}
$builder=Join-Path (Split-Path $PSScriptRoot -Parent) 'Build-DoxaPersonalBundle.ps1'
# PSScriptRoot = doxa-setup/full-release => parent = doxa-setup
$builder=Join-Path (Split-Path $PSScriptRoot -Parent) 'Build-DoxaPersonalBundle.ps1'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
if(Test-Path $OutputDirectory){throw 'Release destination already exists; refusing overwrite'}
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
$stage=Join-Path $env:TEMP ('DoxaFullBuild-'+[Guid]::NewGuid().ToString('N'))
$personalBuild=Join-Path $stage 'personal'
$src=Join-Path $stage 'source'
$personalDist=Join-Path $OutputDirectory 'Personal'
$managedDist=Join-Path $OutputDirectory 'ManageEngine'
$intuneDist=Join-Path $OutputDirectory 'Intune'
$test=Join-Path $OutputDirectory 'Tests'
New-Item -ItemType Directory -Path $stage,$personalBuild,$src,$personalDist,$managedDist,$test -Force|Out-Null
try{
 $app=(& $builder -OutputDirectory $personalBuild -Reproducible|Out-String)|ConvertFrom-Json
 if($app.status -ne 'created'){throw 'App build failed'}
 $appCheck=(& (Join-Path (Split-Path $PSScriptRoot -Parent) 'Test-DoxaPersonalBundle.ps1') -BundlePath $app.path|Out-String)|ConvertFrom-Json
 if($appCheck.status -ne 'PASS'){throw 'App extracted validation failed'}
 Copy-Item $app.path (Join-Path $src 'DoxaSetupPayload.zip')
 Copy-Item $VendorMsiPath (Join-Path $src 'SMIUSBDisplaySW770.msi')
 $csc='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
 if(-not(Test-Path $csc)){throw 'Windows .NET Framework C# compiler missing'}
 $source=Join-Path $PSScriptRoot 'DoxaSetupHost.cs'
 $refs=@('/nologo','/platform:x64','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:Microsoft.CSharp.dll','/reference:System.Management.dll','/reference:System.Web.Extensions.dll','/reference:System.IO.Compression.dll','/reference:System.IO.Compression.FileSystem.dll')
 foreach($name in @('DoxaSetup.exe','DoxaDeploy.exe')){
  $kind=if($name -eq 'DoxaSetup.exe'){'winexe'}else{'exe'}
  & $csc @refs ("/target:$kind") ("/out:$(Join-Path $src $name)") ("/resource:$(Join-Path $src 'SMIUSBDisplaySW770.msi'),Doxa.Driver") ("/resource:$(Join-Path $src 'DoxaSetupPayload.zip'),Doxa.App") $source
  if($LASTEXITCODE -ne 0){throw "Windows executable compilation failed: $name"}
 }
 $testRun=(& (Join-Path $src 'DoxaDeploy.exe') '/selftest'|Out-String).Trim()
 if($LASTEXITCODE -ne 0 -or $testRun -notmatch '^PASS:'){throw 'Release candidate self test failed: '+$testRun}
 $readme=@'
Standivarius Ã¢â‚¬â€ Doxa Setup for Windows
PERSONAL:
  Extract Personal/Doxa-Complete-Windows-Setup.zip and launch DoxaSetup.exe.
  Connect Doxa USB power and DATA cable. Click Install / check Doxa and approve Windows UAC.
  A healthy existing signed driver is kept; no automatic downgrade or driver removal.
  This installer performs no automatic reboot or monitor topology writes.
  Complete the remaining steps in the bilingual Doxa UI.
INTUNE:
  Upload Intune/DoxaDeploy.intunewin as a Win32 app.
  Install command: DoxaDeploy.exe /install
  Uninstall command: DoxaDeploy.exe /uninstall
  Detection: DoxaDeploy.exe /detect (return 0 only with valid installed app).
  Driver/user-session verification: DoxaDeploy.exe /verify; user-session 4-screen check separately.
  Run as SYSTEM, 64-bit, explicit IT targeting, return code 3010 = coordinated reboot.
MANAGEENGINE:
  Extract ManageEngine/Doxa-Complete-Managed.zip to an approved package repository.
  Deliver all four package files side-by-side, using DoxaDeploy.exe /install as SYSTEM.
  Detect / verify / uninstall as for Intune.
SIGNING:
  Sign the generated DoxaSetup.exe and DoxaDeploy.exe using the publisher certificate,
  timestamp and verify their Authenticode signatures. Signing changes their file checksums;
  reissue distribution archives and manifests AFTER signing. Do not remove the existing
  vendor signature from the vendor MSI.
STATUS:
  This is a private unsigned release CANDIDATE. Source and package checks have passed.
  Do not mark full customer release passed without attended hardware installation,
  user-session graphics acceptance, managed-agent execution and signature verification.
'@
 [IO.File]::WriteAllText((Join-Path $src 'README-FIRST.txt'),$readme,[Text.UTF8Encoding]::new($false))
 $srcFiles=@(Get-ChildItem $src -File)
 if($srcFiles.Count -ne 5){throw 'Incorrect distribution source-file count'}
 foreach($file in $srcFiles){if($file.Name -match '(\.env|\.pfx|\.key|token|secret)'){throw 'Secret-like file in release'}}
 $personalZip=Join-Path $personalDist 'Doxa-Complete-Windows-Setup.zip'
 $managedZip=Join-Path $managedDist 'Doxa-Complete-Managed.zip'
 Compress-Archive -LiteralPath @($srcFiles.FullName) -DestinationPath $personalZip -CompressionLevel Optimal
 Compress-Archive -LiteralPath @($srcFiles.FullName) -DestinationPath $managedZip -CompressionLevel Optimal
 $intunePath=''
 if(-not $SkipIntune){
  New-Item $intuneDist -ItemType Directory -Force|Out-Null
  & $ContentPrepTool -c $src -s 'DoxaDeploy.exe' -o $intuneDist -q *> (Join-Path $test 'MicrosoftContentPrep.log')
  if($LASTEXITCODE -ne 0){throw 'Microsoft Win32 prep tool failed'}
  $intune=@(Get-ChildItem $intuneDist -File -Filter '*.intunewin')
  if($intune.Count -ne 1){throw 'Missing Intune content file'}
  $intunePath=$intune[0].FullName
 }
 $appCheck|ConvertTo-Json -Depth 8|Set-Content (Join-Path $test 'app-extracted-check.json')
 $result=[ordered]@{
  status='REVIEW_BUILD_PASS'
  source_commit=((& git -C $root rev-parse HEAD)|Out-String).Trim()
  tested_app_payload_sha256=(Get-FileHash (Join-Path $src 'DoxaSetupPayload.zip') -Algorithm SHA256).Hash
  vendor_msi_signature='Valid'
  host_self_test=$testRun
  personal=$personalZip
  manageengine=$managedZip
  intune=$intunePath
  native_exe_unsigned=$true
  real_hardware_driver_install_test='NOT_RUN'
  real_managed_endpoint_test='NOT_RUN'
 }
 $hashes=@(Get-ChildItem $OutputDirectory -File -Recurse|Sort-Object FullName|ForEach-Object {
  [ordered]@{relative=$_.FullName.Substring($OutputDirectory.Length+1).Replace('\','/');sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;bytes=$_.Length}
 })
 $result['artifacts']=$hashes
 $result|ConvertTo-Json -Depth 10|Set-Content (Join-Path $OutputDirectory 'RELEASE-MANIFEST.json') -Encoding UTF8
 $result|ConvertTo-Json -Depth 6
}finally{
 Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
