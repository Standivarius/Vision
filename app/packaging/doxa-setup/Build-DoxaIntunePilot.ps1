param(
 [string]$OutputDirectory='',
 [Parameter(Mandatory=$true)][string]$ContentPrepTool
)
# Build a repeatable, unsigned Doxa Setup app-only Intune pilot from SOURCE.
# No Silicon Motion driver, user credentials, machine policy or device changes.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'artifacts\releases\intune'}
$output=[IO.Path]::GetFullPath($OutputDirectory)
$tool=[IO.Path]::GetFullPath($ContentPrepTool)
if(-not(Test-Path -LiteralPath $tool -PathType Leaf)){throw 'Microsoft Win32 prep tool not found'}
$sig=Get-AuthenticodeSignature -LiteralPath $tool
if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw 'Prep tool must be authentically signed by Microsoft'}
$stamp=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,7)
$stage=Join-Path $env:TEMP ('DoxaIntuneBuild-'+$stamp)
$src=Join-Path $stage 'source'
$personalOutput=Join-Path $stage 'personal'
$target=Join-Path $output ('doxa-intune-app-only-'+$stamp)
if(Test-Path -LiteralPath $target){throw 'Refusing to overwrite existing output'}
try{
 New-Item -Path $src,$personalOutput,$target -ItemType Directory -Force|Out-Null
 $bundle=Join-Path $PSScriptRoot 'Build-DoxaPersonalBundle.ps1'
 $raw=(& $bundle -OutputDirectory $personalOutput|Out-String)
 $result=$raw|ConvertFrom-Json
 if([string]$result.status -ne 'created' -or [bool]$result.vendor_msi_included -or [bool]$result.credentials_included){throw 'Personal bundle did not pass source manifest gate'}
 $testBundle=Join-Path $PSScriptRoot 'Test-DoxaPersonalBundle.ps1'
 $pass=(& $testBundle -BundlePath ([string]$result.path)|Out-String)|ConvertFrom-Json
 if($pass.status -ne 'PASS'){throw 'Extracted personal bundle failed'}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'enterprise-intune-pilot\DoxaPilot.ps1') -Destination $src
 Copy-Item -LiteralPath ([string]$result.path) -Destination (Join-Path $src 'DoxaSetupPayload.zip')
 $test=Join-Path $PSScriptRoot 'enterprise-intune-pilot\Test-DoxaPilot.py'
 $python=Get-Command python.exe -ErrorAction SilentlyContinue|Select-Object -First 1
 if(-not $python){throw 'Python required for local silent installer acceptance'}
 $testResult=(& $python.Source $test --payload (Join-Path $src 'DoxaSetupPayload.zip')|Out-String)|ConvertFrom-Json
 if($testResult.status -ne 'PASS'){throw 'Local silent install acceptance failed'}
 $packed=(& $tool -c $src -s (Join-Path $src 'DoxaPilot.ps1') -o $target -q 2>&1|Out-String)
 $files=@(Get-ChildItem -LiteralPath $target -File -Filter '*.intunewin')
 if($files.Count -ne 1){throw 'Microsoft Content Prep tool did not create exactly one package: '+$packed}
 $manifest=[ordered]@{
  package_type='DOXA_APP_ONLY_UNSIGNED_PILOT'
  driver_msi_bundled=$false
  cloud_ai_default_off=$true
  source_bundle_sha256=(Get-FileHash -LiteralPath (Join-Path $src 'DoxaSetupPayload.zip') -Algorithm SHA256).Hash
  package_path=$files[0].FullName
  package_sha256=(Get-FileHash -LiteralPath $files[0].FullName -Algorithm SHA256).Hash
  file_count=16
  tool_sha256=(Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash
  sign_status='Doxa app UNSIGNED; only Microsoft content prep tool is signed'
  local_tests='PASS'
  cloud_deployment='NOT PERFORMED'
 }
 [IO.File]::WriteAllText((Join-Path $target 'manifest.json'),($manifest|ConvertTo-Json -Depth 7),[Text.UTF8Encoding]::new($false))
 $manifest|ConvertTo-Json -Depth 7
}finally{
 if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
}
