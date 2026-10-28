param(
 [Parameter(Mandatory=$true)][string]$CompleteCandidateDirectory,
 [string]$ContentPrepTool='C:\dev\Vision\tools\intune-win32-content-prep-v1.8.7\IntuneWinAppUtil.exe',
 [string]$OutputDirectory='',
 [switch]$RequirePublisherSignatures
)
# Repackage one tested complete source bundle as single-file personal and managed installers.
# Keeps the original vendor MSI byte-for-byte, embedded as a C# resource.
# Does not install drivers, change Windows displays or assign endpoints.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'artifacts\releases\retail-final'}
if(Test-Path $OutputDirectory){throw 'Destination already exists; refusing overwrite'}
$from=[IO.Path]::GetFullPath($CompleteCandidateDirectory)
$sourceBundle=Join-Path $from 'Personal\Doxa-Complete-Windows-Setup.zip'
if(-not(Test-Path $sourceBundle -PathType Leaf)){throw 'Missing complete candidate'}
$toolSig=Get-AuthenticodeSignature $ContentPrepTool
if($toolSig.Status -ne 'Valid' -or $toolSig.SignerCertificate.Subject -notmatch 'Microsoft Corporation'){throw 'Microsoft content prep not signed correctly'}
$stage=Join-Path $env:TEMP ('DoxaRetail-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $PSScriptRoot 'DoxaSetupHost.cs'
$csc='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
New-Item $OutputDirectory,$stage -ItemType Directory -Force|Out-Null
try {
 Expand-Archive -LiteralPath $sourceBundle -DestinationPath $stage
 $msi=Join-Path $stage 'SMIUSBDisplaySW770.msi'
 $app=Join-Path $stage 'DoxaSetupPayload.zip'
 if((Get-FileHash $msi -Algorithm SHA256).Hash -ne '3379B46DA029423748E2D2E64DB2015B50136E310A492E31857CC726719192D4'){throw 'Driver payload changed'}
 $vendor=Get-AuthenticodeSignature $msi
 if($vendor.Status -ne 'Valid' -or $vendor.SignerCertificate.Subject -notmatch 'Silicon Motion'){throw 'Embedded driver signature failed'}
 $ref=@('/nologo','/platform:x64','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:Microsoft.CSharp.dll','/reference:System.Management.dll','/reference:System.Web.Extensions.dll','/reference:System.IO.Compression.dll','/reference:System.IO.Compression.FileSystem.dll')
 $personal=Join-Path $OutputDirectory 'Personal'
 $managed=Join-Path $OutputDirectory 'ManageEngine'
 $intune=Join-Path $OutputDirectory 'Intune'
 $tests=Join-Path $OutputDirectory 'Evidence'
 New-Item $personal,$managed,$intune,$tests -ItemType Directory -Force|Out-Null
 foreach($pair in @(@('winexe','DoxaSetup.exe'),@('exe','DoxaDeploy.exe'))){
   $target=if($pair[0] -eq 'winexe'){$personal}else{$managed}
   & $csc @ref ("/target:$($pair[0])") ("/out:$(Join-Path $target $pair[1])") ("/resource:$msi,Doxa.Driver") ("/resource:$app,Doxa.App") $source
   if($LASTEXITCODE){throw "Compiler failed for $($pair[1])"}
 }
 $exe=Join-Path $personal 'DoxaSetup.exe'
 $deploy=Join-Path $managed 'DoxaDeploy.exe'
 $testExe=Join-Path $stage 'standalone-test'
 New-Item $testExe -ItemType Directory|Out-Null
 Copy-Item $deploy $testExe
 $output=(& (Join-Path $testExe 'DoxaDeploy.exe') '/selftest'|Out-String).Trim()
 if($LASTEXITCODE -ne 0 -or $output -notmatch '^PASS:'){throw "Standalone embedded test failed: $output"}
 $detect=(& (Join-Path $testExe 'DoxaDeploy.exe') '/detect'|Out-String).Trim();$detectExit=$LASTEXITCODE
 $testRecord=[ordered]@{self_test='PASS';result=$output;live_dell_readonly_detect=$detect;detect_exit=$detectExit;extracted_from_embedded_resources=$true;system_install_test='NOT_RUN';managed_agent_test='NOT_RUN'}
 $testRecord|ConvertTo-Json -Depth 5|Set-Content (Join-Path $tests 'windows-standalone.json')
 $sigStatus=@{}
 foreach($f in @($exe,$deploy)){
  $sig=Get-AuthenticodeSignature $f
  $sigStatus[(Split-Path $f -Leaf)]=$sig.Status.ToString()
  if($RequirePublisherSignatures -and $sig.Status -ne 'Valid'){throw 'Production publisher signing required before final release'}
 }
 $manageZip=Join-Path $managed 'Doxa-Managed-Windows.zip'
 Compress-Archive -LiteralPath $deploy -DestinationPath $manageZip -CompressionLevel Optimal
 $intuneStage=Join-Path $stage 'intune-source'
 New-Item $intuneStage -ItemType Directory|Out-Null
 Copy-Item $deploy (Join-Path $intuneStage 'DoxaDeploy.exe')
 & $ContentPrepTool -c $intuneStage -s 'DoxaDeploy.exe' -o $intune -q *> (Join-Path $tests 'intune-packaging.log')
 if($LASTEXITCODE){throw 'Intune packaging failed'}
 $intuneFile=@(Get-ChildItem $intune -File -Filter '*.intunewin')
 if($intuneFile.Count -ne 1){throw 'Expected exactly one Intune package'}
 $how=@'
STANDIVARIUS DOXA SETUP - WINDOWS RELEASE CANDIDATE

PERSONAL: Deliver Personal\DoxaSetup.exe. It already embeds the hardware
driver package and the bilingual application. Customer connects power and USB
data, runs the EXE, chooses Install / check Doxa and approves Windows UAC.
A healthy signed driver is preserved; other drivers are never silently
overwritten. After installation the existing bilingual Doxa UI opens.

INTUNE: Upload Intune\DoxaDeploy.intunewin.
  Install (SYSTEM): DoxaDeploy.exe /install
  Detect (SYSTEM): DoxaDeploy.exe /detect
  Uninstall (SYSTEM): DoxaDeploy.exe /uninstall
  Machine driver verification: DoxaDeploy.exe /verify
  Exit 3010: Windows restart required (Doxa does not restart by itself).
  Test actual user-session 4-display independence after machine installation.

MANAGEENGINE: Upload ManageEngine\Doxa-Managed-Windows.zip as an approved
Windows software package. Execute DoxaDeploy.exe /install as SYSTEM, on an
approved, explicitly selected machine. The executable contains all payloads.
Detect and uninstall use the same commands as Intune.

SIGNING: Sign both DoxaSetup.exe and DoxaDeploy.exe, timestamp, verify
Authenticode. Then REBUILD both distribution packages and this manifest
using those exact signed binaries. The embedded driver is not modified.
Signing does not rewrite application behaviour, but changes executable bytes.

QUALITY GATES: Standalone embedded extraction PASS. Clean host physical
install, user-session screen testing and real endpoint-manager agent delivery
are separately needed before any production go-live claim.
'@
 [IO.File]::WriteAllText((Join-Path $OutputDirectory 'README-FIRST.txt'),$how,[Text.UTF8Encoding]::new($false))
 $files=@(Get-ChildItem $OutputDirectory -Recurse -File|Sort-Object FullName|ForEach-Object {
   [ordered]@{path=$_.FullName.Substring($OutputDirectory.Length+1).Replace('\','/');sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;bytes=$_.Length}
 })
 $release=[ordered]@{
  status=if($RequirePublisherSignatures){'SIGNED_BUILD_READY_FOR_ENDPOINT_QUALIFICATION'}else{'UNSIGNED_REVIEW_BUILD_PASS'}
  source_branch=((& git -C $root branch --show-current)|Out-String).Trim()
  embedded_package_source_sha256=(Get-FileHash $sourceBundle -Algorithm SHA256).Hash
  product='Standivarius Doxa Setup'
  machine_install_and_signatures=$sigStatus
  validated_standalone=$true
  test_evidence='Evidence/windows-standalone.json'
  live_driver_change='NONE'
  live_intune_deployment='NOT_RUN'
  live_manageengine_deployment='NOT_RUN'
  files=$files
 }
 $release|ConvertTo-Json -Depth 9|Set-Content (Join-Path $OutputDirectory 'RELEASE-MANIFEST.json') -Encoding UTF8
 $release|ConvertTo-Json -Depth 4
}finally{Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue}
