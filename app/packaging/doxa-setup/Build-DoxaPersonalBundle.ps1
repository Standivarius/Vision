param(
 [string]$OutputDirectory='',
 [switch]$TestOnly,
 [switch]$Reproducible
)
# Assemble a personal, portable Doxa hardware installer preview.
# No vendor binaries, private keys, environments, credentials or live system changes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $repo 'artifacts\releases'}
$items=@(
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
$buildStamp=(Get-Date).ToUniversalTime().ToString('s')+'Z'
if($Reproducible){
 $commitDate=(& git -C $repo log -1 --format=%cI | Out-String).Trim()
 if($LASTEXITCODE -ne 0 -or -not $commitDate){throw 'Immutable Git commit timestamp required for reproducible bundle'}
 $buildStamp=([DateTimeOffset]::Parse($commitDate)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
$stage=Join-Path $env:TEMP ('StandivariusDoxaSetup-'+[Guid]::NewGuid().ToString('N'))
$zip=$null
try {
 New-Item -ItemType Directory -Force -Path $stage|Out-Null
 $digests=@()
 foreach($relative in $items){
  $srcPath=Join-Path $repo ($relative.Replace('/','\'))
  if(-not(Test-Path -LiteralPath $srcPath -PathType Leaf)){throw 'Missing required source: '+$relative}
  $dest=Join-Path $stage ($relative.Replace('/','\'))
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest)|Out-Null
  Copy-Item -LiteralPath $srcPath -Destination $dest
  $digests+= [ordered]@{file=$relative;sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 $manifest=[ordered]@{
  product='Standivarius Doxa Setup'
  channel='personal-preview'
  preview_version='0.4.0-preview.10'
  schema_version=1
  bundle_created_utc=$buildStamp
  no_silicon_motion_driver_bundled=$true
  private_credentials_bundled=$false
  signing_status='UNSIGNED preview - not for public distribution'
  files=$digests
 }
 $launcher=@'
@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -File "%~dp0app\packaging\doxa-setup\personal-ui\Start-DoxaGuidedSetup.ps1"
if errorlevel 1 (
  echo.
  echo Doxa Setup could not start. Check your Windows script execution policy or ask IT.
  echo No driver or display settings were changed by this launcher.
  pause
)
endlocal
'@
 [IO.File]::WriteAllText((Join-Path $stage 'Open Doxa Setup.cmd'),$launcher,[Text.Encoding]::ASCII)
 $readme=@'
STANDIVARIUS DOXA SETUP v0.4 - GUIDED PERSONAL REVIEW PREVIEW

1. Extract the ZIP to a folder on Windows and double-click "Open Doxa Setup.cmd".
2. Review local diagnostic permissions. Cloud AI is OPTIONAL; declining it does not block setup.
3. Choose to connect Doxa now or to continue checking the computer without Doxa.
4. The wizard explains which PC data is read, then checks Windows, USB, the signed driver package and connected Doxa panels with your consent.
5. Use the three customer tabs: Detect Doxa, Set up screens (Connect / Arrange), and Install signed driver. The active tab highlights one framed work area including contextual help. Connector drawing: UPPER USB-C = power, LOWER USB-C = data/signal. Online AI requires separate permission and can be switched off again.
6. If the required official signed MSI is actually missing AND the connected Doxa can be qualified, choose it and confirm Windows administrator approval.
7. Pre-connection installation with the hardware-dependent vendor MSI has NOT been physically qualified and is not automatic. This preview is not a full customer install acceptance. For an existing signed driver, connect Doxa and use Detect Doxa.

LIMITS:
- USB-C port shape, real transfer speed and reliable Doxa screen operation cannot be guaranteed from a controller scan alone.
- No Silicon Motion MSI or personal credentials are included. Official vendor redistribution permission has not been established.
- The Doxa AI cloud identity is enrolled to Dell for this personal preview. Other machines retain local offline help.
- No automatic reboot, firmware update, driver removal, security-policy bypass or uncontrolled installation.
- This ZIP is UNSIGNED and intended only as a personal development preview. Public installer signing remains a release requirement.
- Doxa hardware Setup is independent of the Standivarius Vision low-vision software.
'@
 [IO.File]::WriteAllText((Join-Path $stage 'README-FIRST.txt'),$readme,[Text.UTF8Encoding]::new($false))
 # The launcher and first-use readme are generated content, not part of the source manifest.
 # Include their digests so installer detection cannot accept edited or added executables.
 $manifest['generated_files']=@(
  [ordered]@{file='Open Doxa Setup.cmd';sha256=(Get-FileHash -LiteralPath (Join-Path $stage 'Open Doxa Setup.cmd') -Algorithm SHA256).Hash.ToLowerInvariant()},
  [ordered]@{file='README-FIRST.txt';sha256=(Get-FileHash -LiteralPath (Join-Path $stage 'README-FIRST.txt') -Algorithm SHA256).Hash.ToLowerInvariant()}
 )
 [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'),($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
 if($TestOnly){
  [ordered]@{status='manifest_only';sources=$items.Count;staging=$stage;credential_files_bundled=$false;driver_msi_bundled=$false}|ConvertTo-Json -Compress
  return
 }
 if(-not(Test-Path -LiteralPath $OutputDirectory)){New-Item -ItemType Directory -Force -Path $OutputDirectory|Out-Null}
 $name='Standivarius-Doxa-Setup-personal-preview-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip'
 $zip=Join-Path $OutputDirectory $name
 if(Test-Path -LiteralPath $zip){throw 'Refusing to overwrite an existing bundle'}
 if($Reproducible){
  & python (Join-Path $PSScriptRoot 'Build-DoxaStableZip.py') $stage $zip | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Reproducible bundle failed'}
 }else{
 Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
 }
 [ordered]@{status='created';path=$zip;size_bytes=(Get-Item -LiteralPath $zip).Length;file_count=$items.Count;sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash;credentials_included=$false;vendor_msi_included=$false}|ConvertTo-Json -Compress
}finally{
 if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
